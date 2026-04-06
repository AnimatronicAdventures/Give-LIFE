extends Node
class_name GL_Channel
@onready var title : LineEdit = $ChannelTimeline/title
@onready var bindLabel : Label = $"Bind/Bind Label"
@onready var channelTimeline : Control = $ChannelTimeline
@onready var bitHolder = $ChannelTimeline/BitHolder

var id = ""
var master : GL_Master
var timeline : GL_Timeline
var changingBind = false
var currentBind = null
var insideTimeline = false
var _bit_panels: Array = []

const timeUnits = 1.0 / 120.0
const bitColor = Color(0.4, 0.8, 1.0)

func start() -> void:
	title.text = id
	updateBindLabel()

func _process(delta: float) -> void:
	if insideTimeline && !timeline.playing:
		timeline.setTimeFromTimeline(channelTimeline.get_local_mouse_position().x,channelTimeline.position.x,channelTimeline.size.x)

func _input(event: InputEvent) -> void:
	if changingBind:
		if event is InputEventKey and event.pressed:
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				timeline.channelBinds[id] = event.keycode
			elif event.keycode == KEY_BACKSPACE:
				timeline.channelBinds.erase(id)
			updateBindLabel()


func time_to_int(t: float) -> int:
	return int(t / timeUnits)

func int_to_time(i: int) -> float:
	return i * timeUnits

func get_state_at_index(stamps: Array, idx: int) -> bool:
	return idx % 2 != 0

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
	if not has_node("ChannelTimeline/BitHolder/PreviewPanel"):
		var preview = Panel.new()
		preview.name = "PreviewPanel"
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 0.4, 0.5)
		preview.add_theme_stylebox_override("panel", style)
		bitHolder.add_child(preview)

	var preview_panel = bitHolder.get_node("PreviewPanel")
	if timeline.activeEdit.has(id):
		var edit = timeline.activeEdit[id]
		var seg_start = min(edit["start"], timeline.timeCurrent)
		var seg_end = max(edit["start"], timeline.timeCurrent)
		var cs = clamp(seg_start, t_start, t_end)
		var ce = clamp(seg_end, t_start, t_end)
		preview_panel.position = Vector2(((cs - t_start) / t_range) * width, 0)
		preview_panel.size = Vector2(max(((ce - cs) / t_range) * width, 1.0), bitHolder.size.y)
		preview_panel.visible = true
	else:
		preview_panel.visible = false

func updateBindLabel() -> void:
	var bind = timeline.channelBinds.get(id, null)
	if bind == null:
		bindLabel.text = "[   ]"
	else:
		bindLabel.text = OS.get_keycode_string(bind)

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
