extends Node
## Remote inventory only. No credentials or inventory cache on disk.
const DeckRules = preload("res://deck_rules.gd")
signal changed
var account
var busy = false
var loaded = false
var owner_id = ""
var cards = {}
var decks = []
var gift = null
var status = ""
var generation = 0
var http
var profile = {"avatar_code":""}
var available_avatar_codes = []
var achievement_notifications = []
var packs = 0
var normal_packs = 0
var halloween_packs=0
var restos = 0
var restos_welcome_claimed = false
var shop = []
var last_error_code = ""
var last_http_code = 0
var mission = {}
var missions = []
var challenges = []
var welcome_pack = {}
var pending_opening = null
var last_reply = {}
var last_saved_deck = {}
var pending_deck_save = {}
var deck_catalog = {}
var available_custom_covers = DeckRules.FREE_COVERS.duplicate()
var events = []
var events_deadline_tick = 0
var event_refresh_tick = 0
var server_day = ""

func _ready():
	http = HTTPRequest.new()
	http.timeout = 20.0
	http.max_redirects = 0
	http.body_size_limit = 1048576
	add_child(http)

func clear():
	generation += 1
	loaded = false
	owner_id = ""
	cards = {}
	decks = []
	gift = null
	status = ""
	profile = {"avatar_code":""}
	available_avatar_codes = []; achievement_notifications = []
	packs = 0
	normal_packs = 0
	halloween_packs = 0
	restos = 0
	restos_welcome_claimed = false
	shop = []
	last_error_code = ""
	last_http_code = 0
	mission = {}
	missions = []
	challenges = []
	pending_opening = null
	last_reply = {}
	welcome_pack = {}
	last_saved_deck = {}
	pending_deck_save = {}
	available_custom_covers = DeckRules.FREE_COVERS.duplicate()
	events = []
	events_deadline_tick = 0
	event_refresh_tick = 0
	server_day = ""
	changed.emit()

func normalize_available_covers(value):
	var result = DeckRules.FREE_COVERS.duplicate()
	if value is Array:
		for key in DeckRules.CUSTOM_COVERS:
			if key in value and key not in result: result.append(key)
	return result

func available_covers():
	return normalize_available_covers(available_custom_covers)

func playable_decks():
	var result = []
	if deck_catalog.is_empty(): deck_catalog = DeckRules.load_catalog()
	for deck in decks:
		if not deck is Dictionary or deck.get("draft", false) == true: continue
		if (deck.get("custom", false) == true or deck.get("editable", false) == true) and not DeckRules.validate(deck, deck_catalog, cards, true).ok: continue
		result.append(deck.duplicate(true))
	return result

func save_custom_deck(deck):
	if busy or account == null or not account.signed_in(): return false
	if not loaded or owner_id != account.player_id(): return fail("Recarga tu colección antes de guardar el mazo.")
	if not deck is Dictionary or not (deck.get("custom", false) or deck.get("editable", false)): return fail("Este mazo no se puede editar.")
	if deck_catalog.is_empty(): deck_catalog = DeckRules.load_catalog()
	var validation = DeckRules.validate(deck, deck_catalog, cards, true)
	if not validation.ok: return fail(validation.message)
	var title = str(deck.get("nombre", "")).strip_edges()
	if title.is_empty() or title.length() > 48: return fail("Elige un nombre de entre 1 y 48 caracteres.")
	var cover = str(deck.get("portada", ""))
	if deck.get("custom", false) and cover not in DeckRules.CUSTOM_COVERS: return fail("Elige un diseño para la portada del mazo.")
	if deck.get("custom", false) and cover not in available_covers(): return fail("Este diseño todavía no está desbloqueado en tu cuenta.")
	var revision = int(deck.get("revision", 0))
	var deck_id = str(deck.get("id", "")) if revision > 0 else ""
	if revision > 0 and not deck.get("editable", false) and (deck.get("custom", false) != true or not deck_id.begins_with("custom_")):
		return fail("Los mazos base y regalados no se pueden editar.")
	var payload = {"p_deck_id":deck_id,"p_nombre":title,"p_portada":cover,"p_cartas":validation.entries,"p_draft":deck.get("draft", false) == true,"p_expected_revision":revision}
	var signature = JSON.stringify(payload)
	# Retry the same request after an ambiguous failure, without creating copies.
	if not pending_deck_save.is_empty() and pending_deck_save.signature != signature:
		return fail("El guardado anterior aún no está confirmado. Reintenta ese guardado antes de cambiar el mazo.")
	if pending_deck_save.is_empty():
		pending_deck_save = {"signature":signature,"id":request_id(),"payload":payload.duplicate(true)}
	payload.p_request_id = pending_deck_save.id
	var save_generation = generation
	var save_owner = account.player_id()
	var ok = await request("aamix_save_custom_deck", payload)
	if generation != save_generation or save_owner != account.player_id(): return false
	if ok:
		last_saved_deck = last_reply.get("last_saved_deck", last_reply.get("saved_deck", {})).duplicate(true)
		pending_deck_save = {}
	elif last_error_code in custom_deck_errors() or (last_http_code >= 400 and last_http_code < 500 and last_http_code not in [408,429]):
		pending_deck_save = {}
	return ok

