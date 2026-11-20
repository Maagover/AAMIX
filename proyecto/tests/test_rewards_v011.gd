extends SceneTree
## Local HTTP contract and layout regression; no production account is used.
var ui
var checks = 0
var failures = []
var fixture_url = ""
var screenshot_path = ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--auth-test-url="): fixture_url = arg.trim_prefix("--auth-test-url=")
		if arg.begins_with("--screenshots="): screenshot_path = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func find_text(node, value):
	if (node is Label or node is Button) and node.text == value: return node
	for child in node.get_children():
		var found = find_text(child,value)
		if found != null: return found
	return null

func find_meta(node, key):
	if node.has_meta(key): return node
	for child in node.get_children():
		var found = find_meta(child,key)
		if found != null: return found
	return null

func find_field(node):
	if node is LineEdit: return node
	for child in node.get_children():
		var found = find_field(child)
		if found != null: return found
	return null

func settle():
	for _i in range(6): await process_frame

func wait_network():
	var deadline = Time.get_ticks_msec() + 22000
	while (ui.collection.busy or ui.rewards.pumping) and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not ui.collection.busy, "Local contract request completes")

func total_cards():
	return ui.collection.cards.values().reduce(func(total,n): return total+int(n),0)

func shot(name):
	if screenshot_path.is_empty() or not screenshot_path.is_absolute_path() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshot_path)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot_path.path_join(name + ".png"))

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("rewards-v011@fixture.invalid","Prueba",true)
	await ui.account.verify_code("123456")
	await wait_network()
	await ui.collection.claim("kajido")
	ui.rewards.open_screen("gift_code")
	await settle()
	check(find_text(ui,"Ingresa tu código de regalo") != null, "Code prompt uses requested wording")
	check(find_text(ui,"Canjear").disabled, "An empty code cannot be redeemed")
	check(find_text(ui,"Actualizar") == null, "Code screen has only its required action and navigation")
	check(find_text(ui,"Un regalo para tu colección") == null and find_text(ui,"Cada código se canjea una sola vez por cuenta.") == null, "Extra code explanations removed")
	check(find_text(ui,"Inicio") != null and find_text(ui,"Salir") == null, "Code navigation preserves home-only Exit")
	await shot("v011-codigo")
	var field = find_field(ui)
	field.text = "INVALIDO"
	field.text_changed.emit(field.text)
	check(not find_text(ui,"Canjear").disabled, "Typing enables Canjear")
	await ui.rewards.redeem()
	await wait_network()
	check(total_cards() == 40 and ui.collection.status.contains("no es válido"), "Invalid code retains visible feedback and no award")
	var promos = [{"code":"P3RI","card":"01a","quantity":3},{"code":"B1G0T3S","card":"01b","quantity":3},{"code":"SI2TYA","card":"01c","quantity":1},{"code":"CHANCHULINES","card":"01d","quantity":1},{"code":"TORNEOAAMIX1","card":"01e","quantity":1}]
	for promo in promos:
		ui.rewards.code_text = " " + promo.code.to_lower() + " "
		ui.render()
		var before = int(ui.collection.cards.get(promo.card,0))
		await ui.rewards.redeem()
		await wait_network()
		var name = ui.game.catalog[promo.card].nombre
		check(int(ui.collection.cards.get(promo.card,0)) == before + promo.quantity, "Exact promotional quantity: " + promo.code)
		check(ui.collection.last_reply.get("redeemed_code") == promo.code and ui.collection.last_reply.get("reward_deck_id") == null, "Promotional reply identifies code and card reward: " + promo.code)
		check(find_text(ui,"¡Regalo recibido!") != null and find_text(ui,"%d × %s\nEn Mis Cartas." % [promo.quantity,name]) != null, "Success names the actual rewarded card: " + promo.code)
		check(ui.rewards.code_text.is_empty(), "Successful code field clears: " + promo.code)
		check(find_text(ui,"Tu Mazo Maagover está en Mis Mazos. Sus 40 cartas están en tu colección.") == null, "Promotional success has no unrelated deck message")
		await shot("v011-regalo-" + promo.card)
		ui.rewards.code_text = promo.code
		ui.render()
		await ui.rewards.redeem()
		await wait_network()
		check(int(ui.collection.cards.get(promo.card,0)) == before + promo.quantity and bool(ui.collection.last_reply.get("already_redeemed")), "Code replay is idempotent: " + promo.code)
		check(find_text(ui,"Regalo ya obtenido") != null, "Repeated code reports existing reward: " + promo.code)
	check(total_cards() == 49, "The five codes add exactly nine promotional cards")
	ui.rewards.open_screen("missions")
	await wait_network()
	var mission_row = find_meta(ui,"mission_row")
	var progress = find_meta(ui,"mission_progress")
	check(mission_row != null and mission_row.get_global_rect().position.x < 60, "Missions use a left-aligned list")
	check(not find_meta(ui,"mission_completion").button_pressed and progress.text == "0 / 1", "Mission completion state and progress start pending")
	check(progress.get_global_rect().position.x > mission_row.get_global_rect().get_center().x, "Mission progress is at the right")
	check(find_text(ui,"Recompensa: 1 sobre") != null and find_text(ui,"Termina una partida contra el computador. Puedes ganar o perder.") == null, "Mission shows reward below title without extra explanation")
	check(find_text(ui,"Mis sobres · 0") == null and find_text(ui,"Reclamar sobre").disabled, "Mission has no pack shortcut and protects incomplete rewards")
	await shot("v011-mision-pendiente")
	await ui.collection.begin_match(ui.collection.request_id(),"kajido")
	var receipt_id = ui.collection.last_reply.match_id
	await ui.collection.finish_match(receipt_id,true)
	await settle()
	check(find_meta(ui,"mission_completion").button_pressed and not find_text(ui,"Reclamar sobre").disabled, "Completed mission can be claimed")
	await shot("v011-mision-completa")
	await ui.rewards.claim_mission()
	await wait_network()
	ui.rewards.open_screen("packs")
	await settle()
	var pack_row = find_meta(ui,"pack_expansion")
	check(pack_row != null and pack_row.get_global_rect().position.x < 60, "Packs use a left-aligned expansion list")
	check(find_text(ui,"Transmisión Caída") != null and find_text(ui,"Disponibles: 1") != null, "Only current expansion and available count are shown")
	check(find_text(ui,"Ir a Misiones") == null and find_text(ui,"1 Recurso, 3 normales y una normal o Especial.\nSin cartas promocionales.") == null, "Pack explanations and mission shortcut removed")
	check(not find_text(ui,"Abrir un sobre").disabled, "Available expansion remains openable")
	await shot("v011-sobres")
	await ui.rewards.start_opening()
	await wait_network()
	check(ui.collection.pending_opening == null and ui.collection.packs == 1, "Uncertain opening response remains retryable")
	await ui.rewards.start_opening()
	await wait_network()
	check(find_meta(ui,"pack_reveal") != null and ui.collection.pending_opening.cards.size() == 5, "Pending packet preserves centered interactive reveal")
	await shot("v011-sobre-pendiente")
	print(JSON.stringify({"rewards_v011_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
