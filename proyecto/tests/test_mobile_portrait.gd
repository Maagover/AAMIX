extends SceneTree
var b
var checks=0
var failures=[]
var identity="00000000-0000-4000-8000-000000000001"
func _initialize():run.call_deferred()
func check(value,message):
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames(count=10):
	for i in range(count):await process_frame
func render_screen(name):
	b.screen=name;b.render();await frames()
	check(is_instance_valid(b.mobile.page_root),"Portrait screen built: "+name)
	if is_instance_valid(b.mobile.page_root):
		var minimum=b.mobile.page_root.get_combined_minimum_size().x
		check(minimum<=456.1,"Portrait width fits %s: %s" % [name,minimum])
func screenshot(name):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/qa_portrait_"+name+".png")
func run():
	root.size=Vector2i(480,854);root.content_scale_size=Vector2i(480,854)
	b=load("res://main.tscn").instantiate();root.add_child(b)
	b.mobile_layout=true;b.compact_layout=true;b.animations_enabled=false;b.automation_pause=true
	b.account.set_process(false);b.account.configured=false;b.rewards.set_process(false)
	b.online.set_process(false);b.online.realtime.set_process(false);b.social.set_process(false)
	await frames()
	b.guest=true
	for name in ["intro","home","single","decks","account"]:
		await render_screen(name);await screenshot(name)
	b.account.user={"id":identity,"email":"qa@example.invalid","user_metadata":{"display_name":"Prueba local"}}
	b.account.access_token="offline-ui-fixture";b.account.expires_at=Time.get_unix_time_from_system()+3600
	b.session_owner=identity;b.guest=false;b.collection.owner_id=identity;b.collection.loaded=true;b.collection.gift={"deck_id":"kajido"}
	b.collection.decks=b.game.decklists.duplicate(true)
	for code in b.game.catalog:
		b.collection.cards[code]=3 if b.game.catalog[code].clase!="Recurso" else 18
		if b.game.catalog[code].clase!="Recurso":b.collection.shop.append({"code":code,"price":150})
	b.collection.restos=1250;b.collection.packs=3;b.collection.normal_packs=2;b.collection.server_day="2026-11-20"
	b.collection.missions=[{"id":"local","title":"Juega 1 partida","scope":"daily","target":1,"progress":0,"reward_kind":"restos","reward_amount":25,"claimed":false}]
	b.collection.challenges=[{"stage":1,"unlocked":true,"completed":false,"missions":[]}]
	for name in ["home","account","cards","shop","missions","packs","challenges","multiplayer","friends","trades"]:
		await render_screen(name);await screenshot(name)
	b.cards_tab="decks";await render_screen("cards");await screenshot("my_decks")
	b.online_ui.section="private";await render_screen("multiplayer")
	b.online.lobby_mode="join";b.online.selected_deck=str(b.collection.decks[0].id);await render_screen("multiplayer");await screenshot("join")
	b.catalog_detail("0100");await frames();check(b.overlay_shades.size()==1,"Portrait card detail opens")
	var center=b.overlay_shades.back().get_children().filter(func(n):return n is CenterContainer)[0]
	check(center.get_combined_minimum_size().x<=480,"Portrait card detail width fits")
	b.close_overlay(b.overlay_shades.back())
	b.preview_deck(b.collection.decks[0]);await frames();check(b.overlay_shades.size()==1,"Portrait deck preview opens");b.close_overlay(b.overlay_shades.back())
	b.deck_builder.owner=identity;b.deck_builder.editing={"id":"","nombre":"Prueba local","cartas":[],"custom":true,"draft":true,"portada":"custom_restos"}
	await render_screen("deck_builder");await screenshot("builder")
	b.tutorial.start();b.tutorial.begin();b.tutorial.active=false;b.game.take_visual_events();b.presenting=false;b.started=true;b.screen="table";b.render();await frames()
	check(is_instance_valid(b.action_panel),"Portrait board retains shared action panel")
	var resource=b.tutorial.refs.resource
	var source=b.targets.filter(func(n):return is_instance_valid(n) and n.uid==resource and n.zone=="hand")[0]
	var target=b.targets.filter(func(n):return is_instance_valid(n) and n.card_owner==b.human and n.zone=="resources")[0]
	check(b.tap_surface(source),"Portrait board selects the actual hand resource")
	check(b.tap_surface(target),"Portrait board plays a resource through shared rules")
	await frames()
	check(b.game.location(resource).zone=="resources","Resource changes zone on portrait board")
	check(b.action_panel.get_global_rect().end.y<=854,"Portrait action buttons fit: %s"%b.action_panel.get_global_rect().end.y)
	for node in b.interface_nodes(b.action_panel):
		if node is Button and node.visible:
			check(node.size.x>=140,"Portrait action has a readable touch width: "+node.text)
			check(node.size.y>=44,"Portrait action has a usable touch height: "+node.text)
	if b.action_panel.get_global_rect().end.y>854:
		for node in b.action_panel.get_parent().get_children():
			if node is Control:print("LAYOUT ",node.get_class()," ",node.get_global_rect()," min=",node.get_combined_minimum_size())
		for node in b.targets:
			if is_instance_valid(node) and node.card_owner==b.human and node.get_meta("pile",false):print("PILE ",node.zone," ",node.get_global_rect()," ",node.get_combined_minimum_size())
	await screenshot("board")
	b.show_configuration();await frames();check(b.overlay_shades.size()==1,"Portrait configuration opens")
	b.close_overlay(b.overlay_shades.back());b.show_audio_settings();await frames();check(b.overlay_shades.size()==1,"Portrait sound controls open")
	b.close_overlay(b.overlay_shades.back());b.show_game_settings();await frames();check(b.overlay_shades.size()==1,"Portrait game settings open")
	b.close_overlay(b.overlay_shades.back())
	b.account.access_token="";b.queue_free();await frames()
	print(JSON.stringify({"portrait":{"checks":checks,"failures":failures,"remote_writes":0}}))
	quit(0 if failures.is_empty() else 1)
