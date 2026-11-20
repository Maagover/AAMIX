extends RefCounted
## Portrait presentation of the existing client. Rules and service calls stay shared.
var b
var page_root
var builder_tab = "library"
var collection_specials = false
const WIDTH = 480.0

func _init(board): b = board

func text(parent, value, size = 18, centered = false, color = null):
	var label = b.label(str(value),size,b.TEXT if color == null else color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func button(parent, caption, action, disabled = false, primary = false):
	var node = b.button(caption,action,disabled,primary)
	node.custom_minimum_size.y = 50
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",18)
	parent.add_child(node)
	return node

func icon(parent, caption, action):
	var node = button(parent,caption,action)
	node.custom_minimum_size = Vector2(44,44)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.tooltip_text=caption
	var art
	match caption:
		"Amigos":art=preload("res://heart_icon.gd").new().configure(24)
		"Tienda":art=preload("res://cart_icon.gd").new().configure(24)
		"Regalo":art=b.UIIcons.view("gift",24)
		"Ajustes":art=b.asset_image("estetica_v150/configuracion.png",24,24)
	if art!=null:
		node.text=""
		var center=CenterContainer.new();center.mouse_filter=Control.MOUSE_FILTER_IGNORE;center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);node.add_child(center);center.add_child(art)
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	else:
		node.text={"Volver":"‹","Inicio":"⌂","Salir":"×","Registro":"≡"}.get(caption,caption)
		node.add_theme_font_size_override("font_size",25)
	return node

