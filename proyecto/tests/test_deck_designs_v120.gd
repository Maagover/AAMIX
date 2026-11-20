extends SceneTree
## In-memory fixtures only. No credentials, account writes, cards or codes are sent.
const Rules = preload("res://deck_rules.gd")
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []

class FixtureCollection:
	extends "res://collection.gd"
	var sent = []
	var ambiguous = false
	func request(endpoint, payload):
		assert(endpoint == "aamix_save_custom_deck")
		sent.append(payload.duplicate(true))
		last_http_code = 0 if ambiguous else 200
		last_error_code = ""
		if ambiguous: return false
		var id = str(payload.p_deck_id)
		if id.is_empty(): id = "custom_00000000-0000-4000-8000-%012d" % sent.size()
		var deck = {"id":id,"nombre":payload.p_nombre,"portada":payload.p_portada,"cartas":payload.p_cartas.duplicate(true),"draft":payload.p_draft,"custom":true,"revision":int(payload.p_expected_revision)+1,"recurso_inicial":"0100"}
		var found = false
		for i in range(decks.size()):
			if str(decks[i].id) == id:
				decks[i] = deck
				found = true
		if not found: decks.append(deck)
		last_reply = {"last_saved_deck":deck.duplicate(true)}
		return true

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)

func tagged(node, key):
	var found = [node] if node.has_meta(key) else []
	for child in node.get_children(): found.append_array(tagged(child,key))
	return found

func buttons(node, value):
	var found = [node] if node is Button and node.text == value else []
	for child in node.get_children(): found.append_array(buttons(child,value))
	return found

func settle():
	for _i in range(8): await process_frame

func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var destination = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(destination) == OK:
		captures.append(destination)
	else:
		failures.append("No se pudo guardar captura: "+name)

func theme_mode(dark):
	ui.dark_theme = dark
	ui.apply_visual_palette()
	ui.theme = ui.visual_theme.make_theme()
	ui.render()
	await settle()

func fixture_deck():
	return {"id":"custom_00000000-0000-4000-8000-000000000120","nombre":"Mi mazo de prueba","portada":"custom_restos","custom":true,"draft":false,"revision":1,"recurso_inicial":"0100","cartas":[{"codigo":"0100","cantidad":40}]}