func pending_custom_deck():
	if pending_deck_save.is_empty(): return {}
	var body = pending_deck_save.payload
	return {"id":str(body.p_deck_id),"nombre":str(body.p_nombre),"portada":str(body.p_portada),"custom":str(body.p_deck_id).is_empty() or str(body.p_deck_id).begins_with("custom_"),"editable":true,"draft":body.p_draft == true,"revision":int(body.p_expected_revision),"recurso_inicial":"0100","cartas":body.p_cartas.duplicate(true)}

func merged_decks(base_decks, custom_decks):
	var result = base_decks.duplicate(true)
	var seen = {}
	for deck in result:
		if deck is Dictionary: seen[str(deck.get("id", ""))] = true
	if custom_decks is Array:
		for deck in custom_decks:
			if not deck is Dictionary or deck.get("custom", false) != true: continue
			var id = str(deck.get("id", ""))
			if not id.begins_with("custom_") or seen.has(id): continue
			result.append(deck.duplicate(true))
			seen[id] = true
	return result

func load_inventory():
	var ok = await sync_events()
	if ok and not restos_welcome_claimed: ok = await ensure_economy()
	if ok and not welcome_pack.get("claimed",false): ok = await claim_welcome_pack()
	return ok

func sync_events():
	# Schedule before awaiting, so failed connections back off too.
	event_refresh_tick = Time.get_ticks_msec() + 60000
	return await request("aamix_events_sync", {})

func active_events():
	if not loaded or account == null or owner_id != account.player_id() or Time.get_ticks_msec() >= events_deadline_tick: return []
	return events.duplicate(true)

func expire_events():
	if events.is_empty() or Time.get_ticks_msec() < events_deadline_tick: return false
	events = []
	event_refresh_tick = 0
	changed.emit()
	return true

func apply_events(data):
	events = []
	var stamp = float(data.get("server_time", 0))
	var deadline = float(data.get("events_valid_until", 0))
	# Monotonic time; the PC calendar never decides eligibility.
	events_deadline_tick = Time.get_ticks_msec() + int(maxf(0, deadline-stamp) * 1000)
	event_refresh_tick = mini(Time.get_ticks_msec() + 60000, events_deadline_tick)
	server_day = str(data.get("server_day", ""))
	if data.get("events") is Array:
		for event in data.events:
			if event is Dictionary and event.get("missions") is Array and not str(event.get("id", "")).is_empty(): events.append(event.duplicate(true))

func claim_event_mission(event_id, mission_id):
	return await request("aamix_claim_event_mission", {"p_event_id":str(event_id), "p_mission_id":str(mission_id)})

func ensure_economy():
	return await request("aamix_claim_restos_welcome", {})

func purchase_card(request_uuid, code):
	return await request("aamix_purchase_card", {"p_request_id":str(request_uuid),"p_code":str(code)})

func claim_welcome_pack():
	return await request("aamix_claim_welcome_pack", {})

func enter_challenge():
	return await request("aamix_enter_challenge", {})

func claim(deck_id):
	return await request("aamix_claim_starter", {"p_deck_id":deck_id})

func set_avatar(code):
	return await request("aamix_set_avatar", {"p_code":code})

