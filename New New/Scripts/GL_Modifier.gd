extends Node
@onready var master : GL_Master = $"../Master"
@onready var saveLoad : GL_SaveLoad = $"../Master/SaveLoad"
@onready var fullEditor : Control = $"../Full Editor"
@onready var timeline : GL_Timeline = $"../Full Editor/Data Timeline"
@onready var titleVar : LineEdit = $"../Full Editor/Editor/Modifiers/Settings/MarginContainer/VBoxContainer/Title/LineEdit"
@onready var authorVar : LineEdit = $"../Full Editor/Editor/Modifiers/Settings/MarginContainer/VBoxContainer/Author/LineEdit"
@onready var createdVar : Label = $"../Full Editor/Editor/Modifiers/Settings/MarginContainer/VBoxContainer/Created/Label2"

const defaultShowName = "My Unnamed Show"

func _ready() -> void:
	self.visible = true
	fullEditor.visible = false

func _create_new_show():
	var path = saveLoad.generate_savefile(defaultShowName)
	if path != "":
		if master.load_show(path):
			_load_settings_general()
			timeline.reload_timeline()

func _load_settings_general() -> void:
	self.visible = false
	fullEditor.visible = true
	titleVar.text = master.currentlyLoadedFile.get("title")
	authorVar.text = master.currentlyLoadedFile.get("author")
	createdVar.text = master.currentlyLoadedFile.get("timeCreated")
