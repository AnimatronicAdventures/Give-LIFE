extends Node
@export var flashlightType: Flashlight.flashlightTypes = Flashlight.flashlightTypes.default
@onready var flashlight : Flashlight = $CharacterBody3D/Camera3D/Flashlight


func _ready() -> void:
	flashlight.setFlashlightType(flashlightType)