func page(title, back = Callable(), paper = true):
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(center)
	var width = minf(WIDTH,b.get_viewport_rect().size.x)
	var height = b.get_viewport_rect().size.y
	var margin = MarginContainer.new()
	margin.custom_minimum_size = Vector2(width,height)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	center.add_child(margin)
	var outer = b.box(margin,true,12)
	outer.set_meta("mobile_screen",b.screen)
	page_root = outer
	if title != "":
		var logo_center = CenterContainer.new();outer.add_child(logo_center)
		logo_center.add_child(b.asset_image("logo_color.png",190,46,true))
		var head = b.box(b.panel(outer),false,7)
		icon(head,"Volver",b.go_home if not back.is_valid() else back)
		text(head,title,23,true)
		icon(head,"Inicio",b.go_home)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("mobile_scroll",true)
	outer.add_child(scroll)
	var shell = b.panel(scroll) if paper else VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not paper: scroll.add_child(shell)
	var body = b.box(shell,true,14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return body

func render_screen():
	match b.screen:
		"intro": intro()
		"home": home()
		"single": single()
		"tutorial": tutorial_intro()
		"decks", "gift": decks()
		"versus": versus()
		"account": account()
		"cards": cards()
		"shop": shop()
		"missions", "event", "gift_code", "packs": rewards()
		"challenges": challenges()
		"multiplayer": multiplayer()
		"friends", "trades": social()
		"deck_builder": builder()
		"table": table()
		_: return false
	fit_tree(page_root,minf(WIDTH,b.get_viewport_rect().size.x)-24)
	return true

func intro():
	var body = page("",Callable(),false)
	hero(body,280)
	button(body,"Iniciar sesión",b.open_account,false,true)
	button(body,"Jugar como invitado",b.play_guest)
	text(body,"Usa tu misma cuenta de PC para recuperar tus cartas y mazos.",17,true,Color("fff3d1"))

func home():
	var body = page("",Callable(),false)
	var head = b.box(b.panel(body),false,7)
	var profile = b.button("",b.open_account)
	profile.custom_minimum_size = Vector2(48,48)
	var avatar = b.profiles.avatar(b.profiles.current_code(),42)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile.add_child(avatar);head.add_child(profile)
	var identity = b.box(head,true,2);identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(identity,"Invitado" if b.guest else b.account.display_name(),17)
	if not b.guest: text(identity,"%d Restos" % b.collection.restos,14)
	icon(head,"Amigos",b.social_ui.open_friends)
	icon(head,"Tienda",b.go_shop)
	icon(head,"Regalo",b.open_account_feature.bind("gift_code"))
	icon(head,"Ajustes",b.show_configuration)
	hero(body,260)
	for option in [["Partida individual",b.open_single],["Multijugador",b.show_multiplayer],["Mi Colección",b.open_collection],["Misiones",b.open_account_feature.bind("missions")]]:
		button(body,option[0],option[1],false,option[0]=="Partida individual")
	if not b.collection.active_events().is_empty(): button(body,"Evento activo",b.rewards.open_screen.bind("event"))
	text(body,"AAMIX · Versión web de prueba",13,true,Color("fff3d1"))

func hero(parent,height):
	var frame=Control.new();frame.custom_minimum_size.y=height;frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(frame)
	var art=b.HomeCards.new();art.size=Vector2(520,360)
	art.featured_texture=b.texture_code("0119");art.resource_texture=b.texture_code("0100")
	art.logo_texture=b.asset_texture("logo_color.png",true);art.animated=b.animations_enabled;frame.add_child(art)
	frame.resized.connect(fit_hero.bind(frame,art))
	fit_hero.call_deferred(frame,art)

func fit_hero(frame,art):
	if not is_instance_valid(frame) or not is_instance_valid(art):return
	var ratio=minf(frame.size.x/540.0,frame.size.y/400.0)
	art.scale=Vector2.ONE*ratio;art.position=Vector2((frame.size.x-520*ratio)/2.0,40*ratio)

func single():
	var body = page("Partida individual")
	text(body,"Elige cómo quieres jugar",22,true)
	button(body,"Partida aleatoria",b.open_random,false,true)
	button(body,"Desafío AAMIX",b.open_challenges,false,true)
	button(body,"Tutorial con Sam",b.tutorial.start)
	if b.started and b.game.winner == -1: button(body,"Continuar partida",func():b.screen="table";b.render())
	if b.event_battle_available(): button(body,"Partida de evento",b.open_event_battle)

func tutorial_intro():
	var body=page("Tutorial con Sam",b.tutorial.leave)
	var center=CenterContainer.new();body.add_child(center)
	center.add_child(b.asset_image("actualizacion_v111/sam.png",190,190))
	text(body,"Hola, soy Sam. Vamos a practicar las reglas de AAMIX en el tablero.",23,true)
	button(body,"Comenzar",b.tutorial.begin,false,true)
	button(body,"Saltar tutorial",b.tutorial.leave)

func deck_row(parent, deck, action, caption = "Elegir", selected = false):
	var row = b.box(b.panel(parent),false,12)
	row.set_meta("mobile_deck",str(deck.get("id","")))
	row.add_child(b.deck_cover(deck,80,108))
	var info = b.box(row,true,7);info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text(info,str(deck.nombre),20)
	var count = 0
	for entry in deck.cartas: count += int(entry.cantidad)
	text(info,"%d cartas%s" % [count," · Borrador" if deck.get("draft",false) else ""],14)
	button(info,"Seleccionado" if selected else caption,action,b.collection.busy,selected or caption=="Elegir")
	return info

func decks():
	var gift = b.screen == "gift"
	var body = page("Tu primer mazo" if gift else "Elige tu mazo",b.open_single)
	if gift: text(body,"Elige uno de los tres mazos base. El regalo se entrega una sola vez por cuenta.",18)
	var available = b.game.decklists if gift else b.play_decks()
	for i in range(available.size()):
		var deck = available[i]
		var action = b.confirm_gift.bind(deck) if gift else b.start_match.bind(i)
		var info = deck_row(body,deck,action)
		button(info,"Ver mazo",b.preview_deck.bind(deck))

func versus():
	if b.pending_match.is_empty(): single();return
	var body = page("Preparar partida",b.open_single)
	text(body,str(b.pending_match.opponent.nombre),26,true)
	var center = CenterContainer.new();body.add_child(center)
	center.add_child(b.deck_cover(b.pending_match.opponent,220,290))
	text(body,"Tu mazo: "+b.owned_or_guest_deck_name(b.pending_match.deck_id),20,true)
	if b.rewards.match_status != "": text(body,b.rewards.match_status,17)
	button(body,"Preparando…" if b.rewards.preparing else "Comenzar",b.begin_prepared_match,b.rewards.preparing or b.collection.busy or b.account.busy,true)

func account():
	var body = page("Mi cuenta" if b.account.signed_in() else "Iniciar sesión")
	if b.account.signed_in():
		var row = b.box(body,false,12)
		row.add_child(b.profiles.avatar(b.profiles.current_code(),72))
		button(row,"Elegir foto de perfil",b.profiles.show_picker,b.collection.busy or b.account.busy)
		text(body,b.account.display_name(),26)
		text(body,str(b.account.user.get("email","")),16)
		text(body,"Tu ID de jugador",16)
		b.account_field(body,"",b.account.player_id(),"","unused_identity",true)
		button(body,"Copiar ID",b.copy_player_id)
		text(body,"Este ID identifica la misma cuenta en PC y celular.",16)
		button(body,"Cerrar sesión",b.account.sign_out,b.account.busy or b.collection.busy)
		return
	var tabs = b.box(body,false,8)
	button(tabs,"Ingresar",b.account_mode.bind(false),b.account.busy,not b.account_register)
	button(tabs,"Crear cuenta",b.account_mode.bind(true),b.account.busy,b.account_register)
	text(body,"Ingresa con tu correo y el código que recibirás.",18)
	if b.account_register and not b.account.code_sent:
		b.account_field(body,"Nombre visible",b.account_nickname,"Cómo te verán tus amigos","account_nickname",b.account.busy)
	b.account_field(body,"Correo",b.account.pending_email if b.account.code_sent else b.account_email,"tu@correo.com","account_email",b.account.busy or b.account.code_sent)
	if b.account.code_sent:
		var field = b.account_field(body,"Código recibido",b.account_code,"Código del correo","account_code",b.account.busy)
		field.text_submitted.connect(func(_value):b.account.verify_code(b.account_code))
		button(body,"Verificar e ingresar",func():b.account.verify_code(b.account_code),b.account.busy,true)
		button(body,"Reenviar código",b.send_account_code,b.account.busy)
		button(body,"Usar otro correo",b.account_mode.bind(b.account_register),b.account.busy)
	else: button(body,"Enviar código",b.send_account_code,not b.account.configured or not b.account.registration_ready or b.account.busy,true)
	text(body,b.account.status,16)
	button(body,"Jugar como invitado",b.play_guest,b.account.busy)

func signed_body(title):
	if not b.account.signed_in(): b.screen="account";account();return null
	return page(title)

func collection_tabs(parent):
	var tabs = b.box(parent,false,6)
	for item in [["Colección","collection"],["Mis Mazos","decks"]]:
		var node = button(tabs,item[0],b.select_cards_tab.bind(item[1]),false,b.cards_tab==item[1] and b.screen=="cards")
		node.add_theme_font_size_override("font_size",15)
	var packs = button(tabs,"Mis sobres",b.rewards.open_screen.bind("packs"),false,b.screen=="packs")
	packs.add_theme_font_size_override("font_size",15)

func card_tile(parent, code, amount, width = 78, show_name = false):
	var slot = b.box(parent,true,3)
	slot.custom_minimum_size.x = width
	var picture = b.button("",b.catalog_detail.bind(code))
	picture.custom_minimum_size = Vector2(width,width*1.4)
	picture.set_meta("mobile_catalog_card",code)
	var art = b.catalog_image(code,width,width*1.4)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(art);slot.add_child(picture)
	if amount == 0: art.modulate = Color(0.3,0.3,0.3,0.3)
	text(slot,str(code)+" · ×%d" % amount,12,true)
	if show_name: text(slot,b.game.catalog[code].nombre,13,true)
	return slot

func cards():
	var body = signed_body("Mi Colección")
	if body == null: return
	collection_tabs(body)
	if not b.collection.loaded: text(body,"Cargando tu colección…");return
	if b.cards_tab == "decks":
		for deck in b.collection.decks:
			var info = deck_row(body,deck,b.preview_deck.bind(deck),"Ver")
			if deck.get("custom",false) or deck.get("editable",false):button(info,"Editar",b.deck_builder.open.bind(deck),b.collection.busy)
			if deck.get("custom",false):button(info,"Eliminar",b.confirm_delete_deck.bind(deck),b.collection.busy)
		button(body,"+ Crear mazo",b.deck_builder.open,b.collection.busy,true)
		return
	var codes = b.game.catalog.keys().filter(b.collection_card_visible);codes.sort()
	var total = 0;var collected = 0
	for code in codes:
		total += int(b.collection.cards.get(code,0))
		if int(b.collection.cards.get(code,0))>0: collected+=1
	text(body,"%d cartas · %d de %d coleccionadas" % [total,collected,codes.size()],16,true)
	for family in ["normal","promocionales","exclusive"]:
		var selected = codes.filter(func(code):
			var d=b.game.catalog[code]
			return (d.get("event_exclusive",false) if family=="exclusive" else (not d.get("event_exclusive",false) and (d.get("subcoleccion","")=="promocionales" if family=="promocionales" else d.get("subcoleccion","")!="promocionales"))))
		if selected.is_empty(): continue
		if family != "normal": text(body,"Promocionales" if family=="promocionales" else "Cartas exclusivas",21,true)
		var grid = GridContainer.new();grid.columns=5
		grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",12)
		body.add_child(grid)
		for code in selected: card_tile(grid,code,int(b.collection.cards.get(code,0)))

func shop():
	var body = signed_body("Tienda")
	if body == null:return
	text(body,"%d Restos" % b.collection.restos,21,true)
	button(body,"Recargar tienda",b.collection.load_inventory,b.collection.busy)
	if not b.collection.loaded:text(body,"Cargando tienda…");return
	if not b.shop.pending_purchase.is_empty(): button(body,"Reintentar compra pendiente",b.shop.complete_purchase,b.collection.busy,true)
	var grid=GridContainer.new();grid.columns=4
	grid.add_theme_constant_override("h_separation",7);grid.add_theme_constant_override("v_separation",12);body.add_child(grid)
	var available=b.collection.shop.duplicate();available.sort_custom(func(a,c):return int(a.price)<int(c.price) if a.price!=c.price else str(a.code)<str(c.code))
	for entry in available:
		if not b.game.catalog.has(entry.code):continue
		var d=b.game.catalog[entry.code]
		if d.clase=="Recurso" or d.get("subcoleccion","") in ["promocionales","promocional"]:continue
		var item=b.box(grid,true,4)
		var picture=b.catalog_image(entry.code,96,132);item.add_child(picture)
		var price=button(item,"%d Restos" % entry.price,b.shop.confirm_purchase.bind(str(entry.code),int(entry.price)),b.collection.busy or not b.shop.pending_purchase.is_empty() or b.collection.restos<int(entry.price),true)
		price.add_theme_font_size_override("font_size",13)

func rewards():
	var title={"missions":"Misiones","event":"Misiones","gift_code":"Código de regalo","packs":"Mis sobres"}.get(b.screen,"Recompensas")
	var body=signed_body(title)
	if body==null:return
	if b.screen in ["missions","event"]:
		var tabs=b.box(body,false,6)
		for entry in [["Diarias","daily"],["Históricas","lifetime"],["Evento","event"]]:
			var choose=button(tabs,entry[0],b.rewards.change_mission_tab.bind(entry[1]),false,b.rewards.mission_tab==entry[1])
			choose.add_theme_font_size_override("font_size",15)
		if b.screen=="event" or b.rewards.mission_tab=="event":b.rewards.render_event(body)
		else:b.rewards.render_mission(body)
	elif b.screen=="gift_code":b.rewards.render_code(body)
	else:
		collection_tabs(body)
		if b.collection.pending_opening is Dictionary:
			b.rewards.render_packs(body)
		else:
			var kinds=[["tc",b.collection.packs,"Sobres TC",preload("res://pack_art.gd").texture(false)],["normal_card",b.collection.normal_packs,"Carta aleatoria",preload("res://normal_pack_art.gd").texture(false)],["halloween",b.collection.halloween_packs,"AAMIX Halloween",preload("res://halloween_pack_art.gd").texture(false)]]
			var empty=true
			for pack in kinds:
				if int(pack[1])<=0:continue
				empty=false
				var row=b.box(b.panel(body),false,12)
				var art=TextureRect.new();art.texture=pack[3];art.custom_minimum_size=Vector2(82,126);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(art)
				var info=b.box(row,true,7);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				text(info,pack[2],21);text(info,"%d disponibles" % int(pack[1]),16)
				button(info,"Abrir",b.rewards.start_opening.bind(pack[0]),b.collection.busy or b.rewards.opening_in_flight,true)
				if int(pack[1])>1:button(info,"Abrir todos",b.rewards.start_opening.bind(pack[0],true),b.collection.busy or b.rewards.opening_in_flight)
			if empty:text(body,"No tienes sobres por abrir",22,true)
	if b.collection.status!="":text(body,b.collection.status,16)

func challenges():
	var body=signed_body("Desafío AAMIX")
	if body==null:return
	var definition=b.CHALLENGES[b.challenge_page]
	var state=b.challenge_state(definition.stage)
	text(body,"Nivel %d" % definition.stage,27,true)
	if not state.get("unlocked",false):
		text(body,"Bloqueado",25,true)
		text(body,"Gana el nivel anterior para continuar.",18,true)
	else:
		text(body,definition.title,24,true)
		var center=CenterContainer.new();body.add_child(center);center.add_child(b.deck_cover(definition.deck_id,170,220))
		if b.challenge_ui==null:b.challenge_ui=preload("res://challenge_ui.gd").new(b)
		var completed=bool(state.get("completed",false))
		b.challenge_ui.mission_row(body,definition.stage,{"id":"first_victory","title":"Primera victoria","goal":1,"progress":1 if completed else 0,"claimed":completed,"can_claim":false,"reward_packs":definition.reward_packs,"reward_cover":definition.has("reward_cover")})
		for mission in state.get("missions",[]):b.challenge_ui.mission_row(body,definition.stage,mission)
		button(body,"Volver a jugar" if completed else "Jugar nivel",b.choose_challenge.bind(definition.stage),b.collection.busy,true)
	var controls=b.box(body,false,8)
	button(controls,"Anterior",challenge_page.bind(-1),b.challenge_page<=0)
	text(controls,"%d / %d" % [b.challenge_page+1,b.CHALLENGES.size()],18,true)
	button(controls,"Siguiente",challenge_page.bind(1),b.challenge_page>=b.CHALLENGES.size()-1)

func challenge_page(delta):
	b.challenge_page=clampi(b.challenge_page+delta,0,b.CHALLENGES.size()-1);b.render()

func multiplayer():
	var body=signed_body("Multijugador")
	if body==null:return
	var online=b.online;var ui=b.online_ui
	if not online.incompatible_room.is_empty():
		text(body,"Sala con otra versión de las reglas",23,true)
		text(body,online.status,17)
		button(body,"Cerrar sala anterior",ui.confirm_incompatible_leave,online.busy,true);return
	if not online.room.is_empty():
		if str(online.room.get("status",""))=="finished":ui.render_rematch(body);return
		text(body,"Sala privada",25,true)
		text(body,str(online.room.get("code","")),32,true)
		button(body,"Copiar código",func():DisplayServer.clipboard_set(str(online.room.get("code",""))))
		var people=b.box(body,false,12)
		var entries=online.room.get("players",[])
		for p in range(2):
			var info=b.box(b.panel(people),true,8);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var entry=entries[p] if entries.size()>p else {}
			text(info,str(entry.get("name","Esperando jugador")),18,true)
			text(info,"Confirmado" if online.room.get("confirmed",[false,false])[p] else "Por confirmar",14,true)
		text(body,online.status,17,true)
		if str(online.room.get("status","")) in ["waiting","ready"]:
			var confirmed=bool(online.room.get("confirmed",[false,false])[online.slot])
			button(body,"Confirmado" if confirmed else "Confirmar",online.confirm,online.busy or confirmed,true)
		if online.in_match():button(body,"Volver a la partida",ui.resume_match,false,true)
		button(body,"Abandonar sala",ui.confirm_leave,online.busy)
		return
	if ui.section=="hub":
		text(body,"Juega con un amigo o intercambia cartas.",20,true)
		button(body,"Partida privada",ui.open_private,false,true)
		button(body,"Intercambio",b.social_ui.open_trades)
		return
	if online.lobby_mode in ["create","join"]:
		text(body,"Crear sala" if online.lobby_mode=="create" else "Unirme a una sala",25,true)
		if online.lobby_mode=="join":
			var field=LineEdit.new();field.custom_minimum_size.y=50;field.max_length=8;field.text=online.joining_code;field.placeholder_text="Código de la sala";field.text_changed.connect(func(value):online.joining_code=str(value).to_upper());body.add_child(field)
		text(body,"Elige tu mazo",20)
		for deck in b.collection.playable_decks():deck_row(body,deck,ui.select_deck.bind(str(deck.id)),"Elegir",str(deck.id)==online.selected_deck)
		button(body,"Crear sala" if online.lobby_mode=="create" else "Unirme",ui.launch_room,online.busy or online.selected_deck.is_empty(),true)
		button(body,"Volver",ui.choose_mode.bind("choice"),online.busy)
	else:
		text(body,"Salas privadas para 2 jugadores",21,true)
		button(body,"Crear sala",ui.choose_mode.bind("create"),online.busy,true)
		button(body,"Unirme con código",ui.choose_mode.bind("join"),online.busy)
		button(body,"Retomar sala",online.discover,online.busy)
		text(body,"El creador debe mantener el juego abierto y en primer plano durante la partida.",16,true)
	if online.status!="":text(body,online.status,17,true)

func social():
	var body=signed_body("Amigos" if b.screen=="friends" else "Intercambio")
	if body==null:return
	button(body,"Recargar",b.social_ui.reload,b.social.busy)
	if b.social.status!="":text(body,b.social.status,16)
	if not b.social.loaded:text(body,"Conectando con tus amigos…");return
	if b.screen=="friends":b.social_ui.render_friends(body)
	else:b.social_ui.render_trades(body)
	b.social_ui.present_received.call_deferred()

func builder():
	var db=b.deck_builder
	if db.owner!=b.account.player_id() or db.editing.is_empty():db.close();return
	var body=page("Crear mazo" if str(db.editing.id).is_empty() else "Editar mazo",db.leave)
	db.counters.clear()
	text(body,"Nombre del mazo",16)
	var name_field=LineEdit.new();name_field.custom_minimum_size.y=48;name_field.text=str(db.editing.nombre);name_field.max_length=48;name_field.text_changed.connect(func(value):db.editing.nombre=value;db.refresh_validity());body.add_child(name_field)
	var cover=b.box(body,false,12);cover.add_child(b.deck_cover(db.editing,52,70));button(cover,"Elegir diseño",db.open_design_picker,db.locked())
	db.total_label=text(body,"",20,true)
	text(body,"40 cartas para jugar · 3 copias por carta · 1 por Singular",14,true)
	var search=LineEdit.new();search.custom_minimum_size.y=48;search.text=db.query;search.placeholder_text="Buscar por nombre o número";body.add_child(search)
	var tabs=b.box(body,false,6)
	button(tabs,"Cartas disponibles",set_builder_tab.bind("library"),false,builder_tab=="library")
	button(tabs,"Tu mazo",set_builder_tab.bind("selected"),false,builder_tab=="selected")
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",12);body.add_child(grid)
	db.selected_list=b.box(body,true,5);db.selected_list.visible=false
	var codes=b.collection.cards.keys()
	codes.sort()
	for code in codes:
		if not b.game.catalog.has(code) or int(b.collection.cards[code])<=0:continue
		if builder_tab=="selected" and db.quantity(code)<=0:continue
		if not db.query.strip_edges().is_empty() and not (str(code)+" "+str(b.game.catalog[code].nombre)).to_lower().contains(db.query.strip_edges().to_lower()):continue
		var slot=b.box(grid,true,4)
		var picture=b.button("",b.catalog_detail.bind(code));picture.custom_minimum_size=Vector2(130,150);picture.add_child(b.catalog_image(code,108,148));slot.add_child(picture)
		text(slot,b.game.catalog[code].nombre,14,true)
		text(slot,"Tienes %d · Máx. %d" % [int(b.collection.cards[code]),db.maximum(code)],12,true)
		var controls=b.box(slot,false,3)
		var minus=button(controls,"−",db.change.bind(code,-1))
		var amount=text(controls,str(db.quantity(code)),17,true)
		var plus=button(controls,"+",db.change.bind(code,1))
		db.counters[code]={"amount":amount,"minus":minus,"plus":plus}
	db.hint_label=text(body,"",15)
	db.save_button=button(body,"Guardar y usar",db.save.bind(false),false,true)
	db.draft_button=button(body,"Guardar borrador",db.save.bind(true))
	search.text_changed.connect(func(value):db.query=value)
	search.text_submitted.connect(func(_value):b.render())
	button(body,"Aplicar búsqueda",b.render)
	db.refresh_validity()

func set_builder_tab(value):builder_tab=value;b.render()

func popup(title, kind = "detail", tall = false):
	var center=b.overlay(kind);var shade=center.get_parent()
	var panel=b.panel(center)
	panel.custom_minimum_size.x=minf(440,b.get_viewport_rect().size.x-24)
	var outer=b.box(panel,true,12)
	text(outer,title,24,true)
	var body=outer
	if tall:
		var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,minf(650,b.get_viewport_rect().size.y-180));scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
		body=b.box(scroll,true,10);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(outer,"Cerrar",b.close_overlay.bind(shade))
	return body

