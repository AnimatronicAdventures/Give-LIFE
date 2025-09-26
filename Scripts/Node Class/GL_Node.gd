extends PanelContainer
class_name GL_Node
var rows : Dictionary
var uuid : String
var nodePath:String
var dragging : bool
var canDrag : bool
var dragOffset : Vector2
var loadNodeRow : Resource
var special_condition : String
var special_saved_values : Dictionary
var optionsMenu : Node
var customRows : Dictionary

const draggingScale : float = 1.05
const dragScalingSpeed : float = 8

func _ready():
	loadNodeRow = preload("res://Scenes/Nodes/Node Row.tscn")
	(get_node("Margins").get_node("Holder").get_node("Title").get_node("Exit Button") as Button).connect("button_down",self.delete_whole_node)
	
func _process(delta):
	if dragging:
		position = get_viewport().get_mouse_position() + dragOffset
		scale = lerp(scale,Vector2.ONE * draggingScale,delta * dragScalingSpeed)
	else:
		scale = lerp(scale,Vector2.ONE,delta * dragScalingSpeed)
	for key in rows:
		for connection in rows[key].get("connections",[]):
			if typeof(connection.target) == TYPE_STRING:
				for node in get_tree().get_nodes_in_group("GL Node"):
					if node is GL_Node:
						if node.uuid == connection.target:
							connection.target = node
							break
			
		
func _input(event): 
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed && canDrag:
			dragging = true
			dragOffset = position - get_viewport().get_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT && !event.pressed && dragging:
			dragging = false
func _replace_script_paths_and_colors(data):
	match typeof(data):
		TYPE_DICTIONARY:
			for key in data.keys():
				data[key] = _replace_script_paths_and_colors(data[key])
			return data

		TYPE_ARRAY:
			# If it’s exactly 4 floats, treat as Color
			if data.size() == 4 and [
				typeof(data[0]), typeof(data[1]),
				typeof(data[2]), typeof(data[3])
			] == [TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT, TYPE_FLOAT]:
				return Color(data[0], data[1], data[2], data[3])
			# Otherwise recurse each element
			for i in range(data.size()):
				data[i] = _replace_script_paths_and_colors(data[i])
			return data

		TYPE_STRING:
			# Script path → instance
			if data.begins_with("res://") and data.ends_with(".gd"):
				var script = load(data)
				if script and script is GDScript:
					return script.new()
			return data

		_:
			return data


func load_custom_rows_from_mods(this_class_name: String):
	var mods_dir = DirAccess.open("res://Mods")
	if not mods_dir:
		push_error("Mods folder not found")
		return

	mods_dir.list_dir_begin()
	var mod_name = mods_dir.get_next()
	while mod_name != "":
		if mods_dir.current_is_dir() and not mod_name.begins_with("."):
			var node_settings_path = "res://Mods/%s/Mod Directory/Node Settings" % mod_name
			if DirAccess.dir_exists_absolute(node_settings_path):
				var settings_dir = DirAccess.open(node_settings_path)
				settings_dir.list_dir_begin()
				var file_name = settings_dir.get_next()
				while file_name != "":
					if file_name.to_lower() == (this_class_name.to_lower() + ".json"):
						var file_path = "%s/%s" % [node_settings_path, file_name]
						var file = FileAccess.open(file_path, FileAccess.READ)
						if file:
							var json_parser = JSON.new()
							var parse_result = json_parser.parse_string(file.get_as_text())
							if typeof(parse_result) == TYPE_DICTIONARY:
								var processed_data = _replace_script_paths_and_colors(parse_result)
								for key in processed_data.keys():
									customRows[key] = processed_data[key]
							else:
								push_error("Expected a JSON dictionary, but got %s" % typeof(parse_result))

					file_name = settings_dir.get_next()
		mod_name = mods_dir.get_next()

func _create_uuid():
	var rand = RandomNumberGenerator.new()
	rand.seed = Time.get_unix_time_from_system()
	uuid = str(rand.randi())

