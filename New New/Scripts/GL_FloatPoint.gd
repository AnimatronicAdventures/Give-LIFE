extends Panel
class_name GL_FloatPoint

# The entry this point represents: { "time": int, "value": float }
var entry: Dictionary = {}
var channel: GL_Channel

const POINT_SIZE = 10.0
const TIME_UNITS = 1.0 / 120.0

var _dragging = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_time_int: int = 0
var _drag_start_value: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(POINT_SIZE, POINT_SIZE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_delete_point()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_start_mouse = get_global_mouse_position()
				_drag_start_time_int = entry["time"]
				_drag_start_value = entry["value"]
			else:
				_dragging = false

	if event is InputEventMouseMotion and _dragging:
		_apply_drag()

func _apply_drag() -> void:
	var timeline = channel.timeline
	var holder = channel.channelTimeline
	var width = channel.channelTimeline.size.x
	var height = channel.channelTimeline.size.y
	var t_range = timeline.timeEnd - timeline.timeStart

	var mouse_now = get_global_mouse_position()
	var dx = mouse_now.x - _drag_start_mouse.x
	var dy = mouse_now.y - _drag_start_mouse.y

	# Time delta
	var dt_int = int((dx / width) * t_range / TIME_UNITS)
	var new_time_int = max(0, _drag_start_time_int + dt_int)

	# Value delta (Y inverted: top = 1.0, bottom = 0.0)
	var new_value = clamp(_drag_start_value - (dy / height), 0.0, 1.0)

	# Update entry in data
	var type = GL_ChannelData.get_type(channel.master.currentlyLoadedFile["channels"][channel.id])
	var entries: Array = GL_ChannelData.decode_entries(type, channel.master.currentlyLoadedFile["channels"][channel.id]["data"])

	# Remove old, insert updated
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	entry["time"] = new_time_int
	entry["value"] = new_value
	entries = GL_ChannelData.insert_entry(entries, entry.duplicate())

	channel.master.currentlyLoadedFile["channels"][channel.id]["data"] = GL_ChannelData.encode_entries(type, entries)
	channel.renderBits()

func _delete_point() -> void:
	var type = GL_ChannelData.get_type(channel.master.currentlyLoadedFile["channels"][channel.id])
	var entries: Array = GL_ChannelData.decode_entries(type, channel.master.currentlyLoadedFile["channels"][channel.id]["data"])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	channel.master.currentlyLoadedFile["channels"][channel.id]["data"] = GL_ChannelData.encode_entries(type, entries)
	channel.renderBits()
