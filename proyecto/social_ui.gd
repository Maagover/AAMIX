extends RefCounted
## Friend codes and live trade rooms; every change is authorized by the service.
var board
var social
var code_input = ""
var rooms
var sending = false

func _init(value):
	board = value; social = board.social; rooms = preload("res://trade_room_ui.gd").new(self)
func reset(): code_input = ""; sending = false; completed_notice = ""; received_shade = null
var received_shade
var completed_notice = ""

func changed():
	if board.screen in ["friends", "trades"] and not board.modal_open: board.render()
	present_received.call_deferred()
func open_friends(): open_screen("friends")
func open_trades(): open_screen("trades")
func open_screen(destination):
	if not board.account.signed_in():
		board.show_notice("Amigos", "Accede a tu cuenta para añadir amigos, batallar e intercambiar cartas."); return
	completed_notice = ""
	board.screen = destination; board.render()
	if not social.busy: social.sync()
func wrapped(parent, text, size = 17):
	var label = board.label(text, size, board.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label); return label
func locked(): return sending or social.refreshing_inventory or board.collection.busy or board.account.busy
func render_screen():
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,32)
	board.add_child(margin)
	var outer = board.box(margin,true,14)
	var header = board.box(outer,false,14)
	header.add_child(board.home_logo(170,45)); header.add_child(board.fill(Control.new()))
	header.add_child(board.button("Recargar",reload,social.busy or locked())); header.add_child(board.button("Volver",back))
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var center = CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(center)
	var body = board.box(center,true,10); body.custom_minimum_size.x = 1000; body.set_meta("social_centered_body",true)
	var icon_center = CenterContainer.new(); body.add_child(icon_center)
	icon_center.add_child(preload("res://floating_icon.gd").new().configure(preload("res://heart_icon.gd").new().configure(84),Vector2(84,96),board.animations_enabled))
	body.add_child(board.centered_label("Amigos" if board.screen == "friends" else "Intercambio",30,board.GOLD))
	if not board.account.signed_in(): wrapped(body,"Accede a tu cuenta para continuar."); return
	if not social.pending.is_empty():
		var pending_row = board.box(body,false,12); pending_row.alignment = BoxContainer.ALIGNMENT_CENTER
		wrapped(pending_row,"Hay una operación pendiente de confirmación.")
		pending_row.add_child(board.button("Reintentar",retry,social.busy or locked(),true))
	if not social.status.is_empty(): wrapped(body,social.status)
	if not social.loaded: wrapped(body,"Conectando con tus amigos…"); return
	if board.screen == "friends": render_friends(body)
	else: render_trades(body)
	present_received.call_deferred()
func back():
	if board.screen == "trades": board.show_multiplayer()
	else: board.go_home()
func reload():
	if not social.busy:
		await social.sync(); if board.screen in ["friends", "trades"]: board.render()
func retry():
	await social.retry_pending()
	if board.screen in ["friends", "trades"]: board.render()
func request(endpoint, payload):
	if sending: return false
	sending = true
	var who = board.account.player_id(); var deadline = Time.get_ticks_msec()+25000
	# A click may arrive during a background poll; queue it rather than silently dropping it.
	while (social.busy or social.refreshing_inventory or board.collection.busy or board.account.busy) and Time.get_ticks_msec()<deadline and who == board.account.player_id():
		await board.get_tree().process_frame
	if who != board.account.player_id(): sending = false; return false
	if social.busy or social.refreshing_inventory or board.collection.busy or board.account.busy:
		sending = false; social.status = "La conexión sigue ocupada. Reintenta en un momento."; board.render(); return false
	var ok = await social.mutate(endpoint,payload)
	sending = false
	if who != board.account.player_id(): return false
	if board.screen in ["friends","trades"]:
		if ok and (endpoint == "aamix_trade_room_create" or (endpoint == "aamix_trade_room_action" and payload.get("p_action","") == "accept")): board.screen = "trades"
		board.render()
	present_received.call_deferred()
	return ok
func peer_row(parent, peer):
	var row = board.box(board.panel(parent), false, 14)
	row.add_child(board.profiles.avatar(str(peer.get("avatar_code", "")), 48))
	var name = board.label(str(peer.get("name", "Jugador")), 21)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; row.add_child(board.fill(name)); return row