func _update_visuals():
	var holder = get_node("Margins").get_node("Holder")
	for child in holder.get_children():
		if child.name.contains("Node Row"):
			child.queue_free()
		if child.name.contains("OptionButton"):
			child.queue_free()
		if child.name.contains("Enum"):
			child.queue_free()
			
	match(special_condition):
		"Animatable":
			var add = load("res://Scenes/Nodes/Node Enum.tscn").instantiate()
			holder.add_child(add)
			var _enum = (add as GL_Animatable_Enum)
			_enum.set_up_enum(self)
			
	for key in rows:
		var nodeRow = loadNodeRow.instantiate()
		holder.add_child(nodeRow)
		nodeRow.name = "Node Row"
		var label = nodeRow.get_node("Label")
		(label as Label).text = str(key)
		match(special_condition):
			"Record Node":
				var rclickrow = (label as GL_Node_R_Click_Row)
				rclickrow.mainNode = self
				rclickrow.valueName = str(key)
		var input = nodeRow.get_node("Input") as GL_Node_Point
		var output = nodeRow.get_node("Output") as GL_Node_Point
		input.valueName = str(key)
		input.mainNode = self
		input.update_lines()
		output.valueName = str(key)
		output.mainNode = self
		output.update_lines()
		if rows[key]["picker"] == true:
			match typeof(rows[key]["pickValue"]):
				TYPE_FLOAT:
					assignPick(nodeRow.get_node("Pick Float"),str(key))
					var slider = nodeRow.get_node("Pick Float") as HSlider
					slider.max_value = rows[key]["pickFloatMax"]
					slider.value = rows[key]["pickValue"]
				TYPE_COLOR:
					assignPick(nodeRow.get_node("Pick Color"),str(key))
					(nodeRow.get_node("Pick Color") as ColorPickerButton).color = rows[key]["pickValue"]
				TYPE_BOOL:
					assignPick(nodeRow.get_node("Pick Bool"),str(key))
					(nodeRow.get_node("Pick Bool") as CheckButton).button_pressed = rows[key]["pickValue"]
			if rows[key]["pickValue"] is GL_AudioType:
				assignPick(nodeRow.get_node("Pick Audio"),str(key))
				if rows[key]["pickValue"] == null:
					rows[key]["pickValue"] = GL_AudioType.new()
			if rows[key]["pickValue"] is GL_VideoType:
				assignPick(nodeRow.get_node("Pick Video"),str(key))
				if rows[key]["pickValue"] == null:
					rows[key]["pickValue"] = GL_VideoType.new()
		else:
			(nodeRow.get_node("Label") as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
		_set_inout_type(nodeRow.get_node("Input") as Button,rows[key]["input"])
		_set_inout_type(nodeRow.get_node("Output") as Button,rows[key]["output"])
	match(special_condition):
		"Record Node":
			var add = load("res://Scenes/Nodes/Node Add.tscn").instantiate()
			holder.add_child(add)
			(add as GL_Node_Add).mainNode = self


func assignPick(pick:GL_Node_Picker,key:String):
	if pick != null:
		pick.mainNode = self
		pick.valueName = key

func give_input_point_pos(name:String) -> Vector2:
	var holder = get_node("Margins").get_node("Holder")
	if holder == null:
		return global_position
	else:
		for child in holder.get_children():
			if child.name.contains("Node Row") && (child.get_node("Label") as Label).text == name:
				holder = child.get_node("Input") as GL_Node_Point
				return holder.global_position + Vector2(holder.size.x/2,holder.size.y/2)
	return Vector2.ZERO

func _set_inout_type(label:Button, value):
	match typeof(value):
		TYPE_FLOAT:
			label.text = "◉"
			label.add_theme_color_override("font_color", Color.ROYAL_BLUE)
		TYPE_BOOL:
			label.text = "◆"
			label.add_theme_color_override("font_color", Color.ORANGE)
		TYPE_COLOR:
			label.text = "▲"
			label.add_theme_color_override("font_color", Color.WHITE_SMOKE)
	if value is GL_AudioType:
		label.text = "♫"
		label.add_theme_color_override("font_color", Color.BLUE_VIOLET)
	elif value is GL_VideoType:
		label.text = "📽"
		label.add_theme_color_override("font_color", Color.SEA_GREEN)
	if value == null:
		label.visible = false

func _set_title(name:String):
	(get_node("Margins").get_node("Holder").get_node("Title").get_node("Title Label") as LineEdit).text = name

func _get_title() -> String:
	return (get_node("Margins").get_node("Holder").get_node("Title").get_node("Title Label") as LineEdit).text


func _create_row(name:String,input,output,picker:bool,pickDefault,pickFloatMaximum:float):
	if rows.has(name):
		return
	rows[name] = {"input": input, "output": output, "connections": [], "picker":picker,"pickValue":pickDefault,"backConnected":false,"pickFloatMax":pickFloatMaximum}

func _recieve_input(inputName:String,value):
	if rows.has(inputName):
		if typeof(rows[inputName]["input"]) == TYPE_FLOAT && typeof(value) == TYPE_BOOL:
			rows[inputName]["input"] = float(value)
		else:
			rows[inputName]["input"] = value
	
func _send_input(output_name: String):
	if not rows.has(output_name):
		return

	for conn in rows[output_name].get("connections", []):
		var target = conn.get("target", null)
		var input_name = conn.get("input_name", null)
		if target and input_name:
			if typeof(target) != TYPE_INT:
				target._recieve_input(input_name, rows[output_name]["output"])

func _confirm_backConnection(input_name:String):
	if !rows.has(input_name):
		return
	rows[input_name]["backConnected"] = true

func _create_connection(target:GL_Node,input_name:String,output_name:String):
	if not rows.has(output_name):
		return
		
	var item = target.rows.get(input_name, null)
	if item == null:
		return
	
	var typeA = typeof(rows[output_name].get("output", null))
	var typeB = typeof(target.rows[input_name].get("input",null))
	if (typeA != typeB) && !(typeA == TYPE_BOOL && typeB == TYPE_FLOAT) && !(typeA == TYPE_INT && typeB == TYPE_FLOAT)&& !(typeA == TYPE_FLOAT && typeB == TYPE_INT):
			print("Type mismatch: cannot connect " + output_name + " to " + target.name)
			return
	
	var thenew = {
		"target": target,
		"input_name": input_name
	}
	
	var connections = 	rows[output_name].get("connections", [])
	
	for connection in connections:
		if connection.target == thenew.target and connection.input_name == thenew.input_name:
			print("Connection already exists: " + output_name + " to " + target.name)
			return
	
	for node in get_tree().get_nodes_in_group("GL Node"):
		if node is GL_Node:
			node.destroy_connection(target,input_name)
	
	connections.append(thenew)
	rows[output_name]["connections"] = connections
	
	target._confirm_backConnection(input_name)
	
func destroy_connection(target:GL_Node,input_name:String):
	for key in rows:
		var connections = rows[key].get("connections",[])
		for i in connections.size():
			if connections[i].target == target and connections[i].input_name == input_name:
				connections.remove_at(i)
				rows[key]["connections"] = connections
				var holder = get_node("Margins").get_node("Holder")
				for child in holder.get_children():
					if child.name.contains("Node Row"):
						(child.get_node("Input") as GL_Node_Point).update_lines()
						(child.get_node("Output") as GL_Node_Point).update_lines()
				return
	
func mouse_enter():
	canDrag = true
func mouse_exit():
	canDrag = false
	
func r_click_row(rowName:String):
	var node = load("res://Scenes/UI/Node Options.tscn").instantiate()
	var outerArea = get_parent().get_parent().get_parent()
	outerArea.add_child(node)
	node.global_position = get_viewport().get_mouse_position() - (node.size / 2.0)
	node.mainNode = self
	node.valueName = rowName
	node.set_line_name(rowName)
	if optionsMenu != null:
		optionsMenu.queue_free()
	optionsMenu = node
	
func apply_pick_values():
	for key in rows:
		if rows[key]["picker"] == true && rows[key]["backConnected"] == false:
			rows[key]["input"] = rows[key]["pickValue"]

func delete_whole_node():
	for node in get_tree().get_nodes_in_group("Outputs"):
			if node is GL_Node_Point:
				for key in rows:
					node.mainNode.destroy_connection(self,key)
	if optionsMenu != null:
		optionsMenu.queue_free()
	get_parent().queue_free()

func delete_node_row(rowName:String):
	rows.erase(rowName)
	_update_visuals()
