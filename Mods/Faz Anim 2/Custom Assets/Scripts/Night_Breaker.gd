extends Area3D
class_name Night_Breaker

@export var door_open_curve: Curve
@export var door_close_curve: Curve
@export var switch_close_curve: Curve
@onready var skeleton = $"../Breaker Panel/Armature/Skeleton3D"

const OPEN_ANIM_TIME := 0.8
const CLOSE_ANIM_TIME := 0.4
const SWITCH_CLOSE_TIME := 0.1
const DOOR_ANGLES := [0.0, 145.0]
const SWITCH_ANGLES := [50.0, 0.0]
const SWITCH_ALT_ANGLES := [-50.0, 0.0]
const ALT_SWITCHES: Array = [1, 4, 5, 7, 10, 11]
const SWITCH_COUNT := 12
const PAIRED_SWITCHES := {2:3, 4:5, 8:9, 10:11}
const SOUND_PATH := "res://Mods/Faz Anim 2/Custom Assets/Sounds/"
const DOOR_OPEN_SOUNDS := 10
const DOOR_CLOSE_SOUNDS := 11
const SWITCH_SOUNDS := 15

var door_bone_idx: int
var switch_bone_indices: Array = []
var switch_states: Array = []
var is_open := false
var is_animating := false
var is_switch_animating := false
var panel_ready_to_close := false
var is_manipulated := false
var night_master = null
var player: Player
var speaker: AudioStreamPlayer3D


func _ready() -> void:
	speaker = AudioStreamPlayer3D.new()
	add_child(speaker)
	door_bone_idx = skeleton.find_bone("Door")
	for i in SWITCH_COUNT:
		switch_bone_indices.append(skeleton.find_bone("Switch %d" % i))
	var nm_group = get_tree().get_nodes_in_group("NightMaster")
	night_master = nm_group[0] if nm_group.size() > 0 else null
	switch_states.assign(range(SWITCH_COUNT).map(func(_i): return false))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not is_animating and is_open:
		_handle_space_press()

func _play_sound(prefix: String, count: int) -> void:
	var path = SOUND_PATH + prefix + str(randi() % count) + ".mp3"
	speaker.stream = load(path)
	speaker.play()

func interact() -> void:
	if is_manipulated or is_animating:
		return
	if not is_open:
		animate_door(true)
		panel_ready_to_close = night_master == null or _all_switches_closed()
	elif panel_ready_to_close or _all_switches_closed():
		animate_door(false)

func _handle_space_press() -> void:
	if is_switch_animating or is_manipulated:
		return
	if panel_ready_to_close or _all_switches_closed():
		animate_door(false)
		return
	for i in SWITCH_COUNT:
		if switch_states[i]:
			animate_switch(i)
			if PAIRED_SWITCHES.has(i) and randf() < 0.5:
				animate_switch(PAIRED_SWITCHES[i])
			break

func manipulate_start() -> void:
	is_manipulated = true
	check_player()
	for i in SWITCH_COUNT:
		switch_states[i] = true
		_set_switch_rotation(i, 1.0)
	var was_frozen = player != null and player.frozen_mode
	if not is_open:
		animate_door(true)
		await animation_done
	if was_frozen:
		player.unfreeze_player()

func check_player():
	if player == null:
		player = get_tree().get_first_node_in_group("Player")

func manipulate_end() -> void:
	animate_door(false)
	await animation_done
	is_manipulated = false

func animate_door(opening: bool) -> void:
	is_animating = true
	check_player()
	if opening:
		_play_sound("BreakerOpen", DOOR_OPEN_SOUNDS)
		if not is_manipulated:
			player.freeze_player()
	var tween = create_tween()
	tween.tween_method(_set_door_rotation, 1.0 - float(opening), float(opening),
		OPEN_ANIM_TIME if opening else CLOSE_ANIM_TIME)
	tween.tween_callback(func():
		is_open = opening
		is_animating = false
		if not is_open:
			_play_sound("BreakerClose", DOOR_CLOSE_SOUNDS)
			panel_ready_to_close = false
			if not is_manipulated:
				player.unfreeze_player()
		animation_done.emit()
	)

signal animation_done

func _animation_done():
	if not is_animating:
		return
	await animation_done

func animate_switch(idx: int) -> void:
	is_switch_animating = true
	_play_sound("Breaker", SWITCH_SOUNDS)
	var tween = create_tween()
	tween.tween_method(func(t): _set_switch_rotation(idx, t), 1.0, 0.0, SWITCH_CLOSE_TIME)
	tween.tween_callback(func():
		switch_states[idx] = false
		is_switch_animating = false
		if _all_switches_closed():
			animate_door(false)
	)

func _all_switches_closed() -> bool:
	return not switch_states.any(func(s): return s)

func _set_door_rotation(t: float) -> void:
	var angle = lerp(DOOR_ANGLES[0], DOOR_ANGLES[1],
		(door_open_curve if not is_open else door_close_curve).sample(t))
	_apply_bone_rotation(door_bone_idx, angle)

func _set_switch_rotation(idx: int, t: float) -> void:
	var angles = SWITCH_ALT_ANGLES if idx in ALT_SWITCHES else SWITCH_ANGLES
	var angle = lerp(angles[0], angles[1], switch_close_curve.sample(t))
	_apply_bone_rotation(switch_bone_indices[idx], angle)

func _apply_bone_rotation(bone_idx: int, angle: float) -> void:
	var rest = skeleton.get_bone_rest(bone_idx)
	skeleton.set_bone_pose_rotation(bone_idx,
		rest.basis.get_rotation_quaternion() * Quaternion(rest.basis.y.normalized(), deg_to_rad(angle)))
