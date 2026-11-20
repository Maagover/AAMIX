extends SceneTree
## Navigation, fixed challenge opponents and supplied artwork. In-memory account only.
var ui
var checks = 0
var failures = []
var screenshots = ""
var starts = []
var finishes = []

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok:
		failures.append(caption)
		printerr("FAIL: ", caption)

func text_node(node, caption):
	if (node is Label or node is Button) and node.text == caption: return node
	for child in node.get_children():
		var found = text_node(child, caption)
		if found != null: return found
	return null

func meta_node(node, key, value = null):
	if node.has_meta(key) and (value == null or node.get_meta(key) == value): return node
	for child in node.get_children():
		var found = meta_node(child, key, value)
		if found != null: return found
	return null

func settle():
	for i in range(8): await process_frame

func shot(name):
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshots.path_join(name + ".png"))

func popup_count():
	return ui.sound.recent.filter(func(e): return e.name == "popup").size()

func stage_fixture(all_unlocked = false):
	var result = []
	for d in ui.CHALLENGES:
		var state = d.duplicate(true)
		state.merge({"unlocked":all_unlocked or d.stage == 1,"completed":false,"reward_claimed":false},true)
		result.append(state)
	return result

func within_view(node):
	var rect = node.get_global_rect()
	return rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= root.get_visible_rect().end.x+1 and rect.end.y <= root.get_visible_rect().end.y+1

