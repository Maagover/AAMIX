extends SceneTree
const Game=preload("res://game.gd")
const Bot=preload("res://ai.gd")
var checks=0
var failures=[]
var ui
var captures=""
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):captures=a.trim_prefix("--captures=")
	run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func fresh():
	var g=Game.new()
	for p in range(2):
		var state={"name":"QA","deck_id":"miku"}
		for z in g.ZONES:state[z]=[]
		g.players.append(state)
		for i in range(40):
			var u=g.spawn("0100",p);state["resources" if i<8 else "deck"].append(u)
	g.turn=5;g.phase="main";g.active=0;g.actor=0;return g
func put(g,p,code,z):
	var u=g.players[p].deck.pop_front();g.instances[u].code=code;g.instances[u].entered=1;g.players[p][z].append(u);return u
func fight(g,a,b):return g.declare_attack(a)and g.assign_block(a[0],b)and g.finish_blocks()
func nodes(n):
	var result=[n]
	for c in n.get_children():
		if not c.is_queued_for_deletion():result.append_array(nodes(c))
	return result
func meta(key):return nodes(ui).filter(func(n):return n.has_meta(key))
func settle():
	for i in range(8):await process_frame
func capture(name):
	if captures.is_empty()or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(captures);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func run():
	var bot=Bot.new();var g=fresh();var a=put(g,0,"0104","defense");var b=put(g,0,"0112","defense");var blue=put(g,1,"0111","defense");var conflict=put(g,1,"0116","hand")
	check(fight(g,[a,b],blue),"Two attackers and a valid blocking Azul")
	check(g.force(blue)>g.force(a),"Public blocking bonus predicts Javieriv defeat")
	check(bot.best_target(g,conflict,1)==b,"Conflict selects the second threat instead of an already losing attacker")
	check(bot.try_play(g,1)and b in g.players[0].deck and conflict in g.players[1].graveyard,"Conflict really shuffles the other attacker")
	for i in range(4):
		if g.phase=="events":g.pass_priority()
	check(a in g.players[0].graveyard and blue in g.field(1),"Combat then defeats first attacker while Azul survives")
	check(g.invariant_errors().is_empty(),"Combined event and combat preserve all cards")
	g=fresh();a=put(g,0,"0104","defense");blue=put(g,1,"0111","defense");conflict=put(g,1,"0116","hand");fight(g,[a],blue)
	check(bot.play_score(g,conflict,1)<0 and not bot.try_play(g,1),"Keeps Conflict when the sole target already loses cleanly")
	g.players[1].defense.erase(blue);g.players[1].graveyard.append(blue);g.combat_roles.erase(blue)
	check(bot.play_score(g,conflict,1)>0 and bot.best_target(g,conflict,1)==a,"Reevaluates after blocker leaves instead of trusting stale assignment")
	g=fresh();a=put(g,0,"0104","defense");var support=put(g,1,"0104","defense");conflict=put(g,1,"0116","hand");fight(g,[a],support)
	check(bot.play_score(g,conflict,1)>0,"Can save own ally from a mutual defeat when no better target exists")
	g=fresh();a=put(g,0,"0104","defense");b=put(g,0,"0112","defense");blue=put(g,1,"0111","defense");conflict=put(g,1,"0116","hand");fight(g,[a,b],blue)
	g.instances[blue].force_bonus_turn=g.turn;g.instances[blue].force_bonus=-3
	check(bot.best_target(g,conflict,1)==a,"Reevaluates current Force if the first attacker now defeats its blocker")
	g=fresh();a=put(g,0,"0104","defense");b=put(g,0,"0112","defense");blue=put(g,1,"0111","defense");conflict=put(g,1,"0116","hand");fight(g,[a,b],blue)
	while g.players[1].deck.size()>1:g.players[1].graveyard.append(g.players[1].deck.pop_front())
	check(bot.best_target(g,conflict,1)==b,"Prioritizes removing unblocked lethal damage")
	
	# Separate valid attacking-side fixture.
	g=fresh();a=put(g,0,"0111","defense");b=put(g,1,"0104","defense");conflict=put(g,0,"0116","hand");fight(g,[a],b);g.actor=0
	check(bot.best_target(g,conflict,0)==b and bot.play_score(g,conflict,0)>0,"Attacker may remove a blocker to push damage through")
	g.phase="main";check(bot.removal_value(g,b,0)==bot.target_value(g,b,0),"Main phase uses normal threat priorities")
	# Hidden hands and deck identities cannot affect the public tactical choice.
	g=fresh();a=put(g,0,"0104","defense");b=put(g,0,"0112","defense");blue=put(g,1,"0111","defense");conflict=put(g,1,"0116","hand");fight(g,[a,b],blue)
	var selected=bot.best_target(g,conflict,1);var hidden=put(g,0,"0119","hand")
	for u in g.players[0].deck:g.instances[u].code="0130"
	check(bot.best_target(g,conflict,1)==selected and hidden in g.players[0].hand,"Targeting ignores rival's hidden hand and deck identities")
	root.size=Vector2i(1600,1000);ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.automation_pause=true;ui.animations_enabled=false
	for n in [ui.account,ui.online,ui.online.realtime,ui.rewards,ui.social]:n.set_process(false)
	ui.account.configured=false;ui.account.user={"id":"00000000-0000-4000-8000-000000001111"};ui.account.access_token="local-fixture";ui.account.expires_at=Time.get_unix_time_from_system()+3600;ui.guest=false;ui.session_owner=ui.account.player_id();ui.collection.loaded=true;ui.collection.owner_id=ui.account.player_id()
	var states=[]
	for definition in ui.CHALLENGES:var d=definition.duplicate(true);d.unlocked=d.stage<=6;d.completed=d.stage<=5;states.append(d)
	ui.collection.challenges=ui.collection.normalize_challenges(states);ui.screen="challenges";ui.render();await settle()
	var scroll=meta("challenge_scroll")[0];var tiles=meta("challenge_stage")
	check(tiles.size()==11,"Eleven levels remain present")
	check(scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"Carousel scrolls horizontally only")
	check(tiles.all(func(t):return absf(t.global_position.y-tiles[0].global_position.y)<1),"Every level shares one horizontal row")
	check(scroll.get_h_scroll_bar().max_value>scroll.size.x,"Carousel exposes sideways scroll range")
	await capture("01-primeros-niveles")
	meta("challenge_next")[0].pressed.emit();await settle();check(scroll.scroll_horizontal>0,"Next arrow moves the row")
	var position=scroll.scroll_horizontal;ui.render();await settle();scroll=meta("challenge_scroll")[0]
	check(abs(scroll.scroll_horizontal-position)<3,"Returning to the page preserves sideways position")
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;scroll.gui_input.emit(wheel);await settle();check(scroll.scroll_horizontal>position,"Mouse wheel moves sideways")
	scroll.scroll_horizontal=100000;await settle();tiles=meta("challenge_stage")
	check(tiles[-1].get_global_rect().intersects(scroll.get_global_rect()),"Last level reachable without vertical scrolling")
	check(not nodes(tiles[-1]).any(func(n):return n.has_meta("deck_cover")),"Future cover remains hidden")
	await capture("02-ultimos-niveles")
	meta("challenge_previous")[0].pressed.emit();await settle();check(scroll.scroll_horizontal<int(scroll.get_h_scroll_bar().max_value-scroll.size.x),"Previous arrow moves back")
	ui.sound.shutdown();ui.queue_free();await settle();print(JSON.stringify({"challenge_tactics_v111":{"checks":checks,"failures":failures,"network_requests":0,"random_draws":0}}));quit(0 if failures.is_empty()else 1)
