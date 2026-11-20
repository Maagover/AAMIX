extends RefCounted
## Screen and dialog entry only. Card/table rebuilds do not restart these tweens.
var active = {}

func cancel_all():
	for item in active.values():
		if is_instance_valid(item.node):
			item.node.scale = Vector2.ONE
			item.node.modulate.a = 1.0
		if is_instance_valid(item.tween): item.tween.kill()
	active.clear()

func enter(node, enabled):
	if not is_instance_valid(node) or node.has_meta("interface_entered"): return
	node.set_meta("interface_entered", true)
	if not enabled: return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 0.965
	node.modulate.a = 0.0
	var tween = node.create_tween()
	active[node.get_instance_id()] = {"node":node,"tween":tween}
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.16)
	tween.tween_property(node, "scale", Vector2.ONE * 1.012, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(node, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var key = node.get_instance_id()
	tween.finished.connect(func(): active.erase(key))
	node.tree_exiting.connect(func():
		if active.has(key):
			if tween.is_valid(): tween.kill()
			active.erase(key)
	, CONNECT_ONE_SHOT)
