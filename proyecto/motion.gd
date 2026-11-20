extends CanvasLayer
const CardImage = preload("res://card_image.gd")
## Presentación: consume eventos; no modifica cartas ni decisiones del motor.
signal finished
var busy = false
var speed = 1.0
var board
var root
var before = {}
var after = {}
var events = []
var held = {}
var last_move = {}
var tweens = []
var trace = []
var ghosts = []
var block_pairs = {}
var block_lines = {}
var block_line_root

func clear_block_links():
	block_pairs.clear()
	block_lines.clear()
	if is_instance_valid(block_line_root):
		block_line_root.hide()
		block_line_root.queue_free()
	block_line_root = null

func sync_block_pairs():
	block_pairs.clear()
	if board.game.phase not in ["blocks", "events", "resolving"] or board.game.winner != -1: return
	for attacker in board.game.blocks:
		var blocker = board.game.blocks[attacker]
		if board.game.location(attacker).get("zone", "") == "attack" and board.game.location(blocker).get("zone", "") == "defense":
			block_pairs[attacker] = blocker

func block_center(uid, layout):
	# Follow the real animated card, including movement to its final zone.
	for i in range(ghosts.size()-1, -1, -1):
		var ghost = ghosts[i]
		if is_instance_valid(ghost) and not ghost.is_queued_for_deletion() and ghost.get_meta("motion_uid", -1) == uid:
			return ghost.position + ghost.size * .5
	var entry = layout.get("cards", {}).get(uid, {})
	if entry.is_empty() and busy: entry = before.get("cards", {}).get(uid, {})
	return entry.get("rect", Rect2()).get_center()

func _process(_delta):
	if board == null: return
	if board.screen != "table" or not board.started or (board.game.winner != -1 and not board.presenting):
		clear_block_links()
		return
	if not busy: sync_block_pairs()
	if block_pairs.is_empty():
		clear_block_links()
		return
	if not is_instance_valid(block_line_root):
		block_line_root = Node2D.new()
		block_line_root.z_index = -1
		add_child(block_line_root)
	block_line_root.visible = not board.modal_open or board.presenting
	for attacker in block_lines.keys():
		if not block_pairs.has(attacker):
			block_lines[attacker].hide()
			block_lines[attacker].queue_free()
			block_lines.erase(attacker)
	var layout = board.capture_layout()
	for attacker in block_pairs:
		if not block_lines.has(attacker):
			var line = Line2D.new()
			line.width = 3
			line.default_color = Color("e7c68c")
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.set_meta("block_link", true)
			block_line_root.add_child(line)
			block_lines[attacker] = line
		var blocker = block_pairs[attacker]
		block_lines[attacker].set_meta("attacker", attacker)
		block_lines[attacker].set_meta("blocker", blocker)
		block_lines[attacker].points = PackedVector2Array([block_center(blocker, layout), block_center(attacker, layout)])

func key(p, zone): return "%d:%s" % [p, zone]

func begin(view, packet, old_layout):
	cancel(false, true)
	board = view
	if board.game.phase in ["blocks", "events", "resolving"] and board.game.winner == -1: sync_block_pairs()
	before = old_layout
	events = packet
	busy = true
	trace.clear()
	last_move.clear()
	root = Control.new()
	root.size = board.get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shield = ColorRect.new()
	shield.color = Color.TRANSPARENT
	shield.size = root.size
	# Action/drag guards already prevent playing during presentation. Let the
	# graveyard/burned inspection buttons remain reachable beneath this layer.
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield)
	for i in range(events.size()):
		var e = events[i]
		if e.kind == "move": last_move[e.uid] = i
	var seen = {}
	for i in range(events.size()):
		var e = events[i]
		if e.kind != "move" or seen.has(e.uid): continue
		seen[e.uid] = true
		var entry = before.get("cards", {}).get(e.uid, {})
		if entry.is_empty() or e.from == "deck": continue
		var ghost = make_ghost(e.uid, initial_back(e), entry.rect,str(e.get("face_code","")))
		held[i] = ghost

