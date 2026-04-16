extends Label
class_name NightTimer

var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	var total_minutes = int(_elapsed)
	var hours = (total_minutes / 60 + 12) % 12
	if hours == 0: 
		hours = 12
	text = "%d:%02d AM" % [hours, total_minutes % 60]
	if total_minutes >= 360:
		reset()

func reset():
	var new_scene_res = load("res://Mods/Faz Anim 2/Custom Assets/Night/FDs Night/FDs Night.tscn")
	var new_scene = new_scene_res.instantiate()
	var root = get_tree().root
	root.add_child(new_scene)
	get_tree().current_scene = new_scene
	for child in root.get_children():
		if child != new_scene:
			child.queue_free()
