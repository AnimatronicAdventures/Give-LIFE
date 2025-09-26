extends GL_Node

func _ready():
	super._ready()
	_set_title("Switch Video")
	_create_row("Toggle",false,GL_VideoType.new(),true,false,0)
	_create_row("Video A",GL_VideoType.new(),null,true,GL_VideoType.new(),0)
	_create_row("Video B",GL_VideoType.new(),null,true,GL_VideoType.new(),0)
	_update_visuals()

func _process(delta):
	super._process(delta)
	apply_pick_values()
	if(rows["Toggle"]["input"] == false):
		rows["Toggle"]["output"] = rows["Video A"]["input"]
	else:
		rows["Toggle"]["output"] = rows["Video B"]["input"]
	_send_input("Toggle")
