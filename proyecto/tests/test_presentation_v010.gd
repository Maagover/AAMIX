extends SceneTree
var ui
var checks = 0
var failures = []
var starts = []
var finishes = []
var screenshots_path = ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			var candidate = arg.trim_prefix("--screenshots=")
			if not candidate.is_absolute_path():
				printerr("--screenshots requires an absolute output directory.")
				quit(1)
				return
			screenshots_path = candidate
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func find_text(node, text):
	if (node is Label or node is Button) and node.text == text: return node
	for child in node.get_children():
		var found = find_text(child, text)
		if found != null: return found
	return null

func settle():
	for i in range(6): await process_frame

func shot(name):
	# This distributable test writes images only when explicitly requested.
	if screenshots_path.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots_path)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(screenshots_path.path_join(name + ".png"))

func run():
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.match_started.connect(func(id): starts.append(id))
	ui.match_finished.connect(func(victory): finishes.append(victory))
	await settle()
	check(find_text(ui, "Salir") == null, "No Exit button on account screen")
	ui.exit_game()
	check(ui.quit_dialog.visible and not ui.quitting, "Exit requires confirmation")
	check(ui.quit_dialog.dialog_text == "¿Seguro que quieres salir?", "Exact exit question")
	check(ui.quit_dialog.get_ok_button().text == "Confirmar" and ui.quit_dialog.get_cancel_button().text == "Cancelar", "Explicit confirm and cancel")
	ui.quit_dialog.hide()
	ui._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(ui.quit_dialog.visible and not ui.quitting, "OS close also requires confirmation")
	await shot("v010-salir")
	ui.quit_dialog.hide()
	ui.play_guest()
	await settle()
	check(find_text(ui, "Salir") != null, "Home contains Exit")
	var fans = []
	for node in ui.find_children("*", "Control", true, false):
		if node.get_script() == load("res://home_cards.gd"): fans.append(node)
	check(fans.size() == 1, "Home decorative animation created")
	var fan = fans[0]
	check(fan.floating_cards.size() == 3 and fan.closed_pack.get_meta("decorative_pack", false), "Two printed cards and the sealed pack float behind logo")
	fan.clock = 0
	fan.update_cards()
	var position = fan.floating_cards[0].position
	var logo_position = fan.logo.position
	var rotation = fan.featured.rotation
	var logo_rotation = fan.logo.rotation
	fan.clock = 1
	fan.update_cards()
	check(fan.floating_cards[0].position != position, "Printed cards float continuously")
	check(fan.logo.position != logo_position, "Logo floats gently with the cards")
	check(fan.logo.position.distance_to(logo_position) < fan.featured.position.distance_to(position), "Logo displacement is smaller than card displacement")
	fan.clock = 7
	fan.update_cards()
	check(fan.featured.texture == fan.featured_texture and fan.featured.scale == Vector2.ONE, "Printed front stays visible without rotation")
	fan.clock = 14
	fan.update_cards()
	check(fan.featured.texture == fan.featured_texture and fan.logo.texture == fan.logo_texture, "Floating logo remains over printed fronts")
	check(fan.featured.rotation == rotation and fan.logo.rotation == logo_rotation, "Floating artwork never spins")
	await shot("v010-inicio")
	ui.show_start()
	check(find_text(ui, "Salir") == null, "No Exit button in deck picker")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(starts.size() == 1 and starts[0] == "kajido", "Match start signal once with deck id")
	check(find_text(ui, "Salir") == null, "No Exit button at table")
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.schedule_presentation({})
	await settle()
	check(ui.announced_turn == 1 and is_instance_valid(ui.turn_banner), "First incoming turn is announced")
	check(find_text(ui.turn_banner, "Tu turno" if ui.game.active == ui.human else "Turno rival") != null, "Turn message uses active player")
	var first_banner = ui.turn_banner
	ui.announce_turn_if_needed()
	check(ui.turn_banner == first_banner, "The same turn is never announced twice")
	ui.clear_turn_banner()
	ui.game.phase = "main"
	ui.game.draw(ui.game.active, 9 - ui.game.players[ui.game.active].hand.size())
	ui.game.take_visual_events()
	ui.perform(ui.game.finish_turn)
	await settle()
	check(ui.game.pending.kind == "end_discard" and ui.game.phase == "closing", "Large ending hand requires discard")
	check(ui.announced_turn == 1 and not is_instance_valid(ui.turn_banner), "Turn toast waits until ending discard")
	var options = ui.game.pending.options.slice(0, int(ui.game.pending.min))
	ui.perform(ui.game.choose.bind(options))
	await settle()
	check(ui.announced_turn == 2 and is_instance_valid(ui.turn_banner), "Next turn announced after required discard")
	check(ui.game.invariant_errors().is_empty(), "Presentation preserves game invariants")
	ui.game.phase = "events"
	ui.game.actor = ui.human
	ui.render()
	check(find_text(ui, "Pasar daño") != null and find_text(ui, "Pasar prioridad") == null, "Damage pass renamed without changing action")
	ui.game.lose(ui.computer)
	ui.render()
	check(find_text(ui, "Victoria") != null, "Victory title")
	check(find_text(ui, "Revancha") != null and find_text(ui, "Volver al inicio") != null, "Result buttons")
	check(find_text(ui, "Ver la mesa final") == null, "No view-table button after result")
	ui.render()
	check(finishes.size() == 1 and finishes[0], "Finished signal emitted once")
	await shot("v010-victoria")
	ui.game.winner = ui.computer
	ui.render()
	check(find_text(ui, "Derrota") != null, "Defeat title")
	check(finishes.size() == 1, "Rendering another result cannot duplicate a match receipt")
	await shot("v010-derrota")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(starts.size() == 2 and not ui.winner_announced and ui.announced_turn == 0, "A new match resets presentation lifecycle")
	ui.game.lose(ui.human)
	ui.render()
	check(finishes.size() == 2 and not finishes[1], "A new completed match receives its own result signal")
	ui.guest = false
	ui.account.user = {"id":"presentation-test", "user_metadata":{"display_name":"Prueba"}}
	ui.account.access_token = "fixture"
	ui.account.expires_at = Time.get_unix_time_from_system() + 3600
	ui.collection.loaded = true
	ui.collection.owner_id = "presentation-test"
	ui.collection.gift = null
	ui.screen = "gift"
	ui.render()
	check(find_text(ui, "Tu regalo inicial") != null and find_text(ui, "Salir") == null, "Centered gift title without Exit")
	await shot("v010-regalo")
	ui.collection.gift = {"deck_id":"kajido"}
	ui.collection.cards = {"0100":18}
	ui.screen = "cards"
	ui.render()
	check(find_text(ui, "18 cartas · 1 de 41 cartas obtenidas") != null, "Collection counts say cards")
	check(find_text(ui, "Salir") == null, "No Exit button in collection")
	for name in ["regalo", "regalo_recibido", "victoria", "derrota", "turno", "sobre_abrir", "sobre_carta"]:
		check(ui.sound.streams.has(name) and ui.sound.streams[name] != null, "Synthesized cue loads: " + name)
	print(JSON.stringify({"presentation_v010_checks":checks,"failures":failures}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
