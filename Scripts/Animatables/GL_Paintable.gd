extends GL_Animatable
class_name GL_Paintable

@export var check_siblings: bool = false   # If true, also checks sibling nodes recursively

# Cache of materials → list of ShaderMaterials
# Example: { "green_material": [ShaderMaterial, ShaderMaterial, ...] }
var material_cache: Dictionary = {}
var param_names = ["paint_color_r", "paint_color_g", "paint_color_b", "paint_color_a"]

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
					if mat:
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


# Called externally to change a shader param color
# Example custom shader: _sent_signals("green_material|0", Color(0.8,0.2,0.2))
# Example standard Godot shader: _sent_signals("green_mat|A", Color(0.8,0.2,0.2))
func _sent_signals(_signal_ID: String, _the_signal) -> void:
	if typeof(_the_signal) != TYPE_COLOR:
		return
	
	if not _signal_ID.contains("|"):
		push_error("Invalid signal ID format, expected 'material_name|index_or_code'")
		return

	var parts = _signal_ID.split("|")
	if parts.size() != 2:
		push_error("Invalid signal ID format, expected 'material_name|index_or_code'")
		return

	var mat_name: String = parts[0]
	var key: String = parts[1]

	if not material_cache.has(mat_name):
		push_warning("Material not found in cache: " + mat_name)
		return

	for mat in material_cache[mat_name]:
		if mat is ShaderMaterial:
			if key == "A":
				mat.set_shader_parameter("albedo", _the_signal)
			elif key.is_valid_int():
				var index = int(key)
				if index < 0 or index >= param_names.size():
					push_error("Invalid parameter index: " + str(index))
					return
				var target_param = param_names[index]
				mat.set_shader_parameter(target_param, _the_signal)
			
