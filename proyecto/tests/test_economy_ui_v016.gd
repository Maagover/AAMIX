extends SceneTree
## 35 focused checks against a loopback-only HTTP fixture. No real accounts.
var ui
var checks = 0
var executed_checks = 0
var resume_owner = false
var failures = []
var fixture_url = ""
var screenshot_path = ""
var captures = []
const SINGULARS = ["0103","0105","0115","0119"]

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg == "--resume-owner-v016": resume_owner = true
		if arg.begins_with("--auth-test-url="): fixture_url = arg.trim_prefix("--auth-test-url=")
		if arg.begins_with("--screenshots="): screenshot_path = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok,message):
	checks += 1
	if resume_owner and checks < 34: return
	executed_checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL ",checks,": ",message)

func find_text(node,value):
	if (node is Label or node is Button) and node.text == value: return node
	for child in node.get_children():
		var found = find_text(child,value)
		if found != null: return found
	return null

func meta(node,key,value=null):
	if node.has_meta(key) and (value == null or node.get_meta(key) == value): return node
	for child in node.get_children():
		var found = meta(child,key,value)
		if found != null: return found
	return null

func all_meta(node,key):
	var result = []
	if node.has_meta(key): result.append(node)
	for child in node.get_children(): result.append_array(all_meta(child,key))
	return result

func settle():
	for _i in range(8): await process_frame

func wait_network():
	var deadline = Time.get_ticks_msec()+15000
	await settle()
	while (ui.account.busy or ui.collection.busy or ui.rewards.pumping or ui.welcome_loading) and Time.get_ticks_msec()<deadline: await process_frame
	await settle()

func total_cards():
	return ui.collection.cards.values().reduce(func(total,n): return total+int(n),0)

func dismiss():
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())

func shot(name):
	if screenshot_path.is_empty() or (resume_owner and name != "09-bienvenida-segunda-cuenta"): return
	DirAccess.make_dir_recursive_absolute(screenshot_path)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var target = screenshot_path.path_join(name+".png")
	root.get_texture().get_image().save_png(target)
	captures.append(target)

func login(email,nickname,close_welcome=true):
	# The fixture advances the local OTP throttle, without waiting a real minute.
	ui.account.resend_at = 0
	await ui.account.request_code(email,nickname,true)
	await ui.account.verify_code("123456")
	await wait_network()
	if close_welcome: dismiss()

