extends Control
class_name GL_Timeline
@onready var master : GL_Master= $"../../Master"
@onready var createChannel : OptionButton = $MarginContainer/TimelineBox/CreateChannel
@onready var timelineBox : VBoxContainer = $MarginContainer/TimelineBox
@onready var playButton : Button = $"../TimeManager/HBoxContainer/Play Button"
@onready var timeStartText : Label = $"../TimeManager/MarginContainer/StartTime"
@onready var timeEndText : Label = $"../TimeManager/MarginContainer/EndTime"
@onready var timelinePositionBar : ColorRect = $TimelineBar
@onready var currentTimeText : Label = $TimelineBar/currentTime

var channelPrefab = preload("res://New New/Prefabs/Channel.tscn")
var scrolledIndex = 0
var timeStart = 0.0
var timeEnd = 10.0
var timeCurrent = timeStart
var playing = false
var channelXs = 0
var channelWidths = 1920
var activeEdit: Dictionary = {}
var channelBinds: Dictionary = {}

const zoomMultOut = 1.1
const zoomMultIn = 0.9
const zoomMin = 0.1
const zoomMax = 60
const panAmount = 0.1
const MAX_VISIBLE_CHANNELS = 10

# ── Dirty flag ────────────────────────────────────────────────────────────────
var _timeline_dirty: bool = false

# ── Label update guards ───────────────────────────────────────────────────────
# Cache the last string written to each label so we skip setText when unchanged.
var _last_start_text: String = ""
var _last_end_text: String = ""

var _scrub_handled_this_frame: bool = false

func _mark_dirty() -> void:
	_timeline_dirty = true

func startEdit(channel_id: String, start_time: float, value: bool) -> void:
	activeEdit[channel_id] = {"start": start_time, "value": value}
	_mark_dirty()

func endEdit(channel_id: String) -> void:
	activeEdit.erase(channel_id)
	_mark_dirty()

func getDataForChannel(channel_id: String) -> Array:
	var base: Array = master.currentlyLoadedFile["channels"][channel_id]["data"].duplicate()
	return base

func time_to_int(t: float) -> int:
	return int(t / (1.0 / 120.0))

func format_time(seconds: float) -> String:
	var h = int(seconds) / 3600
	var m = (int(seconds) % 3600) / 60
	var s = int(seconds) % 60
	return "%02d:%02d:%02d" % [h, m, s]

func setTimeFromTimeline(local_mouse_x: float, width: float) -> void:
	var t_ratio = clamp(local_mouse_x / width, 0.0, 1.0)
	
	timeCurrent = timeStart + t_ratio * (timeEnd - timeStart)
	
	currentTimeText.text = format_time(timeCurrent)
	_scrub_handled_this_frame = true

func _process(delta: float) -> void:
	_scrub_handled_this_frame = false
	if playing:
		setCurrentTime(delta)

	var t_range = timeEnd - timeStart
	if t_range > 0:
		var t_ratio = (timeCurrent - timeStart) / t_range
		
		var first_chan = _get_first_visible_channel()
		if first_chan:
			var data_area = first_chan.channelTimeline
			
			var start_gx = data_area.global_position.x
			var width_gx = data_area.size.x * data_area.get_global_transform().get_scale().x
			
			timelinePositionBar.global_position.x = start_gx + (t_ratio * width_gx)
			
			if activeEdit.size() > 0:
				for child in timelineBox.get_children():
					if child is GL_Channel and activeEdit.has(child.id):
						child.sync_preview_to_scrubber(t_ratio * data_area.size.x)

func _get_first_visible_channel() -> GL_Channel:
	for child in timelineBox.get_children():
		if child is GL_Channel and child.visible:
			return child
	return null
					
func _physics_process(delta: float) -> void:
	var s_text = format_time(timeStart)
	if s_text != _last_start_text:
		_last_start_text = s_text
		timeStartText.text = s_text

	var e_text = format_time(timeEnd)
	if e_text != _last_end_text:
		_last_end_text = e_text
		timeEndText.text = e_text

	if _timeline_dirty:
		_timeline_dirty = false
		repaintTimeline()
func setCurrentTime(delta: float) -> void:
	timeCurrent += delta
	
func togglePlayback():
	playing = !playing
	if playing:
		var playback = _get_playback()
		if playback:
			playback.prime_group_cache()

func _get_playback() -> GL_Playback:
	return master.get_node_or_null("GL_Playback")

