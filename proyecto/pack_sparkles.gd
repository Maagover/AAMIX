extends Control
## Six small procedural glints around one card; no full-screen flash or bitmap.
var elapsed = 0.0
var tint = Color("cfb56b")
const DURATION = 0.85

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("singular_sparkles",true)
	queue_redraw()

func _process(delta):
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw():
	var strength = sin(clampf(elapsed / DURATION,0.0,1.0) * PI)
	var points = [Vector2(15,65),Vector2(278,101),Vector2(22,320),Vector2(267,350),Vector2(85,12),Vector2(211,390)]
	for i in range(points.size()):
		var point = points[i] + Vector2(sin(i * 1.8 + elapsed * 3.0) * 3.0,cos(i + elapsed * 2.0) * 3.0)
		var length = (3.0 + (i % 3) * 1.2) * strength
		var color = tint
		color.a *= strength
		draw_line(point-Vector2(length,0),point+Vector2(length,0),color,1.5,true)
		draw_line(point-Vector2(0,length),point+Vector2(0,length),color,1.5,true)
