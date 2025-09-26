extends GL_Node_Picker

var video_selector: OptionButton
var file_dialog: FileDialog

func _ready():
	file_dialog = get_node("FileDialog")
	video_selector = get_node("HBox").get_node("OptionButton")
	DirAccess.make_dir_recursive_absolute(find_video_path())
	file_dialog.file_selected.connect(_on_video_file_selected)
	_update_video_options()

func _on_video_button_pressed():
	file_dialog.clear_filters()
	file_dialog.current_path = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	file_dialog.add_filter("*.ogv ; OGV Video")
	file_dialog.popup_centered()

func _on_video_file_selected(path: String):
	var filename = path.get_file()
	var dest_path = find_video_path() + "/" + filename

	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = file.get_buffer(file.get_length())
		file.close()

		var save_file = FileAccess.open(dest_path, FileAccess.WRITE)
		if save_file:
			save_file.store_buffer(data)
			save_file.close()
			print("Saved video to: ", dest_path)
			_update_video_options(filename)
		else:
			push_error("Failed to write video file to: " + dest_path)
	else:
		push_error("Failed to read selected video file: " + path)

func _update_video_options(select_filename := ""):
	video_selector.clear()
	var video_files: Array = []

	var dir = DirAccess.open(find_video_path())
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if not dir.current_is_dir():
				# optional: filter by extension
				var ext = fname.get_extension().to_lower()
				if ext in ["ogv"]:
					video_files.append(fname)
			fname = dir.get_next()
		dir.list_dir_end()

	video_files.sort()
	for i in video_files.size():
		video_selector.add_item(video_files[i])
		if video_files[i] == select_filename:
			video_selector.select(i)
			_set_video_path(video_files[i])

func _on_video_option_selected(index: int):
	var fname = video_selector.get_item_text(index)
	_set_video_path(fname)

func _set_video_path(file: String):
	var path = find_video_path() + "/" + file
	if mainNode and mainNode.rows.has(valueName):
		var video = GL_VideoType.new()
		video.value = path
		mainNode.rows[valueName]["pickValue"] = video
		print("Video set: ", path)
	else:
		push_error("mainNode or rows[valueName] not found.")

func find_video_path() -> String:
	for node in get_tree().get_nodes_in_group("Node Map"):
		if node is GL_Node_Map:
			return "user://My Precious Save Files/" + node._workspace_ID + "/Video"
	return ""
