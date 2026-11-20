extends RefCounted
## Five PNG icons generated together; regions keep the original atlas untouched.
const ORDER = {"gift":Vector2i(0,0),"dice":Vector2i(1,0),"swords":Vector2i(2,0),"lock":Vector2i(0,1),"reload":Vector2i(1,1)}
static var atlas_source: Texture2D
static var cache = {}

static func texture(kind):
	if cache.has(kind): return cache[kind]
	if atlas_source == null:
		var picture = Image.new()
		picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/estetica_v015/iconos_aamix.png"))
		atlas_source = ImageTexture.create_from_image(picture)
	var cell = Vector2(atlas_source.get_width()/3.0,atlas_source.get_height()/2.0)
	var result = AtlasTexture.new()
	result.atlas = atlas_source
	result.region = Rect2(Vector2(ORDER.get(kind,Vector2i.ZERO))*cell,cell)
	result.filter_clip = true
	cache[kind] = result
	return result

static func view(kind, side):
	var picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = texture(kind)
	picture.custom_minimum_size = Vector2.ONE*side
	picture.size = Vector2.ONE*side
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_meta("ui_icon",kind)
	return picture

static func floating(kind, side, motion = true):
	return preload("res://floating_icon.gd").new().configure(view(kind,side),Vector2(side,side+12),motion)

static func multiplayer_battle(side = 100, motion = true):
	var center = CenterContainer.new()
	var picture = floating("swords", side, motion)
	picture.set_meta("multiplayer_battle_icon", true)
	center.add_child(picture)
	return center
