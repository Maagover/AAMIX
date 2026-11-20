extends Node
const PackReveal = preload("res://pack_reveal.gd")
const PackArt = preload("res://pack_art.gd")
const NormalPackArt = preload("res://normal_pack_art.gd")
const HalloweenPackArt=preload("res://halloween_pack_art.gd")
const RestosArt = preload("res://restos_art.gd")
const GiftCardImage = preload("res://card_image.gd")
const EventArt = preload("res://event_art.gd")
var mission_tab = "daily"
var selected_event = ""
var board
var code_text = ""
var opening_request = ""
var opening_request_kind = "tc"
var opening_in_flight = false
var opening_request_all = false
var reveal_id = ""
var reveal_index = 0
var reveal_open = false
var singular_seen_openings = {}
var receipts = []
var active_receipt = {}
var account_owner = ""
var pumping = false
var retry_after = 0
var match_status = ""
var pending_challenge_rewards = []
var prepared_receipt = {}
var prepare_pending = {}
var preparing = false
var achievement_shade
var preparation_generation = 0
var pending_bonus_notices = []
var bonus_toast

func setup(owner_board):
	board = owner_board
	return self

func _process(_delta):
	if board == null: return
	var current = board.account.player_id()
	if current != account_owner:
		preparation_generation += 1
		prepared_receipt = {}
		prepare_pending = {}
		preparing = false
		account_owner = current
		receipts.clear()
		active_receipt = {}
		opening_request = ""
		opening_request_kind = "tc"
		opening_in_flight = false
		reveal_id = ""
		reveal_index = 0
		reveal_open = false
		singular_seen_openings.clear()
		match_status = ""
		pending_challenge_rewards.clear()
		achievement_shade = null
		pending_bonus_notices.clear()
		if is_instance_valid(bonus_toast): bonus_toast.queue_free()
	if board.collection.loaded and board.screen in ["home", "missions", "event"] and not current.is_empty():
		board.collection.expire_events()
		if not pumping and not preparing and not board.collection.busy and not board.account.busy and Time.get_ticks_msec() >= board.collection.event_refresh_tick:
			board.collection.sync_events()
	# Completion must survive leaving the table during its final animation.
	if not active_receipt.is_empty() and board.started and board.game.winner != -1 and not active_receipt.complete:
		match_finished(board.game.winner == board.human)
	if not current.is_empty() and not pumping and Time.get_ticks_msec() >= retry_after:
		pump_receipts()
	if not pending_challenge_rewards.is_empty() and not pumping and not board.modal_open and board.screen == "challenges":
		var reward = pending_challenge_rewards.pop_front()
		if reward.owner == current:
			board.celebrate_reward("¡Desafío superado!","%d %s TC\nEn Mis sobres." % [reward.packs,"sobre" if reward.packs == 1 else "sobres"],PackArt.texture(false))
	present_achievement()
	if not pending_bonus_notices.is_empty() and not board.presenting and ((board.screen=="table" and board.game.winner!=-1) or (board.screen=="challenges" and not board.modal_open)):
		var notice = pending_bonus_notices.pop_front()
		if notice.owner==current: show_challenge_bonus(notice.amount)

