extends SubViewportContainer

@export var look_speed: float = 0.005
@export var move_speed: float = 5.0
@onready var freecam = $SubViewport/Camera3D
@onready var viewport: SubViewport = $SubViewport
var is_hovering: bool = false
var rotation_target: Vector3 = Vector3.ZERO

func _ready():
	self.mouse_entered.connect(func(): is_hovering = true)
	self.mouse_exited.connect(func(): is_hovering = false)

func _process(delta):
	if is_hovering:
		handle_movement(delta)

func handle_movement(delta):
	var input_dir = Input.get_vector("Move Left", "Move Right", "Move Forward", "Move Backward")
	var direction = (freecam.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	freecam.global_position += direction * move_speed * delta

func _input(event):
	if is_hovering:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			rotation_target.y -= event.relative.x * look_speed
			rotation_target.x -= event.relative.y * look_speed
			rotation_target.x = clamp(rotation_target.x, -deg_to_rad(85), deg_to_rad(85))
			freecam.rotation = rotation_target
