extends "res://tests/test_v05.gd"
const AccountClient = preload("res://account.gd")
const CollectionClient = preload("res://collection.gd")
var fixture_url = ""

func wait_inventory():
	var deadline = Time.get_ticks_msec() + 22000
	while ui.collection.busy and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not ui.collection.busy, "Inventory request completes")

func shot09(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots=") and DisplayServer.get_name() != "headless":
			var folder = arg.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(folder.path_join(name + ".png"))

func all_meta(node, key):
	var result = [node] if node.has_meta(key) else []
	for child in node.get_children(): result.append_array(all_meta(child,key))
	return result

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--auth-test-url="): fixture_url = arg.trim_prefix("--auth-test-url=")
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	await settle()
	check(ui.screen == "account" and not ui.account_register, "First screen is sign in")
	check(find_button(ui,"Jugar como invitado") != null and find_button(ui,"Crear cuenta") != null and find_button(ui,"Salir") == null,"Access navigation available")
	await shot09("01-acceso")
	await click(find_button(ui,"Jugar como invitado"))
	check(ui.guest and ui.screen == "home", "Guest enters home")
	await shot09("08-inicio-invitado")
	check(find_button(ui,"Mis Cartas") == null and find_button(ui,"Mi cuenta") == null and find_button(ui,"Multijugador") == null,"Guest menu restrictions")
	ui.open_cards()
	check(ui.screen == "home", "Guest cannot open collection")
	ui.show_configuration()
	check(find_button(ui,"Sonido") != null,"Guest can configure sound")
	await shot09("09-configuracion")
	ui.show_audio_settings()
	await shot09("10-sonido")
	ui.go_home()
	ui.show_start()
	await settle()
	for name in ["Mazo Kajido","Mazo Papito","Mazo Flaan"]: check(find_button(ui,name) != null,"Guest practice deck: "+name)
	await shot09("02-practica")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(ui.started and ui.game.invariant_errors().is_empty(),"Guest match starts with 80 cards")
	await shot09("03-mesa")
	ui.go_home()
	await click(find_button(ui,"Volver al acceso"))
	check(not ui.guest and not ui.started and ui.screen == "account","Return to access clears guest match")
	var a = ui.account
	a.configure(fixture_url,"sb_publishable_contract_fixture",true)
	check(await a.request_code("a@fixture.invalid","Prueba",true),"Local OTP contract request")
	check(await a.verify_code("123456"),"Local OTP verification contract")
	await wait_inventory()
	check(ui.screen == "gift" and ui.collection.loaded and ui.collection.gift == null,"Existing account without award reaches selection")
	await shot09("04-regalo")
	ui.preview_deck(ui.game.decklists[0])
	await settle()
	check(find_button(ui,"0100 · ×18 · Restos") != null,"Preview exact quantities")
	ui.close_overlay(ui.overlay_shades.back())
	ui.confirm_gift(ui.game.decklists[0])
	await settle()
	check(find_button(ui,"Confirmar mi regalo") != null,"Explicit one-time choice confirmation")
	# Emit then immediately repeat, before a fast loopback reply can complete.
	find_button(ui,"Confirmar mi regalo").pressed.emit()
	check(not await ui.collection.claim("papito"),"Busy latch rejects concurrent second click")
	await wait_inventory()
	check(ui.collection.gift == null and ui.collection.status.contains("No pudimos"),"Lost response does not invent a local award")
	check(await ui.collection.claim("flaan"),"Retry after uncertain response")
	check(ui.collection.gift.deck_id == "kajido" and ui.collection.decks.size() == 1,"First server choice wins even when retry chooses another deck")
	check(ui.collection.cards["0100"] == 18 and ui.collection.cards.values().reduce(func(total,q): return total+int(q),0) == 40,"Forty cards including eighteen Resources")
	check(ui.screen == "cards","Successful award opens collection")
	var slots = all_meta(ui,"collection_code")
	check(slots.size() == 41 and slots[0].get_meta("collection_code") == "0100","Fixed slots start at 0100")
	check(slots.back().get_meta("collection_code") == "01f","Promotional codes retained after numeric codes")
	check(slots[1].get_child(0).get_child_count() == 0,"Missing card has empty fixed slot")
	check(ui.sound.music_wanted,"Menu music remains active")
	await shot09("05-coleccion")
	ui.catalog_detail("0105")
	await shot09("06-detalle")
	ui.close_overlay(ui.overlay_shades.back())
	ui.select_cards_tab("decks")
	await settle()
	check(find_button(ui,"Jugar con Mazo Kajido") != null and find_button(ui,"Jugar con Mazo Flaan") == null,"Only obtained deck is playable")
	await shot09("07-mis-mazos")
	ui.show_start()
	check(find_button(ui,"Mazo Kajido") != null and find_button(ui,"Mazo Flaan") == null,"Account deck picker restricts unowned decks")
	ui.start_match(2)
	check(not ui.started,"Direct unowned deck start rejected")
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(ui.started and ui.game.players[ui.human].deck_id == "kajido","Owned server deck starts match")
	var snapshot = JSON.stringify(ui.collection.cards)
	ui.go_home()
	ui.open_account()
	await a.sign_out()
	await settle()
	check(ui.screen == "account" and not ui.collection.loaded and ui.collection.cards.is_empty() and not ui.started,"Sign out clears private inventory and returns to access")
	a.resend_at = 0
	await a.request_code("a@fixture.invalid","",false)
	await a.verify_code("123456")
	await wait_inventory()
	check(JSON.stringify(ui.collection.cards) == snapshot and ui.collection.gift.deck_id == "kajido","Re-entry reloads same remote inventory")
	ui.open_account()
	await a.sign_out()
	a.resend_at = 0
	await a.request_code("b@fixture.invalid","Prueba",true)
	await a.verify_code("123456")
	await wait_inventory()
	check(ui.collection.cards.is_empty() and ui.collection.decks.is_empty() and ui.collection.gift == null,"Second UUID shares no collection")
	var second = CollectionClient.new()
	second.account = a
	get_root().add_child(second)
	check(await second.load_inventory() and second.cards.is_empty(),"Second client reloads from service")
	second.queue_free()
	print(JSON.stringify({"v09_ui_contract_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	await create_timer(.1).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
