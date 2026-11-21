extends SceneTree
var b
func _initialize():run.call_deferred()
func frames(n=8):
	for i in range(n):await process_frame
func run():
	root.size=Vector2i(480,900);root.content_scale_size=Vector2i(480,900)
	b=load("res://main.tscn").instantiate();root.add_child(b);b.mobile_layout=true;b.compact_layout=true;b.animations_enabled=false;b.automation_pause=true
	b.account.set_process(false);b.account.configured=false;b.rewards.set_process(false);b.online.set_process(false);b.online.realtime.set_process(false);b.social.set_process(false)
	await frames();b.game.new_game(42);b.game.active=b.human;b.game.actor=b.human;b.game.phase="main";b.game.turn=6
	for zone in b.game.ZONES:
		if zone!="deck":b.game.players[b.human][zone].clear();b.game.players[b.computer][zone].clear()
	for code in ["0100","01b","0100","0100","0118","0117","0113","0111"]:b.game.players[b.human].hand.append(b.game.spawn(code,b.human))
	for i in range(6):b.game.players[b.computer].hand.append(b.game.spawn("0100",b.computer))
	for owner in range(2):
		b.game.players[owner].resources.append(b.game.spawn("0100",owner));b.game.players[owner].paid.append(b.game.spawn("0100",owner))
	b.game.players[b.human].defense.append(b.game.spawn("01b",b.human))
	b.game.players[b.computer].defense.append(b.game.spawn("0119",b.computer));b.game.players[b.computer].attack.append(b.game.spawn("0108",b.computer))
	b.game.take_visual_events();b.presenting=false;b.started=true;b.guest=true;b.screen="table";b.render();await frames(25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/qa_reference_board.png")
	b.queue_free();await frames();quit()
