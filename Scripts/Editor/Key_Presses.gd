extends Control

const MAX_KEYS := 10
const DISPLAY_TIME := 2.0

var key_display_timer: Dictionary = {}
var recent_keys: Array[String] = []
var key_labels: Array[Label] = []

var key_lookup: Dictionary = {
	"A": KEY_A,
	"B": KEY_B,
	"C": KEY_C,
	"D": KEY_D,
	"E": KEY_E,
	"F": KEY_F,
	"G": KEY_G,
	"H": KEY_H,
	"I": KEY_I,
	"J": KEY_J,
	"K": KEY_K,
	"L": KEY_L,
	"M": KEY_M,
	"N": KEY_N,
	"O": KEY_O,
	"P": KEY_P,
	"Q": KEY_Q,
	"R": KEY_R,
	"S": KEY_S,
	"T": KEY_T,
	"U": KEY_U,
	"V": KEY_V,
	"W": KEY_W,
	"X": KEY_X,
	"Y": KEY_Y,
	"Z": KEY_Z,
	
	"0": KEY_0,
	"1": KEY_1,
	"2": KEY_2,
	"3": KEY_3,
	"4": KEY_4,
	"5": KEY_5,
	"6": KEY_6,
	"7": KEY_7,
	"8": KEY_8,
	"9": KEY_9,
	
	"Space": KEY_SPACE,
	"Shift": KEY_SHIFT,
	"Ctrl": KEY_CTRL,
	"Alt": KEY_ALT,
	"Up": KEY_UP,
	"Down": KEY_DOWN,
	"Left": KEY_LEFT,
	"Right": KEY_RIGHT,

	"Enter": KEY_ENTER,
	"Backspace": KEY_BACKSPACE,
	"Tab": KEY_TAB,
	"Escape": KEY_ESCAPE,

	"Minus": KEY_MINUS,
	"Equal": KEY_EQUAL,
	"BracketLeft": KEY_BRACKETLEFT,
	"BracketRight": KEY_BRACKETRIGHT,
	"Semicolon": KEY_SEMICOLON,
	"Comma": KEY_COMMA,
	"Period": KEY_PERIOD,
	"Slash": KEY_SLASH,
	"Backslash": KEY_BACKSLASH,
}

var enabled: bool = false
var fpsenabled: bool = false
@export var fps: Label

func _ready():
	add_to_group("SettingsReceivers")
	create_key_labels()

func on_settings_applied(settings: Dictionary) -> void:
	enabled = settings.get("show_key_presses", false)
	fpsenabled = settings.get("show_fps", false)
	visible = enabled
	fps.visible = fpsenabled

func create_key_labels() -> void:
	for i in MAX_KEYS:
		var label: Label = Label.new()
		label.text = ""
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.modulate.a = 0.0
		add_child(label)
		key_labels.append(label)

func _process(delta: float) -> void:
	if not enabled:
		return

	for key: String in recent_keys.duplicate():
		key_display_timer[key] -= delta
		if key_display_timer[key] <= 0.0:
			recent_keys.erase(key)
			key_display_timer.erase(key)

	update_key_display()

func _input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_name: String = OS.get_keycode_string(event.physical_keycode)
		if not recent_keys.has(key_name):
			recent_keys.push_front(key_name)
			if recent_keys.size() > MAX_KEYS:
				var removed: String = recent_keys.pop_back()
				key_display_timer.erase(removed)
		key_display_timer[key_name] = DISPLAY_TIME

func update_key_display() -> void:
	for i in MAX_KEYS:
		var label: Label = key_labels[i]
		if i < recent_keys.size():
			var key: String = recent_keys[i]
			label.text = key
			var keycode: int = key_lookup.get(key, -1)
			var still_pressed: bool = keycode != -1 and Input.is_physical_key_pressed(keycode)
			label.modulate.a = 1.0 if still_pressed else 0.5
		else:
			label.text = ""
			label.modulate.a = 0.0
