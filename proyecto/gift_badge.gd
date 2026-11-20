extends Control
## A small original drawn gift marker, with no external image dependency.
var clock = 0.0
var animated = true

func _ready():
	custom_minimum_size = Vector2(100, 82)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta):
	if not animated: return
	clock += delta
	queue_redraw()

func _draw():
	var c = size * 0.5 + Vector2(0, sin(clock * 2.4) * 3.0)
	var gold = Color("ffde85")
	var ribbon = Color("7f6042")
	draw_rect(Rect2(c + Vector2(-27, -7), Vector2(54, 32)), gold)
	draw_rect(Rect2(c + Vector2(-27, -7), Vector2(54, 32)), ribbon, false, 2.0)
	draw_rect(Rect2(c + Vector2(-31, -16), Vector2(62, 12)), gold.lightened(0.15))
	draw_rect(Rect2(c + Vector2(-31, -16), Vector2(62, 12)), ribbon, false, 2.0)
	draw_rect(Rect2(c + Vector2(-4, -16), Vector2(8, 41)), ribbon)
	draw_arc(c + Vector2(-10, -22), 11, -PI * 0.1, PI * 1.2, 22, ribbon, 4.0, true)
	draw_arc(c + Vector2(10, -22), 11, -PI * 0.2, PI * 1.1, 22, ribbon, 4.0, true)
	for i in range(4):
		var a = float(i) * TAU / 4.0 + 0.4
		var p = c + Vector2(cos(a) * 43.0, sin(a) * 31.0)
		var length = 2.4 + sin(clock * 3.0 + i * 1.6) * 1.4
		draw_line(p - Vector2(length, 0), p + Vector2(length, 0), ribbon, 1.6, true)
		draw_line(p - Vector2(0, length), p + Vector2(0, length), ribbon, 1.6, true)
