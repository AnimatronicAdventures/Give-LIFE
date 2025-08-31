extends GL_Animatable
var anim_tree: AnimationTree
var blend_tree: AnimationNodeBlendTree
var animParameters: Dictionary
@export var animParametersFileName: String

var initialPos: Vector3
var initialRot: Vector3
var initialScale: Vector3

# Assuming this node has a child node with an AnimationPlayer
func _ready():
	print(name + " Animatable Loaded " + str(position))
	initialPos = position
	initialRot = rotation
	initialScale = scale
	
	# Grab the AnimationPlayer from the first child
	var anim_player := get_child(0).get_node("AnimationPlayer") as AnimationPlayer
	
	# Initialize the AnimationTree and set up the blend tree
	anim_tree = AnimationTree.new()
	anim_tree.anim_player = anim_player.get_path()  # Set the path to the AnimationPlayer
	add_child(anim_tree)

	# Create the blend tree
	anim_tree.tree_root = AnimationNodeBlendTree.new()
	anim_tree.active = true
	blend_tree = anim_tree.tree_root as AnimationNodeBlendTree
	
	# Disable automatic playback of animations
	anim_player.speed_scale = 0  # This will stop the animation from automatically playing
	
	var animations = anim_player.get_animation_list()
	if animations.size() == 0:
		return
		
	# Try to load animParameters from JSON file if filename is provided
	if animParametersFileName.strip_edges() != "":
		_load_anim_parameters(animParametersFileName)
	
	# If still empty, fall back to auto-populating
	if animParameters.size() == 0:
		for key in animations:
			_create_anim_dict(key)
	
	# Handle the case where there is only one animation
	if animations.size() == 1:
		printerr("STILL NEED TO FIX THIS AHEM" + name)
		return

	# Start with the first animation node
	var prev_name = "Anim_" + animations[0]
	var old_time_name = "Time_" + animations[0]
	var old_seek_name = "Seek_" + animations[0]
	
	var prev_anim_node := AnimationNodeAnimation.new()
	prev_anim_node.animation = animations[0]
	blend_tree.add_node(prev_name, prev_anim_node)
	
	var old_time_node := AnimationNodeTimeScale.new()
	blend_tree.add_node(old_time_name,old_time_node)
		
	var _old_seek_node := AnimationNodeTimeSeek.new()
	blend_tree.add_node(old_seek_name,_old_seek_node)
		
	blend_tree.connect_node(old_time_name,0,prev_name)
	blend_tree.connect_node(old_seek_name,0,old_time_name)
	prev_name = old_seek_name

	# Iteratively add and connect animations through Add2 nodes
	for i in range(1, animations.size()):
		var anim_name = "Anim_" + animations[i]
		var add_name = "Add_" + animations[i]
		var time_name = "Time_" + animations[i]
		var seek_name = "Seek_" + animations[i]

		var new_anim_node := AnimationNodeAnimation.new()
		new_anim_node.animation = animations[i]
		blend_tree.add_node(anim_name, new_anim_node)
		
		var time_node := AnimationNodeTimeScale.new()
		blend_tree.add_node(time_name,time_node)
		
		var seek_node := AnimationNodeTimeSeek.new()
		blend_tree.add_node(seek_name,seek_node)

		var add_node := AnimationNodeAdd2.new()
		blend_tree.add_node(add_name, add_node)
		
		blend_tree.connect_node(time_name,0,anim_name)
		blend_tree.connect_node(seek_name,0,time_name)
		blend_tree.connect_node(add_name, 0, prev_name)
		blend_tree.connect_node(add_name, 1, seek_name)
		prev_name = add_name

	# Final output node connection
	blend_tree.connect_node("output", 0, prev_name)

	# Set the blend amount for each additive node
	for i in range(0, animations.size()):
		anim_tree.set("parameters/Add_" + str(animations[i]) + "/add_amount", 1.0)
		anim_tree.set("parameters/Seek_" + str(animations[i]) + "/seek_request", 0)
		anim_tree.set("parameters/Time_" + str(animations[i]) + "/scale", 0)

func _create_anim_dict(name:String):
	animParameters[name] = {"type":"standard","out_speed":5.0,"in_speed":5.0,"value":0,"signal_value":0}

# Scan the Mods folder for JSON files with the given filename
func _load_anim_parameters(file_name: String) -> void:
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		push_error("Mods folder not found.")
		return
	
	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and mod_name != "." and mod_name != "..":
			var anim_params_path = "res://Mods/%s/Mod Directory/Anim Parameters/%s.json" % [mod_name, file_name]
			if FileAccess.file_exists(anim_params_path):
				var file = FileAccess.open(anim_params_path, FileAccess.READ)
				if file:
					var json_text = file.get_as_text()
					file.close()
					var result = JSON.parse_string(json_text)
					if typeof(result) == TYPE_DICTIONARY:
						for key in result.keys():
							if typeof(result[key]) == TYPE_DICTIONARY:
								var dict_data = result[key]
								# Inject missing runtime-only keys
								dict_data["value"] = 0
								dict_data["signal_value"] = 0
								animParameters[key] = dict_data
				# ✅ Stop after the first successful load
				return
		mod_name = mods_dir.get_next()

func _process(delta):
	if not anim_tree:
		return
	for key in animParameters:
		var anim_path = "parameters/Seek_" + key + "/seek_request"
		var anim_player = get_child(0).get_node("AnimationPlayer") as AnimationPlayer

		if not anim_player.has_animation(key):
			print("Animation not found: ", key)
			return
		match(animParameters[key]["type"]):
			"standard":
				var value = float(animParameters[key]["signal_value"])
				if value > 0.5:
					animParameters[key]["value"] = clamp(float(animParameters[key]["value"]) + (delta * animParameters[key]["out_speed"] * value),0,1)
				elif value < 0.5:
					animParameters[key]["value"] = clamp(float(animParameters[key]["value"]) - (delta * animParameters[key]["in_speed"] * (1 - value)),0,1)
			"move_to":	
				animParameters[key]["value"] = lerp(float(animParameters[key]["value"]), float(animParameters[key]["signal_value"]),delta * animParameters[key]["out_speed"])
		var anim_length = anim_player.get_animation(key).length
		var time_value = clamp(animParameters[key].get("value",0), 0.0, 1.0) * anim_length

		anim_tree.set(anim_path, time_value)

# Function to set the time of the animation based on a normalized value (0.0 to 1.0)
func _sent_signals(anim_name: String, value):
	if value is not float:
		return
	
	#Non Animations
	match(anim_name):
		"Position X":
			position.x = initialPos.x + value
			return
		"Position Y":
			position.y = initialPos.y + value
			return
		"Position Z":
			position.z = initialPos.z + value
			return
		"Rotation X":
			rotation.x = initialRot.x + (value*TAU)
			return
		"Rotation Y":
			rotation.y = initialRot.y + (value*TAU)
			return
		"Rotation Z":
			rotation.z = initialRot.z + (value*TAU)
			return
		"Scale X":
			scale.x = initialScale.x + value
			return
		"Scale Y":
			scale.y = initialScale.y + value
			return
		"Scale Z":
			scale.z = initialScale.z + value
			return
			
	value = float(value)
	animParameters[anim_name]["signal_value"] = clamp(value,0,1)
