extends Panel
class_name GL_BitPanel

const EDGE_WIDTH = 8
const TIME_UNITS = 1.0 / 120.0

enum DragMode { NONE, MOVE, LEFT_EDGE, RIGHT_EDGE }

var channel: GL_Channel
var _open_stamp: int = -1

var _drag_mode: DragMode = DragMode.NONE
var _drag_start_mouse_x: float = 0.0
var _drag_open_idx: int = -1
var _drag_start_seg_start_int: int = 0
var _drag_start_seg_end_int: int = 0
var _drag_accum: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _get_stamps() -> Array:
	return channel.master.currentlyLoadedFile["channels"][channel.id]["data"]

func _time_to_int(t: float) -> int:
	return int(t / TIME_UNITS)

func _pixels_to_int(px: float) -> float:
	var timeline = channel.timeline
	var width = channel.channelTimeline.size.x
	return (px / width) * (timeline.timeEnd - timeline.timeStart) / TIME_UNITS


func _get_actual_open_idx() -> int:
	if _open_stamp == -1:
		return -1
	var stamps = _get_stamps()
	return stamps.find(_open_stamp)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_delete_segment()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_open_idx = _get_actual_open_idx()
				if _drag_open_idx == -1:
					return
				var stamps = _get_stamps()
				_drag_mode = _get_drag_mode(event.position.x)
				_drag_start_mouse_x = get_global_mouse_position().x
				_drag_accum = 0.0
				_drag_start_seg_start_int = stamps[_drag_open_idx]
				_drag_start_seg_end_int = stamps[_drag_open_idx + 1]
			else:
				if _drag_mode != DragMode.NONE:
					_drag_mode = DragMode.NONE

	if event is InputEventMouseMotion and _drag_mode != DragMode.NONE:
		var dx = get_global_mouse_position().x - _drag_start_mouse_x
		_drag_accum = _pixels_to_int(dx)
		_apply_drag()

func _get_drag_mode(local_x: float) -> DragMode:
	if local_x <= EDGE_WIDTH:
		return DragMode.LEFT_EDGE
	if local_x >= size.x - EDGE_WIDTH:
		return DragMode.RIGHT_EDGE
	return DragMode.MOVE

func _delete_segment() -> void:
	var open_idx = _get_actual_open_idx()
	if open_idx == -1:
		return
	var stamps = _get_stamps()
	stamps.remove_at(open_idx + 1)
	stamps.remove_at(open_idx)
	channel.renderBits()
	channel.master.playback.clean_sweep()

func _apply_drag() -> void:
	if _drag_open_idx == -1:
		return
	var stamps = _get_stamps()
	var delta_int = int(_drag_accum)
	if delta_int == 0:
		return
	var open_idx = _drag_open_idx
	var close_idx = open_idx + 1
	var seg_len = _drag_start_seg_end_int - _drag_start_seg_start_int

	match _drag_mode:
		DragMode.MOVE:
			var new_start = max(0, _drag_start_seg_start_int + delta_int)
			var new_end = new_start + seg_len
			if open_idx - 1 >= 0:
				if new_start <= stamps[open_idx - 1]:
					new_start = stamps[open_idx - 1] + 1
					new_end = new_start + seg_len
			if close_idx + 1 < stamps.size():
				if new_end >= stamps[close_idx + 1]:
					new_end = stamps[close_idx + 1] - 1
					new_start = new_end - seg_len
			new_start = max(0, new_start)
			new_end = new_start + seg_len
			stamps[open_idx] = new_start
			stamps[close_idx] = new_end

		DragMode.LEFT_EDGE:
			var new_start = max(0, _drag_start_seg_start_int + delta_int)
			new_start = min(new_start, stamps[close_idx] - 1)
			if open_idx - 1 >= 0 and new_start <= stamps[open_idx - 1]:
				var merged_start = stamps[open_idx - 2] if open_idx >= 2 else 0
				stamps.remove_at(open_idx)
				stamps.remove_at(open_idx - 1)
				_drag_open_idx -= 2
				stamps[_drag_open_idx] = merged_start
				_drag_mode = DragMode.NONE
				channel.renderBits()
				return
			stamps[open_idx] = new_start

		DragMode.RIGHT_EDGE:
			var new_end = max(_drag_start_seg_end_int + delta_int, stamps[open_idx] + 1)
			if close_idx + 1 < stamps.size() and new_end >= stamps[close_idx + 1]:
				var merged_end = stamps[close_idx + 2] if close_idx + 2 < stamps.size() else new_end
				stamps.remove_at(close_idx + 1)
				stamps.remove_at(close_idx)
				stamps[_drag_open_idx + 1] = merged_end
				_drag_mode = DragMode.NONE
				channel.renderBits()
				return
			stamps[close_idx] = new_end

	channel.renderBits()
