extends SceneTree
const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
const Online = preload("res://online_match.gd")
var bot = Bot.new()
var checks = 0
var failures = []

class FixtureAccount extends RefCounted:
	func player_id(): return "fixture-owner"
	func signed_in(): return true
class FixtureBoard extends RefCounted:
	var account = FixtureAccount.new()
	var game = Game.new()
	var active_deck_id = ""
	var screen = "multiplayer"
	var rendered = 0
	func reset_match(): active_deck_id = ""
	func render(): rendered += 1
class FixtureOnline extends Online:
	var sent = []
	func request(endpoint, payload):
		sent.append({"endpoint":endpoint,"payload":payload.duplicate(true)})
		return {"ok":true,"data":{"status":"cancelled"}}

func check(ok, label):
	checks += 1
	if not ok: failures.append(label)
func add(g, p, code, zone):
	var uid = g.spawn(code,p)
	g.players[p][zone].append(uid)
	g.instances[uid].entered = 1
	return uid
func fresh():
	var g = Game.new()
	for p in range(2):
		var player = {"name":"Fixture","deck_id":"fixture"}
		for zone in g.ZONES: player[zone] = []
		g.players.append(player)
		for _i in range(16): add(g,p,"0100","deck")
		for _i in range(4): add(g,p,"0100","resources")
	g.actor = 0
	g.active = 0
	g.turn = 5
	g.phase = "main"
	return g
