extends SceneTree
const Main = preload("res://main.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")

func _initialize(): call_deferred("run")

func run():
	var ui = Main.new()
	root.add_child(ui)
	await process_frame
	ui.active_deck_id = "online"
	ui.started = true
	ui.screen = "table"
	ui.online.room = {"room_id":"cancelled-fixture","status":"playing","revision":2,"slot":0,"state":Snapshot.capture(ui.game)}
	ui.online.revision = 2
	ui.online.pending_command = {"p_expected_revision":2}
	ui.online.staged_commit = {"p_expected_revision":2}
	ui.online.receive({"room_id":"cancelled-fixture","status":"cancelled","revision":3,"slot":0,"winner":-1,"players":[],"state":Snapshot.capture(ui.game)})
	var valid = ui.screen == "multiplayer" and not ui.started and ui.active_deck_id.is_empty() and not ui.online.in_match() and ui.online.pending_command.is_empty() and ui.online.staged_commit.is_empty() and not ui.perform(ui.game.keep_hand)
	var result = {"multiplayer_cancelled_v017":{"checks":1,"failures":[] if valid else ["cancelled snapshot remained playable"]}}
	ui.queue_free()
	await process_frame
	print(JSON.stringify(result))
	quit(0 if valid else 1)
