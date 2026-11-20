extends SceneTree
const Rules = preload("res://deck_rules.gd")
const Game = preload("res://game.gd")
const Collection = preload("res://collection.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
const Rewards = preload("res://rewards_ui.gd")
var checks = 0
var failures = []

class TestAccount extends RefCounted:
	var owner = "fixture-owner"
	var busy = false
	func player_id(): return owner
	func signed_in(): return not owner.is_empty()

class TestCollection extends Collection:
	var calls = []
	var succeeds = false
	var response = {}
	var rotate_owner = false
	var failure_http = 0
	var failure_code = ""
	func request(endpoint, body):
		calls.append({"endpoint":endpoint,"body":body.duplicate(true)})
		last_http_code = 200 if succeeds else failure_http
		last_error_code = "" if succeeds else failure_code
		last_reply = response.duplicate(true) if succeeds else {}
		if rotate_owner:
			account.owner = "other-owner"
			clear()
		return succeeds

class TestBoard extends RefCounted:
	var guest = false
	var account
	var collection
	var game

func check(value, caption):
	checks += 1
	if not value: failures.append(caption)

func _initialize():
	call_deferred("run")

func custom(entries, draft = false):
	return {"id":"custom_fixture","nombre":"Prueba propia","portada":"custom_restos","custom":true,"draft":draft,"revision":1,"recurso_inicial":"0100","cartas":entries.duplicate(true)}

func run():
	var game = Game.new()
	var catalog = game.catalog
	var entries = [{"codigo":"0100","cantidad":36},{"codigo":"0102","cantidad":3},{"codigo":"01c","cantidad":1}]
	var owned = {"0100":50,"0102":5,"01c":2}
	var deck = custom(entries)
	check(Rules.validate(deck,catalog,owned,true).ok,"40 cartas, Recursos, tres normales y promocional Singular permitidas")
	check(Rules.validate(custom([],true),catalog,owned,true).ok,"Borrador vacío guardable")
	check(not Rules.validate(custom(entries.slice(1),true),catalog,{"0102":2,"01c":1},true).ok,"Borrador no elude propiedad de copias")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":35},{"codigo":"0102","cantidad":4},{"codigo":"01c","cantidad":1}]),catalog).ok,"Cuarta copia ordinaria rechazada")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":35},{"codigo":"0102","cantidad":3},{"codigo":"01c","cantidad":2}]),catalog).ok,"Segunda copia Singular promocional rechazada")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":41}],true),catalog).ok,"Borrador respeta máximo40")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":39}]),catalog).ok,"Finalizado exige40")
	var no_resource = []
	for code in catalog:
		if code != "0100" and Rules.copy_limit(catalog[code]) == 3: no_resource.append({"codigo":code,"cantidad":3})
		if no_resource.size() == 13: break
	for code in catalog:
		if code != "0100" and not no_resource.any(func(entry): return entry.codigo == code):
			no_resource.append({"codigo":code,"cantidad":1})
			break
	check(Rules.validate(custom(no_resource),catalog).code == "AAMIX_DECK_INITIAL_RESOURCE","Finalizado40 exige Recurso Inicial")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":39.5}],true),catalog).ok and not Rules.validate(custom([{"codigo":"0100","cantidad":-1}],true),catalog).ok,"Cantidades fraccionarias y negativas rechazadas")
	check(not Rules.validate(custom([{"codigo":"0100","cantidad":20},{"codigo":"0100","cantidad":20}]),catalog).ok,"Entradas duplicadas rechazadas")
	check(not Rules.validate(custom([{"codigo":"desconocida","cantidad":1}],true),catalog).ok,"Carta desconocida rechazada")
	var collection = TestCollection.new()
	collection.account = TestAccount.new()
	collection.owner_id = collection.account.player_id()
	collection.loaded = true
	collection.cards = owned.duplicate(true)
	var draft = custom([],true)
	draft.id = "custom_draft"
	collection.decks = collection.merged_decks([game.decklists[0]],[deck,draft,deck,{"id":"kajido","custom":true}])
	check(collection.decks.size() == 3 and collection.playable_decks().size() == 2,"Inventario fusiona sin duplicar y excluye borradores al jugar")
	check(game.new_game(110,[deck,game.decklists[0]]) == true and game.players[0].deck_id == deck.id and game.players[0].resources.size() == 1 and game.players[0].hand.size() == 6 and game.invariant_errors().is_empty(),"Motor inicia mazo propio con preparación e invariantes vigentes")
	var full = Snapshot.capture(game)
	var restored = Game.new()
	check(Snapshot.restore(restored,JSON.parse_string(JSON.stringify(full))) and restored.players[0].deck_id == deck.id and restored.instances == game.instances,"Snapshot conserva mazo propio sin modificar protocolo")
	var guest = Snapshot.guest_view(game)
	check(game.players[0].hand.all(func(uid):return not guest.instances.has(uid)) and game.players[0].deck.all(func(uid):return not guest.instances.has(uid)),"Vista rival oculta mano y lista ordenada del mazo propio")
	check(game.new_game(111,[draft,game.decklists[0]]) == false and game.instances == full.instances,"Motor rechaza borrador sin reemplazar mesa previa")
	var new_deck = deck.duplicate(true)
	new_deck.id = ""
	new_deck.revision = 0
	check(not await collection.save_custom_deck(new_deck),"Respuesta perdida mantiene guardado pendiente")
	var first_request = str(collection.calls[-1].body.p_request_id)
	await collection.save_custom_deck(new_deck)
	check(collection.calls[-1].body.p_request_id == first_request and collection.calls[-1].body.p_deck_id == "","Reintento conserva UUID y servidor asigna identidad nueva")
	var changed_deck = new_deck.duplicate(true)
	changed_deck.nombre = "Nombre cambiado"
	var prior_calls = collection.calls.size()
	check(not await collection.save_custom_deck(changed_deck) and collection.calls.size() == prior_calls,"Guardado ambiguo bloquea nuevo contenido que duplicaría el mazo")
	collection.succeeds = true
	collection.response = {"last_saved_deck":deck}
	check(await collection.save_custom_deck(new_deck) and collection.pending_deck_save.is_empty() and collection.last_saved_deck.id == deck.id,"Confirmación recuperada devuelve identidad y revisión canónicas")
	collection.succeeds = false
	collection.failure_http = 500
	collection.failure_code = "AAMIX_DECK_REVISION_CONFLICT"
	check(not await collection.save_custom_deck(deck) and collection.pending_deck_save.is_empty(),"Conflicto de revisión definitivo libera guardado aunque transporte informe500")
	collection.failure_http = 0
	collection.failure_code = ""
	var board = TestBoard.new()
	board.account = collection.account
	board.collection = collection
	board.game = Game.new()
	var rewards = Rewards.new().setup(board)
	collection.succeeds = false
	var prepared = await rewards.prepare_match(deck.id,0)
	var first_begin = str(collection.calls[-1].body.p_request_id)
	collection.succeeds = true
	collection.response = {"match_id":"fixture-match","match_deck":deck}
	prepared = await rewards.prepare_match(deck.id,0)
	check(prepared == deck and collection.calls[-1].body.p_request_id == first_begin,"Inicio recupera misma solicitud y lista congelada del servidor")
	prior_calls = collection.calls.size()
	rewards.match_started(deck.id,0)
	await rewards.pump_receipts()
	check(rewards.active_receipt.begun and rewards.receipts.size() == 1 and collection.calls.size() == prior_calls,"Comienzo consume recibo preparado sin registrar segunda partida")
	collection.rotate_owner = true
	await collection.save_custom_deck(deck)
	check(collection.pending_deck_save.is_empty() and collection.last_saved_deck.is_empty() and collection.decks.is_empty(),"Cambio de UUID durante guardado no entrega datos al siguiente dueño")
	rewards.free()
	collection.free()
	print(JSON.stringify({"custom_decks_v110":{"checks":checks,"failures":failures}}))
	quit(0 if failures.is_empty() else 1)
