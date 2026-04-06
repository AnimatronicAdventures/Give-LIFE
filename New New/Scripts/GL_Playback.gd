extends Node
class_name GL_Playback
@onready var master : GL_Master = $".."
@onready var timeline : GL_Timeline = $"../../Full Editor/Data Timeline"
@onready var audioPlayer : AudioStreamPlayer2D = $"../AudioStreamPlayer2D"

const _TIME_UNITS = 1.0 / 120.0
const AUDIO_EXTENSIONS = ["mp3", "wav", "ogg"]

var _lastTime : float = -1.0
var _scrubTimer : float = 0.0
var _isScrubbing : bool = false

func _process(_delta):
	if master.currentlyLoadedPath != "":
		for key in master.currentlyLoadedFile["channels"]:
			var data = master.currentlyLoadedFile["channels"][key]["data"]
			if not data is Array:
				continue
			var pipe = key.find("|")
			if pipe == -1:
				continue
			var group = key.left(pipe)
			var signal_key = key.substr(pipe + 1)
			var effective_data = data
			if timeline.activeEdit.has(key):
				effective_data = _merge_active_edit(data, key)
			if effective_data.is_empty():
				continue

			var state = float(get_bool_state_at_time(effective_data, timeline.timeCurrent))
			for node in get_tree().get_nodes_in_group(group):
				node._sent_signals(signal_key, state)

		_process_audio(_delta)

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
			# Keep audio in sync if it drifts
			if abs(audioPlayer.get_playback_position() - current) > 0.2:
				audioPlayer.seek(current)
	else:
		if audioPlayer.playing and not _isScrubbing:
			audioPlayer.stop()

		# Detect scrub — time changed while paused
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

func reload_audio() -> void:
	audioPlayer.stop()
	audioPlayer.stream = null

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
			if ext in AUDIO_EXTENSIONS:
				var full_path = folder.path_join(file_name)
				var stream = _load_audio_stream(full_path, ext)
				if stream:
					audioPlayer.stream = stream
					print("Audio loaded: ", file_name)
					return
		file_name = dir.get_next()

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
