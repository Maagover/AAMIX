extends SceneTree
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

func capture(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-screenshots=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(arg.trim_prefix("--ui-screenshots=").path_join(name + ".png"))

func take(p, code, destination):
	for z in ui.game.ZONES:
		for uid in ui.game.players[p][z].duplicate():
			if ui.game.code(uid) == code:
				ui.game.players[p][z].erase(uid)
				ui.game.players[p][destination].append(uid)
				ui.game.instances[uid].entered = 1
				return uid
	return -1

func surface(z, p, uid = -2):
	for node in ui.targets:
		if node.zone == z and node.card_owner == p and (uid == -2 or node.uid == uid): return node
	return null

func move_mouse(position, relative, mask = 0):
	var event = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = mask
	get_root().push_input(event, true)

func mouse_button(position, pressed):
	var event = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_root().push_input(event, true)

func drag(source, destination):
	if source == null or destination == null:
		check(false, "Falta una superficie para arrastrar")
		return
	var a = source.get_global_rect().get_center()
	var b = destination.get_global_rect().get_center()
	move_mouse(a, Vector2.ZERO)
	await process_frame
	mouse_button(a, true)
	await process_frame
	var previous = a
	for i in range(1, 7):
		var position = a.lerp(b, float(i) / 6.0)
		move_mouse(position, position - previous, MOUSE_BUTTON_MASK_LEFT)
		previous = position
		await process_frame
	mouse_button(b, false)
	await settle()

func run():
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	await settle()
	check(ui.screen == "home" and not ui.started, "Inicio permite elegir mazo, sin pantalla de pasar computador")
	await capture("01-elegir-mazo")
	ui.animations_enabled = false
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	ui.game.new_game(7)
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.turn = 10
	ui.game.phase = "resource"
	var resource = take(0, "0100", "hand")
	ui.render()
	await settle()
	await drag(surface("hand", 0, resource), surface("resources", 0))
	check(ui.game.phase == "main" and ui.game.players[0].resources.size() == 2, "Arrastre real Mano a Recursos baja uno y cierra oportunidad")
	while ui.game.players[0].resources.size() < 4: take(0, "0100", "resources")
	var ally = take(0, "0108", "hand")
	take(1, "0104", "defense") # Keep this scenario about assigning available blockers.
	ui.render()
	await settle()
	await drag(surface("hand", 0, ally), surface("paid", 0))
	check(ally in ui.game.players[0].hand and ui.game.payment_request.is_empty(), "Destino inválido deja la carta en Mano")
	await drag(surface("hand", 0, ally), surface("defense", 0, -1))
	check(not ui.game.payment_request.is_empty(), "Arrastre real de Aliado a Defensa solicita el pago")
	await capture("02-pago-pendiente")
	await drag(surface("resources", 0), surface("paid", 0))
	check(ally in ui.game.players[0].defense, "Arrastre real de Recurso a Pagadas juega el Aliado")
	check(ui.game.pending.get("kind") == "reorder", "La habilidad de entrada abre la elección correcta")
	ui.skip_choice()
	await settle()
	var spent = ui.game.players[0].paid.size()
	await drag(surface("paid", 0), surface("resources", 0))
	check(ui.game.players[0].paid.size() == spent, "No se puede arrastrar de vuelta un Recurso gastado")
	var obj = take(0, "0124", "hand")
	ui.render()
	await settle()
	await drag(surface("hand", 0, obj), surface("defense", 0, ally))
	check(ui.game.payment_request.get("cost") == 2, "Arrastre de Objeto sobre portador solicita coste dos")
	await drag(surface("resources", 0), surface("paid", 0))
	await drag(surface("resources", 0), surface("paid", 0))
	check(ui.game.instances[ally].object == obj and ui.game.force(ally) == 5, "Arrastre completo equipa Muñeco de Miku")
	ui.show_detail(ally)
	await capture("03-mesa")
	while ui.game.players[0].resources.size() < 4: take(0, "0100", "resources")
	var destroy = take(0, "0133", "hand")
	ui.render()
	await settle()
	await drag(surface("hand", 0, destroy), surface("object", 0, obj))
	for i in range(4): await drag(surface("resources", 0), surface("paid", 0))
	check(obj in ui.game.players[0].graveyard and ally in ui.game.field(0) and ui.game.force(ally) == 1, "Soltar Muerte de Akira sobre el Objeto destruye solo el Objeto, no su portador")
	ui.game.instances[ally].entered = 1
	await drag(surface("defense", 0, ally), surface("attack", 0, -1))
	check(ally in ui.draft and ui.game.phase == "main", "Arrastrar a Ataque prepara sin declarar todavía")
	await drag(surface("draft_attack", 0, ally), surface("defense", 0, -1))
	check(ui.draft.is_empty(), "Se puede corregir el grupo antes de declarar ataque")
	await drag(surface("defense", 0, ally), surface("attack", 0, -1))
	ui.declare_attack()
	check(ui.game.actor == 1 and ui.game.phase == "blocks", "Declarar ataque cede la defensa al computador")
	check(ui.drag_payload(ui.game.players[0].hand[0], "hand", 0) == null, "Turno del computador bloquea jugadas del humano")
	var secret = ui.game.players[1].hand[0]
	ui.show_detail(secret)
	check(ui.focus_uid != secret, "La vista ampliada no revela la Mano rival")
	check(not ui.targets.any(func(n): return n.zone == "hand" and n.card_owner == 1), "La Mano del computador no crea cartas visibles")
	ui.game.phase = "main"
	ui.game.active = 1
	ui.game.actor = 1
	var enemy = take(1, "0104", "defense")
	var blue = take(0, "0111", "defense")
	ui.game.declare_attack([enemy])
	ui.render()
	await settle()
	await drag(surface("defense", 0, blue), surface("attack", 1, enemy))
	check(ui.game.blocks.get(enemy, -1) == blue and ui.game.force(blue) == 4, "Arrastre real de defensor asigna bloqueo con +2 de Azul")
	await capture("04-bloqueo")
	await drag(surface("defense", 0, blue), surface("defense", 0, -1))
	check(ui.game.blocks.is_empty() and ui.game.force(blue) == 2, "Devolver defensor a su línea quita el bloqueo y el bono")
	ui.game.phase = "main"
	ui.game.active = 1
	ui.game.actor = 1
	ui.game.players[1].attack.erase(enemy)
	ui.game.players[1].defense.append(enemy)
	var second = take(1, "0108", "defense")
	ui.game.declare_attack([enemy, second])
	ui.render()
	await settle()
	await drag(surface("defense", 0, blue), surface("attack", 1, enemy))
	await drag(surface("defense", 0, blue), surface("attack", 1, second))
	check(ui.game.blocks.size() == 1 and ui.game.blocks.get(second, -1) == blue, "Reasignar por arrastre mantiene un solo bloqueo por defensor")
	ui.game.phase = "after_combat"
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.combat_roles.clear()
	ui.render()
	await settle()
	await drag(surface("deck", 0), surface("hand", 0, -1))
	check(ui.game.active == 1 and ui.game.phase == "resource", "Arrastrar Mazo a Mano roba y cede el turno al computador")

	ui.game.new_game(7)
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.phase = "main"
	while ui.game.players[0].resources.size() < 7: take(0, "0100", "resources")
	var domain = take(0, "0122", "hand")
	ui.render()
	await settle()
	await drag(surface("hand", 0, domain), surface("domain", -1))
	for i in range(4): await drag(surface("resources", 0), surface("paid", 0))
	check(ui.game.domain_uid == domain, "Arrastre a Dominio y pago manual dejan un Dominio global")
	var school = take(0, "0131", "hand")
	ui.render()
	await settle()
	await drag(surface("hand", 0, school), surface("domain", -1))
	for i in range(3): await drag(surface("resources", 0), surface("paid", 0))
	check(ui.game.domain_uid == school and domain in ui.game.players[0].graveyard, "Arrastrar otro Dominio descarta el anterior al dueño")
	var target = take(1, "0108", "defense")
	var event = take(0, "0116", "hand")
	take(0, "0100", "resources")
	ui.render()
	await settle()
	await drag(surface("hand", 0, event), surface("defense", 1, target))
	await drag(surface("resources", 0), surface("paid", 0))
	check(target in ui.game.players[1].deck and event in ui.game.players[0].graveyard, "Evento arrastrado sobre rival resuelve su objetivo después de pagar")
	ui.game.players[0].deck.append_array(ui.game.players[0].hand)
	ui.game.players[0].hand.clear()
	ui.game.draw(0, 10)
	ui.finish_turn()
	await settle()
	var excess = int(ui.game.pending.max)
	for i in range(excess): await drag(surface("hand", 0, ui.game.players[0].hand[0]), surface("graveyard", 0))
	check(ui.game.players[0].hand.size() == 8 and ui.game.active == 1, "Arrastrar descartes al Cementerio completa el cierre antes del rival")
	ui.start_match(1)
	ui.automation_pause = true
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 1
	ui.game.actor = 1
	ui.game.phase = "after_combat"
	var cat = take(1, "01b", "defense")
	ui.render()
	await settle()
	await drag(surface("defense", 1, cat), surface("deck", 1))
	check(ui.game.pending.get("kind") == "search_hand" and ui.game.instances[cat].used == ui.game.turn, "Arrastrar Bigotes al Mazo activa su búsqueda una sola vez")
	ui.skip_choice()
	check(not ui.game.can_activate(cat), "Bigotes no puede volver a usarse en el turno")
	ui.show_help()
	await capture("05-ayuda")
	ui.render()
	check(ui.game.invariant_errors().is_empty(), "Las interacciones de interfaz conservan las 80 cartas")
	ui.start_match(1)
	ui.game.new_game(8)
	ui.render()
	for i in range(12):
		if ui.game.keeps[0]: break
		await create_timer(0.3).timeout
	check(ui.game.keeps[0] and ui.game.actor == 1, "El computador revisa su mano automáticamente sin intervención del humano")
	check(ui.human == 1 and ui.computer == 0 and ui.game.manual_payment == [false, true], "Se puede jugar con Girabl contra Maagover")
	check(not ui.modal_open, "No aparece una pantalla para pasar el computador")
	print(JSON.stringify({"ui_checks":checks, "failures":failures}))
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
