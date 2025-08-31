extends GL_Animatable
class_name GL_Colorable

@export var check_siblings: bool = false   # If true, also checks sibling nodes recursively

# Cache of materials → list of ShaderMaterials
# Example: { "green_material": [ShaderMaterial, ShaderMaterial, ...] }
var material_cache: Dictionary = {}

func _ready() -> void:
	_build_material_cache()


func _build_material_cache() -> void:
	material_cache.clear()

	# Always search recursively under this node
	_cache_materials_in_tree(self)

	# If sibling checking is enabled, search them too
	if check_siblings and get_parent():
		for sibling in get_parent().get_children():
			if sibling != self and sibling is Node3D:
				_cache_materials_in_tree(sibling)

func _cache_materials_in_tree(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh: Mesh = child.mesh
			if mesh:
				for surface_idx in range(mesh.get_surface_count()):
					var mat: Material = child.get_active_material(surface_idx)
					if mat and mat is ShaderMaterial:
						var mat_name = ""

						if mat.resource_path != "":
							# Extract the filename without extension (e.g., "Chica")
							mat_name = mat.resource_path.get_file().get_basename()
						else:
							# Fallback for embedded / unsaved materials
							mat_name = "Material_%s_%d" % [str(mat.get_rid()), surface_idx]

						if not material_cache.has(mat_name):
							material_cache[mat_name] = []
						material_cache[mat_name].append(mat)

		# Always recurse into children
		_cache_materials_in_tree(child)


# Helper to recursively collect meshes
func _collect_meshes_recursive(node: Node, meshes: Array) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		if child is Node: # only recurse into Nodes
			_collect_meshes_recursive(child, meshes)


# Called externally to change a shader param color
# Example: _sent_signals("green_material|0", Color(0.8,0.2,0.2))
func _sent_signals(_signal_ID: String, _the_signal: Color) -> void:
	if not _signal_ID.contains("|"):
		push_error("Invalid signal ID format, expected 'material_name|index'")
		return

	var parts = _signal_ID.split("|")
	if parts.size() != 2:
		push_error("Invalid signal ID format, expected 'material_name|index'")
		return

	var mat_name: String = parts[0]
	var index: int = int(parts[1])

	var param_names = ["paint_color_r", "paint_color_g", "paint_color_b", "paint_color_a"]
	if index < 0 or index >= param_names.size():
		push_error("Invalid parameter index: " + str(index))
		return

	var target_param = param_names[index]

	# Look up cached materials
	if material_cache.has(mat_name):
		for mat in material_cache[mat_name]:
			if mat is ShaderMaterial:
				mat.set_shader_parameter(target_param, _the_signal)