func play(new_layout):
	after = new_layout
	var timeline = create_tween()
	tweens.append(timeline)
	var i = 0
	while i < events.size():
		var e = events[i]
		if e.kind == "move":
			var group = [i]
			var j = i + 1
			while j < events.size():
				var other = events[j]
				if played_card(e) or played_card(other) or other.kind != "move" or other.player != e.player or other.from != e.from or other.to != e.to or other.get("via", "") != e.get("via", ""): break
				group.append(j)
				j += 1
			timeline.tween_callback(fly_group.bind(group))
			var duration = 0.62 if e.has("via") else 0.36
			if played_card(e):
				timeline.tween_interval(0.4 + 0.60 * speed + 0.04)
			else:
				timeline.tween_interval((duration + (group.size() - 1) * 0.065) * speed + 0.04)
			i = j
			continue
		timeline.tween_callback(effect.bind(e))
		timeline.tween_interval((0.48 if e.kind in ["attack", "block", "shuffle", "reorder"] else 0.28) * speed + 0.04)
		i += 1
	timeline.tween_callback(complete)

func zone_rect(layout, p, zone):
	if zone == "stack":
		var board_rect = layout.get("zones", {}).get(key(board.human, "board"), Rect2(Vector2(600, 380), Vector2(400, 240)))
		return Rect2(board_rect.get_center() - Vector2(44, 60), Vector2(88, 120))
	var rect = layout.get("zones", {}).get(key(p, zone), Rect2())
	if rect.size == Vector2.ZERO and zone == "domain": rect = layout.get("zones", {}).get(key(-1, zone), Rect2())
	if rect.size == Vector2.ZERO: rect = after.get("zones", {}).get(key(p, zone), Rect2(Vector2(760, 470), Vector2(80, 110)))
	return rect

func card_rect(layout, uid, p, zone, source = false):
	if zone == "deck" or zone == "events": return zone_rect(layout, p, zone)
	var info = layout.get("cards", {}).get(uid, {})
	if not info.is_empty():
		if source or info.zone == zone or (zone == "attack" and info.zone == "draft_attack"): return info.rect
	return zone_rect(layout, p, zone)

func initial_back(e): return e.from == "deck" or (e.from == "hand" and e.player != board.human)
func final_back(e): return e.to == "deck" or (e.to == "hand" and e.player != board.human)
func may_show_face(e): return not initial_back(e) or not final_back(e) or e.get("reveal", false)

func played_card(e):
	if e.get("kind", "") != "move": return false
	var code = str(e.get("face_code", ""))
	if code.is_empty() and board.game.instances.has(e.uid): code = board.game.printed_code(e.uid)
	if not board.game.catalog.has(code) or board.game.catalog[code].clase == "Recurso": return false
	if e.has("played"): return e.played == true
	# Visual compatibility with an unchanged 1.3 host; never enlarge draws/discards.
	return e.from == "hand" and (e.to in ["defense", "object", "domain", "stack"] or e.get("via", "") == "events")

func make_ghost(uid, back, rect, face_code = ""):
	var ghost = CardImage.new()
	ghost.texture = board.asset_texture("dorso.jpg") if back else (board.texture_code(face_code) if board.game.catalog.has(face_code) else board.texture(uid))
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(112, 152)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.position = rect.get_center() - ghost.size * 0.5
	ghost.scale = Vector2.ONE * clampf(rect.size.x / 112.0, 0.28, 1.15)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.set_meta("motion_uid", uid)
	root.add_child(ghost)
	ghosts.append(ghost)
	return ghost

