extends SceneTree
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok, text):
	checks += 1
	if not ok: failures.append(text); printerr("FAIL: ",text)
func nodes(n):
	var all = [n]
	for c in n.get_children(): all.append_array(nodes(c))
	return all
func metas(key): return nodes(ui).filter(func(n):return n.has_meta(key))
func buttons(text): return nodes(ui).filter(func(n):return n is Button and n.text == text)
func settle():
	for _i in range(8): await process_frame
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var path = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(path) == OK: captures.append(path)
func show_room(role, status, connected = true):
	var r = {"id":"00000000-0000-4000-8000-000000000161","role":role,"status":status,"active":status in ["invited","host_offer","guest_offer","confirming"],"peer":ui.social.data.friends[0],"revision":4,"host_connected":true,"guest_connected":connected,"own_code":"0104" if status in ["guest_offer","confirming","completed"] else "","peer_code":"0128" if status in ["confirming","completed"] else "","own_confirmed":false,"peer_confirmed":false,"drafts":[]}
	if role == "guest" and status == "guest_offer": r.own_code = ""; r.peer_code = "0104"
	ui.social.data.trade_room = r; ui.screen = "trades"; ui.render(); await settle()
	return r
func run():
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.animations_enabled = false; ui.automation_pause = true
	ui.social.set_process(false); ui.account.set_process(false); ui.account.configured = false; ui.account.remember_me = false
	ui.account.refresh_token = ""; ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false)
	await settle()
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000160"}
	ui.account.access_token = "local-fixture-not-a-credential"; ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.session_owner = ui.account.player_id(); ui.guest = false; ui.collection.owner_id = ui.account.player_id(); ui.collection.loaded = true
	ui.collection.cards = {"0100":40,"0104":3}; ui.collection.restos_welcome_claimed = true; ui.collection.welcome_pack = {"claimed":true}
	var event = JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events[0]
	for m in event.missions: m.progress = 0; m.claimed = false
	ui.collection.apply_events({"events":[event],"server_time":1000,"events_valid_until":4600,"server_day":event.start_day})
	ui.screen = "home"; ui.render(); await settle()
	var badge = metas("home_event_button")[0]
	check(badge.flat and badge.get_theme_stylebox("normal") is StyleBoxEmpty,"Event artwork has no button background")
	check(metas("event_badge_title")[0].text == "BIENVENIDA AAMIX Online","Home badge always names Welcome event")
	check(metas("event_badge_title")[0].get_theme_font("font") is FontVariation,"Event title uses bold font")
	check("21/10/2026" in metas("event_badge_dates")[0].text and "26/10/2026" in metas("event_badge_dates")[0].text,"Dates shown beneath event title")
	check(badge.get_global_rect().end.y < 850,"Event caption fits above exit controls")
	badge.mouse_entered.emit(); check(badge.scale.x > 1,"Flat event entry grows on hover")
	badge.mouse_exited.emit(); check(badge.scale == Vector2.ONE,"Event hover restores scale")
	await capture("01-inicio-evento-v160")
	ui.screen = "event"; ui.render(); await settle()
	check(buttons("Inicio").size() == 1 and buttons("Misiones").is_empty(),"Event header now returns Home")
	check(absf(metas("event_featured_card")[0].get_global_rect().get_center().x - metas("event_summary")[0].get_global_rect().get_center().x)<2,"Event artwork and summary stay centered")
	buttons("Inicio")[0].pressed.emit(); await settle(); check(ui.screen == "home","Event Home button navigates")
	ui.social.owner_id = ui.account.player_id(); ui.social.loaded = true
	var peer = {"id":"00000000-0000-4000-8000-000000000162","name":"Amigo de prueba","avatar_code":"0104"}
	ui.social.data = {"user_id":ui.account.player_id(),"friend_code":"ABCDEF123456","friends":[peer],"incoming":[],"outgoing":[],"duels":[],"trades":[],"trade_room":{},"tradable_cards":[{"code":"0104","owned":3,"available":3,"family":"ordinary"},{"code":"0105","owned":1,"available":1,"family":"singular"},{"code":"0128","owned":1,"available":1,"family":"ordinary"}]}
	ui.screen = "friends"; ui.render(); await settle()
	check(metas("social_heart_icon").size() == 1,"Friends has matching heart icon")
	check(absf(metas("social_centered_body")[0].get_global_rect().get_center().x-800)<3,"Friends body centered")
	check(metas("social_heart_icon")[0].global_position.y < buttons("Enviar solicitud")[0].global_position.y,"Heart above friends content")
	await capture("02-amigos-v160")
	var logo = metas("home_logo_link")[0]
	logo.mouse_entered.emit(); check(logo.scale.x > 1,"Corner logo has hover feedback")
	var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	logo._gui_input(click); await settle(); check(ui.screen == "home","Clicking corner logo returns Home")
	var current = await show_room("host","invited")
	check(buttons("Entrar a la sala").is_empty() and metas("trade_choose_card").is_empty(),"Inviter waits until friend accepts")
	check(metas("trade_invite_friend").is_empty(),"Active room hides new invitations")
	current = await show_room("guest","invited")
	check(buttons("Entrar a la sala").size() == 1,"Invited friend can enter room")
	await capture("03-invitacion-v160")
	current = await show_room("host","host_offer")
	check(metas("trade_choose_card").size() == 1 and not metas("trade_choose_card")[0].disabled,"Host chooses first")
	current = await show_room("guest","host_offer")
	check(metas("trade_choose_card").is_empty(),"Guest waits for host choice")
	current = await show_room("guest","guest_offer")
	metas("trade_choose_card")[0].pressed.emit(); await settle()
	check(ui.social_ui.rooms.picker_family == "ordinary" and metas("trade_picker_card").size() == 2,"Guest picker matches Normal and Special family")
	ui.render(); await settle()
	current = await show_room("host","confirming")
	check(metas("trade_confirm").size() == 1 and not metas("trade_confirm")[0].disabled,"Final pair enables confirmation")
	check(absf(metas("social_centered_body")[0].get_global_rect().get_center().x-800)<3,"Trade room stays centered")
	await capture("04-sala-v160")
	metas("trade_confirm")[0].pressed.emit(); await settle()
	check(buttons("Confirmar intercambio").size() == 1 and ui.modal_open,"Confirmation reviews the exact pair")
	await capture("05-confirmacion-v160")
	current = await show_room("host","confirming",false)
	check(metas("trade_confirm").is_empty(),"No confirmation while friend disconnected")
	ui.dark_theme = true; ui.apply_visual_palette(); ui.theme = ui.visual_theme.make_theme()
	current = await show_room("host","confirming")
	await capture("06-sala-oscuro-v160")
	ui.deck_builder.open(); ui.deck_builder.change("0100",1); await settle()
	metas("home_logo_link")[0]._gui_input(click); await settle()
	check(ui.screen == "deck_builder" and ui.modal_open and ui.deck_builder.dirty(),"Home logo protects unsaved deck edits")
	check(buttons("Salir sin guardar").size() == 1,"Deck leave offers explicit discard")
	if not buttons("Salir sin guardar").is_empty(): buttons("Salir sin guardar")[0].pressed.emit(); await settle()
	check(ui.screen == "home","Confirmed discard follows requested Home destination")
	ui.game.new_game(); ui.started = true; ui.screen = "table"; ui.game.winner = -1; ui.render(); await settle()
	metas("home_logo_link")[0]._gui_input(click); await settle()
	check(ui.screen == "table" and ui.game.winner == -1 and buttons("Abandonar e ir al inicio").size() == 1,"Table logo requires abandoning active match")
	buttons("Abandonar e ir al inicio")[0].pressed.emit(); await settle()
	check(ui.screen == "home" and ui.game.winner == ui.computer,"Confirmed Home abandonment records defeat")
	ui.sound.shutdown(); ui.queue_free(); await settle()
	print(JSON.stringify({"trade_rooms_ui_v160":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
