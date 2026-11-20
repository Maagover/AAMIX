extends TextureRect
## Kept alive across interface rebuilds so the valley never jumps back to its start.
var clock = 0.0
var animated = true
var halloween=false
var flash_material:ShaderMaterial

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("screen_background", "valley")
	resized.connect(update_zoom)
	update_zoom()
	var shader=Shader.new()
	shader.code="shader_type canvas_item; uniform float flash=0.0; void fragment(){vec4 p=texture(TEXTURE,UV); float grass=smoothstep(0.42,0.85,UV.y); COLOR=vec4(p.rgb*(1.0+flash*grass*1.8)+vec3(0.05,0.09,0.14)*flash*grass,p.a);}"
	flash_material=ShaderMaterial.new();flash_material.shader=shader

func _process(delta):
	if not visible: return
	if animated: clock += delta
	material=flash_material if halloween else null
	if flash_material!=null:
		var cycle=fmod(clock,13.0)
		var flash=1.0 if animated and (cycle>9.70 and cycle<9.77 or cycle>9.92 and cycle<9.96) else 0.0
		flash_material.set_shader_parameter("flash",flash)
	update_zoom()

func update_zoom():
	pivot_offset = size * 0.5
	# A cosine eases both ends of the loop; no snap when the cycle wraps.
	var amount = 1.0 + (1.0 - cos(clock * TAU / 28.0)) * 0.035 if animated else 1.0
	scale = Vector2.ONE * amount
