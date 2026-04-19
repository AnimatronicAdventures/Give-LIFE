extends Panel
class_name GL_FloatPoint

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
	var flat_style = StyleBoxFlat.new()
	flat_style.set_border_width_all(0)
	add_theme_stylebox_override("panel", flat_style)

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
	var width = channel.channelTimeline.size.x
	var height = channel.channelTimeline.size.y
	var t_range = timeline.timeEnd - timeline.timeStart

	var mouse_now = get_global_mouse_position()
	var dx = mouse_now.x - _drag_start_mouse.x
	var dy = mouse_now.y - _drag_start_mouse.y

	var dt_int = int((dx / width) * t_range / TIME_UNITS)
	var new_time_int = max(0, _drag_start_time_int + dt_int)
	var new_value = clamp(_drag_start_value - (dy / height), 0.0, 1.0)
	var channel_dict = channel.master.currentlyLoadedFile["channels"][channel.id]
	var entries: Array = channel_dict.get("data", [])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	entry["time"] = new_time_int
	entry["value"] = new_value
	entries = GL_ChannelData.insert_entry(entries, entry.duplicate())
	channel_dict["data"] = entries
	channel.renderBits()

func _delete_point() -> void:
	var channel_dict = channel.master.currentlyLoadedFile["channels"][channel.id]
	var entries: Array = channel_dict.get("data", [])
	
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	channel_dict["data"] = entries
	channel.renderBits()
