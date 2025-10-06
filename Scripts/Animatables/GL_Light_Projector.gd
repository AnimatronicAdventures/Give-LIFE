extends GL_Animatable

var video_player: VideoStreamPlayer
var spot_light: SpotLight3D
var oldPath: String
@export var canChangeColor: bool = false
@export var energyMultiplier: float = 300
@export var lerp_speed: float = 5.0
var target_energy: float = 0.0

func _ready():
	spot_light = self.get_parent() as SpotLight3D
	if not spot_light:
		printerr("Parent must be a SpotLight3D for projector")
		return
	
	target_energy = spot_light.light_energy
	video_player = get_child(0) as VideoStreamPlayer
	if not video_player:
		printerr("First child must be a VideoStreamPlayer")
	
	set_process(true)

func _process(delta: float) -> void:
	# Smooth light energy
	spot_light.light_energy = lerp(spot_light.light_energy, target_energy, delta * lerp_speed)
	spot_light.visible = spot_light.light_energy > 0.0

	if video_player.stream:
		spot_light.light_projector = null
		spot_light.light_projector = video_player.get_video_texture()

func _sent_signals(anim_name: String, value):
	if not video_player:
		printerr("Can't find VideoPlayer, needs to be first child")
		return

	match anim_name:
		"Video":
			if value is GL_VideoType:
				var path = value.value
				if path != "" and path != oldPath:
					var stream: VideoStream = load(path)
					if stream and stream is VideoStream:
						video_player.stream = stream
						video_player.play()
						oldPath = path
					else:
						printerr("Invalid video stream at path: ", path)

		"Current Time":
			if video_player.stream:
				if abs(video_player.get_stream_position() - value) > 0.05:
					video_player.stream_position = value
					if not video_player.is_playing():
						video_player.play()

		"intensity":
			if typeof(value) == TYPE_BOOL:
				value = value * 1.0
			target_energy = max(value, 0.0) * energyMultiplier

		"color":
			if canChangeColor:
				spot_light.light_color = value
