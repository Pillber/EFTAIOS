shader_type canvas_item;

void fragment() {
	// do circle math here and only show pixels that are in circle
	// pythag theorem bull$#!7 to determine inside circle alpha channel
	float x = UV.x - 0.5;
	float y = UV.y - 0.5;
	bool inside_circle = (x * x + y * y) < 0.25;
	if(!inside_circle) {
		COLOR.a = 0.0;
	}
}
