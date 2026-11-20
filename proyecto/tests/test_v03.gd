extends SceneTree
## Pruebas de presentación: movimientos reales, privacidad y cancelación.
const Game = preload("res://tests/fixtures/legacy_game.gd")
var ui
var checks = 0
var failures = []

func check(value, message):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize(): run.call_deferred()

func settle():
	await process_frame
	await process_frame
	await process_frame

func wait_motion():
	var deadline = Time.get_ticks_msec() + 10000
	while (ui.presenting or ui.fx.busy) and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.presenting and not ui.fx.busy, "La presentación termina y devuelve el control")
	await settle()

func find_button(node, caption):
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found = find_button(child, caption)
		if found != null: return found
	return null

func surface(z, p, uid = -2):
	for node in ui.targets:
		if node.zone == z and node.card_owner == p and (uid == -2 or node.uid == uid): return node
	return null

func take(p, card_code, destination):
	for z in ui.game.ZONES:
		for uid in ui.game.players[p][z].duplicate():
			if ui.game.code(uid) == card_code:
				ui.game.players[p][z].erase(uid)
				ui.game.players[p][destination].append(uid)
				ui.game.instances[uid].entered = 1
				return uid
	return -1

func snapshot():
	return JSON.stringify([ui.game.players, ui.game.instances, ui.game.domain_uid, ui.game.phase, ui.game.actor, ui.game.rng.state])

func fixture():
	ui.game.new_game(19)
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.turn = 10
	ui.game.phase = "main"
	ui.game.take_visual_events()
	ui.draft.clear()
	ui.render()

func record(label_text):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v03-screenshots=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(arg.trim_prefix("--v03-screenshots=").path_join(label_text + ".png"))