func _input(event: InputEvent) -> void:
	if master.currentlyLoadedPath == "":
		return
	if is_visible_in_tree():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if event.ctrl_pressed:
					zoom(false)
				elif event.shift_pressed:
					pan(true)
				else:
					scroll(false)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if event.ctrl_pressed:
					zoom(true)
				elif event.shift_pressed:
					pan(false)
				else:
					scroll(true)
	if event.is_action_pressed("Toggle Play"):
		togglePlayback()

	if event is InputEventKey:
		for channel_id in master.currentlyLoadedFile["channels"]:
			var bind = channelBinds.get(channel_id, null)
			if bind == null:
				continue
			if event.keycode != bind:
				continue

			var ch_data = master.currentlyLoadedFile["channels"][channel_id]
			var type = GL_ChannelData.get_type(ch_data)

			if event.pressed and not event.echo:
				match type:
					GL_ChannelData.TYPE_BOOL:
						startEdit(channel_id, timeCurrent, true)
					GL_ChannelData.TYPE_FLOAT:
						startEdit(channel_id, timeCurrent, true)
					GL_ChannelData.TYPE_COLOR, GL_ChannelData.TYPE_AUDIO, GL_ChannelData.TYPE_VIDEO, \
					GL_ChannelData.TYPE_IMAGE, GL_ChannelData.TYPE_STRING:
						_commit_event(channel_id, type)

			elif not event.pressed:
				match type:
					GL_ChannelData.TYPE_BOOL:
						_commit_edit(channel_id)
					GL_ChannelData.TYPE_FLOAT:
						_commit_float(channel_id)

# ── Bool commit ───────────────────────────────────────────────────────────────

func _commit_edit(channel_id: String) -> void:
	if not activeEdit.has(channel_id):
		return
	var edit_start = activeEdit[channel_id]["start"]
	var range_start = min(edit_start, timeCurrent)
	var range_end = max(edit_start, timeCurrent)
	if range_end - range_start < (1.0 / 120.0):
		range_end = range_start + (1.0 / 120.0)

	var raw = master.currentlyLoadedFile["channels"][channel_id]["data"]
	var stamps: Array = raw if raw is Array else []
	var start_int = time_to_int(range_start)
	var end_int = time_to_int(range_end)

	var insert_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			insert_idx = i
			break
	var state_before: bool = insert_idx % 2 != 0
	var end_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] > end_int:
			end_idx = i
			break
	var state_after: bool = end_idx % 2 != 0
	for i in range(stamps.size() - 1, -1, -1):
		if stamps[i] >= start_int and stamps[i] <= end_int:
			stamps.remove_at(i)

	var ins = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			ins = i
			break

	if not state_before:
		stamps.insert(ins, start_int)
		ins += 1
	if not state_after:
		stamps.insert(ins, end_int)

	master.currentlyLoadedFile["channels"][channel_id]["data"] = stamps
	call_deferred("endEdit", channel_id)
	_mark_dirty()

# ── Float commit ──────────────────────────────────────────────────────────────

func _commit_float(channel_id: String) -> void:
	if not activeEdit.has(channel_id):
		return

	var edit_start = activeEdit[channel_id]["start"]
	var ch_data = master.currentlyLoadedFile["channels"][channel_id]
	
	# FIX: Get the live array directly, no decoding!
	var entries: Array = ch_data.get("data", [])

	var start_int = time_to_int(edit_start)
	var last_value = GL_ChannelData.get_float_at_time(entries, start_int - 1)
	var release_value = clamp(1.0 - last_value, 0.0, 1.0)

	var release_int = time_to_int(timeCurrent)
	if release_int <= start_int:
		release_int = start_int + 1

	entries = GL_ChannelData.insert_entry(entries, { "time": start_int, "value": last_value })
	entries = GL_ChannelData.insert_entry(entries, { "time": release_int, "value": release_value })

	# FIX: Save the array directly, no encoding!
	master.currentlyLoadedFile["channels"][channel_id]["data"] = entries
	_invalidate_playback_cache(channel_id)
	call_deferred("endEdit", channel_id)
	_mark_dirty()

# ── Event commit ──────────────────────────────────────────────────────────────

func _commit_event(channel_id: String, type: String) -> void:
	var ch_data = master.currentlyLoadedFile["channels"][channel_id]
	
	# FIX: Get the live array directly, no decoding!
	var entries: Array = ch_data.get("data", [])
	var t_int = time_to_int(timeCurrent)

	var entry: Dictionary
	match type:
		GL_ChannelData.TYPE_COLOR:
			entry = { "time": t_int, "color": Color.WHITE }
		GL_ChannelData.TYPE_AUDIO, GL_ChannelData.TYPE_VIDEO:
			entry = { "time": t_int, "file": "null", "offset": 0.0 }
		GL_ChannelData.TYPE_IMAGE:
			entry = { "time": t_int, "file": "null" }
		GL_ChannelData.TYPE_STRING:
			entry = { "time": t_int, "value": "null" }

	entries = GL_ChannelData.insert_entry(entries, entry)
	
	# FIX: Save the array directly, no encoding!
	master.currentlyLoadedFile["channels"][channel_id]["data"] = entries
	_invalidate_playback_cache(channel_id)
	_mark_dirty()
	
func _invalidate_playback_cache(channel_id: String) -> void:
	var playback = _get_playback()
	if playback:
		playback.invalidate_channel_cache(channel_id)

