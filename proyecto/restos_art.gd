extends RefCounted
## Currency artwork is independent of the printed resource card.
static var cached: Texture2D
static func texture():
	if cached != null: return cached
	var path = "res://assets/estetica_v017/restos.png"
	if not FileAccess.file_exists(path): return null
	var image = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	var region = AtlasTexture.new()
	region.atlas = ImageTexture.create_from_image(image)
	region.region = Rect2(image.get_used_rect())
	region.filter_clip = true
	cached = region
	return cached
static func view(side):
	var node = TextureRect.new()
	node.texture = texture()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2.ONE * side
	node.size = Vector2.ONE * side
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_meta("restos_icon",true)
	return node
