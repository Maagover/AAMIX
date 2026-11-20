extends "res://tests/test_rewards_v012.gd"
## Current four missions, challenge receipts and supplied reward artwork.

func challenge(stage):
	for value in ui.collection.challenges:
		if value.stage == stage: return value
	return {}

func completed(victory, stage = 0):
	var request_id = ui.collection.request_id()
	check(await ui.collection.begin_match(request_id,"girabl",stage),"Match begins with its fixed challenge context")
	var reply = ui.collection.last_reply.duplicate(true)
	check(int(reply.get("challenge_stage",0)) == stage,"Receipt preserves the requested mode and stage")
	check(await ui.collection.finish_match(reply.match_id,victory),"Match result reaches the fixture service")
	await settle()
	return ui.collection.last_reply.duplicate(true)

func wait_reported(receipt):
	var deadline = Time.get_ticks_msec() + 12000
	while not receipt.get("reported",false) and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(receipt.get("reported",false),"Queued challenge result is reported once")

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"):
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("rewards-v014@fixture.invalid","Prueba",true)
	await ui.account.verify_code("123456")
	await wait_network()
	check(ui.collection.missions.size() == 4 and ui.collection.mission.id == "play_one","Four missions preserve the original singular play-one contract")
	check(state("play_one").scope == "daily" and state("play_one").reward_packs == 1,"Play-one remains daily for one pack")
	check(state("win_one").scope == "lifetime" and state("win_one").reward_packs == 1,"Win-one is now once per account")
	check(state("play_ten").reward_packs == 3 and state("win_ten").target == 10 and state("win_ten").reward_packs == 5,"Ten-play and ten-win rewards are three and five packs")
	check(ui.collection.challenges.size() == 5 and challenge(1).unlocked and not challenge(2).unlocked,"Challenge begins at stage one")
	ui.rewards.open_screen("gift_code")
	ui.rewards.code_text = "AAMIXTC"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(ui.collection.packs == 1 and find_meta(ui,"reward_icon").texture == load("res://pack_art.gd").texture(false),"Pack gift uses the actual closed pack artwork")
	await shot("v014-regalo-sobre")
	ui.rewards.code_text = "P3RI"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(find_meta(ui,"reward_icon").texture == ui.texture_code("01a") and find_text(ui,"3 × %s\nEn Mi Colección." % ui.game.catalog["01a"].nombre) != null,"Card gift displays its full card and names Mi Colección")
	await shot("v014-regalo-carta")
	for code in ["B1G0T3S","SI2TYA","CHANCHULINES","TORNEOAAMIX1"]:
		check(await ui.collection.redeem_code(code),"Existing promotional code remains available: " + code)
	ui.rewards.code_text = "M4Z0G1R4"
	ui.render()
	await ui.rewards.redeem()
	await wait_network()
	check(find_meta(ui,"reward_icon").texture == ui.deck_cover_texture("girabl"),"Deck gift uses its supplied package image")
	await shot("v014-regalo-mazo")
	check(total_cards() == 49 and ui.owned_deck("girabl").cartas.size() == 14,"Girabl and promotional quantities remain exact")
	check(not await ui.collection.redeem_code("M4Z0M44G0"),"Old Maagover uncertain reply remains retryable")
	check(await ui.collection.redeem_code("M4Z0M44G0") and total_cards() == 89,"Old Maagover retries still grant forty cards once")
	ui.rewards.open_screen("missions")
	await wait_network()
	for id in ["play_one","win_one","play_ten","win_ten"]:
		check(meta_value(ui,"mission_row",id) != null,"Each mission has its own row and action: " + id)
	await shot("v014-misiones-iniciales")
	check(not await ui.collection.begin_match(ui.collection.request_id(),"girabl",2),"Locked challenge stage cannot obtain a receipt")
	check(not await ui.collection.begin_match(ui.collection.request_id(),"girabl",6),"Invalid challenge stage is rejected")
	var first = await completed(false)
	check(state("play_one").progress == 1 and state("play_ten").progress == 1 and state("win_one").progress == 0 and state("win_ten").progress == 0,"Loss counts only toward play missions")
	await ui.collection.finish_match(first.match_id,true)
	check(state("play_ten").progress == 1 and state("win_ten").progress == 0,"A reported receipt cannot be changed or counted again")
	check(ui.collection.status.is_empty(),"Successful receipt reporting shows no removed registration message")
	await completed(true)
	await claim_row("play_one")
	await claim_row("win_one")
	check(ui.collection.packs == 3,"Daily play and lifetime win grant independent one-pack rewards")
	for index in range(8): await completed(index % 2 == 0)
	check(state("play_ten").progress == 10 and state("win_ten").progress == 5,"Ten games count wins and losses, ten victories count only wins")
	await claim_row("play_ten")
	check(ui.collection.packs == 6 and ui.collection.last_reply.reward_packs == 3,"New ten-game claim grants exactly three packs")
	check(not await ui.collection.claim_mission("win_ten"),"Ten-win reward remains locked at five victories")
	await ui.collection.request("aamix_fixture_next_day",{})
	check(state("play_one").progress == 0 and not state("play_one").claimed,"Only the daily play mission resets on a new day")
	check(state("win_one").claimed and state("play_ten").claimed and state("win_ten").progress == 5,"Lifetime claims and victory progress survive midnight")
	for _index in range(5): await completed(true)
	await claim_row("win_ten")
	check(ui.collection.packs == 11 and state("win_ten").claimed,"Ten-win claim grants five packs once")
	await claim_row("play_one")
	await ui.collection.claim_mission("win_one")
	await ui.collection.claim_mission("play_ten")
	await ui.collection.claim_mission("win_ten")
	check(ui.collection.packs == 12,"Repeated permanent claims cannot duplicate packs")
	check(not challenge(2).unlocked,"Random matches never unlock challenge stages")
	ui.rewards.open_screen("missions")
	await wait_network()
	await shot("v014-misiones-reclamadas")
	var loss = await completed(false,1)
	check(int(loss.challenge_reward_packs) == 0 and not challenge(2).unlocked,"Challenge loss gives no reward or unlock")
	# Exercise the actual two-argument main signal and delayed receipt queue.
	ui.choose_challenge(1)
	ui.start_match(0)
	ui.automation_pause = true
	ui.selected_challenge_stage = 0
	await settle()
	var receipt = ui.rewards.active_receipt
	check(receipt.challenge_stage == 1,"Queued receipt keeps stage even if menu selection later changes")
	check(ui.game.players[ui.computer].deck_id == "papito","Stage-one game uses the fixed Papito opponent")
	ui.game.lose(ui.computer)
	ui.render()
	await wait_reported(receipt)
	check(ui.collection.packs == 13 and challenge(1).completed and challenge(2).unlocked,"First challenge victory grants and unlocks atomically")
	check(ui.rewards.pending_challenge_rewards.size() == 1 and ui.rewards.match_status.is_empty(),"Reward waits behind the result screen without a removed registration message")
	ui.go_home()
	await settle()
	check(find_text(ui,"¡Desafío superado!") != null and find_meta(ui,"reward_icon") != null,"Leaving the result displays the earned pack once")
	await shot("v014-premio-desafio")
	ui.open_challenges()
	await settle()
	check(ui.rewards.pending_challenge_rewards.is_empty(),"Consumed challenge celebration is not replayed")
	await ui.collection.finish_match(receipt.match_id,true)
	check(ui.collection.packs == 13 and ui.collection.last_reply.challenge_reward_packs == 0,"Same challenge receipt cannot award again")
	var replay = await completed(true,1)
	check(ui.collection.packs == 13 and replay.challenge_already_completed and replay.challenge_reward_packs == 0,"Replaying a completed stage grants no second prize")
	for stage in range(2,6):
		var before = ui.collection.packs
		var result = await completed(true,stage)
		var amount = 1 if stage < 4 else (2 if stage == 4 else 3)
		check(result.challenge_reward_packs == amount and ui.collection.packs == before + amount,"Stage %d grants its exact one-time prize" % stage)
	check(ui.collection.packs == 20 and challenge(5).completed,"All five challenge prizes total eight packs")
	ui.open_challenges()
	await settle()
	await shot("v014-desafios-completados")
	ui.open_account()
	await ui.account.sign_out()
	check(ui.collection.missions.is_empty() and ui.collection.challenges.is_empty(),"Sign-out clears mission and challenge data")
	ui.account.resend_at = 0
	await ui.account.request_code("rewards-v014-legacy@fixture.invalid","Legacy",true)
	await ui.account.verify_code("123456")
	await wait_network()
	await ui.collection.request("aamix_fixture_legacy_claims",{})
	check(state("play_ten").reward_packs == 3 and state("play_ten").claimed and state("win_one").claimed,"Old claims remain claimed while current mission lists the new reward")
	await ui.collection.claim_mission("play_ten")
	check(ui.collection.packs == 6 and ui.collection.last_reply.reward_packs == 5 and ui.collection.last_reply.already_claimed,"Legacy five-pack claim metadata is retained without granting again")
	ui.open_account()
	await ui.account.sign_out()
	ui.account.resend_at = 0
	await ui.account.request_code("rewards-v014@fixture.invalid","",false)
	await ui.account.verify_code("123456")
	await wait_network()
	check(ui.collection.packs == 20 and challenge(5).completed and state("win_ten").claimed and total_cards() == 89,"Reentry restores all challenge and lifetime progress independently of cards")
	print(JSON.stringify({"rewards_v014_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
