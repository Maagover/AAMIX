extends SceneTree
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []
class FixtureCollection extends "res://collection.gd":
	var requests = []
	func request(endpoint,payload):
		requests.append({"endpoint":endpoint,"payload":payload})
		if endpoint == "aamix_ack_achievement": achievement_notifications = achievement_notifications.filter(func(n):return n.id != payload.p_mission_id)
		changed.emit(); return true
class FixtureSocial extends "res://social.gd":
	var requests = []
	func sync(_quiet = false): return true
	func mutate(endpoint,payload):
		requests.append({"endpoint":endpoint,"payload":payload})
		if endpoint == "aamix_ack_trade": data.trade_notifications = []
		changed.emit(); return true
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok,text):
	checks += 1
	if not ok: failures.append(text); printerr("FAIL: ",text)
func nodes(n):
	var all = [n]
	for c in n.get_children(): all.append_array(nodes(c))
	return all
func metas(key): return nodes(ui).filter(func(n):return n.has_meta(key))
func buttons(text): return nodes(ui).filter(func(n):return n is Button and n.text==text)
func labels(text): return nodes(ui).filter(func(n):return n is Label and n.text==text)
func settle():
	for _i in range(8): await process_frame
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir); await RenderingServer.frame_post_draw
	var path = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(path)==OK: captures.append(path)
