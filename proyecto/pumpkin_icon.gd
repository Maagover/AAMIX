extends TextureRect
func configure(side=44):
	custom_minimum_size=Vector2.ONE*side
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var image=Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/halloween_2026/calabaza_aamix.png"))
	texture=ImageTexture.create_from_image(image)
	set_meta("event_pumpkin_icon",true)
	return self
