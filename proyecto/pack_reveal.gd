extends Control
## Presentation only: ordered cards already granted atomically by the server.
const PackArt = preload("res://pack_art.gd")
const NormalPackArt = preload("res://normal_pack_art.gd")
const HalloweenPackArt=preload("res://halloween_pack_art.gd")
const PACK_ART_SIZE = Vector2(326, 478)
const SINGULARS = ["0105","0103","0115","0119"]
const SingularShader = preload("res://singular_shine.gdshader")
const Sparkles = preload("res://pack_sparkles.gd")
const NewBadge = preload("res://new_card_badge.gd")
signal progress_changed(index)
signal finished
signal packet_opened
signal opening_stage_changed(stage)
signal singular_arrived(opening_id)
var board
var cards = []
var revealed = 0
var sealed = true
var dragging = false
var travel = 0.0
var animating = false
var current
var layers
var packet
var packet_closed
var packet_opened_art
var hint
var caption
var origin = Vector2.ZERO
var packet_origin = Vector2.ZERO
var return_tween
var opening_stage = "sealed"
var opening_id = ""
var pack_kind = "tc"
var singular_shown = false
var singular_started_at = -1
var new_card_indices = []

static func normalize_new_indices(values):
	if not values is Array: return []
	return values.filter(func(value):return (value is int or value is float) and value>=0 and value<50000 and value==int(value)).map(func(value):return int(value))

func configure(owner_board, codes, index = 0, already_open = false, id = "", already_shown = false, kind = "tc", new_indices = []):
	board = owner_board
	cards = codes.duplicate()
	revealed = index
	sealed = index == 0 and not already_open
	opening_id = str(id)
	pack_kind = str(kind)
	new_card_indices = normalize_new_indices(new_indices)
	set_meta("pack_kind",pack_kind)
	set_meta("pack_card_count",cards.size())
	singular_shown = already_shown
	custom_minimum_size = Vector2(1080, 600)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	resized.connect(rebuild)
	return self

func _ready():
	board.hover_feedback(self,1.015)
	rebuild()

func rebuild():
	if not is_inside_tree() or board == null or animating: return
	for child in get_children(): child.queue_free()
	current = null
	packet = null
	packet_closed = null
	packet_opened_art = null
	origin = Vector2(size.x / 2.0 - 148, 82)
	# Printed body center is x=450 in the base 896px artwork. The two Atlas
	# frames register that body at the same point, including the torn flap.
	packet_origin = Vector2(origin.x + 148.0 - (450.0 - PackArt.FRAME.position.x) / PackArt.FRAME.size.x * PACK_ART_SIZE.x, origin.y - 52.0)
	if pack_kind in ["normal_card","halloween"]: packet_origin = Vector2(origin.x + 148.0 - PACK_ART_SIZE.x * .5,origin.y - 52.0)
	opening_stage = "sealed" if sealed else "cards"
	set_meta("opening_stage", opening_stage)
	var card_hint = "Desliza la carta hacia un costado para continuar" if cards.size() == 1 else "Desliza la carta hacia un costado para descubrir la siguiente"
	caption = board.label("Desliza la parte superior del sobre hacia un costado" if sealed else card_hint, 21, board.MINT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 10)
	caption.size = Vector2(size.x, 38)
	add_child(caption)
	if revealed >= cards.size(): return
	layers = Control.new()
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layers)
	for i in range(mini(cards.size()-1,revealed+1), revealed - 1, -1):
		var image = board.catalog_image(cards[i], 296, 402)
		image.position = origin
		image.size = Vector2(296, 402)
		image.pivot_offset = image.size * .5
		image.rotation = 0.0
		# Identical bounds and no offsets: the next card is already behind this
		# one, without a rotated edge revealing its rarity before the gesture.
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.visible = not sealed
		image.set_meta("pack_index",i)
		if i in new_card_indices:
			var badge=NewBadge.new()
			badge.position=Vector2(270,2)
			badge.size=Vector2(24,24)
			image.add_child(badge)
		layers.add_child(image)
		if i == revealed: current = image
	if sealed:
		packet = Control.new()
		packet.position = packet_origin
		packet.size = PACK_ART_SIZE
		packet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		packet.set_meta("pack_wrapper",true)
		add_child(packet)
		packet_closed = HalloweenPackArt.view(PACK_ART_SIZE) if pack_kind=="halloween" else (NormalPackArt.view(PACK_ART_SIZE) if pack_kind == "normal_card" else PackArt.view(PACK_ART_SIZE))
		packet_closed.set_meta("pack_closed_layer",true)
		packet.add_child(packet_closed)
		packet_opened_art = HalloweenPackArt.view(PACK_ART_SIZE,true) if pack_kind=="halloween" else (NormalPackArt.view(PACK_ART_SIZE,true) if pack_kind == "normal_card" else PackArt.view(PACK_ART_SIZE,true))
		packet_opened_art.modulate.a = 0.0
		packet_opened_art.set_meta("pack_open_layer",true)
		packet.add_child(packet_opened_art)
	hint = board.label("Abre con el mouse" if sealed else "Carta %d de %d" % [revealed+1,cards.size()],22,board.GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0,524)
	hint.size = Vector2(size.x,38)
	add_child(hint)
	set_meta("pack_reveal",true)
	show_singular_if_needed()

