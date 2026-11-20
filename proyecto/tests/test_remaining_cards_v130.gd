extends SceneTree
## Deterministic rule scenarios against the CURRENT engine. No server or real account.
const Game = preload("res://game.gd")
const REMAINING = ["0101","0118","0121","0125","0126","0128","0129","01d","01e","01f"]
var checks = 0
var failures = []
var scenarios = []
var result_path = ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--results="): result_path = arg.trim_prefix("--results=")
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL ",checks,": ",message)
	return ok

func fixture_deck(id):
	var quantities = {"0100":18,"0101":2,"0118":2,"0121":1,"0125":2,"0126":1,"0128":1,"0129":1,"01d":1,"01e":1,"01f":1,"0114":2,"0123":1,"0124":1,"0133":1,"0122":1,"0104":1,"0119":1,"0130":1}
	var entries = []
	for code in quantities: entries.append({"codigo":code,"cantidad":quantities[code]})
	return {"id":id,"nombre":"Fixture de diez cartas","custom":true,"draft":false,"portada":"custom_transmision","recurso_inicial":"0100","cartas":entries}

func fresh():
	var game = Game.new()
	assert(game.new_game(130, [fixture_deck("custom_fixture_a"),fixture_deck("custom_fixture_b")]),"Valid deterministic 40-card fixtures")
	game.keep_hand()
	game.keep_hand()
	game.active = 0
	game.actor = 0
	game.turn = 10
	game.phase = "main"
	game.take_visual_events()
	return game

func take(game, player, code, zone = "defense"):
	for source in ["deck","hand","graveyard","burned","defense","attack","resources","paid","stack"]:
		for uid in game.players[player][source].duplicate():
			if game.code(uid) != code: continue
			game.players[player][source].erase(uid)
			game.players[player][zone].append(uid)
			game.instances[uid].entered = 1
			return uid
	assert(false,"Fixture card is available: "+code)
	return -1

func resources(game, player, amount = 12):
	while game.players[player].resources.size() < amount: take(game,player,"0100","resources")

func own_turn(game, player):
	game.active = player
	game.actor = player
	game.phase = "main"

func audit(game, scenario):
	check(game.instances.size() == 80 and game.invariant_errors().is_empty(),"80-card/zone conservation: "+scenario)
	scenarios.append(scenario)

func pending(game, kind, message):
	return check(game.pending.get("kind", "") == kind,message)

func equip(game, player, code, carrier):
	own_turn(game,player)
	resources(game,player)
	var uid = take(game,player,code,"hand")
	check(game.request_play(uid,carrier),"Equip "+code+" through normal play")
	return uid

func domain(game, player, code):
	own_turn(game,player)
	resources(game,player)
	var uid = take(game,player,code,"hand")
	check(game.request_play(uid),"Play domain "+code+" through normal play")
	return uid

func resolve_battle(game, attacker, blocker):
	check(game.declare_attack([attacker]),"Declare focused attack")
	check(game.assign_block(attacker,blocker),"Assign focused combat block")
	check(game.finish_blocks(),"Finish focused block selection")
	var passes = 0
	while game.phase == "events" and passes < 2:
		check(game.pass_priority(),"Pass combat priority")
		passes += 1

