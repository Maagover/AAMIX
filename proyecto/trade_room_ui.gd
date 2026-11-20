extends RefCounted
var ui_ref
var ui:
	get: return ui_ref.get_ref()
var board
var social
var picker_grid
var picker_room = {}
var picker_query = ""
var picker_family = ""
func _init(value): ui_ref = weakref(value); board = value.board; social = value.social
func room(): return social.room()
func invite(peer):
	if ui.locked(): return
	ui.completed_notice = ""
	await ui.request("aamix_trade_room_create",{"p_peer":peer.id})
func action(value, operation, code = ""):
	# JSON reads numbers as floats; PostgREST's integer revision must remain an integer.
	return await ui.request("aamix_trade_room_action",{"p_room":value.id,"p_action":operation,"p_code":code,"p_revision":int(value.revision)})
func enter(value): await action(value,"accept")
func friend_invitation(body):
	var current = room()
	if not current.get("active",false): return
	var row = ui.peer_row(body,current.peer)
	if current.status == "invited" and current.role == "guest":
		row.add_child(board.label("Te invita a intercambiar",16,board.MUTED))
		row.add_child(board.button("Entrar a la sala",enter.bind(current.duplicate(true)),ui.locked(),true))
		row.add_child(board.button("Rechazar",action.bind(current.duplicate(true),"cancel"),ui.locked()))
	else: row.add_child(board.button("Volver a la sala",ui.open_trades))
func render(body):
	ui.wrapped(body,"Invita a un amigo y entren ambos a la sala. Primero elige el anfitrión; después su amigo. Al terminar, ambos confirman las mismas dos cartas.")
	var current = room()
	if current.get("active",false): render_room(body,current)
	elif not ui.completed_notice.is_empty():
		var success = board.centered_label("Intercambio completado",23,board.GOLD); success.set_meta("trade_completed_notice",true); body.add_child(success)
	if current.get("active",false): return
	body.add_child(board.centered_label("Elige un amigo para intercambiar",23,board.GOLD))
	if social.friends().is_empty():
		ui.wrapped(body,"Añade un amigo desde Amigos para abrir tu primera sala.")
		body.add_child(board.button("Amigos",ui.open_friends)); return
	for peer in social.friends():
		var row = ui.peer_row(body,peer)
		var start = board.button("Invitar a intercambio",invite.bind(peer),ui.locked(),true)
		start.set_meta("trade_invite_friend",peer.id); row.add_child(start)
func render_room(parent, current):
	var body = board.box(board.panel(parent),true,10); body.set_meta("trade_room_view",current.id)
	body.add_child(board.centered_label("Sala con "+str(current.peer.name),25,board.GOLD))
	var connected = bool(current.host_connected) and bool(current.guest_connected)
	var people = board.box(body,false,46); people.alignment = BoxContainer.ALIGNMENT_CENTER
	for own in [true,false]:
		var column = board.box(people,true,5); column.custom_minimum_size.x = 300
		var host = (current.role == "host") == own
		var online = bool(current.host_connected if host else current.guest_connected)
		var portrait = CenterContainer.new(); column.add_child(portrait)
		portrait.add_child(board.profiles.avatar(board.profiles.current_code() if own else str(current.peer.get("avatar_code","")),54))
		column.add_child(board.centered_label("Tú" if own else str(current.peer.name),21))
		column.add_child(board.centered_label("Conectado" if online else "Esperando conexión",16,board.GOLD if online else board.MUTED))
	if current.status == "invited":
		ui.wrapped(body,"Invitación enviada. Tu amigo debe aceptar y entrar a esta sala." if current.role == "host" else "Tu amigo te invita a una sala de intercambio.")
		if current.role == "guest": body.add_child(board.button("Entrar a la sala",enter.bind(current.duplicate(true)),ui.locked(),true))
	else:
		render_pair(body,current)
		if not connected: ui.wrapped(body,"Esperando a que ambos estén conectados. La elección y la confirmación se habilitan al reencontrarse en la sala.")
		else:
			var own_turn = (current.status == "host_offer" and current.role == "host") or (current.status == "guest_offer" and current.role == "guest")
			if current.status in ["host_offer","guest_offer"]:
				ui.wrapped(body,"Elige la carta que entregarás." if own_turn else "Tu amigo está eligiendo su carta…")
				if own_turn:
					var choose = board.button("Elegir mi carta",choose_card.bind(current.duplicate(true)),ui.locked(),true)
					choose.set_meta("trade_choose_card",true); body.add_child(choose)
			elif current.status == "confirming":
				ui.wrapped(body,"Revisen las dos cartas. El intercambio se realiza cuando ambos confirmen.")
				var confirm = board.button("Confirmado" if current.own_confirmed else "Confirmar",review.bind(current.duplicate(true)),ui.locked() or current.own_confirmed,true)
				confirm.set_meta("trade_confirm",true); body.add_child(confirm)
	ui.wrapped(body,"Normales y Especiales entre sí; Singulares sólo por Singulares. Recursos y Promocionales no se intercambian.",15)
	body.add_child(board.button("Cancelar intercambio",cancel.bind(current.duplicate(true)),ui.locked()))
