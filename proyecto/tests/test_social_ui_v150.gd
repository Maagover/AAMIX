extends SceneTree
const Game = preload("res://game.gd")
const Rules = preload("res://deck_rules.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []

class FixtureCollection extends "res://collection.gd":
	var requests = []
	func request(endpoint, payload):
		requests.append({"endpoint":endpoint, "payload":payload.duplicate(true)})
		if endpoint == "aamix_save_custom_deck":
			last_reply = {"last_saved_deck":{"id":"custom_00000000-0000-4000-8000-000000000140", "draft":payload.p_draft}}
			return true
		return false

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption); printerr("FAIL: ", caption)
func nodes(node):
	var result = [node]
	for child in node.get_children(): result.append_array(nodes(child))
	return result
func metas(key): return nodes(ui).filter(func(node): return node.has_meta(key))
func buttons(value): return nodes(ui).filter(func(node): return node is Button and node.text == value)
func settle():
	for _i in range(8): await process_frame
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var destination = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(destination) == OK: captures.append(destination)
	else: failures.append("Capture failed: "+name)
func apply_event(source):
	var event = source.duplicate(true)
	for state in event.missions:
		state.progress = 1 if state.id == "login" else 0
		state.claimed = false
	ui.collection.apply_events({"events":[event],"server_time":1000,"events_valid_until":4600,"server_day":event.start_day})
func add(g,p,code,zone):
	var uid = g.spawn(code,p)
	g.players[p][zone].append(uid)
	g.instances[uid].entered = 1
	return uid
func fresh():
	var g = Game.new()
	for p in range(2):
		var player = {"name":"Prueba","deck_id":"fixture"}
		for zone in g.ZONES: player[zone] = []
		g.players.append(player)
		for _i in range(12): add(g,p,"0100","deck")
		for _i in range(5): add(g,p,"0100","resources")
	g.active = 0; g.actor = 0; g.turn = 5; g.phase = "main"
	g.manual_payment = [false, false]
	return g
func present(code, owner = 0, viewer = 0):
	ui.game = fresh()
	ui.game.active = owner; ui.game.actor = owner
	var uid = add(ui.game,owner,code,"hand")
	ui.screen = "table"; ui.started = true; ui.human = viewer; ui.computer = 1-viewer
	ui.render(); await settle()
	var before = ui.capture_layout()
	var before_state = Snapshot.capture(ui.game)
	check(ui.game.request_play(uid), "Fixture play "+code)
	var packet = ui.game.take_visual_events()
	if viewer == 1:
		# A real host-to-guest presentation includes the public face only.
		ui.game.visual_events = packet.duplicate(true)
		packet = Snapshot.presentation(ui.game, before_state, 1)
		ui.game.take_visual_events()
	ui.presentation_generation += 1
	ui.presenting = true
	ui.start_presentation.call_deferred(before, packet, ui.presentation_generation)
	return uid
