extends Node
class_name GL_Channel
@onready var title : LineEdit = $ChannelTimeline/title
@onready var bindLabel : Label = $"Bind/Bind Label"
@onready var channelTimeline = $ChannelTimeline
@onready var bitHolder = $ChannelTimeline/BitHolder

var id = ""
var master : GL_Master
var timeline : GL_Timeline
var changingBind = false
var currentBind = null
var insideTimeline = false
var editStart = null
var _bit_panels: Array = []

const timeUnits = 1.0 / 120.0
const bitColor = Color(0.4, 0.8, 1.0)

func start() -> void:
	title.text = id
	updateBindLabel()

func _process(delta: float) -> void:
	if insideTimeline:
		timeline.updateTimelineBarX()
		timeline.setCurrentTime(clamp(channelTimeline.get_local_mouse_position().x / channelTimeline.size.x, 0.0, 1.0))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == currentBind:
			if event.pressed:
				bindPressed()
			else:
				bindReleased()
	if changingBind:
		if event is InputEventKey and event.pressed:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				currentBind = event.keycode
			elif event.keycode == KEY_BACKSPACE:
				currentBind = null
			updateBindLabel()

func bindPressed() -> void:
	editStart = timeline.timeCurrent

func time_to_int(t: float) -> int:
	return int(t / timeUnits)

func int_to_time(i: int) -> float:
	return i * timeUnits

func get_state_at_index(stamps: Array, idx: int) -> bool:
	return idx % 2 != 0

func bindReleased(force_on: bool = true) -> void:
	if editStart == null:
		return
	var range_start = min(editStart, timeline.timeCurrent)
	var range_end = max(editStart, timeline.timeCurrent)
	editStart = null
	if range_end - range_start < timeUnits:
		range_end = range_start + timeUnits

	var raw = master.currentlyLoadedFile["channels"][id]["data"]
	var stamps: Array = raw if raw is Array else []

	var start_int = time_to_int(range_start)
	var end_int   = time_to_int(range_end)

	var insert_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			insert_idx = i
			break
	var state_before_range: bool = get_state_at_index(stamps, insert_idx)

	var end_idx = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] > end_int:
			end_idx = i
			break
	var state_after_range: bool = get_state_at_index(stamps, end_idx)

	for i in range(stamps.size() - 1, -1, -1):
		if stamps[i] >= start_int and stamps[i] <= end_int:
			stamps.remove_at(i)

	var ins = stamps.size()
	for i in range(stamps.size()):
		if stamps[i] >= start_int:
			ins = i
			break

	var desired_state: bool = force_on
	if state_before_range != desired_state:
		stamps.insert(ins, start_int)
		ins += 1
	if state_after_range != desired_state:
		stamps.insert(ins, end_int)

	master.currentlyLoadedFile["channels"][id]["data"] = stamps
	master.save()
	renderBits()

func renderBits() -> void:
	var stamps: Array = master.currentlyLoadedFile["channels"][id]["data"]
	var width: float = bitHolder.size.x
	var t_start: float = timeline.timeStart
	var t_end: float = timeline.timeEnd
	var t_range: float = t_end - t_start

	var segments: Array = []
	var state = false
	var seg_start_time = 0.0

	for i in range(stamps.size()):
		var t = int_to_time(stamps[i])
		if not state:
			seg_start_time = t
			state = true
		else:
			var seg_end_time = t
			if seg_end_time > t_start and seg_start_time < t_end:
				segments.append([seg_start_time, seg_end_time])
			state = false

	if state and seg_start_time < t_end:
		segments.append([seg_start_time, t_end])

	var needed = segments.size()
	while _bit_panels.size() < needed:
		var panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = bitColor
		panel.add_theme_stylebox_override("panel", style)
		bitHolder.add_child(panel)
		_bit_panels.append(panel)
	while _bit_panels.size() > needed:
		var panel = _bit_panels.pop_back()
		panel.queue_free()

	for i in range(needed):
		var seg = segments[i]
		var clamped_start = clamp(seg[0], t_start, t_end)
		var clamped_end = clamp(seg[1], t_start, t_end)
		var x = ((clamped_start - t_start) / t_range) * width
		var w = ((clamped_end - clamped_start) / t_range) * width
		_bit_panels[i].position = Vector2(x, 0)
		_bit_panels[i].size = Vector2(max(w, 1.0), bitHolder.size.y)

func updateBindLabel() -> void:
	if currentBind == null:
		bindLabel.text = "[   ]"
	else:
		bindLabel.text = str(currentBind)

func _on_title_text_submitted(new_text: String) -> void:
	var final_text = new_text
	while true:
		var found = false
		for key in master.currentlyLoadedFile["channels"]:
			if key == final_text:
				found = true
				break
		if found:
			final_text += " (copy)"
		else:
			break
	master.currentlyLoadedFile["channels"][final_text] = master.currentlyLoadedFile["channels"][id]
	master.currentlyLoadedFile["channels"].erase(id)
	id = final_text
	master.save()

func _on_title_focus_exited() -> void:
	title.text = id

func binder_entered() -> void:
	changingBind = true

func binder_exited() -> void:
	changingBind = false

func timelineEntered() -> void:
	insideTimeline = true

func timelineExited() -> void:
	insideTimeline = false
