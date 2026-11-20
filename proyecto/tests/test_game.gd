extends SceneTree

const Game = preload("res://tests/fixtures/legacy_game.gd")
var failures = []
var checks = 0
var simulated = 0

func check(value, message):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func fresh(seed_value = 17):
	var g = Game.new()
	g.new_game(seed_value)
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

func resources(g, p, amount):
	while g.players[p].resources.size() < amount:
		take(g, p, "0100", "resources")

func _initialize():
	var g = Game.new()
	g.new_game(123)
	check(g.players[0].hand.size() == 6 and g.players[1].hand.size() == 6, "Manos iniciales de seis")
	check(g.players[0].resources.size() == 1, "Recurso Inicial tomado del mazo")
	check(g.players[0].deck.size() == 33, "40 = 33 en Mazo + 6 en Mano + 1 Recurso")
	g.mulligan()
	check(g.players[0].hand.size() == 5, "Primer cambio de cinco")
	g.mulligan()
	check(g.players[0].hand.size() == 5, "Segundo cambio también de cinco")
	check(not g.mulligan(), "No hay tercer cambio")
	check(g.invariant_errors().is_empty(), "Conservación de cartas durante cambios")
	for deck in g.decklists:
		for entry in deck.cartas:
			check(entry.codigo in g.SUPPORTED, "Carta del mazo implementada: " + entry.codigo)

	g = fresh()
	var resource = take(g, 0, "0100", "hand")
	check(not g.request_play(resource), "No puede bajarse Recurso después de pasar a Acciones")
	g.phase = "resource"
	check(g.request_play(resource), "Recurso en su oportunidad inicial")
	check(g.phase == "main", "Bajar Recurso cierra su oportunidad")
	check(not g.request_play(take(g, 0, "0100", "hand")), "Solo un Recurso por turno")
	check(g.invariant_errors().is_empty(), "Conservación de cartas al bajar Recurso")

	g = fresh()
	resources(g, 0, 4)
	var ally = take(g, 0, "0108")
	var miku = take(g, 0, "0124", "hand")
	check(g.request_play(miku), "Muñeco solicita portador")
	check(g.choose([ally]), "Muñeco se equipa a Maagover")
	check(g.force(ally) == 5, "Maagover base 1 + 4 = 5, no 6")
	check(g.players[0].paid.size() == 2, "Pago exacto del Objeto")
	g.leave(ally, "deck")
	check(miku in g.players[0].graveyard, "Objeto va al Cementerio aunque su portador se baraje")
	check(ally in g.players[0].deck, "Portador se baraja en su propio Mazo")
	check(g.invariant_errors().is_empty(), "Conservación al separar portador y Objeto")

	g = fresh()
	var girabl = take(g, 1, "0127")
	var peri = take(g, 1, "01a")
	check(g.force(girabl) == 4, "Girabl recibe +2 por Peri")
	check(g.unblockable(peri), "Peri gana Imbloqueable por Girabl")
	g.leave(girabl, "graveyard")
	check(not g.unblockable(peri), "Peri pierde el bono al salir Girabl")
	var yuri = take(g, 1, "0112")
	var celia = take(g, 1, "0113")
	check(g.force(yuri) == 2 and g.force(celia) == 2, "Bonos cruzados de Yuri y Celia")

	g = fresh()
	var newly = take(g, 0, "0104")
	g.instances[newly].entered = g.turn
	check(not g.can_attack(newly), "Aliado recién jugado no ataca")
	var fast = take(g, 0, "01c")
	g.instances[fast].entered = g.turn
	check(g.can_attack(fast), "Ágil puede atacar al entrar")
	var attacker = take(g, 0, "0108")
	take(g, 1, "0104") # This case verifies the manual block window with a defender.
	check(g.declare_attack([attacker]), "Declaración de ataque")
	check(g.actor == 1 and g.phase == "blocks", "El defensor asigna los bloqueos")
	g.finish_blocks()
	check(not g.event_access, "Sin bloqueo no se habilitan Eventos al atacante")
	g.pass_priority()
	check(g.phase == "after_combat", "Sin respuesta del defensor se pasa al daño")
	check(not g.request_play(take(g, 0, "0104", "hand")), "No se vuelve a jugar Aliados después del combate")

	g = fresh()
	resources(g, 1, 4)
	var atk1 = take(g, 0, "0108")
	var atk2 = take(g, 0, "0104")
	var defender = take(g, 1, "0104")
	g.declare_attack([atk1, atk2])
	check(g.assign_block(atk1, defender), "Bloqueo uno a uno")
	check(not g.assign_block(atk2, defender), "Un defensor no bloquea a dos atacantes")
	g.finish_blocks()
	check(g.event_access, "Un bloqueo abre Eventos para el atacante")
	var event = take(g, 1, "0116", "hand")
	check(g.request_play(event), "El defensor puede responder con Evento")
	g.choose([atk1])
	check(g.actor == 0 and g.passes == 0, "Tras resolver un Evento se alterna la prioridad")
	check(atk1 in g.players[0].deck, "Conflicto baraja su objetivo")
	check(g.invariant_errors().is_empty(), "Conservación tras Evento de combate")

	g = fresh()
	var imb = take(g, 0, "0107")
	var block = take(g, 1, "0104")
	g.declare_attack([imb])
	check(not g.assign_block(imb, block), "Imbloqueable impide bloqueo")
	var talca = take(g, 0, "0122", "hand")
	g.players[0].hand.erase(talca)
	g.domain_uid = talca
	check(g.assign_block(imb, block), "Talca habilita bloquear Imbloqueables")

	g = fresh()
	resources(g, 0, 5)
	var six = []
	for i in range(3):
		six.append(take(g, 0, "0108"))
		six.append(take(g, 0, "0104"))
	var obj = take(g, 0, "0124", "hand")
	g.players[0].hand.erase(obj)
	g.instances[six[0]].object = obj
	var school = take(g, 0, "0131", "hand")
	g.request_play(school)
	check(g.pending.kind == "limit_keep", "Escuela pide elegir los Aliados que permanecen")
	g.choose(six.slice(2, 6))
	check(g.field(0).size() == 4, "Escuela deja cuatro Aliados")
	check(obj in g.players[0].graveyard, "El Objeto del Aliado descartado va al Cementerio")
	check(g.invariant_errors().is_empty(), "Conservación durante aplicación de límite")

	for count in [0, 1, 2, 3, 8, 10]:
		g = fresh()
		g.players[0].deck.append_array(g.players[0].hand)
		g.players[0].hand.clear()
		g.draw(0, count)
		g.finish_turn()
		if count >= 8:
			check(g.pending.kind == "end_discard", "Descarte obligatorio antes de ceder el turno")
			g.choose(g.pending.options.slice(0, g.pending.min))
		check(g.players[0].hand.size() == mini(8, maxi(3, count + 1)), "Cierre correcto con mano inicial %d" % count)
		check(g.active == 1 and g.phase == "resource", "El turno rival empieza después del cierre")
		check(g.invariant_errors().is_empty(), "Conservación en cierre de turno")

	g = fresh()
	g.players[1].hand.append_array(g.players[1].deck.slice(1))
	g.players[1].deck = g.players[1].deck.slice(0, 1)
	g.mill(1, 5, "Prueba")
	check(g.winner == 0 and g.phase == "finished", "Quedarse sin Mazo termina la partida")
	check(g.invariant_errors().is_empty(), "Conservación al terminar la partida")

	# Resultados completos de combate y daño separado por atacante.
	for case in ["superior", "igual", "inferior", "sin_bloqueo"]:
		g = fresh()
		var a = take(g, 0, "01c" if case == "superior" else "0108")
		var b = take(g, 1, "0108" if case == "igual" else "0104")
		var before = g.players[1].deck.size()
		g.declare_attack([a])
		if case != "sin_bloqueo":
			g.assign_block(a, b)
		g.finish_blocks()
		while g.phase == "events":
			g.pass_priority()
		var damage = 2 if case == "superior" else (1 if case == "sin_bloqueo" else 0)
		check(g.players[1].deck.size() == before - damage, "Daño correcto: " + case)
		check((a in g.players[0].graveyard) == (case in ["igual", "inferior"]), "Destino atacante: " + case)
		check((b in g.players[1].graveyard) == (case in ["superior", "igual"]), "Destino defensor: " + case)
		check(g.invariant_errors().is_empty(), "Conservación combate: " + case)
	g = fresh()
	var pair = [take(g, 0, "0108"), take(g, 0, "0104")]
	g.declare_attack(pair)
	g.finish_blocks()
	g.pass_priority()
	var damage_entries = g.log_lines.filter(func(line): return "causa" in line)
	check(damage_entries.size() == 2, "Cada atacante produce un daño separado")

	# Un Dominio sustituye al anterior y lo descarta al dueño correspondiente.
	g = fresh()
	resources(g, 0, 7)
	var old_domain = take(g, 0, "0122", "hand")
	g.request_play(old_domain)
	var new_domain = take(g, 0, "0131", "hand")
	g.request_play(new_domain)
	check(g.domain_uid == new_domain, "Solo queda el nuevo Dominio global")
	check(old_domain in g.players[0].graveyard, "Dominio reemplazado vuelve al Cementerio de su dueño")
	check(g.invariant_errors().is_empty(), "Conservación al sustituir Dominio")

	# Bigotes puede buscar una vez por turno y solo muestra Objetos elegibles.
	g = fresh()
	g.active = 1
	g.actor = 1
	var cat = take(g, 1, "01b")
	check(g.activate(cat), "Bigotes activa su búsqueda")
	check(g.pending.options.all(func(uid): return g.definition(uid).clase == "Objeto"), "Búsqueda Bigotes filtra Objetos")
	var found = g.pending.options[0]
	g.choose([found])
	check(found in g.players[1].hand, "Objeto buscado entra en la mano")
	check(not g.activate(cat), "Bigotes no se activa dos veces en el turno")
	check(g.log_lines.any(func(line): return "muestra" in line and g.title(found) in line), "Búsqueda revela la carta en el registro")

	g.error = "Error anterior"
	g.new_game(4)
	check(g.error.is_empty() and g.attacks.is_empty() and g.blocks.is_empty(), "Reiniciar elimina el estado anterior")
	for seed_value in range(24):
		simulate(seed_value)
	print(JSON.stringify({"checks": checks, "failures": failures, "complete_simulations": simulated}))
	quit(0 if failures.is_empty() else 1)