func show_challenge_bonus(amount):
	if is_instance_valid(bonus_toast): bonus_toast.queue_free()
	bonus_toast = board.panel(board.notice_layer,board.PANEL,"gold")
	bonus_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_toast.set_meta("challenge_repeat_bonus",int(amount))
	bonus_toast.position = Vector2(board.get_viewport_rect().size.x*.5-106,board.get_viewport_rect().size.y-82)
	bonus_toast.custom_minimum_size = Vector2(212,42)
	var row = board.box(bonus_toast,false,8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon = RestosArt.view(25)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var caption = board.centered_label("+%d Restos" % int(amount),18,board.GOLD)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var tween = bonus_toast.create_tween()
	tween.tween_interval(3)
	tween.tween_property(bonus_toast,"modulate:a",0.0,.4)
	tween.tween_callback(bonus_toast.queue_free)

func match_started(deck_id, challenge_stage = 0):
	if board.guest or not board.account.signed_in(): return
	account_owner = board.account.player_id()
	var receipt
	if not prepared_receipt.is_empty() and prepared_receipt.account_owner == account_owner and prepared_receipt.deck_id == deck_id and int(prepared_receipt.challenge_stage) == int(challenge_stage) and bool(prepared_receipt.get("event_battle",false)) == board.active_event_battle:
		receipt = prepared_receipt
		prepared_receipt = {}
	else:
		# Legacy callers still register their existing flow with the same receipt pump.
		receipt = {"request_id":board.collection.request_id(),"deck_id":deck_id,"event_battle":board.active_event_battle,"challenge_stage":clampi(int(challenge_stage),0,board.CHALLENGES.size()),"account_owner":account_owner,"begun":false,"complete":false,"reported":false,"victory":false}
	receipts.append(receipt)
	active_receipt = receipt
	retry_after = 0

func prepare_match(deck_id, challenge_stage = 0, event_battle = false):
	if board.guest or not board.account.signed_in() or preparing or pumping or board.collection.busy or board.account.busy: return {}
	var owner = board.account.player_id()
	if owner != account_owner:
		preparation_generation += 1
		account_owner = owner
		receipts.clear()
		active_receipt = {}
		prepared_receipt = {}
		prepare_pending = {}
	var stage = clampi(int(challenge_stage),0,board.CHALLENGES.size())
	if not prepared_receipt.is_empty() and prepared_receipt.account_owner == owner and prepared_receipt.deck_id == str(deck_id) and int(prepared_receipt.challenge_stage) == stage and bool(prepared_receipt.get("event_battle",false)) == event_battle:
		return prepared_receipt.match_deck.duplicate(true)
	if prepare_pending.is_empty() or prepare_pending.get("deck_id", "") != str(deck_id) or int(prepare_pending.get("challenge_stage", -1)) != stage or bool(prepare_pending.get("event_battle",false)) != event_battle:
		prepare_pending = {"request_id":board.collection.request_id(),"deck_id":str(deck_id),"event_battle":event_battle,"challenge_stage":stage,"account_owner":owner}
	var pending = prepare_pending.duplicate(true)
	var expected_generation = preparation_generation
	var inventory_generation = board.collection.generation
	preparing = true
	match_status = "Preparando tu mazo…"
	var ok = await board.collection.begin_match(pending.request_id,pending.deck_id,stage,event_battle)
	if expected_generation == preparation_generation: preparing = false
	if expected_generation != preparation_generation or inventory_generation != board.collection.generation or owner != board.account.player_id(): return {}
	if not ok:
		if board.collection.last_http_code >= 400 and board.collection.last_http_code < 500 and board.collection.last_http_code not in [408,429]: prepare_pending = {}
		match_status = board.collection.status
		return {}
	var match_id = str(board.collection.last_reply.get("match_id", ""))
	var deck = board.collection.last_reply.get("match_deck", {})
	# Compatibility for the old service only permits its immutable base lists.
	if not deck is Dictionary or deck.is_empty():
		deck = {}
		for owned in board.collection.decks:
			if str(owned.get("id", "")) == str(deck_id) and owned.get("custom", false) != true:
				deck = owned.duplicate(true)
				break
	if match_id.is_empty() or deck.is_empty() or str(deck.get("id", "")) != str(deck_id):
		match_status = "No pudimos confirmar el mazo de la partida. Reintenta para recuperar la confirmación."
		return {}
	if deck.get("custom", false) == true:
		var validation = preload("res://deck_rules.gd").validate(deck,board.game.catalog)
		if deck.get("draft", false) == true or not validation.ok:
			match_status = "El mazo confirmado no está listo para jugar. Recarga Mis Mazos."
			return {}
	prepared_receipt = pending.duplicate(true)
	prepared_receipt.merge({"begun":true,"match_id":match_id,"match_deck":deck.duplicate(true),"complete":false,"reported":false,"victory":false},true)
	prepare_pending = {}
	match_status = ""
	return deck.duplicate(true)

func match_finished(victory):
	if board.practice_match:return
	if active_receipt.is_empty() or active_receipt.account_owner != board.account.player_id(): return
	active_receipt.complete = true
	active_receipt.victory = victory
	if not active_receipt.has("metrics"):
		active_receipt.metrics={"deck_remaining":board.game.players[board.human].deck.size(),"allies_lost":board.game.allies_lost[board.human]}
	retry_after = 0

func pump_receipts():
	if preparing or board.collection.busy or board.account.busy: return
	var receipt = null
	for item in receipts:
		if not item.reported and item.account_owner == account_owner and (not item.begun or item.complete):
			receipt = item
			break
	if receipt == null: return
	pumping = true
	var expected_owner = account_owner
	var ok = false
	if not receipt.begun:
		ok = await board.collection.begin_match(receipt.request_id,receipt.deck_id,receipt.challenge_stage,bool(receipt.get("event_battle",false)))
		if ok:
			receipt.begun = true
			receipt["match_id"] = board.collection.last_reply.get("match_id", "")
	else:
		ok = await board.collection.finish_match(receipt.match_id,receipt.victory,receipt.get("metrics",{}))
		if ok:
			receipt.reported = true
			var bonus = maxi(0,int(board.collection.last_reply.get("challenge_repeat_restos",0)))
			if bonus>0 and expected_owner==account_owner: pending_bonus_notices.append({"owner":expected_owner,"amount":bonus})
			var reward_packs = maxi(0,int(board.collection.last_reply.get("challenge_reward_packs",0)))
			if reward_packs > 0 and expected_owner == account_owner:
				pending_challenge_rewards.append({"owner":expected_owner,"packs":reward_packs,"stage":receipt.challenge_stage})
	if expected_owner == account_owner:
		match_status = "" if ok else "No pudimos registrar la partida. Conserva el juego abierto y pulsa Reintentar en Misiones."
		retry_after = Time.get_ticks_msec() + (0 if ok else 15000)
	pumping = false
	if expected_owner == account_owner and board.screen in ["missions","challenges"]: board.render()

func inventory_changed():
	if board.collection.loaded and board.collection.owner_id == board.account.player_id() and board.collection.pending_opening == null and not reveal_id.is_empty():
		opening_request = ""
		opening_request_kind = "tc"
		reveal_id = ""
		reveal_index = 0
		reveal_open = false

func open_screen(name):
	if board.guest or not board.account.signed_in(): return
	board.collection.status = ""
	board.screen = name
	board.render()
	if name in ["missions", "event"] and not board.collection.busy: board.collection.load_inventory()

func render_screen():
	if board.guest or not board.account.signed_in():
		board.screen = "account"
		board.render_account()
		return
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,38)
	board.add_child(margin)
	var outer = board.box(margin,true,18)
	var top = board.box(outer,false,20)
	top.add_child(board.home_logo(210,50))
	var titles = {"gift_code":"Código de regalo","missions":"Misiones","packs":"Mis sobres", "event":"Evento"}
	top.add_child(board.fill(board.label(titles.get(board.screen,"Recompensas"),30,board.GOLD)))
	if board.screen != "gift_code": top.add_child(board.reload_button(board.collection.load_inventory,board.collection.busy or board.account.busy))
	top.add_child(board.button("Inicio",board.go_home))
	if board.screen in ["missions", "event"]: render_mission_tabs(outer)
	var body
	if board.screen == "gift_code" or board.screen == "packs":
		var center = CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer.add_child(center)
		body = board.box(center,true,17)
		body.custom_minimum_size.x = 780
	else:
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		outer.add_child(scroll)
		var padding = MarginContainer.new()
		padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		padding.add_theme_constant_override("margin_right",24)
		padding.set_meta("mission_scroll_padding",true)
		scroll.add_child(padding)
		body = board.box(padding,true,10)
		board.fill(body)
	if board.screen == "gift_code": render_code(body)
	elif board.screen == "missions": render_mission(body)
	elif board.screen == "event": render_event(body)
	else: render_packs(body)
	if not board.collection.status.is_empty():
		var status = board.label(board.collection.status,17,board.MINT)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if board.screen == "gift_code" else HORIZONTAL_ALIGNMENT_LEFT
		outer.add_child(status)

