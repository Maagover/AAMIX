extends Control
signal continued
var board
var logo
var prompt
var done = false

func configure(owner):
	board = owner
	return self

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("intro",true)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",54)
	center.add_child(column)
	logo = board.asset_image("logo_color.png",700,250,true)
	column.add_child(logo)
	prompt = board.centered_label("Haz click para jugar",26,Color("fffaf0"))
	column.add_child(prompt)
	if board.animations_enabled:
		logo.modulate.a = 0
		prompt.modulate.a = 0
		var fade = create_tween()
		fade.tween_property(logo,"modulate:a",1.0,2.5).set_trans(Tween.TRANS_SINE)
		fade.tween_property(prompt,"modulate:a",1.0,.25)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		continue_game()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		continue_game()
		accept_event()

func continue_game():
	if done: return
	done = true
	continued.emit()