func detail(code, uid = -1):
	if not b.game.catalog.has(code):return
	var d=b.game.catalog[code]
	var body=popup(d.nombre+" · "+str(code),"detail" if uid==-1 else "inspection_detail",true)
	var center=CenterContainer.new();body.add_child(center);center.add_child(b.catalog_image(code,235,330))
	text(body,d.clase+(" · Coste %d" % int(d.coste) if d.clase!="Recurso" else ""),18,true)
	if d.clase=="Aliado":text(body,"Fuerza %d" % (b.game.force(uid) if uid!=-1 else int(d.fuerza)),18,true)
	text(body,str(d.get("texto_juego",d.get("texto_impreso",""))),18)
	if uid==-1:text(body,"En tu colección: %d" % int(b.collection.cards.get(code,0)),16,true)
	elif b.game.actor==b.human and b.can_activate(uid):button(body,"Usar habilidad",b.use_card_action.bind(uid,true),false,true)
	if uid!=-1 and b.game.actor==b.human and b.game.code(uid)=="0134" and b.game.location(uid).get("zone")=="graveyard" and b.game.can_play(uid):button(body,"Jugar desde Cementerio",b.use_card_action.bind(uid,false),false,true)

func preview_deck(deck):
	var total=0
	for entry in deck.cartas:total+=int(entry.cantidad)
	var body=popup(str(deck.nombre)+" · %d cartas" % total,"detail",true)
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",10);body.add_child(grid)
	var entries=deck.cartas.duplicate(true);entries.sort_custom(func(a,c):return str(a.codigo)<str(c.codigo))
	for entry in entries:card_tile(grid,entry.codigo,int(entry.cantidad),116,true)