func render_friends(body):
	var code_row = board.box(board.panel(body), false, 16)
	var own_code = str(social.data.get("friend_code", ""))
	var formatted = "%s-%s-%s" % [own_code.substr(0,4), own_code.substr(4,4), own_code.substr(8,4)]
	code_row.add_child(board.fill(board.label("Tu código: "+formatted, 23, board.GOLD)))
	code_row.add_child(board.button("Copiar código", func(): DisplayServer.clipboard_set(formatted)))
	var send_row = board.box(body, false, 12)
	var input = LineEdit.new(); input.text = code_input; input.placeholder_text = "Código de tu amigo"
	input.max_length = 16; input.custom_minimum_size.y = 44; input.set_meta("friend_code_input", true)
	input.text_changed.connect(func(value): code_input = value)
	input.text_submitted.connect(func(_value): send_friend())
	send_row.add_child(board.fill(input)); send_row.add_child(board.button("Enviar solicitud", send_friend, locked()))
	for direction in ["incoming", "outgoing"]:
		var entries = social.data.get(direction, [])
		if entries.is_empty(): continue
		body.add_child(board.label("Solicitudes recibidas" if direction == "incoming" else "Solicitudes enviadas", 23, board.GOLD))
		for peer in entries:
			var row = peer_row(body, peer)
			if direction == "incoming":
				row.add_child(board.button("Aceptar", request.bind("aamix_friend_respond", {"p_peer":peer.id,"p_accept":true}), locked(), true))
				row.add_child(board.button("Rechazar", request.bind("aamix_friend_respond", {"p_peer":peer.id,"p_accept":false}), locked()))
			else: row.add_child(board.button("Cancelar", request.bind("aamix_friend_remove", {"p_peer":peer.id}), locked()))
	var breathing_space = Control.new(); breathing_space.custom_minimum_size.y = 24; breathing_space.set_meta("friend_list_spacing",true); body.add_child(breathing_space)
	if social.data.get("incoming",[]).is_empty() and social.data.get("outgoing",[]).is_empty() and social.friends().is_empty(): wrapped(body,"Aún no has enviado ninguna solicitud")
	rooms.friend_invitation(body)
	for duel in social.data.get("duels", []):
		var row = peer_row(body, duel.peer)
		if duel.direction == "incoming":
			row.add_child(board.label("Te invita a batallar", 16, board.MUTED))
			row.add_child(board.button("Elegir mazo", deck_picker.bind("accept", duel.id), locked(), true))
			row.add_child(board.button("Rechazar", request.bind("aamix_duel_respond", {"p_invite":duel.id,"p_accept":false,"p_deck":""}), locked()))
		else: row.add_child(board.button("Ver sala", board.show_multiplayer.bind(true)))
	body.add_child(board.label("Tus amigos", 24, board.GOLD))
	if social.friends().is_empty(): wrapped(body, "Comparte tu código para añadir a tu primer amigo.")
	for peer in social.friends():
		var row = peer_row(body, peer); row.set_meta("friend", peer.id)
		row.add_child(board.button("Batallar", deck_picker.bind("create", peer.id), social.busy or board.online.busy or not board.online.room.is_empty(), true))
		row.add_child(board.button("Intercambiar", new_offer.bind(peer), locked() or social.room().get("active",false)))
		row.add_child(board.button("Eliminar", remove_friend.bind(peer), locked()))
func send_friend():
	if code_input.strip_edges().is_empty() or locked(): return
	if await request("aamix_friend_request", {"p_code":code_input}): code_input = ""; board.render()
func remove_friend(peer):
	var body = dialog("¿Eliminar a %s?" % peer.name)
	wrapped(body, "Se cerrará cualquier sala de intercambio pendiente con este amigo.")
	body.add_child(board.button("Eliminar amigo", request.bind("aamix_friend_remove", {"p_peer":peer.id}), locked()))
	body.add_child(board.button("Volver", board.render))
func dialog(title):
	var body = board.box(board.panel(board.overlay("social")), true, 14)
	body.custom_minimum_size.x = 780
	body.add_child(board.centered_label(title, 27, board.GOLD)); return body
func deck_picker(action, target):
	if locked(): return
	var decks = board.collection.playable_decks()
	if decks.is_empty(): board.show_notice("Tus mazos", "Completa un mazo para poder batallar con tu amigo."); return
	var body = dialog("Elige tu mazo")
	var scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(750, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroll)
	var grid = HFlowContainer.new(); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.alignment = FlowContainer.ALIGNMENT_CENTER; scroll.add_child(grid)
	for deck in decks:
		var item = board.box(grid, true, 8); item.custom_minimum_size.x = 220
		item.add_child(board.deck_cover(deck, 140, 170))
		var payload = {"p_peer":target,"p_deck":deck.id} if action == "create" else {"p_invite":target,"p_accept":true,"p_deck":deck.id}
		item.add_child(board.button(str(deck.nombre), request.bind("aamix_duel_create" if action == "create" else "aamix_duel_respond", payload), locked(), true))
	body.add_child(board.button("Volver", board.render))
func render_trades(body): rooms.render(body)
func new_offer(peer): rooms.invite(peer)

func present_received():
	if not board.account.signed_in() or social.owner_id != board.account.player_id() or board.modal_open or social.busy or locked(): return
	if is_instance_valid(received_shade) and not received_shade.is_queued_for_deletion(): return
	if board.screen not in ["home","friends","trades","multiplayer"]: return
	var notices = social.data.get("trade_notifications",[])
	if not notices is Array or notices.is_empty(): return
	var notice = notices[0]; var code = str(notice.get("code",""))
	if not board.game.catalog.has(code): return
	var center = board.overlay("trade_received"); received_shade = center.get_parent()
	var body = board.box(board.panel(center),true,16); body.custom_minimum_size.x = 650
	body.set_meta("trade_received_notice",notice.id)
	body.add_child(board.centered_label("Has recibido: "+board.game.catalog[code].nombre,28,board.GOLD))
	body.add_child(board.catalog_image(code,200,276))
	if not notice.get("drafts",[]).is_empty(): wrapped(body,"Los mazos a los que les faltan copias quedaron como borradores editables.")
	body.add_child(board.button("Continuar",ack_received.bind(notice.id),false,true))
	board.sound.play_effect("regalo_recibido")
func ack_received(id):
	if await request("aamix_ack_trade",{"p_room":id}):
		completed_notice = str(id); received_shade = null
		if board.screen in ["trades","friends"]: board.render()
