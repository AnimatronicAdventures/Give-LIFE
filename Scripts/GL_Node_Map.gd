extends Control
class_name GL_Node_Map

var background: TextureRect
var holder: Control
var is_panning: bool = false
var last_mouse_pos: Vector2
var is_hovered: bool = false

# Fix for save files v0.11 or before
var special_value_fix_map := {
	"AA_CHICA": "AA_CCA",
	"L_COLOR_A_CHICA": "L_COLOR_A_CCA",
	"L_COLOR_B_CHICA": "L_COLOR_B_CCA",
	"L_COLOR_A_FREDDY": "L_COLOR_A_FD",
	"L_COLOR_B_FREDDY": "L_COLOR_B_FD",
	"L_SPOT_CHICA": "L_SPOT_CCA",
	"L_SPOT_FREDDY": "L_SPOT_FD",
}

#Workspace shenanigans
var optionsVar:OptionButton
var editMenu:Control
var titleLineEdit:LineEdit
var authorLineEdit:LineEdit
var madeInLabel:Label
var createdLabel:Label
var updatedLabel:Label
@onready var exportDialog: FileDialog = $ExportDialog
@onready var importDialog: FileDialog = $ImportDialog
var _workspace_index_to_id: Dictionary = {}

#Workspaces
var _workspace_ID:String
var save_name: String = "My Save"
var author_name: String = "Unnamed Author"
var version: String = ProjectSettings.get_setting("application/config/version")
var game_title: String = ProjectSettings.get_setting("application/config/name")
var time_created: String = ""
var last_updated: String = ""

const carpetScale:float = 1.5

var loadedUsername:String = "Unnamed Author"

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		save_everything()

func _ready():
	background = get_node("Background")
	holder = get_node("Holder")
	optionsVar = get_node("MarginContainer/HBoxContainer/OptionButton")
	editMenu = get_node("Edit Menu")
	titleLineEdit = get_node("Edit Menu/MarginContainer/VBoxContainer/Title")
	authorLineEdit = get_node("Edit Menu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Author")
	madeInLabel = get_node("Edit Menu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Made In")
	createdLabel = get_node("Edit Menu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Created")
	updatedLabel = get_node("Edit Menu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/Updated")	
	
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

	auto_populate_metadata()
	populate_workspace_options()
	optionsVar.connect("item_selected", Callable(self, "_on_workspace_selected"))
	
	if background.material is ShaderMaterial:
		background.material.set_shader_parameter("uv_offset", Vector2.ZERO)
		background.material.set_shader_parameter("uv_scale", Vector2.ONE)

func _on_mouse_entered():
	is_hovered = true

func _on_mouse_exited():
	is_hovered = false

func _process(_delta):
	is_panning = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	if is_panning:
		last_mouse_pos = get_viewport().get_mouse_position()
	
	if background.material is ShaderMaterial:
		var scale = Vector2.ONE / holder.scale * carpetScale
		var offset = -holder.position / holder.scale * 0.001 * carpetScale

		background.material.set_shader_parameter("uv_scale", scale)
		background.material.set_shader_parameter("uv_offset", offset)

func _input(event: InputEvent) -> void:
	if not is_hovered:
		return

		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var mouse_pos = event.position
			var global_xform = holder.get_global_transform()
			var local_mouse_pos = global_xform.affine_inverse().basis_xform(mouse_pos)

			var zoom_factor := 1.0
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_factor = 1.1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_factor = 0.9

			holder.scale *= zoom_factor
			
			holder.scale.x = clamp(holder.scale.x, 0.1, 10.0)
			holder.scale.y = clamp(holder.scale.y, 0.1, 10.0)	

			var new_global_xform = holder.get_global_transform()
			var new_local_mouse_pos = new_global_xform.affine_inverse().basis_xform(mouse_pos)

			var delta = (new_local_mouse_pos - local_mouse_pos)
			holder.position += delta * holder.scale

	if event is InputEventMouseMotion and is_panning:
		var delta = event.position - last_mouse_pos
		holder.position += delta
		last_mouse_pos = event.position


func toggle_background():
	background.visible = !background.visible

