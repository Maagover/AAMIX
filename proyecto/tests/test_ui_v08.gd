extends "res://tests/test_v05.gd"
const CurrentGame = preload("res://game.gd")

func has_label(node, caption):
	if node is Label and node.text == caption: return true
	for child in node.get_children():
		if has_label(child,caption): return true
	return false

func prepare(a = 0, b = 2):
	ui.fx.cancel()
	ui.presentation_generation += 1
	ui.presenting = false
	ui.game = CurrentGame.new()
	ui.game.new_game(81,[ui.game.decklists[a],ui.game.decklists[b]])
	ui.human = 0
	ui.computer = 1
	ui.started = true
	ui.screen = "table"
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.turn = 10
	ui.game.phase = "main"
	ui.game.manual_payment = [false,false]
	ui.game.take_visual_events()
	ui.draft.clear()
	ui.render()
	await settle()

func screenshot08(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v08-screenshots=") and DisplayServer.get_name() != "headless":
			var folder = arg.trim_prefix("--v08-screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(folder.path_join(name+".png"))

func run():
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	ui.animations_enabled = false
	ui.automation_pause = true
	await settle()
	ui.show_start()
	await settle()
	check(has_label(ui,"Elige tu mazo"), "Título solicitado en la selección")
	for name in ["Mazo Kajido","Mazo Papito","Mazo Flaan"]:
		var b = find_button(ui,name)
		check(b != null and b.get_global_rect().end.x <= get_root().get_visible_rect().end.x, "Opción visible: " + name)
	await screenshot08("01-elige-tu-mazo")
	ui.deck_rng.seed = 923
	var rivals = {}
	for i in range(15):
		var index = i % 3
		ui.start_match(index)
		await settle()
		check(ui.game.players[ui.human].deck_id == ui.game.decklists[index].id, "Elección humana independiente del asiento %d" % index)
		check(ui.game.players[ui.computer].deck_id in ["kajido","papito","flaan"], "Rival de uno de los tres mazos")
		rivals[ui.game.players[ui.computer].deck_id] = true
		check(ui.game.invariant_errors().is_empty() and ui.game.manual_payment[ui.human] and not ui.game.manual_payment[ui.computer], "80 cartas y pagos del humano correctos")
	check(rivals.size() == 3, "El sorteo alcanza los tres mazos, sin excluir espejos")

	await prepare()
	resources(7)
	var guitar = take(0,"0134","graveyard")
	ui.render()
	await settle()
	check(ui.drag_payload(guitar,"graveyard",0) != null, "Guitarramala tiene arrastre desde Cementerio")
	ui.game.manual_payment = [true,false]
	ui.render()
	await settle()
	await drag(surface("graveyard",0),surface("defense",0,-1))
	check(ui.game.payment_request.get("uid") == guitar and guitar in ui.game.players[0].graveyard, "Arrastre de Guitarramala comienza pago sin moverlo aún")
	for i in range(7): await drag(surface("resources",0),surface("paid",0))
	check(guitar in ui.game.players[0].defense and ui.game.players[0].paid.size() == 7, "Pago de siete Recursos por arrastre juega desde Cementerio")
	check(ui.game.invariant_errors().is_empty(), "80 cartas durante jugada desde Cementerio")
	ui.game.leave(guitar,"graveyard")
	resources(7)
	ui.render()
	await settle()
	ui.inspect_zone(0,"graveyard")
	ui.open_card_detail(guitar)
	await settle()
	var play = find_button(ui,"Jugar desde Cementerio · Coste 7")
	check(play != null, "El detalle permite jugar Guitarramala cuando no está arriba del Cementerio")
	await click(play)
	check(not ui.modal_open and ui.game.payment_request.get("uid") == guitar, "Jugar desde detalle cierra ventanas y deja preparar pago")
	ui.game.cancel_payment()

	await prepare()
	var luchador = take(0,"0111","defense")
	var cake = take(0,"0123","hand")
	resources(2)
	ui.game.request_play(cake,luchador)
	ui.game.take_visual_events()
	ui.render()
	await settle()
	check(ui.drag_payload(cake,"object",0) != null, "Pastelito equipado admite arrastre de habilidad")
	await drag(surface("object",0,cake),surface("deck",0))
	check(ui.game.pending.kind == "search_hand" and ui.game.pending.title.begins_with("Pastelito"), "Arrastrar Pastelito al Mazo activa su búsqueda")
	ui.skip_choice()
	await settle()
	check(not ui.game.can_activate(cake), "Pastelito muestra agotamiento de su habilidad tras la elección")

	await prepare(2,0)
	var serandi = take(0,"0130","defense")
	var incoming = take(1,"0104","hand")
	ui.game.actor = 1
	ui.game.active = 1
	while ui.game.players[1].resources.size() < 2: take(1,"0100","resources")
	ui.game.request_play(incoming)
	ui.game.take_visual_events()
	ui.render()
	await settle()
	check(ui.modal_open and has_label(ui,"Tu rival juega Javieriv"), "Serandimini muestra la carta anunciada públicamente")
	var counter = find_button(ui,"Anular con Serandimini")
	check(counter != null and counter.disabled, "Anular requiere elegir primero la Serandimini")
	await screenshot08("02-serandimini")
	await click(surface("choice",0,serandi))
	check(surface("choice",0,serandi).has_meta("indicator_role") and surface("choice",0,serandi).get_meta("indicator_role") == "selected", "Serandimini elegida queda resaltada")
	await click(find_button(ui,"Anular con Serandimini"))
	check(incoming in ui.game.players[1].graveyard and serandi in ui.game.players[0].deck and not ui.modal_open, "Confirmación nativa anula y devuelve el control al rival")
	check(ui.game.invariant_errors().is_empty(), "80 cartas conservadas después de anulación por interfaz")

	ui.go_home()
	ui.open_account()
	await settle()
	check(ui.account.configured and find_button(ui,"Enviar código") != null and find_button(ui,"Enviar código").disabled == not ui.account.registration_ready, "Servicio conectado; envío habilitado sólo cuando están listos los correos")
	await screenshot08("03-mi-cuenta")
	print(JSON.stringify({"v08_ui_checks":checks,"failures":failures}))
	await create_timer(0.4).timeout
	ui.sound.shutdown()
	await create_timer(.1).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