func report():
	var result = {"economy_ui_v016_checks":checks,"executed_checks":executed_checks,"resume_owner":resume_owner,"failures":failures,"captures":captures,"fixture_only":true,"real_emails_sent":0,"real_rewards_claimed":0}
	print(JSON.stringify(result))
	if not screenshot_path.is_empty():
		var file = FileAccess.open(screenshot_path.path_join("economy_ui_v016_owner_results.json" if resume_owner else "economy_ui_v016_results.json"),FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result,"  "))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() and checks == 35 else 1)

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"): quit(1);return
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	ui.automation_pause=true
	await settle()
	ui.play_guest()
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await login("economy-v016@fixture.invalid","Restos de prueba")
	var original_owner = ui.account.player_id()
	check(ui.collection.loaded and ui.collection.restos==100 and ui.collection.restos_welcome_claimed,"Login grants 100 Restos once") # 1
	await ui.collection.ensure_economy()
	await wait_network()
	check(ui.collection.restos==100 and ui.collection.packs==1 and not ui.collection.last_reply.get("restos_awarded",true),"Welcome retry preserves 100 Restos and existing TC pack") # 2
	ui.go_home()
	await settle()
	var wallet = meta(ui,"home_restos")
	var name = find_text(meta(ui,"home_account"),"Restos de prueba")
	check(wallet!=null and meta(wallet,"restos_icon")!=null and meta(wallet,"restos_balance",100)!=null and wallet.global_position.y>name.global_position.y,"Home shows currency below player name beside profile") # 3
	await shot("01-inicio-restos")
	ui.go_shop()
	await settle()
	var shop_cards = all_meta(ui,"shop_card")
	check(shop_cards.size()==34 and ui.collection.shop.size()==34,"Shop renders exactly 34 eligible cards") # 4
	var prices = all_meta(ui,"shop_price")
	check(prices.filter(func(b):return b.get_meta("shop_price")==500).size()==4 and prices.filter(func(b):return b.get_meta("shop_price")==150).size()==30,"Four Singulars cost 500 and other shop cards cost 150") # 5
	check(shop_cards.all(func(item):return ui.game.catalog[item.get_meta("shop_card")].clase!="Recurso" and ui.game.catalog[item.get_meta("shop_card")].get("subcoleccion","")!="promocionales"),"Shop excludes every resource and promotional card") # 6
	check(prices.all(func(button):return button.disabled),"100 Restos cannot buy a 150 or 500 Restos card") # 7
	await shot("02-tienda-100")
	ui.rewards.open_screen("missions")
	await wait_network()
	var missions = ui.collection.missions
	check(missions.size()==4 and missions[0].scope=="daily" and missions[0].reward_kind=="restos" and missions[0].reward_amount==50 and missions[1].scope=="daily" and missions[1].reward_kind=="normal_pack" and missions[2].reward_amount==3 and missions[3].reward_amount==5,"Four mission definitions match new daily and lifetime rewards") # 8
	var rows = all_meta(ui,"mission_row")
	check(rows.size()==4 and rows.all(func(row):return row.get_parent().size.y<=110),"Mission rows are compact at most 110 pixels") # 9
	check(all_meta(ui,"mission_reward_icon").map(func(icon):return icon.get_meta("mission_reward_icon"))==["restos","normal_pack","tc_pack","tc_pack"],"Mission reward images correspond to currency, brown packet and TC packet") # 10
	await shot("03-misiones-compactas")
	await ui.collection.enter_challenge()
	await ui.collection.claim(ui.game.decklists[0].id)
	await wait_network()
	dismiss()
	var receipt_request = ui.collection.request_id()
	await ui.collection.begin_match(receipt_request,ui.collection.decks[0].id)
	var match_id = ui.collection.last_reply.match_id
	await ui.collection.finish_match(match_id,true)
	await wait_network()
	check(ui.collection.missions[0].progress==1 and ui.collection.missions[1].progress==1 and total_cards()==40,"One completed fixture victory progresses both daily missions") # 11
	var tc_before = ui.collection.packs
	await ui.rewards.claim_mission("play_one")
	await wait_network()
	check(ui.collection.restos==150 and ui.collection.packs==tc_before,"Daily play reward grants 50 Restos without TC packs") # 12
	var money_reward = meta(ui,"reward_icon")
	var money_texture = load("res://restos_art.gd").texture()
	check(money_reward!=null and money_reward.texture==money_texture,"Restos mission popup uses eaten-apple reward image") # 13
	dismiss()
	await ui.collection.claim_mission("play_one")
	await wait_network()
	check(ui.collection.restos==150 and ui.collection.last_reply.already_claimed,"Daily claim retry does not duplicate currency") # 14
	ui.go_shop()
	await settle()
	check(meta(ui,"shop_balance").text=="150 Restos","Shop displays current balance in header") # 15
	var code = "0101"
	var prior_copies = int(ui.collection.cards.get(code,0))
	ui.shop.confirm_purchase(code,150)
	await settle()
	check(ui.modal_open and find_text(ui,"Comprar")!=null and ui.shop.pending_purchase.is_empty(),"Purchase confirmation precedes any payment request") # 16
	find_text(ui,"Comprar").pressed.emit()
	await wait_network()
	var purchase_request = str(ui.shop.pending_purchase.get("id",""))
	check(not purchase_request.is_empty() and ui.collection.last_http_code==503 and ui.collection.restos==150 and int(ui.collection.cards.get(code,0))==prior_copies,"Lost purchase response retains exact request without optimistic grant") # 17
	await ui.shop.complete_purchase()
	await wait_network()
	check(ui.shop.pending_purchase.is_empty() and ui.collection.restos==0 and int(ui.collection.cards.get(code,0))==prior_copies+1 and total_cards()==41,"Purchase retry charges 150 once and grants one card") # 18
	check(meta(ui,"reward_icon")!=null and meta(ui,"reward_icon").texture==ui.texture_code(code),"Purchase reward displays purchased card") # 19
	await shot("04-carta-comprada")
	dismiss()
	await ui.collection.request("aamix_fixture_metrics",{})
	var metrics = ui.collection.last_reply.fixture_metrics
	var buy_requests = metrics.requests.filter(func(item):return item.method=="aamix_purchase_card")
	check(metrics.purchase_count==1 and buy_requests.size()==2 and buy_requests.all(func(item):return item.request_id==purchase_request and item.uid==original_owner),"Both purchase requests use the same UUID and owner with one receipt") # 20
	await ui.collection.ensure_economy()
	check(ui.collection.restos==0 and not ui.collection.last_reply.restos_awarded,"Spending currency cannot reclaim welcome Restos") # 21
	await ui.rewards.claim_mission("win_one")
	await wait_network()
	check(ui.collection.normal_packs==1 and ui.collection.packs==tc_before and ui.collection.restos==0,"Daily win reward grants one normal-card packet only") # 22
	var normal_reward = meta(ui,"reward_icon")
	check(normal_reward!=null and normal_reward.texture.get_meta("pack_kind","")=="normal_card","Daily win popup uses brown normal-card packet artwork") # 23
	dismiss()
	await ui.collection.claim_mission("win_one")
	check(ui.collection.normal_packs==1 and ui.collection.last_reply.already_claimed,"Daily win retry does not duplicate normal packet") # 24
	ui.rewards.open_screen("packs")
	await settle()
	var tiles = all_meta(ui,"pack_kind").filter(func(node):return node is Button)
	check(tiles.size()==2 and tiles.all(func(tile):return absf(tile.size.x-tile.size.y)<2) and meta(ui,"pack_kind","tc")!=null and meta(ui,"pack_kind","normal_card")!=null,"Owned TC and normal packets use two square tiles") # 25
	await shot("05-dos-tipos-sobre")
	meta(ui,"pack_kind","normal_card").pressed.emit()
	await wait_network()
	var opening_request = ui.rewards.opening_request
	check(ui.collection.last_http_code==503 and ui.collection.pending_opening==null and not opening_request.is_empty() and ui.rewards.opening_request_kind=="normal_card","Lost normal opening keeps original kind and UUID") # 26
	await ui.rewards.start_opening("normal_card")
	await wait_network()
	check(ui.collection.pending_opening is Dictionary and ui.collection.pending_opening.kind=="normal_card" and ui.collection.pending_opening.cards==["0104"] and ui.collection.normal_packs==0 and ui.collection.packs==tc_before and total_cards()==42,"Opening retry grants exactly one normal card and spends no TC pack") # 27
	await ui.collection.request("aamix_fixture_metrics",{})
	metrics=ui.collection.last_reply.fixture_metrics
	var normal_requests = metrics.requests.filter(func(item):return item.method=="aamix_open_normal_pack")
	check(metrics.opening_count==1 and normal_requests.size()==2 and normal_requests.all(func(item):return item.request_id==opening_request),"Normal opening retries retain identical UUID with one opening receipt") # 28
	await settle()
	var reveal = meta(ui,"pack_reveal")
	check(reveal!=null and reveal.sealed and reveal.cards.size()==1 and reveal.layers.get_child_count()==1 and not reveal.current.visible and reveal.packet_closed.get_meta("pack_kind")=="normal_card","Sealed brown packet contains one fully hidden card") # 29
	reveal.open_packet()
	await create_timer(.3).timeout
	check(reveal.opening_stage=="opened" and reveal.packet_opened_art.modulate.a>.99 and reveal.packet_opened_art.texture!=reveal.packet_closed.texture,"Brown opening crossfades to torn artwork with same pause") # 30
	await shot("06-sobre-cafe-abierto")
	await create_timer(1.4).timeout
	await settle()
	check(reveal.opening_stage=="cards" and reveal.current.visible and reveal.current.rotation==0 and not reveal.current.has_meta("singular_highlight"),"Only normal card appears front-facing without Singular effect") # 31
	await shot("07-carta-normal-frontal")
	await reveal.slide_card()
	await settle()
	var one_card_summary = find_text(ui,"¡Una carta para tu colección!")!=null
	await ui.rewards.finish_opening()
	await ui.rewards.finish_opening()
	await wait_network()
	check(one_card_summary and ui.collection.pending_opening==null and total_cards()==42 and ui.collection.normal_packs==0 and ui.collection.packs==tc_before,"One slide completes one-card summary; acknowledgement retry changes no rewards") # 32
	await ui.collection.request("aamix_fixture_empty_packs",{})
	await settle()
	check(meta(ui,"empty_packs")!=null and find_text(ui,"No tienes sobres por abrir")!=null and all_meta(ui,"pack_expansion").is_empty(),"Empty inventory shows centered no-packets message") # 33
	await shot("08-sin-sobres")
	ui.shop.pending_purchase={"id":ui.collection.request_id(),"code":code,"owner":original_owner}
	ui.rewards.opening_request=ui.collection.request_id()
	await ui.account.sign_out()
	await settle()
	await login("economy-other-v016@fixture.invalid","Otra cuenta",false)
	check(ui.account.player_id()!=original_owner and ui.collection.restos==100 and ui.collection.normal_packs==0 and total_cards()==0 and ui.shop.pending_purchase.is_empty() and ui.rewards.opening_request.is_empty() and find_text(ui,"¡Tu primer sobre TC!")!=null,"Changing owner clears pending requests and balance; welcome popup survives currency bootstrap") # 34
	await shot("09-bienvenida-segunda-cuenta")
	dismiss()
	await ui.account.sign_out()
	await settle()
	await login("economy-v016@fixture.invalid","Restos de prueba")
	check(ui.account.player_id()==original_owner and ui.collection.restos==0 and total_cards()==42 and ui.collection.missions[0].claimed and ui.collection.missions[1].claimed,"Returning owner retains own spent balance, purchased card and claimed daily rewards") # 35
	await report()
