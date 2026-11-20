extends RefCounted
## Motor local. No depende de la interfaz ni de la red.

var catalog = {}
const DeckRules = preload("res://deck_rules.gd")
var decklists = []
var players = []
var instances = {}
var domain_uid = -1
var allies_lost = [0,0]
var active = 0
var actor = 0
var turn = 0
var phase = "setup"
var setup_player = 0
var keeps = [false, false]
var changes = [0, 0]
var pending = {}
var queue = []
var log_lines = []
var error = ""
var winner = -1
var attacks = []
var blocks = {}
var combat_roles = {}
var event_access = false
var passes = 0
var next_uid = 1
var rng = RandomNumberGenerator.new()
# El jugador humano reserva Recursos arrastrándolos; el bot usa las mismas reglas.
var manual_payment = [false, false]
var reserved = [[], []]
var payment_request = {}
var announced_play = {}
var visual_events = []
const ZONES = ["deck", "hand", "defense", "attack", "graveyard", "burned", "resources", "paid", "stack"]
const RULESET_VERSION = "1.9"
const SUPPORTED = ["0100", "0101", "0102", "0103", "0104", "0105", "0106", "0107", "0108", "0109", "0110", "0111", "0112", "0113", "0114", "0115", "0116", "0117", "0118", "0119", "0120", "0121", "0122", "0123", "0124", "0125", "0126", "0127", "0128", "0129", "0130", "0131", "0132", "0133", "0134", "01a", "01b", "01c", "01d", "01e", "01f"]

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogo_edicion_1.json"))
	for c in data.cartas:
		catalog[c.codigo] = c
	decklists = JSON.parse_string(FileAccess.get_file_as_string("res://data/mazos_prueba.json")).mazos

func note(text):
	log_lines.append(text)
	if log_lines.size() > 160:
		log_lines.pop_front()

func visual(data):
	visual_events.append(data.duplicate(true))

func visual_move(uid, from_zone, to_zone, extra = {}):
	var event = {"kind":"move", "uid":uid, "player":instances[uid].owner, "from":from_zone, "to":to_zone}
	event.merge(extra, true)
	visual(event)

func take_visual_events():
	var events = visual_events.duplicate(true)
	visual_events.clear()
	return events

func fail(text):
	error = text
	return false

func shuffled(items):
	var out = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out

func new_game(seed_value = -1, selected_decks = []):
	# Base/challenge lists retain their established rules. Custom lists must be
	# finalized before any instances or previous table state are replaced.
	if selected_decks.size() == 2:
		for deck in selected_decks:
			if deck is Dictionary and deck.get("custom", false) == true:
				var validation = DeckRules.validate(deck, catalog)
				if deck.get("draft", false) == true: return fail("Este mazo es un borrador. Termínalo antes de jugar.")
				if not validation.ok: return fail(validation.message)
	allies_lost=[0,0]
	instances.clear()
	players.clear()
	queue.clear()
	pending.clear()
	log_lines.clear()
	visual_events.clear()
	error = ""
	attacks.clear()
	blocks.clear()
	combat_roles.clear()
	passes = 0
	event_access = false
	domain_uid = -1
	next_uid = 1
	winner = -1
	turn = 0
	phase = "setup"
	setup_player = 0
	keeps = [false, false]
	changes = [0, 0]
	reserved = [[], []]
	payment_request.clear()
	announced_play.clear()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	active = rng.randi_range(0, 1)
	actor = 0
	for p in range(2):
		var deck = selected_decks[p] if selected_decks.size() == 2 else decklists[p]
		var state = {"name": deck.nombre, "deck_id": deck.id}
		for zone in ZONES:
			state[zone] = []
		players.append(state)
		for entry in deck.cartas:
			for _copy in range(int(entry.cantidad)):
				var uid = spawn(entry.codigo, p)
				state.deck.append(uid)
		for uid in state.deck.duplicate():
			if code(uid) == "0100":
				state.deck.erase(uid)
				state.resources.append(uid)
				visual_move(uid, "deck", "resources")
				break
		state.deck = shuffled(state.deck)
		visual({"kind":"shuffle", "player":p})
		draw(p, 6)
	note("Preparación: seis cartas y un Recurso Inicial por jugador.")
	note("Comenzará %s, elegido al azar." % players[active].name)
	return true

func spawn(card_code, owner):
	var uid = next_uid
	next_uid += 1
	instances[uid] = {"uid": uid, "code": card_code, "owner": owner, "entered": -1, "object": -1, "used": -1, "papito_empowered": false}
	return uid

func code(uid):
	return DeckRules.canonical(instances[uid].code)

func printed_code(uid):return instances[uid].code

func definition(uid):
	return catalog[printed_code(uid)]

func title(uid):
	return definition(uid).nombre

