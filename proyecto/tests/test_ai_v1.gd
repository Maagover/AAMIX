extends SceneTree
const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
const Badge = preload("res://new_card_badge.gd")
var checks = 0
var failures = []
var bot = Bot.new()

func check(result, label):
	checks += 1
	if not result: failures.append(label)

func fresh(deck_size = 12):
	var g = Game.new()
	for p in range(2):
		var state = {"name":"Prueba", "deck_id":"fixture"}
		for z in g.ZONES: state[z] = []
		g.players.append(state)
		for _i in range(deck_size): add(g, p, "0100", "deck")
		for _i in range(8): add(g, p, "0100", "resources")
	g.actor = 0; g.active = 0; g.turn = 5; g.phase = "main"
	return g

func add(g, p, code, zone):
	var uid = g.spawn(code, p)
	g.players[p][zone].append(uid)
	g.instances[uid].entered = 1
	return uid

func school(g, count):
	g.domain_uid = g.spawn("0131", 1)
	for _i in range(count): add(g, 0, "0102", "defense")

func _initialize(): run.call_deferred()

func efficient_block_case():
	var g = fresh(); g.phase = "blocks"; g.active = 1; g.actor = 0
	var first = add(g, 1, "0106", "attack"); g.attacks = [first]
	var expensive = add(g, 0, "0105", "defense")
	var efficient = add(g, 0, "0104", "defense")
	return bot.block(g, 0) and g.blocks.get(first, -1) == efficient and expensive not in g.blocks.values()

func run():
	if "--only=blocking" in OS.get_cmdline_user_args():
		check(efficient_block_case(), "Prefiere el bloqueador que gana sin comprometer el Aliado más valioso")
		print(JSON.stringify({"ai_v1_repaired_fixture_checks":checks, "failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	var g = fresh()
	school(g, 4)
	var ally = add(g, 0, "0109", "hand")
	check(not bot.try_play(g, 0) and ally in g.players[0].hand and g.players[0].resources.size() == 8 and g.pending.is_empty(), "Escuela: cuatro Aliados no gastan Recursos en un quinto")
	g = fresh(); school(g, 3)
	ally = add(g, 0, "0102", "hand")
	check(bot.try_play(g, 0) and ally in g.field(0) and g.field(0).size() == 4, "Escuela permite ocupar la cuarta plaza")
	g = fresh(); school(g, 4)
	ally = add(g, 0, "0134", "hand")
	check(bot.try_play(g, 0) and ally in g.field(0) and g.domain_uid == -1 and g.pending.is_empty(), "Guitarramala puede retirar Escuela antes de comprobar el límite")

	g = fresh()
	var maagover = add(g, 0, "0108", "defense")
	var item = g.spawn("0124", 0); g.instances[maagover].object = item
	for _i in range(4): add(g, 0, "0109", "defense")
	g.set_choice({"kind":"limit_keep", "player":0, "options":g.field(0), "min":4, "max":4, "optional":false})
	check(bot.choose_pending(g, 0) and maagover in g.field(0) and g.instances[maagover].object == item, "Conserva un Aliado equipado usando su Fuerza actual")

	g = fresh()
	var event = add(g, 0, "0132", "hand")
	check(bot.play_score(g, event, 0) < 0 and not bot.try_play(g, 0) and g.players[0].resources.size() == 8, "No paga Descubrimiento sin un Dominio disponible")
	event = add(g, 0, "0120", "hand")
	check(bot.play_score(g, event, 0) < 0, "No paga Raid de Nanchy sin Aliados elegibles")
	g = fresh(0)
	add(g, 0, "0105", "deck")
	event = add(g, 0, "0117", "hand")
	check(bot.play_score(g, event, 0) < 0, "No busca la última carta de su Mazo causando su propia derrota")
	add(g, 0, "0100", "deck")
	check(bot.play_score(g, event, 0) > 0 and bot.try_play(g, 0) and bot.choose_pending(g, 0) and g.players[0].deck.size() == 1, "Sí busca una Singular cuando queda otra carta en el Mazo")
	g = fresh(2)
	var oscar = add(g, 0, "0106", "defense")
	for _i in range(2): add(g, 0, "0106", "defense")
	var cake = g.spawn("0123", 0); g.instances[oscar].object = cake
	check(g.can_activate(cake) and not bot.useful_activation(g, cake, 0), "No activa Pastelito sin una búsqueda útil")
	var bigotes = add(g, 0, "01b", "defense")
	check(not bot.useful_activation(g, bigotes, 0), "No activa Bigotes si no quedan Objetos en su Mazo")
	g = fresh(0)
	oscar = add(g, 0, "0106", "defense")
	for _i in range(2): add(g, 0, "0106", "defense")
	add(g, 0, "0115", "graveyard")
	check(bot.useful_activation(g, oscar, 0), "La búsqueda desde Cementerio sigue siendo útil sin agotar el Mazo")

	g = fresh(7); g.phase = "blocks"
	var first = add(g, 1, "0109", "attack")
	var second = add(g, 1, "0109", "attack")
	var third = add(g, 1, "0109", "attack")
	g.attacks = [first, second, third]; g.active = 1; g.actor = 0
	var blocker = add(g, 0, "0108", "defense")
	item = g.spawn("0124", 0); g.instances[blocker].object = item
	var reserve = add(g, 0, "0103", "defense")
	check(bot.block(g, 0) and g.blocks.size() == 1 and blocker in g.blocks.values() and reserve not in g.blocks.values(), "Recalcula daño restante y evita sacrificar un segundo Aliado cuando ya sobrevivirá")
	check(efficient_block_case(), "Prefiere el bloqueador que gana sin comprometer el Aliado más valioso")
	g = fresh()
	event = add(g, 0, "0132", "hand"); add(g, 0, "0131", "deck")
	var before = bot.play_score(g, event, 0)
	add(g, 1, "0119", "hand"); g.players[1].deck.reverse()
	check(is_equal_approx(before, bot.play_score(g, event, 0)), "La decisión no cambia al variar la Mano y orden ocultos del rival")
	var badge = Badge.new(); badge.size = Vector2(24,24); root.add_child(badge)
	await process_frame
	check(badge.has_meta("new_card_badge") and badge.size == Vector2(24,24) and badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Estrella brillante conserva tamaño y no intercepta interacciones")
	badge.queue_free()
	print(JSON.stringify({"ai_v1_checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