func updateTimelineBarX() -> void:
	if playing:
		var t = (timeCurrent - timeStart) / (timeEnd - timeStart)
		timelinePositionBar.position.x = channelXs + t * channelWidths
	else:
		timelinePositionBar.position.x = get_viewport().get_mouse_position().x

func zoom(out: bool):
	var mid = (timeStart + timeEnd) / 2.0
	var dist = timeEnd - timeStart
	var new_dist = dist * (zoomMultOut if out else zoomMultIn)
	new_dist = clamp(new_dist, zoomMin, zoomMax)
	timeStart = mid - new_dist / 2.0
	timeEnd = mid + new_dist / 2.0
	if timeStart < 0.0:
		timeEnd += -timeStart
		timeStart = 0.0
	_last_start_text = ""   # force label refresh after range change
	_last_end_text = ""
	_mark_dirty()

func pan(left: bool):
	var dist = timeEnd - timeStart
	var offset = dist * panAmount * (-1.0 if left else 1.0)
	timeStart += offset
	timeEnd += offset
	if timeStart < 0.0:
		timeEnd += -timeStart
		timeStart = 0.0
	_last_start_text = ""
	_last_end_text = ""
	_mark_dirty()

func scroll(down: bool):
	if master.currentlyLoadedPath == "":
		return
	var total = master.currentlyLoadedFile["channels"].size()
	if down:
		if scrolledIndex < total - 1:
			scrolledIndex += 1
	else:
		if scrolledIndex > 0:
			scrolledIndex -= 1
	_reassign_channel_slots()

func _get_sorted_keys() -> Array:
	var channels = master.currentlyLoadedFile["channels"]
	var sorted_keys = channels.keys()
	sorted_keys.sort_custom(func(a, b): return channels[a]["index"] < channels[b]["index"])
	return sorted_keys

func _get_channel_slots() -> Array:
	var slots = []
	for child in timelineBox.get_children():
		if child.name != "CreateChannel":
			slots.append(child)
	return slots

func _reassign_channel_slots() -> void:
	if master.currentlyLoadedPath == "":
		return

	await get_tree().process_frame

	var sorted_keys = _get_sorted_keys()
	var slots = _get_channel_slots()

	for i in range(slots.size()):
		var data_index = scrolledIndex + i
		if i >= slots.size(): break

		var slot : GL_Channel = slots[i]
		if data_index < sorted_keys.size():
			var key = sorted_keys[data_index]
			slot.id = key
			var color = master.currentlyLoadedFile["channels"][key].get("color", null)
			if color != null:
				var r = ("0x" + color.substr(0, 2)).hex_to_int() / 255.0
				var g = ("0x" + color.substr(2, 2)).hex_to_int() / 255.0
				var b = ("0x" + color.substr(4, 2)).hex_to_int() / 255.0
				slot.color = Color(r, g, b)
			slot.master = master
			slot.timeline = self
			slot.visible = true
			slot.start()
			slot.renderBits()
		else:
			slot.visible = false

func repaintTimeline() -> void:
	for child in timelineBox.get_children():
		if child.name != "CreateChannel" and child.visible:
			(child as GL_Channel).renderBits()

func _ready() -> void:
	reload_timeline()

func create_channel(type: int) -> void:
	var finished = false
	match(type):
		0:
			return
		1:
			finished = master.create_channel("bool")
			print("Creating Bool Channel")
		2:
			finished = master.create_channel("float")
			print("Creating Float Channel")
		3:
			finished = master.create_channel("color")
			print("Creating Color Channel")
		4:
			finished = master.create_channel("audio")
			print("Creating Audio Channel")
		5:
			finished = master.create_channel("video")
			print("Creating Video Channel")
		6:
			finished = master.create_channel("image")
			print("Creating Image Channel")
		7:
			finished = master.create_channel("string")
			print("Creating Text Channel")
	if finished:
		reload_timeline()
		createChannel.selected = 0
	else:
		print("Creating Channel Failed")

func reload_timeline() -> void:
	if master.currentlyLoadedPath == "":
		createChannel.visible = false
	else:
		createChannel.visible = true

	for child in timelineBox.get_children():
		if child.name != "CreateChannel":
			child.queue_free()

	if master.currentlyLoadedPath == "":
		return

	var total = master.currentlyLoadedFile["channels"].size()

	if scrolledIndex >= total:
		scrolledIndex = max(0, total - 1)

	var slots_needed = min(MAX_VISIBLE_CHANNELS, total)
	for i in range(slots_needed):
		var channelBox : GL_Channel = channelPrefab.instantiate()
		timelineBox.add_child(channelBox)

	timelineBox.move_child(timelineBox.get_node("CreateChannel"), timelineBox.get_child_count() - 1)

	# Prime the dispatch table now so first play-start has zero setup cost.
	# Deferred so group memberships are stable after the scene settles.
	call_deferred("_prime_playback_deferred")
	call_deferred("_reassign_channel_slots")

func _prime_playback_deferred() -> void:
	var playback = _get_playback()
	if playback:
		playback.prime_group_cache()