func location(uid):
	if domain_uid == uid:
		return {"player": instances[uid].owner, "zone": "domain"}
	for p in range(players.size()):
		for z in ZONES:
			if uid in players[p][z]:
				return {"player": p, "zone": z}
		for ally in field(p):
			if instances[ally].object == uid:
				return {"player": p, "zone": "object", "carrier": ally}
	return {}

func field(p):
	return players[p].defense + players[p].attack

func count_code(p, card_code):
	var n = 0
	for uid in field(p):
		if code(uid) == card_code:
			n += 1
	return n

func all_permanents():
	var out = field(0) + field(1)
	for uid in out.duplicate():
		if instances[uid].object != -1:
			out.append(instances[uid].object)
	if domain_uid != -1:
		out.append(domain_uid)
	return out

func draw(p, amount):
	for _i in range(amount):
		if winner != -1:
			return
		if players[p].deck.is_empty():
			lose(p)
			return
		var uid = players[p].deck.pop_front()
		players[p].hand.append(uid)
		visual_move(uid, "deck", "hand")
		check_deck(p)

func lose(p):
	winner = 1 - p
	phase = "finished"
	pending.clear()
	queue.clear()
	note("%s se quedó sin Mazo. Gana %s." % [players[p].name, players[winner].name])

func check_deck(p):
	if winner == -1 and players[p].deck.is_empty():
		lose(p)

func mulligan():
	error = ""
	if phase != "setup" or changes[setup_player] >= 2:
		return fail("Puedes cambiar la mano hasta dos veces.")
	var p = setup_player
	for uid in players[p].hand:
		visual_move(uid, "hand", "deck")
	players[p].deck.append_array(players[p].hand)
	players[p].hand.clear()
	players[p].deck = shuffled(players[p].deck)
	visual({"kind":"shuffle", "player":p})
	changes[p] += 1
	draw(p, 5)
	note("%s cambia su mano: recibe cinco cartas (%d/2)." % [players[p].name, changes[p]])
	return true

func keep_hand():
	if phase != "setup":
		return false
	keeps[setup_player] = true
	if setup_player == 0:
		setup_player = 1
		actor = 1
	else:
		start_turn()
	return true

func start_turn():
	turn += 1
	actor = active
	phase = "resource"
	error = ""
	attacks.clear()
	blocks.clear()
	combat_roles.clear()
	reserved[active].clear()
	passes = 0
	event_access = false
	for uid in players[active].paid: visual_move(uid, "paid", "resources")
	for uid in players[active].attack: visual_move(uid, "attack", "defense")
	players[active].resources.append_array(players[active].paid)
	players[active].paid.clear()
	players[active].defense.append_array(players[active].attack)
	players[active].attack.clear()
	note("Turno %d · %s reagrupa." % [turn, players[active].name])
	if not has_resource_in_hand(active):
		phase = "main"
		note("Sin Recursos en Mano: %s pasa a Acciones." % players[active].name)

func has_resource_in_hand(p):
	return players[p].hand.any(func(uid): return definition(uid).clase == "Recurso")

func skip_resource():
	if phase != "resource" or not pending.is_empty():
		return false
	phase = "main"
	note("%s cierra la oportunidad de bajar Recurso." % players[active].name)
	return true

func can_play(uid):
	if winner != -1 or not pending.is_empty() or not payment_request.is_empty() or not instances.has(uid):
		return false
	if uid not in players[actor].hand and not (code(uid) == "0134" and uid in players[actor].graveyard):
		return false
	var d = definition(uid)
	if d.clase == "Recurso":
		return phase == "resource" and actor == active
	if code(uid) not in SUPPORTED:
		return false
	if code(uid) == "0118" and last_ally_in_graveyard(1 - actor) == -1:
		return false
	if int(d.coste) > players[actor].resources.size() + reserved[actor].size():
		return false
	if phase == "main" and actor == active:
		return not (d.clase == "Objeto" and domain_uid != -1 and code(domain_uid) == "0121")
	if phase == "events" and d.clase == "Evento":
		return actor != active or event_access
	return false

func request_play(uid, target = -1):
	error = ""
	if not can_play(uid):
		return fail("Esta carta no puede jugarse ahora o faltan Recursos.")
	var p = actor
	var d = definition(uid)
	if d.clase == "Recurso":
		players[p].hand.erase(uid)
		players[p].resources.append(uid)
		visual_move(uid, "hand", "resources")
		phase = "main"
		note("%s baja un Recurso." % players[p].name)
		return true
	var targets = play_targets(uid)
	if d.clase == "Objeto" or code(uid) in ["0116", "0133"]:
		if targets.is_empty():
			return fail("No hay un objetivo válido para esta carta.")
		if target != -1:
			if target not in targets:
				return fail("Ese objetivo no es válido para la carta.")
			begin_play(uid, target)
		else:
			set_choice({"kind": "play_target", "player": p, "title": "Objetivo de %s" % title(uid), "options": targets, "min": 1, "max": 1, "optional": true, "source": uid})
	else:
		begin_play(uid)
	return true

