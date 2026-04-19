extends Node
class_name GL_Playback

@onready var master : GL_Master = $".."
@onready var timeline : GL_Timeline = $"../../Full Editor/Data Timeline"
@onready var audioPlayer : AudioStreamPlayer2D = $"../AudioStreamPlayer2D"

const _TIME_UNITS = 1.0 / 120.0
const AUDIO_EXTENSIONS = ["mp3", "wav", "ogg"]
const VIDEO_EXTENSIONS = ["mp4", "webm", "ogv"]
const _VIDEO_TIMESTAMP_INTERVAL = 0.1

var _lastTime : float = -1.0
var _scrubTimer : float = 0.0
var _isScrubbing : bool = false
var _media_state: Dictionary = {}
var _media_timers: Dictionary = {}

func _process(delta: float):
	if master.currentlyLoadedPath != "":
		for key in master.currentlyLoadedFile["channels"]:
			var ch = master.currentlyLoadedFile["channels"][key]
			var data = ch["data"]
			var type = GL_ChannelData.get_type(ch)
			var pipe = key.find("|")
			if pipe == -1:
				continue
			var group = key.left(pipe)
			var signal_key = key.substr(pipe + 1)
			
			# Handle both Video and Audio event channels with the same logic
			if type == GL_ChannelData.TYPE_VIDEO or type == GL_ChannelData.TYPE_AUDIO:
				_process_media_channel(key, type, data, group, signal_key, delta)
			else:
				var state = _get_state_for_type(type, data, key)
				for node in get_tree().get_nodes_in_group(group):
					node._sent_signals(signal_key, state)
		_process_audio(delta)

func _process_media_channel(channel_id: String, type: String, data, group: String, signal_key: String, delta: float) -> void:
	var entries: Array = GL_ChannelData.decode_entries(type, data)
	if entries.is_empty():
		return
		
	var t_int = int(timeline.timeCurrent / _TIME_UNITS)
	var active_entry: Dictionary = {}
	
	# Find the last marker that started before or at the current time
	for e in entries:
		if e["time"] <= t_int:
			active_entry = e
		else:
			break
			
	if active_entry.is_empty():
		return

	var prev = _media_state.get(channel_id, {})
	var entry_changed = prev.get("entry_time", -1) != active_entry["time"]
	
	# Update state if we've moved onto a new marker
	if entry_changed:
		_media_state[channel_id] = {
			"file": active_entry.get("file", "null"),
			"offset": active_entry.get("offset", 0.0),
			"stamp_time": GL_ChannelData.int_to_time(active_entry["time"]),
			"entry_time": active_entry["time"]
		}
		# Force an immediate signal update by maxing out the timer
		_media_timers[channel_id] = _VIDEO_TIMESTAMP_INTERVAL
		
	_media_timers[channel_id] = _media_timers.get(channel_id, 0.0) + delta
	
	# Send signals on interval (and immediately upon marker change)
	if _media_timers[channel_id] >= _VIDEO_TIMESTAMP_INTERVAL:
		_media_timers[channel_id] = 0.0
		
		var state = _media_state[channel_id]
		var file = state["file"]
		var offset = state["offset"]
		var stamp_time = state["stamp_time"]
		
		var path_to_send = null
		var time_to_send = 0.0
		
		if file != "null":
			path_to_send = master.currentlyLoadedPath.path_join(file)
			# Calculate timestamp: offset + (current timeline time - marker trigger time)
			time_to_send = max(offset + (timeline.timeCurrent - stamp_time), 0.0)
		
		# Always force both path and timestamp updates on this interval
		for node in get_tree().get_nodes_in_group(group):
			node._sent_signals(signal_key, path_to_send)
			node._sent_signals("Current Time", time_to_send)

func _get_state_for_type(type: String, data, channel_id: String):
	match type:
		GL_ChannelData.TYPE_BOOL:
			var stamps: Array = data if data is Array else []
			if timeline.activeEdit.has(channel_id):
				stamps = _merge_active_edit(stamps, channel_id)
			if stamps.is_empty():
				return 0.0
			return float(get_bool_state_at_time(stamps, timeline.timeCurrent))
		GL_ChannelData.TYPE_FLOAT:
			var entries: Array = GL_ChannelData.decode_entries(type, data)
			if entries.is_empty():
				return 0.0
			var t_int = int(timeline.timeCurrent / _TIME_UNITS)
			return GL_ChannelData.get_float_at_time(entries, t_int)
		GL_ChannelData.TYPE_COLOR:
			var entries: Array = GL_ChannelData.decode_entries(type, data)
			if entries.is_empty():
				return Color.BLACK
			var t_int = int(timeline.timeCurrent / _TIME_UNITS)
			var result_color: Color = entries[0]["color"]
			for e in entries:
				if e["time"] <= t_int:
					result_color = e["color"]
				else:
					break
			return result_color
		_:
			return 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_send_null_media_signals()

func _send_null_media_signals() -> void:
	if not master or master.currentlyLoadedPath == "":
		return
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return
	for key in master.currentlyLoadedFile["channels"]:
		var ch = master.currentlyLoadedFile["channels"][key]
		var type = GL_ChannelData.get_type(ch)
		if type != GL_ChannelData.TYPE_VIDEO and type != GL_ChannelData.TYPE_AUDIO:
			continue
		var pipe = key.find("|")
		if pipe == -1:
			continue
		var group = key.left(pipe)
		var signal_key = key.substr(pipe + 1)
		for node in scene_tree.get_nodes_in_group(group):
			node._sent_signals(signal_key, null)
			node._sent_signals("Current Time", 0.0)

