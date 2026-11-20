extends SceneTree
## One explicit temporary synthetic session; no DPAPI, passwords, email or Realtime.
const Collection = preload("res://collection.gd")
const Rules = preload("res://deck_rules.gd")
var fixture_path = ""
var collection
var account
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

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--private-fixture="): fixture_path = arg.trim_prefix("--private-fixture=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)
	return ok

func wallet():
	return {"cards":collection.cards.duplicate(true),"restos":collection.restos,"packs":collection.packs,"normal_packs":collection.normal_packs}

func done():
	if is_instance_valid(collection): collection.queue_free()
	if is_instance_valid(account): account.queue_free()
	for _i in range(3): await process_frame
	print(JSON.stringify({"deck_designs_http_v120":{"checks":checks,"failures":failures,"synthetic_accounts":1,"real_emails_sent":0,"realtime_tested":false}}))
	quit(0 if failures.is_empty() else 1)

func run():
	if fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		check(false,"Falta fixture sintético privado explícito")
		await done()
		return
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not fixture is Dictionary or fixture.get("synthetic_only",false) != true or not str(fixture.get("url","")).begins_with("https://"):
		check(false,"Fixture sintético inválido")
		await done()
		return
	account = LiveAccount.new()
	account.service_url = str(fixture.url)
	account.publishable_key = str(fixture.publishable_key)
	account.access_token = str(fixture.access_token)
	account.expires_at = float(fixture.expires_at)
	account.fixture_user = str(fixture.id)
	root.add_child(account)
	collection = Collection.new()
	collection.account = account
	root.add_child(collection)
	if not check(await collection.request("aamix_inventory",{}) and collection.available_covers() == Rules.FREE_COVERS,"Inventario HTTPS inicia con dos diseños gratuitos"):
		await done()
		return
	var before = wallet()
	var locked_body = {"p_request_id":collection.request_id(),"p_deck_id":"","p_nombre":"Diseño bloqueado","p_portada":"custom_tsuki_akira","p_cartas":[{"codigo":"0100","cantidad":40}],"p_draft":false,"p_expected_revision":0}
	check(not await collection.request("aamix_save_custom_deck",locked_body) and collection.last_error_code == "AAMIX_DECK_COVER_LOCKED","Servidor rechaza diseño protegido antes de canjear")
	var codes = ["SI2MAZO","CHANCHUMAZO","VIBMAZO"]
	var covers = ["custom_tsuki_akira","custom_chanchuus","custom_viborin"]
	for i in range(codes.size()):
		var ok = await collection.redeem_code(codes[i])
		if not check(ok and str(collection.last_reply.get("reward_cover","")) == covers[i] and covers[i] in collection.available_covers() and collection.available_covers().size() == i+3,"Canje HTTPS desbloquea sólo el diseño esperado: "+codes[i]):
			await done()
			return
	check(wallet() == before,"Los tres canjes conservan cartas, Restos y sobres")
	check(await collection.redeem_code(codes[0]) and collection.last_reply.get("already_redeemed",false) == true and collection.available_covers() == Rules.CUSTOM_COVERS and wallet() == before,"Repetir código no duplica ni entrega otras recompensas")
	var deck = {"id":"","nombre":"Diseño obtenido por código","portada":"custom_tsuki_akira","custom":true,"draft":false,"revision":0,"recurso_inicial":"0100","cartas":[{"codigo":"0100","cantidad":40}]}
	if not check(await collection.save_custom_deck(deck) and collection.last_saved_deck.get("portada","") == "custom_tsuki_akira","Guarda mazo40 con diseño obtenido por código"):
		await done()
		return
	var deck_id = str(collection.last_saved_deck.id)
	collection.clear()
	check(collection.available_covers() == Rules.FREE_COVERS,"Limpiar cliente elimina desbloqueos de memoria")
	check(await collection.request("aamix_inventory",{}) and collection.available_covers() == Rules.CUSTOM_COVERS and collection.decks.any(func(value):return str(value.id) == deck_id and value.get("portada","") == "custom_tsuki_akira") and wallet() == before,"Nueva carga recupera diseños y portada guardada sin consumir inventario")
	await done()
