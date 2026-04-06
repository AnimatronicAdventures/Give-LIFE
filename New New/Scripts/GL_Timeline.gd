extends Node
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

const zoomMultOut = 1.1
const zoomMultIn = 0.9
const zoomMin = 0.1
const zoomMax = 60
const panAmount = 0.1
const MAX_VISIBLE_CHANNELS = 10


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
	if master.currentlyLoadedPath != "":
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

func updateTimelineBarX() -> void:
	if playing:
		var t = (timeCurrent - timeStart) / (timeEnd - timeStart)
		timelinePositionBar.position.x = channelXs + t * channelWidths
	else:
		timelinePositionBar.position.x = get_viewport().get_mouse_position().x

func zoom(out: bool):
	if out:
		print("Zoomed Out")
	else:
		print("Zoomed In")
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
	if left:
		print("Panned Left")
	else:
		print("Panned Right")
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
			print("Scrolled Down to index: ", scrolledIndex)
	else:
		if scrolledIndex > 0:
			scrolledIndex -= 1
			print("Scrolled Up to index: ", scrolledIndex)
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

# Reconfigures existing channel node slots to display the correct channel data
# based on scrolledIndex. No nodes are created or destroyed.
func _reassign_channel_slots() -> void:
	if master.currentlyLoadedPath == "":
		return
	var sorted_keys = _get_sorted_keys()
	var slots = _get_channel_slots()
	for i in range(slots.size()):
		var data_index = scrolledIndex + i
		var slot : GL_Channel = slots[i]
		if data_index < sorted_keys.size():
			var key = sorted_keys[data_index]
			slot.id = key
			slot.master = master
			slot.timeline = self
			slot.visible = true
			slot.start()
		else:
			# No channel data for this slot, hide it
			slot.visible = false
	repaintTimeline()

# Only repaints bits on visible channels, no structural changes
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

# Only called when a file is loaded/unloaded or a channel is added/removed.
# Destroys and recreates exactly MAX_VISIBLE_CHANNELS slot nodes, then assigns data.
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

	# Clamp scroll so it never goes out of range after a reload
	if scrolledIndex >= total:
		scrolledIndex = max(0, total - 1)

	# Instantiate only as many slots as needed (up to MAX_VISIBLE_CHANNELS)
	var slots_needed = min(MAX_VISIBLE_CHANNELS, total)
	for i in range(slots_needed):
		var channelBox : GL_Channel = channelPrefab.instantiate()
		timelineBox.add_child(channelBox)
	
	# Always keep CreateChannel at the bottom
	timelineBox.move_child(timelineBox.get_node("CreateChannel"), timelineBox.get_child_count() - 1)

	# Assign the correct data to each slot
	_reassign_channel_slots()
