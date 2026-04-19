extends Panel
class_name GL_EventBar

var entry: Dictionary = {}
var channel: GL_Channel
var entry_type: String = ""

const BAR_WIDTH = 6.0
const TIME_UNITS = 1.0 / 120.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var flat_style = StyleBoxFlat.new()
	flat_style.set_border_width_all(0)
	add_theme_stylebox_override("panel", flat_style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_delete_bar()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_open_edit_popup()

func _delete_bar() -> void:
	var channel_dict = channel.master.currentlyLoadedFile["channels"][channel.id]
	var entries: Array = channel_dict.get("data", [])
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	channel_dict["data"] = entries
	channel.renderBits()



func _open_edit_popup() -> void:
	if entry_type == GL_ChannelData.TYPE_COLOR:
		_open_color_picker()
		return

	# ConfirmationDialog handles window focus and embedding much better than a raw Window
	var popup = ConfirmationDialog.new()
	popup.title = entry_type.capitalize() + " Edit"
	popup.get_ok_button().text = "Close"
	popup.get_cancel_button().visible = false
	
	popup.exclusive = true 
	popup.transient = true
	popup.popup_window = true
	
	get_tree().root.add_child(popup)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS 
	popup.add_child(vbox)

	match entry_type:
		GL_ChannelData.TYPE_AUDIO, GL_ChannelData.TYPE_VIDEO:
			var audio_exts = ["mp3", "wav", "ogg"]
			var video_exts = ["ogv"]
			var ext = audio_exts if entry_type == GL_ChannelData.TYPE_AUDIO else video_exts
			var files = _get_files_of_types(ext)
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

	popup.popup_centered(Vector2(300, 180))
	popup.confirmed.connect(func(): popup.queue_free())
	popup.canceled.connect(func(): popup.queue_free())

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
	var channel_dict = channel.master.currentlyLoadedFile["channels"][channel.id]
	var entries: Array = channel_dict.get("data", [])
	
	entries = GL_ChannelData.remove_entry_at_time(entries, entry["time"])
	entry[field] = value
	entries = GL_ChannelData.insert_entry(entries, entry.duplicate())
	channel_dict["data"] = entries
	channel.renderBits()

func _get_files_of_types(extensions: Array) -> Array:
	var results = []
	var raw_path = channel.master.currentlyLoadedPath
	var glob_path = ProjectSettings.globalize_path(raw_path)
	
	var dir = DirAccess.open(raw_path)
	if not dir:
		dir = DirAccess.open(glob_path)
		if not dir:
			return results
			
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			if f.get_extension().to_lower() in extensions:
				results.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return results
