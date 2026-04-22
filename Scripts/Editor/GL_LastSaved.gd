extends Label
class_name GL_LastSaved

@onready var master = $"../../../../../../Master"

func _process(_delta: float) -> void:
	if not visible:
		return
	if master.currentlyLoadedPath == "":
		text = ""
		return
	
	var last_saved_string = master.currentlyLoadedFile["lastUpdated"]
	var last_saved_unix = Time.get_unix_time_from_datetime_string(last_saved_string)
	var elapsed = Time.get_unix_time_from_system() - last_saved_unix
	
	if elapsed < 60:
		var seconds = int(elapsed)
		text = "Last saved %d second%s ago" % [seconds, "s" if seconds != 1 else ""]
	else:
		var minutes = int(elapsed / 60)
		text = "Last saved %d minute%s ago" % [minutes, "s" if minutes != 1 else ""]
