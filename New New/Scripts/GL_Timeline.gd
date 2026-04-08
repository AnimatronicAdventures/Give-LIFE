extends Control
class_name GL_Timeline
@onready var master = $"../../Master"
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

func startEdit(channel_id: String, start_time: float, value: bool) -> void:
	activeEdit[channel_id] = {"start": start_time, "value": value}
	repaintTimeline()

func endEdit(channel_id: String) -> void:
	activeEdit.erase(channel_id)
	repaintTimeline()

func getDataForChannel(channel_id: String) -> Array:
	var base: Array = master.currentlyLoadedFile["channels"][channel_id]["data"].duplicate()
	if activeEdit.get("id", "") == channel_id:
		# Inject a preview stamp for the active edit
		var start_int = time_to_int(activeEdit["start"])
		var end_int = time_to_int(timeCurrent)
		# Just return the base data with the active range visible
		# Channel's renderBits will handle the preview panel separately
	return base

func time_to_int(t: float) -> int:
	return int(t / (1.0 / 120.0))

func format_time(seconds: float) -> String:
	var h = int(seconds) / 3600
	var m = (int(seconds) % 3600) / 60
	var s = int(seconds) % 60
	return "%02d:%02d:%02d" % [h, m, s]

func _process(delta: float) -> void:
	timeStartText.text = format_time(timeStart)
	timeEndText.text = format_time(timeEnd)
	if playing:
		setCurrentTime(delta)
	if activeEdit.size() > 0:
		repaintTimeline()

func setCurrentTime(delta: float) -> void:
	timeCurrent += delta
	currentTimeText.text = format_time(timeCurrent)
	updateTimelineBarX()
	
func setTimeFromTimeline(mouse: float,pos: float, width: float) -> void:
	channelXs = pos
	channelWidths = width
	timeCurrent = timeStart + clamp(mouse / width, 0.0, 1.0) * (timeEnd - timeStart)
	currentTimeText.text = format_time(timeCurrent)
	updateTimelineBarX()

func togglePlayback():
	playing = !playing

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
		for key in master.currentlyLoadedFile["channels"]:
			var bind = channelBinds.get(key, null)
			if bind == null:
				continue
			if event.keycode == bind:
				if event.pressed and not event.echo:
					startEdit(key, timeCurrent, true)
				elif not event.pressed:
					_commit_edit(key)

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
	repaintTimeline()

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
	repaintTimeline()

func pan(left: bool):
	var dist = timeEnd - timeStart
	var offset = dist * panAmount * (-1.0 if left else 1.0)
	timeStart += offset
	timeEnd += offset
	if timeStart < 0.0:
		timeEnd += -timeStart
		timeStart = 0.0
	repaintTimeline()

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

# Gets the sorted channel keys from master, same order as before
func _get_sorted_keys() -> Array:
	var channels = master.currentlyLoadedFile["channels"]
	var sorted_keys = channels.keys()
	sorted_keys.sort_custom(func(a, b): return channels[a]["index"] < channels[b]["index"])
	return sorted_keys

# Returns only the currently visible channel nodes (excludes CreateChannel)
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

	# Free all existing channel slots
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

	call_deferred("_reassign_channel_slots")
