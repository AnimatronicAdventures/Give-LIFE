extends HFlowContainer
class_name GL_Media

@onready var master = $"../../../../../../Master"

const SUPPORTED_EXTENSIONS = ["mp3", "wav", "ogg", "mp4", "ogv", "webm", "png", "jpg", "jpeg"]
const COVER_EXTENSIONS = ["png", "jpg", "jpeg"]
var itemPrefab = preload("res://New New/Prefabs/Media.tscn")
func _ready():
	reload_media()

func reload_media() -> void:
	for child in get_children():
		child.queue_free()

	if master.currentlyLoadedPath == "":
		return

	var folder = master.currentlyLoadedPath
	print("Folder: ", folder)
	print("Dir access: ", DirAccess.open(folder))
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

func _get_or_create_cover(file_path: String) -> ImageTexture:
	var folder = file_path.get_base_dir()
	var ext = file_path.get_extension().to_lower()

	# Image files are their own cover
	if ext in ["png", "jpg", "jpeg"]:
		var img = Image.load_from_file(file_path)
		if img:
			return ImageTexture.create_from_image(img)
		return null

	for cover_ext in COVER_EXTENSIONS:
		var cover_path = folder.path_join("cover." + cover_ext)
		if FileAccess.file_exists(cover_path):
			var img = Image.load_from_file(cover_path)
			if img:
				return ImageTexture.create_from_image(img)

	var image: Image = null

	if ext in ["mp4", "ogv", "webm"]:
		image = _extract_video_thumbnail(file_path)
	elif ext in ["mp3", "wav", "ogg"]:
		image = _extract_audio_cover(file_path)

	if image:
		var save_path = folder.path_join("cover.png")
		image.save_png(save_path)
		return ImageTexture.create_from_image(image)

	return null

func _extract_video_thumbnail(file_path: String) -> Image:
	var output = []
	var tmp_path = OS.get_temp_dir().path_join("gl_thumb.png")
	var args = ["-y", "-i", file_path, "-ss", "00:00:00.000", "-vframes", "1", tmp_path]
	var exit = OS.execute("ffmpeg", args, output, true)
	if exit == 0 and FileAccess.file_exists(tmp_path):
		var img = Image.load_from_file(tmp_path)
		DirAccess.remove_absolute(tmp_path)
		return img
	return null

func _extract_audio_cover(file_path: String) -> Image:
	var output = []
	var tmp_path = OS.get_temp_dir().path_join("gl_audiocover.png")
	var args = ["-y", "-i", file_path, "-an", "-vcodec", "png", tmp_path]
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

	var texture = _get_or_create_cover(file_path)
	if texture and cover:
		cover.texture = texture

	delete_btn.pressed.connect(_on_delete.bind(file_path))

func _on_delete(file_path: String) -> void:
	DirAccess.remove_absolute(file_path)
	reload_media()
