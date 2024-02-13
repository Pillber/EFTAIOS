extends Camera2D

@export var zoom_factor = 0.05
@export var min_zoom: Vector2 = Vector2(0.25, 0.25)
@export var max_zoom := Vector2.ONE

var dragging: bool = false
var mouse_start_pos: Vector2
var screen_start_position: Vector2


func _input(event):
	# set dragging of camera
	if event.is_action("mouse_drag"):
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = position
			dragging = true
		else:
			dragging = false
	
	# drag camera if needed
	elif event is InputEventMouseMotion and dragging:
		position = (mouse_start_pos - event.position) * (1 / zoom.x) + screen_start_position
	
	# zoom camera
	elif event.is_action("zoom_out"):
		set_zoom(get_zoom() - Vector2.ONE * zoom_factor)
	elif event.is_action("zoom_in"):
		set_zoom(get_zoom() + Vector2.ONE * zoom_factor)
	
	# clamp zoom value
	set_zoom(clamp(zoom, min_zoom, max_zoom))