func redeem_code(value):
	return await request("aamix_redeem_code", {"p_code":str(value).strip_edges().to_upper()})

func begin_match(request_id, deck_id, challenge_stage = 0, event_battle = false):
	if event_battle: return await request("aamix_begin_event_match", {"p_request_id":request_id,"p_deck_id":deck_id})
	if int(challenge_stage) > 0:
		return await request("aamix_begin_challenge_match", {"p_request_id":request_id,"p_deck_id":deck_id,"p_stage":int(challenge_stage)})
	return await request("aamix_begin_match", {"p_request_id":request_id,"p_deck_id":deck_id})

func finish_match(match_id, victory, metrics={}):
	return await request("aamix_finish_challenge_v111", {"p_match_id":match_id,"p_result":"victory" if victory else "defeat","p_metrics":metrics})

func claim_challenge_mission(stage,id):
	return await request("aamix_claim_challenge_mission_v111",{"p_stage":int(stage),"p_mission_id":str(id)})

func claim_daily_mission():
	return await request("aamix_claim_daily_mission", {})

func claim_mission(mission_id):
	return await request("aamix_claim_mission", {"p_mission_id":str(mission_id)})

func normalize_missions(value, legacy = {}):
	var definitions = {
		"play_one":["Juega 1 partida",1,"restos",25],"win_one":["Gana 1 partida",1,"normal_pack",1],
		"play_ten":["Juega 10 partidas",10,"tc_pack",3],"win_ten":["Gana 10 partidas",10,"tc_pack",5],
		"play_fifty":["Juega 50 partidas",50,"normal_pack",10],"win_fifty":["Gana 50 partidas",50,"tc_pack",7],
		"win_five_kajido":["Gana 5 partidas con un mazo que incluya a Kajido",5,"restos",200],
		"win_five_flaan":["Gana 5 partidas con un mazo que incluya a SoyFlaan",5,"restos",200],
		"win_five_papito":["Gana 5 partidas con un mazo que incluya a Papito",5,"restos",200],
		"collect_ten_sam":["Colecciona 10 cartas de Sam",10,"avatar",1,"0114"],
		"collect_ten_yuri":["Colecciona 10 cartas de Yuri",10,"avatar",1,"0112"],
		"collect_ten_celia":["Colecciona 10 cartas de Celia",10,"avatar",1,"0113"],
		"collect_ten_viborin":["Colecciona 10 Viborín",10,"avatar",1,"0126"]}
	var entries = value if value is Array else []
	if entries.is_empty() and legacy is Dictionary and not legacy.is_empty(): entries = [legacy]
	var result = []; var seen = {}
	for entry in entries:
		if not entry is Dictionary: continue
		var id = str(entry.get("id", ""))
		if not definitions.has(id) or seen.has(id): continue
		var definition = definitions[id]; var state = entry.duplicate(true)
		state.id = id; state.title = str(entry.get("title", definition[0])); state.target = definition[1]
		state.progress = clampi(int(entry.get("progress", 0)), 0, state.target)
		state.claimed = entry.get("claimed", false) == true
		state.reward_kind = definition[2]; state.reward_amount = definition[3]
		if state.reward_kind == "avatar": state.reward_code = definition[4]
		state.reward_packs = state.reward_amount if state.reward_kind == "tc_pack" else 0
		state.scope = "daily" if id in ["play_one", "win_one"] else "lifetime"
		state.day = null if state.scope == "lifetime" else entry.get("day")
		result.append(state); seen[id] = true
	return result

func normalize_challenges(value):
	var result = []
	var entries = value if value is Array else []
	var expected = ["papito", "flaan", "kajido", "maago", "girabl", "dominios", "miku", "tsuki_akira", "imbloqueable", "chanchuus", "transmision"]
	var seen = {}
	for entry in entries:
		if not entry is Dictionary: continue
		var stage = int(entry.get("stage", 0))
		if stage < 1 or stage > expected.size() or seen.has(stage): continue
		if str(entry.get("deck_id", "")) != expected[stage - 1]: continue
		result.append({"stage":stage,"deck_id":expected[stage - 1],"title":str(entry.get("title", "")),"reward_packs":maxi(0,int(entry.get("reward_packs", 0))),"unlocked":entry.get("unlocked",false) == true,"completed":entry.get("completed",false) == true,"reward_claimed":entry.get("reward_claimed",false) == true})
		result.back()["missions"]=entry.get("missions",[]).duplicate(true)
		seen[stage] = true
	result.sort_custom(func(a,b): return a.stage < b.stage)
	return result