func _initialize(): run.call_deferred()
func run():
	var g = fresh()
	var viborin = add(g,0,"0126","defense")
	var cheap = add(g,0,"0106","defense")
	var precious = add(g,0,"0105","defense")
	check(bot.useful_activation(g,viborin,0) and g.activate(viborin) and bot.choose_pending(g,0) and cheap in g.players[0].graveyard and precious in g.field(0) and g.force(viborin) == 5,"IA sacrifica Aliado barato para Viborín y conserva el valioso")
	var recovered_bonus = Game.new()
	check(Snapshot.restore(recovered_bonus,JSON.parse_string(JSON.stringify(Snapshot.capture(g)))) and recovered_bonus.force(viborin) == 5 and recovered_bonus.instances[viborin].force_bonus == 3 and recovered_bonus.instances[viborin].force_bonus_turn == g.turn,"Snapshot JSON conserva cantidad y turno del bono de Viborín")
	g = fresh()
	viborin = add(g,0,"0126","defense")
	check(not bot.useful_activation(g,viborin,0) and g.activate(viborin) and bot.choose_pending(g,0) and viborin in g.field(0) and g.instances[viborin].used != g.turn,"IA cancela sin sacrificarse a sí misma ni gastar habilidad")
	g = fresh()
	var almenta = add(g,0,"0129","defense")
	g.instances[almenta].entered = g.turn
	var dragon = add(g,0,"01e","defense")
	var already = add(g,0,"0128","defense")
	add(g,0,"0106","defense")
	add(g,1,"0105","defense")
	check(bot.useful_activation(g,almenta,0) and g.activate(almenta) and bot.choose_pending(g,0) and g.unblockable(dragon) and g.players[0].resources.size() == 3 and int(g.instances[already].get("unblockable_turn",-1)) != g.turn,"IA usa Almenta sobre atacante útil que aún no era Imbloqueable")
	var full = Snapshot.capture(g)
	var restored = Game.new()
	check(Snapshot.restore(restored,JSON.parse_string(JSON.stringify(full))) and restored.unblockable(dragon) and restored.instances[dragon].unblockable_turn == g.turn,"Snapshot JSON conserva bono temporal y versión de reglas")
	var before = Snapshot.capture(restored)
	var old = full.duplicate(true)
	old.erase("ruleset_version")
	var future = full.duplicate(true)
	future.ruleset_version = "1.4"
	check(not Snapshot.restore(restored,old) and not Snapshot.restore(restored,future) and Snapshot.capture(restored) == before,"Snapshot viejo o desconocido se rechaza antes de mutar mesa")
	g = fresh()
	almenta = add(g,0,"0129","defense")
	g.instances[almenta].entered = g.turn
	add(g,1,"0105","defense")
	check(not bot.useful_activation(g,almenta,0) and g.activate(almenta) and bot.choose_pending(g,0) and g.players[0].resources.size() == 4 and g.instances[almenta].used != g.turn,"IA no paga Almenta si no hay atacante listo")
	add(g,0,"01e","defense")
	g.domain_uid = g.spawn("0122",1)
	check(not bot.useful_activation(g,almenta,0),"IA no paga Imbloqueable cuando Templo de Girabl permite bloquear")
	g.domain_uid = -1
	g.phase = "after_combat"
	check(not bot.useful_activation(g,almenta,0),"IA no desperdicia Almenta una vez terminado el combate")
	g = fresh()
	var fall = add(g,0,"0118","hand")
	check(bot.play_score(g,fall,0) < 0,"IA no intenta Caída sin Aliado en Cementerio rival")
	add(g,1,"0128","graveyard")
	var score = bot.play_score(g,fall,0)
	add(g,1,"0119","hand")
	g.players[1].deck.reverse()
	check(score > 0 and is_equal_approx(score,bot.play_score(g,fall,0)),"Caída usa Cementerio público sin consultar mano ni orden rival")
	g = fresh()
	var guitar = add(g,0,"0124","hand")
	var pig = add(g,0,"0125","defense")
	check(bot.best_target(g,guitar,0) == -1 and bot.play_score(g,guitar,0) < 0,"IA evita Guitarra sobre Chanchuus inmune a Fuerza externa")
	dragon = add(g,0,"01e","defense")
	add(g,0,"0102","defense")
	check(bot.best_target(g,guitar,0) == dragon,"IA reconoce bono propio de Dragón al equipar un Objeto")
	g = fresh()
	var nonungus = add(g,0,"0101","defense")
	var sam = add(g,0,"0114","deck")
	g.actor = 0
	g.set_choice({"kind":"search_hand","player":0,"source":nonungus,"title":"Nonungus","options":[sam],"min":0,"max":1,"optional":true,"shuffle":true})
	var guest = Snapshot.guest_view(g)
	check(guest.pending.kind == "waiting" and guest.pending.options.is_empty() and not guest.instances.has(sam),"Búsqueda Nonungus no revela opciones ni carta rival antes de elegir")
	var before_search = Snapshot.capture(g)
	g.take_visual_events()
	check(bot.choose_pending(g,0) and sam in g.players[0].hand,"IA completa búsqueda Nonungus con el contrato de búsqueda existente")
	var public_search = Snapshot.presentation(g,before_search,1).filter(func(event):return event.kind == "move" and event.get("to","") == "hand")
	check(public_search.size() == 1 and public_search[0].face_code == "0114" and int(public_search[0].uid) < 0 and not Snapshot.guest_view(g).instances.has(sam),"Búsqueda muestra sólo la cara revelada y conserva anónimos UID y Mano")
	var before_draw = Snapshot.capture(g)
	g.take_visual_events()
	g.draw(0,1)
	var hidden_draw = Snapshot.presentation(g,before_draw,1).filter(func(event):return event.kind == "move" and event.get("to","") == "hand")
	check(hidden_draw.size() == 1 and int(hidden_draw[0].uid) < 0 and not hidden_draw[0].has("face_code"),"Robo normal conserva dorso anónimo sin mostrar otra carta de la Mano")
	g = fresh()
	g.active = 1
	g.actor = 1
	viborin = add(g,1,"0126","defense")
	cheap = add(g,1,"0106","defense")
	var hidden = add(g,0,"0105","hand")
	g.activate(viborin)
	guest = Snapshot.guest_view(g)
	check(guest.pending.kind == "sacrifice_ally" and guest.pending.options == g.field(1) and guest.instances.has(viborin) and not guest.instances.has(hidden),"Invitado recibe su elección y fuente sin revelar mano rival")
	check(Snapshot.dispatch(g,1,"choose",[[cheap]]) and g.force(viborin) == 5,"Comando multijugador existente resuelve sacrificio autorizado")
	var endpoints = ["aamix_mp_create_room","aamix_mp_join_room","aamix_mp_active","aamix_mp_poll","aamix_mp_confirm","aamix_mp_submit","aamix_mp_commit","aamix_mp_host_action"]
	check(endpoints.all(func(endpoint):return Online.rpc_endpoint(endpoint) == endpoint+"_v130") and Online.rpc_endpoint("aamix_mp_leave") == "aamix_mp_leave","Todos los accesos al juego usan guardia1.3 y el cierre sigue compatible")
	var board = FixtureBoard.new()
	var online = FixtureOnline.new().setup(board)
	var initial_engine = Snapshot.capture(g)
	board.game = g
	online.pending_command = {"p_request_id":"pending"}
	online.receive({"room_id":"old-room","status":"playing","ruleset_version":"1.2","state":full,"commands":[{}],"host_deck":{"cartas":[]}})
	check(online.room.is_empty() and online.incompatible_room.keys().size() == 3 and online.pending_command.is_empty() and Snapshot.capture(board.game) == initial_engine,"Sala1.2 sólo guarda metadatos de cierre y no restaura cartas ni comandos")
	check(await online.close_incompatible_room() and online.sent.size() == 1 and online.sent[0].endpoint == "aamix_mp_leave" and online.incompatible_room.is_empty(),"Sala anterior puede cerrarse explícitamente para salir de la incompatibilidad")
	online.receive({"room_id":"compatible-room","status":"waiting","ruleset_version":"1.3","revision":0,"room_version":1,"slot":0,"state":{},"commands":[],"confirmed":[false,false]})
	check(online.room.get("room_id","") == "compatible-room" and online.connected and online.incompatible_room.is_empty(),"Sala1.3 compatible sigue siendo aceptada")
	online.free()
	print(JSON.stringify({"cards_integration_v130":{"checks":checks,"failures":failures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
