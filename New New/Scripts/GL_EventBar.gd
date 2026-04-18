extends Panel
class_name GL_EventBar

var entry: Dictionary = {}
var channel: GL_Channel
var entry_type: String = ""

const BAR_WIDTH = 6.0
const TIME_UNITS = 1.0 / 120.0

var _dragging = false
var _drag_start_mouse_x: float = 0.0
var _drag_start_time_int: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_delete_bar()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dragging = true
			_drag_start_mouse_x = get_global_mouse_position().x
			_drag_start_time_int = entry["time"]
			_open_edit_popup()

	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false

	if event is InputEventMouseMotion and _dragging:
		_apply_drag()

func _apply_drag() -> void:
	var timeline = channel.timeline
	var width = channel.channelTimeline.size.x
	var t_range = timeline.timeEnd - timeline.timeStart
	var dx = get_global_mouse_position().x - _drag_start_mouse_x
	var dt_int = int((dx / width) * t_range / TIME_UNITS)
	var new_time_int = max(0, _drag_start_time_int + dt_int)
	var entries: Array = GL_ChannelData.decode_entries(entry_type, channel.master.currentlyLoadedFile["channels"][channel.id]["data"])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	entry["time"] = new_time_int
	entries = GL_ChannelData.insert_entry(entries, entry.duplicate())
	channel.master.currentlyLoadedFile["channels"][channel.id]["data"] = GL_ChannelData.encode_entries(entry_type, entries)
	channel.renderBits()

func _delete_bar() -> void:
	var entries: Array = GL_ChannelData.decode_entries(entry_type, channel.master.currentlyLoadedFile["channels"][channel.id]["data"])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	channel.master.currentlyLoadedFile["channels"][channel.id]["data"] = GL_ChannelData.encode_entries(entry_type, entries)
	channel.renderBits()

func _open_edit_popup() -> void:
	if entry_type == GL_ChannelData.TYPE_COLOR:
		_open_color_picker()
		return

	var popup = Window.new()
	popup.title = entry_type.capitalize() + " Edit"
	popup.size = Vector2(300, 180)
	popup.unresizable = true
	popup.always_on_top = true
	get_tree().root.add_child(popup)
	popup.popup_centered()

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	popup.add_child(vbox)

	match entry_type:
		GL_ChannelData.TYPE_AUDIO, GL_ChannelData.TYPE_VIDEO:
			var audio_exts = ["mp3", "wav", "ogg"]
			var video_exts = ["mp4", "webm", "ogv"]
			var ext = audio_exts if entry_type == GL_ChannelData.TYPE_AUDIO else video_exts
			var files = _get_files_of_types(ext)
			var drop = OptionButton.new()
			drop.add_item("null")
			for f in files:
				drop.add_item(f)
			# Select current value
			var current_file = entry.get("file", "null")
			for i in range(drop.item_count):
				if drop.get_item_text(i) == current_file:
					drop.selected = i
					break
			vbox.add_child(drop)
			drop.item_selected.connect(func(idx: int):
				_update_entry_field("file", drop.get_item_text(idx))
			)
			var offset_label = Label.new()
			offset_label.text = "Offset (seconds):"
			vbox.add_child(offset_label)
			var offset_spin = SpinBox.new()
			offset_spin.min_value = 0.0
			offset_spin.max_value = 3600.0
			offset_spin.step = 0.01
			offset_spin.value = entry.get("offset", 0.0)
			vbox.add_child(offset_spin)
			offset_spin.value_changed.connect(func(v: float):
				_update_entry_field("offset", v)
			)

		GL_ChannelData.TYPE_IMAGE:
			var files = _get_files_of_types(["png", "jpg", "jpeg", "webp"])
			var drop = OptionButton.new()
			drop.add_item("null")
			for f in files:
				drop.add_item(f)
			var current_file = entry.get("file", "null")
			for i in range(drop.item_count):
				if drop.get_item_text(i) == current_file:
					drop.selected = i
					break
			vbox.add_child(drop)
			drop.item_selected.connect(func(idx: int):
				_update_entry_field("file", drop.get_item_text(idx))
			)

		GL_ChannelData.TYPE_STRING:
			var line = LineEdit.new()
			line.text = entry.get("value", "null")
			line.custom_minimum_size = Vector2(0, 32)
			vbox.add_child(line)
			line.text_submitted.connect(func(t: String):
				_update_entry_field("value", t)
				popup.queue_free()
			)

	var close_btn = Button.new()
	close_btn.text = "Close"
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func(): popup.queue_free())

func _open_color_picker() -> void:
	var popup = PopupPanel.new()
	popup.always_on_top = true
	get_tree().root.add_child(popup)
	var picker = ColorPicker.new()
	picker.color = entry.get("color", Color.WHITE)
	picker.custom_minimum_size = Vector2(400, 300)
	popup.add_child(picker)
	picker.color_changed.connect(func(c: Color):
		_update_entry_field("color", c)
	)
	popup.popup_centered()
	popup.popup_hide.connect(func():
		popup.queue_free()
	)

func _update_entry_field(field: String, value) -> void:
	var entries: Array = GL_ChannelData.decode_entries(entry_type, channel.master.currentlyLoadedFile["channels"][channel.id]["data"])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	entry[field] = value
	entries = GL_ChannelData.insert_entry(entries, entry.duplicate())
	channel.master.currentlyLoadedFile["channels"][channel.id]["data"] = GL_ChannelData.encode_entries(entry_type, entries)
	channel.renderBits()

func _get_files_of_types(extensions: Array) -> Array:
	var results = []
	var folder = ProjectSettings.globalize_path(channel.master.currentlyLoadedPath)
	var dir = DirAccess.open(folder)
	if not dir:
		# Fallback: try the path as-is
		dir = DirAccess.open(channel.master.currentlyLoadedPath)
		if not dir:
			return results
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			if f.get_extension().to_lower() in extensions:
				results.append(f)
		f = dir.get_next()
	return results