func open_pack(request_id):
	return await request("aamix_open_pack", {"p_request_id":request_id})

func delete_custom_deck(deck_id,revision):
	return await request("aamix_delete_custom_deck",{"p_deck_id":deck_id,"p_expected_revision":revision})

func open_normal_pack(request_id):
	return await request("aamix_open_normal_pack", {"p_request_id":request_id})

func acknowledge_opening(opening_id):
	return await request("aamix_acknowledge_opening", {"p_opening_id":opening_id})

func request_id():
	var bytes = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func request(endpoint, body):
	if busy or account == null or not account.signed_in(): return false
	last_error_code = ""
	last_http_code = 0
	if account.busy: return fail("La cuenta está conectando. Inténtalo de nuevo en un momento.")
	if account.expires_at < Time.get_unix_time_from_system() + 60:
		if not await account.refresh_session(): return false
	if not account.signed_in(): return false
	var request_owner = account.player_id()
	var request_generation = generation
	busy = true
	status = "Cargando tus cartas…" if endpoint == "aamix_inventory" else "Confirmando en el servicio…"
	changed.emit()
	var headers = PackedStringArray(["Content-Type: application/json", "apikey: " + account.publishable_key, "Authorization: Bearer " + account.access_token])
	var error = http.request(account.service_url + "/rest/v1/rpc/" + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var reply = []
	if error == OK: reply = await http.request_completed
	busy = false
	if request_generation != generation or request_owner != account.player_id():
		changed.emit()
		return false
	last_http_code = int(reply[1]) if reply.size() > 1 else 0
	if error != OK or reply[0] != HTTPRequest.RESULT_SUCCESS:
		return fail("No pudimos confirmar la respuesta. Usa el icono de recarga o reintenta: las recompensas no se duplican.")
	var code = int(reply[1])
	if code < 200 or code >= 300:
		var problem = JSON.parse_string(reply[3].get_string_from_utf8())
		last_error_code = str(problem.get("message", "")) if problem is Dictionary else ""
	if code == 401 or code == 403:
		loaded = false
		return fail("No pudimos validar el acceso a tus cartas. Vuelve a ingresar o usa el icono de recarga.")
	if code < 200 or code >= 300:
		var messages = {"AAMIX_START_CHALLENGE":"Entra al Desafío AAMIX para elegir tu mazo inicial.","AAMIX_INVALID_CODE":"Ese código de regalo no es válido.","AAMIX_NO_PACKS":"No tienes sobres disponibles.","AAMIX_MISSION_NOT_READY":"Completa esta misión antes de reclamar la recompensa.","AAMIX_INVALID_MISSION":"Esa misión no está disponible.","AAMIX_UNOWNED_DECK":"Ese mazo todavía no está entre tus mazos obtenidos.","AAMIX_INVALID_AVATAR":"Elige una carta de tipo Aliado para tu foto de perfil.","AAMIX_CHALLENGE_LOCKED":"Gana el desafío anterior para desbloquear esta partida.","AAMIX_INVALID_CHALLENGE":"Ese desafío no está disponible.","AAMIX_INSUFFICIENT_RESTOS":"No tienes Restos suficientes para esta carta.","AAMIX_CARD_NOT_FOR_SALE":"Esta carta no está disponible en la tienda.","AAMIX_PURCHASE_REQUEST_MISMATCH":"Esta solicitud corresponde a otra compra. Recarga la tienda antes de continuar."}
		messages.merge({"AAMIX_CODE_INACTIVE":"Este código sólo está disponible durante las fechas de su evento.","AAMIX_EVENT_INACTIVE":"Este evento ya no está activo. Recarga para ver los eventos disponibles."}, true)
		messages.merge(custom_deck_errors(), true)
		messages["AAMIX_DECK_IN_ROOM"] = "Sal de la sala multijugador antes de eliminar este mazo."
		messages.merge({"AAMIX_AVATAR_LOCKED":"Completa su misión histórica o canjea el código correspondiente para desbloquear esta foto.","AAMIX_MISSION_INCOMPLETE":"Alcanza el objetivo de esta misión antes de reclamar su recompensa."},true)
		return fail(messages.get(last_error_code,"No pudimos completar la solicitud. Revisa la conexión y usa el icono de recarga."))
	var data = JSON.parse_string(reply[3].get_string_from_utf8())
	if not data is Dictionary or data.get("user_id", "") != request_owner or not data.get("collection") is Dictionary or not data.get("decks") is Array:
		return fail("El servicio devolvió una respuesta inesperada. Usa el icono de recarga.")
	apply_social_inventory(data, false)
	var statuses = {"aamix_inventory":"","aamix_enter_challenge":"","aamix_claim_welcome_pack":"","aamix_claim_restos_welcome":"","aamix_purchase_card":"¡Carta añadida a Mi Colección!","aamix_set_avatar":"Foto guardada.","aamix_redeem_code":redemption_message(data),"aamix_begin_match":"","aamix_begin_challenge_match":"","aamix_finish_match":"","aamix_claim_daily_mission":mission_reward_message(data),"aamix_claim_mission":mission_reward_message(data),"aamix_open_pack":"","aamix_open_normal_pack":"","aamix_acknowledge_opening":"Tus nuevas cartas están en Mi Colección."}
	statuses["aamix_events_sync"] = ""
	statuses["aamix_claim_event_mission"] = "Esta recompensa ya está guardada." if data.get("already_claimed", false) else "¡Recompensa del evento recibida!"
	statuses["aamix_save_custom_deck"] = "Borrador guardado." if last_reply.get("last_saved_deck", {}).get("draft", false) else "Mazo guardado."
	statuses["aamix_delete_custom_deck"] = "Mazo eliminado."
	status = statuses.get(endpoint,"Tu regalo ya estaba guardado. Conservas el primer mazo elegido." if data.get("already_claimed", false) else "")
	changed.emit()
	return true

func redemption_message(data):
	if data.get("already_redeemed", false): return "ya has canjeado este regalo"
	var design = str(data.get("reward_cover", data.get("reward_design", "")))
	if design in DeckRules.CUSTOM_COVERS:
		return "Ya desbloqueaste el diseño %s." % DeckRules.cover_name(design) if data.get("already_redeemed", false) else "¡Diseño desbloqueado: %s!" % DeckRules.cover_name(design)
	var wallet_prizes = []
	var reward_packs = maxi(0, int(data.get("reward_packs", 0)))
	var reward_restos = maxi(0, int(data.get("reward_restos", 0)))
	var reward_normal_packs = maxi(0, int(data.get("reward_normal_packs", 0)))
	if reward_packs > 0: wallet_prizes.append("%d sobre%s TC" % [reward_packs, "" if reward_packs == 1 else "s"])
	if reward_restos > 0: wallet_prizes.append("%d Restos" % reward_restos)
	if reward_normal_packs > 0: wallet_prizes.append("%d carta%s aleatoria%s" % [reward_normal_packs, "" if reward_normal_packs == 1 else "s", "" if reward_normal_packs == 1 else "s"])
	if not wallet_prizes.is_empty(): return "¡Recibiste %s!" % ", ".join(wallet_prizes)
	var reward = str(data.get("reward_name", ""))
	if not reward.is_empty(): return "¡Recibiste %s!" % reward
	if data.get("reward_deck_id", "") == "maago": return "¡Recibiste tu Mazo Maagover y sus 40 cartas!"
	return "¡Recompensa añadida a tu colección!"

func custom_deck_errors():
	return {"AAMIX_DECK_COVER_LOCKED":"Este diseño todavía no está desbloqueado en tu cuenta. Completa su evento, canjea su código de regalo o elige otro diseño.","AAMIX_INVALID_DECK":"Revisa el nombre, la portada y las cartas del mazo.","AAMIX_DECK_SIZE":"Para jugar, el mazo debe tener 40 cartas. Puedes guardarlo como borrador.","AAMIX_DECK_INITIAL_RESOURCE":"Incluye al menos un Restos como Recurso Inicial.","AAMIX_DECK_UNOWNED_COPIES":"No tienes suficientes copias de una carta. Recarga tu colección.","AAMIX_DUPLICATE_DECK_CARD":"Cada carta debe aparecer una sola vez en la lista.","AAMIX_DECK_IMMUTABLE":"Los mazos base y regalados no se pueden editar.","AAMIX_DECK_REVISION_CONFLICT":"El mazo cambió en otra sesión. Recarga la colección y vuelve a editarlo.","AAMIX_REQUEST_REUSED":"Esta solicitud corresponde a otra operación. Recarga la colección.","AAMIX_INVALID_DECK_NAME":"Elige un nombre de entre 1 y 48 caracteres.","AAMIX_INVALID_DECK_COVER":"Elige un diseño disponible para el mazo.","AAMIX_INVALID_DECK_CARDS":"Revisa las cartas y sus cantidades.","AAMIX_DECK_COPY_LIMIT":"El mazo supera el límite de copias de una carta.","AAMIX_DECK_TOO_LARGE":"El mazo puede tener hasta 40 cartas, incluidos los Restos.","AAMIX_DECK_EMPTY":"Añade cartas al mazo o guárdalo como borrador.","AAMIX_DECK_UNOWNED_CARD":"No tienes suficientes copias de una carta. Recarga tu colección.","AAMIX_DECK_DRAFT":"Este mazo es un borrador. Termínalo antes de jugar.","AAMIX_DECK_CONFLICT":"El mazo cambió en otra sesión. Recarga la colección y vuelve a editarlo.","AAMIX_DECK_NOT_EDITABLE":"Los mazos base y regalados no se pueden editar.","AAMIX_DECK_REQUEST_MISMATCH":"Esta solicitud corresponde a otro guardado. Recarga la colección antes de continuar."}

func mission_reward_message(data):
	if data.get("already_claimed", false): return "Esta recompensa ya está guardada."
	var amount = maxi(1, int(data.get("reward_amount", data.get("reward_packs", 1))))
	var kind = str(data.get("reward_kind", "tc_pack"))
	if kind == "restos": return "¡Recibiste %d Restos!" % amount
	if kind == "normal_pack": return "¡Recibiste %d %s!" % [amount, "carta aleatoria" if amount == 1 else "cartas aleatorias"]
	return "¡Recibiste %d %s TC!" % [amount, "sobre" if amount == 1 else "sobres"]

func fail(message):
	status = message
	changed.emit()
	return false






func apply_social_inventory(data, notify = true):
	if not data is Dictionary or data.get("user_id", "") != account.player_id() or not data.get("collection") is Dictionary or not data.get("decks") is Array: return false
	owner_id = account.player_id()
	cards = data.collection.duplicate(true)
	decks = merged_decks(data.decks, data.get("custom_decks", []))
	available_custom_covers = normalize_available_covers(data.get("available_custom_covers"))
	apply_events(data)
	gift = data.get("gift")
	welcome_pack = data.get("welcome_pack", {"claimed":gift != null})
	profile = data.get("profile", {"avatar_code":""})
	available_avatar_codes = data.get("available_avatar_codes",[]).duplicate() if data.get("available_avatar_codes") is Array else []
	achievement_notifications = data.get("achievement_notifications",[]).duplicate(true) if data.get("achievement_notifications") is Array else []
	packs = int(data.get("packs", 0))
	normal_packs = maxi(0, int(data.get("normal_packs", 0)))
	halloween_packs=maxi(0,int(data.get("halloween_packs",0)))
	restos = maxi(0, int(data.get("restos", 0)))
	restos_welcome_claimed = data.get("restos_welcome_claimed", false) == true
	shop = data.get("shop", []).duplicate(true) if data.get("shop") is Array else []
	missions = normalize_missions(data.get("missions"), data.get("mission", {}))
	challenges = normalize_challenges(data.get("challenges"))
	mission = {}
	for state in missions:
		if state.id == "play_one": mission = state.duplicate(true)
	pending_opening = data.get("pending_opening")
	last_reply = data.duplicate(true)
	loaded = true
	last_error_code = ""
	if notify: changed.emit()
	return true

