extends SceneTree
var b
var checks=0
var failures=[]
var identity="00000000-0000-4000-8000-000000000001"
func _initialize():run.call_deferred()
func frames(n=8):
	for i in range(n):await process_frame
func check(value,message):
	checks+=1
	if not value:failures.append(message);push_error(message)
func nodes():return b.interface_nodes(b)+b.interface_nodes(b.modal_layer)
func find_button(caption):
	for n in nodes():
		if n is Button and n.is_visible_in_tree() and n.text==caption:return n
	return null
func click_node(node,jitter=Vector2.ZERO):
	check(is_instance_valid(node),"Interactive control exists")
	if not is_instance_valid(node):return
	var at=node.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true)
	await frames(2)
	motion=InputEventMouseMotion.new();motion.position=at+jitter;motion.relative=jitter;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
	event=InputEventMouseButton.new();event.position=at+jitter;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;root.push_input(event,true)
	await frames()
func click(caption):await click_node(find_button(caption),Vector2(2,2))
func icon(caption):
	var found=nodes().filter(func(n):return n is Button and n.is_visible_in_tree() and n.tooltip_text==caption)
	check(not found.is_empty(),"Header control exists: "+caption)
	if not found.is_empty():await click_node(found[0])
func touch(caption):
	var node=find_button(caption);check(node!=null,"Touch target exists: "+caption)
	if node==null:return
	var at=node.get_global_rect().get_center()
	Input.emulate_mouse_from_touch=true
	var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true;Input.parse_input_event(event)
	await frames(2)
	event=InputEventScreenTouch.new();event.index=0;event.position=at+Vector2(2,2);event.pressed=false;Input.parse_input_event(event)
	await frames()
func screen(name):b.screen=name;b.render();await frames()
func run():
	root.size=Vector2i(480,900);root.content_scale_size=Vector2i(480,900)
	b=load("res://main.tscn").instantiate();root.add_child(b);b.mobile_layout=true;b.compact_layout=true;b.animations_enabled=false;b.automation_pause=true
	b.account.set_process(false);b.account.configured=false;b.rewards.set_process(false);b.online.set_process(false);b.online.realtime.set_process(false);b.social.set_process(false)
	await frames();await screen("intro");await click("Jugar como invitado");check(b.screen=="home" and b.guest,"Guest button routes to home with finger jitter")
	await click("Partida individual");check(b.screen=="single","Single-player button routes correctly")
	await click("Partida aleatoria");check(b.screen=="decks","Random match opens deck selection")
	await click("Inicio");check(b.screen=="home","Home control returns to home")
	await touch("Partida individual");check(b.screen=="single","ScreenTouch reaches the button with finger jitter")
	await click("Inicio")
	await screen("account");await click("Crear cuenta");check(b.account_register,"Registration tab selects registration")
	check(nodes().any(func(n):return n is LineEdit and n.get_meta("account_field","")=="account_password" and n.secret and n.max_length==128),"Password field is masked and accepts full passwords")
	check(find_button("Enviar código")==null,"OTP request is absent from mobile account")
	b.account.user={"id":identity,"email":"qa@example.invalid","user_metadata":{"display_name":"Prueba local"}};b.account.access_token="offline-ui-fixture";b.account.expires_at=Time.get_unix_time_from_system()+3600
	b.session_owner=identity;b.guest=false;b.collection.owner_id=identity;b.collection.loaded=true;b.collection.gift={"deck_id":"kajido"};b.collection.decks=b.game.decklists.duplicate(true);b.collection.set_process(false);b.collection.busy=true;b.social.busy=true
	for code in b.game.catalog:b.collection.cards[code]=3
	await screen("home");await icon("Amigos");check(b.screen=="friends","Friends icon opens friends")
	await screen("home");await icon("Tienda");check(b.screen=="shop","Shop icon opens shop")
	await screen("home");await icon("Regalo");check(b.screen=="gift_code","Gift icon opens redemption screen")
	check(find_button("Canjear código")!=null or find_button("Canjear")!=null,"Redemption control is present")
	await screen("home");await icon("Ajustes");check(b.overlay_shades.any(func(n):return n.get_meta("overlay_kind","")=="configuration"),"Settings icon opens settings")
	await click("Sonido");check(b.overlay_shades.any(func(n):return n.get_meta("overlay_kind","")=="audio"),"Sound button opens sound controls")
	await screen("home");await click("Mi Colección");check(b.screen=="cards","Collection button opens collection")
	await click("Mis Mazos");check(b.cards_tab=="decks","Deck tab opens owned decks")
	await click("Mis sobres");check(b.screen=="packs","Pack tab opens packs")
	await click("Inicio");await click("Misiones");check(b.screen=="missions","Missions button opens missions")
	await click("Históricas");check(b.rewards.mission_tab=="lifetime","Historical mission tab has correct destination")
	await click("Evento");check(b.rewards.mission_tab=="event","Event tab has correct destination")
	await screen("home");await click("Multijugador");check(b.screen=="multiplayer","Multiplayer button opens its hub")
	await click("Partida privada");check(b.online_ui.section=="private","Private game opens room choices")
	b.collection.busy=false;b.social.busy=false
	await screen("account");b.account.password_recovery=true;b.render();await frames();check(find_button("Guardar contraseña")!=null,"Recovery link session routes to password form")
	b.account.password_recovery=false;b.account_register=false
	b.tutorial.start();b.tutorial.begin();b.tutorial.active=false;b.game.take_visual_events();b.presenting=false;b.screen="table";b.started=true;b.render();await frames()
	var stage=b.get_node_or_null("ReferenceBoard");check(stage!=null,"Reference board is rendered")
	if stage!=null:
		check(stage.get_meta("reference_size")==Vector2(916,1717),"Board retains exact reference proportions")
		var scale_before=stage.scale;b.pop_in(stage);await frames();check(stage.scale==scale_before,"Entry animation cannot move visual touch targets")
	for node in b.targets:
		if node.zone=="resources" and node.card_owner==b.human:check(node.has_meta("pile_image"),"Own resource pile uses PC card graphics")
	var resource=b.tutorial.refs.resource
	var source=b.targets.filter(func(n):return n.uid==resource and n.zone=="hand")[0]
	await click_node(source)
	check(b.tap_selection.get("uid",-1)==resource,"Pointer release selects actual card through GUI")
	var target=b.targets.filter(func(n):return n.zone=="resources" and n.card_owner==b.human)[0]
	await click_node(target)
	check(b.game.location(resource).zone=="resources","Pointer release plays actual card to resource pile")
	for n in nodes():
		if n is ScrollContainer:check(n.scroll_deadzone>=20,"Touch list allows finger jitter")
	b.account.access_token="";b.queue_free();await frames()
	print(JSON.stringify({"mobile_interactions":{"checks":checks,"failures":failures,"remote_writes":0}}));quit(0 if failures.is_empty() else 1)
