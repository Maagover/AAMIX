extends SceneTree
const Pack=preload("res://pack_reveal.gd")
var ui
func _initialize(): run.call_deferred()
func badges(node):
	var count=1 if node.has_meta("new_card_badge") else 0
	for child in node.get_children(): count+=badges(child)
	return count
func run():
	ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.animations_enabled=false
	for _i in range(8): await process_frame
	var p=Pack.new().configure(ui,["0100","0101","0101","0104","0105"],0,true,"fixture",false,"tc",[1.0,3.0,4.0])
	p.size=Vector2(1080,600);ui.add_child(p)
	for _i in range(8): await process_frame
	var failures=[]
	if badges(p)!=3: failures.append("New markers follow server JSON indices")
	await p.slide_card()
	for _i in range(8): await process_frame
	if badges(p.current)!=1 or p.current.get_child(0).size!=Vector2(24,24): failures.append("New card has a small corner star")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--screenshot="))
	print(JSON.stringify({"badge_repair_v018_checks":2,"failures":failures,"repeated_affected_cases_only":true}))
	ui.sound.shutdown();ui.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
