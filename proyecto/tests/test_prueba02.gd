extends SceneTree
const Rules=preload("res://deck_rules.gd")
var b
var checks=0
var failures=[]
var receipts=[0]
func _initialize():run.call_deferred()
func check(value,text):
	checks+=1
	if not value:failures.append(text);push_error(text)
func frames(n=8):for i in range(n):await process_frame
func nodes(root_node):
	var result=[root_node]
	for child in root_node.get_children():result.append_array(nodes(child))
	return result
func meta(key):return nodes(b).filter(func(n):return n.has_meta(key))
func surface(uid,zone="",owner=0):
	for n in b.targets:
		if not is_instance_valid(n):continue
		if uid>=0 and n.uid!=uid:continue
		if not zone.is_empty() and n.zone!=zone:continue
		if n.card_owner==owner:return n
	return null
func drag(uid,to_zone,to_owner=0,target=-1):
	var loc=b.game.location(uid);var payload=b.drag_payload(uid,loc.zone,loc.player)
	var dest=surface(target,to_zone,to_owner)
	check(payload!=null and dest!=null,"Board source/destination available: "+to_zone)
	if payload==null or dest==null:return false
	check(b.can_drop(payload,dest.descriptor()),"Real board permits guided drop: "+to_zone)
	var ok=b.apply_drop(payload,dest.descriptor());await frames();return ok
func pay(count):
	for i in range(count):await drag(b.game.players[0].resources.back(),"paid")
func tap(n):
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;n._gui_input(event)
func capture(name):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://tests/qa_p02_"+name+".png")
func expect_step(value):check(b.tutorial.step==value,"Guided step "+value+" (actual: "+b.tutorial.step+")")
func settle_motion():
	var until=Time.get_ticks_msec()+10000
	while (b.presenting or b.fx.busy) and Time.get_ticks_msec()<until:await process_frame
	await frames(5)
	check(not b.presenting and not b.fx.busy,"Board animation completes without blocking guide")