func simulate(seed_value):
	var g = Game.new()
	g.new_game(seed_value)
	g.keep_hand()
	g.keep_hand()
	var steps = 0
	while g.winner == -1 and steps < 2400:
		steps += 1
		if not g.pending.is_empty():
			var c = g.pending
			var amount = int(c.max)
			if c.kind == "search_hand":
				amount = mini(1, amount)
			g.choose(c.options.slice(0, amount))
		elif g.phase == "resource":
			var r = -1
			for uid in g.players[g.active].hand:
				if g.code(uid) == "0100":
					r = uid
					break
			if r != -1:
				g.request_play(r)
			else:
				g.skip_resource()
		elif g.phase == "main":
			var played = false
			for uid in g.players[g.active].hand.duplicate():
				if g.can_play(uid) and g.request_play(uid):
					played = true
					break
			if not played:
				var ready = []
				for uid in g.players[g.active].defense:
					if g.can_attack(uid):
						ready.append(uid)
				if ready.is_empty():
					g.finish_turn()
				else:
					g.declare_attack(ready)
		elif g.phase == "blocks":
			for uid in g.attacks:
				for block in g.players[1 - g.active].defense:
					if block not in g.blocks.values() and g.assign_block(uid, block):
						break
			g.finish_blocks()
		elif g.phase == "events":
			g.pass_priority()
		elif g.phase == "after_combat":
			g.finish_turn()
		else:
			check(false, "Fase inesperada: " + g.phase)
			break
		var errors = g.invariant_errors()
		if not errors.is_empty():
			check(false, "Simulación %d: %s" % [seed_value, str(errors)])
			return
	check(g.winner != -1, "La simulación %d termina sin bloqueo" % seed_value)
	if g.winner != -1:
		simulated += 1
