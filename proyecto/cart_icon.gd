extends Control
## Original AAMIX shopping icon: warm gold, chocolate outline and cream highlights.
func configure(side = 100):
	custom_minimum_size = Vector2.ONE*side; mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("shop_cart_icon",true); return self
func _draw():
	var c = size*0.5; var s = minf(size.x,size.y)/100.0
	var edge = Color("493720"); var gold = Color("ffde85"); var shine = Color("fff5d6")
	var basket = PackedVector2Array()
	for p in [Vector2(-27,-20),Vector2(36,-20),Vector2(27,8),Vector2(-19,8),Vector2(-27,-20)]: basket.append(c+p*s)
	draw_colored_polygon(basket,gold); draw_polyline(basket,edge,3.5*s,true)
	for x in [-12,2,16]: draw_line(c+Vector2(x,-16)*s,c+Vector2(x,4)*s,shine,2*s,true)
	draw_line(c+Vector2(-21,-6)*s,c+Vector2(30,-6)*s,shine,2*s,true)
	var handle = PackedVector2Array()
	for p in [Vector2(-43,-29),Vector2(-31,-29),Vector2(-20,17),Vector2(28,17)]: handle.append(c+p*s)
	draw_polyline(handle,edge,4*s,true)
	for x in [-15,23]:
		draw_circle(c+Vector2(x,27)*s,6.5*s,edge); draw_circle(c+Vector2(x,27)*s,3.2*s,gold)
