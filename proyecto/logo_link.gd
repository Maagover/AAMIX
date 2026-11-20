extends TextureRect
## A real image link: no rectangular button background.
var action = Callable()
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if action.is_valid(): action.call(); accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		if action.is_valid(): action.call(); accept_event()
