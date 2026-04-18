extends GL_Animatable
var spotLight:SpotLight3D
var omniLight:OmniLight3D
@export var canChangeColor:bool = false
@export var canChangeSize:bool = false
@export var energyMultiplier:float = 300
@export var lerp_speed: float = 5.0
var target_energy: float = 0.0

func _ready():
	var light = self.get_parent()
	if light is SpotLight3D:
		spotLight = light
	if light is OmniLight3D:
		omniLight = light
	target_energy = light.light_energy

func _process(delta: float) -> void:
	if spotLight != null:
		spotLight.light_energy = lerp(spotLight.light_energy, target_energy, delta * lerp_speed)
		if spotLight.light_energy == 0.0:
			spotLight.visible = false
		else:
			spotLight.visible = true
	elif omniLight != null:
		omniLight.light_energy = lerp(omniLight.light_energy, target_energy, delta * lerp_speed)
		if omniLight.light_energy == 0.0:
			omniLight.visible = false
		else:
			omniLight.visible = true

func _sent_signals(signal_ID:String,the_signal):
	signal_ID = signal_ID.split("|", true, 1)[-1]
	match(signal_ID):
		"intensity":
			if typeof(the_signal) == TYPE_BOOL:
				the_signal = the_signal * 1.0
			target_energy = max(the_signal, 0.0) * energyMultiplier
		"color":
			if canChangeColor && typeof(the_signal) == TYPE_COLOR:
				if spotLight != null:
					spotLight.light_color = the_signal
				elif omniLight != null:
					omniLight.light_color = the_signal
		"size":
			if canChangeSize:
				if typeof(the_signal) == TYPE_BOOL:
					the_signal = the_signal * 1.0
				if spotLight != null:
					spotLight.spot_angle = clamp(the_signal * 45.0,0.1,90)
	pass 
