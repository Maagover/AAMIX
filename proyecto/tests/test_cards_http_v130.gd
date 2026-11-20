extends SceneTree
## Two HTTPS clients in one process, using explicit temporary synthetic sessions.
## A controlled mid-match fixture preserves all 40 cards per player; subsequent
## abilities, payments, searches and blocks use the actual engine commands.
const Game = preload("res://game.gd")
const Collection = preload("res://collection.gd")
const Online = preload("res://online_match.gd")
const Snapshot = preload("res://multiplayer_snapshot.gd")
var fixture_path = ""
var clients = []
var collections = []
var nodes = []
var game
var room_id = ""
var revision = 0
var checks = 0
var failures = []

class LiveAccount extends Node:
	var service_url = ""
	var publishable_key = ""
	var access_token = ""
	var expires_at = 0.0
	var busy = false
	var fixture_user = ""
	func player_id(): return fixture_user
	func signed_in(): return not fixture_user.is_empty() and not access_token.is_empty()
	func refresh_session(): return false
class LiveBoard extends RefCounted:
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
func rpc(role, endpoint, payload): return await clients[role].request(endpoint,payload)
func done():
	if not room_id.is_empty() and not clients.is_empty(): await rpc(0,"aamix_mp_leave",{"p_room_id":room_id})
	for node in nodes:
		if is_instance_valid(node): node.queue_free()
	for _i in range(3): await process_frame
	print(JSON.stringify({"cards_http_v130":{"checks":checks,"failures":failures,"synthetic_accounts":2,"processes":1,"mid_match_fixture":true,"realtime_tested":false,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)
func find_uid(p, code):
	for uid in game.instances:
		if game.instances[uid].owner == p and game.code(uid) == code: return uid
	return -1
func place(uid, destination):
	if game.location(uid).get("zone", "") != destination: game.leave(uid,destination,false)
	game.instances[uid].entered = 1
func packet(request_id, before):
	var host = Snapshot.capture(game)
	var guest = Snapshot.guest_view(game)
	var public_motion = Snapshot.presentation(game,before,1)
	host.presentation = game.visual_events.duplicate(true)
	host.guest_presentation = public_motion
	guest.presentation = public_motion
	host.visual_events = []
	game.visual_events.clear()
	return {"p_room_id":room_id,"p_request_id":request_id,"p_expected_revision":revision,"p_host_state":host,"p_guest_view":guest,"p_actor_slot":game.actor,"p_winner":game.winner,"p_error":""}
func host_action(method, args):
	var before = Snapshot.capture(game)
	game.take_visual_events()
	if not Snapshot.dispatch(game,0,method,args):
		failures.append("Motor rechazó acción de prueba: "+method)
		return false
	var payload = packet(collections[0].request_id(),before)
	payload.p_method = method
	payload.p_args = args.duplicate(true)
	var reply = await rpc(0,"aamix_mp_host_action",payload)
	if not reply.get("ok",false):
		failures.append("Servicio rechazó acción de prueba: "+method+" / "+str(clients[0].last_error))
		return false
	revision = int(reply.data.revision)
	return true
func mission_progress(collection):
	for mission in collection.missions:
		if str(mission.id) == "play_ten": return int(mission.progress)
	return -1
func run():
	if fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		check(false,"Falta fixture sintético privado explícito")
		await done()
		return
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary or fixture.get("synthetic_only",false) != true or not fixture.get("users") is Array or fixture.users.size() != 2 or not str(fixture.get("url","")).begins_with("https://"):
		check(false,"Fixture sintético inválido")
		await done()
		return
	var decks = []
	for i in range(2):
		var credentials = fixture.users[i]
		var account = LiveAccount.new()
		account.service_url = str(fixture.url)
		account.publishable_key = str(fixture.publishable_key)
		account.fixture_user = str(credentials.id)
		account.access_token = str(credentials.access_token)
		account.expires_at = float(credentials.expires_at)
		root.add_child(account)
		nodes.append(account)
		var collection = Collection.new()
		collection.account = account
		root.add_child(collection)
		nodes.append(collection)
		collections.append(collection)
		var board = LiveBoard.new()
		board.account = account
		board.collection = collection
		var online = Online.new().setup(board)
		root.add_child(online)
		online.set_process(false)
		online.realtime.set_process(false)
		nodes.append(online)
		clients.append(online)
		if not check(await collection.request("aamix_inventory",{}) and collection.owner_id == account.player_id(),"Inventario HTTPS del UUID sintético "+str(i)):
			await done()
			return
		var deck = {"id":"","nombre":"Prueba reglas1.3 "+str(i),"portada":"custom_transmision","custom":true,"draft":false,"revision":0,"recurso_inicial":"0100","cartas":[{"codigo":"0100","cantidad":30},{"codigo":"0101","cantidad":3},{"codigo":"0114","cantidad":3},{"codigo":"0126","cantidad":1},{"codigo":"0129","cantidad":1},{"codigo":"01e","cantidad":1},{"codigo":"0128","cantidad":1}]}
		if not check(await collection.save_custom_deck(deck),"Mazo propio40 con cartas nuevas para cliente "+str(i)):
			await done()
			return
		decks.append(collection.last_saved_deck.duplicate(true))
	var created = await rpc(0,"aamix_mp_create_room",{"p_request_id":collections[0].request_id(),"p_deck_id":decks[0].id})
	if not created.get("ok",false):
		check(false,"Crear sala1.3 HTTPS")
		await done()
		return
	room_id = str(created.data.room_id)
	var joined = await rpc(1,"aamix_mp_join_room",{"p_request_id":collections[1].request_id(),"p_code":str(created.data.code),"p_deck_id":decks[1].id})
	if not check(joined.get("ok",false) and str(created.data.get("ruleset_version","")) == "1.3" and str(joined.data.get("ruleset_version","")) == "1.3","Crear y unir usan realmente endpoints compatibles1.3"):
		await done()
		return
	var confirmed_host = await rpc(0,"aamix_mp_confirm",{"p_room_id":room_id})
	var confirmed_guest = await rpc(1,"aamix_mp_confirm",{"p_room_id":room_id})
	var ready = await rpc(0,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	if not check(confirmed_host.get("ok",false) and confirmed_guest.get("ok",false) and ready.get("ok",false) and ready.data.get("confirmed",[]) == [true,true],"Ambos clientes confirman antes del estado inicial"):
		await done()
		return
	game = Game.new()
	game.new_game(130,[ready.data.host_deck,ready.data.guest_deck])
	game.manual_payment = [true,true]
	game.active = 0
	game.actor = 0
	game.turn = 5
	game.phase = "main"
	game.keeps = [true,true]
	var viborin = find_uid(0,"0126")
	var almenta = find_uid(0,"0129")
	var sam_cost = find_uid(0,"0114")
	var nonungus = find_uid(0,"0101")
	var defender = find_uid(1,"0114")
	for uid in [viborin,almenta,sam_cost]: place(uid,"defense")
	for uid in game.instances:
		if game.instances[uid].owner == 0 and game.code(uid) == "0114" and uid != sam_cost:
			place(uid,"deck")
			break
	place(nonungus,"hand")
	place(defender,"defense")
	while game.players[0].resources.size() < 4:
		var resource = game.players[0].deck.filter(func(uid):return game.code(uid) == "0100")[0]
		place(resource,"resources")
	game.take_visual_events()
	var initialized = await rpc(0,"aamix_mp_commit",packet(collections[0].request_id(),Snapshot.capture(game)))
	if not check(game.instances.size() == 80 and game.invariant_errors().is_empty() and initialized.get("ok",false),"Fixture80 UID conserva invariantes y confirma snapshot1 con reglas1.3"):
		await done()
		return
	revision = int(initialized.data.revision)
	if not await host_action("activate",[viborin]) or not await host_action("choose",[[sam_cost]]): await done(); return
	var guest_view = await rpc(1,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	var recovered = Game.new()
	check(guest_view.get("ok",false) and Snapshot.restore(recovered,guest_view.data.state) and recovered.force(viborin) == 5 and recovered.instances[viborin].force_bonus_turn == 5,"Bono Viborín cruza HTTPS y snapshot del invitado")
	if not await host_action("activate",[almenta]) or not await host_action("choose",[[almenta]]) or not await host_action("reserve_resource",[game.players[0].resources[0]]): await done(); return
	guest_view = await rpc(1,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	check(guest_view.get("ok",false) and Snapshot.restore(recovered,guest_view.data.state) and recovered.unblockable(almenta) and recovered.instances[almenta].unblockable_turn == 5,"Pago Almenta y bandera temporal cruzan HTTPS")
	if not await host_action("request_play",[nonungus,-1]): await done(); return
	for _i in range(2):
		if not await host_action("reserve_resource",[game.players[0].resources[0]]): await done(); return
	guest_view = await rpc(1,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	var sam = int(game.pending.options[0]) if not game.pending.is_empty() else -1
	check(guest_view.get("ok",false) and game.pending.get("kind","") == "search_hand" and guest_view.data.state.pending.get("kind","") == "waiting" and guest_view.data.state.pending.options.is_empty() and not guest_view.data.state.instances.has(str(sam)),"Nonungus no revela opciones de búsqueda al rival")
	if not await host_action("choose",[[sam]]): await done(); return
	guest_view = await rpc(1,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	var reveals = guest_view.data.state.get("presentation",[]).filter(func(event):return event.get("face_code","") == "0114") if guest_view.get("ok",false) else []
	check(reveals.size() == 1 and int(reveals[0].uid) < 0 and guest_view.data.state.players[0].hand.all(func(uid):return int(uid) < 0) and not guest_view.data.state.instances.has(str(sam)),"Sólo Sam revelado se muestra durante animación, Mano e identidad siguen ocultas")
	if not await host_action("declare_attack",[[viborin]]): await done(); return
	var command_id = collections[1].request_id()
	var command = {"p_room_id":room_id,"p_request_id":command_id,"p_expected_revision":revision,"p_method":"assign_block","p_args":[viborin,defender]}
	var submitted = await rpc(1,"aamix_mp_submit",command)
	var pending = await rpc(0,"aamix_mp_poll",{"p_room_id":room_id,"p_since_revision":-1})
	if not submitted.get("ok",false) or not pending.get("ok",false) or pending.data.get("commands",[]).is_empty():
		check(false,"Comando del invitado llega al anfitrión")
		await done()
		return
	Snapshot.restore(game,pending.data.state)
	var before = Snapshot.capture(game)
	game.take_visual_events()
	var applied = Snapshot.dispatch(game,1,"assign_block",[viborin,defender])
	var commit = packet(command_id,before)
	var committed = await rpc(0,"aamix_mp_commit",commit)
	var replay_commit = await rpc(0,"aamix_mp_commit",commit)
	var replay_submit = await rpc(1,"aamix_mp_submit",command)
	check(applied and committed.get("ok",false) and replay_commit.get("ok",false) and replay_submit.get("ok",false) and int(committed.data.revision) == int(replay_commit.data.revision) and int(committed.data.revision) == int(replay_submit.data.revision),"Comando y commit repetidos no duplican revisión")
	var left = await rpc(1,"aamix_mp_leave",{"p_room_id":room_id})
	await collections[1].request("aamix_inventory",{})
	var first_progress = mission_progress(collections[1])
	var left_again = await rpc(1,"aamix_mp_leave",{"p_room_id":room_id})
	await collections[1].request("aamix_inventory",{})
	check(left.get("ok",false) and left_again.get("ok",false) and left.data.get("status","") == "finished" and int(left.data.get("winner",-1)) == 0 and int(left.data.revision) == int(left_again.data.revision) and first_progress == 1 and mission_progress(collections[1]) == first_progress,"Abandono repetido conserva resultado y cuenta una sola partida")
	await done()
