extends SceneTree
## Explicit temporary synthetic credentials only. Never invoke with player sessions.
const Collection = preload("res://collection.gd")
const Online = preload("res://online_match.gd")
const Rewards = preload("res://rewards_ui.gd")
const Game = preload("res://game.gd")
var fixture_path = ""
var checks = 0
var failures = []
var live_nodes = []

class LiveAccount extends Node:
	var service_url = ""
	var publishable_key = ""
	var access_token = ""
	var expires_at = 0.0
	var busy = false
	var fixture_user = ""
	func signed_in(): return not fixture_user.is_empty() and not access_token.is_empty()
	func player_id(): return fixture_user
	func refresh_session(): return false

class LiveBoard extends RefCounted:
	var guest = false
	var account
	var collection
	var game = Game.new()

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--private-fixture="): fixture_path = arg.trim_prefix("--private-fixture=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)
	return ok

func done():
	for node in live_nodes:
		if is_instance_valid(node): node.queue_free()
	for _i in range(3): await process_frame
	print(JSON.stringify({"custom_decks_http_v110":{"checks":checks,"failures":failures,"synthetic_accounts_only":true,"realtime_tested":false,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)

func run():
	if fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		check(false,"Falta fixture privado sintético explícito")
		await done()
		return
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary or fixture.get("synthetic_only", false) != true or not fixture.get("players") is Array or fixture.players.size() != 2 or not str(fixture.get("url", "")).begins_with("https://"):
		check(false,"Fixture sintético inválido")
		await done()
		return
	var collections = []
	var boards = []
	var online_clients = []
	for player in fixture.players:
		var account = LiveAccount.new()
		account.service_url = str(fixture.url)
		account.publishable_key = str(fixture.publishable_key)
		account.access_token = str(player.access_token)
		account.expires_at = float(player.expires_at)
		account.fixture_user = str(player.id)
		root.add_child(account)
		live_nodes.append(account)
		var collection = Collection.new()
		collection.account = account
		root.add_child(collection)
		live_nodes.append(collection)
		collections.append(collection)
		var board = LiveBoard.new()
		board.account = account
		board.collection = collection
		boards.append(board)
		var online = Online.new().setup(board)
		root.add_child(online)
		online.set_process(false)
		online.realtime.set_process(false)
		live_nodes.append(online)
		online_clients.append(online)
		if not check(await collection.request("aamix_inventory",{}) and collection.owner_id == account.player_id(),"Inventario HTTPS sólo del UUID sintético"):
			await done()
			return
	var owner = collections[0]
	var guest = collections[1]
	var draft = {"id":"","nombre":"Prueba nativa borrador","portada":"custom_restos","custom":true,"draft":true,"revision":0,"recurso_inicial":"0100","cartas":[]}
	if not check(await owner.save_custom_deck(draft) and owner.last_saved_deck.draft == true,"Crea borrador vacío por RPC real"):
		await done()
		return
	var deck = owner.last_saved_deck.duplicate(true)
	check(not owner.playable_decks().any(func(value):return value.id == deck.id),"Borrador remoto excluido de partidas")
	check(not await owner.begin_match(owner.request_id(),deck.id) and owner.last_error_code == "AAMIX_DECK_DRAFT","Servidor rechaza comenzar borrador")
	deck.cartas = fixture.deck_cards.duplicate(true)
	deck.draft = false
	if not check(await owner.save_custom_deck(deck),"Finaliza40 cartas propias con promocional por HTTPS"):
		await done()
		return
	deck = owner.last_saved_deck.duplicate(true)
	var save_id = owner.request_id()
	var normalized_cards = preload("res://deck_rules.gd").validate(deck,boards[0].game.catalog).entries
	var body = {"p_request_id":save_id,"p_deck_id":deck.id,"p_nombre":"Guardado idempotente","p_portada":deck.portada,"p_cartas":normalized_cards,"p_draft":false,"p_expected_revision":int(deck.revision)}
	if not check(await owner.request("aamix_save_custom_deck",body),"Guarda nueva revisión autenticada"):
		await done()
		return
	var saved = owner.last_reply.last_saved_deck.duplicate(true)
	check(await owner.request("aamix_save_custom_deck",body) and owner.last_reply.last_saved_deck == saved,"Repetir UUID no duplica ni incrementa revisión")
	var foreign_body = body.duplicate(true)
	foreign_body.p_request_id = guest.request_id()
	foreign_body.p_expected_revision = int(saved.revision)
	check(not await guest.request("aamix_save_custom_deck",foreign_body) and guest.last_error_code == "AAMIX_UNOWNED_DECK","Otro UUID no puede editar mazo ajeno")
	check(not guest.decks.any(func(value):return value.id == saved.id),"Inventario de otro UUID no revela mazo ajeno")
	var rewards = Rewards.new().setup(boards[0])
	live_nodes.append(rewards)
	var frozen = await rewards.prepare_match(saved.id,0)
	if not check(not frozen.is_empty() and frozen.cartas == saved.cartas,"Preflight individual recibe lista congelada real"):
		await done()
		return
	var begin_id = rewards.prepared_receipt.request_id
	saved.cartas = [{"codigo":"0100","cantidad":40}]
	if not check(await owner.save_custom_deck(saved),"Edición posterior guarda nueva revisión"):
		await done()
		return
	var current_host = owner.last_saved_deck.duplicate(true)
	check(await owner.begin_match(begin_id,saved.id) and owner.last_reply.match_deck == frozen,"Reintento individual preserva lista previa a la edición")
	rewards.match_started(saved.id,0)
	check(rewards.active_receipt.begun and rewards.receipts.size() == 1,"Inicio consume recibo preconfirmado sin segundo registro")
	var guest_deck = draft.duplicate(true)
	guest_deck.nombre = "Invitado personalizado"
	guest_deck.cartas = fixture.deck_cards.duplicate(true)
	guest_deck.draft = false
	if not check(await guest.save_custom_deck(guest_deck),"Invitado crea su propio mazo personalizado"):
		await done()
		return
	guest_deck = guest.last_saved_deck.duplicate(true)
	var created = await online_clients[0].request("aamix_mp_create_room",{"p_request_id":owner.request_id(),"p_deck_id":current_host.id})
	if not check(created.get("ok",false),"Anfitrión crea sala con mazo personalizado por HTTPS"):
		await done()
		return
	var room_id = str(created.data.room_id)
	var joined = await online_clients[1].request("aamix_mp_join_room",{"p_request_id":guest.request_id(),"p_code":str(created.data.code),"p_deck_id":guest_deck.id})
	if not check(joined.get("ok",false),"Invitado entra con otro mazo personalizado por HTTPS"):
		await online_clients[0].request("aamix_mp_leave",{"p_room_id":room_id})
		await done()
		return
	var guest_frozen = guest_deck.duplicate(true)
	guest_deck.cartas = []
	guest_deck.draft = true
	check(await guest.save_custom_deck(guest_deck),"Editar mazo a borrador no cambia una sala ya creada")
	var confirmed_host = await online_clients[0].request("aamix_mp_confirm",{"p_room_id":room_id})
	var confirmed_guest = await online_clients[1].request("aamix_mp_confirm",{"p_room_id":room_id})
	var polled = await online_clients[0].request("aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	if check(confirmed_host.get("ok",false) and confirmed_guest.get("ok",false) and polled.get("ok",false),"Ambos confirman y recuperan sala autenticada"):
		check(polled.data.get("guest_deck",{}) == guest_frozen and polled.data.get("host_deck",{}) == current_host,"Sala conserva ambas listas completas congeladas")
		var game = Game.new()
		check(game.new_game(110,[polled.data.host_deck,polled.data.guest_deck]) and game.invariant_errors().is_empty(),"Motor real inicia las dos listas devueltas por servidor")
	var closed = await online_clients[0].request("aamix_mp_leave",{"p_room_id":room_id})
	check(closed.get("ok",false),"Sala sintética cerrada al terminar la prueba")
	await done()

