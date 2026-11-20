extends SceneTree
const Game=preload("res://game.gd")
const Bot=preload("res://ai.gd")
class LocalOnline extends "res://online_match.gd":
	var calls=[]
	func in_match():return true
	func waiting_action():return false
	func submit(method,args=[]):
		calls.append(method)
		return preload("res://multiplayer_snapshot.gd").dispatch(board.game,board.human,method,args)
var ui
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(value,message):
	checks+=1
	if not value:failures.append(message);push_error(message)
func fresh():
	var g=Game.new();g.new_game(111);g.visual_events.clear();g.queue.clear();g.pending.clear();g.phase="main";g.turn=3;g.active=0;g.actor=0
	for p in [0,1]:
		for z in ["hand","defense","attack","resources","paid"]:g.players[p].deck.append_array(g.players[p][z]);g.players[p][z].clear()
	return g
func put(g,p,code,z):var uid=g.spawn(code,p);g.players[p][z].append(uid);return uid
func frames(n=10):for i in range(n):await process_frame
func descendants(n):
	var all=[n]
	for child in n.get_children():all.append_array(descendants(child))
	return all
func click(text):
	for n in descendants(ui):
		if n is Button and n.text==text and not n.disabled:n.pressed.emit();return true
	return false
func capture(name):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/qa_v111_"+name+".png")
func run():
	var g=fresh();var a=put(g,0,"0104","attack");var m=put(g,0,"0109","attack");var sam=put(g,1,"0114","defense")
	g.attacks=[a,m];g.phase="blocks";g.actor=1
	check(Bot.new().block(g,1),"AI finishes blocks")
	check(g.blocks.get(a,-1)==sam and not g.blocks.has(m),"Sam trades with Javieriv instead of dying to Mog")
	g=fresh();var ally=put(g,0,"0111","defense");g.leave(ally,"graveyard")
	check(g.allies_lost[0]==1,"Ally loss tracked when destroyed")
	g=fresh();ally=put(g,0,"0111","defense");g.leave(ally,"deck")
	check(g.allies_lost[0]==0,"Returning to deck is not destruction")
	ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.animations_enabled=false;await frames()
	ui.gameplay_settings_path="res://tests/qa_gameplay.cfg"
	ui.guest=true;ui.screen="home";ui.render();await frames()
	check(descendants(ui).any(func(n):return n is Button and n.focus_mode==Control.FOCUS_ALL),"Buttons support keyboard focus")
	var key=InputEventKey.new();key.keycode=KEY_DOWN;key.pressed=true;ui._unhandled_key_input(key);await frames()
	check(ui.get_viewport().gui_get_focus_owner() is Button,"Arrow selects a home button")
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key);await frames(2)
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key);await frames()
	check(ui.screen=="single","Enter activates focused home button")
	key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;ui._unhandled_key_input(key);await frames()
	check(ui.screen=="home","Escape returns from interfaces")
	var center=ui.overlay("notice");var shade=center.get_parent();var body=ui.box(ui.panel(center));var entry=LineEdit.new();body.add_child(entry)
	var confirmed=[false];body.add_child(ui.button("Confirmar",func():confirmed[0]=true,false,true));ui.decorate_navigation();entry.text_submitted.emit("QA")
	check(confirmed[0],"Enter in a text field activates confirmation")
	ui.close_overlay(shade)
	await capture("home")
	ui.game=fresh();ui.game.manual_payment=[true,false];ui.human=0;ui.computer=1;ui.started=true;ui.screen="table";ui.automation_pause=true;ui.practice_match=true;ui.render();await frames()
	check(not descendants(ui).any(func(n):return n is Button and n.text in ["Nueva partida","Cómo jugar"]),"Old table controls removed")
	check(descendants(ui).any(func(n):return n is Button and n.text=="Registro"),"Log available by button")
	ui.show_log();var reader=ui.overlay_shades.back();ui.game.note("A live move under the reader");ui.render();await frames()
	check(is_instance_valid(reader) and reader in ui.overlay_shades,"Log survives board renders")
	check(descendants(reader).any(func(n):return n.has_meta("live_log") and "A live move" in n.text),"Log updates under reader")
	ui.game.actor=1;ui.game.active=1;ui.automation_pause=false;var before_turn=ui.game.turn
	await create_timer(0.85).timeout
	check(ui.game.turn>before_turn and reader in ui.overlay_shades,"Rival continues while log stays open")
	ui.automation_pause=true;ui.game.phase="main";ui.game.active=0;ui.game.actor=0
	ui.close_interface(reader)
	for i in range(3):put(ui.game,0,"0100","resources")
	var card=put(ui.game,0,"0111","hand");ui.render();ui.automatic_cost=false;ui.ask_automatic_cost=true
	check(ui.request_card(card),"Unpaid card opens prompt")
	check(ui.overlay_shades.back().get_meta("overlay_kind")=="auto_cost","Cost prompt kind")
	check(click("No"),"Cost cancellation available")
	check(card in ui.game.players[0].hand and ui.game.payment_request.is_empty(),"No cancels without consuming resources")
	ui.request_card(card);check(click("Sí"),"Cost acceptance available");await frames(80)
	check(card in ui.game.players[0].defense and ui.game.players[0].paid.size()==2,"Automatic payment spends exact cost and plays card")
	ui.game=fresh();ui.game.manual_payment=[true,false]
	for i in range(4):put(ui.game,0,"0100","resources")
	card=put(ui.game,0,"0111","hand");ui.render();ui.request_card(card)
	var prompt=ui.overlay_shades.back()
	for n in descendants(prompt):
		if n is CheckBox:n.button_pressed=true
	click("No");check(not ui.automatic_cost and not ui.ask_automatic_cost,"Remember No disables further prompts")
	ui.request_card(card);await frames(15)
	check(not ui.game.payment_request.is_empty() and ui.overlay_shades.is_empty(),"Remember No retains manual payment")
	ui.perform(ui.game.cancel_payment);await frames(15);ui.ask_automatic_cost=true;ui.request_card(card)
	for n in descendants(ui.overlay_shades.back()):
		if n is CheckBox:n.button_pressed=true
	click("Sí");await frames(35)
	check(ui.automatic_cost and not ui.ask_automatic_cost and card in ui.game.players[0].defense,"Remember Yes enables automatic payment")
	ui.automatic_cost=false;ui.ask_automatic_cost=true
	var real_online=ui.online;ui.remove_child(real_online);var local_online=LocalOnline.new();local_online.board=ui;ui.add_child(local_online);local_online.set_process(false);ui.online=local_online
	ui.game=fresh();ui.game.manual_payment=[true,true]
	for i in range(2):put(ui.game,0,"0100","resources")
	card=put(ui.game,0,"0111","hand");ui.automatic_cost=true;ui.render();ui.request_card(card);await frames(30)
	check(card in ui.game.players[0].defense and local_online.calls==["request_play","reserve_resource","reserve_resource"],"Multiplayer auto cost uses existing validated commands")
	ui.automatic_cost=false;ui.online=real_online;ui.add_child(real_online);local_online.queue_free()
	ui.show_configuration();var config=ui.overlay_shades.back();ui.render();await frames()
	check(config in ui.overlay_shades and not ui.modal_blocks_play(),"Settings survive and do not stop rules")
	ui.close_interface(config)
	await capture("table")
	var target=put(ui.game,1,"0104","attack");var blocker=put(ui.game,0,"0111","defense");ui.game.phase="blocks";ui.game.active=1;ui.game.actor=0;ui.game.attacks=[target];ui.game.assign_block(target,blocker);ui.render();await frames()
	ui.open_card_detail(blocker);var detail=ui.overlay_shades.back();ui.render();await frames()
	check(detail in ui.overlay_shades,"Card detail survives updates during combat")
	await capture("detail_above_block");ui.close_interface(detail)
	ui.dark_theme=true;ui.apply_visual_palette();ui.theme=ui.visual_theme.make_theme();ui.render();ui.show_configuration();await frames();await capture("dark_settings");ui.close_interface(ui.overlay_shades.back());ui.dark_theme=false;ui.apply_visual_palette();ui.theme=ui.visual_theme.make_theme()
	ui.game.winner=0;ui.started=false;ui.tutorial.start();await frames();await capture("tutorial")
	var t=ui.tutorial
	for lesson in range(t.LESSONS.size()):
		t.step=lesson;t.prepare();ui.render();await frames()
		match lesson:
			0:t.select(t.find("0100"));t.lower_resource()
			1:t.select(t.find("0111"));t.pay(2);t.play_ally()
			2:t.select(t.find("0111"));t.attack()
			3:t.select(t.find("0104"));t.block_attacker()
			4:t.ability()
			5:t.select(t.find("0124"));t.equip()
			6:t.select(t.find("0122"));t.domain()
			7:
				for code in ["0127","0102","0103"]:t.select(t.find(code));t.answer()
		check(t.completed,"Tutorial lesson %d playable"%lesson)
		if lesson==0:check(t.model.players[0].resources.size()==2,"Tutorial really lowers resource")
		if lesson==1:check(t.find("0111") in t.model.players[0].defense,"Tutorial really plays ally")
		if lesson==4:check(t.model.unblockable(t.find("0104")),"Tutorial really applies Almenta")
		if lesson==5:check(t.model.force(t.find("0107"))==5,"Tutorial really equips Miku")
		if lesson==6:check(t.model.code(t.model.domain_uid)=="0122","Tutorial really plays Talca")
	check(t.model.domain_uid==-1,"Tutorial scenarios independent")
	t.practice();await frames(30);check(ui.practice_match and ui.active_challenge_stage==0 and not t.active,"Practice is separate from rewards")
	ui.started=false;ui.screen="challenges";ui.guest=false;ui.account.access_token="qa-placeholder";ui.account.user={"id":"qa"};ui.account.expires_at=Time.get_unix_time_from_system()+3600;ui.collection.owner_id="qa"
	ui.collection.challenges=[{"stage":11,"unlocked":true,"completed":false,"missions":[{"id":"win_five","title":"Gana 5 partidas","goal":5,"reward_packs":2,"progress":2,"claimed":false,"can_claim":false},{"id":"no_singular","title":"Gana 1 partida sin Cartas Singulares en tu mazo","goal":1,"reward_packs":1,"progress":0,"claimed":false,"can_claim":false},{"id":"keep_twenty","title":"Gana 1 partida con más de 20 cartas en tu Mazo","goal":1,"reward_packs":1,"progress":0,"claimed":false,"can_claim":false},{"id":"no_losses","title":"Gana 1 partida sin perder ningún Aliado","goal":1,"reward_packs":3,"progress":0,"claimed":false,"can_claim":false}]}]
	ui.challenge_page=10;ui.render();await frames();await capture("challenge")
	check(descendants(ui).filter(func(n):return n.has_meta("challenge_stage")).size()==1,"Only one challenge level visible")
	ui.account.access_token="";ui.queue_free();await frames()
	print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
