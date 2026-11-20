extends SceneTree
const Game=preload("res://game.gd")
const Snapshot=preload("res://multiplayer_snapshot.gd")
var ui
var failures=[]
func _initialize():run.call_deferred()
func settle():
	for _i in range(8):await process_frame
func finish_animation():
	var deadline=Time.get_ticks_msec()+5000
	while (ui.presenting or ui.fx.busy) and Time.get_ticks_msec()<deadline:await process_frame
func apply(g,before):
	var packet=Snapshot.presentation(g,before,1)
	var layout=ui.capture_layout()
	Snapshot.restore(ui.game,Snapshot.guest_view(g))
	ui.accept_online_state(1,packet,layout)
	await finish_animation()
func run():
	ui=load("res://main.tscn").instantiate();root.add_child(ui);await settle()
	ui.online.set_process(false);ui.rewards.set_process(false)
	var g=Game.new();g.new_game(18);g.take_visual_events()
	Snapshot.restore(ui.game,Snapshot.guest_view(g))
	ui.human=1;ui.computer=0;ui.active_deck_id="online";ui.started=true;ui.screen="table";ui.automation_pause=true
	ui.online.slot=1;ui.online.connected=true;ui.online.room={"status":"playing","state":Snapshot.guest_view(g)}
	ui.render();await settle()
	var before=Snapshot.capture(g)
	var uid=g.players[0].deck[0]
	g.mill(0,1,"Prueba visual")
	await apply(g,before)
	if not ui.fx.trace.any(func(e):return e.kind=="move" and e.to=="graveyard" and e.face_visible) or ui.presenting:failures.append("Guest graveyard animation did not finish with public face")
	g.take_visual_events();before=Snapshot.capture(g);g.leave(uid,"deck",true)
	await apply(g,before)
	if not ui.fx.trace.any(func(e):return e.kind=="move" and e.to=="deck") or not ui.fx.trace.any(func(e):return e.kind=="shuffle") or ui.presenting:failures.append("Recycle and shuffle animations missing")
	print(JSON.stringify({"online_effects_v018_checks":2,"failures":failures,"network_requests":0}))
	ui.sound.shutdown();ui.queue_free();await settle();quit(0 if failures.is_empty() else 1)