func play_targets(uid):
	var p = instances[uid].owner
	var d = definition(uid)
	var targets = []
	if d.clase == "Objeto":
		for a in field(p):
			if instances[a].object == -1:
				targets.append(a)
	elif code(uid) == "0116":
		for a in field(1 - p):
			if int(definition(a).coste) <= 2:
				targets.append(a)
	elif code(uid) == "0133":
		targets = all_permanents()
	return targets

func begin_play(uid, target = -1):
	var p = instances[uid].owner
	if manual_payment[p] and reserved[p].size() < int(definition(uid).coste):
		payment_request = {"uid": uid, "target": target, "player": p, "cost": int(definition(uid).coste)}
		note("Paga %d Recursos para jugar %s." % [int(definition(uid).coste), title(uid)])
		return true
	return commit_play(uid, target)

func can_reserve(uid):
	if winner != -1 or not pending.is_empty() or uid not in players[actor].resources or not manual_payment[actor]:
		return false
	if payment_request.get("kind", "card") == "ability" and actor == active and phase in ["main", "events", "after_combat"]: return true
	return (phase == "main" and actor == active) or (phase == "events" and (actor != active or event_access))

func reserve_resource(uid):
	error = ""
	if not can_reserve(uid):
		return fail("Ahora no puedes preparar un pago.")
	players[actor].resources.erase(uid)
	players[actor].paid.append(uid)
	reserved[actor].append(uid)
	visual_move(uid, "resources", "paid")
	if not payment_request.is_empty() and reserved[actor].size() >= int(payment_request.cost):
		var request = payment_request.duplicate()
		payment_request.clear()
		if request.get("kind", "card") == "ability":
			return commit_ability(request.uid, request.target)
		return commit_play(request.uid, request.target)
	return true

func refund_resource(uid):
	if uid not in reserved[actor]:
		return fail("Ese Recurso ya se gastó. Se reagrupará en tu siguiente turno.")
	reserved[actor].erase(uid)
	players[actor].paid.erase(uid)
	players[actor].resources.append(uid)
	visual_move(uid, "paid", "resources")
	return true

func refund_all(p):
	for uid in reserved[p].duplicate():
		players[p].paid.erase(uid)
		players[p].resources.append(uid)
		visual_move(uid, "paid", "resources")
	reserved[p].clear()

func cancel_payment():
	if payment_request.is_empty() and reserved[actor].is_empty():
		return false
	payment_request.clear()
	refund_all(actor)
	note("Pago sin completar cancelado: los Recursos preparados vuelven a estar disponibles.")
	return true

func pay(p, cost):
	if (manual_payment[p] and reserved[p].size() < cost) or players[p].resources.size() + reserved[p].size() < cost:
		return false
	for _i in range(cost):
		if not reserved[p].is_empty():
			reserved[p].pop_front()
		else:
			var uid = players[p].resources.pop_back()
			players[p].paid.append(uid)
			visual_move(uid, "resources", "paid")
	return true

func commit_play(uid, target = -1):
	var p = instances[uid].owner
	var d = definition(uid)
	var source = "hand" if uid in players[p].hand else "graveyard"
	if (source == "graveyard" and (code(uid) != "0134" or uid not in players[p].graveyard)) or not pay(p, int(d.coste)):
		return fail("La carta o los Recursos ya no están disponibles.")
	players[p][source].erase(uid)
	players[p].stack.append(uid)
	note("%s juega %s (Coste %d)." % [players[p].name, d.nombre, int(d.coste)])
	var battle_event = phase == "events"
	if battle_event and p != active: event_access = true
	announced_play = {"uid":uid, "player":p, "target":target, "source":source, "battle_event":battle_event, "revealed":false}
	var counters = field(1 - p).filter(func(u): return code(u) == "0130")
	if not counters.is_empty():
		announced_play.revealed = true
		visual_move(uid, source, "stack", {"reveal":true, "played":true})
		set_choice({"kind":"counter", "player":1 - p, "title":"Serandimini: ¿anular %s?" % title(uid), "options":counters, "min":1, "max":1, "optional":true, "source":uid})
		return true
	return resolve_announced_play()