func centered(body, text, size = 21, color = null):
	var node = board.label(text,size,board.TEXT if color == null else color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(node)
	return node

func render_code(body):
	var icon_center = CenterContainer.new(); body.add_child(icon_center)
	icon_center.add_child(board.UIIcons.floating("gift",100,board.animations_enabled))
	centered(body,"Ingresa tu código de regalo",29,board.GOLD)
	var field = LineEdit.new()
	field.placeholder_text = "Código de regalo"
	field.text = code_text
	field.max_length = 48
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(680,52)
	field.editable = not board.collection.busy
	field.text_submitted.connect(func(_value): redeem())
	body.add_child(field)
	var submit = board.button("Canjear",redeem,board.collection.busy or code_text.strip_edges().is_empty(),true)
	field.text_changed.connect(func(value):
		code_text = value
		submit.disabled = board.collection.busy or value.strip_edges().is_empty()
	)
	body.add_child(submit)

func redeem():
	if board.collection.busy or code_text.strip_edges().is_empty(): return
	var ok = await board.collection.redeem_code(code_text)
	if ok:
		code_text = ""
		if board.collection.last_reply.get("already_redeemed", false):
			board.collection.status = "ya has canjeado este regalo"
			board.render()
			return
		board.render()
		show_code_reward(board.collection.last_reply)

func code_reward_items(reply):
	var items = []
	var halloween_count=maxi(0,int(reply.get("reward_halloween_packs",0)))
	if halloween_count>0:items.append({"kind":"halloween_pack","amount":halloween_count,"caption":"%d Sobre%s AAMIX Halloween" % [halloween_count,"" if halloween_count==1 else "s"],"texture":HalloweenPackArt.texture(false)})
	var avatar_code = str(reply.get("reward_avatar",""))
	if board.game.catalog.has(avatar_code):
		items.append({"kind":"avatar","amount":1,"code":avatar_code,"caption":"Foto de perfil\n"+board.game.catalog[avatar_code].nombre,"texture":board.texture_code(avatar_code)})
	var design = str(reply.get("reward_cover", reply.get("reward_design", "")))
	if design in preload("res://deck_rules.gd").CUSTOM_COVERS:
		items.append({"kind":"deck_design","amount":1,"caption":"Diseño desbloqueado\n" + preload("res://deck_rules.gd").cover_name(design),"texture":board.deck_cover_texture({"custom":true,"portada":design})})
	var deck_id = reply.get("reward_deck_id")
	if deck_id != null and not str(deck_id).is_empty():
		items.append({"kind":"deck","amount":1,"caption":str(reply.get("reward_name", "Mazo")),"texture":board.deck_cover_texture(str(deck_id))})
	else:
		for entry in reply.get("reward_cards", []):
			var code = str(entry.get("codigo", ""))
			var quantity = maxi(0, int(entry.get("cantidad", 0)))
			var definition = board.game.catalog.get(code, {})
			if quantity > 0:
				items.append({"kind":"card","amount":quantity,"caption":"%d × %s" % [quantity, str(definition.get("nombre", "Carta"))],"texture":board.texture_code(code)})
	var count = maxi(0, int(reply.get("reward_packs", 0)))
	if count > 0:
		items.append({"kind":"tc_pack","amount":count,"caption":"%d sobre%s TC" % [count, "" if count == 1 else "s"],"texture":PackArt.texture(false)})
	count = maxi(0, int(reply.get("reward_restos", 0)))
	if count > 0:
		items.append({"kind":"restos","amount":count,"caption":"%d Restos" % count,"texture":RestosArt.texture()})
	count = maxi(0, int(reply.get("reward_normal_packs", 0)))
	if count > 0:
		items.append({"kind":"normal_pack","amount":count,"caption":"%d carta%s aleatoria%s" % [count, "" if count == 1 else "s", "" if count == 1 else "s"],"texture":NormalPackArt.texture(false)})
	return items

func show_code_reward(reply, heading = ""):
	var items = code_reward_items(reply)
	var title = "Regalo ya obtenido" if reply.get("already_redeemed", false) else "¡Regalo recibido!"
	if items.any(func(item): return item.kind == "deck_design"):
		title = "Diseño ya desbloqueado" if reply.get("already_redeemed", false) else "¡Diseño desbloqueado!"
	if not heading.is_empty(): title = heading
	if items.is_empty():
		board.celebrate_reward(title, str(reply.get("reward_name", "Recompensa añadida.")))
		return
	var center = board.overlay("reward")
	var shade = center.get_parent()
	shade.set_meta("gift_reward_bundle", items.map(func(item): return item.kind))
	var body = board.box(board.panel(center), true, 18)
	body.custom_minimum_size = Vector2(710, 330)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(board.centered_label(title, 35, board.GOLD))
	var row = board.box(body, false, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in items:
		var column = board.box(row, true, 10)
		column.custom_minimum_size.x = 184
		column.set_meta("gift_reward_kind", item.kind)
		column.set_meta("gift_reward_amount", item.amount)
		var texture = item.texture
		var picture = board.profiles.avatar(item.code,180) if item.kind == "avatar" else (GiftCardImage.new() if texture != null and texture.get_meta("printed_card", false) else TextureRect.new())
		if item.kind != "avatar": picture.texture = texture
		picture.custom_minimum_size = Vector2(180, 200)
		if item.kind != "avatar":
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_meta("reward_icon", true)
		column.add_child(picture)
		var caption = board.centered_label(item.caption, 20, board.TEXT)
		caption.custom_minimum_size.x = 184
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(caption)
	var controls = board.box(body, false)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_child(board.button("Continuar", board.close_overlay.bind(shade), false, true))
	board.sound.play_effect("regalo_recibido")

func render_mission(body):
	var states = board.collection.missions
	if states.is_empty() and not board.collection.mission.is_empty(): states = [board.collection.mission]
	if states.is_empty():
		centered(body,"Cargando misiones…",18,board.MUTED)
		return
	for state in states:
		if str(state.get("scope", "daily")) == mission_tab: render_mission_row(body, state)
	if not match_status.is_empty():
		centered(body,match_status,17,board.MUTED)
		if receipts.any(func(receipt): return receipt.complete and not receipt.reported):
			body.add_child(board.button("Reintentar registro de partida",func(): retry_after = 0,board.collection.busy))

func reward_details(state):
	var kind = str(state.get("reward_kind", "tc_pack"))
	var amount = maxi(1,int(state.get("reward_amount",state.get("reward_packs",1))))
	if kind == "avatar":
		var code = str(state.get("reward_code",state.get("reward_avatar","")))
		return {"kind":kind,"amount":1,"code":code,"caption":"Foto de perfil "+str(board.game.catalog.get(code,{}).get("nombre","")),"texture":board.texture_code(code)}
	if kind == "restos":
		return {"kind":kind,"amount":amount,"caption":"%d Restos" % amount,"texture":RestosArt.texture()}
	if kind == "normal_pack":
		return {"kind":kind,"amount":amount,"caption":"%d carta%s aleatoria%s" % [amount,"" if amount == 1 else "s","" if amount == 1 else "s"],"texture":NormalPackArt.texture(false)}
	return {"kind":"tc_pack","amount":amount,"caption":"%d sobre%s TC" % [amount,"" if amount == 1 else "s"],"texture":PackArt.texture(false)}

func reward_view(reward):
	if reward.kind == "avatar":
		var portrait = board.profiles.avatar(reward.code,58); portrait.set_meta("mission_reward_icon","avatar"); return portrait
	var image = TextureRect.new()
	image.texture = reward.texture
	image.custom_minimum_size = Vector2(58,76)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_meta("mission_reward_icon",reward.kind)
	return image

func render_mission_row(body, state):
	var id=str(state.get("id","play_one"));var reward=reward_details(state)
	var model={"title":str(state.get("title","Juega 1 partida")),"caption":reward.caption,"scope":"Única" if state.get("scope","daily")=="lifetime" else "Diaria","progress":int(state.get("progress",0)),"goal":int(state.get("target",1)),"claimed":state.get("claimed",false),"prizes":[reward]}
	model.ready=model.progress>=model.goal and not state.is_empty()
	var ui=preload("res://mission_row.gd").render(board,body,model,claim_mission.bind(id))
	ui.shell.set_meta("compact_mission",true);ui.row.set_meta("mission_row",id);ui.row.set_meta("mission_scope",str(state.get("scope","daily")))
	ui.row.set_meta("reward_kind",reward.kind);ui.row.set_meta("reward_amount",reward.amount);ui.icon.set_meta("claim_mission",id);ui.subtitle.set_meta("mission_progress",id)
	if ui.bar!=null:ui.bar.set_meta("mission_progress_bar",id)

func claim_mission(mission_id = "play_one"):
	if await board.collection.claim_mission(mission_id):
		var reply = board.collection.last_reply
		if reply.get("reward_kind","") == "avatar":
			show_code_reward(reply,"Foto ya obtenida" if reply.get("already_claimed",false) else "¡Misión cumplida!"); return
		var reward = reward_details(reply)
		var description = reward.caption
		if reward.kind == "restos": description += "\nDisponibles en la Tienda."
		else: description += "\nEn Mis sobres."
		board.celebrate_reward("Recompensa ya obtenida" if reply.get("already_claimed", false) else "¡Misión cumplida!",description,reward.texture)

func render_packs(body):
	var pending = board.collection.pending_opening
	if pending is Dictionary:
		var kind = str(pending.get("kind","tc"))
		var per_pack = 1 if kind in ["normal_card","halloween"] else 5
		var pack_count = int(pending.get("pack_count",1))
		var count = per_pack * pack_count
		var codes = pending.get("cards",[])
		var valid = kind in ["tc","normal_card","halloween"] and pack_count>0 and pack_count<=10000 and codes is Array and codes.size() == count
		if valid:
			for code in codes: valid = valid and board.game.catalog.has(code)
		if not valid:
			centered(body,"No pudimos mostrar las cartas del sobre. Usa el icono de recarga.",22)
			return
		if reveal_id != str(pending.opening_id):
			reveal_id = str(pending.opening_id)
			reveal_index = 0
			reveal_open = false
		if reveal_index < count:
			var opening_id = str(pending.opening_id)
			var reveal = PackReveal.new().configure(board,codes,reveal_index,reveal_open,opening_id,singular_seen_openings.has(opening_id+":"+str(reveal_index)),kind,pending.get("new_card_indices",[]))
			reveal.packet_opened.connect(func(): reveal_open = true)
			reveal.progress_changed.connect(func(value): reveal_index = value)
			reveal.singular_arrived.connect(func(id): singular_seen_openings[id] = true)
			reveal.finished.connect(func(): board.render())
			body.add_child(reveal)
		else:
			centered(body,"¡Una carta para tu colección!" if count == 1 else "¡%d cartas para tu colección!" % count,30,board.GOLD)
			var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(1050,430)
			scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
			body.add_child(scroll)
			var row=HFlowContainer.new();row.alignment=FlowContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("h_separation",14);row.add_theme_constant_override("v_separation",12)
			scroll.add_child(board.fill(row))
			var amounts={};var new_codes=[]
			var new_indices=PackReveal.normalize_new_indices(pending.get("new_card_indices",[]))
			for i in range(codes.size()):
				amounts[codes[i]]=int(amounts.get(codes[i],0))+1
				if i in new_indices:new_codes.append(codes[i])
			for code in amounts:
				var column=board.box(row,true,4)
				var image=board.catalog_image(code,155,215);column.add_child(image)
				column.add_child(board.centered_label("×%d" % amounts[code],18,board.TEXT))
				if code in new_codes:
					var badge=PackReveal.NewBadge.new();badge.position=Vector2(129,2);badge.size=Vector2(24,24);image.add_child(badge)
			body.add_child(board.button("Continuar",finish_opening,board.collection.busy,true))
		return
	if board.collection.packs <= 0 and board.collection.normal_packs <= 0 and board.collection.halloween_packs<=0:
		var empty = centered(body,"No tienes sobres por abrir",24,board.MUTED)
		empty.set_meta("empty_packs",true)
		return
	var tiles = board.box(body,false,22)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	if board.collection.packs > 0: render_pack_tile(tiles,"tc",board.collection.packs)
	if board.collection.normal_packs > 0: render_pack_tile(tiles,"normal_card",board.collection.normal_packs)
	if board.collection.halloween_packs>0:render_pack_tile(tiles,"halloween",board.collection.halloween_packs)

func render_pack_tile(parent,kind,amount):
	var normal = kind == "normal_card"
	var disabled = board.collection.busy or (not opening_request.is_empty() and opening_request_kind != kind)
	var tile = board.button("",start_opening.bind(kind),disabled)
	tile.disabled=disabled or (not opening_request.is_empty() and opening_request_all)
	tile.custom_minimum_size = Vector2(300,300)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.set_meta("pack_expansion","halloween_2026" if kind=="halloween" else ("carta_aleatoria" if normal else "transmision_caida"))
	tile.set_meta("pack_kind",kind)
	tile.set_meta("pack_quantity",amount)
	var group=board.box(parent,true,10)
	group.add_child(tile)
	if amount>1:
		var all_button=board.button("Abrir todos · %d" % amount if amount<=10000 else "Abrir 10.000",start_opening.bind(kind,true),disabled or (not opening_request.is_empty() and not opening_request_all),true)
		all_button.set_meta("open_all_packs",kind);group.add_child(all_button)
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 14
	content.offset_bottom = -14
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation",6)
	tile.add_child(content)
	content.add_child(HalloweenPackArt.view(Vector2(132,194)) if kind=="halloween" else (NormalPackArt.view(Vector2(132,194)) if normal else PackArt.view(Vector2(132,194))))
	content.add_child(board.centered_label("AAMIX Halloween" if kind=="halloween" else ("Carta aleatoria" if normal else "Transmisión Caída"),22,board.TEXT))
	content.add_child(board.centered_label("Cantidad: %d" % amount,16,board.MUTED))

func pack_music_suspended():
	return board.screen == "packs" and (opening_in_flight or board.collection.pending_opening is Dictionary)

func start_opening(kind = "tc", all_packs = false):
	if board.collection.busy or opening_in_flight: return
	if opening_request.is_empty():
		opening_request = board.collection.request_id()
		opening_request_kind = kind
		opening_request_all = all_packs
	elif opening_request_kind != kind or opening_request_all != all_packs:
		return
	opening_in_flight = true
	board.render()
	var ok = false
	if all_packs:ok=await board.collection.request("aamix_open_all_packs",{"p_request_id":opening_request,"p_kind":kind})
	elif kind=="halloween":ok=await board.collection.request("aamix_open_halloween_pack",{"p_request_id":opening_request})
	elif kind == "normal_card": ok = await board.collection.open_normal_pack(opening_request)
	else: ok = await board.collection.open_pack(opening_request)
	opening_in_flight = false
	if ok and board.collection.pending_opening == null:
		opening_request = ""
		opening_request_kind = "tc"
	board.render()

func finish_opening():
	if not board.collection.pending_opening is Dictionary: return
	if await board.collection.acknowledge_opening(board.collection.pending_opening.opening_id):
		opening_request = ""
		opening_request_kind = "tc"
		reveal_id = ""
		reveal_index = 0
		board.render()

func event_icon():
	var atlas = AtlasTexture.new()
	atlas.atlas = board.asset_texture("eventos.png")
	atlas.region = Rect2(68, 74, 1422, 1222)
	atlas.filter_clip = true
	return atlas

func home_event_button():
	var action = board.button("", open_screen.bind("event"))
	action.custom_minimum_size = Vector2(244, 194)
	action.size = action.custom_minimum_size
	action.set_meta("home_event_button", true)
	action.tooltip_text = "Ver el evento activo y sus misiones"
	action.flat = true
	for state in ["normal", "hover", "pressed", "focus"]: action.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 5
	content.offset_bottom = -5
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(EventArt.new().configure(event_icon(), Vector2(166, 76), false, board.animations_enabled))
	var caption = board.centered_label("Evento Activo", 19, Color("fff3c6"))
	caption.add_theme_color_override("font_outline_color", Color("302316"))
	caption.add_theme_constant_override("outline_size", 5)
	content.add_child(caption)
	var active = board.collection.active_events()
	if not active.is_empty():
		var event = active[0]
		var title = board.centered_label("BIENVENIDA AAMIX Online" if event.id == "bienvenida_2026" else str(event.title),18,Color("fff3c6"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bold = FontVariation.new(); bold.base_font = ThemeDB.fallback_font; bold.variation_embolden = 0.75
		title.add_theme_font_override("font",bold); title.set_meta("event_badge_title",event.id)
		title.add_theme_color_override("font_outline_color",Color("302316")); title.add_theme_constant_override("outline_size",4)
		content.add_child(title)
		var dates = board.centered_label(display_day(event.start_day)+" – "+display_day(event.end_day),13,Color("fff3c6"))
		dates.set_meta("event_badge_dates",true); dates.add_theme_color_override("font_outline_color",Color("302316")); dates.add_theme_constant_override("outline_size",4)
		content.add_child(dates)
	board.hover_feedback(action,1.05)
	action.add_child(content)
	return action

func render_mission_tabs(parent):
	var tabs = board.box(parent, false, 12)
	for item in [["Misiones diarias", "daily"], ["Misiones históricas", "lifetime"], ["Evento", "event"]]:
		var is_event = item[1] == "event"
		var active = board.screen == "event" if is_event else board.screen == "missions" and mission_tab == item[1]
		var tab = board.button(item[0], change_mission_tab.bind(item[1]), is_event and board.collection.active_events().is_empty(), active)
		tab.set_meta("mission_tab", item[1])
		if is_event and tab.disabled: tab.tooltip_text = "No hay un evento activo"
		tabs.add_child(board.fill(tab))

func change_mission_tab(tab):
	if tab == "event":
		if board.collection.active_events().is_empty(): return
		board.screen = "event"
	else:
		mission_tab = tab
		board.screen = "missions"
	board.render()

func render_event(body):
	var active = board.collection.active_events()
	if active.is_empty():
		centered(body, "No hay un evento activo en este momento.", 24, board.MUTED)
		return
	var event = active[0]
	for available in active:
		if str(available.id) == selected_event: event = available
	selected_event = str(event.id)
	if active.size() > 1:
		var choices = board.box(body, false, 10)
		for available in active: choices.add_child(board.button(available.title, select_event.bind(str(available.id)), false, available.id == event.id))
	var intro = board.box(body, true, 8)
	intro.set_meta("event_intro", event.id)
	var card_center = CenterContainer.new()
	intro.add_child(card_center)
	var featured = preload("res://event_card_pair.gd").new().configure(board,event.get("featured_cards",[str(event.card_code)]))
	featured.set_meta("event_featured_card", str(event.card_code))
	card_center.add_child(featured)
	var text = board.box(intro, true, 7)
	board.fill(text)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(board.centered_label(str(event.title), 27, board.GOLD))
	text.add_child(board.centered_label("%s al %s" % [display_day(event.start_day), display_day(event.end_day)], 15, board.MUTED))
	var summary = board.label(str(event.summary), 20)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.set_meta("event_summary", true)
	text.add_child(summary)
	for state in event.missions: render_event_mission(body, event, state)
	if not match_status.is_empty(): centered(body, match_status, 17, board.MUTED)

func display_day(value):
	var parts = str(value).split("-")
	return "%s/%s/%s" % [parts[2], parts[1], parts[0]] if parts.size() == 3 else str(value)

func select_event(id):
	selected_event = id
	board.render()

func event_reward_reply(prize):
	return {"reward_cards":prize.get("cards", []), "reward_packs":int(prize.get("packs", 0)), "reward_restos":int(prize.get("restos", 0)), "reward_normal_packs":int(prize.get("normal_packs", 0)), "reward_halloween_packs":int(prize.get("halloween_packs",0)),"reward_design":str(prize.get("deck_design", ""))}

func render_event_mission(body, event, state):
	var prizes=code_reward_items(event_reward_reply(state.reward))
	var captions=prizes.map(func(prize):return prize.caption.replace("\n"," "))
	var model={"title":str(state.title),"caption":" + ".join(captions),"scope":"Diaria" if state.get("scope")=="daily" else "Única","progress":int(state.get("progress",0)),"goal":int(state.get("target",1)),"claimed":state.get("claimed",false),"prizes":prizes}
	model.ready=model.progress>=model.goal
	var ui=preload("res://mission_row.gd").render(board,body,model,claim_event_mission.bind(str(event.id),str(state.id)))
	ui.row.set_meta("event_mission_row",str(state.id));ui.icon.set_meta("claim_event_mission",str(state.id))
	if ui.bar!=null:ui.bar.set_meta("mission_progress_bar","event_"+str(state.id))

func claim_event_mission(event_id, mission_id):
	if await board.collection.claim_event_mission(event_id, mission_id):
		var reply = board.collection.last_reply
		var reward = event_reward_reply(reply.get("event_reward", {}))
		show_code_reward(reward, "Recompensa ya obtenida" if reply.get("already_claimed", false) else "¡Misión del evento cumplida!")

func add_progress(parent, id, progress, target):
	if target <= 1: return
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = target
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.set_meta("mission_progress_bar", id)
	var background = StyleBoxFlat.new()
	background.bg_color = Color(board.MUTED, 0.17)
	background.set_corner_radius_all(4)
	var fill = StyleBoxFlat.new()
	fill.bg_color = board.ACCENT if board.dark_theme else Color("c5993c")
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)

func present_achievement():
	if board == null or board.modal_open or board.collection.busy or board.account.busy or pumping or is_instance_valid(achievement_shade): return
	if not board.account.signed_in() or board.collection.owner_id != board.account.player_id(): return
	if board.screen not in ["home","challenges","missions","cards","packs","shop","friends","trades"]: return
	if not board.social.data.get("trade_notifications",[]).is_empty(): return
	if board.collection.achievement_notifications.is_empty(): return
	var prize = board.collection.achievement_notifications[0]
	var reply = {}
	if prize.kind == "card": reply.reward_cards = [{"codigo":prize.code,"cantidad":1}]
	elif prize.kind == "design": reply.reward_design = prize.code
	else: reply.reward_avatar = prize.code
	var center = board.overlay("achievement"); achievement_shade = center.get_parent()
	var body = board.box(board.panel(center),true,16); body.custom_minimum_size.x = 690
	body.set_meta("secret_achievement_reward",prize.id)
	body.add_child(board.centered_label("¡Misión histórica completada!",28,board.GOLD))
	body.add_child(board.centered_label(str(prize.title),21,board.TEXT))
	for item in code_reward_items(reply):
		body.add_child(board.catalog_image(prize.code,190,255) if prize.kind == "card" else board.deck_cover({"custom":true,"portada":prize.code},180,240))
		body.add_child(board.centered_label(item.caption,20,board.TEXT))
	body.add_child(board.button("Continuar",ack_achievement.bind(str(prize.id)),false,true))
	board.sound.play_effect("regalo_recibido")
func ack_achievement(id):
	if board.collection.busy: return
	if await board.collection.request("aamix_ack_achievement",{"p_mission_id":id}):
		achievement_shade = null; board.render()
