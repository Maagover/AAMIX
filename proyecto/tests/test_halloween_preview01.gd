extends SceneTree
const Game=preload("res://game.gd")
const Rules=preload("res://deck_rules.gd")
const Bot=preload("res://ai.gd")
const Snapshot=preload("res://multiplayer_snapshot.gd")
var checks=0
var failures=[]
var ui
var capture_dir=""
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):capture_dir=a.trim_prefix("--captures=")
	run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle():
	for i in range(8):await process_frame
func add(g,p,c,z):
	var u=g.spawn(c,p);g.instances[u].entered=1;g.players[p][z].append(u);return u
func fresh(plan="fixture"):
	var g=Game.new()
	for p in range(2):
		var state={"name":"Prueba","deck_id":plan}
		for z in g.ZONES:state[z]=[]
		g.players.append(state)
		for i in range(25):add(g,p,"0100","deck")
		for i in range(10):add(g,p,"0100","resources")
	g.turn=5;g.active=1;g.actor=1;g.phase="main";return g
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
func nodes(n):
	var found=[n]
	for c in n.get_children():found.append_array(nodes(c))
	return found
func wait_fx():
	var until=Time.get_ticks_msec()+8000
	while (ui.fx.busy or ui.presenting) and Time.get_ticks_msec()<until:await process_frame
	check(not ui.fx.busy and not ui.presenting,"Animation finishes at normal speed")
	await settle()
