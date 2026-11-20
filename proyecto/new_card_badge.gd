extends Control
## Small, static marker. It belongs to the printed card and moves with it.
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	tooltip_text="Carta nueva"
	set_meta("new_card_badge",true)
func _draw():
	var points=PackedVector2Array()
	for i in range(24):
		var angle=-PI*.5+TAU*i/24.0
		var radius=10.0 if i%2==0 else 5.8
		points.append(Vector2(12,12)+Vector2(cos(angle),sin(angle))*radius)
	# Un halo cálido y un centro casi blanco conservan el tamaño discreto
	# del indicador, pero se distinguen sobre ilustraciones oscuras y claras.
	draw_circle(Vector2(12,12),11.5,Color("fff4ae38"))
	draw_colored_polygon(points,Color("fff2a8"))
	points.append(points[0])
	draw_polyline(points,Color("fffdf0"),1.15,true)
	draw_circle(Vector2(12,12),2.1,Color("ffffff"))
