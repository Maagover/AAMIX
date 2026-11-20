extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	await create_timer(.2).timeout
	print("SMOKE015_READY")
	ui.sound.shutdown()
	ui.queue_free()
	await process_frame
	quit()
