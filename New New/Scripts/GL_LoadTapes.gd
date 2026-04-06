extends Node
class_name GL_LoadTapes

const SAVE_ROOT = "user://My Precious Save Files"
const DATA_FILE = "data.json"
@onready var container : HFlowContainer = $HFlowContainer
@onready var modifier : GL_Master = $"../../../../Master"

var showEntryPrefab = preload("res://New New/Prefabs/LoadedShow.tscn") 

func _ready() -> void:
	scan_and_populate()

func scan_and_populate() -> void:
	for child in container.get_children():
		child.queue_free()

	var shows = find_valid_shows()
	for show in shows:
		var entry = showEntryPrefab.instantiate()
		container.add_child(entry)
		entry.get_node("MarginContainer/VBoxContainer/Title").text = show["title"]
		entry.get_node("MarginContainer/VBoxContainer/Author").text = show["author"]
		var path = show["path"] #dont delete this is dumb for loop stuff
		entry.pressed.connect(func(): modifier.load_show(path))
		var cover_texture = _find_cover(show["path"])
		if cover_texture:
			entry.get_node("MarginContainer/VBoxContainer/Cover").texture = cover_texture

func find_valid_shows() -> Array:
	var results = []

	var dir = DirAccess.open(SAVE_ROOT)
	if not dir:
		push_warning("Could not open save root: " + SAVE_ROOT)
		return results

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			var folder_path = SAVE_ROOT + "/" + folder_name
			var data_path = folder_path + "/" + DATA_FILE
			if FileAccess.file_exists(data_path):
				var show = _parse_show(data_path, folder_path)
				if show != {}:
					results.append(show)
		folder_name = dir.get_next()
	dir.list_dir_end()

	results.sort_custom(func(a, b): return a["lastUpdated"] > b["lastUpdated"])
	return results

func _find_cover(folder_path: String) -> Texture2D:
	for ext in ["png", "jpg", "jpeg"]:
		var path = folder_path + "/cover." + ext
		if FileAccess.file_exists(path):
			var image = Image.load_from_file(path)
			if image:
				return ImageTexture.create_from_image(image)
	return null

func _parse_show(data_path: String, folder_path: String) -> Dictionary:
	var file = FileAccess.open(data_path, FileAccess.READ)
	if not file:
		return {}

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("Skipping malformed JSON at: " + data_path)
		return {}

	var data: Dictionary = json.data

	return {
		"path":        folder_path,
		"title":       data.get("title", "Untitled"),
		"author":      data.get("author", "Unknown"),
		"timeCreated": data.get("timeCreated", ""),
		"lastUpdated": data.get("lastUpdated", ""),
		"version":     data.get("saveFileVersion", "?"),
		"channels":    data.get("channels", {}).size(),
	}
