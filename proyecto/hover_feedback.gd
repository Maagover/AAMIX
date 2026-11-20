extends RefCounted
## Visual cue only: never changes a rule, click action, drag payload or hidden information.
static func attach(node, amount = 1.04, animated = true):
	if node.has_meta("interactive_hover"): return node
	node.set_meta("interactive_hover", true)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state = {"tween":null}
	var update = func(active):
		if not is_instance_valid(node) or not node.is_inside_tree(): return
		if state.tween != null and state.tween.is_valid(): state.tween.kill()
		node.pivot_offset = node.size * 0.5
		var target = Vector2.ONE * (amount if active else 1.0)
		if not animated: node.scale = target; return
		state.tween = node.create_tween()
		state.tween.tween_property(node,"scale",target,0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	node.mouse_entered.connect(update.bind(true)); node.mouse_exited.connect(update.bind(false))
	node.focus_entered.connect(update.bind(true)); node.focus_exited.connect(update.bind(false))
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	node.tree_exiting.connect(func():
		if state.tween != null and state.tween.is_valid(): state.tween.kill()
	)
	return node
