extends SceneTree
var ui
var output = OS.get_user_data_dir().path_join("capturas")

func _initialize(): run.call_deferred()

func screenshot(name):
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(output.path_join(name + ".png"))

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): output = arg.trim_prefix("--screenshots=")
	DirAccess.make_dir_recursive_absolute(output)
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	await process_frame
	await screenshot("01-inicio")
	ui.open_single()
	await screenshot("02-mazos")
	ui.fx.speed = 0.3
	ui.start_match(0)
	ui.automation_pause = true
	await create_timer(0.25).timeout
	await screenshot("03-reparto")
	while ui.presenting or ui.fx.busy: await process_frame
	await screenshot("04-mesa")
	ui.open_card_detail(ui.game.players[0].hand[0])
	await screenshot("05-detalle")
	ui.close_overlay(ui.overlay_shades.back())
	ui.show_log()
	await screenshot("06-registro")
	print("Capturas de interfaz listas")
	ui.sound.shutdown()
	await create_timer(0.10).timeout
	ui.queue_free()
	await process_frame
	quit()
