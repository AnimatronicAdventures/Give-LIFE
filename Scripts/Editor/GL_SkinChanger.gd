extends Control

const PAINTABLE_SHADERS = [
	"res://Shaders/GL_Paintable.gdshader",
	"res://Shaders/Paintable_Simple.gdshader"
]

@onready var skin_preview: TextureRect = $"VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/Character Portrait"
@onready var skin_author_label: Label = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/Author
@onready var character_option: OptionButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/CharacterBox
@onready var skin_option: OptionButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/SkinBox
@onready var material_option: OptionButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer/MarginContainer/VBoxContainer2/MaterialBox
@onready var material_panel: PanelContainer =$VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer
@onready var color_pickers: Array = [
$VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer/MarginContainer/VBoxContainer2/ColorA,
$VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer/MarginContainer/VBoxContainer2/ColorB,
$VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer/MarginContainer/VBoxContainer2/ColorC,
$VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer2/PanelContainer/MarginContainer/VBoxContainer2/ColorD,
]

const FALLBACK_ICON = preload("res://UI/Question.png")
const ANIMATABLES_SUBPATH = "Animatables"

var skin_db: Dictionary = {}
var custom_colors: Dictionary = {}
var current_group: String = ""
var current_skin_name: String = ""
var current_material: String = ""
var _active_instances: Array = []


func _ready() -> void:
	_scan_mods()
	_populate_character_option()
	character_option.item_selected.connect(_on_character_selected)
	skin_option.item_selected.connect(_on_skin_selected)
	material_option.item_selected.connect(_on_material_selected)
	for i in color_pickers.size():
		color_pickers[i].color_changed.connect(_on_color_changed.bind(i))


func _scan_mods() -> void:
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		return
	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			_scan_animatables("res://Mods/%s/Mod Directory/%s" % [mod_name, ANIMATABLES_SUBPATH])
		mod_name = mods_dir.get_next()
	mods_dir.list_dir_end()