func resolve_announced_play(counter_uid = -1):
	if announced_play.is_empty(): return false
	var play = announced_play.duplicate()
	announced_play.clear()
	var uid = play.uid
	var p = play.player
	var target = play.target
	var d = definition(uid)
	var source = "stack" if play.revealed else play.source
	actor = p
	players[p].stack.erase(uid)
	if counter_uid != -1:
		return_to_deck([counter_uid])
		players[p].graveyard.append(uid)
		visual_move(uid, source, "graveyard", {"reveal":true, "played":not play.revealed})
		note("Serandimini anula %s: va al Cementerio sin resolver; el Coste queda pagado." % title(uid))
	elif d.clase == "Aliado":
		instances[uid].entered = turn
		instances[uid].papito_empowered = false
		players[p].defense.append(uid)
		visual_move(uid, source, "defense", {"played":not play.revealed})
		queue.append({"kind":"enter", "uid":uid, "player":p})
		queue.append({"kind":"check_limits"})
	elif d.clase == "Objeto":
		instances[target].object = uid
		visual_move(uid, source, "object", {"carrier":target, "played":not play.revealed})
	elif d.clase == "Dominio":
		if domain_uid != -1: leave(domain_uid, "graveyard")
		domain_uid = uid
		visual_move(uid, source, "domain", {"played":not play.revealed})
		queue.append({"kind":"check_limits"})
	elif d.clase == "Evento":
		players[p].graveyard.append(uid)
		visual_move(uid, source, "graveyard", {"via":"events", "played":not play.revealed})
		match code(uid):
			"0118":
				var last_ally = last_ally_in_graveyard(1 - p)
				if last_ally != -1: leave(last_ally, "burned")
			"0116": leave(target, "deck")
			"0133": leave(target, "graveyard")
			"0117": queue.append({"kind":"search", "player":p, "class":"Aliado", "singular":true, "count":1, "optional":true, "shuffle":false, "name":"Desaparición de Papito"})
			"0119":
				for ally in (field(0) + field(1)).duplicate(): leave(ally, "burned")
			"0120": queue.append({"kind":"search", "player":p, "class":"Aliado", "max_cost":2, "count":3, "optional":true, "shuffle":true, "name":"Raid de Nanchy"})
			"0132": queue.append({"kind":"search", "player":p, "class":"Dominio", "count":1, "optional":true, "shuffle":true, "name":"Descubrimiento Ancestral"})
	if play.battle_event: queue.append({"kind":"advance_priority"})
	drain()
	return true

func leave(uid, destination, shuffle_after = true):
	var loc = location(uid)
	if loc.is_empty() or loc.zone == "burned": return false
	var owner = instances[uid].owner
	if loc.zone in ["attack","defense"] and definition(uid).clase=="Aliado" and destination in ["graveyard","burned"]:allies_lost[owner]+=1
	if definition(uid).clase == "Aliado" and instances[uid].object != -1:
		var obj = instances[uid].object
		instances[uid].object = -1
		players[instances[obj].owner].graveyard.append(obj)
		visual_move(obj, "object", "graveyard", {"carrier":uid})
		note("%s se descarta al Cementerio al salir su portador." % title(obj))
	if loc.zone == "domain":
		domain_uid = -1
	elif loc.zone == "object":
		instances[loc.carrier].object = -1
	else:
		players[loc.player][loc.zone].erase(uid)
	players[owner][destination].append(uid)
	instances[uid].papito_empowered = false
	# A continuous or temporary effect belongs to this stay on the battlefield.
	# Returning the same physical card later cannot retain a previous buff.
	instances[uid].force_bonus = 0
	instances[uid].force_bonus_turn = -1
	instances[uid].unblockable_turn = -1
	visual_move(uid, loc.zone, destination)
	if destination == "deck":
		if shuffle_after: shuffle_deck(owner)
		instances[uid].entered = -1
	note("%s → %s de %s." % [title(uid), zone_name(destination), players[owner].name])
	return true

func last_ally_in_graveyard(p):
	# Graveyard order already records every arrival, including damage and discard.
	# An Ally which subsequently left this zone is no longer an eligible victim.
	for index in range(players[p].graveyard.size() - 1, -1, -1):
		var uid = players[p].graveyard[index]
		if definition(uid).clase == "Aliado": return uid
	return -1

func shuffle_deck(p):
	players[p].deck = shuffled(players[p].deck)
	visual({"kind":"shuffle", "player":p})

func return_to_deck(cards):
	var owners = []
	for uid in cards:
		if leave(uid, "deck", false) and instances[uid].owner not in owners: owners.append(instances[uid].owner)
	for p in owners: shuffle_deck(p)

func zone_name(z):
	return {"deck": "Mazo", "graveyard": "Cementerio", "burned": "Quemadas", "hand": "Mano", "defense": "Defensa", "attack": "Ataque", "resources": "Recursos", "paid": "Pagados"}.get(z, z)

func set_choice(data):
	pending = data
	actor = int(data.player)

