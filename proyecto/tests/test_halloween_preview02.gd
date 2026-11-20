extends SceneTree
const Game=preload("res://game.gd")
const Reveal=preload("res://pack_reveal.gd")
var ui
var checks=0
var failures=[]
var captures=""
class FixtureCollection extends "res://collection.gd":
	var calls=[]
	func request(endpoint,body):
		calls.append({"endpoint":endpoint,"body":body.duplicate(true)})
		if endpoint=="aamix_acknowledge_opening":pending_opening=null;return true
		var kind=body.get("p_kind","tc")
		var codes=["H05","H01","H05"] if kind=="halloween" else []
		if kind=="tc":
			for i in range(packs):codes.append_array(["0100","0104","0107","0120","0119"])
		elif kind=="normal_card":
			for i in range(normal_packs):codes.append("0104")
		pending_opening={"opening_id":"fixture-bundle-"+kind,"kind":kind,"pack_count":3 if kind=="halloween" else packs if kind=="tc" else normal_packs,"cards":codes,"new_card_indices":[0,1]}
		return true
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):captures=a.trim_prefix("--captures=")
	run.call_deferred()
func nodes(n):
	var found=[n]
	for c in n.get_children():
		if not c.is_queued_for_deletion():found.append_array(nodes(c))
	return found
func marked(key):return nodes(ui).filter(func(n):return n.has_meta(key))
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle():
	for i in range(8):await process_frame
func capture(name):
	if captures.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(captures)
	await create_timer(.15).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func cue(name):return ui.sound.recent.filter(func(e):return e.name==name).size()
func idle(view):
	var deadline=Time.get_ticks_msec()+5000
	while view.animating and Time.get_ticks_msec()<deadline:await process_frame
	check(not view.animating,"Finite pack animation")
	await settle()
func navigation():return nodes(ui).any(func(n):return n is Button and (n.has_meta("navigation_control") or n.has_meta("interface_close") or n.text=="←"))
func fresh():
	var g=Game.new()
	for p in range(2):
		var state={"name":"Prueba","deck_id":"fixture"}
		for z in g.ZONES:state[z]=[]
		g.players.append(state)
		for i in range(25):var u=g.spawn("0100",p);state.deck.append(u)
	g.turn=5;g.active=0;g.actor=0;g.phase="main";return g
