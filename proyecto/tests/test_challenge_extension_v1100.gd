extends SceneTree
const Game=preload("res://game.gd")
const Bot=preload("res://ai.gd")
const Rules=preload("res://deck_rules.gd")
class FixtureCollection:
	extends "res://collection.gd"
	var requested_stages=[]
	func begin_match(_request_id,deck_id,stage=0,_event=false):
		requested_stages.append(stage)
		await get_tree().process_frame
		last_reply={"match_id":"local-receipt-"+str(stage),"match_deck":{"id":deck_id,"nombre":"QA","cartas":[{"codigo":"0100","cantidad":40}]}}
		return true
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
	for c in n.get_children():
		if not c.is_queued_for_deletion():result.append_array(nodes(c))
	return result
func marked(key):return nodes(ui).filter(func(n):return n.has_meta(key))
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle():
	for i in range(6):await process_frame
func capture(name):
	if captures.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(captures);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func add(g,p,c,z):
	var uid=g.spawn(c,p);g.instances[uid].entered=1;g.players[p][z].append(uid);return uid
func fresh(plan):
	var g=Game.new()
	for p in range(2):
		var state={"name":"Prueba","deck_id":plan if p==1 else "fixture"}
		for z in g.ZONES:state[z]=[]
		g.players.append(state)
		for i in range(25):add(g,p,"0100","deck")
		for i in range(12):add(g,p,"0100","resources")
	g.turn=7;g.active=1;g.actor=1;g.phase="main";return g
func search(g,bot,options,title,count):
	g.pending={"kind":"search_hand","player":1,"title":title,"options":options,"min":0,"max":count,"optional":true,"shuffle":true}
	return bot.choose_pending(g,1)