func choose(selected):
	error = ""
	if pending.is_empty():
		return fail("No hay una elección pendiente.")
	var c = pending.duplicate(true)
	var unique = []
	for uid in selected:
		if uid not in c.options or uid in unique:
			return fail("Selección inválida.")
		unique.append(uid)
	if unique.size() < int(c.min) or unique.size() > int(c.max):
		return fail("Selecciona entre %d y %d cartas." % [int(c.min), int(c.max)])
	pending.clear()
	if c.kind == "play_target":
		begin_play(c.source, unique[0])
	elif c.kind == "counter":
		return resolve_announced_play(unique[0])
	elif c.kind in ["sacrifice_ally", "grant_unblockable"]:
		if not begin_ability(c.source, unique[0]): return false
	elif c.kind == "grave_to_deck":
		return_to_deck(unique)
	elif c.kind == "remove_permanent":
		for uid in unique: leave(uid, "graveyard")
	elif c.kind == "search_hand":
		for uid in unique:
			var origin = location(uid).zone
			players[c.player][origin].erase(uid)
			players[c.player].hand.append(uid)
			visual_move(uid, origin, "hand", {"reveal":true})
			note("%s muestra %s y lo pone en su Mano." % [players[c.player].name, title(uid)])
		if c.get("shuffle", false):
			players[c.player].deck = shuffled(players[c.player].deck)
			visual({"kind":"shuffle", "player":c.player})
		check_deck(c.player)
	elif c.kind == "reorder":
		var rest = players[c.player].deck.duplicate()
		for uid in unique:
			rest.erase(uid)
		players[c.player].deck = unique + rest
		visual({"kind":"reorder", "player":c.player})
		note("%s reordena las tres primeras cartas." % players[c.player].name)
	elif c.kind == "limit_keep":
		for uid in field(c.player).duplicate():
			if uid not in unique:
				leave(uid, "graveyard")
	elif c.kind == "end_discard":
		for uid in unique:
			leave(uid, "graveyard")
		finish_next_turn()
	drain()
	return true

func skip_choice():
	if pending.is_empty() or not pending.get("optional", false):
		return fail("Esta elección es obligatoria.")
	var c = pending.duplicate(true)
	pending.clear()
	if c.kind == "counter": return resolve_announced_play()
	if c.kind == "search_hand" and c.get("shuffle", false):
		players[c.player].deck = shuffled(players[c.player].deck)
		visual({"kind":"shuffle", "player":c.player})
	note("%s omite la elección." % players[c.player].name)
	drain()
	return true

func discard_by_drag(uid):
	if pending.is_empty() or pending.player != actor or uid not in pending.options:
		return fail("No corresponde descartar esa carta ahora.")
	if pending.kind == "end_discard":
		leave(uid, "graveyard")
		pending.options.erase(uid)
		pending.min -= 1
		pending.max -= 1
		if int(pending.max) == 0:
			pending.clear()
			finish_next_turn()
		return true
	if pending.kind == "limit_keep":
		var p = int(pending.player)
		leave(uid, "graveyard")
		pending.options.erase(uid)
		if field(p).size() == int(pending.max):
			pending.clear()
			drain()
		return true
	return fail("Esta elección se completa en su ventana.")

func search_options(effect):
	var options = []
	for z in effect.get("zones", ["deck"]):
		for uid in players[effect.player][z]:
			var d = definition(uid)
			if effect.has("code") and code(uid) != effect.code: continue
			if effect.has("class") and d.clase != effect["class"]: continue
			if effect.has("max_cost") and int(d.coste) > int(effect.max_cost): continue
			if effect.get("singular", false) and "Singular" not in d.palabras_clave: continue
			options.append(uid)
	return options

