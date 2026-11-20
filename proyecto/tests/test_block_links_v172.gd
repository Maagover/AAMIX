extends SceneTree
const Game = preload("res://game.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok,message):
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle():
	for _i in range(8): await process_frame
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	var path = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(path)==OK: captures.append(path)
func add(g,p,code,zone):
	var uid = g.spawn(code,p); g.players[p][zone].append(uid); g.instances[uid].entered = 1; return uid
func fresh(lethal=false):
	var g = Game.new()
	for p in range(2):
		var player = {"name":"Prueba","deck_id":"fixture"}
		for zone in g.ZONES: player[zone] = []
		g.players.append(player)
		for _i in range(1 if p==1 and lethal else 35): add(g,p,"0100","deck")
		if p==1 and lethal:
			for _i in range(34): add(g,p,"0100","graveyard")
		for _i in range(3): add(g,p,"0100","resources")
	g.active = 0; g.actor = 0; g.turn = 5; g.phase = "main"
	var ids = [add(g,0,"0110","defense"),add(g,0,"0101","defense"),add(g,1,"0112","defense"),add(g,1,"0114","defense")]
	return {"game":g,"ids":ids}
func wait_animation():
	var deadline = Time.get_ticks_msec()+8000
	while (ui.presenting or ui.fx.busy) and Time.get_ticks_msec()<deadline: await process_frame
	check(not ui.presenting and not ui.fx.busy,"Presentation finishes within normal animation time")
	await settle()
func install(g,human=0):
	ui.presentation_generation += 1; ui.fx.cancel(false)
	ui.online.room = {}; ui.online.connected = false
	ui.game = g; ui.human = human; ui.computer = 1-human; ui.started = true; ui.guest = true
	ui.active_deck_id = "fixture"; ui.active_challenge_stage = 0; ui.winner_announced = false
	ui.presenting = false; ui.moving_uids.clear(); ui.visual_counts.clear(); ui.screen = "table"; ui.render()
func result_nodes(): return ui.find_children("*","TextureRect",true,false).filter(func(n):return n.has_meta("result_art"))
func run():
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.automation_pause = true; ui.animations_enabled = false
	ui.account.set_process(false); ui.account.configured = false; ui.account.refresh_token = ""
	ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false); ui.social.set_process(false)
	var sample = fresh(); var g = sample.game; var ids = sample.ids; install(g)
	ui.perform(g.declare_attack.bind([ids[0],ids[1]])); await wait_animation()
	ui.animations_enabled = true
	ui.perform(g.assign_block.bind(ids[0],ids[2])); await wait_animation()
	check(ui.fx.block_pairs=={ids[0]:ids[2]} and ui.fx.block_lines.size()==1,"First block has one persistent link")
	await create_timer(.7).timeout
	check(ui.fx.block_lines.size()==1 and ui.fx.block_lines[ids[0]].modulate.a==1,"Link outlasts old 0.44-second fade")
	ui.perform(g.assign_block.bind(ids[1],ids[3])); await wait_animation()
	check(ui.fx.block_lines.size()==2,"Both attacker/blocker pairs remain visible")
	for attacker in ui.fx.block_pairs:
		var line = ui.fx.block_lines[attacker]; var layout = ui.capture_layout()
		check(line.points[0].distance_to(layout.cards[ui.fx.block_pairs[attacker]].rect.get_center())<1 and line.points[1].distance_to(layout.cards[attacker].rect.get_center())<1,"Link joins the correct public card centers")
	await capture("01-dos-bloqueos")
	ui.render(); await settle()
	check(ui.fx.block_lines.size()==2,"Redrawing table preserves both links")
	ui.perform(g.assign_block.bind(ids[0],-1)); await wait_animation()
	check(ui.fx.block_lines.size()==1 and not ui.fx.block_lines.has(ids[0]),"Unassigning removes only its old link")
	ui.perform(g.assign_block.bind(ids[0],ids[2])); await wait_animation()
	ui.perform(g.finish_blocks); await wait_animation()
	check(g.phase=="events" and ui.fx.block_lines.size()==2,"Links persist into the event response phase")
	ui.perform(g.pass_priority); await wait_animation()
	check(ui.fx.block_lines.size()==2,"Passing first priority retains the pairings")
	ui.perform(g.pass_priority)
	await create_timer(.1).timeout
	check(ui.presenting and ui.fx.block_pairs.size()==2,"Final resolved state retains lines while combat animation is playing")
	await wait_animation()
	check(g.phase=="after_combat" and ui.fx.block_lines.is_empty() and ui.fx.block_line_root==null,"All links clear when combat has finished")
	check(ui.fx.root==null and ui.fx.ghosts.is_empty(),"No transient textures remain after nonlethal resolution")
	check(g.invariant_errors().is_empty(),"Presentation preserves nonlethal game invariants")
	await capture("02-combate-resuelto")
	# Lethal blocked combat skips end_combat in the engine: reproduce stale roles.
	sample = fresh(true); g = sample.game; ids = sample.ids
	g.declare_attack([ids[0]]); g.assign_block(ids[0],ids[2]); g.take_visual_events(); install(g); await settle()
	check(ui.fx.block_lines.size()==1,"Lethal fixture starts with its visible blocking pair")
	g.finish_blocks(); g.pass_priority(); g.take_visual_events()
	Engine.max_fps = 15
	ui.perform(g.pass_priority); await wait_animation()
	check(g.winner==0 and g.combat_roles.get(ids[2])=="block","Real lethal block reproduces the engine's retained final role")
	check(result_nodes().size()==1 and result_nodes()[0].get_meta("result_art")=="victory","Victory appears after lethal blocked play")
	check(ui.fx.root==null and ui.fx.ghosts.is_empty() and ui.fx.block_lines.is_empty(),"Victory has no blocking ghost or connection")
	check(not ui.block_marker_visible(ids[2]),"Final blocker outline/annotation is suppressed despite retained engine role")
	await capture("03-victoria-sin-textura")
	Engine.max_fps = 0
	# Guest receives the same completed play through the existing redacted protocol.
	sample = fresh(true); g = sample.game; ids = sample.ids
	g.declare_attack([ids[0]]); g.assign_block(ids[0],ids[2]); g.finish_blocks(); g.pass_priority(); g.take_visual_events()
	Snapshot.restore(ui.game,Snapshot.guest_view(g)); ui.human=1; ui.computer=0; ui.active_deck_id="online"
	ui.winner_announced=false; ui.online.slot=1; ui.online.connected=true; ui.online.room={"status":"playing","state":Snapshot.guest_view(g)}; ui.screen="table"; ui.render(); await settle()
	check(ui.online.in_match(),"Guest fixture enters the multiplayer result controls")
	check(ui.fx.block_lines.size()==1,"Guest view displays the same public blocker relationship")
	var before = Snapshot.capture(g); var layout = ui.capture_layout(); g.pass_priority()
	var packet = Snapshot.presentation(g,before,1)
	Snapshot.restore(ui.game,Snapshot.guest_view(g)); ui.accept_online_state(1,packet,layout,{"status":"finished","winner":0})
	await wait_animation()
	check(result_nodes().size()==1 and result_nodes()[0].get_meta("result_art")=="defeat","Guest defeat uses the existing online presentation path")
	check(ui.fx.root==null and ui.fx.block_lines.is_empty() and not ui.block_marker_visible(ids[2]),"Guest defeat clears all final blocking indicators")
	await capture("04-derrota-invitado-sin-textura")
	# Defensive cleanup is immediate even if a result interrupts an active pulse.
	ui.fx.begin(ui,[],ui.capture_layout()); var ghost=ui.fx.make_ghost(ids[2],false,Rect2(100,100,88,120))
	ui.show_winner()
	check(ui.fx.root==null and not ghost.is_visible_in_tree() and not ui.fx.busy,"Result synchronously hides/detaches a stray blocker texture before the frame ends")
	ui.go_home(); await settle()
	check(ui.fx.block_line_root==null and ui.fx.block_pairs.is_empty(),"Returning home removes every link")
	sample = fresh(); install(sample.game); ui.animations_enabled=false; ids=sample.ids; g=sample.game
	g.declare_attack([ids[0]]); g.assign_block(ids[0],ids[2]); g.take_visual_events(); ui.render(); await settle()
	check(ui.fx.block_lines.size()==1,"Pairing remains readable when animations are disabled")
	ui.fx.cancel(false)
	check(ui.fx.block_line_root==null and ui.fx.block_pairs.is_empty(),"Explicit cancellation clears links immediately")
	ui.sound.shutdown(); ui.queue_free(); await settle()
	print(JSON.stringify({"block_links_v172":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0,"random_simulations":0,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)
