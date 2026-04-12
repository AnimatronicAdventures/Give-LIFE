extends Button
signal button_held

var _hold_timer: Timer

func _ready() -> void:
	_hold_timer = Timer.new()
	_hold_timer.wait_time = 0.8
	_hold_timer.one_shot = true
	_hold_timer.timeout.connect(_on_hold_complete)
	add_child(_hold_timer)

func _on_button_down() -> void:
	_hold_timer.start()
	print("Holding Button")

func _on_button_up() -> void:
	_hold_timer.stop()
	print("Stopped Button")

func _on_hold_complete() -> void:
	button_held.emit()
