extends CanvasItem

const FADE_SPEED     : float = 1
const FADE_IN_SPEED  : float = 5
const BRIGHTNESS_MIN : float = 0.5
const BRIGHTNESS_MAX : float = 1.0
const WAIT_MIN       : float = 1
const WAIT_MAX       : float = 5.0

@export var images: Array[Texture2D] = []

enum State { WAITING, FADING_IN, FADING_OUT }

var _state      : State = State.WAITING
var _brightness : float = 0.0
var _target     : float = 1.0
var _wait_timer : float = 0.0
var _mat        : ShaderMaterial
var _last_index : int   = -1

func _ready() -> void:
	_mat = material as ShaderMaterial
	_mat.set_shader_parameter("IMAGE_BRIGHTNESS", 0.0)
	_start_wait()

func _process(delta: float) -> void:
	match _state:
		State.WAITING:
			_wait_timer -= delta
			if _wait_timer <= 0.0:
				_pick_image()

		State.FADING_IN:
			_brightness = move_toward(_brightness, _target, FADE_IN_SPEED * delta)
			_mat.set_shader_parameter("IMAGE_BRIGHTNESS", _brightness)
			if abs(_brightness - _target) < 0.01:
				_state = State.FADING_OUT

		State.FADING_OUT:
			_brightness = move_toward(_brightness, 0.0, FADE_SPEED * delta)
			_mat.set_shader_parameter("IMAGE_BRIGHTNESS", _brightness)
			if _brightness <= 0.001:
				_brightness = 0.0
				_mat.set_shader_parameter("IMAGE_BRIGHTNESS", 0.0)
				_start_wait()

func _start_wait() -> void:
	_state = State.WAITING
	_wait_timer = randf_range(WAIT_MIN, WAIT_MAX)

func _pick_image() -> void:
	if images.is_empty():
		return
	var index := _last_index
	if images.size() > 1:
		while index == _last_index:
			index = randi() % images.size()
	else:
		index = 0
	_last_index = index
	_mat.set_shader_parameter("SOURCE_IMAGE", images[index])
	_target = randf_range(BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	_brightness = 0.0
	_state = State.FADING_IN