func fly_group(indices):
	for n in range(indices.size()):
		var i = indices[n]
		var e = events[i]
		var start = card_rect(before, e.uid, e.player, e.from, true)
		if e.from == "deck": start = zone_rect(after, e.player, "deck")
		var end = card_rect(after, e.uid, e.player, e.to)
		var ghost = held.get(i)
		if not is_instance_valid(ghost): ghost = make_ghost(e.uid, initial_back(e), start,str(e.get("face_code","")))
		ghost.z_index = 20 + n
		if played_card(e):
			fly_play(i, e, start, end, ghost)
			continue
		var front = (board.texture_code(str(e.face_code)) if board.game.catalog.has(str(e.get("face_code",""))) else board.texture(e.uid)) if may_show_face(e) else null
		var back = board.asset_texture("dorso.jpg")
		var middle = zone_rect(after, board.human, "board").get_center() if e.has("via") else Vector2.ZERO
		var duration = (0.62 if e.has("via") else 0.36) * speed
		var tween = create_tween()
		tweens.append(tween)
		trace.append({"kind":"move", "uid":e.uid, "player":e.player, "from":e.from, "to":e.to, "face_visible":may_show_face(e)})
		tween.tween_interval(n * 0.065 * speed + 0.001)
		tween.tween_callback(board.sound.play_move.bind(e))
		tween.tween_method(func(t):
			if not is_instance_valid(ghost): return
			var center = start.get_center().lerp(end.get_center(), t)
			if e.has("via"):
				center = start.get_center().lerp(middle, t / 0.52) if t < 0.52 else middle.lerp(end.get_center(), (t - 0.52) / 0.48)
			center.y -= sin(PI * t) * 32.0
			ghost.position = center - ghost.size * 0.5
			var s = lerpf(clampf(start.size.x / 112.0, 0.28, 1.15), clampf(end.size.x / 112.0, 0.28, 1.15), t) + sin(PI * t) * 0.18
			var flip = 1.0
			var show_front = not initial_back(e)
			if front != null:
				if initial_back(e):
					show_front = t >= 0.36
					if absf(t - 0.36) < 0.08: flip = absf(t - 0.36) / 0.08
				if final_back(e):
					if t >= 0.83: show_front = false
					if absf(t - 0.83) < 0.07: flip = absf(t - 0.83) / 0.07
			else: show_front = false
			ghost.texture = front if show_front else back
			ghost.scale = Vector2(s * maxf(0.02, flip), s)
			ghost.rotation = sin(PI * t) * 0.045
		, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			if is_instance_valid(ghost): ghost.queue_free()
			board.visual_move_finished(e)
			if last_move.get(e.uid) == i: board.reveal_visual_uid(e.uid)
		)

func fly_play(index, e, start, end, ghost):
	var code = str(e.get("face_code", ""))
	ghost.texture = board.texture_code(code) if board.game.catalog.has(code) else board.texture(e.uid)
	ghost.rotation = 0
	var middle = root.size * 0.5
	var large_scale = minf(3.0, root.size.y * 0.64 / ghost.size.y)
	var initial_scale = clampf(start.size.x / 112.0, 0.28, 1.15)
	var final_scale = clampf(end.size.x / 112.0, 0.28, 1.15)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.24)
	shade.size = root.size
	shade.z_index = 16
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	trace.append({"kind":"played_zoom", "uid":e.uid, "hold_seconds":0.4, "player":e.player})
	var tween = create_tween()
	tweens.append(tween)
	board.sound.play_move(e)
	tween.tween_method(func(t):
		if not is_instance_valid(ghost): return
		ghost.position = start.get_center().lerp(middle, t) - ghost.size * 0.5
		ghost.scale = Vector2.ONE * lerpf(initial_scale, large_scale, t)
	, 0.0, 1.0, 0.24 * speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): ghost.set_meta("played_zoom_hold", true); ghost.set_meta("hold_started_ms", Time.get_ticks_msec()))
	# Short readable pause, independent of movement speed.
	tween.tween_interval(0.4)
	tween.tween_callback(func():
		ghost.set_meta("played_zoom_hold", false)
		trace.append({"kind":"played_zoom_end", "uid":e.uid, "hold_ms":Time.get_ticks_msec()-int(ghost.get_meta("hold_started_ms"))})
	)
	tween.tween_method(func(t):
		if not is_instance_valid(ghost): return
		ghost.position = middle.lerp(end.get_center(), t) - ghost.size * 0.5
		ghost.scale = Vector2.ONE * lerpf(large_scale, final_scale, t)
		if is_instance_valid(shade): shade.color.a = 0.24 * (1.0-t)
	, 0.0, 1.0, 0.36 * speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		if is_instance_valid(ghost): ghost.queue_free()
		if is_instance_valid(shade): shade.queue_free()
		board.visual_move_finished(e)
		if last_move.get(e.uid) == index: board.reveal_visual_uid(e.uid)
	)

func flash(rect, color, duration = 0.3):
	var p = Panel.new()
	p.position = rect.position - Vector2(4, 4)
	p.size = rect.size + Vector2(8, 8)
	p.pivot_offset = p.size * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color, 0.12)
	s.border_color = color
	s.set_border_width_all(3)
	s.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", s)
	root.add_child(p)
	var t = create_tween().set_parallel(true)
	tweens.append(t)
	t.tween_property(p, "modulate:a", 0.0, duration * speed)
	t.tween_property(p, "scale", Vector2(1.12, 1.12), duration * speed)
	t.chain().tween_callback(p.queue_free)

