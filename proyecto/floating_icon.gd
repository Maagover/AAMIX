extends Control
## Keeps the layout slot fixed while the artwork moves gently inside it.
var picture
var animated = true
var clock = 0.0
func configure(child, dimensions, motion = true):
	picture = child; animated = motion; custom_minimum_size = dimensions
	mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(child); set_meta("floating_icon",true)
	return self
func _ready():
	resized.connect(place); place(); set_process(animated)
func _process(delta):
	clock += delta; place()
func place():
	if not is_instance_valid(picture): return
	picture.size = size-Vector2(0,12)
	picture.position = Vector2(0,6+(sin(clock*1.5)*4 if animated else 0))
