extends Node

@export var hover_sound: AudioStream
@export var hover_pitch_randomize_enabled: bool = true
@export var hover_pitch_multiplier: float = 1.0    # base multiplier for hover pitch

@export var press_sound: AudioStream
@export var press_pitch_randomize_enabled: bool = true
@export var press_pitch_multiplier_on: float = 1.0   # base multiplier for press toggle ON
@export var press_pitch_multiplier_off: float = 1.0  # base multiplier for press toggle OFF

var pitch_variations: Array = [1.1,0.9,1.0,1.0,1.0,0.9,1.0]          # shared pitch multiplier array for hover & press

@export var audio_player_path: NodePath

var player_ref: AudioStreamPlayer2D

var pitch_index := 0

func _ready():
	if audio_player_path != NodePath():
		player_ref = get_node(audio_player_path)
	else:
		push_error("No audio player assigned for UISoundHelper.")
		
	if has_signal("tab_hovered"):
		connect("tab_hovered", on_tab_hover)
	elif has_signal("mouse_entered"):
		connect("mouse_entered", _on_hover)
		
	if has_signal("focus_entered"):
		connect("focus_entered", _on_hover)
	elif has_signal("item_focused"):
		connect("item_focused", _on_hover)
	
	if has_signal("toggled"):
		connect("toggled", _on_press)
	elif has_signal("pressed"):
		connect("pressed", _on_pressed_button)
	elif has_signal("value_changed"):
		connect("value_changed", _on_press)
	elif has_signal("item_selected"):
		connect("item_selected", _on_press)
	elif has_signal("text_changed"):
		connect("text_changed", _on_changed_text)
	elif has_signal("tab_clicked"):
		connect("tab_clicked", on_tab_click)

func _on_hover():
	if hover_sound and player_ref:
		player_ref.stop()
		player_ref.stream = hover_sound
		var pitch = hover_pitch_multiplier
		if hover_pitch_randomize_enabled and pitch_variations.size() > 0:
			pitch *= _get_next_pitch()
		player_ref.pitch_scale = pitch	
		player_ref.play()

func _on_changed_text(_unused:String):
	_on_press(false)

func on_tab_click(_unused:int):
	_on_press(false)
	
func on_tab_hover(_unused:int):
	_on_hover()

func _on_pressed_button():
	_on_press(false)
	
func _on_press(toggled_state: bool = false):
	if press_sound and player_ref:
		player_ref.stop()
		player_ref.stream = press_sound
		var base_multiplier = press_pitch_multiplier_on if toggled_state else press_pitch_multiplier_off
		var pitch = base_multiplier
		if press_pitch_randomize_enabled and pitch_variations.size() > 0:
			pitch *= _get_next_pitch()
		player_ref.pitch_scale = pitch
		player_ref.play()


func _get_next_pitch() -> float:
	var pitch = pitch_variations[pitch_index]
	pitch_index = (pitch_index + 1) % pitch_variations.size()
	return pitch