func choice():
	var pending=b.game.pending
	if pending.kind=="counter":return false
	var body=popup(str(pending.title),"choice",true)
	text(body,"Seleccionadas %d / %d" % [b.choice_selected.size(),int(pending.max)],16,true)
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);body.add_child(grid)
	for uid in pending.options:
		var surface=b.card(grid,uid,"choice",b.human,112,152,uid in b.choice_selected)
		surface.clicked=b.select_choice.bind(uid)
	if pending.optional:button(body,"Omitir / cancelar",b.skip_choice)
	button(body,"Confirmar",b.confirm_choice,b.choice_selected.size()<int(pending.min) or b.choice_selected.size()>int(pending.max),true)
	return true

func fit_tree(node, width):
	if node==null or not is_instance_valid(node):return
	var child_width=width
	if node is Control:
		if node.custom_minimum_size.x>width:node.custom_minimum_size.x=width
		if node is Label:
			node.autowrap_mode=TextServer.AUTOWRAP_OFF if node.get_meta("mobile_no_wrap",false) else TextServer.AUTOWRAP_WORD_SMART
			node.text=node.text.replace(String.chr(26)," / ")
			if node.get_theme_font_size("font_size")>26:node.add_theme_font_size_override("font_size",26)
		if node is Button:
			if node.get_combined_minimum_size().x>width:node.clip_text=true
			node.tooltip_text=node.text if node.tooltip_text.is_empty() else node.tooltip_text
		if node is ScrollContainer:node.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		if node is GridContainer:
			var largest=0.0
			for child in node.get_children():
				if child is Control:largest=maxf(largest,child.custom_minimum_size.x)
			if largest>0:node.columns=mini(node.columns,maxi(1,int(width/(largest+6))))
			child_width=(width-8*(node.columns-1))/node.columns
		elif node is HBoxContainer:
			var minimum=0.0;var count=0
			for child in node.get_children():
				if child is Control and child.visible:minimum+=child.get_combined_minimum_size().x;count+=1
			if minimum>width and count>0:child_width=maxf(60,(width-7*(count-1))/count)
	for child in node.get_children():fit_tree(child,child_width)