func show_singular_if_needed():
	if sealed or not preload("res://deck_rules.gd").canonical(cards[revealed]) in SINGULARS or not is_instance_valid(current):return
	if singular_shown:
		# Container layout may resize this instance just after _ready. Continue the
		# existing sweep on its new card node without replaying sound or arrival.
		if singular_started_at >= 0:
			var elapsed = float(Time.get_ticks_msec() - singular_started_at) / 1000.0
			if elapsed < 1.25: apply_singular_visual(elapsed)
		return
	singular_shown = true
	singular_started_at = Time.get_ticks_msec()
	singular_arrived.emit(opening_id+":"+str(revealed))
	apply_singular_visual(0.0)
	board.sound.play_effect("singular")

func apply_singular_visual(elapsed):
	current.set_meta("singular_highlight",cards[revealed])
	var front_texture=current.texture
	for child in layers.get_children():
		if child!=current:child.hide()
	current.pivot_offset=Vector2(148,201)
	current.set_meta("singular_spin",true)
	caption.hide()
	animating=true
	var spin=current.create_tween()
	spin.tween_method(update_singular_pose.bind(front_texture),elapsed,1.25,maxf(1.25-elapsed,.01))
	spin.tween_callback(func():
		if is_instance_valid(current):current.texture=front_texture;current.scale=Vector2.ONE
		if is_instance_valid(layers):
			for child in layers.get_children():child.show()
		if is_instance_valid(caption):caption.show()
		animating=false
	)
	var shine = ShaderMaterial.new()
	shine.shader = SingularShader
	var initial = lerpf(-0.3,1.4,clampf(elapsed / .8,0.0,1.0))
	shine.set_shader_parameter("shine_progress",initial)
	current.material = shine
	var sparkles = Sparkles.new()
	sparkles.elapsed = elapsed
	sparkles.position = origin
	sparkles.size = Vector2(296,402)
	add_child(sparkles)
	var sweep = current.create_tween()
	sweep.tween_method(func(value): shine.set_shader_parameter("shine_progress",value),initial,1.4,maxf(.8-elapsed,.01))

