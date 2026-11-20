extends SceneTree
const Game=preload("res://game.gd")
var ui
var checks=0
var failures=[]
var capture_dir=""
var captures=[]
class FixtureCollection extends "res://collection.gd":
	var calls=[]
	var reply={}
	func request(endpoint,payload):
		calls.append({"endpoint":endpoint,"payload":payload})
		last_reply=reply.duplicate(true)
		if endpoint=="aamix_redeem_code":status=redemption_message(last_reply)
		if endpoint=="aamix_delete_custom_deck":decks=decks.filter(func(d):return d.id!=payload.p_deck_id)
		changed.emit();return true
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):capture_dir=arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func nodes(node):
	var result=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func metas(key):return nodes(ui).filter(func(n):return n.has_meta(key))
func labels(text):return nodes(ui).filter(func(n):return n is Label and n.text==text)
func buttons(text):return nodes(ui).filter(func(n):return n is Button and n.text==text)
func settle():
	for _i in range(8):await process_frame
func shot(name):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(capture_dir);await RenderingServer.frame_post_draw
	var file=capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(file)==OK:captures.append(file)
func game_fixture():
	var g=Game.new()
	for p in range(2):
		var state={"name":"Prueba","deck_id":"fixture"}
		for zone in g.ZONES:state[zone]=[]
		g.players.append(state)
		for _i in range(40):state.deck.append(g.spawn("0100",p))
	g.phase="main";g.active=0;g.actor=0;g.turn=5;return g
