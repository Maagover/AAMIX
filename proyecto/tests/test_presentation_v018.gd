extends SceneTree
const Game=preload("res://game.gd")
const Snapshot=preload("res://multiplayer_snapshot.gd")
const Pack=preload("res://pack_reveal.gd")
const OnlineFixture=preload("res://tests/online_fixture_v018.gd")
var ui
var checks=0
var failures=[]
var shots=""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): shots=arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok,label):
	checks+=1
	if not ok: failures.append(label);printerr("FAIL ",checks,": ",label)
func settle():
	for _i in range(8): await process_frame
func find_text(node,value):
	if (node is Button or node is Label) and node.text==value: return node
	for child in node.get_children():
		var found=find_text(child,value)
		if found!=null: return found
	return null
func metas(node,key):
	var found=[]
	if node.has_meta(key): found.append(node)
	for child in node.get_children(): found.append_array(metas(child,key))
	return found
func dismiss():
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())
func shot(name):
	if shots.is_empty(): return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name+".png"))
func run():
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	ui.automation_pause=true
	await settle()
	ui.play_guest()
	ui.online.set_process(false)
	ui.rewards.set_process(false)
	var reveal=Pack.new().configure(ui,["0100","0101","0101","0104","0105"],0,true,"fixture",false,"tc",[1.0,3.0,4.0])
	reveal.size=Vector2(1080,600)
	ui.add_child(reveal)
	await settle()
	check(reveal.layers.get_child_count()==5 and reveal.layers.get_children().all(func(c):return c.visible),"Five cards are together from the first reveal")
	check(reveal.layers.get_children().all(func(c):return c.position==reveal.origin and c.rotation==0 and c.size==Vector2(296,402) and c.stretch_mode==TextureRect.STRETCH_SCALE),"All card bounds align frontally without a visible tilted edge")
	check(metas(reveal,"new_card_badge").size()==3,"New markers follow server indices including JSON numeric values")
	check(metas(reveal.current,"new_card_badge").is_empty(),"Previously owned front resource has no new marker")
	var front=reveal.current
	var down=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=reveal.origin+Vector2(100,100)
	reveal._gui_input(down)
	var move=InputEventMouseMotion.new()
	move.relative=Vector2(140,0)
	reveal._gui_input(move)
	check(front.position.x==reveal.origin.x+140 and reveal.layers.get_child(3).visible and reveal.layers.get_child(3).position==reveal.origin,"Next card is visible immediately during the drag")
	await shot("01-sobre-frontal-deslizando")
	await reveal.slide_card()
	await settle()
	check(reveal.revealed==1 and reveal.layers.get_child_count()==4 and reveal.current.rotation==0,"Sliding advances one card and preserves the frontal pile")
	check(metas(reveal.current,"new_card_badge").size()==1 and metas(reveal.current,"new_card_badge")[0].size==Vector2(24,24),"New card has only a small static corner star")
	await shot("02-carta-nueva-estrella")
	reveal.queue_free()
	await settle()
	var last=Pack.new().configure(ui,["0100","0101","0101","0104","0105"],4,true,"last",false,"tc",[4])
	last.size=Vector2(1080,600);ui.add_child(last);await settle()
	check(last.current.has_meta("singular_highlight") and metas(last.current,"new_card_badge").size()==1,"Singular shine and new-card badge coexist")
	last.queue_free();await settle()
	var single=Pack.new().configure(ui,["0104"],0,true,"single",false,"normal_card",[0])
	single.size=Vector2(1080,600);ui.add_child(single);await settle()
	check(single.layers.get_child_count()==1 and metas(single,"new_card_badge").size()==1,"Single-card normal packet supports the same new marker")
	single.queue_free();await settle()
	var unsupported=ui.game.catalog.keys().filter(func(code):return code not in Game.SUPPORTED)[0]
	ui.catalog_detail(unsupported);await settle()
	check(find_text(ui,"Catalogada. Su efecto todavía no está programado para partidas.")==null,"Collection details omit unprogrammed-card notice")
	dismiss()
	ui.open_random();ui.start_match(0);ui.begin_prepared_match();await settle()
	check(metas(ui,"abandon_match").size()==1,"Individual table exposes Abandonar partida")
	ui.confirm_abandon_match();await settle()
	check(find_text(ui,"¿Abandonar la partida?")!=null and ui.game.winner==-1,"Abandon asks confirmation before changing the result")
	find_text(ui,"Cancelar").pressed.emit();await settle()
	check(ui.game.winner==-1 and ui.started,"Cancelling abandon preserves the current game")
	ui.confirm_abandon_match();await settle()
	find_text(ui,"Abandonar").pressed.emit();await settle()
	check(ui.game.winner==ui.computer and ui.game.phase=="finished" and metas(ui,"result_art")[0].get_meta("result_art")=="defeat","Confirmed individual abandon shows defeat")
	ui.account.user={"id":"00000000-0000-4000-8000-000000000018","user_metadata":{"display_name":"Prueba"}}
	ui.account.access_token="isolated_fixture";ui.account.expires_at=Time.get_unix_time_from_system()+3600;ui.account.set_process(false)
	ui.session_owner=ui.account.player_id();ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true;ui.guest=false
	ui.rewards.account_owner=ui.account.player_id()
	ui.online.room={};ui.reset_match();ui.game.new_game(18);ui.game.take_visual_events();ui.started=true;ui.screen="table";ui.active_deck_id="papito"
	ui.rewards.match_started("papito");ui.render();ui.abandon_match();await settle()
	check(ui.rewards.receipts.size()==1 and ui.rewards.active_receipt.complete and not ui.rewards.active_receipt.victory,"Signed-in individual abandon queues one defeat receipt")
	ui.abandon_match();await settle()
	check(ui.rewards.receipts.size()==1,"Repeated abandon cannot duplicate local result")
	dismiss();ui.reset_match()
	ui.online.slot=0;ui.online.connected=true
	ui.online.room={"room_id":"local-room","status":"ready","revision":0,"confirmed":[false,false],"players":[{"name":"Prueba"},{"name":"Amigo"}]}
	ui.screen="multiplayer";ui.render();await settle()
	check(find_text(ui,"Confirmar")!=null and not find_text(ui,"Confirmar").disabled and find_text(ui,"Por confirmar")!=null,"Room shows explicit confirmation and per-player status")
	await shot("03-sala-confirmacion")
	ui.online.room.confirmed=[true,false];ui.render();await settle()
	check(find_text(ui,"Confirmado")!=null and metas(ui,"mp_confirm")[0].disabled,"Confirmed player cannot double-confirm and waits for opponent")
	ui.online.clear()
	var g=Game.new();g.new_game(18);g.take_visual_events()
	var before=Snapshot.capture(g);var old_host=g.players[0].hand.duplicate();g.mulligan()
	var packet=Snapshot.presentation(g,before,1)
	check(packet.any(func(e):return e.kind=="shuffle") and packet.filter(func(e):return e.kind=="move").size()==11,"Mulligan transmits all return/draw moves and shuffle")
	check(packet.filter(func(e):return e.kind=="move" and e.player==0).all(func(e):return int(e.uid)<0 and not e.has("face_code")),"Opponent mulligan uses anonymous backs without hidden identifiers or faces")
	g.take_visual_events();var uid=g.players[0].deck[0];before=Snapshot.capture(g);g.leave(uid,"graveyard",false)
	packet=Snapshot.presentation(g,before,1)
	check(packet[0].uid==uid and packet[0].face_code==g.code(uid),"Card entering graveyard carries its newly public face")
	g.take_visual_events();before=Snapshot.capture(g);g.leave(uid,"deck",true);packet=Snapshot.presentation(g,before,1)
	check(int(packet[0].uid)<0 and packet[0].face_code==g.code(uid) and packet.any(func(e):return e.kind=="shuffle"),"Recycling shows only the previously public face then hides deck identifiers")
	var fake=OnlineFixture.new().setup(ui);ui.add_child(fake);fake.set_process(false)
	ui.online=fake;ui.game.new_game(18);ui.game.take_visual_events();ui.started=true;ui.screen="table";ui.active_deck_id="online"
	fake.slot=0;fake.revision=1;fake.connected=true
	fake.room={"room_id":"fast-fixture","status":"playing","slot":0,"revision":1,"actor_slot":0,"state":Snapshot.capture(ui.game)}
	var committed_keeps=ui.game.keeps.duplicate()
	check(fake.submit("keep_hand",[]) and fake.commit_endpoint=="aamix_mp_host_action" and ui.game.keeps==committed_keeps,"Host stages a one-call action without optimistic board mutation")
	var full=fake.staged_commit.p_host_state.duplicate(true)
	fake.replies=[{"ok":true,"data":{"room_id":"fast-fixture","status":"playing","slot":0,"revision":2,"actor_slot":1,"state":full}}]
	await fake.pump();await settle()
	check(fake.calls.size()==1 and fake.calls[0].endpoint=="aamix_mp_host_action" and ui.game.keeps[0] and fake.staged_commit.is_empty(),"One successful HTTP round trip commits and applies the host action")
	fake.calls.clear();fake.slot=1;fake.room.slot=1;fake.room.actor_slot=1;ui.human=1;ui.game.actor=1
	fake.pending_command={"p_expected_revision":2};fake.command_submitted=true
	fake.replies=[{"ok":true,"data":{"room_id":"fast-fixture","status":"playing","slot":1,"revision":2,"actor_slot":1}}]
	await fake.pump()
	check(fake.calls.size()==1 and fake.calls[0].endpoint=="aamix_mp_poll","Acknowledged guest command polls instead of resubmitting repeatedly")
	check(fake.poll_interval()<=.2 and ui.fx.speed<1.0,"Waiting for a guest action uses short polling and compact online animations")
	fake.pending_command={};fake.command_submitted=false;fake.clear()
	print(JSON.stringify({"presentation_v018_checks":checks,"failures":failures,"network_requests":0}))
	ui.sound.shutdown();ui.queue_free();await settle()
	quit(0 if failures.is_empty() else 1)
