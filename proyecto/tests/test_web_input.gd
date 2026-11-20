extends SceneTree
var board
var checks = 0
var failures = []

func _initialize(): run.call_deferred()
func check(value, message):
	checks += 1
	if not value: failures.append(message); push_error(message)
func frames(count = 8):
	for i in range(count): await process_frame
func surface(uid, zone, owner = 0):
	for node in board.targets:
		if is_instance_valid(node) and node.zone == zone and node.card_owner == owner and (uid == -1 or node.uid == uid): return node
	return null
func run():
	board = load("res://main.tscn").instantiate()
	root.add_child(board)
	board.animations_enabled = false
	board.automation_pause = true
	board.account.set_process(false)
	board.account.configured = false
	board.rewards.set_process(false)
	board.online.set_process(false)
	board.online.realtime.set_process(false)
	board.social.set_process(false)
	board.guest = true
	board.tutorial.start()
	board.tutorial.begin()
	await frames()
	var resource = board.tutorial.refs.resource
	board.tutorial.active = false
	board.render()
	await frames()
	var source = surface(resource, "hand")
	check(source != null, "A resource is visible in the real hand")
	check(board.tap_surface(source), "A tap selects a playable card")
	check(board.tap_selection.get("uid", -1) == resource, "Selection retains the card UID")
	check(board.game.location(resource).zone == "hand", "Selection alone does not play the card")
	check(board.tap_surface(source), "A second tap on the same card cancels")
	check(board.tap_selection.is_empty(), "Cancellation clears selection")
	check(board.game.location(resource).zone == "hand", "Cancellation leaves the card in hand")
	board.tap_surface(source)
	check(not board.tap_surface(surface(-1, "resources", 1)), "Cannot play a resource into the opponent's resources")
	check(board.game.location(resource).zone == "hand", "Invalid destination does not change state")
	check(board.tap_surface(surface(-1, "resources")), "A destination tap plays the resource through existing rules")
	await frames()
	check(board.game.location(resource).zone == "resources", "The played resource reaches its normal zone")
	check(board.tap_selection.is_empty(), "A completed action clears selection")
	var uid = board.game.players[0].resources.back()
	check(board.tap_surface(surface(uid, "resources")), "Can select an available resource for payment")
	check(board.tap_surface(surface(-1, "paid")), "Can move the selected resource to payments")
	await frames()
	check(uid in board.game.reserved[0], "The normal engine records the payment reservation")
	check(board.tap_surface(surface(uid, "paid")), "Can select an unspent payment")
	check(board.tap_surface(surface(-1, "resources")), "Can refund the unspent payment")
	await frames()
	check(uid in board.game.players[0].resources and uid not in board.game.reserved[0], "Refund uses normal resource rules")
	board.tap_surface(surface(uid, "resources"))
	board.render()
	await frames()
	check(board.tap_selection.is_empty(), "A state redraw cannot reuse a stale selection")
	board.game.actor = 1
	check(not board.tap_surface(surface(uid, "resources")), "Cannot act while the other player has priority")
	board.game.actor = 0
	board.compact_layout = true
	root.content_scale_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	board.render()
	await frames(12)
	check(board.action_panel.get_global_rect().end.y <= board.get_viewport_rect().size.y, "Compact action panel fits the web viewport: %s / %s" % [board.action_panel.get_global_rect().end.y, board.get_viewport_rect().size.y])
	for control in board.interface_nodes(board.action_panel):
		if control is Button and control.visible:
			check(control.get_global_rect().end.y <= board.get_viewport_rect().size.y, "Compact action button remains visible: " + control.text)
	board.screen = "home"
	check(not board.tap_surface(surface(uid, "resources")), "Card input is limited to the table")
	check(not board.account.remember_available(), "Web-development engine has no Windows session helper")
	board.queue_free()
	await frames()
	print(JSON.stringify({"web_input": {"checks": checks, "failures": failures, "remote_writes": 0}}))
	quit(0 if failures.is_empty() else 1)