func fit_overlays():
	if not b.mobile_layout:return
	for shade in b.overlay_shades:
		if is_instance_valid(shade):fit_tree(shade,minf(440,b.get_viewport_rect().size.x-24))

func table():
	var root=page("",Callable(),false)
	root.add_theme_constant_override("separation",5)
	var header=b.box(root,false,5)
	header.add_child(b.home_logo(100,27))
	text(header,("TU TURNO" if b.game.active==b.human else "TURNO RIVAL")+" · %d" % b.game.turn,12,true,Color("fff3d1"))
	icon(header,"Ajustes",b.show_configuration)
	icon(header,"Registro",b.show_log)
	icon(header,"Salir",b.confirm_abandon_match)
	if b.tutorial.active:
		var guide=b.box(b.panel(root),true,5)
		text(guide,str(b.tutorial.messages.get(b.tutorial.step,"")).replace("Haz doble clic","Mantén pulsado"),15)
		if b.tutorial.step in ["new_turn","blocking_intro","ability_intro","object_intro","object_done","domain_done","unblock_intro","singular_intro","singular","finish"]:button(guide,"Partida de práctica" if b.tutorial.step=="finish" else "Continuar",b.tutorial.next,false,true)
	b.opponent_hand(root)
	var piles=b.box(root,false,4)
	for z in ["resources","paid","deck","graveyard","burned"]:mobile_pile(piles,z,b.computer,false)
	mobile_lane(root,b.computer,"defense","DEFENSA RIVAL")
	mobile_lane(root,b.computer,"attack","ATAQUE RIVAL")
	var domain_center=CenterContainer.new();root.add_child(domain_center)
	var domain=b.zone(domain_center,"domain",-1,b.game.domain_uid)
	domain.custom_minimum_size=Vector2(105,62);domain.set_meta("shared_domain",true);domain.set_meta("pile",true)
	var row=b.box(domain,false,5);text(row,"DOMINIO",11,true)
	if b.game.domain_uid!=-1:row.add_child(b.image_card(b.game.domain_uid,36,50))
	b.attach_indicator(domain)
	var own=b.box(root,false,6)
	var side=b.box(own,true,4);side.custom_minimum_size.x=58
	for z in ["paid","deck","resources","graveyard","burned"]:mobile_pile(side,z,b.human,true)
	var lanes=b.box(own,true,5);lanes.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mobile_lane(lanes,b.human,"attack","TU ATAQUE")
	mobile_lane(lanes,b.human,"defense","TU DEFENSA")
	var hand=b.zone(root,"hand",b.human)
	var hand_body=b.box(hand,true,3)
	var hand_count=b.label("",12,b.MUTED);hand_body.add_child(hand_count);b.register_count(hand_count,b.human,"hand","TU MANO · "," cartas")
	var hand_scroll=ScrollContainer.new();hand_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;hand_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;hand_scroll.custom_minimum_size.y=101;hand_body.add_child(hand_scroll);b.hand_scroll=hand_scroll
	var cards_row=b.box(hand_scroll,false,2)
	for uid in b.game.players[b.human].hand:b.card(cards_row,uid,"hand",b.human,62,88)
	b.action_panel=b.panel(root)
	b.action_panel.set_meta("actions",true)
	b.action_bar(b.action_panel)
	for node in b.interface_nodes(b.action_panel):
		if node is Label:
			node.custom_minimum_size.x=0
			node.add_theme_font_size_override("font_size",13)
			if node.text.begins_with("Arrastra"):node.text=node.text.replace("Arrastra","Toca").replace("se sueltan","se juegan")
			if node.text=="ACCIONES" or node.text.is_empty() or (b.game.phase in ["main","after_combat"] and b.game.pending.is_empty() and b.game.payment_request.is_empty() and b.game.error.is_empty()):node.hide()
		if node is Button:
			node.custom_minimum_size=Vector2((minf(WIDTH,b.get_viewport_rect().size.x)-64)/2.0,44)
			node.add_theme_font_size_override("font_size",14)
	if b.tutorial.active:b.tutorial.decorate_board()
	for uid in b.moving_uids:b.hide_visual_uid(uid)
	if not b.presenting:
		if not b.game.pending.is_empty() and int(b.game.pending.player)==b.human and b.game.pending.kind not in ["end_discard","limit_keep"] and not b.choice_dismissed:b.show_choice()
		elif b.game.winner!=-1 and not b.overlay_shades.any(func(n):return n.get_meta("overlay_kind","")=="result"):b.show_winner()

