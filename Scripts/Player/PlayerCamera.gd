extends Camera3D

func _ready() -> void:
	add_to_group("cameras")
	refresh()

func refresh() -> void:
	var vp = get_viewport()
	if not vp:
		return
	var config := ConfigFile.new()
	if config.load("user://Settings/user_settings.cfg") != OK:
		return
	vp.msaa_3d = config.get_value("settings", "msaa_3d", vp.msaa_3d)
	match config.get_value("settings", "scale_mode", 0):
		0: vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1: vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		2: vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	vp.scaling_3d_scale = config.get_value("settings", "render_scale", 1.0)
	fov = config.get_value("settings", "fov", 75.0)
