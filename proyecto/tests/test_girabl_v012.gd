extends SceneTree
## Historic Girabl quantities, exercised through the CURRENT rules and AI.
## No production catalog, deck list, game rule or AI selection is modified.
const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
var checks = 0
var failures = []
var simulations = 0
var games = []

func _initialize():
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func run():
	var basis = Game.new()
	var original_ids = []
	for deck in basis.decklists: original_ids.append(str(deck.id))
	check(original_ids == ["kajido", "papito", "flaan"], "The original three production decks remain unchanged")
	var original_lists = JSON.stringify(basis.decklists)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mazos_legacy.json"))
	var historic = {}
	for deck in fixture.mazos:
		if deck.id == "usuario_girabl": historic = deck
	check(not historic.is_empty(), "The exact historic Girabl fixture exists")
	if historic.is_empty():
		finish()
		return
	var girabl = historic.duplicate(true)
	girabl.id = "girabl"
	girabl.nombre = "Mazo Girabl"
	check(girabl.cartas == historic.cartas, "Reward deck preserves every historic card quantity")
	check(girabl.id == "girabl" and girabl.nombre == "Mazo Girabl", "Reward identity matches Mazo Girabl")
	var count = 0
	var resources = 0
	for entry in girabl.cartas:
		var known = basis.catalog.has(entry.codigo) and entry.codigo in Game.SUPPORTED
		check(known and int(entry.cantidad) > 0, "Historic card is known and supported: " + entry.codigo)
		count += int(entry.cantidad)
		if known and basis.catalog[entry.codigo].clase == "Recurso": resources += int(entry.cantidad)
	check(count == 40, "Mazo Girabl contains exactly 40 cards")
	check(resources == 12, "Mazo Girabl contains exactly 12 Resources")
	if not failures.is_empty():
		finish()
		return
	var matchup = 0
	for original in basis.decklists:
		for order in range(2):
			for seed_index in range(3):
				var decks = [girabl, original] if order == 0 else [original, girabl]
				simulate(decks, 14000 + matchup * 31 + seed_index, seed_index)
			matchup += 1
	var maagover = fixture.mazos[0].duplicate(true)
	maagover.id = "maago"
	maagover.nombre = "Mazo Maagover"
	for order in range(2):
		for seed_index in range(3):
			var decks = [girabl, maagover] if order == 0 else [maagover, girabl]
			simulate(decks, 16000 + order * 31 + seed_index, seed_index)
	for seed_index in range(3): simulate([girabl, girabl], 15000 + seed_index, seed_index)
	check(simulations == 27, "All 27 matchups complete: both seats against base decks and Maagover, plus mirrors")
	check(JSON.stringify(basis.decklists) == original_lists, "Simulation leaves the original deck lists unchanged")
	finish()

func simulate(decks, seed_value, payment_mode):
	var game = Game.new()
	var bot = Bot.new()
	game.new_game(seed_value, decks)
	# Match test_v08's reservation path, testing each seat as the manual payer.
	game.manual_payment = [payment_mode == 1, payment_mode == 2]
	var context = "%s / %s seed %d manual %s" % [decks[0].id, decks[1].id, seed_value, str(game.manual_payment)]
	check(game.instances.size() == 80 and game.invariant_errors().is_empty(), "Initial 80-card conservation: " + context)
	var steps = 0
	var ok = true
	var reason = ""
	while game.winner == -1 and steps < 6000:
		var success = false
		if not game.payment_request.is_empty():
			if game.players[game.actor].resources.is_empty():
				reason = "No Resource available for requested manual payment"
				ok = false
				break
			success = game.reserve_resource(game.players[game.actor].resources.back())
		else:
			success = bot.step(game, game.actor)
		steps += 1
		if not success:
			ok = false
			reason = "Action failed: " + game.error
			break
		var errors = game.invariant_errors()
		if game.instances.size() != 80 or not errors.is_empty():
			ok = false
			reason = "80-card invariant failed: " + str(errors)
			break
	if game.winner == -1 and reason.is_empty(): reason = "Match exceeded 6000 actions"
	var completed = ok and game.winner != -1
	check(completed, "Full game with current AI and 80-card invariants throughout: " + context + (" · " + reason if not completed else ""))
	if completed: simulations += 1
	games.append({"deck_ids":[decks[0].id,decks[1].id], "seed":seed_value, "manual_payment":game.manual_payment, "actions":steps, "winner":game.winner, "completed":completed, "error":reason})

func finish():
	print(JSON.stringify({"girabl_v012_checks":checks, "complete_simulations":simulations, "failures":failures, "games":games}))
	quit(0 if failures.is_empty() else 1)