func drain():
	while not queue.is_empty() and pending.is_empty() and winner == -1:
		var effect = queue.pop_front()
		match effect.kind:
			"enter":
				var uid = effect.uid
				match code(uid):
					"0101": queue.push_front({"kind":"search", "player":effect.player, "code":"0114", "count":1, "optional":true, "shuffle":true, "name":"Nonungus"})
					"0104": queue.push_front({"kind":"search", "player":effect.player, "class":"Aliado", "max_cost":3, "count":1, "optional":true, "shuffle":true, "name":"Javieriv"})
					"0105": queue.push_front({"kind":"recover", "player":effect.player, "max_cost":3, "count":2, "name":"Kajido"})
					"0107": queue.push_front({"kind":"search", "player":effect.player, "code":"0124", "count":1, "optional":true, "shuffle":true, "name":"Dicky"})
					"0108":
						var top = players[effect.player].deck.slice(0, 3)
						if not top.is_empty(): set_choice({"kind":"reorder", "player":effect.player, "title":"Maagover: elige el orden del tope", "options":top, "min":top.size(), "max":top.size(), "optional":true})
					"0110":
						var options = all_permanents().filter(func(u): return definition(u).clase in ["Dominio", "Objeto"])
						if not options.is_empty(): set_choice({"kind":"remove_permanent", "player":effect.player, "title":"Feranando: envía un Dominio u Objeto al Cementerio", "options":options, "min":1, "max":1, "optional":true})
					"0114": queue.push_front({"kind":"search", "player":effect.player, "class":"Evento", "max_cost":2, "count":1, "optional":true, "shuffle":true, "name":"Sam"})
					"0115":
						var oscars = field(effect.player).filter(func(u): return code(u) == "0106")
						instances[uid].papito_empowered = oscars.size() >= 3
						return_to_deck(oscars)
						if instances[uid].papito_empowered: note("Papito obtiene +2 de Fuerza, Ágil e Imbloqueable.")
					"0134":
						for permanent in all_permanents().duplicate():
							if definition(permanent).clase in ["Dominio", "Objeto"]: leave(permanent, "graveyard")
			"search":
				var options = search_options(effect)
				if options.is_empty():
					note("%s: no se encontró una carta válida." % effect.name)
					if effect.get("shuffle", false): shuffle_deck(effect.player)
				else:
					set_choice({"kind":"search_hand", "player":effect.player, "title":"%s: busca y muestra" % effect.name, "options":options, "min":0, "max":mini(int(effect.count), options.size()), "optional":true, "shuffle":effect.get("shuffle", false)})
			"recover":
				effect["class"] = "Aliado"
				effect.zones = ["graveyard"]
				var options = search_options(effect)
				if options.size() >= int(effect.count): set_choice({"kind":"grave_to_deck", "player":effect.player, "title":"%s: elige %d Aliado(s) del Cementerio para barajar" % [effect.name, int(effect.count)], "options":options, "min":int(effect.count), "max":int(effect.count), "optional":true})
			"check_limits":
				if domain_uid != -1 and code(domain_uid) == "0131":
					for p in range(2):
						if field(p).size() > 4:
							queue.push_front({"kind":"check_limits"})
							set_choice({"kind":"limit_keep", "player":p, "title":"Escuela de Vuelo: conserva cuatro Aliados", "options":field(p), "min":4, "max":4, "optional":false})
							break
			"advance_priority":
				passes = 0
				actor = 1 - actor
			"combat": combat_step(effect.uid)
			"hnyko_damage": mill(effect.player, 2, "HNyko", effect.uid)
			"end_combat":
				combat_roles.clear()
				phase = "after_combat"
				actor = active
				note("Combate resuelto. Corresponde robar y terminar el turno.")
	if pending.is_empty() and winner == -1 and phase not in ["setup", "events"]:
		actor = (1 - active) if phase == "blocks" else active

func can_activate(uid):
	if winner != -1 or not payment_request.is_empty() or not pending.is_empty() or not instances.has(uid) or actor != active or phase not in ["main", "events", "after_combat"]: return false
	if code(uid) == "01b": return uid in field(actor) and instances[uid].used != turn
	if code(uid) == "0126": return uid in field(actor) and instances[uid].used != turn
	if code(uid) == "0129": return uid in field(actor) and instances[uid].used != turn and players[actor].resources.size() + reserved[actor].size() >= 1
	if code(uid) == "0106": return uid in field(actor) and count_code(actor, "0106") >= 3 and not search_options({"player":actor, "code":"0115", "zones":["deck", "graveyard"]}).is_empty()
	if code(uid) == "0123":
		var loc = location(uid)
		return loc.get("zone") == "object" and loc.player == actor and definition(loc.carrier).tipo_aliado == "Lucha" and instances[uid].used != turn
	return false

func activate(uid):
	if not can_activate(uid): return fail("La habilidad no está disponible en este momento.")
	if code(uid) in ["0126", "0129"]:
		var sacrifice = code(uid) == "0126"
		set_choice({"kind":"sacrifice_ally" if sacrifice else "grant_unblockable", "player":actor, "source":uid, "options":field(actor).duplicate(), "min":1, "max":1, "optional":true, "title":"Viborín: envía un Aliado propio al Cementerio" if sacrifice else "Almenta: elige un Aliado y paga 1 Recurso"})
		return true
	instances[uid].used = turn
	match code(uid):
		"01b": queue.append({"kind":"search", "player":actor, "class":"Objeto", "count":1, "shuffle":true, "name":"Bigotes"})
		"0106": queue.append({"kind":"search", "player":actor, "code":"0115", "zones":["deck", "graveyard"], "count":1, "shuffle":true, "name":"Oscarksss"})
		"0123": queue.append({"kind":"search", "player":actor, "class":"Aliado", "max_cost":2, "count":1, "shuffle":true, "name":"Pastelito de manjar"})
	drain()
	return true

func begin_ability(uid, target):
	if not can_activate(uid) or target not in field(actor): return fail("La habilidad o su objetivo ya no están disponibles.")
	if code(uid) == "0129" and manual_payment[actor] and reserved[actor].size() < 1:
		payment_request = {"kind":"ability", "uid":uid, "target":target, "player":actor, "cost":1}
		note("Paga 1 Recurso para activar Almenta.")
		return true
	return commit_ability(uid, target)