func update_singular_pose(elapsed,front_texture):
	if not is_instance_valid(current):return
	var progress=clampf(elapsed/1.25,0.0,1.0)
	var angle=clampf((elapsed-.15)/.95,0.0,1.0)*TAU
	var face=cos(angle)
	var zoom=1.26
	if elapsed<.15:zoom=lerpf(1.0,1.26,1.0-pow(1.0-clampf(elapsed/.15,0.0,1.0),2))
	elif elapsed>1.10:zoom=lerpf(1.26,1.0,clampf((elapsed-1.10)/.15,0.0,1.0))
	current.scale=Vector2(maxf(absf(face),.025)*zoom,zoom)
	current.texture=front_texture if face>=0 else board.asset_texture("dorso.jpg")
	for child in current.get_children():
		if child is CanvasItem:child.visible=face>=0
	current.set_meta("singular_spin_progress",progress)

func _gui_input(event):
	if animating or revealed >= cards.size(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if Rect2(origin-Vector2(30,30),Vector2(356,470)).has_point(event.position):
				if return_tween != null and return_tween.is_valid(): return_tween.kill()
				dragging = true
				travel = 0
				accept_event()
		elif dragging:
			dragging = false
			if absf(travel) >= (65 if sealed else 110):
				if sealed: open_packet()
				else: slide_card()
			elif sealed:
				hint.text = "Abre con el mouse"
			elif is_instance_valid(current):
				return_tween = create_tween().set_parallel(true)
				return_tween.tween_property(current,"position",origin,.18)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		travel += event.relative.x
		if sealed:
			# Gesture progress only: the printed wrapper never moves or rotates.
			hint.text = "Suelta para abrir" if absf(travel) >= 65 else "Abre con el mouse"
		elif is_instance_valid(current):
			current.position.x = origin.x + travel
			current.rotation = 0.0
		accept_event()

func set_opening_stage(value):
	opening_stage = value
	set_meta("opening_stage",value)
	opening_stage_changed.emit(value)

func open_packet():
	if animating or not sealed or not is_instance_valid(packet): return
	animating = true
	dragging = false
	await board.sound.wait_for_pack_silence()
	if not is_inside_tree() or is_queued_for_deletion(): return
	sealed = false
	# Commit before awaiting the tween. Refresh/cancel resumes open presentation
	# without repeating the tear or sending another inventory transaction.
	packet_opened.emit()
	set_opening_stage("transition")
	caption.text = "Abriendo sobre…"
	hint.text = ""
	board.sound.play_effect("sobre_abrir")
	for child in layers.get_children(): child.visible = true
	layers.modulate.a = 0.0
	var flash = ColorRect.new()
	flash.color = Color(1.0,1.0,1.0,0.18)
	flash.size = Vector2(302,48)
	flash.position = Vector2((PACK_ART_SIZE.x-flash.size.x)*.5,48)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	packet.add_child(flash)
	var crossfade = create_tween().set_parallel(true)
	crossfade.tween_property(packet_closed,"modulate:a",0.0,.16)
	crossfade.tween_property(packet_opened_art,"modulate:a",1.0,.16)
	crossfade.tween_property(flash,"modulate:a",1.0,.07)
	crossfade.tween_property(flash,"modulate:a",0.0,.09).set_delay(.07)
	await crossfade.finished
	set_opening_stage("opened")
	var reveal = create_tween()
	reveal.tween_interval(1.12)
	reveal.tween_property(packet,"modulate:a",0.0,.28)
	reveal.parallel().tween_property(layers,"modulate:a",1.0,.28)
	await reveal.finished
	animating = false
	set_opening_stage("cards")
	rebuild()

func slide_card():
	if animating or sealed or not is_instance_valid(current): return
	animating = true
	current.rotation = 0.0
	board.sound.play_effect("sobre_carta")
	var direction = 1.0 if travel >= 0 else -1.0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(current,"position",origin+Vector2(direction*520,0),.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(current,"modulate:a",0.0,.20)
	await tween.finished
	revealed += 1
	singular_shown=false;singular_started_at=-1
	animating = false
	progress_changed.emit(revealed)
	if revealed >= cards.size():
		finished.emit()
	else:
		rebuild()
