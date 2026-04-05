extends Node
class_name GL_SaveLoad

const saveFileVersion : int = 1
const _BYTES_PER_STAMP : int = 4

func generate_savefile(title: String) -> String:
	var node_data = {
		"title": title,
		"author": "Anonymous",
		"timeCreated": Time.get_datetime_string_from_system(true),
		"lastUpdated": Time.get_datetime_string_from_system(true),
		"saveFileVersion": str(saveFileVersion),
		"projectVersion": ProjectSettings.get_setting("application/config/version"),
		"projectName": ProjectSettings.get_setting("application/config/name"),
		"channels": {},
		"media": {},
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	var save_dir = "user://My Precious Save Files/" + str(rng.randi())

	var dir_err = DirAccess.make_dir_recursive_absolute(save_dir)
	if dir_err != OK:
		push_error("Could not create save directory: " + save_dir)
		return ""

	var file = FileAccess.open(save_dir + "/data.json", FileAccess.WRITE)
	if not file:
		push_error("Could not create data.json in: " + save_dir)
		return ""

	file.store_string(JSON.stringify(node_data, "\t"))
	file.close()
	return save_dir

func load_savefile(save_dir: String) -> Dictionary:
	var file = FileAccess.open(save_dir + "/data.json", FileAccess.READ)
	if not file:
		push_error("Could not open save file at: " + save_dir)
		return {}

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("Failed to parse save file JSON: " + json.get_error_message())
		return {}

	var data: Dictionary = json.data
	_decompress_channels(data)
	return data

func save_to_folder(data: Dictionary, save_dir: String) -> void:
	var file = FileAccess.open(save_dir + "/data.json", FileAccess.WRITE)
	if not file:
		push_error("Could not open save file at: " + save_dir)
		return

	var save_data: Dictionary = data.duplicate(true)
	_compress_channels(save_data)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

func copy_file_to_folder(file_path: String, save_dir: String) -> void:
	var err = DirAccess.copy_absolute(file_path, save_dir + "/" + file_path.get_file())
	if err != OK:
		push_error("Could not copy file from: " + file_path + " to: " + save_dir)

func _decompress_channels(data: Dictionary) -> void:
	for id in data["channels"]:
		var channel = data["channels"][id]
		channel["data"] = _stamps_from_b64(channel["data"])

func _compress_channels(data: Dictionary) -> void:
	for id in data["channels"]:
		var channel = data["channels"][id]
		if not channel.has("data") or not channel["data"] is Array:
			continue
		channel["data"] = _stamps_to_b64(channel["data"])

func _stamps_to_b64(stamps: Array) -> String:
	if stamps.is_empty():
		return ""
	var buf = PackedByteArray()
	buf.resize(stamps.size() * _BYTES_PER_STAMP)
	for i in range(stamps.size()):
		var s: int = stamps[i]
		buf[i * 4 + 0] = (s >> 24) & 0xFF
		buf[i * 4 + 1] = (s >> 16) & 0xFF
		buf[i * 4 + 2] = (s >> 8)  & 0xFF
		buf[i * 4 + 3] =  s        & 0xFF
	return Marshalls.raw_to_base64(buf)

func _stamps_from_b64(b64: String) -> Array:
	if b64 == "":
		return []
	var buf: PackedByteArray = Marshalls.base64_to_raw(b64)
	var stamps: Array = []
	for i in range(0, buf.size(), 4):
		if i + 3 >= buf.size():
			break
		var s: int = (buf[i] << 24) | (buf[i+1] << 16) | (buf[i+2] << 8) | buf[i+3]
		stamps.append(s)
	return stamps
