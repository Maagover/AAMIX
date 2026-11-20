extends SceneTree
const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
var checks = 0
var failures = []
var simulations = 0

func check(value, message):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func fresh(a = 0, b = 1):
	var g = Game.new()
	g.new_game(83, [g.decklists[a], g.decklists[b]])
	g.keep_hand()
	g.keep_hand()
	g.turn = 10
	g.active = 0
	g.actor = 0
	g.phase = "main"
	g.take_visual_events()
	return g

# Controlled effect fixtures keep exactly forty physical cards per player.
# If a card is absent from this deck, replace one unused Resource in its deck.
func bring(g, p, c, destination = "hand"):
	var uid = -1
	for z in g.ZONES:
		if z == destination: continue
		for u in g.players[p][z]:
			if g.code(u) == c:
				uid = u
				break
		if uid != -1: break
	if uid == -1:
		for u in g.players[p].deck:
			if g.code(u) == "0100":
				uid = u
				g.instances[u].code = c
				break
	assert(uid != -1, "Fixture needs a free card")
	var loc = g.location(uid)
	g.players[p][loc.zone].erase(uid)
	g.players[p][destination].append(uid)
	g.instances[uid].entered = 1
	return uid

func resources(g, p, amount):
	while g.players[p].resources.size() < amount: bring(g, p, "0100", "resources")

func equip(g, ally, c):
	var p = g.instances[ally].owner
	var obj = bring(g, p, c)
	g.players[p].hand.erase(obj)
	g.instances[ally].object = obj
	return obj

func invariant(g, context): check(g.invariant_errors().is_empty(), "80 cartas conservadas: " + context)