func run():
	var g = Game.new()
	g.new_game(9)
	var packet = g.take_visual_events()
	check(packet.filter(func(e): return e.kind == "move" and e.to == "hand").size() == 12, "La preparación produce doce robos individuales")
	check(packet.filter(func(e): return e.kind == "shuffle").size() == 2, "La preparación baraja ambos mazos")
	check(g.take_visual_events().is_empty(), "Cada evento se consume una sola vez")
	g.mulligan()
	packet = g.take_visual_events()
	check(packet.filter(func(e): return e.kind == "move" and e.to == "deck").size() == 6, "El cambio de mano devuelve las seis cartas al Mazo")
	check(packet.filter(func(e): return e.kind == "move" and e.to == "hand").size() == 5, "El cambio reparte cinco cartas nuevas")
	check(packet.any(func(e): return e.kind == "shuffle"), "El cambio contiene la animación de barajado")

	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	await settle()
	check(ui.screen == "home", "El juego abre en la pantalla de inicio")
	for caption in ["Partida individual", "Configuración", "Volver al acceso", "Salir"]:
		check(find_button(ui, caption) != null, "Botón de invitado: " + caption)
	check(find_button(ui, "Multijugador") == null and not ui.started, "El invitado no accede a multijugador")
	ui.open_cards()
	check(ui.screen == "home" and not ui.started, "El invitado no obtiene una colección ficticia")
	check(ui.asset_texture("logo_color.png", true).get_width() > ui.asset_texture("logo_color.png", true).get_height() * 4, "El logo se muestra sin su amplio margen transparente")
	ui.open_single()
	check(ui.screen == "decks", "Partida individual permite elegir el mazo")
	ui.fx.speed = 0.15
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	check(ui.presenting and ui.drag_payload(ui.game.players[0].hand[0], "hand", 0) == null, "El reparto bloquea acciones nuevas hasta finalizar")
	await wait_motion()
	var moves = ui.fx.trace.filter(func(e): return e.kind == "move" and e.to == "hand")
	check(moves.size() == 12, "El animador presenta las dos manos iniciales completas")
	check(moves.filter(func(e): return e.player == 0 and e.face_visible).size() == 6, "Las seis cartas propias se voltean al llegar")
	check(moves.filter(func(e): return e.player == 1 and not e.face_visible).size() == 6, "Las seis cartas rivales se reparten sin revelar el frente")
	check(ui.visual_count(0, "deck") == 33 and ui.visual_count(0, "hand") == 6, "Los contadores terminan en 33 y seis")
	check(ui.fx.ghosts.is_empty(), "El reparto retira todas las copias visuales")
	for p in range(2):
		check(surface("deck", p).get_meta("pile_image").texture == ui.asset_texture("dorso.jpg"), "El Mazo usa el dorso original del autor")
	var before_detail = snapshot()
	var own = surface("hand", 0, ui.game.players[0].hand[0])
	var event = InputEventMouseButton.new()
	event.position = own.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	get_root().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_root().push_input(event, true)
	await settle()
	check(ui.modal_open and ui.overlay_shades.back().get_meta("overlay_kind") == "detail", "El doble clic nativo abre el detalle de la carta")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_root().push_input(escape, true)
	await settle()
	check(not ui.modal_open and snapshot() == before_detail, "Esc cierra el detalle sin jugar ni modificar la carta")
	ui.open_card_detail(ui.game.players[1].hand[0])
	check(not ui.modal_open, "No se puede ampliar la Mano oculta del rival")
	check(not ui.targets.any(func(n): return n.zone == "hand" and n.card_owner == 1), "La Mano rival no contiene superficies con frentes de cartas")
	ui.show_log()
	check(ui.overlay_shades.back().get_meta("overlay_kind") == "log", "El registro compacto puede ampliarse")
	ui.close_overlay(ui.overlay_shades.back())

	fixture()
	var attacker = take(0, "0104", "defense")
	var defender = take(1, "0111", "defense")
	ui.render()
	await settle()
	check(ui.perform(ui.game.declare_attack.bind([attacker])), "Declarar ataque inicia su presentación")
	var committed_attack = snapshot()
	ui.fx.speed = 1.0
	await create_timer(0.13).timeout
	await record("07-ataque")
	await wait_motion()
	check(ui.fx.trace.any(func(e): return e.kind == "attack"), "El ataque tiene impulso visual además del cambio de zona")
	check(snapshot() == committed_attack, "La animación del ataque no altera el motor ni su aleatoriedad")
	check(ui.perform(ui.game.assign_block.bind(attacker, defender)), "Asignar bloqueo inicia su presentación")
	await create_timer(0.12).timeout
	await record("08-bloqueo")
	await wait_motion()
	check(ui.fx.trace.any(func(e): return e.kind == "block"), "El bloqueo anima las dos cartas involucradas")
	check(ui.game.blocks.get(attacker) == defender and ui.game.force(defender) == 4, "El bloqueo conserva la regla confirmada de Azul")
	ui.fx.speed = 0.15
	ui.perform(ui.game.draw.bind(1, 1))
	await wait_motion()
	check(ui.fx.trace.size() == 1 and not ui.fx.trace[0].face_visible, "Un robo rival ordinario permanece boca abajo durante todo el recorrido")
	var life = ui.game.players[1].deck.size()
	var grave = ui.game.players[1].graveyard.size()
	ui.fx.speed = 1.0
	ui.perform(ui.game.mill.bind(1, 3, "Prueba visual", attacker))
	await create_timer(0.47).timeout
	await record("09-dano")
	await wait_motion()
	check(ui.fx.trace.filter(func(e): return e.kind == "move" and e.from == "deck" and e.to == "graveyard").size() == 3, "El daño anima cada carta del Mazo al Cementerio")
	check(ui.game.players[1].deck.size() == life - 3 and ui.game.players[1].graveyard.size() == grave + 3, "El daño animado conserva los contadores finales")
	ui.perform(ui.game.leave.bind(defender, "graveyard"))
	await wait_motion()
	check(ui.fx.trace.any(func(e): return e.kind == "move" and e.from == "defense" and e.to == "graveyard"), "Un Aliado descartado viaja desde su zona al Cementerio")
	ui.perform(ui.game.leave.bind(attacker, "deck"))
	await create_timer(0.55).timeout
	await record("10-barajado")
	await wait_motion()
	check(ui.fx.trace.any(func(e): return e.kind == "shuffle"), "Barajar una carta mueve visualmente el Mazo")
	check(attacker in ui.game.players[0].deck, "Barajar visualmente conserva la carta dentro del Mazo")
	check(ui.game.invariant_errors().is_empty(), "Todas las presentaciones conservan las 80 cartas")

	ui.fx.speed = 0.15
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	ui.go_home()
	await create_timer(0.2).timeout
	check(ui.screen == "home" and not ui.presenting and not ui.fx.busy, "Volver al inicio cancela una presentación pendiente")
	check(ui.fx.ghosts.is_empty(), "Cancelar no deja cartas flotantes ni un bloqueo de entrada")
	var preserved = snapshot()
	ui.open_single()
	check(ui.screen == "table" and snapshot() == preserved, "Volver a Partida individual conserva la partida abierta")
	ui.start_match(1)
	ui.automation_pause = true
	await wait_motion()
	check(ui.human == 1 and ui.fx.trace.filter(func(e): return e.kind == "move" and e.to == "hand" and e.player == 0 and e.face_visible).is_empty(), "La privacidad también funciona al elegir Girabl")
	check(ui.game.invariant_errors().is_empty(), "Una nueva partida queda íntegra después de cancelar otra")
	print(JSON.stringify({"v03_checks":checks, "failures":failures}))
	ui.sound.shutdown()
	await create_timer(0.10).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
