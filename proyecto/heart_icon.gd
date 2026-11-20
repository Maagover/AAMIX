extends Control
## Original vector heart, matching the existing drawn gift badge and gold/brown icons.
func configure(side = 92):
	custom_minimum_size = Vector2.ONE*side; mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("social_heart_icon",true); return self
func curve(a,b,c,d,t): return a*pow(1.0-t,3)+b*3.0*pow(1.0-t,2)*t+c*3.0*(1.0-t)*t*t+d*t*t*t
func _draw():
	var paths = [
		[Vector2(.5,.29),Vector2(.19,-.02),Vector2(-.04,.40),Vector2(.20,.60)],
		[Vector2(.20,.60),Vector2(.29,.70),Vector2(.42,.81),Vector2(.50,.89)],
		[Vector2(.50,.89),Vector2(.58,.81),Vector2(.71,.70),Vector2(.80,.60)],
		[Vector2(.80,.60),Vector2(1.04,.40),Vector2(.81,-.02),Vector2(.50,.29)]]
	var points = PackedVector2Array()
	for path in paths:
		for i in range(17): points.append(curve(path[0],path[1],path[2],path[3],float(i)/16.0)*size)
	draw_colored_polygon(points,Color("ffde85"))
	points.append(points[0]); draw_polyline(points,Color("493720"),maxf(2.0,size.x*.035),true)
	draw_arc(size*Vector2(.29,.34),size.x*.11,PI*1.06,PI*1.65,16,Color("fff3c6"),maxf(2.0,size.x*.035),true)
