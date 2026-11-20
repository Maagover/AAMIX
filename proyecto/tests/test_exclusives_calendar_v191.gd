extends SceneTree
var ui
var checks=0
var failures=[]
var captures=""
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):captures=a.trim_prefix("--captures=")
	run.call_deferred()
func nodes(n):
	var result=[n]
	for child in n.get_children():
		if not child.is_queued_for_deletion():result.append_array(nodes(child))
	return result
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle():
	for i in range(5):await process_frame
func capture(name):
	if captures.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(captures)
	var scroll=nodes(ui).filter(func(n):return n.has_meta("collection_scroll"))[0]
	scroll.scroll_vertical=100000
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func run():
	root.size=Vector2i(1600,1000)
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	for n in [ui.account,ui.online,ui.online.realtime,ui.rewards,ui.social]:n.set_process(false)
	ui.account.configured=false
	ui.account.user={"id":"00000000-0000-4000-8000-000000000191"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	var c=ui.collection;c.loaded=true;c.owner_id=ui.account.player_id();c.cards={"0100":62,"0104":2,"H03":1};c.gift={"deck_id":"papito"};c.restos_welcome_claimed=true;c.welcome_pack={"claimed":true};c.events=[]
	ui.session_owner=c.owner_id;ui.guest=false;ui.screen="cards";ui.cards_tab="collection"
	var ordinary=ui.game.catalog.values().filter(func(d):return not d.get("event_exclusive",false)).size()
	for day in ["","2026-10-27","2026-10-29","2026-10-30","2026-11-01","2026-11-02"]:
		c.server_day=day;ui.render();await settle()
		var opened=not day.is_empty() and day>="2026-10-30"
		var all=nodes(ui)
		check(all.any(func(n):return n is Label and n.text=="Cartas Exclusivas")==opened,"Section follows server start on "+day)
		check(all.filter(func(n):return n.has_meta("collection_exclusive_grid")).size()==(1 if opened else 0),"No hidden empty grid or placeholders on "+day)
		var expected="%d cartas · %d de %d cartas coleccionadas"%[65 if opened else 64,3 if opened else 2,ui.game.catalog.size() if opened else ordinary]
		check(all.any(func(n):return n is Label and n.text==expected),"Counter excludes unreleased cards on "+day)
		check(all.any(func(n):return n is Label and n.text=="Promocionales"),"Promotional section retained on "+day)
		if day=="2026-10-27":await capture("01-antes-del-evento")
		if day=="2026-10-30":await capture("02-desde-el-evento")
	c.server_day="";c.events=[{"id":"halloween_2026"}];c.events_deadline_tick=Time.get_ticks_msec()+60000
	check(ui.collection_card_visible("H01"),"Server-active event also reveals its cards")
	c.events_deadline_tick=Time.get_ticks_msec()-1
	check(not ui.collection_card_visible("H01"),"Expired event state cannot reveal a future collection")
	c.events=[];c.server_day="2026-10-30";ui.game.catalog.H01.collection_visible_from="2026-12-01";ui.game.catalog.H01.event_id="future_fixture"
	check(not ui.collection_card_visible("H01") and ui.collection_card_visible("H02"),"Future exclusive cards stay hidden individually")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="AAMIX","Official data directory retained")
	ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"exclusives_calendar_v191":{"checks":checks,"failures":failures,"network_requests":0,"random_draws":0}}))
	quit(0 if failures.is_empty() else 1)
