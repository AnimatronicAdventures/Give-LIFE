extends MenuButton
class_name GL_ImportSaveTemplates

const TEMPLATES_SUBPATH = "Mod Directory/Save Templates"

@onready var master : GL_Master = $"../../../../../Master"

var _templates: Dictionary = {}

func _ready() -> void:
	_load_templates()
	get_popup().id_pressed.connect(_on_item_selected)

func _load_templates() -> void:
	_templates.clear()
	get_popup().clear()

	var mods_path = "res://Mods"
	if not DirAccess.dir_exists_absolute(mods_path):
		push_error("Mods directory not found: " + mods_path)
		return

	var mods_dir = DirAccess.open(mods_path)
	if mods_dir == null:
		push_error("Failed to open Mods directory: " + mods_path)
		return

	mods_dir.list_dir_begin()
	var mod_folder = mods_dir.get_next()
	while mod_folder != "":
		if mods_dir.current_is_dir() and mod_folder != "." and mod_folder != "..":
			var templates_path = mods_path + "/" + mod_folder + "/" + TEMPLATES_SUBPATH
			if DirAccess.dir_exists_absolute(templates_path):
				var templates_dir = DirAccess.open(templates_path)
				if templates_dir != null:
					templates_dir.list_dir_begin()
					var fname = templates_dir.get_next()
					while fname != "":
						if not templates_dir.current_is_dir() and fname.to_lower().ends_with(".json"):
							var file_path = templates_path + "/" + fname
							var file = FileAccess.open(file_path, FileAccess.READ)
							if file:
								var parsed = JSON.new().parse_string(file.get_as_text())
								file.close()
								if typeof(parsed) == TYPE_DICTIONARY:
									var basename = fname.get_basename()
									_templates[basename] = parsed
									get_popup().add_item(basename)
								else:
									push_warning("Failed to parse JSON: " + file_path)
						fname = templates_dir.get_next()
					templates_dir.list_dir_end()
		mod_folder = mods_dir.get_next()
	mods_dir.list_dir_end()

	if _templates.is_empty():
		push_warning("No save templates found.")
		
	get_popup().add_separator()
	get_popup().add_item("Create From Scratch")

func _on_item_selected(id: int) -> void:
	var basename = get_popup().get_item_text(id)
	if basename == "Create From Scratch":
		master._create_new_show()
	elif _templates.has(basename):
		master._create_new_show_template(_templates[basename])