func run():
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/desafio_aamix.json"))
	var g=Game.new();var bot=Bot.new()
	check(data.levels.size()==11 and data.new_decks.size()==6,"Eleven levels and six new decks")
	for deck in data.new_decks:
		check(Rules.validate(deck,g.catalog).ok,"Forty-card rules valid for "+deck.id)
		check(deck.cartas.reduce(func(total,c):return total+int(c.cantidad),0)==40,"Exact list size "+deck.id)
		check(data.levels[deck.challenge_stage-1].reward_packs==3,"Three TC packs "+deck.id)
	g=fresh("dominios");var mog=add(g,1,"0109","deck");var sam=add(g,1,"0114","deck");var j=add(g,1,"0104","deck")
	check(search(g,bot,[j,sam,mog],"Javieriv: busca y muestra",1) and mog in g.players[1].hand,"Dominios Javieriv searches Mog instead of itself")
	g=fresh("dominios");var discovery=add(g,1,"0132","deck");var conflict=add(g,1,"0116","deck")
	check(search(g,bot,[conflict,discovery],"Sam: busca y muestra",1) and discovery in g.players[1].hand,"Sam obtains domain search when no Domain exists")
	var domain=add(g,1,"0121","hand");check(bot.play_score(g,domain,1)>20,"Dominios prioritizes establishing a Domain")
	g=fresh("miku");var dicky=add(g,1,"0107","defense");var maago=add(g,1,"0108","defense");var miku=add(g,1,"0124","hand")
	check(bot.best_target(g,miku,1)==dicky,"Miku equips Dicky before Maagover")
	var fernando=add(g,1,"0110","hand");check(bot.play_score(g,fernando,1)<0,"Miku holds Feranando until a permanent can be removed")
	var talca=add(g,0,"0122","stack");g.domain_uid=talca;var enemy_object=add(g,0,"0124","stack")
	g.pending={"kind":"remove_permanent","player":1,"title":"Feranando","options":[enemy_object,talca],"min":1,"max":1,"optional":true}
	check(bot.choose_pending(g,1) and g.domain_uid==-1,"Feranando removes Talca before a lower-priority Object")
	g=fresh("tsuki_akira");var options=[]
	for code in ["0112","0112","0112","0113","0113","01a"]:options.append(add(g,1,code,"deck"))
	check(search(g,bot,options,"Raid de Nanchy: busca y muestra",3),"Tsuki Raid search resolves")
	check(g.players[1].hand.any(func(u):return g.code(u)=="0112") and g.players[1].hand.any(func(u):return g.code(u)=="0113") and g.players[1].hand.any(func(u):return g.code(u)=="01a"),"Raid balances Yuri, Celia and Peri")
	var flaan=add(g,1,"0103","deck");var tsuki=add(g,1,"01c","deck")
	check(search(g,bot,[tsuki,flaan],"Desaparición de Papito: busca y muestra",1) and flaan in g.players[1].hand,"Desaparición searches SoyFlaan for Tsuki deck")
	g=fresh("imbloqueable");dicky=add(g,1,"0107","defense");maago=add(g,1,"0108","defense");j=add(g,1,"0104","defense");add(g,0,"0111","defense")
	var unblockable=bot.unblockable_candidates(g,1)
	check(dicky not in unblockable and maago in unblockable and j in unblockable,"Almenta targets allies that need Imbloqueable")
	g=fresh("transmision");var kajido=add(g,1,"0105","hand");check(bot.play_score(g,kajido,1)<0,"Final deck builds allies before Kajido")
	for code in ["0104","0108","0111"]:add(g,1,code,"defense")
	check(bot.play_score(g,kajido,1)>0,"Kajido can enter after board develops")
	var viborin=add(g,1,"0126","defense");var fodder=bot.sacrifice_candidates(g,viborin,1)
	check(fodder.any(func(u):return g.code(u)=="0104") and not fodder.any(func(u):return g.code(u)=="0108"),"Viborín can use a spent support while preserving combo Maagover")
	root.size=Vector2i(1600,1000);ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.automation_pause=true;ui.animations_enabled=false
	for n in [ui.account,ui.online,ui.online.realtime,ui.rewards,ui.social]:n.set_process(false)
	ui.account.configured=false;ui.account.user={"id":"00000000-0000-4000-8000-000000001100"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	var c=ui.collection;c.loaded=true;c.owner_id=ui.account.player_id();ui.session_owner=c.owner_id;ui.guest=false;c.gift={"deck_id":"papito"};c.restos_welcome_claimed=true;c.welcome_pack={"claimed":true};c.decks=ui.game.decklists.duplicate(true)
	var states=[]
	for level in data.levels:var entry=level.duplicate(true);entry.unlocked=level.stage<=6;entry.completed=level.stage<=5;entry.reward_claimed=entry.completed;states.append(entry)
	c.challenges=c.normalize_challenges(states);check(c.challenges.size()==11,"Server normalization accepts all eleven levels")
	ui.screen="challenges";ui.render();await settle();check(marked("challenge_stage").size()==11,"UI renders eleven level tiles")
	for tile in marked("challenge_stage"):
		if int(tile.get_meta("challenge_stage"))>=7:check(not nodes(tile).any(func(n):return n.has_meta("deck_cover")) and nodes(tile).any(func(n):return n is Label and n.text=="Bloqueado"),"Future level hidden "+str(tile.get_meta("challenge_stage")))
	await capture("01-niveles-iniciales")
	marked("challenge_scroll")[0].scroll_vertical=400;await settle();await capture("02-nivel-seis-desbloqueado")
	for deck in data.new_decks:
		check(ui.challenge_opponent(deck.challenge_stage).cartas==deck.cartas,"Correct opponent list "+deck.id)
		var texture=ui.deck_cover_texture(deck.id);check(texture!=null and texture.atlas!=null and texture.region.end.x<=texture.atlas.get_width() and texture.region.end.y<=texture.atlas.get_height(),"New cover registered "+deck.id)
	for entry in c.challenges:entry.unlocked=true;entry.completed=false
	ui.render();await settle();marked("challenge_scroll")[0].scroll_vertical=100000;await settle();await capture("03-ultimos-niveles")
	check(marked("challenge_stage").all(func(n):return n.get_global_rect().size.x<=270),"Tiles retain readable fixed width in scroll layout")
	c.available_custom_covers=Rules.FREE_COVERS.duplicate();check(not c.available_covers().has("custom_miku"),"New designs not available before unlock")
	c.available_custom_covers.append_array(data.new_decks.map(func(d):return d.reward_cover));ui.deck_builder.open();await settle();ui.deck_builder.open_design_picker();await settle()
	check(marked("deck_design_option").size()==8,"Six unlocked challenge designs join two standard covers")
	await capture("04-portadas-obtenidas")
	var fixture=FixtureCollection.new();ui.add_child(fixture);fixture.set_process(false);ui.collection=fixture
	for stage in [6,11]:
		ui.rewards.prepared_receipt={}
		var prepared=await ui.rewards.prepare_match("papito",stage)
		check(not prepared.is_empty() and fixture.requested_stages.back()==stage and ui.rewards.prepared_receipt.challenge_stage==stage,"Receipt preparation preserves stage "+str(stage))
		ui.rewards.match_started("papito",stage)
		check(ui.rewards.active_receipt.challenge_stage==stage and ui.rewards.active_receipt.begun,"Started match consumes correct prepared receipt "+str(stage))
	ui.rewards.prepared_receipt={};ui.rewards.match_started("papito",11)
	check(ui.rewards.active_receipt.challenge_stage==11 and not ui.rewards.active_receipt.begun,"Fallback receipt preserves final stage eleven")
	ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"challenge_extension_v1100":{"checks":checks,"failures":failures,"network_requests":0,"random_draws":0}}));quit(0 if failures.is_empty() else 1)
