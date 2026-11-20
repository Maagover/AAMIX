extends SceneTree
## Eight focused UI checks using local inventory; no account request is sent.
var ui
var failures=[]
var checks=0
var shots=""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): shots=arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok: failures.append(message);printerr("FAIL ",message)
func settle():
	for _i in range(8): await process_frame
func all_meta(node,key):
	var found=[]
	if node.has_meta(key): found.append(node)
	for child in node.get_children(): found.append_array(all_meta(child,key))
	return found
func text_node(node,text):
	if (node is Button or node is Label) and node.text==text: return node
	for child in node.get_children():
		var found=text_node(child,text)
		if found!=null: return found
	return null
func shot(name):
	if shots.is_empty(): return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name+".png"))
func run():
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	ui.automation_pause=true
	await settle()
	ui.play_guest()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000017","user_metadata":{"display_name":"AAMIX"}}
	ui.account.access_token="local_fixture_only"
	ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.account.configured=false
	ui.account.set_process(false)
	ui.online.set_process(false)
	ui.session_owner=ui.account.player_id()
	ui.collection.owner_id=ui.account.player_id()
	ui.collection.loaded=true
	ui.collection.restos=1250
	ui.collection.profile={"avatar_code":"0105"}
	ui.collection.decks=[ui.game.decklists[1]]
	ui.guest=false
	ui.collection.shop=[]
	for code in ui.game.catalog:
		var card=ui.game.catalog[code]
		if card.clase!="Recurso" and card.get("subcoleccion","")!="promocionales":
			ui.collection.shop.push_front({"code":code,"price":500 if code in ["0103","0105","0115","0119"] else 150})
	ui.go_home()
	await settle()
	var menus=all_meta(ui,"home_main_menu")
	var names=[]
	for child in menus[0].get_children():
		if child is Button: names.append(child.text)
	check(names==["Partida individual","Multijugador","Mi Colección","Misiones"],"Four main actions have requested order")
	var shop=text_node(ui,"Tienda")
	check(shop!=null and shop.global_position.x>root.size.x/2 and shop.global_position.y<160 and not shop in menus[0].get_children(),"Shop is compact in top-right row")
	var texture=ui.RestosArt.texture()
	check(texture!=null and texture.get_width()<=160 and texture.get_height()<=160 and all_meta(ui,"restos_icon").size()==1,"Supplied apple PNG is displayed next to account balance")
	await shot("01-inicio-v017")
	ui.go_shop()
	await settle()
	var items=all_meta(ui,"shop_card")
	var sorted=items.size()==34
	var last_price=0
	var last_code=""
	for item in items:
		var code=str(item.get_meta("shop_card"))
		var price=500 if code in ["0103","0105","0115","0119"] else 150
		if price<last_price or (price==last_price and code.naturalnocasecmp_to(last_code)<0): sorted=false
		last_price=price
		last_code=code
	check(sorted,"All 34 shop cards sort by price then card number")
	await shot("02-tienda-ordenada")
	var currency_ok=true
	for amount in [50,100,1000]:
		var entries=ui.rewards.code_reward_items({"reward_restos":amount})
		if entries.size()!=1 or entries[0].kind!="restos" or entries[0].amount!=amount: currency_ok=false
	check(currency_ok,"Currency gift items use exact requested Restos amounts")
	ui.rewards.show_code_reward({"reward_name":"AAMIXNAVIDAD","reward_packs":1,"reward_restos":50,"reward_normal_packs":1})
	await settle()
	var icons=all_meta(ui,"gift_reward_kind")
	check(icons.size()==3 and icons.map(func(node): return node.get_meta("gift_reward_kind"))==["tc_pack","restos","normal_pack"],"Christmas gift displays three distinct reward images")
	await shot("03-navidad-tres-recompensas")
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())
	ui.screen="multiplayer"
	ui.render()
	await settle()
	check(all_meta(ui,"multiplayer_ui").size()==1 and text_node(ui,"Crear sala")!=null and text_node(ui,"Unirme con código")!=null and text_node(ui,"Retomar sala")!=null,"Online screen has create, join and recover actions")
	await shot("04-multijugador")
	ui.account.clear_session()
	ui.online.clear()
	ui.screen="multiplayer"
	ui.render()
	await settle()
	check(text_node(ui,"Accede a tu cuenta para jugar con un amigo.")!=null and text_node(ui,"Crear sala")==null,"Guest must sign in before creating an online room")
	print(JSON.stringify({"release_ui_v017_checks":checks,"failures":failures,"network_requests":0}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
