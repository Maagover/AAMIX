extends RefCounted
## Both frames share one runtime atlas crop; original PNGs are preserved.
const CLOSED_PATH = "res://assets/estetica_v016/sobre_normal_cerrado.png"
const OPEN_PATH = "res://assets/estetica_v016/sobre_normal_abierto.png"
static var cache = {}
static var frame = Rect2()
static var canvas = Vector2.ZERO

static func registered_frame():
	if canvas != Vector2.ZERO: return
	var closed = Image.new()
	var opened = Image.new()
	if closed.load_png_from_buffer(FileAccess.get_file_as_bytes(CLOSED_PATH)) != OK: return
	canvas = Vector2(closed.get_width(),closed.get_height())
	frame = Rect2(closed.get_used_rect())
	if opened.load_png_from_buffer(FileAccess.get_file_as_bytes(OPEN_PATH)) == OK:
		var ratio = canvas / Vector2(opened.get_width(),opened.get_height())
		var bounds = Rect2(opened.get_used_rect())
		frame = frame.merge(Rect2(bounds.position * ratio,bounds.size * ratio))

static func texture(opened = false) -> Texture2D:
	var key = "open" if opened else "closed"
	if cache.has(key): return cache[key]
	registered_frame()
	var picture = Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(OPEN_PATH if opened else CLOSED_PATH)) != OK: return null
	var atlas = AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(picture)
	var ratio = Vector2(picture.get_width(),picture.get_height()) / canvas
	atlas.region = Rect2(frame.position * ratio,frame.size * ratio)
	atlas.filter_clip = true
	atlas.set_meta("pack_kind","normal_card")
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
	image.set_meta("pack_kind","normal_card")
	image.set_meta("pack_source",OPEN_PATH if opened else CLOSED_PATH)
	image.set_meta("pack_registration","shared_brown_canvas")
	return image