func save_everything():
	var saveDict := {}
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	
	if holder.get_child_count() == 0:
		return

	for child in holder.get_children():
		child = child.get_child(0)
		if child is not GL_Node:
			print(child.name)
			continue

		var id = "SAVE_" + str(rng.randi())
		var node_data = {
			"path": child.nodePath,
			"name": child._get_title(),
			"uuid": child.uuid,
			"special_saved_values": child.special_saved_values,
			"rows": child.rows.duplicate(true),
			"position": child.position
		}

		# Save recording if it's a GL_Record and has enough data
		if child is GL_Record and child.recording != null:
			if child.recording.size() >= 3:
				var recording_file_path = "user://My Precious Save Files/" + str(_workspace_ID) + "/" + child.uuid + "_recording.tres"
				var recording_config = ConfigFile.new()
				recording_config.set_value("recording", "data", child.recording)
				var err = recording_config.save(recording_file_path)
				if err != OK:
					push_error("Failed to save recording for " + child.uuid + ": " + str(err))
				else:
					print("Saved recording for node ", child.uuid)

		# Convert connections to uuid references
		for key in node_data["rows"]:
			if node_data["rows"][key].has("connections"):
				var connections = node_data["rows"][key]["connections"]
				for i in range(connections.size()):
					if connections[i]["target"] is GL_Node:
						connections[i]["target"] = connections[i]["target"].uuid

		saveDict[id] = node_data

	var save_dir = "user://My Precious Save Files/" + str(_workspace_ID)
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file_path = save_dir + "/node_workspace.tres"

	var resource = ConfigFile.new()

	# Metadata section
	if time_created == "":
		time_created = Time.get_datetime_string_from_system(true)
	last_updated = Time.get_datetime_string_from_system(true)

	resource.set_value("meta", "save_name", save_name)
	resource.set_value("meta", "author", author_name)
	resource.set_value("meta", "version", ProjectSettings.get_setting("application/config/version"))
	resource.set_value("meta", "game_title", ProjectSettings.get_setting("application/config/name"))
	resource.set_value("meta", "time_created", time_created)
	resource.set_value("meta", "last_updated", last_updated)

	# Main save data
	resource.set_value("workspace", "data", saveDict)

	var err = resource.save(file_path)
	if err != OK:
		push_error("Failed to save workspace: " + str(err))
	else:
		print("Saved workspace to: ", file_path)

	populate_workspace_options()




func load_everything():
	var file_path = "user://My Precious Save Files/" + str(_workspace_ID) + "/node_workspace.tres"
	var resource = ConfigFile.new()
	var err = resource.load(file_path)
	if err != OK:
		push_error("Failed to load workspace: " + str(err))
		return {}

	# Load metadata
	save_name = resource.get_value("meta", "save_name", "Unnamed Save")
	author_name = resource.get_value("meta", "author", "Unknown Author")
	version = resource.get_value("meta", "version", "0.0")
	game_title = resource.get_value("meta", "game_title", "Untitled Game")
	time_created = resource.get_value("meta", "time_created", "")
	last_updated = resource.get_value("meta", "last_updated", "")
	_update_edit_menu_labels()

	print("Loaded workspace metadata:")
	print("Save Name: ", save_name)
	print("Author: ", author_name)
	print("Version: ", version)
	print("Game Title: ", game_title)
	print("Time Created: ", time_created)
	print("Last Updated: ", last_updated)

	var version_num = float(version)
	var needs_special_value_fix = version_num <= 0.11

	# Load nodes
	var data = resource.get_value("workspace", "data", {})
	for key in data:
		var original_path = data[key].get("path", "")
		var packed_scene = load(original_path)
		
		# ... (your existing Mods folder search code remains unchanged) ...

		if packed_scene == null:
			push_error("Could not load resource at path: " + data[key].get("path", "ERR"))
			continue

		var node = packed_scene.instantiate() as Control
		holder.add_child(node)
		node = node.get_child(0) as GL_Node
		node.position = data[key].get("position", Vector2.ZERO)
		node.nodePath = data[key].get("path", "ERR")
		node.uuid = data[key].get("uuid", "ERR_" + key + str(Time.get_ticks_msec()))
		node._set_title(data[key].get("name", "???"))
		
		# Merge saved rows into existing rows
		var saved_rows = data[key].get("rows", {})
		for row_key in saved_rows.keys():
			if node.rows.has(row_key):
				for sub_key in saved_rows[row_key].keys():
					node.rows[row_key][sub_key] = saved_rows[row_key][sub_key]
			else:
				node.rows[row_key] = saved_rows[row_key]

		node.special_saved_values = data[key].get("special_saved_values", {})

		# === FIX SPECIAL SAVED VALUES FOR OLD SAVES ===
		if needs_special_value_fix:
			for sv_key in node.special_saved_values.keys():
				var current_val = node.special_saved_values[sv_key]
				if typeof(current_val) == TYPE_STRING and special_value_fix_map.has(current_val):
					node.special_saved_values[sv_key] = special_value_fix_map[current_val]

		node._update_visuals()

		if node is GL_Record:
			var recording_file = "user://My Precious Save Files/" + str(_workspace_ID) + "/" + node.uuid + "_recording.tres"
			var config = ConfigFile.new()
			if config.load(recording_file) == OK:
				node.recording = config.get_value("recording", "data", {})


func generate_new_workspace_id() -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	return str(rng.randi())

func clear_holder():
	for node in holder.get_children():
		node.queue_free()
	await get_tree().process_frame  # ensure all nodes are freed
	