func mobile_pile(parent,zone,owner,own):
	var cards=b.game.players[owner][zone]
	var uid=-1 if cards.is_empty() or zone=="deck" else cards.back()
	if zone=="paid" and not b.game.reserved[owner].is_empty():uid=b.game.reserved[owner].back()
	var holder=b.zone(parent,zone,owner,uid)
	holder.set_meta("pile",true);holder.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var body=b.box(holder,not own,0)
	body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var names={"resources":"RECURSOS","paid":"PAGADAS","deck":"MAZO","graveyard":"CEMENTERIO","burned":"QUEMADAS"}
	var caption={"resources":"REC.","paid":"PAG.","deck":"MAZO","graveyard":"CEM.","burned":"QUEM."}.get(zone,zone) if own else names[zone]
	var title=b.centered_label(caption,8 if own else 9,b.MUTED);body.add_child(title)
	title.set_meta("mobile_no_wrap",true)
	holder.tooltip_text=names[zone]
	var count=b.centered_label("",16,b.TEXT);count.set_meta("mobile_no_wrap",true);body.add_child(count);b.register_count(count,owner,zone)
	if own and zone in ["graveyard","burned"]:
		holder.clicked=b.inspect_zone.bind(owner,zone)
	if own and zone=="deck":
		holder.set_meta("pile_image",count)
	b.attach_indicator(holder)

func mobile_lane(parent,owner,zone,title):
	var holder=b.zone(parent,zone,owner)
	holder.custom_minimum_size.y=87
	var row=b.box(holder,false,4)
	var label=b.label(title.replace(" ","\n"),10,b.MUTED);label.custom_minimum_size.x=44;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
	var scroll=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;row.add_child(scroll)
	var cards=b.box(scroll,false,4)
	var current=b.game.players[owner][zone].duplicate()
	if owner==b.human and zone=="defense":current=current.filter(func(u):return u not in b.draft)
	if owner==b.human and zone=="attack":current.append_array(b.draft)
	for uid in current:b.card(cards,uid,"draft_attack" if uid in b.draft else zone,owner,48,66,uid in b.draft or b.block_marker_visible(uid))
