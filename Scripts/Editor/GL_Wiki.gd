extends Control

@onready var category_list: VBoxContainer = $"Mods/PanelContainer/HBoxContainer/VBoxContainer/ScrollContainer/Page Holder"
@onready var content_display: RichTextLabel = $"Mods/PanelContainer/HBoxContainer/MarginContainer/Mod Desc/MarginContainer/RichTextLabel"

const MODS_PATH := "res://Mods/"
const WIKI_FOLDER := "Wiki"

func _ready() -> void:
	content_display.bbcode_enabled = true

func initialize() -> void:
	_load_all_wikis()

func _load_all_wikis() -> void:
	for child in category_list.get_children():
		child.queue_free()

	var dir := DirAccess.open(MODS_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var mod_name := dir.get_next()
	while mod_name != "":
		if dir.current_is_dir() and not mod_name.begins_with("."):
			_load_mod_wiki(MODS_PATH + mod_name + "/Mod Directory/" + WIKI_FOLDER + "/")
		mod_name = dir.get_next()
	dir.list_dir_end()

func _load_mod_wiki(wiki_path: String) -> void:
	var dir := DirAccess.open(wiki_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_parse_wiki_file(wiki_path + file_name, file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

func _parse_wiki_file(path: String, category: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var pages: Dictionary = json.get_data()
	_build_category_ui(category, pages)

func _build_category_ui(category: String, pages: Dictionary) -> void:
	# Category label
	var label := Label.new()
	label.text = category
	label.add_theme_font_size_override("font_size", 16)
	category_list.add_child(label)

	# Separator
	var sep := HSeparator.new()
	category_list.add_child(sep)

	# Page buttons
	for page_name in pages:
		var btn := Button.new()
		btn.text = page_name
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_show_page.bind(pages[page_name]))
		category_list.add_child(btn)

	# Bottom spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	category_list.add_child(spacer)

func _show_page(content: String) -> void:
	content_display.text = content
