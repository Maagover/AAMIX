extends Control
## A code-native circular portrait. Original card artwork is never modified.
const CIRCLE_SHADER = preload("res://avatar_circle.gdshader")
# Center X/Y in the full card, followed by square width / full image width.
# Reviewed against every Aliado, including the promotional illustrations.
const FRAMING = {
	"0101": Vector3(0.66, 0.29, 0.48),
	"0102": Vector3(0.50, 0.29, 0.59),
	"0103": Vector3(0.59, 0.29, 0.50),
	"0104": Vector3(0.47, 0.34, 0.40),
	"0105": Vector3(0.55, 0.34, 0.50),
	"0106": Vector3(0.53, 0.28, 0.59),
	"0107": Vector3(0.445, 0.445, 0.58),
	"0108": Vector3(0.635, 0.300, 0.34),
	"0109": Vector3(0.50, 0.31, 0.57),
	"0110": Vector3(0.48, 0.25, 0.30),
	"0111": Vector3(0.48, 0.31, 0.56),
	"0112": Vector3(0.43, 0.39, 0.46),
	"0113": Vector3(0.54, 0.31, 0.54),
	"0114": Vector3(0.62, 0.34, 0.54),
	"0115": Vector3(0.51, 0.36, 0.69),
	"0125": Vector3(0.54, 0.36, 0.72),
	"0126": Vector3(0.43, 0.30, 0.47),
	"0127": Vector3(0.505, 0.220, 0.34),
	"0128": Vector3(0.56, 0.30, 0.72),
	"0129": Vector3(0.51, 0.32, 0.63),
	"0130": Vector3(0.47, 0.31, 0.55),
	"0134": Vector3(0.47, 0.31, 0.62),
	"01a": Vector3(0.29, 0.30, 0.40),
	"01b": Vector3(0.49, 0.25, 0.44),
	"01c": Vector3(0.59, 0.32, 0.53),
	"01e": Vector3(0.58, 0.32, 0.62),
	"01f": Vector3(0.38, 0.64, 0.44)
}
var avatar_code = ""
var selected = false:
	set(value):
		selected = value
		queue_redraw()
var portrait = TextureRect.new()
var portrait_material = ShaderMaterial.new()

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_material.shader = CIRCLE_SHADER
	portrait.material = portrait_material
	add_child(portrait)
	resized.connect(_layout)

func configure(picture, code = "", diameter = 96):
	avatar_code = str(code)
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	portrait.texture = picture
	portrait.visible = picture != null
	if picture != null:
		portrait_material.set_shader_parameter("crop_rect", crop_rect(avatar_code, picture))
	_layout()
	queue_redraw()
	return self

static func crop_rect(code, picture):
	var focus = FRAMING.get(str(code), Vector3(0.52, 0.33, 0.52))
	var width = focus.z
	var height = width * float(picture.get_width()) / maxf(1.0, picture.get_height())
	return Vector4(focus.x - width * 0.5, focus.y - height * 0.5, width, height)

func _layout():
	var side = minf(size.x, size.y)
	portrait.position = (size - Vector2.ONE * side) * 0.5 + Vector2(3, 3)
	portrait.size = Vector2.ONE * maxf(1, side - 6)
	queue_redraw()

func _draw():
	var center = size * 0.5
	var radius = minf(size.x, size.y) * 0.5
	draw_circle(center, radius, Color("7f6042") if selected else Color("cdb66d"), true, -1, true)
	draw_circle(center, maxf(0, radius - 2), Color("fffaf0"), true, -1, true)
	if not portrait.visible:
		# Neutral silhouette until the player explicitly chooses a character.
		draw_circle(center + Vector2(0, -radius * 0.22), radius * 0.23, Color("96724e"), true, -1, true)
		draw_style_box(_silhouette_style(radius), Rect2(center + Vector2(-radius * 0.44, radius * 0.10), Vector2(radius * 0.88, radius * 0.50)))

func _silhouette_style(radius):
	var result = StyleBoxFlat.new()
	result.bg_color = Color("96724e")
	result.corner_radius_top_left = int(radius * 0.45)
	result.corner_radius_top_right = int(radius * 0.45)
	result.corner_radius_bottom_left = int(radius * 0.12)
	result.corner_radius_bottom_right = int(radius * 0.12)
	return result
