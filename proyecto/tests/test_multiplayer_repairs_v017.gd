extends SceneTree
const Game = preload("res://game.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
const Main = preload("res://main.gd")
var failures = []

func _initialize(): call_deferred("run")

func run():
	var game = Game.new()
	game.new_game(17018)
	game.payment_request = {"uid":game.players[0].hand[0],"player":0,"target":-1,"cost":1}
	var guest = Snapshot.guest_view(game)
	if not guest.payment_request.is_empty() or guest.instances.has(game.payment_request.uid): failures.append("host payment privacy")
	var ui = Main.new()
	root.add_child(ui)
	await process_frame
	ui.online.receive({"room_id":null})
	if not ui.online.room.is_empty() or ui.online.has_room_id({"room_id":null}): failures.append("null active room")
	var recovered = true
	for error in ["AAMIX_STALE_REVISION","AAMIX_ROOM_EXPIRED","AAMIX_ROOM_NOT_PLAYING","AAMIX_UNKNOWN_COMMAND"]:
		ui.online.staged_commit = {"request":true}
		ui.online.pending_command = {"request":true}
		ui.online.revision = 3
		ui.online.last_error = error
		if not ui.online.recover_commit_failure() or not ui.online.staged_commit.is_empty() or not ui.online.pending_command.is_empty() or ui.online.revision != -1: recovered = false
	if not recovered: failures.append("terminal commit recovery")
	ui.queue_free()
	await process_frame
	print(JSON.stringify({"multiplayer_repairs_v017":{"checks":3,"failures":failures}}))
	quit(0 if failures.is_empty() else 1)