func clean_sweep() -> void:
	if master.currentlyLoadedPath == "":
		return
	for key in master.currentlyLoadedFile["channels"]:
		var ch = master.currentlyLoadedFile["channels"][key]
		var data = ch["data"]
		var type = GL_ChannelData.get_type(ch)
		var is_empty = (data is Array and data.is_empty()) or (data is String and data == "")
		if not is_empty:
			continue
		var pipe = key.find("|")
		if pipe == -1:
			continue
		var group = key.left(pipe)
		var signal_key = key.substr(pipe + 1)
		for node in get_tree().get_nodes_in_group(group):
			node._sent_signals(signal_key, 0.0)

# ── Default media seeding ─────────────────────────────────────────────────────

func _seed_default_media() -> void:
	if master.currentlyLoadedPath == "":
		return
	var default_audio = _find_default_file(AUDIO_EXTENSIONS)
	var default_video = _find_default_file(VIDEO_EXTENSIONS)
	for key in master.currentlyLoadedFile["channels"]:
		var ch = master.currentlyLoadedFile["channels"][key]
		var type = GL_ChannelData.get_type(ch)
		if type != GL_ChannelData.TYPE_AUDIO and type != GL_ChannelData.TYPE_VIDEO:
			continue
		var data = ch.get("data", "")
		var is_empty = (data is String and data == "") or (data is Array and data.is_empty()) or data == null
		if not is_empty:
			continue
		var default_file: String = ""
		if type == GL_ChannelData.TYPE_AUDIO and default_audio != "":
			default_file = default_audio
		elif type == GL_ChannelData.TYPE_VIDEO and default_video != "":
			default_file = default_video
		if default_file == "":
			continue
		var entry = { "time": 0, "file": default_file, "offset": 0.0 }
		ch["data"] = GL_ChannelData.encode_entries(type, [entry])

func _find_default_file(extensions: Array) -> String:
	var folder = master.currentlyLoadedPath
	var dir = DirAccess.open(ProjectSettings.globalize_path(folder))
	if not dir:
		dir = DirAccess.open(folder)
	if not dir:
		return ""
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			if f.get_extension().to_lower() in extensions:
				return f
		f = dir.get_next()
	return ""

# ── Audio playback (Global Background) ────────────────────────────────────────

func reload_audio() -> void:
	audioPlayer.stop()
	audioPlayer.stream = null
	if master.currentlyLoadedPath == "":
		return
	var default_audio = _find_default_file(AUDIO_EXTENSIONS)
	if default_audio != "":
		var full_path = master.currentlyLoadedPath.path_join(default_audio)
		var stream = _load_audio_stream(full_path, default_audio.get_extension().to_lower())
		if stream:
			audioPlayer.stream = stream
			print("Audio loaded: ", default_audio)
	_seed_default_media()

func _process_audio(delta: float) -> void:
	if not audioPlayer.stream:
		return
	var current = timeline.timeCurrent
	var playing = timeline.playing
	if playing:
		_isScrubbing = false
		_scrubTimer = 0.0
		if not audioPlayer.playing:
			audioPlayer.play(current)
		else:
			if abs(audioPlayer.get_playback_position() - current) > 0.2:
				audioPlayer.seek(current)
	else:
		if audioPlayer.playing and not _isScrubbing:
			audioPlayer.stop()
		if abs(current - _lastTime) > 0.001:
			_isScrubbing = true
			_scrubTimer = 0.1
			audioPlayer.play(current)
		if _isScrubbing:
			_scrubTimer -= delta
			if _scrubTimer <= 0.0:
				_isScrubbing = false
				audioPlayer.stop()
	_lastTime = current

func _load_audio_stream(path: String, ext: String) -> AudioStream:
	var absolute_path = ProjectSettings.globalize_path(path)
	match ext:
		"mp3":
			return AudioStreamMP3.load_from_file(absolute_path)
		"wav":
			return AudioStreamWAV.load_from_file(absolute_path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(absolute_path)
	return null

func get_bool_state_at_time(stamps: Array, current_time: float) -> bool:
	var current_time_int: int = int(current_time / _TIME_UNITS)
	var lo: int = 0
	var hi: int = stamps.size() - 1
	var result_idx: int = -1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		if stamps[mid] <= current_time_int:
			result_idx = mid
			lo = mid + 1
		else:
			hi = mid - 1
	if result_idx == -1:
		return false
	return result_idx % 2 == 0

func _merge_active_edit(base: Array, channel_id: String) -> Array:
	var stamps = base.duplicate()
	var edit = timeline.activeEdit[channel_id]
	var range_start = min(edit["start"], timeline.timeCurrent)
	var range_end = max(edit["start"], timeline.timeCurrent)
	if range_end - range_start < (1.0 / 120.0):
		range_end = range_start + (1.0 / 120.0)
	var start_int = timeline.time_to_int(range_start)
	var end_int = timeline.time_to_int(range_end)
	var insert_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			insert_idx = i
			break
	var state_before: bool = insert_idx % 2 == 0
	var end_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] > end_int:
			end_idx = i
			break
	var state_after: bool = end_idx % 2 == 0
	for i in range(stamps.size() - 1, -1, -1):
		if stamps[i] >= start_int and stamps[i] <= end_int:
			stamps.remove_at(i)
	var ins = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			ins = i
			break
	if state_before:
		stamps.insert(ins, start_int)
		ins += 1
	if not state_after:
		stamps.insert(ins, end_int)
	return stamps