func run():
	b=load("res://main.tscn").instantiate();root.add_child(b);b.animations_enabled=false
	b.account.set_process(false);b.account.configured=false;b.rewards.set_process(false);b.online.set_process(false);b.online.realtime.set_process(false)
	b.social.set_process(false)
	b.guest=true;await frames();b.match_started.connect(func(_id,_stage):receipts[0]+=1)
	# Native key dispatch: a non-primary focused button must win over default.
	var center=b.overlay("notice");var shade=center.get_parent();var v=b.box(b.panel(center));var selected=[0]
	var first=b.button("Principal",func():selected[0]=1,false,true);var second=b.button("Seleccionado con flechas",func():selected[0]=2)
	v.add_child(first);v.add_child(second);await frames();first.grab_focus()
	var key=InputEventKey.new();key.keycode=KEY_DOWN;key.pressed=true;Input.parse_input_event(key);await frames(2)
	key=InputEventKey.new();key.keycode=KEY_DOWN;key.pressed=false;Input.parse_input_event(key);await frames(2)
	check(second.has_focus(),"Arrows focus the non-primary button")
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key);await frames(2)
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key);await frames(3)
	check(selected[0]==2,"Enter activates focused button, not default")
	b.close_overlay(shade);b.tutorial.start();await frames()
	expect_step("intro");check(b.screen=="tutorial" and meta("tutorial_zone").is_empty(),"Sam presents himself before board/explanations")
	await capture("intro")
	b.tutorial.begin();await frames();expect_step("resource")
	check(Rules.validate(b.tutorial.lesson_deck(),b.game.catalog).ok,"Guided deck is a legal 40-card deck")
	check(surface(-1,"hand")!=null and surface(-1,"resources")!=null and surface(-1,"paid")!=null and surface(-1,"defense")!=null,"Full ordinary board present")
	check(not nodes(b).any(func(n):return n is Button and n.text in ["Seleccionar","Seleccionada"]),"No separate card-selection buttons")
	await capture("resource")
	tap(surface(b.tutorial.refs.resource,"hand"));tap(surface(-1,"resources"));await frames();expect_step("pay_blue")
	check(b.game.players[0].resources.size()==2,"Click card then real zone lowers resource")
	await pay(2);expect_step("play_blue");await capture("paid")
	await drag(b.tutorial.refs.blue,"defense");expect_step("new_turn")
	check(b.game.players[0].defense.has(b.tutorial.refs.blue),"Azul really enters Defense")
	b.tutorial.next();await frames();expect_step("attack")
	check(b.game.players[0].resources.size()==2 and b.game.players[0].paid.is_empty(),"Next turn regroups spent resources")
	await drag(b.tutorial.refs.blue,"attack");expect_step("declare");b.declare_attack();await frames(12);expect_step("blocking_intro")
	check(b.game.players[1].graveyard.size()==3,"Attack deals exactly three deck damage")
	check(meta("current_force_uid").any(func(n):return n.get_meta("current_force_uid")==b.tutorial.refs.blue and n.get_child(0).text=="3"),"Azul force badge updates in Attack")
	await capture("attack")
	b.tutorial.next();await frames();expect_step("block")
	check(b.game.players[1].attack.size()==2 and b.game.players[0].defense.has(b.tutorial.refs.sam),"Attacking and defending cards in real lanes")
	await drag(b.tutorial.refs.sam,"attack",1,b.tutorial.refs.javier);expect_step("confirm_block");await capture("block")
	b.finish_blocks();await frames();expect_step("block_events");b.pass_priority();await frames(15);expect_step("ability_intro")
	check(b.game.players[0].graveyard.has(b.tutorial.refs.sam) and b.game.players[1].graveyard.has(b.tutorial.refs.javier),"Real combat defeats both blockers/attackers on tie")
	check(b.game.players[0].deck.size()==36,"Unblocked Mog deals three deck damage")
	b.tutorial.next();await frames();expect_step("ability")
	b.open_card_detail(b.tutorial.refs.almenta);await frames()
	var ability=nodes(b).filter(func(n):return n is Button and n.text=="Usar habilidad")
	check(ability.size()==1,"Uses normal card-detail ability control");ability[0].pressed.emit();await frames();expect_step("ability_target")
	b.select_choice(b.tutorial.refs.javier);b.confirm_choice();await frames();expect_step("ability_pay")
	await pay(1);expect_step("object_intro");check(b.game.unblockable(b.tutorial.refs.javier),"Ability really makes Javieriv unblockable")
	b.tutorial.next();await frames();await pay(2);expect_step("object_play")
	await drag(b.tutorial.refs.object,"defense",0,b.tutorial.refs.dicky);expect_step("object_done")
	check(b.game.force(b.tutorial.refs.dicky)==5,"Miku equipment adds four Force")
	await capture("object")
	b.tutorial.next();await frames();expect_step("domain_pay");await pay(4);expect_step("domain_play")
	var domain=meta("shared_domain")[0]
	b.highlight_destinations(b.drag_payload(b.tutorial.refs.domain,"hand",0));await frames()
	check(domain.get_meta("domain_lit",false),"Domain area lights while dragging a Domain")
	b.clear_highlights();await drag(b.tutorial.refs.domain,"domain",-1);expect_step("domain_done")
	check(b.game.force(b.tutorial.refs.mog)==5,"Domain actually raises Mog to five Force")
	await capture("domain")
	b.tutorial.next();await frames();await pay(3);expect_step("agile_play")
	await drag(b.tutorial.refs.gira,"defense");expect_step("agile_attack")
	check(b.game.instances[b.tutorial.refs.gira].entered==b.game.turn and b.game.can_attack(b.tutorial.refs.gira),"Agile permits attack on entry turn")
	await drag(b.tutorial.refs.gira,"attack");b.declare_attack();await frames(15);expect_step("unblock_intro")
	b.tutorial.next();await frames();await drag(b.tutorial.refs.depul,"attack");b.declare_attack();await frames(20);expect_step("singular_intro")
	check(b.game.players[1].defense.has(b.tutorial.refs.defender) and b.game.players[1].graveyard.size()==1,"Unblockable deals damage despite a defender")
	b.tutorial.next();await frames();expect_step("singular");b.tutorial.test_singular();await frames();expect_step("finish")
	check(b.game.invariant_errors().is_empty(),"Tutorial scenario cards retain engine invariants")
	b.tutorial.practice();await frames(12);check(not b.tutorial.active and b.practice_match and receipts[0]==0,"Tutorial and final practice create no reward receipt")
	b.started=false;b.automation_pause=true;b.screen="home";b.account.user={"id":"qa"};b.account.access_token="local-fixture";b.account.expires_at=Time.get_unix_time_from_system()+3600;b.guest=false
	b.collection.owner_id="qa";b.collection.loaded=true;b.collection.challenges=[];b.collection.busy=false
	for definition in b.CHALLENGES:
		b.collection.challenges.append({"stage":definition.stage,"unlocked":definition.stage<=3,"completed":definition.stage==1,"missions":[{"id":"win_five","title":"Gana 5 partidas","goal":5,"progress":5 if definition.stage==1 else 2,"reward_packs":2,"claimed":false,"can_claim":definition.stage==1}]})
	b.challenge_page=0;b.screen="challenges";b.render();await frames(15)
	check(b.challenge_ui!=null and b.challenge_ui.scroll.scroll_horizontal==0,"Carousel controller retained and starts at first level")
	var next=meta("challenge_next")[0];next.pressed.emit();await frames(8)
	check(b.challenge_page==1 and b.challenge_ui.scroll.scroll_horizontal>0,"Actual next arrow advances")
	next.pressed.emit();await frames(8);check(b.challenge_page==2,"Same arrow advances twice")
	var back=meta("challenge_previous")[0];back.pressed.emit();await frames(8);check(b.challenge_page==1,"Previous arrow returns")
	check(nodes(b).any(func(n):return n.has_meta("play_challenge") and n.get_meta("play_challenge")==2 and not n.disabled),"First victory unlocks next level without completing extra missions")
	b.challenge_ui.change_page(-1);await frames(8)
	b.animations_enabled=true;b.challenge_ui.change_page(1);await create_timer(0.40).timeout
	check(abs(b.challenge_ui.scroll.scroll_horizontal-b.challenge_ui.pitch)<3,"Animated arrow reaches correct level")
	b.animations_enabled=false;b.challenge_ui.change_page(-1);await frames(8)
	check(nodes(b).any(func(n):return n.has_meta("challenge_reward") and n.get_meta("challenge_reward")=="win_five" and not n.disabled and n.has_meta("primary")),"Ready reward is a colored clickable icon")
	check(meta("challenge_progress")[0].custom_minimum_size.y>=12,"Progress bars have visible thickness")
	for icon in meta("challenge_reward"):
		check(icon.get_child(0).get_global_rect().end.x<=icon.get_global_rect().end.x+1 and icon.get_child(0).get_global_rect().end.y<=icon.get_global_rect().end.y+1,"Reward art stays inside its button")
	var cards=meta("challenge_stage");var second_card=cards[1].get_parent().get_global_rect();var viewport=b.challenge_ui.scroll.get_global_rect()
	check(second_card.intersection(viewport).size.x>0 and second_card.intersection(viewport).size.x<second_card.size.x,"Next card peeks into viewport")
	await capture("carousel")
	b.collection.challenges[10].unlocked=true;b.collection.challenges[10].completed=true
	for mission in [{"id":"no_singular","title":"Gana 1 partida sin Cartas Singulares en tu mazo","reward_packs":1},{"id":"keep_twenty","title":"Gana 1 partida con más de 20 cartas en tu Mazo","reward_packs":1},{"id":"no_losses","title":"Gana 1 partida sin perder ningún Aliado","reward_packs":3}]:
		mission.merge({"goal":1,"progress":0,"claimed":false,"can_claim":false});b.collection.challenges[10].missions.append(mission)
	b.challenge_page=10;b.render();await frames(15)
	var last_card=meta("challenge_stage")[10].get_parent().get_global_rect()
	check(meta("level_mission").filter(func(n):return last_card.encloses(n.get_global_rect())).size()>=5,"All five rows fit the level 11 card")
	await capture("carousel11")
	b.collection.events=[{"id":"halloween_2026","title":"EVENTO HALLOWEEN","start_day":"2026-10-30","end_day":"2026-11-01"}];b.collection.events_deadline_tick=Time.get_ticks_msec()+60000;b.collection.server_day="2026-11-01"
	b.collection.cards={"0100":62,"0104":3,"0119":1,"0132":1}
	b.screen="cards";b.cards_tab="collection";b.render();await frames(12)
	check(meta("backdrop_text").all(func(n):return n.get_theme_color("font_color").r>0.9),"Text on Halloween backdrop is light")
	check(nodes(b).any(func(n):return n is Label and n.text=="(x62) 0100 - Restos"),"Owned card captions retained on changed background")
	await capture("collection")
	b.screen="home";b.render();await frames(8);await capture("home")
	b.started=true;b.screen="table";b.render();await frames();var empty_domain=meta("shared_domain")[0]
	check(empty_domain.modulate.a==1.0 and not empty_domain.get_meta("domain_lit",true),"Empty Domain dims panel, not its text")
	# Exercise regular-speed presentations on the same guided board.
	b.started=false;b.tutorial.start();b.tutorial.begin();b.animations_enabled=true;await frames()
	await drag(b.tutorial.refs.resource,"resources");await settle_motion();expect_step("pay_blue")
	for i in range(2):await drag(b.game.players[0].resources.back(),"paid");await settle_motion()
	await drag(b.tutorial.refs.blue,"defense");await settle_motion();expect_step("new_turn")
	var uid=b.tutorial.refs.blue;b.game.instances[uid].force_bonus=3;b.game.instances[uid].force_bonus_turn=b.game.turn;await frames(3)
	check(meta("current_force_uid").any(func(n):return n.get_meta("current_force_uid")==uid and n.get_child(0).text=="5"),"Force badge updates a temporary bonus without rebuilding the board")
	b.game.turn+=1;await frames(3)
	check(meta("current_force_uid").any(func(n):return n.get_meta("current_force_uid")==uid and n.get_child(0).text=="2"),"Force badge updates again when temporary bonus expires")
	b.tutorial.leave();await frames();check(b.screen=="single" and not b.tutorial.active and receipts[0]==0,"Skip returns to individual without a result receipt")
	b.account.access_token="";b.queue_free();await frames();print(JSON.stringify({"prueba02":{"checks":checks,"failures":failures,"reward_requests":receipts[0]}}));quit(0 if failures.is_empty() else 1)
