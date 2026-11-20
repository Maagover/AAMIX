extends SceneTree
const Game=preload("res://game.gd")
const Bot=preload("res://ai.gd")
var bot=Bot.new()
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func fresh():
	var g=Game.new()
	for p in range(2):
		var state={"name":"Prueba IA","deck_id":"fixture"}
		for zone in g.ZONES:state[zone]=[]
		g.players.append(state)
		for i in range(40):
			var uid=g.spawn("0100",p);state["resources" if i<10 else "deck"].append(uid)
	g.turn=5;g.active=1;g.actor=1;g.phase="main";return g
func put(g,code,zone):
	var uid=g.players[1].deck.pop_front();g.instances[uid].code=code;g.instances[uid].entered=1;g.players[1][zone].append(uid);return uid
func small(g,n):
	while g.players[1].deck.size()>n:g.players[1].graveyard.append(g.players[1].deck.pop_front())
func run():
	var g=fresh();var first=put(g,"0108","hand");var second=put(g,"0108","hand")
	check(bot.try_play(g,1) and g.pending.get("kind")=="reorder","First Maagover is played and may reorder the top")
	bot.choose_pending(g,1)
	check(g.can_play(second),"Second Maagover would be legal under the card rules")
	check(bot.play_score(g,second,1)<0 and not bot.try_play(g,1),"AI avoids a second Maagover during the same turn")
	g.turn+=2
	check(bot.play_score(g,second,1)>0,"Another Maagover is allowed on a later turn")
	g=fresh();var raid=put(g,"0120","hand");g.instances[g.players[1].deck[-1]].code="0104";small(g,8)
	check(g.can_play(raid) and g.search_options({"player":1,"class":"Aliado","max_cost":2}).size()==1,"Eight-card fixture has a legal Raid and a real search target")
	check(bot.play_score(g,raid,1)<0 and not bot.try_play(g,1),"AI will not waste Raid when its deck has eight cards")
	check(g.players[1].deck.size()==8 and raid in g.players[1].hand,"Declining Raid spends neither deck cards nor the event")
	g=fresh();var bigotes=put(g,"01b","defense");g.instances[g.players[1].deck[-1]].code="0124";small(g,14)
	check(g.can_activate(bigotes) and not bot.useful_activation(g,bigotes,1),"Optional Bigotes search is declined below fifteen")
	g=fresh();g.instances[g.players[1].deck[-1]].code="0104";small(g,15)
	check(bot.safe_search(g,1,{"class":"Aliado"}),"Search remains available at fifteen cards")
	g.players[1].graveyard.append(g.players[1].deck.pop_front())
	check(not bot.safe_search(g,1,{"class":"Aliado"}),"Search is declined at fourteen cards")
	g=fresh();var javier=put(g,"0104","hand");g.instances[g.players[1].deck[-1]].code="0114";small(g,8)
	check(bot.try_play(g,1) and javier in g.field(1),"AI can still play a useful Ally and decline its optional search")
	bot.choose_pending(g,1)
	check(g.players[1].deck.size()==8 and g.pending.is_empty(),"Optional on-entry search does not reduce a small deck")
	g=fresh();var recovered=put(g,"0115","graveyard");g.instances[g.players[1].deck[-1]].code="0115";small(g,8)
	var options=g.search_options({"player":1,"code":"0115","zones":["deck","graveyard"]})
	g.pending={"kind":"search_hand","player":1,"options":options,"min":0,"max":1,"optional":true,"shuffle":true};
	check(bot.safe_search(g,1,{"code":"0115","zones":["deck","graveyard"]}),"Recovery from graveyard remains useful with a small deck")
	bot.choose_pending(g,1)
	check(recovered in g.players[1].hand and g.players[1].deck.size()==8,"Search chooses graveyard target instead of spending deck cards")
	g=fresh();small(g,8);g.phase="after_combat";bot.step(g,1)
	check(g.players[1].deck.size()==5 and g.players[1].hand.size()==3,"Mandatory ending draw/minimum hand still occur")
	check(g.invariant_errors().is_empty(),"Low-deck AI preserves all forty cards per player")
	# Search eligibility: all copies, with the actual card-specific restrictions.
	g=fresh();var cheap=put(g,"0112","deck");var costly=put(g,"0115","deck");var copy=put(g,"0112","deck");var item=put(g,"0124","deck")
	check(g.search_options({"player":1,"class":"Aliado"}).size()==3,"Unrestricted Ally search contains all three eligible physical cards")
	var limited=g.search_options({"player":1,"class":"Aliado","max_cost":2})
	check(limited.size()==2 and cheap in limited and copy in limited and costly not in limited and item not in limited,"Cost-restricted Ally search includes both copies and excludes only invalid targets")
	var singular=g.search_options({"player":1,"class":"Aliado","singular":true})
	check(singular==[costly],"Singular search respects its printed restriction")
	print(JSON.stringify({"ai_final_v180":{"checks":checks,"failures":failures,"random_simulations":0,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
