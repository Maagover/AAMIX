extends SceneTree
var ui
var output=""
var failures=[]
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): output=arg.trim_prefix("--captures=")
	run.call_deferred()
func capture(name):
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	if image.is_empty() or image.save_png(output.path_join(name+".png"))!=OK: failures.append(name+" capture failed")
func run():
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause=true
	ui.animations_enabled=false
	ui.online.set_process(false)
	ui.online.realtime.set_process(false)
	await create_timer(3).timeout
	if ProjectSettings.get_setting("application/config/version","")!="1.0": failures.append("Wrong release version")
	if not ui.account.remember_available(): failures.append("Missing Windows DPAPI helper")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await capture("Intro_v1.0")
		ui.guest=true
		ui.screen="home"
		ui.render()
		await capture("Inicio_v1.0")
		ui.screen="account"
		ui.render()
		await capture("Cuenta_v1.0")
	print(JSON.stringify({"portable_v100_native_start":true,"version":"1.0","failures":failures}))
	ui.online.clear()
	ui.sound.shutdown()
	ui.queue_free()
	for _i in range(5): await process_frame
	quit(0 if failures.is_empty() else 1)