func _initialize():
	var g = fresh()
	check(g.decklists.map(func(d): return d.nombre) == ["Mazo Kajido", "Mazo Papito", "Mazo Flaan"], "Tres mazos exactos y en orden")
	check(g.SUPPORTED.size() == 31, "31 habilidades cubren mazos nuevos y regresiones antiguas")
	for d in g.decklists:
		var total = 0
		var counts = {}
		for entry in d.cartas:
			total += int(entry.cantidad)
			counts[entry.codigo] = int(entry.cantidad)
			check(entry.codigo in g.SUPPORTED, d.nombre + ": carta implementada " + entry.codigo)
			if entry.codigo != "0100": check(int(entry.cantidad) <= int(g.catalog[entry.codigo].maximo_copias_mazo), "Restricción de copias " + entry.codigo)
		check(total == 40 and counts.get("0100") == 18, d.nombre + ": 40 cartas y 18 Recursos")
	for a in range(3):
		for b in range(3):
			g.new_game(12, [g.decklists[a], g.decklists[b]])
			check(g.players[0].deck_id == g.decklists[a].id and g.players[1].deck_id == g.decklists[b].id, "Asignación independiente y espejos %d/%d" % [a,b])
			check(g.players.all(func(p): return p.hand.size() == 6 and p.resources.size() == 1 and p.deck.size() == 33), "Reparto 6+1+33 en ambos jugadores")
			invariant(g, "preparación")

	g = fresh(2,2)
	var flaan = bring(g,0,"0103","defense")
	var yuri = bring(g,0,"0112","defense")
	var celia = bring(g,1,"0113","defense")
	check(g.force(flaan) == 4 and not g.unblockable(flaan), "SoyFlaan cuenta Yuri/Celia de ambos lados; requiere pareja propia para Imbloqueable")
	bring(g,0,"0113","defense")
	check(g.force(flaan) == 5 and g.unblockable(flaan), "SoyFlaan con pareja propia y bono literal por tres cartas")
	g.leave(yuri,"graveyard")
	check(not g.unblockable(flaan) and g.force(flaan) == 4, "Bonificaciones continuas de SoyFlaan se actualizan")

	g = fresh()
	resources(g,0,7)
	var kajido = bring(g,0,"0105")
	var small1 = bring(g,0,"0111","graveyard")
	var small2 = bring(g,0,"0104","graveyard")
	var big = bring(g,0,"0134","graveyard")
	g.request_play(kajido)
	check(g.pending.kind == "grave_to_deck" and g.pending.min == 2 and big not in g.pending.options, "Kajido exige dos Aliados C≤3, nunca Guitarramala C7")
	check(not g.choose([small1]) and not g.finish_turn(), "Kajido no admite una sola carta ni cerrar con elección pendiente")
	check(g.choose([small1,small2]) and small1 in g.players[0].deck and small2 in g.players[0].deck, "Kajido recupera dos y baraja")
	check(g.force(kajido) == 4, "Kajido cuenta su propio Tipo Fundamental")
	bring(g,0,"0102","defense")
	bring(g,0,"0114","defense")
	check(g.force(kajido) == 5, "Kajido cuenta Lucha propio; no cuenta Salvaje")
	invariant(g,"Kajido")
	g = fresh()
	resources(g,0,7)
	kajido = bring(g,0,"0105")
	bring(g,0,"0111","graveyard")
	g.request_play(kajido)
	check(g.pending.is_empty(), "Kajido no ofrece recuperar si no hay dos válidos")

	g = fresh(1,0)
	var oscars = []
	for i in range(3): oscars.append(bring(g,0,"0106","defense"))
	var papito = bring(g,0,"0115","graveyard")
	check(g.can_activate(oscars[0]) and g.activate(oscars[0]), "Tres Oscarksss habilitan la búsqueda de Papito")
	check(g.pending.options == [papito] and g.choose([papito]), "Oscarksss busca en Cementerio además de Mazo")
	check(papito in g.players[0].hand and not g.can_activate(oscars[0]), "Papito pasa a Mano y se muestra; no se ofrece búsqueda vacía")
	var obj = equip(g,oscars[0],"0123")
	resources(g,0,4)
	g.request_play(papito)
	check(oscars.all(func(u): return u in g.players[0].deck), "Papito baraja todos los Oscarksss propios")
	check(obj in g.players[0].graveyard, "Objeto de Oscarksss se descarta al barajar portador")
	check(g.force(papito) == 6 and g.agile(papito) and g.unblockable(papito) and g.can_attack(papito), "Con tres Oscarksss, Papito obtiene F6, Ágil e Imbloqueable")
	g.leave(papito,"hand")
	check(not g.instances[papito].papito_empowered and not g.agile(papito), "Papito pierde mejoras al salir de juego")
	resources(g,0,4)
	g.request_play(papito)
	check(g.force(papito) == 4 and not g.unblockable(papito) and not g.can_attack(papito), "Papito que vuelve a entrar sin tres Oscarksss no conserva mejoras")
	invariant(g,"Papito")

	g = fresh(0,2)
	resources(g,0,3)
	var fern = bring(g,0,"0110")
	var carrier = bring(g,1,"0112","defense")
	obj = equip(g,carrier,"0123")
	g.request_play(fern)
	check(g.pending.kind == "remove_permanent" and obj in g.pending.options and carrier not in g.pending.options, "Feranando elige sólo Objeto o Dominio")
	g.choose([obj])
	check(g.instances[carrier].object == -1 and obj in g.players[1].graveyard, "Feranando respeta dueño del Objeto")
	invariant(g,"Feranando")

	g = fresh(2,0)
	resources(g,0,2)
	var sam = bring(g,0,"0114")
	var cheap = bring(g,0,"0116","deck")
	var expensive = bring(g,0,"0117","deck")
	g.request_play(sam)
	check(g.pending.kind == "search_hand" and cheap in g.pending.options and expensive not in g.pending.options, "Sam busca sólo Eventos C≤2")
	check(g.pending.options.all(func(u): return g.definition(u).clase == "Evento" and int(g.definition(u).coste) <= 2), "Filtro de Sam no permite Aliados")
	g.choose([cheap])
	check(cheap in g.players[0].hand, "Sam muestra Evento antes de incorporarlo a Mano")

	g = fresh()
	resources(g,0,3)
	var disappearing = bring(g,0,"0117")
	g.request_play(disappearing)
	check(g.pending.options.all(func(u): return g.definition(u).clase == "Aliado" and "Singular" in g.definition(u).palabras_clave), "Desaparición busca sólo Aliado Singular")
	var chosen = g.pending.options[0]
	g.choose([chosen])
	check(g.phase == "main" and g.actor == 0 and chosen in g.players[0].hand, "Desaparición de Papito conserva el turno corregido")

	g = fresh()
	var luchador = bring(g,0,"0111","defense")
	obj = equip(g,luchador,"0123")
	check(g.can_activate(obj) and g.activate(obj), "Pastelito en Lucha puede activarse")
	check(g.pending.options.all(func(u): return g.definition(u).clase == "Aliado" and int(g.definition(u).coste) <= 2), "Pastelito busca Aliados C≤2")
	g.skip_choice()
	check(not g.can_activate(obj), "Pastelito sólo una vez por turno propio incluso al omitir búsqueda")
	g.turn += 2
	check(g.can_activate(obj), "Pastelito se repone en el siguiente turno propio")
	g.active = 1
	check(not g.can_activate(obj), "Pastelito no se activa en turno del rival")
	g.active = 0
	g.instances[luchador].code = "0114"
	check(not g.can_activate(obj), "Pastelito no se activa con portador Salvaje")

	g = fresh()
	resources(g,0,5)
	var depul = bring(g,1,"0102","defense")
	obj = equip(g,depul,"0123")
	var own = bring(g,0,"0111","defense")
	var wipe = bring(g,0,"0119")
	g.request_play(wipe)
	check(depul in g.players[1].burned and own in g.players[0].burned and g.field(0).is_empty() and g.field(1).is_empty(), "Transmisión caída quema todos los Aliados de ambos lados")
	check(obj in g.players[1].graveyard and g.pending.is_empty(), "Quemar descarta Objetos, sin recuperación de elDepul")
	check(not g.leave(depul,"deck") and depul in g.players[1].burned, "Quemadas nunca puede regresar al Mazo")
	invariant(g,"Quemadas")

	g = fresh()
	var a1 = bring(g,0,"0110","defense")
	var a2 = bring(g,0,"0110","defense")
	depul = bring(g,1,"0102","defense")
	g.declare_attack([a1,a2])
	g.assign_block(a1,depul)
	g.finish_blocks()
	g.pass_priority()
	var before = g.players[1].deck.size()
	g.pass_priority()
	check(g.phase == "resolving" and g.pending.kind == "grave_to_deck" and g.actor == 1 and depul in g.pending.options, "elDepul derrotado al bloquear pausa el combate y puede recuperarse a sí mismo")
	check(g.players[1].deck.size() == before - 2, "Primer atacante causa diferencia de daño por separado")
	g.choose([depul])
	check(depul in g.players[1].deck and g.phase == "after_combat" and g.actor == 0 and g.players[1].deck.size() == before - 4, "Recuperación termina antes del daño del siguiente atacante")
	invariant(g,"elDepul entre atacantes")

	g = fresh(0,2)
	resources(g,0,3)
	var serandi = bring(g,1,"0130","defense")
	var incoming = bring(g,0,"0104")
	check(g.request_play(incoming) and g.pending.kind == "counter" and g.actor == 1, "Serandimini abre respuesta al jugar carta rival")
	check(incoming in g.players[0].stack and incoming not in g.players[0].hand and g.players[0].paid.size() == 2, "La carta se anuncia y paga antes de responder")
	invariant(g,"carta anunciada")
	check(not g.finish_turn() and not g.can_play(bring(g,1,"0114")), "Ningún jugador puede intercalar cartas durante anulación pendiente")
	g.choose([serandi])
	check(serandi in g.players[1].deck and incoming in g.players[0].graveyard and g.pending.is_empty() and g.players[0].stack.is_empty(), "Serandimini se baraja y carta anulada va al Cementerio sin entrada")
	check(g.actor == 0 and g.phase == "main" and g.players[0].paid.size() == 2, "Anular restablece el turno y no devuelve Coste")
	invariant(g,"anulación")
	serandi = bring(g,1,"0130","defense")
	resources(g,0,3)
	incoming = bring(g,0,"0104")
	g.request_play(incoming)
	g.skip_choice()
	check(incoming in g.players[0].defense and g.pending.kind == "search_hand" and serandi in g.field(1), "Dejar jugar conserva Serandimini y resuelve entrada de Javieriv")
	g.skip_choice()
	g.phase = "resource"
	g.request_play(bring(g,0,"0100"))
	check(g.phase == "main" and g.pending.is_empty(), "Serandimini no puede anular Recursos")

	g = fresh(0,2)
	resources(g,1,5)
	serandi = bring(g,0,"0130","defense")
	var attacker = bring(g,0,"0110","defense")
	incoming = bring(g,1,"0119")
	g.declare_attack([attacker])
	if g.phase == "blocks": g.finish_blocks()
	check(g.phase == "events" and g.actor == 1, "Defensor conserva Evento válido antes del daño")
	g.request_play(incoming)
	check(g.pending.kind == "counter" and g.event_access, "Evento del defensor permite respuestas aunque luego se anule")
	g.choose([serandi])
	check(g.phase == "events" and g.actor == 0 and g.event_access and attacker in g.field(0), "Anulación de Evento no quema Aliados ni salta prioridad")
	g.pass_priority()
	g.pass_priority()
	check(g.phase == "after_combat", "Combate continúa tras anulación")
	invariant(g,"Evento anulado")

	g = fresh()
	resources(g,0,7)
	var guitar = bring(g,0,"0134","graveyard")
	var carrier0 = bring(g,0,"0111","defense")
	carrier = bring(g,1,"0111","defense")
	var obj0 = equip(g,carrier0,"0123")
	obj = equip(g,carrier,"0123")
	var dom = bring(g,1,"0131")
	g.players[1].hand.erase(dom)
	g.domain_uid = dom
	check(g.can_play(guitar) and g.request_play(guitar), "Guitarramala se puede jugar desde Cementerio pagando Coste 7")
	check(g.players[0].paid.size() == 7 and guitar in g.players[0].defense and not g.can_attack(guitar), "Guitarramala entra sin Ágil y paga todo su Coste")
	check(g.domain_uid == -1 and dom in g.players[1].graveyard and obj0 in g.players[0].graveyard and obj in g.players[1].graveyard, "Guitarramala destruye Dominio y todos los Objetos de ambos lados")
	invariant(g,"Guitarramala")
	g.leave(guitar,"graveyard")
	g.manual_payment = [true,false]
	resources(g,0,7)
	check(g.request_play(guitar) and g.payment_request.uid == guitar and guitar in g.players[0].graveyard, "Guitarramala conserva pago manual desde Cementerio")
	for r in g.players[0].resources.duplicate():
		if g.payment_request.is_empty(): break
		g.reserve_resource(r)
	check(guitar in g.players[0].defense and g.payment_request.is_empty(), "Arrastrar siete Recursos completa Guitarramala")

	g = fresh(0,2)
	g.manual_payment = [true,false]
	resources(g,0,7)
	guitar = bring(g,0,"0134","graveyard")
	serandi = bring(g,1,"0130","defense")
	carrier = bring(g,1,"0112","defense")
	obj = equip(g,carrier,"0123")
	g.request_play(guitar)
	for r in g.players[0].resources.duplicate():
		if g.payment_request.is_empty(): break
		g.reserve_resource(r)
	check(g.pending.kind == "counter" and g.players[0].paid.size() == 7 and g.actor == 1, "Serandimini responde después de completar el pago manual desde Cementerio")
	g.choose([serandi])
	check(guitar in g.players[0].graveyard and g.instances[carrier].object == obj and g.players[0].paid.size() == 7 and g.actor == 0, "Guitarramala anulado no destruye Objetos ni devuelve los siete Recursos")
	invariant(g,"pago manual anulado desde Cementerio")

	for a in range(3):
		for b in range(3):
			for seed_value in range(6): simulate(a,b,seed_value)
			for seed_value in range(3): simulate(a,b,seed_value,true)
	print(JSON.stringify({"checks":checks,"new_complete_games":simulations,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func simulate(a,b,seed_value,manual = false):
	var g = Game.new()
	var bot = Bot.new()
	g.new_game(2000 + seed_value, [g.decklists[a],g.decklists[b]])
	g.manual_payment = [manual,false]
	var turns = 0
	var ok = true
	while g.winner == -1 and turns < 6000:
		var success = g.reserve_resource(g.players[g.actor].resources.back()) if not g.payment_request.is_empty() else bot.step(g,g.actor)
		if not success:
			ok = false
			break
		if not g.invariant_errors().is_empty():
			ok = false
			break
		turns += 1
	check(ok and g.winner != -1, "Partida completa %d/%d semilla %d, fase %s, decisión %s" % [a,b,seed_value,g.phase,str(g.pending)])
	if ok and g.winner != -1: simulations += 1
