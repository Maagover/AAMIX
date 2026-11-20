extends "res://tests/test_compact_ui_v181.gd"
func run():
	root.size=Vector2i(1600,1000)
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	ui.account.set_process(false);ui.account.configured=false;ui.account.remember_me=false;ui.account.refresh_token=""
	ui.online.set_process(false);ui.online.realtime.set_process(false);ui.rewards.set_process(false);ui.social.set_process(false)
	await settle()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000181"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.session_owner=ui.account.player_id();ui.guest=false;ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true
	ui.collection.cards.clear()
	for code in ui.game.catalog:ui.collection.cards[code]=62
	ui.screen="cards";ui.cards_tab="collection";ui.render();await settle()
	var overflow=[]
	for caption in metas("collection_card_caption"):
		if caption.get_line_count()>2:overflow.append({"text":caption.text,"lines":caption.get_line_count()})
	print(JSON.stringify({"caption_layout":{"captions":metas("collection_card_caption").size(),"over_two_lines":overflow,"network_requests":0}}))
	ui.sound.shutdown();ui.queue_free();await settle();quit(0 if overflow.is_empty() else 1)