func test_nonungus():
	var game = fresh()
	resources(game,0)
	var sam = take(game,0,"0114","deck")
	var nonungus = take(game,0,"0101","hand")
	check(game.request_play(nonungus),"Nonungus can enter normally")
	if pending(game,"search_hand","Nonungus opens optional search"):
		check(game.pending.options.all(func(uid): return game.code(uid) == "0114" and uid in game.players[0].deck),"Nonungus offers only Sams in own deck")
		check(not game.choose([nonungus]),"Nonungus rejects a non-Sam choice")
		check(game.choose([sam]) and sam in game.players[0].hand,"Nonungus puts chosen Sam in hand")
		check(game.visual_events.any(func(event): return event.kind == "shuffle" and event.player == 0),"Nonungus search shuffles deck")
		check(game.log_lines.any(func(line): return "muestra" in line and "Sam" in line),"Nonungus search reveals Sam in log")
	audit(game,"Nonungus successful filtered search")
	game = fresh()
	resources(game,0)
	for uid in game.players[0].deck.duplicate():
		if game.code(uid) == "0114": game.leave(uid,"graveyard")
	game.take_visual_events()
	check(game.request_play(take(game,0,"0101","hand")) and game.pending.is_empty(),"Nonungus with no Sam in deck completes without blocked choice")
	check(game.visual_events.any(func(event): return event.kind == "shuffle"),"Failed Nonungus search still shuffles")
	audit(game,"Nonungus no target")
	game = fresh()
	resources(game,0)
	check(game.request_play(take(game,0,"0101","hand")),"Nonungus offers search before optional refusal")
	if pending(game,"search_hand","Nonungus refusal choice exists"):
		var hand_before = game.players[0].hand.size()
		check(game.skip_choice() and game.players[0].hand.size() == hand_before and game.pending.is_empty(),"Declining Nonungus search adds no card and resumes play")
	audit(game,"Nonungus declined search")
	game = fresh()
	resources(game,0)
	var counter = take(game,1,"0130")
	nonungus = take(game,0,"0101","hand")
	check(game.request_play(nonungus),"Nonungus can be announced into counter window")
	if pending(game,"counter","Serandimini can counter Nonungus"):
		check(game.choose([counter]) and nonungus in game.players[0].graveyard and game.pending.is_empty(),"Countered Nonungus never triggers entry search")
	audit(game,"Nonungus countered before entering")

func test_last_ally():
	var game = fresh()
	resources(game,0)
	var older = take(game,1,"0101","graveyard")
	var newest = take(game,1,"0125","graveyard")
	take(game,1,"0124","graveyard")
	check(game.last_ally_in_graveyard(1) == newest,"Last Ally helper ignores a more recent Object")
	game.leave(newest,"hand")
	check(game.last_ally_in_graveyard(1) == older,"Last Ally considers only Allies currently in graveyard")
	var event = take(game,0,"0118","hand")
	check(game.request_play(event) and older in game.players[1].burned and newest in game.players[1].hand,"Caída burns last remaining opposing graveyard Ally")
	audit(game,"Caída current graveyard order")
	game = fresh()
	resources(game,0)
	take(game,1,"0124","graveyard")
	event = take(game,0,"0118","hand")
	var money = game.players[0].resources.size()
	check(not game.can_play(event) and not game.request_play(event),"Caída cannot be played with no opposing graveyard Ally")
	check(event in game.players[0].hand and game.players[0].resources.size() == money,"Invalid Caída consumes neither card nor payment")
	audit(game,"Caída unavailable target")

func test_templo():
	var game = fresh()
	var dragon = take(game,0,"01e")
	var attached = equip(game,0,"0124",dragon)
	var temple = domain(game,1,"0121")
	var their_object = take(game,1,"0123","hand")
	check(not game.can_play(their_object),"Templo prevents its owner's Object play")
	own_turn(game,0)
	resources(game,0)
	var own_object = take(game,0,"0123","hand")
	check(not game.can_play(own_object) and not game.request_play(own_object,dragon),"Templo also prevents opponent Object play")
	check(game.instances[dragon].object == attached and attached not in game.players[0].graveyard,"Templo keeps already equipped Objects attached")
	domain(game,0,"0122")
	check(temple in game.players[1].graveyard and game.can_play(own_object),"Replacing Templo restores Object play")
	audit(game,"Templo bilateral prohibition and replacement")

func test_chanchuus():
	var game = fresh()
	var pig = take(game,0,"0125")
	var object = equip(game,0,"0124",pig)
	check(game.force(pig) == 3 and int(game.definition(pig).coste) == 4,"Chanchuus ignores Miku force bonus and retains printed cost")
	var dragon = take(game,1,"01e")
	equip(game,1,"0124",dragon)
	check(game.force(dragon) > game.force(pig),"Other Allies still receive applicable force bonuses")
	resolve_battle(game,dragon,pig)
	check(pig in game.players[0].graveyard and object in game.players[0].graveyard,"Chanchuus immunity does not prevent combat defeat or discard of its Object")
	audit(game,"Chanchuus force protection is limited to force and cost")

