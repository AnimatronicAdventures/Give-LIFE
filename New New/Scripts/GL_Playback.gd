extends Node

func _process(_delta):
	for node in get_tree().get_nodes_in_group("Animatables"):
		if node is GL_Animatable:
			for key in currentlyLoadedFile["channels"]:
				node._sent_signals(key,1)

func get_bool_state_at_time(channel_data: Dictionary, current_time: float) -> bool:
	var stamps: Array = _parse_stamps(channel_data["data"])
	if stamps.is_empty():
		return false
 
	var current_time_int: int = _time_to_int(current_time)
 
	# Binary search for the rightmost stamp <= current_time_int
	var lo: int = 0
	var hi: int = stamps.size() - 1
	var result_idx: int = -1
 
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		if stamps[mid] <= current_time_int:
			result_idx = mid   # This stamp qualifies; keep searching right for a closer one
			lo = mid + 1
		else:
			hi = mid - 1
 
	# No stamp exists at or before current_time — state is false (never toggled on)
	if result_idx == -1:
		return false
 
	# State flips each stamp: even index = false, odd index = true
	return result_idx % 2 != 0
