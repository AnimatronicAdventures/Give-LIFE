extends MenuButton
@onready var modifier : GL_Master = $"../../../../../Master"
@onready var save_load : GL_SaveLoad = $"../../../../../Master/SaveLoad"

func _ready() -> void:
	save_load.xshw_load_bit_charts()
	var popup = get_popup()
	popup.clear()
	for chart_name in save_load._xshw_bit_charts.keys():
		popup.add_item(chart_name)
	popup.id_pressed.connect(_on_chart_selected)

func _on_chart_selected(id: int) -> void:
	var chart_name = get_popup().get_item_text(id)
	var file_dialog := FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.* ; All Files"]
	file_dialog.title = "Select a .shw file"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.file_selected.connect(func(path: String):
		file_dialog.queue_free()
		var save_root = save_load.xshw_convert_file(path, chart_name)
		if save_root != "":
			modifier._import_rr(save_root)
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	add_child(file_dialog)
	file_dialog.popup_centered_ratio()