func test_viborin():
	var game = fresh()
	var snake = take(game,0,"0126")
	var sacrifice = take(game,0,"0128")
	var enemy = take(game,1,"0101")
	var enemy_deck = game.players[1].deck.size()
	check(game.activate(snake),"Viborín activates on owner's turn")
	if pending(game,"sacrifice_ally","Viborín asks for friendly sacrifice"):
		check(snake in game.pending.options and sacrifice in game.pending.options and enemy not in game.pending.options,"Viborín offers self and friendly Allies, excluding enemies")
		check(not game.choose([enemy]),"Viborín rejects enemy sacrifice")
		check(game.choose([sacrifice]) and sacrifice in game.players[0].graveyard and game.force(snake) == 5,"Viborín sacrifice grants exactly +3 force")
		check(game.players[1].deck.size() == enemy_deck,"Sacrificing HNyko is not combat defeat and causes no damage")
		check(not game.can_activate(snake),"Viborín is once per owner's turn")
		game.phase = "after_combat"
		check(game.force(snake) == 5,"Viborín bonus remains through after-combat phase")
		check(game.finish_turn() and game.force(snake) == 2,"Viborín force bonus expires at end of turn")
		game.skip_resource()
		check(not game.can_activate(snake),"Viborín cannot activate on opponent's turn")
	audit(game,"Viborín sacrifice, limit and expiry")
	game = fresh()
	snake = take(game,0,"0126")
	resources(game,0)
	check(game.activate(snake),"Viborín self-sacrifice activation starts")
	if pending(game,"sacrifice_ally","Viborín self-sacrifice choice exists"):
		check(game.choose([snake]) and snake in game.players[0].graveyard and game.force(snake) == 2,"Self-sacrificed Viborín gains no surviving bonus")
		game.leave(snake,"hand")
		check(game.request_play(snake) and game.force(snake) == 2,"Reentered Viborín does not retain previous force bonus")
	audit(game,"Viborín self-sacrifice and reentry")
	game = fresh()
	snake = take(game,0,"0126")
	check(game.activate(snake),"Viborín cancellation activation starts")
	if pending(game,"sacrifice_ally","Viborín cancellation choice exists"):
		check(game.skip_choice() and game.can_activate(snake) and game.force(snake) == 2,"Cancelling Viborín does not spend its use or sacrifice a card")
	audit(game,"Viborín cancelled activation")

func test_hnyko():
	var game = fresh()
	var hnyko = take(game,0,"0128")
	var defender = take(game,1,"0101")
	check(game.unblockable(hnyko) and game.declare_attack([hnyko]),"HNyko has printed Imbloqueable")
	check(not game.assign_block(hnyko,defender),"HNyko cannot be blocked without Talca")
	audit(game,"HNyko unblockable keyword")
	game = fresh()
	var dragon = take(game,0,"01e")
	hnyko = take(game,1,"0128")
	var before = game.players[0].deck.size()
	resolve_battle(game,dragon,hnyko)
	check(hnyko in game.players[1].graveyard and game.players[0].deck.size() == before-2,"Combat-defeated HNyko mills exactly two opposing cards")
	audit(game,"HNyko defeat trigger")
	game = fresh()
	hnyko = take(game,1,"0128")
	resources(game,0)
	var removal = take(game,0,"0133","hand")
	before = game.players[0].deck.size()
	check(game.request_play(removal,hnyko),"Muerte can destroy HNyko by effect")
	check(hnyko in game.players[1].graveyard and game.players[0].deck.size() == before,"Effect destruction is not HNyko combat defeat")
	audit(game,"HNyko effect destruction does not trigger")