func render_pair(parent, current):
	var row = board.box(parent,false,44); row.alignment = BoxContainer.ALIGNMENT_CENTER
	for own in [true,false]:
		var column = board.box(row,true,5); column.custom_minimum_size.x = 300
		column.add_child(board.centered_label("Tu carta" if own else "Carta de tu amigo",18,board.MUTED))
		var code = str(current.get("own_code" if own else "peer_code",""))
		if board.game.catalog.has(code):
			var picture = board.catalog_image(code,150,204); column.add_child(picture)
			column.add_child(board.centered_label(board.game.catalog[code].nombre,18))
		else:
			var empty = board.centered_label("Por elegir",20,board.MUTED); empty.custom_minimum_size = Vector2(150,204); column.add_child(empty)
		if current.status in ["confirming","completed"]:
			column.add_child(board.centered_label("Confirmado" if current.get("own_confirmed" if own else "peer_confirmed",false) else "Por confirmar",16,board.GOLD))
func choose_card(current):
	if ui.locked(): return
	picker_room = current; picker_query = ""; picker_family = ""
	var other = str(current.get("peer_code",""))
	if board.game.catalog.has(other): picker_family = "singular" if "Singular" in board.game.catalog[other].get("palabras_clave",[]) else "ordinary"
	var body = ui.dialog("Elige la carta que entregarás")
	var search = LineEdit.new(); search.placeholder_text = "Buscar carta…"; search.custom_minimum_size.y = 40
	search.text_changed.connect(func(value): picker_query = value; render_picker()); body.add_child(search)
	var scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(750,410); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroll)
	picker_grid = HFlowContainer.new(); picker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picker_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	picker_grid.add_theme_constant_override("h_separation",14); picker_grid.add_theme_constant_override("v_separation",14); scroll.add_child(picker_grid)
	ui.wrapped(body,"Si entregas una copia necesaria para un mazo, quedará como borrador editable. Para cambiar la elección, cancela y abre una nueva sala.",15)
	body.add_child(board.button("Volver",board.render)); render_picker()
func render_picker():
	if not is_instance_valid(picker_grid): return
	for child in picker_grid.get_children(): picker_grid.remove_child(child); child.queue_free()
	for card in social.data.get("tradable_cards",[]):
		if int(card.available)<=0 or (not picker_family.is_empty() and card.family != picker_family): continue
		var code = str(card.code); var definition = board.game.catalog.get(code,{})
		if definition.is_empty() or (not picker_query.is_empty() and picker_query.to_lower() not in (str(definition.nombre)+code).to_lower()): continue
		var item = board.box(picker_grid,true,5); item.custom_minimum_size.x = 160
		item.add_child(board.catalog_image(code,145,195))
		var choose = board.button(str(definition.nombre),offer.bind(code),ui.locked())
		choose.clip_text = true; choose.custom_minimum_size.x = 160; choose.set_meta("trade_picker_card",code); item.add_child(choose)
		item.add_child(board.centered_label("Tienes: %d" % int(card.owned),14,board.MUTED))
	if picker_grid.get_child_count() == 0: picker_grid.add_child(board.label("No tienes cartas disponibles para este filtro.",18,board.MUTED))
func offer(code): await action(picker_room,"offer",code)
func review(current):
	var body = ui.dialog("Confirma estas dos cartas")
	render_pair(body,current)
	ui.wrapped(body,"Entregas la carta de la izquierda y recibes la de la derecha. Sólo se realiza al confirmar ambos.")
	body.add_child(board.button("Confirmar intercambio",action.bind(current,"confirm"),ui.locked(),true))
	body.add_child(board.button("Volver",board.render))
func cancel(current):
	var body = ui.dialog("¿Cancelar el intercambio?")
	ui.wrapped(body,"Cada jugador conservará sus cartas.")
	body.add_child(board.button("Cancelar la sala",action.bind(current,"cancel"),ui.locked(),true))
	body.add_child(board.button("Continuar",board.render))