func run():
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.animations_enabled = false; ui.automation_pause = true
	ui.social.set_process(false); ui.account.set_process(false); ui.account.configured = false; ui.account.remember_me = false
	ui.account.refresh_token = ""; ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false)
	await settle()
	var old_collection = ui.collection
	old_collection.changed.disconnect(ui.collection_changed)
	ui.collection = FixtureCollection.new(); ui.collection.account = ui.account; ui.add_child(ui.collection)
	ui.collection.changed.connect(ui.collection_changed); old_collection.queue_free()
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000140"}
	ui.account.access_token = "local-fixture-not-a-credential"; ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.session_owner = ui.account.player_id(); ui.guest = false
	ui.collection.owner_id = ui.account.player_id(); ui.collection.loaded = true
	ui.collection.cards = {"0100":40,"0104":3}; ui.collection.restos_welcome_claimed = true; ui.collection.welcome_pack = {"claimed":true}
	ui.collection.missions = ui.collection.normalize_missions([
		{"id":"play_one","progress":1,"target":1,"reward_amount":25}, {"id":"win_one","progress":0,"target":1},
		{"id":"play_ten","progress":4,"target":10}, {"id":"win_ten","progress":2,"target":10},
		{"id":"play_fifty","progress":17},{"id":"win_fifty","progress":8},{"id":"win_five_kajido","progress":3},{"id":"win_five_flaan","progress":1},{"id":"win_five_papito","progress":0}])
	var events = JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events
	apply_event(events[0]); ui.screen = "home"; ui.render(); await settle()
	check(metas("home_event_button").size() == 1 and buttons("Evento Activo").is_empty(), "Home event entry uses artwork with one caption")
	var entry = metas("home_event_button")[0]
	check(entry.global_position.x > 800 and entry.global_position.y > 450 and entry.size.y <= 140, "Event entry below logo on right at moderate size")
	check(entry.flat and entry.get_theme_stylebox("normal") is StyleBoxEmpty, "Event icon has no button background")
	check(metas("gift_icon_button")[0].text.is_empty() and metas("settings_icon_button")[0].text.is_empty() and buttons("Amigos").size() == 1, "Home friends and gift/gear icon controls")
	await capture("01-inicio-evento")
	ui.screen = "missions"; ui.render(); await settle()
	check(metas("mission_row").size() == 2 and metas("mission_scope").all(func(n): return n.get_meta("mission_scope") == "daily"), "Daily missions tab contains original two")
	check(metas("mission_progress_bar").is_empty(), "Single-step daily missions have no bars")
	ui.rewards.change_mission_tab("lifetime"); await settle()
	check(metas("mission_row").size() == 7 and metas("mission_scope").all(func(n): return n.get_meta("mission_scope") == "lifetime"), "Historical tab contains original two and five new missions")
	check(metas("mission_progress_bar").size() == 7, "Every multi-step historical mission has a bar")
	await capture("02-misiones-historicas")
	ui.rewards.change_mission_tab("event"); await settle()
	check(ui.screen == "event" and metas("event_mission_row").size() == 5 and metas("event_featured_card")[0].get_meta("event_featured_card") == "0100", "Event tab shows Welcome text, card and five missions")
	check(not metas("claim_event_mission")[0].disabled and metas("claim_event_mission").slice(1).all(func(n):return n.disabled), "Only completed login is claimable")
	check(absf(metas("event_featured_card")[0].get_global_rect().get_center().x - metas("event_summary")[0].get_global_rect().get_center().x) < 2, "Event card and summary centered together")
	check(nodes(ui).filter(func(n): return n is Label and ("America/Santiago" in n.text or "Sólo inicia sesión" in n.text)).is_empty(), "Removed technical event footer")
	await capture("03-evento-bienvenida")
	ui.dark_theme = true; ui.apply_visual_palette(); ui.theme = ui.visual_theme.make_theme()
	apply_event(events[3]); ui.render(); await settle()
	check(metas("event_mission_row").size() == 3 and metas("event_featured_card")[0].get_meta("event_featured_card") == "0105", "Kajido event and mixed cosmetic reward fit dark theme")
	await capture("03-evento-kajido-oscuro")
	ui.collection.events_deadline_tick = Time.get_ticks_msec()-1
	check(ui.collection.active_events().is_empty(), "Monotonic server deadline hides stale events")
	ui.collection.expire_events(); ui.screen = "missions"; ui.render(); await settle()
	check(metas("mission_tab").filter(func(n):return n.get_meta("mission_tab") == "event")[0].disabled, "Event tab disabled outside calendar")
	var draft = {"draft":true,"cartas":[]}
	check(not Rules.validate(draft,ui.game.catalog).ok, "Resource-less draft rejected")
	draft.cartas = [{"codigo":"0100","cantidad":1}]
	check(Rules.validate(draft,ui.game.catalog).ok, "One-Resource draft accepted")
	ui.deck_builder.open(); await settle()
	check(ui.deck_builder.draft_button.disabled, "Editor blocks saving no-Resource draft")
	ui.deck_builder.change("0100",1); ui.deck_builder.open_design_picker(); await settle()
	ui.deck_builder.select_design("custom_restos"); ui.deck_builder.confirm_design(); await settle()
	check(ui.deck_builder.design_chosen and ui.deck_builder.editing.portada == "custom_restos", "Confirmed design survives editor renders")
	ui.deck_builder.save(true); await settle()
	check(ui.collection.requests.size() == 1 and ui.collection.requests[0].payload.p_portada == "custom_restos" and metas("deck_design_picker").is_empty(), "Chosen design saves directly without asking again")
	ui.deck_builder.open(); ui.deck_builder.change("0100",1); ui.deck_builder.save(true); await settle()
	check(metas("deck_design_picker").size() == 1 and ui.collection.requests.size() == 1, "Unchosen design is requested on first save")
	ui.deck_builder.cancel_design(); ui.deck_builder.close(); await settle()
	ui.animations_enabled = true
	var uid = await present("0104");
	var timeout = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < timeout and not ui.fx.ghosts.any(func(g):return is_instance_valid(g) and g.get_meta("played_zoom_hold",false)):
		await process_frame
	check(ui.fx.busy and ui.fx.ghosts.any(func(g):return is_instance_valid(g) and g.get_meta("played_zoom_hold",false) and g.scale.x >= 2.9), "Played Ally holds readable large card")
	await capture("04-carta-jugada-ampliada")
	await ui.fx.finished; await settle()
	var ends = ui.fx.trace.filter(func(e):return e.kind == "played_zoom_end")
	check(ends.size() == 1 and int(ends[0].hold_ms) >= 380 and int(ends[0].hold_ms) < 620 and uid in ui.game.players[0].defense, "Card holds 0.4 seconds then reaches destination")
	ui.game = fresh(); ui.game.phase = "resource"; uid = add(ui.game,0,"0100","hand")
	ui.game.request_play(uid)
	check(ui.game.take_visual_events().all(func(e):return not ui.fx.played_card(e)), "Resource play never zooms")
	ui.game = fresh(); uid = add(ui.game,0,"0104","hand")
	ui.game.discard_by_drag(uid)
	check(not ui.fx.played_card({"kind":"move","uid":uid,"from":"hand","to":"graveyard"}), "Discard is not mistaken for a played card")
	ui.game = fresh(); var event_uid = add(ui.game,0,"0117","hand"); ui.game.request_play(event_uid)
	var event_packet = ui.game.take_visual_events()
	check(event_packet.filter(func(e):return e.get("played",false)).size() == 1 and event_packet.any(func(e):return e.get("via", "") == "events" and ui.fx.played_card(e)), "Event card has exactly one zoom before effect destination")
	ui.game = fresh(); var counter = add(ui.game,1,"0130","defense"); var ally = add(ui.game,0,"0104","hand")
	ui.game.request_play(ally); var announced = ui.game.take_visual_events(); ui.game.choose([counter]); var resolved = ui.game.take_visual_events()
	check(announced.filter(func(e):return ui.fx.played_card(e)).size() == 1 and resolved.filter(func(e):return ui.fx.played_card(e)).is_empty(), "Countered card enlarges only at announcement")
	uid = await present("0104",0,1)
	await ui.fx.finished; await settle()
	check(ui.fx.trace.filter(func(e):return e.kind == "played_zoom").size() == 1, "Opponent played card enlarges through redacted presentation")

	ui.animations_enabled = false; ui.collection.events = []
	ui.social.owner_id = ui.account.player_id(); ui.social.loaded = true
	var peer = {"id":"00000000-0000-4000-8000-000000000151","name":"Amigo de prueba","avatar_code":"0104"}
	var trade = {"id":"00000000-0000-4000-8000-000000000152","peer":peer,"own_code":"0104","peer_code":"0128","own_confirmed":false,"peer_confirmed":true,"revision":2,"status":"open","drafts":[]}
	ui.social.data = {"user_id":ui.account.player_id(),"friend_code":"ABCDEF123456","friends":[peer],"incoming":[peer],"outgoing":[],"duels":[],"trades":[trade],"tradable_cards":[{"code":"0104","owned":3,"available":2,"family":"ordinary"},{"code":"0105","owned":1,"available":1,"family":"singular"},{"code":"0128","owned":1,"available":1,"family":"ordinary"}]}
	ui.screen = "friends"; ui.render(); await settle()
	check(metas("friend").size() == 1 and metas("friend_code_input").size() == 1 and buttons("Aceptar").size() == 1, "Friend list, code and incoming requests accessible")
	await capture("05-amigos-oscuro")
	ui.screen = "trades"; ui.social_ui.selected_trade = trade.id; ui.render(); await settle()
	check(metas("trade_detail").size() == 1 and buttons("Confirmar oferta").size() == 1 and not buttons("Confirmar oferta")[0].disabled, "Two-card offer and final confirmation available")
	await capture("06-intercambio-oscuro")
	ui.social_ui.confirm_offer(trade); await settle()
	check(buttons("Confirmar estas cartas").size() == 1 and ui.modal_open, "Final review shows exact pair before confirmation")
	ui.render(); ui.social_ui.change_offer(trade); await settle()
	check(ui.social_ui.picker_family == "ordinary" and ui.social_ui.picker_grid.get_child_count() == 2, "Normal/Special picker excludes Singular")
	ui.render(); ui.screen = "multiplayer"; ui.online_ui.section = "hub"; ui.render(); await settle()
	check(buttons("PARTIDA PRIVADA").size() == 1 and buttons("INTERCAMBIO").size() == 1, "Multiplayer hub has private match and trade")
	ui.online.busy = true; ui.online_ui.open_private(); await settle(); ui.online.busy = false
	check(buttons("Crear sala").size() == 1 and buttons("Unirme con código").size() == 1, "Existing private lobby retained")
	var base = {"id":"kajido","nombre":"Mazo Kajido","portada":"MazoKajido_Portada.png","custom":false,"editable":true,"draft":true,"revision":2,"cartas":[{"codigo":"0100","cantidad":39}],"recurso_inicial":"0100"}
	ui.collection.cards["0100"] = 40; ui.collection.decks = [base]
	check(ui.collection.playable_decks().is_empty(), "Damaged base draft unavailable for play")
	ui.deck_builder.open(base); await settle()
	check(ui.screen == "deck_builder" and ui.deck_builder.editing.editable and metas("choose_deck_design").is_empty(), "Affected base opens in editor preserving original cover")
	ui.deck_builder.change("0100",1); ui.deck_builder.save(false); await settle()
	check(ui.collection.requests[-1].payload.p_deck_id == "kajido" and not ui.collection.requests[-1].payload.p_draft and metas("deck_design_picker").is_empty(), "Repaired base saves forty cards without reprompting design")
	ui.game = fresh(); ui.human = 0; ui.computer = 1; ui.game.winner = 0; ui.started = true; ui.screen = "table"; ui.winner_announced = true
	ui.render(); await settle()
	check(not ui.sound.music_wanted and not ui.sound.music_player.playing and metas("result_art").size() == 1, "Victory screen stops music immediately")
	ui.game.winner = 1; ui.render(); await settle()
	check(not ui.sound.music_player.playing and metas("result_art")[0].get_meta("result_art") == "defeat", "Defeat screen keeps music stopped")
	ui.go_home(); await settle()
	check(ui.sound.music_wanted and ui.sound.music_player.playing, "Leaving result screen resumes menu music")
	ui.social.clear(); check(not ui.social.loaded and ui.social.data.is_empty() and ui.social.pending.is_empty(), "Logout clears social data and pending requests")

	ui.sound.shutdown(); ui.queue_free(); await settle()
	print(JSON.stringify({"social_ui_v150":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