func test_almenta():
	var game = fresh()
	var almenta = take(game,0,"0129")
	var friend = take(game,0,"0101")
	var enemy = take(game,1,"0101")
	var money = game.players[0].resources.size()
	check(game.activate(almenta),"Almenta starts friendly-target selection")
	if pending(game,"grant_unblockable","Almenta asks for friendly target"):
		check(friend in game.pending.options and almenta in game.pending.options and enemy not in game.pending.options,"Almenta includes own Ally/self and excludes enemy")
		check(not game.choose([enemy]),"Almenta rejects opponent target")
		check(game.choose([friend]) and game.unblockable(friend),"Almenta grants Imbloqueable to selected Ally")
		check(game.players[0].resources.size() == money-1 and game.players[0].paid.size() == 1,"Almenta pays exactly one Resource")
		check(not game.can_activate(almenta),"Almenta is once per owner's turn")
		check(game.declare_attack([friend]) and not game.assign_block(friend,enemy),"Granted Imbloqueable prevents ordinary block")
		game.finish_blocks()
		game.pass_priority()
		check(game.finish_turn() and not game.unblockable(friend),"Almenta's granted keyword expires at turn end")
	audit(game,"Almenta target, payment, combat and expiry")
	game = fresh()
	almenta = take(game,0,"0129")
	friend = take(game,0,"0101")
	money = game.players[0].resources.size()
	check(game.activate(almenta),"Almenta cancellable activation starts")
	if pending(game,"grant_unblockable","Almenta cancellation choice exists"):
		check(game.skip_choice() and game.can_activate(almenta) and game.players[0].resources.size() == money,"Cancelling Almenta spends neither use nor payment")
	for uid in game.players[0].resources.duplicate():
		game.players[0].resources.erase(uid)
		game.players[0].paid.append(uid)
	check(not game.can_activate(almenta),"Almenta cannot activate with no unspent Resource")
	own_turn(game,1)
	check(not game.can_activate(almenta),"Almenta cannot activate during opponent turn")
	audit(game,"Almenta cancelled activation and unavailable payment")
	game = fresh()
	almenta = take(game,0,"0129")
	friend = take(game,0,"0101")
	game.manual_payment[0] = true
	var resource = game.players[0].resources[0]
	check(game.reserve_resource(resource),"Prepare one Resource for manual Almenta payment")
	check(game.activate(almenta),"Almenta can use already reserved Resource")
	if pending(game,"grant_unblockable","Manual Almenta target choice exists"):
		check(game.choose([friend]) and game.unblockable(friend) and game.reserved[0].is_empty() and game.players[0].paid.size() == 1,"Manual Almenta consumes exactly its reserved Resource")
	audit(game,"Almenta manual reserved payment")
	game = fresh()
	almenta = take(game,0,"0129")
	friend = take(game,0,"0101")
	game.manual_payment[0] = true
	game.phase = "after_combat"
	check(game.activate(almenta),"Almenta activates after combat on its owner's turn")
	if pending(game,"grant_unblockable","After-combat Almenta target choice exists"):
		check(game.choose([friend]) and game.payment_request.get("kind","") == "ability","Manual after-combat Almenta waits for one Resource")
		check(game.cancel_payment() and game.can_activate(almenta) and not game.unblockable(friend),"Cancelling deferred ability payment spends neither Resource nor use")
		game.activate(almenta)
		game.choose([friend])
		resource = game.players[0].resources[0]
		check(game.can_reserve(resource) and game.reserve_resource(resource) and game.payment_request.is_empty() and game.unblockable(friend),"After-combat Resource reservation completes Almenta without deadlock")
	audit(game,"Almenta after-combat deferred payment and cancellation")
	game = fresh()
	almenta = take(game,0,"0129")
	friend = take(game,0,"0101")
	resources(game,0,3)
	game.manual_payment[0] = true
	game.reserve_resource(game.players[0].resources[0])
	game.reserve_resource(game.players[0].resources[0])
	check(game.activate(almenta),"Almenta activates with excess prepared Resources")
	if pending(game,"grant_unblockable","Excess-reservation Almenta target choice exists"):
		check(game.choose([friend]) and game.reserved[0].size() == 1,"Almenta consumes one reservation and leaves excess unspent")
		check(game.cancel_payment() and game.reserved[0].is_empty() and game.players[0].paid.size() == 1 and game.players[0].resources.size() == 2 and game.unblockable(friend),"Cancelling excess reservation refunds only extra Resource and preserves resolved ability")
	audit(game,"Almenta refunds extra prepared Resources")
	game = fresh()
	almenta = take(game,0,"0129")
	friend = take(game,0,"0101")
	enemy = take(game,1,"0101")
	domain(game,0,"0122")
	check(game.activate(almenta),"Almenta activates under Talca")
	if pending(game,"grant_unblockable","Talca scenario target choice exists"):
		check(game.choose([friend]) and game.declare_attack([friend]) and game.assign_block(friend,enemy),"Talca permits blocking an Ally granted Imbloqueable")
	audit(game,"Almenta and Talca interaction")