func run():
	root.size=Vector2i(1600,1000)
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	ui.account.set_process(false);ui.account.configured=false;ui.account.remember_me=false;ui.account.refresh_token=""
	ui.online.set_process(false);ui.online.realtime.set_process(false);ui.rewards.set_process(false);ui.social.set_process(false)
	await settle()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000180"};ui.account.access_token="local-fixture-not-a-credential"
	ui.account.expires_at=Time.get_unix_time_from_system()+3600;ui.session_owner=ui.account.player_id();ui.guest=false
	var previous=ui.collection;previous.changed.disconnect(ui.collection_changed)
	ui.collection=FixtureCollection.new();ui.collection.account=ui.account;ui.add_child(ui.collection);ui.collection.changed.connect(ui.collection_changed);previous.queue_free()
	ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true;ui.collection.cards={"0100":40,"0101":3,"0105":1};ui.collection.restos=1000
	ui.collection.restos_welcome_claimed=true;ui.collection.welcome_pack={"claimed":true};ui.collection.event_refresh_tick=Time.get_ticks_msec()+999999
	ui.rewards.account_owner=ui.account.player_id()
	for prize in [{"reward_cards":[{"codigo":"01a","cantidad":3}]},{"reward_cover":"custom_viborin"},{"reward_deck_id":"girabl"}]:
		prize.already_redeemed=true;ui.collection.reply=prize;ui.screen="gift_code";ui.rewards.code_text="REPETIDO";ui.render();await ui.rewards.redeem();await settle()
		check(labels("ya has canjeado este regalo").size()==1 and metas("gift_reward_bundle").is_empty(),"Repeated gift has inline text and no reward interface: "+str(prize.keys()))
	await shot("01-codigo-ya-canjeado")
	ui.collection.reply={"already_redeemed":false,"reward_cards":[{"codigo":"0101","cantidad":1}]};ui.rewards.code_text="NUEVO";await ui.rewards.redeem();await settle()
	check(metas("gift_reward_bundle").size()==1,"First redemption still presents its original reward")
	ui.collection.status="";ui.screen="cards";ui.cards_tab="collection";ui.render();await settle()
	var slot=metas("collection_code").filter(func(n):return n.get_meta("collection_code")=="0101")[0]
	check(nodes(slot).any(func(n):return n is Label and n.text=="0101") and nodes(slot).any(func(n):return n is Label and n.text=="Nonungus") and nodes(slot).any(func(n):return n is Label and n.text=="Cantidad: 3"),"Collection puts number, name and owned quantity below each card")
	check(nodes(ui).any(func(n):return n is Label and n.text.contains("cartas coleccionadas")) and not nodes(ui).any(func(n):return n is Label and n.text.contains("cartas obtenidas")),"Collection uses coleccionadas")
	await shot("02-coleccion-nombres-cantidades")
	ui.collection.shop=[{"code":"0101","price":150},{"code":"0105","price":500}];ui.screen="shop";ui.render();await settle()
	check(metas("shop_card_name").size()==2 and labels("0101").size()==1 and labels("Nonungus").size()==1,"Shop lists number and name below its cards")
	check(not nodes(ui).any(func(n):return n is Label and n.text.begins_with("Cantidad:")),"Shop grid does not add ownership quantity")
	await shot("03a-tienda-grilla")
	ui.shop.confirm_purchase("0101",150);await settle()
	check(labels("(Tienes: 3)").size()==1 and metas("purchase_owned").size()==1,"Purchase confirmation shows owned copies below the image")
	check(not ui.collection.calls.any(func(call):return call.endpoint=="aamix_purchase_card"),"Opening confirmation does not purchase a card")
	await shot("03-tienda-confirmacion-cantidad")
	var custom={"id":"custom_00000000-0000-4000-8000-000000000180","nombre":"Mi mazo","portada":"custom_restos","custom":true,"draft":false,"revision":1,"cartas":[{"codigo":"0100","cantidad":39},{"codigo":"0101","cantidad":1}]}
	var gift={"id":"kajido","nombre":"Mazo Kajido","portada":"kajido","custom":false,"editable":true,"draft":true,"revision":1,"cartas":[{"codigo":"0100","cantidad":15}]}
	ui.collection.decks=[gift,custom];ui.cards_tab="decks";ui.screen="cards";ui.render();await settle()
	check(metas("delete_deck").size()==1 and metas("delete_deck")[0].get_meta("delete_deck")==custom.id,"Only user-created deck offers deletion; repaired gift remains protected")
	var count=ui.collection.calls.size();ui.confirm_delete_deck(gift);check(ui.collection.calls.size()==count and not ui.modal_open,"Gift cannot open deletion through its callback")
	ui.confirm_delete_deck(custom);await settle();check(buttons("Eliminar").size()==1 and buttons("Cancelar").size()==1,"Deleting a deck requires the in-game confirmation")
	await shot("04-eliminar-mazo-confirmacion")
	buttons("Eliminar")[0].pressed.emit();await settle()
	check(ui.collection.decks.size()==1 and ui.collection.cards["0101"]==3 and ui.collection.calls[-1].endpoint=="aamix_delete_custom_deck","Confirmed deletion removes deck while keeping cards")
	ui.preview_deck(gift);await settle();check(not nodes(ui).any(func(n):return n is Label and n.text.begins_with("Guardar un mazo")),"Ver Mazo removes redundant saving text")
	ui.collection.status="";ui.deck_builder.open(custom);await settle()
	check(not nodes(ui).any(func(n):return n is Label and (n.text.contains("Guardar no consume") or n.text.contains("Listo para jugar. También"))),"Editor removes both requested instructions")
	check(nodes(ui).any(func(n):return n is Label and n.text.contains("Máximo 3 copias por carta")),"Editor gives the full copy-limit wording")
	var tile=metas("builder_card")[0];var picture=nodes(tile).filter(func(n):return n is Button and n.text=="")[0]
	check(picture.flat and picture.get_theme_stylebox("normal") is StyleBoxEmpty,"Card picture has no inner square frame in editor")
	await shot("05-editor-sin-recuadro")
	ui.collection.missions=[{"id":"play_one","title":"Juega 1 partida","scope":"daily","progress":0,"target":1,"claimed":false,"reward_kind":"restos","reward_amount":25},{"id":"win_one","title":"Gana 1 partida","scope":"daily","progress":1,"target":1,"claimed":true,"reward_kind":"normal_pack","reward_amount":1}]
	ui.screen="missions";ui.rewards.mission_tab="daily";ui.render();await settle()
	check(metas("completed_mission_dimmed").size()==1 and is_equal_approx(metas("completed_mission_dimmed")[0].modulate.a,.72),"Completed daily mission row is dimmed")
	check(metas("mission_scroll_padding").size()==1 and metas("mission_scroll_padding")[0].get_theme_constant("margin_right")==24,"Mission scrollbar has a separate 24px gutter")
	await shot("06-misiones-opacas-espacio")
	ui.collection.missions=[{"id":"play_fifty","title":"Juega 50 partidas","scope":"lifetime","progress":50,"target":50,"claimed":false,"reward_kind":"normal_pack","reward_amount":10}]
	ui.rewards.mission_tab="lifetime";ui.render();await settle()
	check(metas("completed_mission_dimmed").size()==1 and not metas("claim_mission")[0].disabled,"Completed unclaimed historical mission dims while its reward remains claimable")
	var event=JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events[0]
	for mission in event.missions:mission.progress=1 if mission.id=="login" else 0;mission.claimed=false
	ui.collection.events=[event];ui.collection.events_deadline_tick=Time.get_ticks_msec()+60000
	ui.screen="event";ui.render();await settle()
	check(event.start_day=="2026-10-23" and event.end_day=="2026-10-26","Local welcome dates are 23 to26 October")
	check(metas("completed_mission_dimmed").size()==1,"Completed event mission receives the same dimming")
	check(labels("Diaria").size()==1 and labels("Única").size()==4,"Event scope appears separately beside the title")
	check(not nodes(ui).any(func(n):return n is Label and n.text.begins_with("Recompensa:") and (n.text.contains("Diaria") or n.text.contains("Única"))),"Event reward subtitle no longer mixes in its scope")
	await shot("07-evento-diagramacion-fechas")
	ui.game=game_fixture();ui.game.domain_uid=ui.game.players[0].deck.pop_back();ui.game.instances[ui.game.domain_uid].code="0130"
	ui.started=true;ui.human=0;ui.computer=1;ui.active_deck_id="fixture";ui.screen="table";ui.render();await settle()
	var mount=metas("shared_domain")[0].get_meta("pile_image");var domain=mount.get_child(0)
	check(is_equal_approx(domain.rotation,-PI/2.0) and domain.position==Vector2(3,56),"Domain rotation is reversed and stays registered in its slot")
	await shot("08-dominio-orientacion")
	var g=game_fixture();var options=[]
	for i in range(30):var uid=g.players[0].deck[i];g.instances[uid].code="0101";options.append(uid)
	g.pending={"kind":"search_hand","title":"Búsqueda de Aliados","player":0,"options":options,"min":0,"max":3,"optional":true,"shuffle":false}
	ui.game=g;ui.render();await settle()
	check(ui.targets.filter(func(n):return n.zone=="choice").size()==30,"Search interface renders all thirty eligible physical cards")
	var scroll=metas("choice_scroll")[0];scroll.scroll_vertical=99999;await settle();var offset=scroll.scroll_vertical
	var last=ui.targets.filter(func(n):return n.zone=="choice" and n.uid==options[-1])[0]
	check(offset>0 and last.get_global_rect().intersects(scroll.get_global_rect()),"Last eligible Ally is reachable by scrolling")
	last.clicked.call();await settle();scroll=metas("choice_scroll")[0]
	check(options[-1] in ui.choice_selected and scroll.scroll_vertical==offset,"Selecting lower search result preserves scroll position")
	await shot("09-busqueda-todas-opciones")
	g.pending={};g.winner=0;ui.winner_announced=false;ui.render();await settle()
	ui.collection.reply={"challenge_repeat_restos":5,"challenge_reward_packs":0};ui.rewards.account_owner=ui.account.player_id()
	ui.rewards.receipts=[{"begun":true,"complete":true,"reported":false,"account_owner":ui.account.player_id(),"match_id":"fixture-finished","victory":true,"challenge_stage":1}]
	await ui.rewards.pump_receipts();check(ui.rewards.pending_bonus_notices.size()==1,"Server-confirmed replay bonus is queued once after reporting result")
	ui.rewards._process(0);await settle()
	check(metas("challenge_repeat_bonus").size()==1 and labels("+5 Restos").size()==1,"Earned bonus appears as a simple post-match notice")
	await ui.rewards.pump_receipts();check(ui.rewards.pending_bonus_notices.is_empty(),"Reported match does not queue a duplicate notice")
	await shot("10-bono-post-partida")
	await ui.account.sign_out();await settle();check(ui.account.status.is_empty(),"Successful logout has no signed-out message below the screen")
	ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"online_final_ui_v180":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
