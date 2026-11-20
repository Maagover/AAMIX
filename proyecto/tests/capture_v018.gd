extends SceneTree
var ui
var dest=""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): dest=arg.trim_prefix("--screenshots=")
	run.call_deferred()
func settle():
	for _i in range(8): await process_frame
func shot(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dest.path_join(name+".png"))
func run():
	ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.animations_enabled=false;await settle()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000018","user_metadata":{"display_name":"AAMIX"}};ui.account.access_token="visual_fixture";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.account.set_process(false);ui.online.set_process(false);ui.rewards.set_process(false)
	ui.guest=false;ui.session_owner=ui.account.player_id();ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true
	if "--home-only" in OS.get_cmdline_user_args():
		ui.collection.restos=100;ui.collection.profile={"avatar_code":"0105"};ui.go_home();await settle();await shot("00-inicio-v018")
		ui.sound.shutdown();ui.queue_free();await settle();quit();return
	ui.collection.pending_opening={"opening_id":"visual-only","kind":"tc","cards":["0100","0101","0101","0104","0105"],"new_card_indices":[1.0,3.0,4.0]}
	ui.rewards.account_owner=ui.account.player_id();ui.rewards.reveal_id="visual-only";ui.rewards.reveal_open=true;ui.rewards.reveal_index=0
	ui.screen="packs";ui.render();await settle()
	var reveal=ui.find_children("*","Control",true,false).filter(func(n):return n.has_meta("pack_reveal"))[0]
	var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=reveal.origin+Vector2(100,100);reveal._gui_input(down)
	var move=InputEventMouseMotion.new();move.relative=Vector2(145,0);reveal._gui_input(move)
	await shot("01-sobre-frontal-deslizando")
	await reveal.slide_card();await settle();await shot("02-carta-nueva-estrella")
	ui.screen="multiplayer";ui.online.slot=0;ui.online.connected=true;ui.online.room={"room_id":"visual-only","code":"AAMIX018","status":"ready","revision":0,"confirmed":[true,false],"players":[{"name":"AAMIX"},{"name":"Amigo"}]};ui.render();await settle();await shot("03-sala-confirmacion")
	ui.online.clear();ui.collection.pending_opening=null;ui.account.clear_session();ui.play_guest();ui.open_random();ui.start_match(0);ui.begin_prepared_match();ui.automation_pause=true;await settle();await shot("04-abandonar-partida")
	ui.sound.shutdown();ui.queue_free();await settle();print("CAPTURES_V018_OK visual_only");quit()
