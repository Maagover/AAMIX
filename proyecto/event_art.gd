extends Control
## Floating original artwork; no changes to its source pixels.
const CardImage = preload("res://card_image.gd")
var picture
var animated = true
var clock = 0.0

func configure(texture, dimensions, printed = false, motion_enabled = true):
	custom_minimum_size = dimensions
	animated = motion_enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture = CardImage.new() if printed else TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return self

func _process(delta):
	if picture == null: return
	if animated: clock += delta
	picture.size = size - Vector2(0, 10)
	picture.position = Vector2(0, 5 + (sin(clock * 1.35) * 4 if animated else 0))
