extends SceneTree
const Game = preload("res://game.gd")
const AI = preload("res://ai.gd")

func _initialize(): run.call_deferred()

func run():
	var ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	ui.animations_enabled = false
	ui.start_match(0)
	ui.automation_pause = true
	await process_frame
	await process_frame
	await process_frame
	var ai = AI.new()
	var chosen
	var score = -1
	for seed_value in range(20):
		var g = Game.new()
		g.new_game(seed_value)
		for i in range(700):
			if g.winner != -1 or g.turn > 12: break
			if g.active == 0 and g.actor == 0 and g.phase == "main" and g.pending.is_empty() and g.turn >= 5:
				var current = mini(g.field(0).size(), 4) * 4 + mini(g.field(1).size(), 4) * 4
				for uid in g.field(0) + g.field(1):
					if g.instances[uid].object != -1: current += 4
				if g.domain_uid != -1: current += 3
				if current > score:
					score = current
					chosen = g
					break
			if not ai.step(g, g.actor): break
	ui.game = chosen
	ui.game.take_visual_events()
	ui.game.manual_payment = [true, false]
	ui.render()
	for uid in ui.game.field(0):
		if ui.game.instances[uid].object != -1:
			ui.show_detail(uid)
			break
	await process_frame
	await process_frame
	var bounds = get_root().get_visible_rect()
	var overflow = []
	for node in ui.targets:
		if node.zone == "inspection" or node.zone == "choice": continue
		var rect = node.get_global_rect()
		if rect.end.y > bounds.end.y + 1: overflow.append(node.zone)
	print(JSON.stringify({"layout_overflow":overflow,"turn":ui.game.turn,"field_human":ui.game.field(0).size(),"field_bot":ui.game.field(1).size()}))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(arg.trim_prefix("--screenshot="))
	ui.sound.shutdown()
	await create_timer(0.1).timeout
	ui.queue_free()
	await process_frame
	quit(0 if overflow.is_empty() else 1)
