extends Control
## Decorative, pointer-transparent webs drawn in the same ink as the interface.
var animated=true
var clock=0.0
var mirror=false
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_meta("interface_decoration","halloween_web")
func _process(delta):
	if animated:clock+=delta;queue_redraw()
func _draw():
	var origin=Vector2(size.x-2,2) if mirror else Vector2(2,2)
	var direction=-1.0 if mirror else 1.0
	var radius=minf(size.x,size.y)*.78
	var ink=Color("d5c9d6");ink.a=.62
	for ray in range(5):
		var angle=ray*PI/8
		draw_line(origin,origin+Vector2(cos(angle)*direction,sin(angle))*radius,ink,1.1,true)
	for ring in [0.30,0.57,0.83]:
		for ray in range(4):
			var a=origin+Vector2(cos(ray*PI/8)*direction,sin(ray*PI/8))*radius*ring
			var b=origin+Vector2(cos((ray+1)*PI/8)*direction,sin((ray+1)*PI/8))*radius*ring
			draw_line(a,b,ink,.9,true)
	var spider=origin+Vector2(radius*.75*direction,radius*.52+sin(clock*1.7)*3)
	draw_line(origin+Vector2(radius*.75*direction,0),spider,ink,.8,true)
	for side in [-1,1]:
		for leg in range(4):
			var knee=spider+Vector2(side*7,(leg-1.5)*4)
			draw_line(spider,knee,Color("342139"),1.3,true)
			draw_line(knee,knee+Vector2(side*2,4),Color("342139"),1.3,true)
	draw_circle(spider,3.8,Color("342139"),true,-1,true)
	draw_circle(spider+Vector2(0,-3.5),2.5,Color("342139"),true,-1,true)
