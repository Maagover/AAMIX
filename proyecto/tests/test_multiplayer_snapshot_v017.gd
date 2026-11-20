extends SceneTree
const Game = preload("res://game.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
const Main = preload("res://main.gd")
var checks = 0
var failures = []

func check(condition,caption):
	checks += 1
	if not condition: failures.append(caption)

func _initialize():
	call_deferred("run")

func run():
	var game = Game.new()
	game.manual_payment = [true,true]
	game.new_game(17017)
	game.take_visual_events()
	var full = Snapshot.capture(game)
	var restored = Game.new()
	check(Snapshot.restore(restored,JSON.parse_string(JSON.stringify(full))),"JSON snapshot restores")
	check(restored.players == game.players and restored.instances == game.instances,"UID dictionaries restore with integer keys")
	check(restored.rng.state == game.rng.state and restored.rng.seed == game.rng.seed,"64-bit RNG bits preserved")
	check(restored.invariant_errors().is_empty(),"full recovered state satisfies engine invariant")
	check(restored.rng.randi() == game.rng.randi(),"recovery next random draw identical")
	var guest = Snapshot.guest_view(game)
	check(guest.players[1].hand == game.players[1].hand,"guest sees own hand")
	var private_absent = true
	for uid in game.players[0].hand + game.players[0].deck + game.players[1].deck:
		if guest.instances.has(uid): private_absent = false
	check(private_absent,"opponent hand and both deck identities absent")
	check(guest.players[0].deck.size() == game.players[0].deck.size() and guest.players[0].hand.size() == game.players[0].hand.size(),"hidden zone counts preserved")
	check(guest.players[0].deck.all(func(u): return u < 0) and guest.players[1].deck.all(func(u): return u < 0) and guest.players[0].hand.all(func(u):return u < 0),"hidden order uses unlinkable placeholders")
	check(guest.queue.is_empty() and guest.log_lines.is_empty() and guest.rng_state == "0" and guest.error.is_empty(),"no private queue logs errors or RNG")
	game.pending = {"kind":"reorder","player":0,"options":game.players[0].deck.slice(0,3),"title":"Private choice","min":3,"max":3,"optional":false}
	guest = Snapshot.guest_view(game)
	check(guest.pending.kind == "waiting" and guest.pending.options.is_empty() and guest.pending.title != "Private choice","other player's pending options hidden")
	game.pending = {"kind":"reorder","player":1,"options":game.players[1].deck.slice(0,3),"title":"Own choice","min":3,"max":3,"optional":false}
	game.actor = 1
	guest = Snapshot.guest_view(game)
	check(guest.pending.options == game.pending.options and game.pending.options.all(func(u):return guest.instances.has(u)),"legal own search choices visible")
	game.pending = {}
	game.actor = 0
	check(not Snapshot.dispatch(game,1,"keep_hand",[]),"wrong actor rejected")
	check(not Snapshot.dispatch(game,0,"lose",[1]) and not Snapshot.dispatch(game,0,"request_play",["bad",-1]),"unknown methods and invalid types rejected")
	check(Snapshot.dispatch(game,0,"keep_hand",[]) and game.actor == 1 and Snapshot.dispatch(game,1,"keep_hand",[]),"both humans prepare using same rules")
	check(not Snapshot.dispatch(game,game.actor,"request_play",[game.players[1-game.actor].hand[0],-1]),"opponent card cannot be played")
	var ui = Main.new()
	root.add_child(ui)
	await process_frame
	check(ui.online != null and ui.online_ui != null and ui.screen == "intro","online modules integrated without replacing offline intro")
	ui.queue_free()
	await process_frame
	print(JSON.stringify({"multiplayer_snapshot_v017":{"checks":checks,"failures":failures}}))
	quit(0 if failures.is_empty() else 1)