func pulse_card(uid, target_center, amount = 30.0, shake = false):
	var loc = board.game.location(uid)
	if loc.is_empty(): return
	var rect = card_rect(after, uid, loc.player, loc.zone)
	board.hide_visual_uid(uid)
	var ghost = make_ghost(uid, false, rect)
	var start = rect.get_center()
	var direction = (target_center - start).normalized()
	var tween = create_tween()
	tweens.append(tween)
	tween.tween_method(func(t):
		var offset = Vector2(sin(t * PI * 6.0) * 6.0, 0) if shake else direction * sin(PI * t) * amount
		ghost.position = start + offset - ghost.size * 0.5
	, 0.0, 1.0, 0.42 * speed)
	tween.tween_callback(func():
		if is_instance_valid(ghost): ghost.queue_free()
		board.reveal_visual_uid(uid)
	)

func effect(e):
	trace.append({"kind":e.kind})
	board.sound.play_action(e)
	match e.kind:
		"attack":
			var target = zone_rect(after, 1 - e.player, "attack").get_center()
			for uid in e.uids:
				pulse_card(uid, target, 34.0)
				var loc = board.game.location(uid)
				flash(card_rect(after, uid, loc.player, loc.zone), Color("efbd78"), 0.42)
		"block":
			var defender = card_rect(after, e.uid, e.player, "defense")
			var attacker = card_rect(after, e.attacker, 1 - e.player, "attack")
			pulse_card(e.uid, attacker.get_center(), 38.0)
			pulse_card(e.attacker, defender.get_center(), 0.0, true)
			flash(defender, Color("bfe3dc"), 0.44)
			flash(attacker, Color("efbd78"), 0.44)
		"shuffle", "reorder":
			var rect = zone_rect(after, e.player, "deck")
			for n in range(3):
				var ghost = make_ghost(-1, true, rect)
				var t = create_tween()
				tweens.append(t)
				t.tween_method(func(progress):
					var offset = sin(progress * PI * 4.0 + n * 0.7) * sin(progress * PI)
					ghost.position = rect.get_center() - ghost.size * 0.5 + Vector2(offset * 24.0, n * 2.0)
					ghost.rotation = offset * 0.14
				, 0.0, 1.0, 0.44 * speed)
				t.tween_callback(ghost.queue_free)
			flash(rect, Color("dca46d"), 0.44)
		"damage":
			var rect = zone_rect(after, e.player, "deck")
			flash(rect, Color("dc795b"), 0.26)
			var text = Label.new()
			text.text = "−%d" % int(e.amount)
			text.add_theme_font_size_override("font_size", 34)
			text.add_theme_color_override("font_color", Color("493720"))
			text.add_theme_color_override("font_outline_color", Color("fffaf0"))
			text.add_theme_constant_override("outline_size", 2)
			text.position = rect.get_center() + Vector2(-15, -25)
			root.add_child(text)
			var t = create_tween().set_parallel(true)
			tweens.append(t)
			t.tween_property(text, "position:y", text.position.y - 26, 0.26 * speed)
			t.tween_property(text, "modulate:a", 0.0, 0.26 * speed)
			t.chain().tween_callback(text.queue_free)

func release_root():
	# Hide and detach synchronously: this layer sits above the result overlay.
	# queue_free alone leaves its last texture drawable until the frame ends.
	if is_instance_valid(root):
		root.hide()
		if root.get_parent() == self: remove_child(root)
		root.queue_free()
	root = null

func complete():
	# A low frame rate can leave a child tween one frame behind the timeline.
	# Stop it before releasing its visual nodes (also when restarting quickly).
	for t in tweens:
		if t.is_valid(): t.kill()
	busy = false
	release_root()
	held.clear()
	ghosts.clear()
	tweens.clear()
	if board.game.winner != -1 or board.game.phase not in ["blocks", "events", "resolving"]: clear_block_links()
	finished.emit()

func cancel(emit_done = true, keep_block_links = false):
	for t in tweens:
		if t.is_valid(): t.kill()
	tweens.clear()
	release_root()
	if not keep_block_links: clear_block_links()
	held.clear()
	ghosts.clear()
	var was_busy = busy
	busy = false
	if was_busy and emit_done: finished.emit()