func run():
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.set_process(false)
	ui.account.configured = false
	ui.account.remember_me = false
	ui.account.refresh_token = ""
	ui.online.set_process(false)
	ui.online.realtime.set_process(false)
	ui.rewards.set_process(false)
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000120","user_metadata":{"display_name":"Prueba visual"}}
	ui.account.access_token = "local-fixture-not-a-credential"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.session_owner = ui.account.player_id()
	var old = ui.collection
	ui.remove_child(old)
	old.queue_free()
	ui.collection = FixtureCollection.new()
	ui.collection.account = ui.account
	ui.add_child(ui.collection)
	ui.collection.owner_id = ui.account.player_id()
	ui.collection.loaded = true
	ui.collection.cards = {"0100":60,"0102":3,"01c":1}
	ui.collection.restos = 275
	ui.collection.welcome_pack = {"claimed":true}
	ui.collection.restos_welcome_claimed = true
	ui.collection.changed.connect(ui.collection_changed)
	ui.collection.decks = [fixture_deck()]
	ui.guest = false
	ui.screen = "multiplayer"
	ui.render()
	await settle()
	var icon = tagged(ui,"multiplayer_battle_icon")[0]
	var title = tagged(ui,"multiplayer_title")[0]
	check(icon.global_position.y+icon.size.y <= title.global_position.y and absf(icon.global_position.x+icon.size.x/2-title.global_position.x-title.size.x/2) <= 2,"Icono de batalla centrado sobre Multijugador")
	await capture("01-multijugador-claro")
	ui.deck_builder.open(fixture_deck())
	await settle()
	check(buttons(ui,"Elegir diseño").size() == 1 and buttons(ui,"Transmisión Caída").is_empty() and buttons(ui,"Restos").is_empty(),"Constructor muestra un solo botón Elegir diseño")
	var initial = ui.deck_builder.editing.duplicate(true)
	var inventory = ui.collection.cards.duplicate(true)
	ui.deck_builder.open_design_picker()
	await settle()
	check(tagged(ui,"deck_design_option").size() == 2 and ui.deck_builder.picker_selected == "custom_restos","Sólo dos diseños gratuitos y portada existente preseleccionada")
	ui.deck_builder.select_design("custom_tsuki_akira")
	check(ui.deck_builder.picker_selected == "custom_restos","No permite elegir diseño bloqueado ni mediante llamada directa")
	ui.deck_builder.select_design("custom_transmision")
	ui.deck_builder.cancel_design()
	ui.deck_builder.confirm_design()
	await settle()
	check(ui.deck_builder.editing == initial and ui.collection.sent.is_empty(),"Cancelar galería conserva nombre, portada, cartas y cantidades")
	ui.deck_builder.open_design_picker()
	ui.deck_builder.select_design("custom_transmision")
	var escape = InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	ui._unhandled_key_input(escape)
	await settle()
	check(tagged(ui,"deck_design_picker").is_empty() and ui.deck_builder.editing == initial,"Escape cancela galería sin modificar formulario")
	ui.deck_builder.open_design_picker()
	ui.deck_builder.select_design("custom_transmision")
	ui.deck_builder.confirm_design()
	await settle()
	check(ui.deck_builder.editing.portada == "custom_transmision" and ui.collection.sent.is_empty() and ui.screen == "deck_builder","Elegir durante construcción cambia diseño sin guardar")
	ui.deck_builder.save(false)
	await settle()
	check(tagged(ui,"deck_design_picker").size() == 1 and ui.collection.sent.is_empty(),"Guardar finalizado pide diseño antes de escribir")
	ui.deck_builder.cancel_design()
	check(ui.deck_builder.editing.cartas == initial.cartas and ui.screen == "deck_builder","Cancelar guardado mantiene formulario completo")
	ui.deck_builder.save(false)
	ui.deck_builder.select_design("custom_restos")
	ui.deck_builder.confirm_design()
	await settle()
	check(ui.collection.sent.size() == 1 and not ui.collection.sent[0].p_draft and ui.collection.sent[0].p_portada == "custom_restos" and ui.collection.cards == inventory,"Confirmar guarda finalizado con diseño sin consumir cartas")
	var locked = fixture_deck()
	locked.portada = "custom_chanchuus"
	var sent_count = ui.collection.sent.size()
	check(not await ui.collection.save_custom_deck(locked) and ui.collection.sent.size() == sent_count,"Guardado local rechaza diseño aún bloqueado")
	ui.deck_builder.open()
	ui.deck_builder.change("0102",3)
	ui.deck_builder.save(true)
	await settle()
	check(tagged(ui,"deck_design_picker").size() == 1 and ui.collection.sent.size() == sent_count,"Guardar borrador también pide diseño")
	ui.deck_builder.confirm_design()
	await settle()
	check(ui.collection.sent.size() == sent_count+1 and ui.collection.sent[-1].p_draft and ui.collection.cards == inventory,"Borrador conserva cantidades y no consume cartas")
	check(ui.collection.normalize_available_covers(null) == Rules.FREE_COVERS and ui.collection.normalize_available_covers(["kajido","invento"]) == Rules.FREE_COVERS,"Servidor anterior y diseños desconocidos no otorgan desbloqueos")
	ui.collection.available_custom_covers = ui.collection.normalize_available_covers(Rules.CUSTOM_COVERS + ["custom_viborin","kajido"])
	check(ui.collection.available_covers() == Rules.CUSTOM_COVERS,"Desbloqueos remotos conservan orden fijo sin duplicar diseños")
	ui.deck_builder.open(fixture_deck())
	await theme_mode(false)
	await capture("02-constructor-claro")
	ui.deck_builder.open_design_picker()
	await settle()
	var options = tagged(ui,"deck_design_option")
	check(options.size() == 5 and options.all(func(button):return button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= ui.size.x and button.get_global_rect().end.y <= ui.size.y),"Galería de cinco diseños cabe en pantalla")
	check(options.all(func(button):return button.get_child(0).get_meta("deck_cover", "") == button.get_meta("deck_design_option") and button.get_child(0).texture != null),"Cada diseño muestra su arte correspondiente y no una portada de respaldo")
	await capture("03-disenos-claro")
	ui.deck_builder.select_design("custom_tsuki_akira")
	ui.deck_builder.confirm_design()
	await settle()
	check(ui.deck_builder.editing.portada == "custom_tsuki_akira","Diseño desbloqueado puede seleccionarse")
	await theme_mode(true)
	await capture("04-constructor-oscuro")
	ui.deck_builder.save(false)
	await settle()
	await capture("05-disenos-oscuro")
	ui.deck_builder.select_design("custom_viborin")
	ui.collection.ambiguous = true
	ui.deck_builder.confirm_design()
	await settle()
	check(not ui.collection.pending_deck_save.is_empty() and ui.deck_builder.locked(),"Respuesta ambigua conserva UUID y bloquea edición")
	var retry_id = str(ui.collection.sent[-1].p_request_id)
	ui.collection.ambiguous = false
	ui.deck_builder.save(false)
	await settle()
	check(ui.collection.pending_deck_save.is_empty() and ui.collection.sent[-1].p_request_id == retry_id and ui.collection.sent[-1].p_portada == "custom_viborin" and tagged(ui,"deck_design_picker").is_empty(),"Reintento usa mismo UUID y diseño sin volver a abrir galería")
	var items = ui.rewards.code_reward_items({"reward_cover":"custom_chanchuus","reward_design":"custom_chanchuus"})
	check(items.size() == 1 and items[0].kind == "deck_design" and items[0].caption.contains("Diseño desbloqueado") and ui.collection.cards == inventory and ui.collection.restos == 275,"Canje presenta diseño desbloqueado y no promete cartas ni saldo")
	check(ui.collection.redemption_message({"reward_cover":"custom_chanchuus"}).contains("Diseño desbloqueado") and ui.collection.redemption_message({"reward_cover":"custom_chanchuus","already_redeemed":true}).contains("Ya desbloqueaste"),"Mensajes distinguen diseño recién obtenido y ya canjeado")
	ui.screen = "multiplayer"
	ui.render()
	await settle()
	await capture("06-multijugador-oscuro")
	ui.collection.clear()
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000121"}
	check(ui.collection.available_covers() == Rules.FREE_COVERS and ui.collection.decks.is_empty() and ui.collection.pending_deck_save.is_empty(),"Cambiar cuenta elimina diseños adquiridos y guardados pendientes")
	print(JSON.stringify({"deck_designs_v120":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
