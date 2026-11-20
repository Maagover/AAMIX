extends RefCounted
## Registration shared by both original artworks. Source PNGs are never changed.
## Closed artwork is exactly twice the open canvas; both use this same frame.
const CLOSED_PATH = "res://assets/estetica/sobre_cerrado.png"
const OPEN_PATH = "res://assets/estetica/sobre_abierto.png"
const FRAME = Rect2(140, 80, 710, 1040)
const REGISTRATION = "common_896x1200_rect140_80_710_1040"
static var cache = {}

static func texture(opened = false) -> Texture2D:
	var key = "open" if opened else "closed"
	if cache.has(key): return cache[key]
	var picture = Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(OPEN_PATH if opened else CLOSED_PATH)) != OK: return null
	var atlas = AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(picture)
	var ratio = Vector2(picture.get_width() / 896.0, picture.get_height() / 1200.0)
	atlas.region = Rect2(FRAME.position * ratio, FRAME.size * ratio)
	atlas.filter_clip = true
	cache[key] = atlas
	return atlas

static func view(dimensions: Vector2, opened = false) -> TextureRect:
	var image = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture(opened)
	image.custom_minimum_size = dimensions
	image.size = dimensions
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_meta("pack_art", "open" if opened else "closed")
	image.set_meta("pack_source", OPEN_PATH if opened else CLOSED_PATH)
	image.set_meta("pack_registration", REGISTRATION)
	return image
