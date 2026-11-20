extends TextureRect
## Shared corner mask; the original card images are never modified.
const CORNER_MATERIAL = preload("res://card_corners.tres")

func _init():
	material = CORNER_MATERIAL
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
