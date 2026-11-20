extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	ui.collection.packs=1
	var center=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var body=VBoxContainer.new()
	body.custom_minimum_size.x=780
	center.add_child(body)
	ui.rewards.render_packs(body)
	for _i in range(8): await process_frame
	var tile=body.get_child(0)
	var ok=absf(tile.get_global_rect().get_center().x-ui.size.x*.5)<3
	print(JSON.stringify({"ui_v015_repaired_assertion":27,"checks":1,"failures":[] if ok else ["Pack tile center"],"network_requests":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await process_frame
	quit(0 if ok else 1)
