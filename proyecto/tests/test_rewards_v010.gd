extends "res://tests/test_v05.gd"
var fixture_url = ""

func wait_network():
	var end = Time.get_ticks_msec()+25000
	while (ui.collection.busy or ui.rewards.pumping) and Time.get_ticks_msec()<end: await process_frame
	await settle()
	check(not ui.collection.busy,"Request completes")

func total_cards():
	return ui.collection.cards.values().reduce(func(total,n): return total+int(n),0)

func screenshot010(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots=") and DisplayServer.get_name() != "headless":
			var folder = arg.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(folder.path_join(name+".png"))

func slide_pack(view, distance):
	await settle()
	var a = view.get_global_rect().position + view.origin + Vector2(145,150)
	var b = a + Vector2(distance,0)
	move_mouse(a,Vector2.ZERO)
	await process_frame
	mouse_button(a,true)
	await process_frame
	var previous = a
	for i in range(1,9):
		var point = a.lerp(b,float(i)/8.0)
		move_mouse(point,point-previous,MOUSE_BUTTON_MASK_LEFT)
		previous = point
		await process_frame
	mouse_button(b,false)
	await create_timer(.6).timeout
	await settle()

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--auth-test-url="): fixture_url=arg.trim_prefix("--auth-test-url=")
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	await settle()
	check(find_button(ui,"Salir") == null,"No exit on access")
	var a = ui.account
	a.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await a.request_code("rewards-a@fixture.invalid","Prueba",true)
	await a.verify_code("123456")
	await wait_network()
	check(ui.collection.loaded,"Inventory contract connected")
	await ui.collection.claim("kajido")
	ui.go_home()
	await settle()
	check(find_button(ui,"Código de regalo") != null and find_button(ui,"Misiones") != null,"Home side reward buttons")
	check(find_button(ui,"Salir") != null,"Exit only on home")
	await screenshot010("01-inicio-cuenta")
	ui.open_account()
	await settle()
	check(find_button(ui,"Salir") == null,"No exit on account")
	await click(find_button(ui,"Elegir foto de perfil"))
	await settle()
	var portrait = null
	for node in ui.profiles.choices.values():
		if node.get_meta("avatar_choice") == "0108": portrait=node
	await click(portrait)
	await click(find_button(ui,"Guardar foto"))
	await wait_network()
	check(ui.modal_open and ui.collection.profile.get("avatar_code") == null,"Avatar failed request remains retryable")
	await click(find_button(ui,"Guardar foto"))
	await wait_network()
	check(ui.collection.profile.avatar_code == "0108" and not ui.modal_open,"Avatar saved through service")
	await screenshot010("02-mi-cuenta")
	ui.go_home()
	await click(find_button(ui,"Código de regalo"))
	await settle()
	var field = null
	for n in find_nodes(ui,"LineEdit"): field=n
	field.text="invalido"
	field.text_changed.emit(field.text)
	check(not find_button(ui,"Canjear").disabled,"Typing enables redeem button")
	await click(find_button(ui,"Canjear"))
	await wait_network()
	check(total_cards()==40 and ui.collection.status.contains("no es válido"),"Invalid code changes no inventory")
	ui.rewards.code_text=" m4z0m44g0 "
	ui.render()
	await click(find_button(ui,"Canjear"))
	await wait_network()
	check(total_cards()==40,"Uncertain redeem response creates no local fake cards")
	await click(find_button(ui,"Canjear"))
	await wait_network()
	check(total_cards()==80 and ui.collection.decks.size()==2,"Redeem retry grants one exact forty card deck")
	check(ui.owned_deck("maago").nombre=="Mazo Maagover","Historic Maagover saved as acquired deck")
	ui.go_home()
	ui.open_cards()
	ui.select_cards_tab("decks")
	await settle()
	check(find_button(ui,"Jugar con Mazo Maagover") == null,"Collection deck lists are for inspection")
	await screenshot010("03-mis-mazos")
	ui.go_home()
	ui.show_start()
	await settle()
	check(find_button(ui,"Mazo Maagover") != null,"Reward Maagover can be played from the deck selector")
	await click(find_button(ui,"Mazo Maagover"))
	ui.automation_pause = true
	var deadline=Time.get_ticks_msec()+8000
	while not ui.rewards.active_receipt.get("begun",false) and Time.get_ticks_msec()<deadline: await process_frame
	check(ui.game.players[ui.human].deck_id=="maago" and ui.game.invariant_errors().is_empty(),"Maagover starts with valid eighty cards")
	check(ui.rewards.active_receipt.get("match_id","") != ui.rewards.active_receipt.request_id,"Server match ID is distinct from retry UUID")
	ui.game.turn=5
	ui.game.lose(ui.computer)
	ui.go_home()
	deadline=Time.get_ticks_msec()+8000
	while not ui.rewards.active_receipt.get("reported",false) and Time.get_ticks_msec()<deadline: await process_frame
	check(ui.rewards.active_receipt.get("reported",false) and ui.collection.mission.progress==1,"Completed match reports actual server receipt ID")
	check(ui.screen=="home","Completion recorded even when leaving table before result animation")
	ui.screen="table"
	ui.render()
	check(find_button(ui,"Ver mesa")==null and find_button(ui,"Revancha")!=null,"Result actions updated")
	await screenshot010("04-victoria")
	await click(find_button(ui,"Volver al inicio"))
	await click(find_button(ui,"Misiones"))
	await wait_network()
	check(not find_button(ui,"Reclamar sobre").disabled,"Daily mission ready")
	await screenshot010("05-mision")
	await click(find_button(ui,"Reclamar sobre"))
	await wait_network()
	check(ui.collection.packs==1 and ui.collection.mission.claimed,"Mission grants one pack")
	ui.rewards.open_screen("missions")
	await wait_network()
	check(find_button(ui,"Recompensa reclamada").disabled,"Daily mission cannot be claimed twice")
	ui.rewards.open_screen("packs")
	await click(find_button(ui,"Abrir un sobre"))
	await wait_network()
	check(ui.collection.packs==1 and ui.collection.pending_opening==null,"Uncertain open response leaves local state unconfirmed")
	var request_uuid=ui.rewards.opening_request
	await click(find_button(ui,"Abrir un sobre"))
	await wait_network()
	check(ui.rewards.opening_request==request_uuid and total_cards()==85 and ui.collection.packs==0,"Opening retry consumes once and adds exactly five")
	check(ui.collection.pending_opening.cards==["0100","0104","0104","0120","0119"],"Ordered five cards retain legal normal duplicates")
	await screenshot010("06-sobre-cerrado")
	var reveal=find_meta(ui,"pack_reveal")
	await slide_pack(reveal,200)
	check(not reveal.sealed and reveal.revealed==0,"Mouse tear opens packet before first card")
	ui.render()
	await settle()
	reveal=find_meta(ui,"pack_reveal")
	check(not reveal.sealed and ui.rewards.reveal_open,"Refresh preserves torn wrapper before first slide")
	await screenshot010("07-primer-recurso")
	for i in range(5):
		await slide_pack(reveal,230 if i%2==0 else -230)
		check(ui.rewards.reveal_index==i+1,"Slide reveals next card in order %d"%i)
		if i==1: await screenshot010("08-deslizar-cartas")
	await screenshot010("09-cinco-cartas")
	check(find_button(ui,"Continuar")!=null and ui.rewards.reveal_index==5,"All five cards require slides")
	await click(find_button(ui,"Continuar"))
	await wait_network()
	check(ui.collection.pending_opening != null,"Uncertain acknowledgement remains safe to resume")
	await ui.collection.load_inventory()
	await settle()
	check(ui.rewards.opening_request.is_empty(),"Refresh after committed acknowledgement clears old retry UUID")
	check(ui.collection.pending_opening==null and total_cards()==85,"Acknowledge keeps collection, removes pending animation")
	ui.open_account()
	await a.sign_out()
	a.resend_at=0
	await a.request_code("rewards-a@fixture.invalid","",false)
	await a.verify_code("123456")
	await wait_network()
	check(total_cards()==85 and ui.collection.profile.avatar_code=="0108" and ui.collection.decks.size()==2,"Reentry reloads avatar deck and opened cards")
	ui.open_account()
	await a.sign_out()
	a.resend_at=0
	await a.request_code("rewards-b@fixture.invalid","Prueba",true)
	await a.verify_code("123456")
	await wait_network()
	check(total_cards()==0 and ui.collection.packs==0 and ui.collection.profile.avatar_code==null,"Second account isolated")
	print(JSON.stringify({"rewards_ui_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	await create_timer(.2).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func find_nodes(node,type_name):
	var found=[node] if node.is_class(type_name) else []
	for child in node.get_children(): found.append_array(find_nodes(child,type_name))
	return found
