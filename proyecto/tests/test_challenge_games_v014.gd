extends SceneTree
## Five complete games through the same fixed-opponent resolver used by main.
const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
var checks = 0
var failures = []
var games = []

func _initialize():
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ",message)

func run():
	# Deliberately do not add main to the tree: no account, networking or rendering.
	var resolver = load("res://main.gd").new()
	resolver.game = Game.new()
	var original = JSON.stringify(resolver.game.decklists)
	check(resolver.game.decklists.map(func(d):return d.id) == ["kajido","papito","flaan"],"Random pool retains the original three decks")
	check(resolver.challenge_opponent(0).is_empty() and resolver.challenge_opponent(6).is_empty(),"Unknown challenge stages cannot resolve an opponent")
	for stage in range(1,6):
		var opponent = resolver.challenge_opponent(stage)
		var supported = true
		var total = 0
		for entry in opponent.cartas:
			supported = supported and entry.codigo in Game.SUPPORTED and int(entry.cantidad) > 0
			total += int(entry.cantidad)
		check(supported and total == 40,"Stage %d has a supported 40-card opponent" % stage)
		var human = stage % 2
		var pair = [null,null]
		pair[human] = resolver.game.decklists[(stage-1)%3]
		pair[1-human] = opponent
		var game = Game.new()
		game.new_game(24000+stage*31,pair)
		game.manual_payment = [human == 0,human == 1]
		check(game.players[1-human].deck_id == resolver.CHALLENGES[stage-1].deck_id and game.instances.size() == 80 and game.invariant_errors().is_empty(),"Stage %d starts with correct fixed opponent and all 80 cards" % stage)
		var bot = Bot.new()
		var actions = 0
		var error = ""
		while game.winner == -1 and actions < 6000:
			var success = false
			if not game.payment_request.is_empty():
				if game.players[game.actor].resources.is_empty():
					error = "Manual payment has no available Resource"
					break
				success = game.reserve_resource(game.players[game.actor].resources.back())
			else:
				success = bot.step(game,game.actor)
			actions += 1
			if not success:
				error = game.error
				break
			var violations = game.invariant_errors()
			if game.instances.size() != 80 or not violations.is_empty():
				error = "80-card invariant: " + str(violations)
				break
		check(error.is_empty() and game.winner != -1,"Stage %d completes with 80-card conservation through every action: %s" % [stage,error])
		games.append({"stage":stage,"opponent":opponent.id,"human_seat":human,"seed":24000+stage*31,"actions":actions,"winner":game.winner,"complete":error.is_empty() and game.winner != -1,"error":error})
	check(games.filter(func(g):return g.complete).size() == 5,"All five current challenge paths finish full games")
	check(JSON.stringify(resolver.game.decklists) == original,"Challenge resolver leaves the random pool untouched")
	resolver.free()
	print(JSON.stringify({"challenge_games_v014_checks":checks,"failures":failures,"complete_simulations":games.filter(func(g):return g.complete).size(),"games":games,"live_rpc_calls":0}))
	quit(0 if failures.is_empty() else 1)