func commit_ability(uid, target):
	if not can_activate(uid) or target not in field(actor): return fail("La habilidad o su objetivo ya no están disponibles.")
	var p = actor
	if code(uid) == "0129":
		if not pay(p, 1): return fail("Falta 1 Recurso para activar Almenta.")
		instances[uid].used = turn
		instances[target].unblockable_turn = turn
		note("Almenta: %s es Imbloqueable hasta el final del turno." % title(target))
	elif code(uid) == "0126":
		instances[uid].used = turn
		if not leave(target, "graveyard"): return fail("No se pudo enviar ese Aliado al Cementerio.")
		# 'Uno de tus Aliados' includes the source. Sacrificing itself pays the
		# cost but cannot grant Force to a card which has left the battlefield.
		if uid in field(p):
			instances[uid].force_bonus = 3
			instances[uid].force_bonus_turn = turn
			note("Viborín gana +3 de Fuerza hasta el final del turno.")
	else: return fail("Esa carta no tiene esta habilidad.")
	if phase == "events": passes = 0
	return true

func agile(uid):
	return "Ágil" in definition(uid).palabras_clave or (code(uid) == "0115" and instances[uid].papito_empowered)

func unblockable(uid):
	var p = instances[uid].owner
	return (uid in field(p) and int(instances[uid].get("unblockable_turn", -1)) == turn) or "Imbloqueable" in definition(uid).palabras_clave or (code(uid) == "01a" and count_code(p, "0127") > 0) or (code(uid) == "0115" and instances[uid].papito_empowered) or (code(uid) == "0103" and count_code(p, "0112") > 0 and count_code(p, "0113") > 0)

func force(uid):
	var d = definition(uid)
	if d.clase != "Aliado": return 0
	var p = instances[uid].owner
	var n = int(d.fuerza)
	# Chanchuus retains its printed Force; equipped Objects may still have
	# other abilities, but another card cannot modify this Force or Cost.
	if code(uid) == "0125": return n
	match code(uid):
		"0103":
			for side in range(2): n += count_code(side, "0112") + count_code(side, "0113")
		"0105":
			for ally in field(p):
				if definition(ally).tipo_aliado in ["Fundamental", "Lucha"]: n += 1
		"0109":
			if domain_uid != -1: n += 2
		"0112": n += count_code(p, "0113")
		"0113": n += count_code(p, "0112")
		"0115":
			if instances[uid].papito_empowered: n += 2
		"0127":
			if count_code(p, "01a") > 0: n += 2
		"0111":
			if uid in players[p].attack: n += 1
			elif uid in players[p].defense and combat_roles.get(uid, "") == "block": n += 2
		"01e":
			if instances[uid].object != -1: n += 2
		"01f":
			if uid in field(p): n += count_code(0, "01f") + count_code(1, "01f") - 1
	if uid in field(p) and int(instances[uid].get("force_bonus_turn", -1)) == turn:
		n += int(instances[uid].get("force_bonus", 0))
	var obj = instances[uid].object
	if obj != -1 and code(obj) == "0124": n += 4 if code(uid) in ["0107", "0108"] else 1
	return n

func can_attack(uid):
	return uid in players[active].defense and (instances[uid].entered < turn or agile(uid))

func declare_attack(selected):
	error = ""
	if phase != "main" or not pending.is_empty() or not payment_request.is_empty() or selected.is_empty():
		return fail("Selecciona al menos un Aliado que pueda atacar.")
	var seen = []
	for uid in selected:
		if not can_attack(uid) or uid in seen:
			return fail("Uno de los Aliados seleccionados aún no puede atacar.")
		seen.append(uid)
	attacks = selected.duplicate()
	refund_all(active)
	blocks.clear()
	combat_roles.clear()
	for uid in attacks:
		players[active].defense.erase(uid)
		players[active].attack.append(uid)
		visual_move(uid, "defense", "attack")
		combat_roles[uid] = "attack"
	phase = "blocks"
	actor = 1 - active
	visual({"kind":"attack", "player":active, "uids":attacks.duplicate()})
	note("%s declara ataque con %d Aliados." % [players[active].name, attacks.size()])
	if players[actor].defense.is_empty():
		note("Sin Aliados en Defensa: no se requiere confirmar bloqueos.")
		finish_blocks()
		if not has_event_response():
			note("Sin Eventos jugables: el daño pasa automáticamente.")
			pass_priority()
	return true

func has_event_response():
	for uid in players[actor].hand:
		if definition(uid).clase != "Evento" or not can_play(uid): continue
		if code(uid) in ["0116", "0133"] and play_targets(uid).is_empty(): continue
		return true
	return false

