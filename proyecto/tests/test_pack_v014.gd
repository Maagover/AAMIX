extends "res://tests/test_pack_art_v013.gd"
## Opening hold, upright card motion and singular-only presentation lifecycle.
const Reveal = preload("res://pack_reveal.gd")

func singular_count():
	return ui.sound.recent.filter(func(cue): return cue.name == "singular").size()

func wait_animation(view):
	var deadline = Time.get_ticks_msec() + 4000
	while is_instance_valid(view) and view.animating and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not is_instance_valid(view) or not view.animating,"Presentation animation completes")

func sample_effect(code, index = 4, shown = false):
	var cards = ["0100","0104","0104","0120",code]
	if index == 3: cards = ["0100","0104","0104",code,"0120"]
	var sample = Reveal.new().configure(ui,cards,index,true,"sample-"+code,shown)
	var arrivals = []
	sample.singular_arrived.connect(func(id): arrivals.append(id))
	var before = singular_count()
	ui.add_child(sample)
	await process_frame
	var expected = index == 4 and not shown and code in Reveal.SINGULARS
	check(sample.current.has_meta("singular_highlight") == expected,"Shine applies only to the four named cards in position five: " + code)
	check(arrivals.size() == (1 if expected else 0),"Singular arrival signal matches its eligibility: " + code)
	check(singular_count() == before + (1 if expected else 0),"Singular audio matches its eligibility: " + code)
	check(sample.current.rotation == 0.0,"Highlighted or ordinary card remains upright")
	sample.rebuild()
	await settle()
	check(arrivals.size() == (1 if expected else 0) and singular_count() == before + (1 if expected else 0),"Local rebuild cannot repeat an arrival effect: " + code)
	sample.queue_free()
	await create_timer(.05).timeout

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.sound.muted = false
	ui.sound.effects_volume = .7
	ui.sound.apply_volumes()
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("pack-v014@fixture.invalid","Prueba",true)
	await ui.account.verify_code("123456")
	await wait_network()
	await ui.collection.redeem_code("AAMIXTC")
	ui.rewards.open_screen("packs")
	await ui.rewards.start_opening()
	await wait_network()
	var request_id = ui.rewards.opening_request
	await ui.rewards.start_opening()
	await wait_network()
	check(ui.rewards.opening_request == request_id and total_cards() == 5 and ui.collection.packs == 0,"Retry opens one server-awarded packet without duplicate cards")
	var view = find_meta(ui,"pack_reveal")
	var opening_id = ui.collection.pending_opening.opening_id
	var initial_position = view.packet.position
	check(view.packet_closed.get_global_rect() == view.packet_opened_art.get_global_rect(),"Both real wrapper images remain registered")
	check(not ui.sound.music_wanted and ui.sound.pack_suspense,"Music fades out during opening")
	await ui.sound.wait_for_pack_silence()
	await shot("v014-sobre-cerrado")
	var started_at = Time.get_ticks_msec()
	slide(view,200)
	check(ui.rewards.reveal_open and not view.sealed,"Committed opening survives cancellation before its animation ends")
	await create_timer(.07).timeout
	check(view.packet.position == initial_position and view.packet.rotation == 0.0,"Wrapper does not move or rotate")
	await shot("v014-sobre-transicion")
	await create_timer(.60).timeout
	check(view.animating and view.opening_stage == "opened" and view.packet.modulate.a > .99 and view.layers.modulate.a < .01,"Opened wrapper is still held after the old animation would finish")
	await shot("v014-sobre-abierto-mas-tiempo")
	await wait_animation(view)
	check(Time.get_ticks_msec()-started_at >= 1400,"Opening includes the additional full second")
	check(view.opening_stage == "cards" and view.current.rotation == 0.0,"First revealed card starts upright")
	check(singular_count() == 0,"Singular sound does not play when the wrapper opens")
	await shot("v014-sobre-carta-1")
	var before = JSON.stringify(ui.collection.last_reply)
	for index in range(4):
		slide(view,230 if index % 2 == 0 else -230)
		check(view.current.rotation == 0.0,"Card remains upright at drag release")
		await create_timer(.15).timeout
		check(view.current.rotation == 0.0,"Card remains upright while sliding away")
		await wait_animation(view)
		check(ui.rewards.reveal_index == index+1,"Sliding advances exactly one card")
		if index < 3: check(singular_count() == 0,"Earlier cards do not trigger the singular cue")
	check(view.revealed == 4 and view.current.get_meta("singular_highlight","") == "0119","Fifth Transmission card receives the singular shine")
	check(ui.rewards.singular_seen_openings.has(opening_id) and singular_count() == 1,"Arrival is recorded once for this opening")
	var sparkle = find_meta(view,"singular_sparkles")
	check(sparkle != null and sparkle.size == Vector2(296,402),"Sparkles are confined to one card")
	check(view.current.material is ShaderMaterial and view.current.material.shader.resource_path.ends_with("singular_shine.gdshader"),"Shine uses a procedural shader without altering the printed image")
	await create_timer(.10).timeout
	await shot("v014-quinta-singular-brillo")
	check(JSON.stringify(ui.collection.last_reply) == before and total_cards() == 5,"Presentation effects do not call the server or change inventory")
	await ui.collection.load_inventory()
	await settle()
	view = find_meta(ui,"pack_reveal")
	check(view.revealed == 4 and view.current.rotation == 0.0 and singular_count() == 1,"Refresh resumes the fifth card without replaying its shine or cue")
	ui.rewards.open_screen("missions")
	await wait_network()
	ui.rewards.open_screen("packs")
	await settle()
	view = find_meta(ui,"pack_reveal")
	check(view.revealed == 4 and singular_count() == 1,"Returning from another screen cannot repeat the singular reward")
	await shot("v014-quinta-retomada")
	slide(view,-230)
	await wait_animation(view)
	check(ui.rewards.reveal_index == 5 and find_text(ui,"¡Cinco cartas para tu colección!") != null,"Fifth card can be slid away to the existing summary")
	check(singular_count() == 1,"Summary does not repeat singular effects")
	await shot("v014-cinco-cartas")
	for code in Reveal.SINGULARS: await sample_effect(code)
	for code in ["0134","0128","0125","0131","0130"]: await sample_effect(code)
	await sample_effect("0119",3)
	await sample_effect("0119",4,true)
	print(JSON.stringify({"pack_v014_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
