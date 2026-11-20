extends SceneTree
const Game = preload("res://tests/fixtures/legacy_game.gd")
const Bot = preload("res://ai.gd")
var checks = 0
var failures = []
var simulations = 0

func check(value, message):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func fresh():
	var g = Game.new()
	g.new_game(21)
	g.keep_hand()
	g.keep_hand()
	g.active = 0
	g.actor = 0
	g.turn = 10
	g.phase = "main"
	return g

func take(g, p, card_code, destination = "defense"):
	for z in g.ZONES:
		for uid in g.players[p][z].duplicate():
			if g.code(uid) == card_code:
				g.players[p][z].erase(uid)
				g.players[p][destination].append(uid)
				g.instances[uid].entered = 1
				return uid
	return -1

func resources(g, p, count):
	while g.players[p].resources.size() < count: take(g, p, "0100", "resources")

func _initialize():
	var g = fresh()
	g.manual_payment = [true, false]
	resources(g, 0, 4)
	var ally = take(g, 0, "0108", "hand")
	check(g.request_play(ally), "Carta primero: comienza el pago manual")
	check(not g.payment_request.is_empty() and ally in g.players[0].hand, "No se juega ni mueve la carta antes de pagar")
	check(not g.finish_turn(), "No se cede el turno con una jugada a medio pagar")
	var r = g.players[0].resources.back()
	check(g.reserve_resource(r), "Mover Recurso a Pagadas completa el coste")
	check(ally in g.players[0].defense and g.payment_request.is_empty(), "La carta se resuelve al completar el pago")
	g.skip_choice()
	check(r in g.players[0].paid and r not in g.reserved[0], "El Recurso usado queda gastado, sin crédito duplicado")
	check(not g.refund_resource(r), "Un Recurso gastado no puede devolverse manualmente")
	check(g.invariant_errors().is_empty(), "Conservación durante pago manual")

	var miku = take(g, 0, "0124", "hand")
	for i in range(3): g.reserve_resource(g.players[0].resources.back())
	check(g.request_play(miku, ally), "Pago primero: se equipa el Objeto con Recursos preparados")
	check(g.instances[ally].object == miku and g.force(ally) == 5, "Miku mantiene el bono total +4 al pagar por arrastre")
	check(g.reserved[0].size() == 1, "Un pago mayor al coste conserva el sobrante sin gastar")
	check(g.refund_resource(g.reserved[0][0]), "Puede devolverse un Recurso preparado y sin gastar")
	check(g.invariant_errors().is_empty(), "Conservación al equipar con pago preparado")

	g = fresh()
	g.manual_payment = [true, false]
	resources(g, 0, 4)
	var javier = take(g, 0, "0104", "hand")
	g.request_play(javier)
	g.reserve_resource(g.players[0].resources.back())
	check(g.cancel_payment(), "Se puede cancelar un pago parcial")
	check(g.players[0].paid.is_empty() and g.players[0].resources.size() == 4 and javier in g.players[0].hand, "Cancelar devuelve Recursos y conserva la carta")
	check(g.payment_request.is_empty() and g.reserved[0].is_empty(), "Cancelar limpia el pago pendiente")
	check(not g.request_play(take(g, 0, "0124", "hand"), take(g, 1, "0104")), "Un Objeto no acepta un portador rival")

	g = fresh()
	var azul = take(g, 0, "0111")
	check(g.force(azul) == 2, "Azul en Defensa sin bloquear tiene fuerza base 2")
	g.declare_attack([azul])
	check(g.force(azul) == 3, "Azul en Ataque tiene +1")
	g.finish_blocks()
	g.pass_priority()
	check(g.force(azul) == 3, "Azul conserva +1 después del combate mientras sigue en Ataque")
	g.finish_turn()
	check(g.force(azul) == 3, "Azul conserva +1 en Ataque durante el turno rival")
	g.skip_resource()
	g.finish_turn()
	check(azul in g.players[0].defense and g.force(azul) == 2, "Reagrupar devuelve Azul a Defensa sin bono")

	g = fresh()
	var attacker = take(g, 0, "0108")
	azul = take(g, 1, "0111")
	g.declare_attack([attacker])
	g.assign_block(attacker, azul)
	check(g.force(azul) == 4, "Azul bloquea con +2")
	g.assign_block(attacker, -1)
	check(g.force(azul) == 2, "Quitar el bloqueo quita inmediatamente el +2 de Azul")
	g.assign_block(attacker, azul)
	g.finish_blocks()
	g.pass_priority()
	g.pass_priority()
	check(g.force(azul) == 2, "Tras defender, Azul vuelve a Defensa sin bono")

	g = fresh()
	var cat = take(g, 1, "01b")
	g.active = 1
	g.actor = 1
	check(g.activate(cat), "Bigotes se activa durante su propio turno")
	g.skip_choice()
	check(not g.can_activate(cat), "Bigotes no repite en el mismo turno")
	g.active = 0
	g.actor = 1
	g.turn += 1
	g.phase = "events"
	check(not g.can_activate(cat), "Bigotes no se activa durante el turno rival, aunque tenga prioridad")
	g.active = 1
	g.actor = 1
	g.turn += 1
	g.phase = "after_combat"
	check(g.can_activate(cat), "En el siguiente turno propio recupera su habilidad, incluso antes del robo final")

	# Descartes uno a uno conservan el turno hasta completar el límite.
	g = fresh()
	g.players[0].deck.append_array(g.players[0].hand)
	g.players[0].hand.clear()
	g.draw(0, 10)
	g.finish_turn()
	var to_discard = int(g.pending.max)
	for i in range(to_discard):
		check(g.discard_by_drag(g.players[0].hand[0]), "Descartar por arrastre al cerrar")
		if i < to_discard - 1: check(g.active == 0, "El rival espera mientras faltan descartes")
	check(g.players[0].hand.size() == 8 and g.active == 1, "El turno rival comienza con mano propia ajustada a ocho")
	check(g.invariant_errors().is_empty(), "Conservación al descartar uno a uno")

	for seed_value in range(64): simulate(seed_value)
	for seed_value in range(24): simulate_manual(seed_value)
	# Alterar información privada rival no cambia la decisión del bot.
	var left = fresh()
	var right = fresh()
	for state in [left, right]:
		state.active = 1
		state.actor = 1
		resources(state, 1, 5)
	right.players[0].deck.reverse()
	var swap = right.players[0].hand[0]
	right.players[0].hand[0] = right.players[0].deck[0]
	right.players[0].deck[0] = swap
	var ai = Bot.new()
	ai.step(left, 1)
	ai.step(right, 1)
	check(left.players[1].hand == right.players[1].hand and left.pending == right.pending and left.log_lines == right.log_lines, "El bot decide igual aunque cambien la Mano y el orden del Mazo rival")
	print(JSON.stringify({"v02_checks":checks, "bot_games":simulations, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func simulate(seed_value):
	var g = Game.new()
	g.new_game(seed_value)
	var ai = Bot.new()
	var steps = 0
	while g.winner == -1 and steps < 4000:
		steps += 1
		if not ai.step(g, g.actor):
			check(false, "Bot bloqueado: semilla %d, fase %s, error %s" % [seed_value, g.phase, g.error])
			return
		var errors = g.invariant_errors()
		if not errors.is_empty():
			check(false, "Bot altera cartas: " + str(errors))
			return
	check(g.winner != -1, "Partida del bot %d termina" % seed_value)
	if g.winner != -1: simulations += 1

func simulate_manual(seed_value):
	var g = Game.new()
	g.manual_payment[seed_value % 2] = true
	g.new_game(seed_value)
	var ai = Bot.new()
	var steps = 0
	while g.winner == -1 and steps < 4500:
		steps += 1
		var result = false
		if not g.payment_request.is_empty(): result = g.reserve_resource(g.players[g.actor].resources.back())
		else: result = ai.step(g, g.actor)
		if not result or not g.invariant_errors().is_empty():
			check(false, "Partida con pago manual bloqueada: %d / %s" % [seed_value, g.error])
			return
	check(g.winner != -1, "Partida mixta de pagos %d termina" % seed_value)
	if g.winner != -1: simulations += 1