func run():
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.automation_pause = true; ui.animations_enabled = false
	ui.account.set_process(false); ui.account.configured = false; ui.account.remember_me = false; ui.account.refresh_token = ""
	ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false); ui.social.set_process(false)
	await settle()
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000170"}; ui.account.access_token = "local-fixture-not-a-credential"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600; ui.session_owner = ui.account.player_id(); ui.guest = false
	var previous = ui.collection; previous.changed.disconnect(ui.collection_changed)
	ui.collection = FixtureCollection.new(); ui.collection.account = ui.account; ui.add_child(ui.collection); ui.collection.changed.connect(ui.collection_changed); previous.queue_free()
	ui.collection.owner_id = ui.account.player_id(); ui.collection.loaded = true; ui.collection.cards = {"0100":40,"0114":0}
	ui.collection.restos_welcome_claimed = true; ui.collection.welcome_pack = {"claimed":true}
	ui.collection.available_avatar_codes = ui.profiles.ally_codes().filter(func(c):return c not in ["0112","0113","0114","0126","01a","01b"])
	previous = ui.social; previous.changed.disconnect(ui.social_ui.changed)
	ui.social = FixtureSocial.new().setup(ui); ui.add_child(ui.social); ui.social.set_process(false)
	ui.social_ui = preload("res://social_ui.gd").new(ui); ui.social.changed.connect(ui.social_ui.changed); previous.queue_free()
	ui.social.owner_id = ui.account.player_id(); ui.social.loaded = true
	ui.social.data = {"friend_code":"ABCDEF123456","friends":[],"incoming":[],"outgoing":[],"duels":[],"trades":[],"tradable_cards":[],"trade_room":{"id":"old-completed","active":false,"status":"completed","own_code":"0101","peer_code":"0104"},"trade_notifications":[{"id":"received-room","code":"0104","drafts":["kajido"]}]}
	ui.screen = "trades"; ui.social_ui.changed(); await settle()
	check(metas("trade_received_notice").size()==1 and labels("Has recibido: Javieriv").size()==1,"Incoming card appears before completion message")
	check(metas("trade_completed_notice").is_empty() and metas("trade_room_view").is_empty(),"No completed room or premature completion banner")
	check(labels("Tu carta").is_empty() and labels("Carta de tu amigo").is_empty(),"Post-trade notice never shows confusing offered pair")
	await capture("01-carta-recibida-v170")
	buttons("Continuar")[0].pressed.emit(); await settle()
	check(metas("trade_completed_notice").size()==1 and metas("trade_received_notice").is_empty(),"Acknowledging receipt then shows Intercambio completado")
	check(metas("trade_room_view").is_empty() and ui.social.data.trade_notifications.is_empty(),"Acknowledged room and cards disappear")
	await capture("01b-intercambio-completado-v170")
	ui.social_ui.open_trades(); await settle(); check(metas("trade_completed_notice").is_empty() and metas("trade_room_view").is_empty(),"Reopening trades has no completed history")
	ui.screen = "friends"; ui.render(); await settle()
	check(labels("Aún no has enviado ninguna solicitud").size()==1,"Empty friends shows requested message")
	check(metas("friend_list_spacing").size()==1 and metas("friend_list_spacing")[0].size.y>=24,"Friend request field separated from list")
	check(metas("floating_icon").size()==1 and metas("social_heart_icon").size()==1,"Friends heart floats in fixed slot")
	await capture("02-amigos-v170")
	ui.animations_enabled = true; ui.render(); await settle()
	var slot = metas("floating_icon")[0]; var art = slot.picture; var start_y = art.position.y; var slot_position = slot.position
	await create_timer(0.25).timeout
	check(absf(art.position.y-start_y)>0.1 and slot.position==slot_position,"Actual floating motion keeps surrounding layout stationary")
	ui.animations_enabled = false; ui.screen = "multiplayer"; ui.online_ui.section = "hub"; ui.render(); await settle()
	check(metas("multiplayer_battle_icon").size()==1 and metas("floating_icon").size()==1,"Multiplayer swords float")
	ui.screen = "single"; ui.render(); await settle()
	check(metas("floating_icon").size()==2 and metas("ui_icon").filter(func(n):return n.get_meta("ui_icon") in ["dice","swords"]).size()==2,"Single-player dice and swords both float")
	ui.screen = "gift_code"; ui.render(); await settle()
	check(metas("floating_icon").size()==1 and metas("ui_icon").filter(func(n):return n.get_meta("ui_icon")=="gift").size()==1,"Gift-code screen has floating gift above input")
	await capture("03-codigo-regalo-v170")
	ui.collection.shop = [{"code":"0101","price":150},{"code":"0105","price":500}]
	ui.screen = "shop"; ui.render(); await settle()
	check(metas("shop_cart_icon").size()==1 and metas("floating_icon").size()==1,"Shop has original floating cart above cards")
	check(metas("shop_cart_icon")[0].get_global_rect().end.y < metas("shop_grid")[0].global_position.y,"Shop icon does not overlap cards")
	await capture("04-tienda-v170")
	var stationary = metas("floating_icon")[0]; var position = stationary.picture.position
	await create_timer(0.2).timeout; check(stationary.picture.position==position,"Floating respects disabled animations")
	ui.screen = "home"; ui.render(); await settle(); ui.profiles.show_picker(); await settle()
	check(["0112","0113","0114","0126"].all(func(code):return ui.profiles.choices[code].disabled),"Four mission photos unavailable before entitlement")
	check(not ui.profiles.choices.has("01a") and not ui.profiles.choices.has("01b"),"Gift portraits absent until earned")
	ui.profiles.select("0114"); check(ui.profiles.selected_code.is_empty(),"Locked photo cannot be chosen by callback")
	await capture("05-perfiles-bloqueados-v170")
	ui.profiles.close(); ui.collection.available_avatar_codes.append_array(["0114","01a"]); ui.profiles.show_picker(); await settle()
	check(not ui.profiles.choices["0114"].disabled and ui.profiles.choices.has("01a") and not ui.profiles.choices.has("01b"),"Only earned photos become selectable")
	ui.profiles.select("0114"); check(ui.profiles.selected_code=="0114" and int(ui.collection.cards["0114"])==0,"Unlocked photo stays usable after cards are traded")
	ui.profiles.close()
	var states = []
	for id in ["play_one","win_one","play_ten","win_ten","play_fifty","win_fifty","win_five_kajido","win_five_flaan","win_five_papito","collect_ten_sam","collect_ten_yuri","collect_ten_celia","collect_ten_viborin","challenge_complete"]:
		states.append({"id":id,"progress":10 if id=="collect_ten_sam" else 0,"claimed":false})
	ui.collection.missions = ui.collection.normalize_missions(states)
	ui.screen = "missions"; ui.rewards.mission_tab = "lifetime"; ui.render(); await settle()
	check(ui.collection.missions.size()==13 and metas("mission_row").size()==11,"Four visible historical missions added; secrets filtered")
	check(metas("mission_reward_icon").filter(func(n):return n.get_meta("mission_reward_icon")=="avatar").size()==4,"Photo missions show portrait rewards")
	var sam = ui.collection.missions.filter(func(m):return m.id=="collect_ten_sam")[0]
	check(sam.progress==10 and not sam.claimed,"Latched mission remains claimable at zero currently owned")
	ui.dark_theme = true; ui.apply_visual_palette(); ui.theme = ui.visual_theme.make_theme(); ui.render(); await settle()
	await capture("06-misiones-oscuro-v170")
	for n in nodes(ui):
		if n is ScrollContainer: n.scroll_vertical = 1200
	await settle(); await capture("06b-misiones-fotos-oscuro-v170")
	ui.collection.achievement_notifications = [{"id":"challenge_complete","title":"Completa el Desafío AAMIX","kind":"card","code":"01d"}]
	ui.rewards.present_achievement(); await settle()
	check(metas("secret_achievement_reward").size()==1,"Completed secret mission shows its received reward")
	await capture("07-premio-secreto-v170")
	buttons("Continuar")[0].pressed.emit(); await settle(); ui.rewards.present_achievement()
	check(ui.collection.achievement_notifications.is_empty() and metas("secret_achievement_reward").is_empty(),"Secret reward acknowledgement removes repeat popup")
	ui.collection.available_custom_covers.append_array(["custom_maagover","custom_girabl"])
	check(ui.deck_cover_texture({"custom":true,"portada":"custom_maagover"}) != null and ui.deck_cover_texture({"custom":true,"portada":"custom_girabl"}) != null,"Both earned challenge covers resolve existing unified artwork")
	ui.rewards.show_code_reward({"reward_avatar":"01a","reward_cards":[{"codigo":"01a","cantidad":3}]}); await settle()
	check(metas("gift_reward_kind").size()==2 and metas("gift_reward_kind").any(func(n):return n.get_meta("gift_reward_kind")=="avatar"),"Gift receipt clearly includes cards and profile photo")
	await capture("08-foto-regalo-v170")
	ui.render(); ui.sound.shutdown(); ui.queue_free(); await settle()
	print(JSON.stringify({"milestones_ui_v170":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