func test_granjita():
	var game = fresh()
	var dragon = take(game,0,"01e")
	var hnyko = take(game,1,"0128")
	var object = equip(game,1,"0123",hnyko)
	domain(game,0,"01d")
	var before = game.players[0].deck.size()
	resolve_battle(game,dragon,hnyko)
	check(dragon in game.players[0].burned and hnyko in game.players[1].burned,"Granjita burns combat-defeated Allies on both sides")
	check(object in game.players[1].graveyard and object not in game.players[1].burned,"Granjita still sends attached Object to owner's graveyard")
	check(game.players[0].deck.size() == before-2,"HNyko defeat trigger survives Granjita destination replacement")
	audit(game,"Granjita combat replacement with HNyko and attached Object")
	game = fresh()
	var ally = take(game,1,"0101")
	domain(game,0,"01d")
	check(game.request_play(take(game,0,"0133","hand"),ally) and ally in game.players[1].graveyard and ally not in game.players[1].burned,"Granjita does not replace effect destruction")
	audit(game,"Granjita excludes noncombat destruction")
	game = fresh()
	var snake = take(game,0,"0126")
	hnyko = take(game,0,"0128")
	object = equip(game,0,"0124",hnyko)
	domain(game,0,"01d")
	before = game.players[1].deck.size()
	check(game.activate(snake),"Viborín activates while Granjita is active")
	if pending(game,"sacrifice_ally","Granjita sacrifice choice exists"):
		check(game.choose([hnyko]) and hnyko in game.players[0].graveyard and object in game.players[0].graveyard and game.players[1].deck.size() == before,"Granjita does not burn sacrifices and sacrificed HNyko does not trigger")
	audit(game,"Granjita excludes sacrifice and preserves Object cleanup")

func test_dragon_and_souls():
	var game = fresh()
	var dragon = take(game,0,"01e")
	check(game.force(dragon) == 4,"Unequipped Dragón has printed force four")
	var object = equip(game,0,"0123",dragon)
	check(game.force(dragon) == 6,"Any equipped Object enables Dragón's +2")
	game.leave(object,"graveyard")
	check(game.force(dragon) == 4,"Removing Object removes Dragón's conditional +2")
	object = equip(game,0,"0124",dragon)
	check(game.force(dragon) == 7,"Dragón's +2 stacks with Miku's ordinary +1")
	game.leave(dragon,"graveyard")
	check(object in game.players[0].graveyard and game.force(dragon) == 4,"Dragón loses conditional effects and detaches Object on leaving")
	audit(game,"Dragón continuous Object bonus")
	game = fresh()
	var left = take(game,0,"01f")
	check(game.force(left) == 1,"Almas Perdidas does not count itself")
	var right = take(game,1,"01f")
	check(game.force(left) == 2 and game.force(right) == 2,"Almas Perdidas counts the other copy across both players")
	game.leave(right,"graveyard")
	check(game.force(left) == 1,"Almas Perdidas counts only other copies currently in play")
	equip(game,0,"0124",left)
	check(game.force(left) == 2,"Almas Perdidas still receives an unrelated Object bonus")
	audit(game,"Almas Perdidas continuous global count")

func run():
	var basis = Game.new()
	var originals = JSON.stringify(basis.decklists)
	for code in REMAINING: check(code in Game.SUPPORTED,"New card supported: "+code)
	test_nonungus()
	test_last_ally()
	test_templo()
	test_chanchuus()
	test_viborin()
	test_hnyko()
	test_almenta()
	test_granjita()
	test_dragon_and_souls()
	check(JSON.stringify(basis.decklists) == originals,"Production deck lists remain unchanged")
	var result = {"remaining_cards_v130_checks":checks,"failures":failures,"cards":REMAINING,"scenarios":scenarios,"random_simulations":0,"network_requests":0,"real_accounts_used":0,"fixture":"Deterministic two custom decks, exactly 40 cards each, current engine","engine":Engine.get_version_info().string}
	print(JSON.stringify(result))
	if not result_path.is_empty():
		var output = FileAccess.open(result_path,FileAccess.WRITE)
		if output != null: output.store_string(JSON.stringify(result,"  "))
	quit(0 if failures.is_empty() else 1)
