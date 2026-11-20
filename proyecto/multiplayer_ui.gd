extends RefCounted
var board
var online
var section = "hub"

func _init(value):
	board = value
	online = board.online

func render_screen():
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(center)
	var content = board.box(board.panel(center),true,18)
	content.custom_minimum_size = Vector2(960,650)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.set_meta("multiplayer_ui",true)
	content.add_child(board.UIIcons.multiplayer_battle(100,board.animations_enabled))
	var title = board.centered_label("Multijugador",32,board.TEXT)
	title.set_meta("multiplayer_title",true)
	content.add_child(title)
	if not board.account.signed_in():
		content.add_child(board.centered_label("Accede a tu cuenta para jugar con un amigo.",19,board.MUTED))
		content.add_child(board.button("Mi cuenta",board.open_account,false,true))
		content.add_child(board.button("Volver",board.go_home))
		return
	if section == "hub" and online.room.is_empty() and online.incompatible_room.is_empty():
		content.add_child(board.button("PARTIDA PRIVADA", open_private, false, true))
		content.add_child(board.button("INTERCAMBIO", board.social_ui.open_trades))
		content.add_child(board.button("Volver", board.go_home))
		return
	if not online.incompatible_room.is_empty():
		content.add_child(board.centered_label("Sala con otra versión de las reglas",23,board.GOLD))
		content.add_child(board.centered_label("Ambos jugadores deben usar AAMIX 1.3 para compartir estas reglas.",18,board.MUTED))
		var explanation = board.centered_label("Puedes cerrar tu sala anterior y crear una nueva.",17,board.MUTED)
		content.add_child(explanation)
		if not online.status.is_empty():
			var status = board.centered_label(online.status,15,board.MUTED)
			status.custom_minimum_size.x = 880
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(status)
		content.add_child(board.button("Cerrar sala anterior",confirm_incompatible_leave,online.busy,true))
		content.add_child(board.button("Volver",board.go_home))
		return
	if not online.room.is_empty():
		render_room(content)
		return
	if online.lobby_mode in ["create","join"]:
		render_deck_selection(content)
	else:
		content.add_child(board.centered_label("Salas privadas para 2 jugadores",19,board.MUTED))
		content.add_child(board.centered_label("El creador debe mantener el juego abierto durante la partida.",15,board.MUTED))
		var choices = board.box(content,false,22)
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_child(board.button("Crear sala",choose_mode.bind("create"),online.busy,true))
		choices.add_child(board.button("Unirme con código",choose_mode.bind("join"),online.busy))
		var reconnect = board.button("Retomar sala",online.discover,online.busy)
		reconnect.set_meta("mp_resume",true)
		content.add_child(reconnect)
		if not online.status.is_empty(): content.add_child(board.centered_label(online.status,15,board.MUTED))
		content.add_child(board.button("Volver",board.go_home))

func open_private():
	section = "private"; board.render()
	if online.room.is_empty() and not online.busy: online.discover()

func choose_mode(mode):
	if not board.collection.loaded or board.collection.owner_id != board.account.player_id():
		if not await board.collection.load_inventory(): return
	var decks = board.collection.playable_decks()
	if decks.is_empty():
		board.show_notice("Elige tu mazo","Termina un mazo en Mis Mazos o entra al Desafío AAMIX para obtener tu mazo inicial.")
		return
	online.lobby_mode = mode
	if not decks.any(func(deck): return str(deck.id) == online.selected_deck): online.selected_deck = str(decks[0].id)
	board.render()

func confirm_incompatible_leave():
	var body = board.box(board.panel(board.overlay("online_leave")),true,17)
	body.custom_minimum_size.x = 610
	var playing = str(online.incompatible_room.get("status", "")) == "playing"
	body.add_child(board.centered_label("¿Cerrar la sala anterior?",25))
	if playing: body.add_child(board.centered_label("Abandonar la partida en curso se contará como derrota.",16,board.MUTED))
	body.add_child(board.button("Abandonar y cerrar" if playing else "Cerrar sala",online.close_incompatible_room,online.busy,true))
	body.add_child(board.button("Continuar",board.render))

func render_deck_selection(content):
	content.add_child(board.centered_label("Elige tu mazo",20,board.MUTED))
	var decks = board.collection.playable_decks()
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid = GridContainer.new()
	grid.columns = clampi(decks.size(),1,4)
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	center.add_child(grid)
	for deck in decks:
		var column = board.box(grid,true,6)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.custom_minimum_size.x = 205
		column.add_child(board.deck_cover(deck,150,185))
		var choose = board.button(str(deck.nombre),select_deck.bind(str(deck.id)),online.busy,str(deck.id) == online.selected_deck)
		choose.clip_text = true
		choose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choose.tooltip_text = str(deck.nombre)
		choose.custom_minimum_size.x = 205
		choose.set_meta("mp_deck",str(deck.id))
		choose.add_theme_font_size_override("font_size",15)
		column.add_child(choose)
	if online.lobby_mode == "join":
		var code_center = CenterContainer.new()
		content.add_child(code_center)
		var code = LineEdit.new()
		code.custom_minimum_size = Vector2(310,46)
		code.max_length = 8
		code.placeholder_text = "Código de sala"
		code.text = online.joining_code
		code.set_meta("mp_room_code_input",true)
		code.alignment = HORIZONTAL_ALIGNMENT_CENTER
		code.text_changed.connect(func(value): online.joining_code = str(value).to_upper())
		code_center.add_child(code)
	var controls = board.box(content,false,16)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var launch = board.button("Crear sala" if online.lobby_mode == "create" else "Unirme",launch_room,online.busy or online.selected_deck.is_empty(),true)
	launch.set_meta("mp_launch",true)
	controls.add_child(launch)
	controls.add_child(board.button("Volver",choose_mode.bind("choice"),online.busy))
	if not online.status.is_empty(): content.add_child(board.centered_label(online.status,15,board.MUTED))

