extends Node3D

@export var drain_range := 10.0
@export var check_interval := 0.5

var _lights: Array = []
var _active_drains: Array = []
var _timer := 0.0

func _ready() -> void:
	_lights = get_tree().get_nodes_in_group("NightLight")

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0:
		return
	_timer = check_interval
	_check_lights()
	
func _check_lights() -> void:
	var range_sq = drain_range * drain_range
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var in_range = light.global_position.distance_squared_to(global_position) <= range_sq
		var was_draining = light in _active_drains
		if in_range and not was_draining:
			_active_drains.append(light)
			light.drain_start()
		elif not in_range and was_draining:
			_active_drains.erase(light)
			light.drain_end()
