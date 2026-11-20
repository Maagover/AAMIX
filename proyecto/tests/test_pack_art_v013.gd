extends "res://tests/test_rewards_v011.gd"
## HTTP gift/open transaction plus visual stages of the supplied original art.

func slide(view, distance):
	var start = view.origin + Vector2(145,150)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	view._gui_input(press)
	var move = InputEventMouseMotion.new()
	move.position = start + Vector2(distance,0)
	move.relative = Vector2(distance,0)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	view._gui_input(move)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = move.position
	view._gui_input(release)

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("pack-art-v013@fixture.invalid","Prueba",true)
	await ui.account.verify_code("123456")
	await wait_network()
	ui.rewards.open_screen("gift_code")
	ui.rewards.code_text = "AAMIXTC"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(ui.collection.packs == 1 and total_cards() == 0, "Gift supplies one server-confirmed pack")
	check(find_meta(ui,"reward_icon") != null, "Pack gift celebration uses supplied closed artwork")
	await shot("v013-regalo-sobre-real")
	ui.rewards.open_screen("missions")
	await wait_network()
	check(find_meta(ui,"pack_art").get_meta("pack_source").ends_with("sobre_cerrado.png"), "Mission rewards show the supplied closed pack")
	await shot("v013-misiones-sobre-real")
	ui.rewards.open_screen("packs")
	await settle()
	check(find_meta(ui,"pack_art").get_meta("pack_source").ends_with("sobre_cerrado.png"), "Expansion cover shows the supplied closed pack")
	await shot("v013-lista-sobres-reales")
	await ui.rewards.start_opening()
	await wait_network()
	var request_id = ui.rewards.opening_request
	await ui.rewards.start_opening()
	await wait_network()
	check(ui.rewards.opening_request == request_id and total_cards() == 5 and ui.collection.packs == 0, "Opening retries keep the existing transaction and award five cards once")
	var view = find_meta(ui,"pack_reveal")
	check(view.sealed and view.packet_closed.texture is AtlasTexture and view.packet_opened_art.texture is AtlasTexture, "Reveal loads both registered real artwork layers")
	var position = view.packet.position
	var packet_size = view.packet.size
	check(view.packet_closed.get_global_rect() == view.packet_opened_art.get_global_rect(), "Closed and torn artwork occupy the same rectangle")
	await shot("v013-sobre-cerrado")
	var before = JSON.stringify(ui.collection.last_reply)
	slide(view,200)
	check(not view.sealed and view.animating and ui.rewards.reveal_open, "Mouse tear commits open presentation immediately")
	await create_timer(.07).timeout
	check(view.packet.position == position and view.packet.rotation == 0.0 and view.packet.size == packet_size, "Wrapper never flies, shifts or rotates during its transition")
	await shot("v013-sobre-transicion")
	var deadline = Time.get_ticks_msec() + 3000
	while view.opening_stage == "transition" and Time.get_ticks_msec() < deadline: await process_frame
	check(view.opening_stage == "opened" and view.packet_opened_art.modulate.a == 1.0, "Torn artwork appears before cards are revealed")
	await shot("v013-sobre-abierto")
	while view.animating and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(view.opening_stage == "cards" and view.revealed == 0 and view.current.visible, "Wrapper fades to reveal the first card")
	await shot("v013-sobre-carta-1")
	slide(view,-230)
	deadline = Time.get_ticks_msec() + 3000
	while view.animating and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(ui.rewards.reveal_index == 1 and view.revealed == 1, "Each card still slides individually")
	await shot("v013-sobre-carta-2")
	check(JSON.stringify(ui.collection.last_reply) == before and total_cards() == 5, "Visual gestures make no extra server transaction or card award")
	check(ui.sound.recent.any(func(cue): return cue.name == "sobre_abrir"), "Opening retains its mapped opening sound")
	print(JSON.stringify({"pack_art_v013_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
