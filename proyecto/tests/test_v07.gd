extends "res://tests/test_v05.gd"

func no_events(p):
	for uid in ui.game.players[p].hand.duplicate():
		if ui.game.definition(uid).clase == "Evento":
			ui.game.players[p].hand.erase(uid)
			ui.game.players[p].deck.append(uid)

func fresh_combat(p):
	ui.screen = "table"
	fresh_ui()
	ui.game.active = p
	ui.game.actor = p
	for owner in range(2):
		for uid in ui.game.players[owner].defense.duplicate(): ui.game.leave(uid, "graveyard")
		no_events(owner)
	ui.game.take_visual_events()

func key_escape():
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	get_root().push_input(event, true)
	await settle()

func shot07(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v07-screenshots=") and DisplayServer.get_name() != "headless":
			var folder = arg.trim_prefix("--v07-screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(folder.path_join(name + ".png"))

func run():
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	ui.animations_enabled = false
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	for attacker_owner in range(2):
		fresh_combat(attacker_owner)
		var defender = 1 - attacker_owner
		var ally = take(attacker_owner, "0108" if attacker_owner == 0 else "0127", "defense")
		var before = ui.game.players[defender].deck.size()
		var damage = ui.game.force(ally)
		ui.game.declare_attack([ally])
		check(ui.game.phase == "after_combat" and ui.game.actor == attacker_owner, "Sin defensores ni Eventos se resuelve el daño para el jugador %d" % defender)
		check(ui.game.players[defender].deck.size() == before - damage and ui.game.blocks.is_empty(), "El daño automático usa la fuerza del atacante, sin bloqueos ficticios")
		check(ui.game.invariant_errors().is_empty(), "La defensa automática conserva las 80 cartas")
		ui.render()
		await settle()
		check(find_button(ui, "Confirmar bloqueos") == null, "Sin Aliados en Defensa no aparece Confirmar bloqueos")

	fresh_combat(0)
	var first = take(0, "0108", "defense")
	var second = take(0, "0104", "defense")
	var before_multi = ui.game.players[1].deck.size()
	var total = ui.game.force(first) + ui.game.force(second)
	ui.game.take_visual_events()
	ui.game.declare_attack([first, second])
	var visual = ui.game.take_visual_events()
	check(ui.game.players[1].deck.size() == before_multi - total, "El daño automático cuenta todos los atacantes")
	check(visual.filter(func(e): return e.kind == "damage").size() == 2 and visual[0].kind == "move", "Se conservan los movimientos y un evento de daño separado por atacante")

	fresh_combat(0)
	var expensive = take(0, "0109", "defense")
	var conflict = take(1, "0116", "hand")
	ui.game.declare_attack([expensive])
	check(ui.game.phase == "after_combat" and conflict in ui.game.players[1].hand, "Un Evento sin objetivo válido no detiene el daño automático")

	fresh_combat(0)
	var attack = take(0, "0108", "defense")
	var unaffordable = take(1, "0120", "hand")
	ui.game.declare_attack([attack])
	check(ui.game.phase == "after_combat" and unaffordable in ui.game.players[1].hand, "Un Evento sin Recursos suficientes no exige una confirmación vacía")

	fresh_combat(0)
	attack = take(0, "0108", "defense")
	conflict = take(1, "0116", "hand")
	var before_event = ui.game.players[1].deck.size()
	ui.game.declare_attack([attack])
	check(ui.game.phase == "events" and ui.game.actor == 1 and not ui.game.event_access, "Sin Aliados se conserva la respuesta del defensor con un Evento jugable")
	check(ui.game.players[1].deck.size() == before_event, "No se aplica daño antes de la oportunidad de responder")
	ui.game.request_play(conflict, attack)
	check(ui.game.event_access and attack in ui.game.players[0].deck, "Responder con un Evento habilita los Eventos del atacante y resuelve el objetivo")
	ui.game.pass_priority()
	ui.game.pass_priority()
	check(ui.game.phase == "after_combat" and ui.game.players[1].deck.size() == before_event, "El atacante retirado por el Evento no causa daño")

	fresh_combat(0)
	attack = take(0, "0108", "defense")
	var blocker = take(1, "0104", "defense")
	ui.game.declare_attack([attack])
	check(ui.game.phase == "blocks" and ui.game.actor == 1, "Con un defensor disponible se conserva la asignación manual")
	check(ui.game.assign_block(attack, blocker) and ui.game.blocks.get(attack) == blocker, "El bloqueo manual sigue disponible")
	ui.game.finish_blocks()
	check(ui.game.phase == "events" and ui.game.event_access, "Confirmar un bloqueo conserva la ventana de Eventos de ambos jugadores")

	fresh_combat(0)
	attack = take(0, "0108", "defense")
	while ui.game.players[1].deck.size() > 1:
		ui.game.players[1].graveyard.append(ui.game.players[1].deck.pop_back())
	ui.game.declare_attack([attack])
	check(ui.game.winner == 0 and ui.game.phase == "finished", "El daño automático detecta la derrota al vaciar el Mazo")
	check(ui.game.invariant_errors().is_empty(), "El cierre automático no pierde cartas")

	fresh_combat(1)
	attack = take(1, "0104", "defense") # Cost two: a valid target for Conflicto.
	take(0, "0116", "hand")
	ui.game.declare_attack([attack])
	ui.render()
	await settle()
	check(ui.game.actor == ui.human and find_button(ui, "Pasar daño") != null and find_button(ui, "Confirmar bloqueos") == null, "El humano sin defensores puede responder con un Evento, sin confirmar bloqueos")

	fresh_combat(1)
	attack = take(1, "0127", "defense")
	ui.game.take_visual_events()
	ui.render()
	await settle()
	ui.animations_enabled = true
	ui.fx.speed = 0.2
	ui.perform(ui.game.declare_attack.bind([attack]))
	var resolved = JSON.stringify([ui.game.players, ui.game.instances, ui.game.phase])
	var deadline = Time.get_ticks_msec() + 10000
	await settle()
	while (ui.presenting or ui.fx.busy) and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.presenting and not ui.fx.busy and ui.fx.trace.any(func(e): return e.kind == "attack") and ui.fx.trace.any(func(e): return e.kind == "damage"), "Ataque y daño automático completan sus animaciones sin pedir intervención")
	check(ui.game.phase == "after_combat" and JSON.stringify([ui.game.players, ui.game.instances, ui.game.phase]) == resolved, "La presentación no aplica el daño automático dos veces")
	ui.animations_enabled = false

	ui.go_home()
	await settle()
	check(find_button(ui, "Sonido") == null and find_button(ui, "Salir") != null, "El inicio muestra Salir en lugar del acceso directo a Sonido")
	await shot07("01-inicio")
	await click(find_button(ui, "Configuración"))
	check(ui.modal_open and ui.overlay_shades.back().get_meta("overlay_kind") == "configuration" and find_button(ui.overlay_shades.back(), "Sonido") != null, "Configuración contiene el botón Sonido")
	await shot07("19-configuracion")
	await click(find_button(ui.overlay_shades.back(), "Sonido"))
	check(ui.overlay_shades.size() == 2 and ui.overlay_shades.back().get_meta("overlay_kind") == "audio", "Sonido se abre dentro de Configuración")
	await shot07("20-sonido")
	await key_escape()
	check(ui.modal_open and ui.overlay_shades.size() == 1 and ui.overlay_shades.back().get_meta("overlay_kind") == "configuration", "Esc en Sonido vuelve a Configuración")
	await key_escape()
	check(not ui.modal_open, "Esc en Configuración vuelve al juego")
	fresh_combat(0)
	ui.render()
	await settle()
	check(find_button(ui, "Sonido") == null and find_button(ui, "Salir") == null and find_button(ui, "Configuración") != null, "La cabecera conserva Configuración y reserva Salir para Inicio")
	var state = JSON.stringify([ui.game.players, ui.game.instances, ui.game.rng.state])
	await click(find_button(ui, "Configuración"))
	await key_escape()
	check(JSON.stringify([ui.game.players, ui.game.instances, ui.game.rng.state]) == state, "La configuración conserva el estado de la partida")
	print(JSON.stringify({"v07_checks":checks, "failures":failures}))
	ui.sound.shutdown()
	await create_timer(0.1).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
