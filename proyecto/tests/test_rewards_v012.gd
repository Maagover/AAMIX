extends "res://tests/test_rewards_v011.gd"
## Three-mission lifecycle and new gifts against the loopback-only fixture.

func state(id):
	for value in ui.collection.missions:
		if value.id == id: return value
	return {}

func meta_value(node, key, value):
	if node.has_meta(key) and node.get_meta(key) == value: return node
	for child in node.get_children():
		var found = meta_value(child,key,value)
		if found != null: return found
	return null

func named_button(node, caption):
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found = named_button(child,caption)
		if found != null: return found
	return null

func complete_match(victory, verify_retry = false):
	var request_uuid = ui.collection.request_id()
	check(await ui.collection.begin_match(request_uuid,"girabl"), "Owned Girabl starts a server match receipt")
	var id = ui.collection.last_reply.match_id
	if verify_retry:
		check(await ui.collection.begin_match(request_uuid,"girabl") and ui.collection.last_reply.match_id == id, "Retrying a match UUID returns the same receipt")
	check(await ui.collection.finish_match(id,victory), "Completed match reports its actual result")
	await settle()
	return id

func claim_row(id):
	var button = meta_value(ui,"claim_mission",id)
	check(button != null and not button.disabled, "The correct mission row is claimable: " + id)
	if button != null: button.pressed.emit()
	await wait_network()
	check(ui.collection.last_reply.get("mission_id") == id, "Row sends its own mission ID: " + id)

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("rewards-v012@fixture.invalid","Prueba",true)
	await ui.account.verify_code("123456")
	await wait_network()
	check(ui.collection.missions.size() == 3 and ui.collection.mission.id == "play_one", "Inventory exposes three missions and the legacy play-one alias")
	check(state("play_one").target == 1 and state("win_one").target == 1 and state("play_ten").target == 10, "Mission targets are one play, one win and ten plays")
	check(state("play_ten").scope == "lifetime" and state("play_ten").day == null and state("play_ten").reward_packs == 5, "Ten games is a permanent five-pack mission")
	var normalized = ui.collection.normalize_missions([null,{"id":"unknown"},{"id":"play_ten","target":10,"progress":99,"reward_packs":5},{"id":"play_ten"}])
	check(normalized.size() == 1 and normalized[0].progress == 10 and normalized[0].scope == "lifetime", "Malformed, duplicate and excessive mission state is sanitized")
	check(ui.collection.normalize_missions(null,{"id":"play_one","progress":1}).size() == 1, "Legacy inventory mission remains compatible")
	ui.rewards.open_screen("gift_code")
	ui.rewards.code_text = " aamixtc "
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(ui.collection.packs == 1 and total_cards() == 0 and ui.collection.decks.is_empty(), "AAMIXTC grants one pack without inventing cards or a deck")
	check(ui.collection.last_reply.get("reward_packs") == 1 and ui.collection.last_reply.get("reward_cards") == [], "Pack gift uses the new reward-packs contract")
	check(find_text(ui,"1 sobre\nEn Mis sobres.") != null, "Pack gift celebration points to Mis sobres")
	await shot("v012-regalo-sobre")
	ui.rewards.code_text = "AAMIXTC"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(ui.collection.packs == 1 and ui.collection.last_reply.already_redeemed, "AAMIXTC is once per player")
	ui.rewards.code_text = " m4z0g1r4 "
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	var girabl = ui.owned_deck("girabl")
	check(girabl.get("nombre") == "Mazo Girabl" and total_cards() == 40, "Girabl code awards a named forty-card deck")
	var resources = 0
	var count = 0
	for entry in girabl.get("cartas",[]):
		count += int(entry.cantidad)
		if ui.game.catalog[entry.codigo].clase == "Recurso": resources += int(entry.cantidad)
	check(count == 40 and resources == 12, "Historic Girabl contains exactly forty cards and twelve Resources")
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mazos_legacy.json"))
	var historic = fixture.mazos.filter(func(deck): return deck.id == "usuario_girabl")[0]
	check(girabl.cartas == historic.cartas and ui.collection.gift == null, "Girabl preserves historic quantities and leaves the starter gift available")
	check(find_text(ui,"Mazo Girabl está en Mis Mazos.") != null, "Deck gift celebration names Girabl")
	await shot("v012-regalo-girabl")
	ui.rewards.code_text = "M4Z0G1R4"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(total_cards() == 40 and ui.collection.decks.size() == 1, "Girabl code replay cannot duplicate its deck or cards")
	ui.go_home()
	ui.show_start()
	await settle()
	check(named_button(ui,"Mazo Girabl") != null, "Acquired Girabl is playable from the deck selector")
	await shot("v012-selector-girabl")
	ui.open_cards()
	ui.select_cards_tab("decks")
	await settle()
	check(find_text(ui,"Mazo Girabl") != null and named_button(ui,"Jugar con Mazo Girabl") == null, "Girabl appears in the inspection-only owned deck list")
	await shot("v012-mis-mazos-girabl")
	for code in ["P3RI","B1G0T3S","SI2TYA","CHANCHULINES","TORNEOAAMIX1"]:
		check(await ui.collection.redeem_code(code), "Prior promotional code remains available: " + code)
	check(total_cards() == 49, "Five prior card codes still grant exactly nine cards")
	check(not await ui.collection.redeem_code("M4Z0M44G0"), "Lost Maagover response remains unconfirmed locally")
	check(total_cards() == 49, "Uncertain old gift creates no local cards")
	check(await ui.collection.redeem_code("M4Z0M44G0") and total_cards() == 89 and ui.collection.decks.size() == 2, "Old Maagover gift retry still grants its exact forty cards once")
	ui.rewards.open_screen("missions")
	await wait_network()
	for id in ["play_one","win_one","play_ten"]:
		var row = meta_value(ui,"mission_row",id)
		check(row != null and row.global_position.x < 60 and meta_value(row,"claim_mission",id).disabled, "Initial mission row is left aligned and protected: " + id)
	check(find_text(ui,"Acumulativa") != null and find_text(ui,"Recompensa: 5 sobres") != null, "Permanent mission has a concise scope flag and five-pack reward")
	await shot("v012-misiones-iniciales")
	check(not await ui.collection.claim_mission("win_one") and ui.collection.packs == 1, "Unfinished win mission cannot be claimed")
	check(not await ui.collection.claim_mission("invalid") and ui.collection.status.contains("no está disponible"), "Unknown mission ID has clear feedback")
	var first_id = await complete_match(false,true)
	check(state("play_one").progress == 1 and state("win_one").progress == 0 and state("play_ten").progress == 1, "A loss advances play missions but not the win mission")
	await ui.collection.finish_match(first_id,false)
	await ui.collection.finish_match(first_id,true)
	check(state("play_ten").progress == 1 and state("win_one").progress == 0, "Repeated or changed receipt results cannot count twice")
	await claim_row("play_one")
	check(ui.collection.packs == 2 and state("play_one").claimed, "Play-one row grants exactly one pack")
	await ui.collection.claim_daily_mission()
	check(ui.collection.packs == 2 and ui.collection.last_reply.already_claimed, "Legacy daily claim shares the same once-only reward")
	await complete_match(true)
	check(state("win_one").progress == 1 and state("play_ten").progress == 2, "A victory independently advances win-one and lifetime progress")
	await claim_row("win_one")
	check(ui.collection.packs == 3 and state("win_one").claimed, "Win-one row grants its independent one-pack reward")
	await ui.collection.claim_mission("win_one")
	check(ui.collection.packs == 3 and ui.collection.last_reply.already_claimed, "Win reward is idempotent")
	check(not await ui.collection.claim_mission("play_ten") and ui.collection.packs == 3, "Lifetime reward waits until all ten games")
	for index in range(8): await complete_match(index % 2 == 0)
	check(state("play_ten").progress == 10 and not state("play_ten").claimed, "Wins and losses accumulate to ten completed matches")
	await shot("v012-misiones-completas")
	await claim_row("play_ten")
	check(ui.collection.packs == 8 and state("play_ten").claimed, "Lifetime row grants exactly five packs")
	check(find_text(ui,"5 sobres\nEn Mis sobres.") != null, "Mission celebration displays its actual five-pack quantity")
	await ui.collection.claim_mission("play_ten")
	check(ui.collection.packs == 8 and ui.collection.last_reply.already_claimed, "Lifetime claim retry grants no duplicate reward")
	# Explicitly local test clock; production has no such endpoint.
	await ui.collection.request("aamix_fixture_next_day",{})
	check(state("play_one").progress == 0 and not state("play_one").claimed and state("win_one").progress == 0, "Daily missions reset on a new Chile day")
	check(state("play_ten").progress == 10 and state("play_ten").claimed and state("play_ten").day == null, "Permanent progress and claimed state survive a new day")
	await complete_match(true)
	check(state("play_ten").progress == 10, "Permanent progress stays capped after ten matches")
	await ui.collection.claim_mission("play_one")
	await ui.collection.claim_mission("win_one")
	await ui.collection.claim_mission("play_ten")
	check(ui.collection.packs == 10, "Only daily rewards can be obtained on another day")
	ui.rewards.open_screen("missions")
	await wait_network()
	await shot("v012-misiones-reclamadas")
	ui.rewards.open_screen("packs")
	await ui.rewards.start_opening()
	await wait_network()
	check(ui.collection.pending_opening == null and ui.collection.packs == 10, "Uncertain opening is still safe to retry")
	await ui.rewards.start_opening()
	await wait_network()
	check(total_cards() == 94 and ui.collection.packs == 9 and ui.collection.pending_opening.cards.size() == 5, "Retry adds exactly five cards and consumes one pack")
	var opening_id = ui.collection.pending_opening.opening_id
	ui.rewards.reveal_open = true
	ui.rewards.reveal_index = 2
	ui.render()
	await settle()
	check(find_meta(ui,"pack_reveal").revealed == 2, "Packet reveal resumes at its existing card index")
	await ui.collection.load_inventory()
	check(ui.collection.pending_opening.opening_id == opening_id and ui.rewards.reveal_index == 2, "Inventory refresh preserves pending packet progress")
	await shot("v012-sobre-retomado")
	await ui.rewards.finish_opening()
	await ui.collection.load_inventory()
	check(ui.collection.pending_opening == null and total_cards() == 94 and ui.collection.packs == 9, "Committed acknowledgement is recovered without duplicating cards")
	ui.open_account()
	await ui.account.sign_out()
	check(ui.collection.missions.is_empty(), "Signing out clears all three mission states")
	ui.account.resend_at = 0
	await ui.account.request_code("rewards-v012@fixture.invalid","",false)
	await ui.account.verify_code("123456")
	await wait_network()
	check(state("play_ten").claimed and ui.collection.packs == 9 and total_cards() == 94 and ui.owned_deck("girabl").nombre == "Mazo Girabl", "Reentry restores permanent claim, packs and Girabl ownership")
	ui.open_account()
	await ui.account.sign_out()
	ui.account.resend_at = 0
	await ui.account.request_code("rewards-v012-b@fixture.invalid","Otra cuenta",true)
	await ui.account.verify_code("123456")
	await wait_network()
	check(total_cards() == 0 and ui.collection.packs == 0 and state("play_ten").progress == 0 and not state("play_ten").claimed, "Another account shares no lifetime progress or rewards")
	print(JSON.stringify({"rewards_v012_checks":checks,"failures":failures,"real_emails_sent":0,"completed_fixture_matches":11}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
