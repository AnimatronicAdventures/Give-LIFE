extends HFlowContainer
class_name GL_Media

@onready var master = $"../../../../../../Master"
@onready var playback = $"../../../../../../Master/Playback"

const SUPPORTED_EXTENSIONS = ["mp3", "wav", "ogg", "mp4", "ogv", "webm", "png", "jpg", "jpeg"]
const COVER_EXTENSIONS = ["png", "jpg", "jpeg"]
var itemPrefab = preload("res://New New/Prefabs/Media.tscn")

func _ready():
	reload_media()

func import_file() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray([
		"*.mp3,*.wav,*.ogg,*.mp4,*.ogv,*.webm,*.png,*.jpg,*.jpeg ; Supported Media"
	])
	add_child(dialog)
	dialog.popup_centered(Vector2(900, 600))
	dialog.file_selected.connect(_on_file_selected)
	dialog.canceled.connect(dialog.queue_free)

func _on_file_selected(source_path: String) -> void:
	var dialogs = get_children().filter(func(c): return c is FileDialog)
	if dialogs.size() > 0:
		dialogs[0].queue_free()

	var ext = source_path.get_extension().to_lower()
	if ext not in SUPPORTED_EXTENSIONS:
		printerr("Unsupported file type: ", ext)
		return

	var folder = master.currentlyLoadedPath
	var file_name = source_path.get_file()
	var dest_path = folder.path_join(file_name)

	if FileAccess.file_exists(dest_path):
		var base = file_name.get_basename()
		var dest_ext = file_name.get_extension()
		var copy_path = folder.path_join("%s (copy).%s" % [base, dest_ext])
		var copy_count = 1
		while FileAccess.file_exists(copy_path):
			copy_count += 1
			copy_path = folder.path_join("%s (copy %d).%s" % [base, copy_count, dest_ext])
		dest_path = copy_path

	var err = DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		printerr("Failed to copy file: ", err)
		return

	print("Imported: ", dest_path)

	var cover_exists = false
	for cover_ext in COVER_EXTENSIONS:
		if FileAccess.file_exists(folder.path_join("cover." + cover_ext)):
			cover_exists = true
			break

	if not cover_exists:
		var image: Image = null
		if ext in ["mp4", "ogv", "webm"]:
			image = _extract_video_thumbnail(dest_path)
		elif ext in ["mp3", "wav", "ogg"]:
			image = _extract_audio_cover(dest_path)
		if image:
			image.save_png(folder.path_join("cover.png"))
			print("Cover extracted and saved.")
			
	_save_cover_if_missing(folder, dest_path)
	reload_media()

func reload_media() -> void:
	for child in get_children():
		child.queue_free()

	if master.currentlyLoadedPath == "":
		return

	var folder = master.currentlyLoadedPath
	var dir = DirAccess.open(folder)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext in SUPPORTED_EXTENSIONS:
				_spawn_item(folder.path_join(file_name))
		file_name = dir.get_next()
		
func _get_cover_for_display(file_path: String) -> ImageTexture:
	var ext = file_path.get_extension().to_lower()

	if ext in COVER_EXTENSIONS:
		var img = Image.load_from_file(file_path)
		if img:
			return ImageTexture.create_from_image(img.duplicate())
		return null

	var image: Image = null
	if ext in ["mp4", "ogv", "webm"]:
		image = _extract_video_thumbnail(file_path)
	elif ext in ["mp3", "wav", "ogg"]:
		image = _extract_audio_cover(file_path)

	if image:
		return ImageTexture.create_from_image(image.duplicate())

	return null
	
func _save_cover_if_missing(folder: String, file_path: String) -> void:
	var ext = file_path.get_extension().to_lower()
	for cover_ext in COVER_EXTENSIONS:
		if FileAccess.file_exists(folder.path_join("cover." + cover_ext)):
			return
	var image: Image = null
	if ext in ["mp4", "ogv", "webm"]:
		image = _extract_video_thumbnail(file_path)
	elif ext in ["mp3", "wav", "ogg"]:
		image = _extract_audio_cover(file_path)
	if image:
		image.save_png(folder.path_join("cover.png"))
		print("Cover saved.")
		
func _extract_video_thumbnail(file_path: String) -> Image:
	var output = []
	var tmp_path = OS.get_temp_dir().path_join("gl_thumb.png")
	var absolute_path = ProjectSettings.globalize_path(file_path)
	var args = ["-y", "-i", absolute_path, "-ss", "00:00:00.000", "-vframes", "1", "-update", "1", tmp_path]
	var exit = OS.execute("ffmpeg", args, output, true)
	if exit == 0 and FileAccess.file_exists(tmp_path):
		var img = Image.load_from_file(tmp_path)
		DirAccess.remove_absolute(tmp_path)
		return img
	return null

func _extract_audio_cover(file_path: String) -> Image:
	var output = []
	var tmp_path = OS.get_temp_dir().path_join("gl_audiocover.png")
	var absolute_path = ProjectSettings.globalize_path(file_path)
	var args = ["-y", "-i", absolute_path, "-map", "0:v:0", "-vframes", "1", "-update", "1", tmp_path]
	var exit = OS.execute("ffmpeg", args, output, true)
	if exit == 0 and FileAccess.file_exists(tmp_path):
		var img = Image.load_from_file(tmp_path)
		DirAccess.remove_absolute(tmp_path)
		return img
	return null

func _spawn_item(file_path: String) -> void:
	var item = itemPrefab.instantiate()
	add_child(item)

	var cover = item.get_node("Control/cover") as TextureRect
	var filename = item.get_node("Control/HBoxContainer/filename") as Label
	var delete_btn = item.get_node("Control/HBoxContainer/delete") as TextureButton

	filename.text = file_path.get_file()

	var texture = _get_cover_for_display(file_path)
	if texture and cover:
		cover.texture = texture

	delete_btn.pressed.connect(_on_delete.bind(file_path))

func _on_delete(file_path: String) -> void:
	DirAccess.remove_absolute(file_path)
	reload_media()
	playback.reload_audio()