func select_deck(id):
	if not board.collection.playable_decks().any(func(deck): return str(deck.id) == str(id)): return
	online.selected_deck = id
	board.render()

func launch_room():
	if not board.collection.playable_decks().any(func(deck): return str(deck.id) == online.selected_deck): return
	if online.lobby_mode == "create": online.create_room(online.selected_deck)
	else: online.join_room(online.joining_code,online.selected_deck)
	board.render()

func render_room(content):
	if str(online.room.get("status",""))=="finished":
		render_rematch(content)
		return
	var code = str(online.room.get("code",""))
	content.add_child(board.centered_label(code,38,board.GOLD))
	var copy = board.button("Copiar código",func(): DisplayServer.clipboard_set(code))
	copy.set_meta("mp_copy_code",true)
	content.add_child(copy)
	var state = str(online.room.get("status","waiting"))
	var players = board.box(content,false,28)
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	for p in range(2):
		var info = board.box(board.panel(players),true,8)
		info.custom_minimum_size = Vector2(340,100)
		var entries = online.room.get("players",[])
		var entry = entries[p] if entries.size() > p and entries[p] is Dictionary else {}
		if not entry.is_empty():
			var portrait=CenterContainer.new()
			portrait.add_child(board.profiles.avatar(str(entry.get("avatar_code","")),72))
			info.add_child(portrait)
		info.add_child(board.centered_label(str(entry.get("name","Esperando jugador…")),21))
		var confirmed=online.room.get("confirmed",[false,false])
		info.add_child(board.centered_label(("Confirmado" if bool(confirmed[p]) else "Por confirmar") if not entry.is_empty() else "Comparte el código",15,board.MUTED))
	content.add_child(board.centered_label(online.status,16,board.MUTED))
	var controls = board.box(content,false,16)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	if state in ["waiting","ready"]:
		var own_confirmed=bool(online.room.get("confirmed",[false,false])[online.slot])
		var ready_button=board.button("Confirmado" if own_confirmed else "Confirmar",online.confirm,online.busy or own_confirmed,true)
		ready_button.set_meta("mp_confirm",true)
		controls.add_child(ready_button)
	if online.in_match():
		controls.add_child(board.button("Volver a la partida",resume_match,false,true))
	if state in ["waiting","ready","playing"]:
		controls.add_child(board.button("Cancelar sala" if state in ["waiting","ready"] else "Abandonar partida",confirm_leave,online.busy))
	else:
		controls.add_child(board.button("Cerrar sala",close_finished,online.busy))

func resume_match():
	board.screen = "table"
	board.render()

func confirm_leave():
	var box = board.box(board.panel(board.overlay("online_leave")),true,17)
	box.custom_minimum_size.x = 540
	var playing=str(online.room.get("status",""))=="playing"
	box.add_child(board.centered_label("¿Abandonar la partida?" if playing else "¿Cerrar la sala?",25))
	if playing: box.add_child(board.centered_label("La partida en curso se contará como derrota.",16,board.MUTED))
	box.add_child(board.button("Abandonar" if playing else "Cerrar sala",online.leave,online.busy,true))
	box.add_child(board.button("Continuar",board.render))

func close_finished():
	online.leave()

func request_rematch():
	board.screen="multiplayer";section="private"
	board.render()
	var decks=board.collection.playable_decks()
	if decks.is_empty():return
	var own=online.room.get("players",[])[online.slot].get("deck_id","")
	var chosen=str(decks[0].id)
	for d in decks:
		if str(d.id)==str(own):chosen=str(d.id)
	await online.rematch_action("request",chosen)

func render_rematch(content):
	var rematch=online.room.get("rematch",{})
	var cancelled=bool(rematch.get("cancelled",false))
	content.add_child(board.centered_label("Revancha cancelada" if cancelled else "¿Otra partida?",27,board.GOLD))
	if cancelled:
		content.add_child(board.centered_label("Un jugador salió de la sala.",19,board.MUTED))
	else:
		var requested=rematch.get("requested",[false,false])
		var ready=rematch.get("ready",[false,false])
		for slot in range(2):
			var player=online.room.get("players",[])[slot]
			content.add_child(board.centered_label(str(player.get("name","Jugador"))+": "+("Confirmado" if ready[slot] else "Eligiendo mazo" if requested[slot] else "Esperando revancha"),20,board.MUTED))
		if not requested[online.slot]:
			content.add_child(board.button("Revancha",request_rematch,online.busy,true))
		else:
			content.add_child(board.centered_label("Puedes cambiar tu mazo antes de confirmar.",17,board.MUTED))
			var center=CenterContainer.new();content.add_child(center)
			var chooser=OptionButton.new();chooser.custom_minimum_size=Vector2(420,46)
			var decks=board.collection.playable_decks();var selected=str(rematch.get("deck_id",""))
			for d in decks:
				chooser.add_item(str(d.nombre))
				if str(d.id)==selected:chooser.select(chooser.item_count-1)
			chooser.disabled=online.busy
			chooser.set_meta("rematch_deck",true)
			chooser.item_selected.connect(func(i):online.rematch_action("choose",str(decks[i].id)))
			center.add_child(chooser)
			content.add_child(board.button("Confirmado" if ready[online.slot] else "Confirmar revancha",online.rematch_action.bind("ready"),online.busy or ready[online.slot] or not (requested[0] and requested[1]),true))
	if not online.last_error.is_empty() or not online.connected:content.add_child(board.centered_label(online.status,16,board.MUTED))
	content.add_child(board.button("Salir de la sala",online.leave,online.busy))