func assign_block(attacker, blocker):
	if phase != "blocks" or attacker not in attacks:
		return fail("No se pueden asignar bloqueos ahora.")
	if blocker == -1:
		if blocks.has(attacker):
			combat_roles.erase(blocks[attacker])
		blocks.erase(attacker)
		return true
	if blocker not in players[1 - active].defense:
		return fail("El bloqueador debe estar en Defensa.")
	if unblockable(attacker) and not (domain_uid != -1 and code(domain_uid) == "0122"):
		return fail("Este Aliado es Imbloqueable.")
	if blocker in blocks.values() and blocks.get(attacker, -1) != blocker:
		return fail("Un Aliado defensor solo puede bloquear a un atacante.")
	if blocks.has(attacker):
		combat_roles.erase(blocks[attacker])
	blocks[attacker] = blocker
	combat_roles[blocker] = "block"
	visual({"kind":"block", "player":1 - active, "uid":blocker, "attacker":attacker})
	return true

func finish_blocks():
	if phase != "blocks":
		return false
	event_access = not blocks.is_empty()
	passes = 0
	phase = "events"
	actor = 1 - active
	note("El defensor tiene la primera oportunidad de jugar un Evento.")
	return true

func pass_priority():
	if phase != "events" or not pending.is_empty() or not payment_request.is_empty():
		return false
	refund_all(actor)
	note("%s pasa." % players[actor].name)
	passes += 1
	if passes >= 2 or (actor != active and not event_access):
		resolve_combat()
	else:
		actor = 1 - actor
	return true

func mill(p, amount, source, source_uid = -1):
	var dealt = 0
	visual({"kind":"damage", "player":p, "amount":mini(amount, players[p].deck.size()), "source_uid":source_uid})
	for _i in range(amount):
		if winner != -1:
			break
		if players[p].deck.is_empty():
			check_deck(p)
			break
		var uid = players[p].deck.pop_front()
		players[p].graveyard.append(uid)
		visual_move(uid, "deck", "graveyard")
		dealt += 1
		check_deck(p)
	note("%s causa %d de daño al Mazo de %s." % [source, dealt, players[p].name])

func resolve_combat():
	phase = "resolving"
	for uid in attacks: queue.append({"kind":"combat", "uid":uid})
	queue.append({"kind":"end_combat"})
	drain()

func defeated(uid, during_defense = false):
	if not instances.has(uid) or uid not in field(instances[uid].owner): return
	var p = instances[uid].owner
	var burn = domain_uid != -1 and code(domain_uid) == "01d"
	leave(uid, "burned" if burn else "graveyard")
	if code(uid) == "0102" and during_defense:
		queue.push_front({"kind":"recover", "player":p, "count":1, "name":"elDepul"})
	if code(uid) == "0128":
		queue.push_front({"kind":"hnyko_damage", "player":1 - p, "uid":uid})

func combat_step(uid):
	if uid not in field(active): return
	var f = force(uid)
	var b = blocks.get(uid, -1)
	if b == -1 or b not in players[1 - active].defense:
		mill(1 - active, f, title(uid), uid)
		return
	var bf = force(b)
	if f > bf:
		mill(1 - active, f - bf, title(uid), uid)
		if winner == -1: defeated(b, true)
	elif f == bf:
		defeated(uid)
		defeated(b, true)
	else:
		defeated(uid)

func finish_turn():
	if phase not in ["main", "after_combat"] or not pending.is_empty() or not payment_request.is_empty():
		return fail("Primero completa las acciones o elecciones pendientes.")
	phase = "closing"
	actor = active
	refund_all(active)
	draw(active, 1)
	if winner != -1:
		return true
	if players[active].hand.size() < 3:
		draw(active, 3 - players[active].hand.size())
	if winner != -1:
		return true
	note("%s roba para terminar: Mano de %d cartas." % [players[active].name, players[active].hand.size()])
	if players[active].hand.size() > 8:
		var n = players[active].hand.size() - 8
		set_choice({"kind": "end_discard", "player": active, "title": "Descarta %d para quedar con ocho" % n, "options": players[active].hand.duplicate(), "min": n, "max": n, "optional": false})
	else:
		finish_next_turn()
	return true

func finish_next_turn():
	if winner == -1:
		active = 1 - active
		start_turn()

func invariant_errors():
	var used = []
	var out = []
	for p in range(players.size()):
		var count = 0
		for z in ZONES:
			for uid in players[p][z]:
				used.append(uid)
				count += 1
		for uid in field(p):
			if instances[uid].object != -1:
				used.append(instances[uid].object)
				count += 1
		if domain_uid != -1 and instances[domain_uid].owner == p:
			used.append(domain_uid)
			count += 1
		if count != 40:
			out.append("%s tiene %d cartas, se esperaban 40." % [players[p].name, count])
	var unique = {}
	for uid in used:
		if unique.has(uid):
			out.append("Carta duplicada: %s" % uid)
		unique[uid] = true
	return out