func _scan_animatables(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			var full_path = "%s/%s" % [path, file]
			var packed = load(full_path)
			if packed:
				var instance = packed.instantiate()
				var groups = instance.get_groups()
				var group = ""
				for g in groups:
					group = g
					break
				if group != "":
					var skin_name = file.get_basename()
					var icon: Texture2D = null
					var authors: String = ""
					if instance.get_script():
						if "skinIcon" in instance:
							icon = instance.skinIcon
						if "skinAuthors" in instance:
							authors = instance.skinAuthors
					var paintable_mats = _extract_paintable_materials(instance)
					if not skin_db.has(group):
						skin_db[group] = {}
					skin_db[group][skin_name] = {
						"path": full_path,
						"icon": icon,
						"authors": authors,
						"materials": paintable_mats,
					}
				instance.queue_free()
		file = dir.get_next()
	dir.list_dir_end()

func _extract_paintable_materials(node: Node) -> Dictionary:
	var found: Dictionary = {}
	_recurse_materials(node, found)
	return found


func _recurse_materials(node: Node, found: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = node.get_active_material(i)
				if mat and mat is ShaderMaterial:
					var shader = mat.shader
					if shader and shader.resource_path in PAINTABLE_SHADERS:
						var mat_name = ""
						if mat.resource_path != "":
							mat_name = mat.resource_path.get_file().get_basename()
						else:
							mat_name = "Material_%s_%d" % [str(mat.get_rid()), i]
						if mat_name not in found:
							var defaults: Dictionary = {}
							var params = ["paint_color_r", "paint_color_g", "paint_color_b", "paint_color_a"]
							for idx in params.size():
								var val = mat.get_shader_parameter(params[idx])
								if val is Color:
									defaults[idx] = val
							found[mat_name] = defaults
	for child in node.get_children():
		_recurse_materials(child, found)


func _populate_character_option() -> void:
	character_option.clear()
	for group in skin_db.keys():
		character_option.add_item(group)
	if character_option.item_count > 0:
		_on_character_selected(0)


func _on_character_selected(index: int) -> void:
	current_group = character_option.get_item_text(index)
	custom_colors.clear()
	_populate_skin_option()


func _populate_skin_option() -> void:
	skin_option.clear()
	if not skin_db.has(current_group):
		return
	for skin_name in skin_db[current_group].keys():
		skin_option.add_item(skin_name)
	if skin_option.item_count > 0:
		_on_skin_selected(0)


func _on_skin_selected(index: int) -> void:
	current_skin_name = skin_option.get_item_text(index)
	_refresh_preview()
	_refresh_material_list()
	_swap_scene()


func _refresh_preview() -> void:
	var data = _current_skin_data()
	if not data:
		return
	var icon = data.get("icon", null)
	skin_preview.texture = icon if icon else FALLBACK_ICON
	skin_author_label.text = "Skin by %s" % data.get("authors", "???")

func _refresh_material_list() -> void:
	material_option.clear()
	var data = _current_skin_data()
	if not data:
		material_panel.visible = false
		return
	for mat_name in data.get("materials", {}).keys():
		material_option.add_item(mat_name)
	if material_option.item_count > 0:
		material_panel.visible = true
		_on_material_selected(0)
	else:
		material_panel.visible = false
		current_material = ""
		_update_color_pickers_from_cache()


func _on_material_selected(index: int) -> void:
	current_material = material_option.get_item_text(index)
	_update_color_pickers_from_cache()


func _update_color_pickers_from_cache() -> void:
	if current_material == "":
		return
	var key = "%s|%s" % [current_skin_name, current_material]
	var cached = custom_colors.get(key, {})
	var data = _current_skin_data()
	var defaults: Dictionary = {}
	if data and data.get("materials", {}).has(current_material):
		defaults = data["materials"][current_material]
	for i in color_pickers.size():
		if cached.has(i):
			color_pickers[i].color = cached[i]
		elif defaults.has(i):
			color_pickers[i].color = defaults[i]


func _on_color_changed(color: Color, param_index: int) -> void:
	if current_material == "":
		return
	var key = "%s|%s" % [current_skin_name, current_material]
	if not custom_colors.has(key):
		custom_colors[key] = {}
	custom_colors[key][param_index] = color
	var signal_id = "%s|%s|%d" % [current_group, current_material, param_index]
	_broadcast_signal(signal_id, color)


func _broadcast_signal(signal_id: String, value) -> void:
	var tree = get_tree()
	if not tree:
		return
	var nodes = tree.get_nodes_in_group(current_group)
	for node in nodes:
		if node.has_method("_sent_signals"):
			node._sent_signals(signal_id, value)

func _swap_scene() -> void:
	var data = _current_skin_data()
	if not data:
		return
	var tree = get_tree()
	if not tree:
		return
	var existing = tree.get_nodes_in_group(current_group)
	if existing.is_empty():
		return

	var transforms: Array = []
	var parents: Array = []
	for node in existing:
		var parent = node.get_parent()
		if node is Node3D and parent:
			transforms.append(node.global_transform)
			parents.append(parent)
		node.remove_from_group(current_group)
		node.queue_free()

	if transforms.is_empty():
		return

	var packed = load(data["path"])
	if not packed:
		return

	for node in existing:
		if is_instance_valid(node):
			node.free()
	for i in transforms.size():
		var parent = parents[i]
		if not is_instance_valid(parent):
			push_warning("SkinSwapper: parent for slot %d was freed, skipping." % i)
			continue
		var instance = packed.instantiate()
		parent.add_child(instance)
		if instance is Node3D:
			instance.global_transform = transforms[i]

	_reapply_custom_colors()

func _reapply_custom_colors() -> void:
	for key in custom_colors.keys():
		var parts = key.split("|", true, 1)
		if parts.size() != 2 or parts[0] != current_skin_name:
			continue
		var mat_name = parts[1]
		var colors = custom_colors[key]
		for param_index in colors.keys():
			var signal_id = "%s|%s|%d" % [current_group, mat_name, param_index]
			_broadcast_signal(signal_id, colors[param_index])

func _current_skin_data() -> Dictionary:
	if skin_db.has(current_group) and skin_db[current_group].has(current_skin_name):
		return skin_db[current_group][current_skin_name]
	return {}