func run():
	root.size=Vector2i(1600,1000)
	var g=fresh();var bot=Bot.new()
	for h in Rules.VARIANTS:
		var u=add(g,1,h,"hand");var base=Rules.VARIANTS[h]
		check(g.code(u)==base and g.printed_code(u)==h,"Canonical rules and printed code "+h)
		check(g.definition(u).nombre==g.catalog[base].nombre and g.definition(u).coste==g.catalog[base].coste,"Original name and cost "+h)
		var normal=add(g,1,base,"hand")
		check(g.agile(u)==g.agile(normal) and g.unblockable(u)==g.unblockable(normal),"Shared passive keywords "+h)
	var deck=JSON.parse_string(FileAccess.get_file_as_string("res://data/mazo_halloween.json"))
	check(Rules.validate(deck,g.catalog).ok,"Exact forty-card Halloween rival is valid")
	var mixed={"draft":false,"cartas":[{"codigo":"0100","cantidad":37},{"codigo":"0127","cantidad":2},{"codigo":"H03","cantidad":1}]}
	check(Rules.validate(mixed,g.catalog).ok,"Mixed three Girabl accepted")
	mixed.cartas[0].cantidad=36;mixed.cartas[2].cantidad=2
	check(not Rules.validate(mixed,g.catalog).ok,"Mixed four Girabl rejected")
	mixed.cartas=[{"codigo":"0100","cantidad":38},{"codigo":"0103","cantidad":1},{"codigo":"H05","cantidad":1}]
	check(not Rules.validate(mixed,g.catalog).ok,"Original plus Halloween Singular rejected")
	g=fresh();var j=add(g,1,"H01","hand");var target=add(g,1,"0114","deck")
	check(g.request_play(j) and g.pending.get("kind","")=="search_hand" and target in g.pending.options,"H01 executes Javieriv search")
	g=fresh();var gira=add(g,1,"H03","defense");add(g,1,"01a","defense")
	check(g.agile(gira) and g.force(gira)==int(g.catalog.H03.fuerza)+2,"H03 receives Peri strength and Agile")
	g=fresh();var counter=add(g,1,"H02","defense");var cast=add(g,0,"0114","hand");g.active=0;g.actor=0
	check(g.request_play(cast) and g.pending.get("kind","")=="counter" and counter in g.pending.options,"H02 offers Serandimini counter")
	check(g.choose([counter]) and counter in g.players[1].deck and cast in g.players[0].graveyard,"H02 shuffles itself and cancels rival card")
	g=fresh();var flaan=add(g,1,"H05","defense");add(g,1,"0112","defense");add(g,1,"0113","defense")
	check(g.unblockable(flaan) and g.force(flaan)==4,"H05 uses Yuri/Celia effect")
	g=fresh();var depul=add(g,1,"H04","defense")
	check(g.unblockable(depul),"H04 remains unblockable")
	g=fresh("papito");var papito=add(g,1,"0115","deck");var o=[]
	for i in range(3):o.append(add(g,1,"0106","hand"))
	g.players[1].resources=g.players[1].resources.slice(0,2)
	check(bot.hold_oscars(g,o[0],1),"Papito holds Oscars below three available resources")
	add(g,1,"0100","resources")
	check(not bot.hold_oscars(g,o[0],1),"Papito releases Oscars when all three can be paid")
	for u in o:g.players[1].hand.erase(u);g.players[1].defense.append(u);g.instances[u].entered=g.turn
	g.players[1].deck.erase(papito);g.players[1].hand.append(papito)
	check(bot.play_score(g,papito,1)<0,"Papito waits until the turn after the Oscars")
	g.turn+=2
	check(bot.play_score(g,papito,1)>0,"Papito can play next own turn")
	g=fresh("papito");papito=add(g,1,"0115","deck");o=[]
	for i in range(3):o.append(add(g,1,"0106","hand"))
	g.players[1].resources=g.players[1].resources.slice(0,3)
	for i in range(3):check(bot.try_play(g,1),"Papito plays Oscar "+str(i+1)+" in the same turn")
	check(g.count_code(1,"0106")==3,"All three Oscars deployed together")
	check(bot.step(g,1) and g.pending.get("kind","")=="search_hand","Oscars activate to search Papito")
	bot.choose_pending(g,1)
	check(papito in g.players[1].hand,"Oscars bring Papito into hand")
	g=fresh("flaan");var protected=add(g,1,"0112","defense");var attacker_equal=add(g,0,"0108","defense")
	g.active=0;g.actor=0;g.declare_attack([attacker_equal]);bot.block(g,1)
	check(protected not in g.blocks.values(),"Flaan protects Yuri from an equal-force trade")
	for code in ["0110","0104","0108","0111"]:
		g=fresh();var fodder=add(g,1,code,"defense");var big=add(g,0,"0115","defense")
		g.active=0;g.actor=0;g.declare_attack([big]);bot.block(g,1)
		check(fodder in g.blocks.values(),"Willing defender "+code+" blocks even if it may die")
	g=fresh("flaan");var y=add(g,1,"0112","deck");var celia=add(g,1,"0113","deck");var otherj=add(g,1,"0104","deck")
	g.pending={"kind":"search_hand","player":1,"title":"Javieriv: busca y muestra","options":[otherj,y,celia],"min":0,"max":1,"optional":true,"shuffle":true}
	bot.choose_pending(g,1)
	check(otherj in g.players[1].deck and (y in g.players[1].hand or celia in g.players[1].hand),"Javieriv searches Flaan support instead of chaining Javieriv")
	g=fresh("kajido");var k=add(g,1,"0105","hand");var support=add(g,1,"0104","hand")
	check(bot.strategic_value(g,k,1)>bot.strategic_value(g,support,1) and bot.strategic_value(g,support,1)>0,"Kajido values its finisher and support tribes")
	g=fresh("maago");var d=add(g,1,"0107","hand");var m=add(g,1,"0124","hand");var mog=add(g,1,"0109","defense")
	check(bot.strategic_value(g,d,1)>0 and bot.strategic_value(g,m,1)>0,"Maago values Dicky and Miku")
	g.domain_uid=add(g,1,"0122","stack");check(bot.strategic_value(g,mog,1)>0,"Maago strengthens Mog with a domain")
	g=fresh("girabl");var attacker=add(g,1,"0110","defense");add(g,0,"0115","defense");bot.step(g,1)
	check(attacker in g.attacks,"Girabl attacks even into stronger defense")
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=true
	ui.account.set_process(false);ui.account.configured=false;ui.online.set_process(false);ui.online.realtime.set_process(false);ui.rewards.set_process(false)
	await settle();ui.play_guest();await settle()
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name")=="AAMIX_Halloween_Prueba01","Preview local profile is separate")
	check(ui.home_background.halloween and ui.sound.music_track=="halloween","Halloween background and original music active")
	check(nodes(ui).filter(func(n):return n.has_meta("interface_decoration") and str(n.get_meta("interface_decoration"))=="halloween_web").size()==5,"Two corner webs and three decorated buttons")
	await capture("01-inicio-halloween")
	check(ui.rewards.HalloweenPackArt.texture(false)!=null and ui.rewards.HalloweenPackArt.texture(true)!=null,"Both Halloween wrappers load without import cache")
	for code in Rules.VARIANTS:check(ui.texture_code(code)!=null,"PNG loads "+code)
	g=fresh();var atk=add(g,0,"0110","defense");var defender=add(g,1,"0112","defense");var grave=add(g,1,"H01","graveyard")
	g.active=0;g.actor=0;g.declare_attack([atk]);g.assign_block(atk,defender);g.take_visual_events()
	ui.game=g;ui.human=1;ui.computer=0;ui.started=true;ui.active_deck_id="fixture";ui.screen="table";ui.render();await settle()
	check(ui.fx.block_lines.size()==1,"Blocking link exists before inspection")
	check(ui.cancel_block_on_click(defender),"Click assigned defender cancels its block")
	await wait_fx();check(g.blocks.is_empty(),"Cancelled block removed from rules")
	g.assign_block(atk,defender);g.take_visual_events();ui.render();await settle()
	ui.fx.begin(ui,[],ui.capture_layout())
	check(nodes(ui.fx).filter(func(n):return n is ColorRect).all(func(n):return n.mouse_filter==Control.MOUSE_FILTER_IGNORE),"Animation does not shield inspection buttons")
	ui.inspect_zone(1,"graveyard");await settle()
	check(ui.inspection.is_open() and ui.modal_layer.layer>ui.fx.layer and not ui.modal_blocks_play(),"Reader stays above effects and does not pause rules")
	ui.set_visual_uid_alpha(grave,0)
	check(ui.targets.filter(func(n):return n.zone=="inspection").all(func(n):return n.modulate.a==1),"Board movement cannot hide reader cards")
	ui.fx.cancel(false);ui.presenting=false
	var later=add(g,1,"H04","graveyard");ui.render();await settle()
	check(ui.inspection.is_open() and ui.inspection.grid.get_child_count()==2,"Reader survives renders and refreshes arrivals")
	await capture("02-cementerio-sobre-bloqueo")
	g.actor=0;g.phase="main";g.pending={};ui.automation_pause=false;ui.bot_clock=1;ui._process(1)
	check(ui.inspection.is_open(),"AI can continue under the reader")
	ui.automation_pause=true;await wait_fx()
	g.winner=1;g.phase="finished";ui.winner_announced=false;ui.render();await settle()
	check(ui.inspection.is_open() and ui.overlay_shades[0].get_meta("overlay_kind")=="result","Result stays beneath manually opened reader")
	check(not ui.sound.music_player.playing,"Result stops Halloween music too")
	await capture("03-lector-sobre-victoria")
	ui.inspection.close();await settle()
	check(not ui.inspection.is_open(),"Reader closes only on explicit close")
	ui.online.clear();ui.reset_match()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000190"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.session_owner=ui.account.player_id();ui.guest=false
	ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true;ui.collection.packs=3;ui.collection.normal_packs=3;ui.collection.halloween_packs=10
	ui.collection.restos_welcome_claimed=true;ui.collection.welcome_pack={"claimed":true}
	var event=null
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events:
		if item.id=="halloween_2026":event=item.duplicate(true)
	for mission in event.missions:mission.progress=0;mission.claimed=false
	ui.collection.events=[event];ui.collection.events_deadline_tick=Time.get_ticks_msec()+3600000
	ui.screen="event";ui.render();await settle()
	check(nodes(ui).filter(func(n):return n.has_meta("event_mission_row")).size()==6,"Six Halloween mission rows rendered")
	check(ui.event_battle_available(),"Server-active event enables event battle")
	await capture("04-evento-halloween")
	ui.screen="single";ui.render();await settle()
	check(nodes(ui).any(func(n):return n.has_meta("event_battle_button")),"Partida de Evento appears in single player")
	await capture("05-partida-de-evento")
	ui.screen="packs";ui.render();await settle()
	check(nodes(ui).filter(func(n):return n is Button and n.has_meta("pack_quantity")).size()==3,"TC, normal and Halloween packs are separate")
	await capture("06-tres-sobres")
	ui.collection.pending_opening={"opening_id":"fixture-h05","kind":"halloween","cards":["H05"],"new_card_indices":[0]}
	ui.render();await settle()
	var reveal=nodes(ui).filter(func(n):return n.has_meta("pack_reveal"))[0]
	check(reveal.cards.size()==1 and reveal.pack_kind=="halloween","Halloween wrapper holds one card")
	await capture("07-sobre-halloween")
	reveal.open_packet()
	var until=Time.get_ticks_msec()+7000
	while reveal.animating and Time.get_ticks_msec()<until:await process_frame
	await settle()
	check(not reveal.sealed and reveal.singular_shown and not ui.sound.music_player.playing,"H05 reveals with Singular celebration after music fades")
	check(ui.sound.recent.any(func(n):return str(n.get("name",""))=="singular"),"H05 retains treasure sound")
	await capture("08-h05-singular")
	ui.online.clear();ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"halloween_preview01":{"checks":checks,"failures":failures,"random_simulations":0,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