func run():
	root.size=Vector2i(1600,1000)
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	for n in [ui.account,ui.online,ui.online.realtime,ui.rewards,ui.social]:n.set_process(false)
	ui.account.configured=false
	await settle();check(navigation(),"Intro has exit X")
	ui.play_guest();await settle()
	check(marked("interface_decoration").filter(func(n):return str(n.get_meta("interface_decoration"))=="halloween_web").size()==4,"Two corners plus only two menu spiders")
	var decorated=nodes(ui).filter(func(n):return n is Button and nodes(n).any(func(c):return c.has_meta("interface_decoration") and str(c.get_meta("interface_decoration"))=="halloween_web")).map(func(n):return n.text)
	check(decorated==["Partida individual","Misiones"],"Only Individual and Missions buttons have spiders")
	check(navigation(),"Home has exit X")
	await capture("01-inicio-dos-aranas")
	var old=ui.collection;old.changed.disconnect(ui.collection_changed)
	var c=FixtureCollection.new();ui.collection=c;c.account=ui.account;ui.add_child(c);c.changed.connect(ui.collection_changed);old.queue_free()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000192"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.session_owner=ui.account.player_id();ui.guest=false;c.loaded=true;c.owner_id=ui.account.player_id();c.gift={"deck_id":"papito"};c.restos_welcome_claimed=true;c.welcome_pack={"claimed":true};c.decks=ui.game.decklists.duplicate(true)
	c.packs=5;c.normal_packs=4;c.halloween_packs=3
	for code in ui.game.catalog:c.cards[code]=3
	var event=null
	for e in JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events:
		if e.id=="halloween_2026":event=e.duplicate(true)
	for m in event.missions:m.progress=0;m.claimed=false
	c.events=[event];c.events_deadline_tick=Time.get_ticks_msec()+3600000
	for screen in ["single","cards","missions","event","packs","shop","friends","trades","multiplayer","account"]:
		ui.screen=screen;ui.render();await settle()
		check(ui.sound.music_track=="halloween","Halloween music retained in "+screen)
		check(navigation(),"Back arrow or close X in "+screen)
	ui.screen="event";ui.render();await settle()
	check(marked("event_headliner").map(func(n):return n.get_meta("event_headliner"))==["H02","H05"],"Both Halloween headliners visible in one stack")
	await capture("02-evento-dos-cartas")
	ui.screen="single";ui.render();await settle()
	check(marked("event_pumpkin_icon").size()==1,"Event battle has AAMIX pumpkin")
	await capture("03-calabaza-evento")
	var cover=ui.deck_cover_texture({"id":"halloween"})
	check(cover!=null and cover.get_width()>0,"Halloween rival has a real cover")
	ui.show_notice("Mazo Halloween","Portada nueva con SoyFlaan H05");var center=ui.overlay_shades.back().get_child(0)
	# Cover screenshot in the existing deck viewer/versus size.
	ui.close_overlay(ui.overlay_shades.back());ui.pending_match={"deck_id":str(c.decks[0].id),"stage":0,"event_battle":true,"opponent":JSON.parse_string(FileAccess.get_file_as_string("res://data/mazo_halloween.json"))};ui.screen="versus";ui.render();await settle();await capture("04-portada-halloween")
	ui.screen="cards";ui.cards_tab="collection";ui.render();await settle()
	var exclusive=marked("collection_exclusive_grid")[0]
	check(nodes(exclusive).filter(func(n):return n.has_meta("collection_code")).map(func(n):return n.get_meta("collection_code"))==["H01","H02","H03","H04","H05"],"Five Halloween cards in exclusive section")
	var ordinary=marked("collection_grid")[0]
	check(not nodes(ordinary).any(func(n):return n.has_meta("collection_code") and str(n.get_meta("collection_code")).begins_with("H")),"Event cards absent from ordinary grid")
	check(exclusive.get_index()>marked("collection_promotional_row")[0].get_index(),"Exclusive section below Promos")
	var sc=marked("collection_scroll")[0];sc.scroll_vertical=100000;await settle();await capture("05-exclusivas")
	var g=fresh();var card=g.spawn("H05",0);g.players[0].defense.append(card);g.instances[card].entered=1
	ui.game=g;ui.human=0;ui.computer=1;ui.started=true;ui.active_deck_id="fixture";ui.active_event_battle=true
	for dark in [false,true]:
		ui.dark_theme=dark;ui.apply_visual_palette();ui.theme=ui.visual_theme.make_theme();ui.screen="table";ui.render();await settle()
		check(ui.sound.music_track=="random","Event battle uses original battle track")
		ui.open_card_detail(card);await settle()
		var ability=marked("card_ability_text")[0]
		check(ability.get_theme_color("default_color")==ui.TEXT,"Card rules inherit readable theme")
		var close=marked("interface_close").back()
		check(close.get_theme_color("font_color")==ui.TEXT,"Modal button text follows theme")
		check(close.theme==ui.theme,"Canvas modal controls have explicit AAMIX theme")
		await capture("06-detalle-oscuro" if dark else "06-detalle-claro")
		if not dark:
			for pressed in [true,false]:
				var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;click.position=close.get_global_rect().get_center();click.global_position=click.position
				root.push_input(click,true)
		else:close.pressed.emit()
		await settle();check(not ui.modal_open,"Close X returns from card detail through real hit testing")
	ui.active_challenge_stage=1;ui.render();check(ui.sound.music_track=="challenge","Challenge retains original challenge track")
	g.pending={"kind":"search_hand","player":0,"title":"Elección pendiente de prueba","options":[card],"min":0,"max":1,"optional":true,"shuffle":false};ui.render();await settle()
	var pending_before=g.pending.duplicate(true)
	marked("interface_close").back().pressed.emit();await settle()
	check(g.pending==pending_before and ui.choice_dismissed and not ui.modal_open,"Closing a choice never silently skips its rule")
	check(nodes(ui).any(func(n):return n is Button and n.text=="Resolver elección"),"Closed pending choice can be reopened")
	ui.resume_choice();await settle();check(ui.modal_open and not ui.choice_dismissed,"Pending choice reopens safely")
	g.pending={};ui.render()
	ui.active_challenge_stage=0;g.winner=0;g.phase="finished";ui.render();check(not ui.sound.music_player.playing,"Result still stops battle music")
	ui.dark_theme=false;ui.apply_visual_palette();ui.theme=ui.visual_theme.make_theme();ui.started=false;ui.screen="packs";ui.render();await settle()
	check(marked("open_all_packs").size()==3,"All three pack kinds have open-all controls")
	await capture("07-abrir-todos")
	await ui.rewards.start_opening("halloween",true)
	check(c.calls.back().endpoint=="aamix_open_all_packs" and c.calls.back().body.p_kind=="halloween","Open-all button uses bundle endpoint and correct kind")
	var view=marked("pack_reveal")[0]
	check(view.cards.size()==3 and view.layers.get_child_count()==2,"Batch keeps a bounded current/next stack")
	var tears=cue("sobre_abrir");var treasure=cue("singular")
	view.open_packet()
	var until=Time.get_ticks_msec()+5000
	while view.sealed or view.opening_stage!="cards":
		if Time.get_ticks_msec()>until:break
		await process_frame
	await create_timer(.08).timeout
	check(view.current.texture==ui.texture_code("H05") and view.current.scale.y>1.05,"Singular first zooms while its face remains readable")
	await create_timer(.55).timeout
	check(view.current.texture==ui.asset_texture("dorso.jpg") and view.current.scale.y>1.15,"Singular zoom shows its back halfway through full rotation")
	check(view.layers.get_children().filter(func(n):return n!=view.current).all(func(n):return not n.visible),"Spin does not reveal the next card early")
	await capture("08-singular-reverso")
	await idle(view)
	check(view.current.texture==ui.texture_code("H05") and view.current.scale.is_equal_approx(Vector2.ONE),"Full rotation returns face and scale to normal")
	check(cue("singular")==treasure+1,"First Singular retains one treasure cue")
	view.slide_card();await idle(view)
	check(view.revealed==1 and not view.sealed,"Next card appears without another wrapper")
	view.slide_card();await idle(view)
	check(view.revealed==2 and cue("singular")==treasure+2,"Second Singular in same bundle also celebrates")
	check(cue("sobre_abrir")==tears+1,"Exactly one wrapper animation/sound for bundle")
	ui.render();await settle();view=marked("pack_reveal")[0]
	check(not view.sealed and not view.animating and cue("singular")==treasure+2,"Refresh resumes current batch card without repeating tear or epic cue")
	view.slide_card();await create_timer(.35).timeout;await settle()
	check(marked("pack_reveal").is_empty(),"Batch reaches grouped results after its last card")
	await capture("09-resultado-lote")
	await ui.rewards.finish_opening()
	for kind in ["tc","normal_card"]:
		await ui.rewards.start_opening(kind,true);view=marked("pack_reveal")[0]
		check(view.cards.size()==(25 if kind=="tc" else 4) and view.pack_kind==kind,"Bundle renders full count for "+kind)
		check(view.layers.get_child_count()==2,"Bounded card stack for "+kind)
		await ui.rewards.finish_opening()
	var receipt_close=marked("interface_close")
	check(Reveal.normalize_new_indices([0,5,14,49999,-1,50000])==[0,5,14,49999],"New-card stars support indices beyond five")
	var large=Reveal.new().configure(ui,Array().duplicate(),0,true)
	large.cards=[]
	for i in range(500):large.cards.append("H01")
	ui.add_child(large);await settle()
	check(large.layers.get_child_count()==2,"Large batches do not create hundreds of card nodes")
	large.queue_free()
	ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"halloween_preview02":{"checks":checks,"failures":failures,"network_requests":0,"random_pack_draws":0}}))
	quit(0 if failures.is_empty() else 1)
