extends GL_Node

@onready var http_request : HTTPRequest = HTTPRequest.new()
var sending_allowed := true
var server_url := "http://192.168.12.158:8080"
var last_send_time := 0.0
var send_interval := 0.01667
var last_values := []

func _ready():
	super._ready()
	_set_title("GL Board")
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	# initialise last_values to the starting values
	for i in range(16):
		_create_row("Servo %d" % i, 0.0, null, true, 0.0, 1.0)
		last_values.append(0.0)
	_update_visuals()

func _process(delta):
	super._process(delta)
	apply_pick_values()
	for i in range(16):
		rows["Servo %d" % i]["output"] = rows["Servo %d" % i]["input"]
	last_send_time += delta
	if sending_allowed and last_send_time >= send_interval:
		if _values_changed():
			send_servo_values()
			last_send_time = 0.0

func _values_changed() -> bool:
	for i in range(16):
		var current = rows["Servo %d" % i]["output"]
		if abs(current - last_values[i]) > 0.0001:
			# value changed
			return true
	return false

func send_servo_values():
	sending_allowed = false
	var data := {}
	for i in range(16):
		var key = "servo%d" % i
		var value = rows["Servo %d" % i]["output"]
		data[key] = value
		last_values[i] = value  # update the last known
	var json_str := JSON.stringify(data)
	print("Sending packet to ", server_url, ": ", json_str)
	var headers := ["Content-Type: application/json"]
	var err := http_request.request(server_url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		print("HTTP error on send:", err)
		sending_allowed = true

func _on_request_completed(result, response_code, headers, body):
	print("Request completed. result=", result, " response_code=", response_code)
	print("Response body:", body.get_string_from_utf8())
	sending_allowed = true
