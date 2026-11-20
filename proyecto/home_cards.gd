extends Control
## Printed cards and a sealed pack behind the gently floating logo.
const PackArt = preload("res://pack_art.gd")
const CardImage = preload("res://card_image.gd")
var featured_texture: Texture2D
var resource_texture: Texture2D
var logo_texture: Texture2D
var animated = true
var clock = 0.0
var floating_cards = []
var featured: TextureRect
var logo: TextureRect
var closed_pack: TextureRect

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	featured = make_card(featured_texture, Vector2(230, 314), true)
	featured.position = Vector2(24, -6)
	featured.rotation = -0.13
	featured.set_meta("decorative_card", "0119")
	var resource = make_card(resource_texture, Vector2(218, 297), true)
	resource.position = Vector2(276, 24)
	resource.rotation = 0.12
	resource.set_meta("decorative_card", "0100")
	for picture in [featured, resource]:
		picture.set_meta("rest_position", picture.position)
		floating_cards.append(picture)
	closed_pack = make_card(PackArt.texture(false), Vector2(244, 358))
	closed_pack.position = Vector2(139, -34)
	closed_pack.rotation = 0.035
	move_child(closed_pack,1)
	closed_pack.set_meta("decorative_pack", true)
	closed_pack.set_meta("pack_art", "closed")
	closed_pack.set_meta("rest_position", closed_pack.position)
	floating_cards.append(closed_pack)
	logo = make_card(logo_texture, Vector2(490, 174))
	logo.position = Vector2(15, 134)
	logo.set_meta("home_logo", true)
	logo.set_meta("rest_position", logo.position)
	update_cards()

func make_card(picture, dimensions, printed = false):
	var image = CardImage.new() if printed else TextureRect.new()
	image.texture = picture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size = dimensions
	image.pivot_offset = dimensions * 0.5
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

func _process(delta):
	if not animated: return
	clock += delta
	update_cards()

func update_cards():
	for i in range(floating_cards.size()):
		var picture = floating_cards[i]
		var phase = clock * 0.85 + i * 2.1
		picture.position = picture.get_meta("rest_position") + Vector2(sin(phase * 0.6) * 4.0, sin(phase) * 11.0)
	if is_instance_valid(logo):
		logo.position = logo.get_meta("rest_position") + Vector2(sin(clock * 0.51) * 1.4, sin(clock * 0.85 + 1.1) * 3.5)
