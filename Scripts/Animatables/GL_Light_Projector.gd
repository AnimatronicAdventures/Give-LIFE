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
	spot_light.light_energy = lerp(spot_light.light_energy, target_energy, delta * lerp_speed)
	spot_light.visible = spot_light.light_energy > 0.0
	if video_player.stream:
		spot_light.light_projector = null
		spot_light.light_projector = video_player.get_video_texture()

func _sent_signals(anim_name: String, value):
	anim_name = anim_name.split("|", true, 1)[-1]
	if not video_player:
		printerr("Can't find VideoPlayer, needs to be first child")
		return
	match anim_name:
		"Video":
			# null means playback ended/destroyed — reset
			if value == null:
				video_player.stop()
				video_player.stream = null
				spot_light.light_projector = null
				oldPath = ""
				return
			var path: String = str(value)
			if path == "null" or path == "":
				return
			if path != oldPath:
				# Godot 4's load() does not work on arbitrary absolute paths for
				# VideoStream. We must create the stream object manually.
				var stream: VideoStream = null
				var ext = path.get_extension().to_lower()
				match ext:
					"ogv", "ogg":
						stream = VideoStreamTheora.new()
						stream.file = path
					_:
						# For mp4/webm Godot 4 uses GDNative/platform players;
						# attempt a generic load as fallback.
						var loaded = ResourceLoader.load(path, "VideoStream")
						if loaded and loaded is VideoStream:
							stream = loaded
				if stream:
					video_player.stream = stream
					video_player.play()
					oldPath = path
				else:
					printerr("GL_Light_Projector: could not create VideoStream for: ", path)

		"Current Time":
			# VideoStreamPlayer in Godot 4 has no seek(); the best we can do is
			# restart playback from the beginning if drift is large. For small
			# drift we leave it alone to avoid stuttering.
			if video_player.stream and typeof(value) == TYPE_FLOAT:
				var pos = video_player.get_stream_position()
				var diff = value - pos
				# Only resync if noticeably behind/ahead and not just starting up
				if abs(diff) > 0.5 and value > 0.05:
					video_player.stop()
					video_player.play()
					# Godot 4.x VideoStreamPlayer: stream_position is read-only.
					# We can't seek, so we note this is a known limitation.
				elif not video_player.is_playing() and value > 0.0:
					video_player.play()

		"intensity":
			if typeof(value) == TYPE_BOOL:
				value = float(value)
			target_energy = max(value, 0.0) * energyMultiplier

		"color":
			if canChangeColor and value is Color:
				spot_light.light_color = value