func populate_workspace_options():
	optionsVar.clear()
	_workspace_index_to_id.clear()

	optionsVar.add_item("New Workspace")
	_workspace_index_to_id[0] = null  # Index 0 is reserved for "New Workspace"

	var dir := DirAccess.open("user://My Precious Save Files")
	if dir:
		dir.list_dir_begin()
		var name = dir.get_next()
		var index = 1  # Start from 1 to skip "New Workspace"
		while name != "":
			if dir.current_is_dir() and name != "." and name != "..":
				var metadata_path = "user://My Precious Save Files/" + name + "/node_workspace.tres"
				var config = ConfigFile.new()
				var save_label = name
				if config.load(metadata_path) == OK:
					save_label = config.get_value("meta", "save_name", name) + " (" + name + ")"
				optionsVar.add_item(save_label)
				_workspace_index_to_id[index] = name
				index += 1
			name = dir.get_next()
		dir.list_dir_end()

func _on_workspace_selected(index: int):
	save_everything()

	if index == 0:  # New Workspace
		clear_holder()
		auto_populate_metadata()
		print("Created new workspace: ", _workspace_ID)
	else:
		if _workspace_index_to_id.has(index):
			_workspace_ID = _workspace_index_to_id[index]
		else:
			push_error("Invalid workspace selection index: " + str(index))
			return
		clear_holder()
		load_everything()

func auto_populate_metadata():
	_workspace_ID = generate_new_workspace_id()
	save_name = "My Save"
	author_name = loadedUsername
	version = ProjectSettings.get_setting("application/config/version")
	game_title = ProjectSettings.get_setting("application/config/name")
	time_created = ""
	last_updated = ""
	_update_edit_menu_labels()
	
func on_settings_applied(settings: Dictionary) -> void:
	loadedUsername = settings["username"]

func _update_edit_menu_labels():
	titleLineEdit.text = save_name
	authorLineEdit.text = author_name
	madeInLabel.text = "Made in " + game_title + " v" + version
	if time_created == "":
		createdLabel.text = "Not Saved Yet"
		updatedLabel.text = ""
	else:
		createdLabel.text = "Created: " + time_created
		updatedLabel.text = "Last Updated: " + last_updated
	
func _edit_button_toggled():
	editMenu.visible = !editMenu.visible
	
func title_changed(titleName:String):
	if titleName != save_name:
		save_name = titleName
	
func author_changed(authortext:String):
	if authortext != author_name:
		author_name = authortext

func export_workspace_zip():
	if _workspace_ID == "":
		push_error("No workspace ID to export.")
		return

	var workspace_path = "user://My Precious Save Files/" + _workspace_ID
	var dir := DirAccess.open(workspace_path)
	if dir == null:
		push_error("Could not open workspace folder.")
		return

	exportDialog.current_file = save_name + " (GLST).zip"
	exportDialog.popup_centered()

func _on_exportDialog_file_selected(clicked_path: String) -> void:
	var safe_path = sanitize_filename_from_path(clicked_path)
	var save_dir = safe_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(save_dir)

	var writer = ZIPPacker.new()
	var err = writer.open(safe_path, ZIPPacker.APPEND_CREATE)
	if err != OK:
		push_error("Failed to create zip: %s (error %d)" % [safe_path, err])
		return

	var workspace_root = "user://My Precious Save Files/" + _workspace_ID + "/"
	var files = _get_all_files_recursive(workspace_root)
	for rel in files:
		writer.start_file(rel)
		writer.write_file(FileAccess.get_file_as_bytes(workspace_root + rel))
		writer.close_file()  # MUST close each file before starting next
	writer.close()
	print("✅ Exported workspace to %s" % safe_path)


func sanitize_filename_from_path(path: String) -> String:
	var filename = path.get_file()
	var sanitized := ""
	for c in filename:
		if c in "/\\:*?\"<>|":
			sanitized += "_"
		else:
			sanitized += c
	
	return path.get_base_dir().path_join(sanitized)


func import_workspace_zip():
	importDialog.popup_centered()

func _on_importDialog_file_selected(path: String):
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		push_error("Failed to open zip file.")
		return

	if not zip.file_exists("node_workspace.tres"):
		push_error("Zip does not contain a valid node_workspace.tres file.")
		return

	var new_id = generate_new_workspace_id()
	var new_folder = "user://My Precious Save Files/" + new_id + "/"
	DirAccess.make_dir_recursive_absolute(new_folder)

	for i in zip.get_files():
		var file_path = new_folder + i
		var data = zip.read_file(i)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_buffer(data)
			file.close()
		else:
			push_error("Failed to write file: " + file_path)

	_workspace_index_to_id[optionsVar.item_count] = new_id
	populate_workspace_options()
	print("Imported workspace as ID: ", new_id)
	
func _get_all_files_recursive(base_path: String, rel_path: String = "") -> PackedStringArray:
	var files: PackedStringArray = []
	var dir_path = base_path.path_join(rel_path)
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return files

	dir.include_hidden = false
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			if dir.current_is_dir():
				# Recurse into the folder
				files.append_array(_get_all_files_recursive(base_path, rel_path.path_join(name)))
			else:
				# Add relative path so folder structure is preserved in ZIP
				files.append(rel_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()

	return files