func run():
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause = true
	ui.animations_enabled = false
	ui.rewards.set_process(false)
	ui.sound.muted = false
	ui.sound.effects_volume = 0.7
	ui.account.user = {"id":"v014-ui-fixture","email":"fixture@example.invalid","user_metadata":{"display_name":"Jugador de prueba"}}
	ui.account.access_token = "memory-only-fixture"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.collection.owner_id = "v014-ui-fixture"
	ui.collection.loaded = true
	ui.collection.gift = {"deck_id":"kajido"}
	ui.collection.profile = {"avatar_code":"0108"}
	ui.collection.decks = ui.game.decklists.duplicate(true)
	ui.collection.challenges = stage_fixture()
	for stage in [4,5]: ui.collection.decks.append(ui.challenge_opponent(stage))
	for code in ui.game.catalog: ui.collection.cards[code] = 1
	ui.match_started.connect(func(id, stage): starts.append({"id":id,"stage":stage}))
	ui.match_finished.connect(func(victory): finishes.append(victory))
	ui.screen = "home"
	ui.render()
	await settle()
	var menu = meta_node(ui,"home_main_menu")
	var order = []
	for child in menu.get_children(): order.append(child.text)
	check(order == ["Partida individual","Multijugador","Misiones","Mi Colección"],"Home has exactly the four requested options in order")
	check(text_node(ui,"Mi cuenta") == null and text_node(ui,"Mis Cartas") == null,"Home removes the old account menu button and collection wording")
	check(text_node(ui,"Juega contra el rival") == null,"Home has no obsolete rival note")
	check(text_node(ui,"Sobres · 0") == null,"No packs shortcut remains on home")
	check(text_node(ui,"AAMIX · versión 0.14.0") != null,"Home version is current")
	check(ui.home_background.visible and ui.home_background.texture != null,"Home uses the supplied valley")
	var valley = ui.home_background
	valley.clock = 11.0
	valley.animated = true
	valley.update_zoom()
	var zoom = valley.scale.x
	check(zoom > 1.02 and zoom <= 1.07,"Valley zoom remains subtle")
	valley.clock = 27.99
	valley.update_zoom()
	var end_zoom = valley.scale.x
	valley.clock = 28.01
	valley.update_zoom()
	check(absf(valley.scale.x-end_zoom) < 0.0001,"Valley loop wraps without a jump")
	valley.clock = 12.0
	ui.render()
	await settle()
	check(ui.home_background == valley and valley.clock == 12.0,"Inventory rerender preserves valley node and animation clock")
	check(valley.scale == Vector2.ONE,"Animations-off preference disables valley zoom")
	menu = meta_node(ui,"home_main_menu")
	var identity = meta_node(ui,"home_account")
	check(identity is Button and identity.global_position.x < root.get_visible_rect().size.x*0.25,"Account identity is clickable at upper left")
	check(text_node(identity,"Jugador de prueba") != null,"Identity includes the current account name")
	check(text_node(ui,"Código de regalo").global_position.x > root.get_visible_rect().size.x*0.6 and text_node(ui,"Configuración").global_position.y < 120,"Gift code and settings sit at upper right")
	var fan = null
	for node in ui.find_children("*","Control",true,false):
		if node.get_script() == load("res://home_cards.gd"): fan = node
	check(fan != null and fan.floating_cards.size() == 3,"Home retains two printed cards and sealed pack")
	check(fan.featured.get_script() == load("res://card_image.gd") and fan.floating_cards[1].get_script() == load("res://card_image.gd"),"Both printed home cards share the rounded mask")
	check(fan.closed_pack.material == null and fan.logo.material == null,"Pack and logo remain unmasked artwork")
	check(within_view(menu) and within_view(identity) and within_view(text_node(ui,"Salir")),"Home interactive areas fit the normal viewport")
	await shot("01-inicio")
	identity.pressed.emit()
	await settle()
	check(ui.screen == "account" and text_node(ui,"Elegir foto de perfil") != null,"Clicking identity opens Mi cuenta")
	check(not valley.visible,"Valley is hidden outside home")
	await shot("02-mi-cuenta")
	ui.go_home()
	await settle()
	text_node(ui,"Multijugador").pressed.emit()
	await settle()
	check(text_node(ui,"En desarrollo") != null and ui.screen == "home","Multiplayer opens the requested placeholder")
	ui.close_overlay(ui.overlay_shades.back())
	text_node(ui,"Partida individual").pressed.emit()
	await settle()
	check(ui.screen == "single" and text_node(ui,"Partida Aleatoria") != null and text_node(ui,"Desafío AAMIX") != null,"Individual opens its two-mode submenu")
	check(text_node(ui,"Salir") == null,"Exit button stays on home only")
	await shot("03-partida-individual")
	text_node(ui,"Desafío AAMIX").pressed.emit()
	await settle()
	var stages = meta_node(ui,"challenge_stages")
	check(ui.screen == "challenges" and stages.get_child_count() == 5,"Five challenge stages render")
	var stage_ids = []
	for node in stages.get_children(): stage_ids.append(meta_node(node,"challenge_stage").get_meta("challenge_stage"))
	check(stage_ids == [1,2,3,4,5],"Challenge stages keep their required order")
	check(ui.CHALLENGES.map(func(d):return d.deck_id) == ["papito","flaan","kajido","maago","girabl"],"The five fixed opponents are Papito, Flaan, Kajido, Maagover and Girabl")
	check(ui.CHALLENGES.map(func(d):return d.reward_packs) == [1,1,1,2,3],"Stage rewards display 1,1,1,2,3 packs")
	check(not text_node(stages.get_child(0),"Jugar etapa").disabled and text_node(stages.get_child(1),"Jugar etapa").disabled,"Only the server-unlocked stage is playable")
	check(within_view(stages),"All five stage covers and controls fit the normal viewport")
	await shot("04-desafio-bloqueado")
	ui.choose_challenge(5)
	check(ui.screen == "challenges" and ui.selected_challenge_stage == 0,"Programmatic selection cannot bypass a locked stage")
	ui.choose_challenge(1)
	await settle()
	check(ui.screen == "decks" and ui.selected_challenge_stage == 1,"Unlocked stage opens owned-deck selection")
	var choices = meta_node(ui,"deck_choices")
	check(choices.get_child_count() == 5 and within_view(choices),"All five owned decks fit in the selector")
	for i in range(choices.get_child_count()):
		check(meta_node(choices.get_child(i),"deck_cover").texture != null,"Owned deck uses its supplied cover: "+str(i))
	await shot("05-elegir-mazo-desafio")
	var original_base = JSON.stringify(ui.game.decklists)
	for stage in range(1,6):
		var opponent = ui.challenge_opponent(stage)
		var total = 0
		for entry in opponent.cartas: total += int(entry.cantidad)
		check(opponent.id == ui.CHALLENGES[stage-1].deck_id and total == 40,"Fixed challenge stage uses the correct 40-card deck: "+str(stage))
	var historical = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mazos_legacy.json")).mazos
	check(ui.challenge_opponent(4).cartas == historical[0].cartas,"Maagover opponent exactly preserves its historical list")
	check(ui.challenge_opponent(5).cartas == historical[1].cartas,"Girabl opponent exactly preserves its historical list, including promos")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(ui.game.players[ui.computer].deck_id == "papito" and starts.back().stage == 1,"Challenge start fixes the opponent and emits its stage receipt")
	check(ui.game.players[ui.human].deck_id == ui.collection.decks[0].id,"Challenge player uses the chosen owned deck")
	check(not valley.visible and meta_node(ui,"screen_background","wood") != null,"Matches keep their wooden table")
	check(ui.sound.music_wanted,"Music continues during a match")
	check(text_node(ui,"Salir") == null,"Match retains no exit shortcut")
	var popups = popup_count()
	ui.render()
	ui.render()
	await settle()
	check(popup_count() == popups,"Table refreshes do not replay interface entry audio")
	await shot("06-partida-desafio")
	ui.game.lose(ui.computer)
	ui.render()
	await settle()
	check(meta_node(ui,"result_art","victory") != null and text_node(ui,"Revancha") != null,"Victory uses supplied result art with rematch actions")
	check(finishes == [true],"Victory is reported exactly once")
	ui.render()
	await settle()
	check(finishes == [true],"Result rerender does not duplicate completion")
	await shot("07-victoria")
	var original_player = ui.active_deck_id
	ui.collection.decks.reverse()
	ui.rematch()
	ui.automation_pause = true
	await settle()
	check(ui.game.players[ui.human].deck_id == original_player and ui.game.players[ui.computer].deck_id == "papito","Rematch preserves both decks if the inventory order changes")
	ui.collection.decks.reverse()
	ui.collection.challenges = stage_fixture(true)
	ui.collection.challenges[0].completed = true
	ui.collection.challenges[0].reward_claimed = true
	ui.open_challenges()
	await settle()
	check(text_node(ui,"Completado · premio recibido") != null and text_node(ui,"Volver a jugar") != null,"Server completion state supports replay without another reward promise")
	await shot("08-desafio-progreso")
	ui.choose_challenge(5)
	ui.start_match(1)
	ui.automation_pause = true
	await settle()
	check(ui.game.players[ui.computer].deck_id == "girabl" and starts.back().stage == 5,"Final challenge selects Girabl and stage5")
	ui.game.lose(ui.human)
	ui.render()
	await settle()
	check(meta_node(ui,"result_art","defeat") != null,"Defeat uses the supplied result art")
	await shot("09-derrota")
	ui.open_random()
	await settle()
	check(ui.selected_challenge_stage == 0,"Random navigation clears the selected challenge")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(ui.game.players[ui.computer].deck_id in ["papito","kajido","flaan"] and starts.back().stage == 0,"Random play keeps only the original three NPC decks and emits stage0")
	check(JSON.stringify(ui.game.decklists) == original_base,"Challenge play does not modify the random base pool")
	ui.open_cards()
	await settle()
	check(text_node(ui,"Mis Cartas") == null and text_node(ui,"Mi Colección") != null,"Collection navigation uses the requested name")
	check(meta_node(ui,"collection_grid").get_child_count() == 35 and meta_node(ui,"collection_promotional_row").get_child_count() == 6,"Existing 35+6 card grouping is preserved")
	await shot("10-mi-coleccion")
	ui.select_cards_tab("decks")
	await settle()
	check(meta_node(ui,"deck_cover","girabl") != null and text_node(ui,"Ver lista") != null,"Owned deck list uses supplied cover and retains card-list access")
	await shot("11-mis-mazos")
	ui.collection.gift = null
	ui.screen = "gift"
	ui.render()
	await settle()
	check(meta_node(ui,"deck_cover","papito") != null and meta_node(ui,"deck_cover","kajido") != null,"Starter gift uses the provided base-deck covers")
	await shot("12-regalo-inicial")
	ui.collection.gift = {"deck_id":"kajido"}
	ui.screen = "home"
	ui.render()
	await settle()
	ui.animations_enabled = true
	await create_timer(0.05).timeout
	ui.open_single()
	await process_frame
	check(not ui.interface_motion.active.is_empty(),"Semantic screen entry starts an interface tween")
	await create_timer(0.42).timeout
	check(ui.interface_motion.active.is_empty(),"Entry bounce finishes and releases its tween")
	ui.show_multiplayer()
	await process_frame
	var popup = ui.overlay_shades.back().get_child(0)
	check(popup.has_meta("interface_entered"),"Popups share the entry animation")
	await create_timer(0.05).timeout
	ui.show_notice("Otro aviso", "Una nueva ventana sobre la anterior.")
	await process_frame
	check(ui.overlay_shades.size() == 2 and ui.overlay_shades.back().get_child(0).has_meta("interface_entered"),"Nested dialogs of the same kind receive their own entry animation")
	ui.go_home()
	await create_timer(0.42).timeout
	check(ui.interface_motion.active.is_empty() and ui.overlay_shades.is_empty(),"Navigation cancels obsolete dialog tweens")
	ui.animations_enabled = false
	ui.show_configuration()
	await settle()
	check(ui.interface_motion.active.is_empty(),"Animations-off preference suppresses popup tweens")
	await shot("13-configuracion")
	ui.show_audio_settings()
	await settle()
	check(text_node(ui,"Música") != null,"Audio settings describe music across every interface")
	await shot("14-sonido")
	ui.go_home()
	ui.exit_game()
	await settle()
	check(ui.quit_dialog.visible and ui.quit_dialog.dialog_text == "¿Seguro que quieres salir?","Exit confirmation remains mandatory")
	await shot("15-confirmar-salida")
	ui.quit_dialog.hide()
	ui.account.user = {}
	ui.account.access_token = ""
	ui.collection.clear()
	ui.guest = true
	ui.screen = "home"
	ui.render()
	await settle()
	check(text_node(ui,"Invitado") != null and meta_node(ui,"home_main_menu").get_child_count() == 4,"Guest retains the same four home choices")
	ui.open_single()
	await settle()
	ui.open_challenges()
	await settle()
	check(text_node(ui,"Accede a tu cuenta para guardar el progreso y recibir las recompensas del desafío.") != null,"Guest challenge explains the account requirement")
	ui.go_home()
	ui.open_account_feature("missions")
	await settle()
	check(text_node(ui,"Inicia sesión para guardar tu progreso y recibir recompensas.") != null,"Guest missions explain the account requirement")
	ui.go_home()
	ui.open_collection()
	await settle()
	check(text_node(ui,"Accede a tu cuenta para consultar tus cartas, mazos y sobres.") != null,"Guest collection route remains actionable")
	ui.go_home()
	ui.open_single()
	ui.open_random()
	await settle()
	check(ui.screen == "decks" and meta_node(ui,"deck_choices").get_child_count() == 3,"Guest retains the three base decks for practice")
	print(JSON.stringify({"ui_v014_checks":checks,"failures":failures,"real_emails_sent":0,"live_rpc_calls":0,"synthetic_results":2}))
	ui.sound.shutdown()
	ui.interface_motion.cancel_all()
	await create_timer(0.12).timeout
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
