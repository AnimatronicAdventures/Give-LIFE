extends Light3D
class_name NightLight

var timer := 0.0
var initial_energy := 0.0
var drain_count := 0
const TIMER_SPEED := 2
const lightChangeSpeed = 35

func _ready() -> void:
	await get_tree().process_frame
	var nm_group = get_tree().get_nodes_in_group("NightMaster")
	if nm_group.is_empty():
		queue_free()
		return
	initial_energy = light_energy

func _process(delta: float) -> void:
	timer = maxf(0, timer - delta * TIMER_SPEED)
	var setLight = light_energy
	if timer != 0:
		setLight = lerpf(initial_energy, 0, maxf(0, timer + randf_range(-0.1, 0.1)))
	elif drain_count > 0:
		setLight = initial_energy * randf_range(0.3, 0.6)
	else:
		setLight = initial_energy
	light_energy = lerp(light_energy,setLight,delta * lightChangeSpeed)

func flicker() -> void:
	timer = 1
	light_energy = 0

func drain_start() -> void:
	drain_count += 1

func drain_end() -> void:
	drain_count = maxi(0, drain_count - 1)
