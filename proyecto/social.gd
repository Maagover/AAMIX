extends Node
## Authenticated social transport. No email, password, session or inventory files.
signal changed
var board
var http
var busy = false
var loaded = false
var owner_id = ""
var generation = 0
var data = {}
var last_reply = {}
var status = ""
var last_error = ""
var next_poll = 0
var pending = {}
var inventory_dirty = false
var refreshing_inventory = false
var inventory_retry_tick = 0
const MESSAGES = {
	"AAMIX_ALREADY_TRADING":"Tú o tu amigo ya tienen una sala de intercambio. Terminen o cancelen esa sala antes de crear otra.",
	"AAMIX_TRADE_TURN":"Primero elige el anfitrión y después su amigo. Revisa el paso actual de la sala.",
	"AAMIX_TRADE_NOT_CONNECTED":"Los dos deben estar conectados en la sala para elegir y confirmar. Espera a que tu amigo vuelva.",
	"AAMIX_TRADE_UPDATE_REQUIRED":"Actualiza AAMIX para usar las nuevas salas de intercambio.",
	"AAMIX_FRIEND_UNAVAILABLE":"Revisa el código de amigo. No puedes añadirte a ti mismo.",
	"AAMIX_FRIEND_REQUEST_UNAVAILABLE":"Esta solicitud ya cambió. Recarga la lista.",
	"AAMIX_NOT_FRIENDS":"Deben aceptar la solicitud de amistad antes de continuar.",
	"AAMIX_SOCIAL_WAIT":"Espera un minuto antes de volver a enviar la solicitud.",
	"AAMIX_SOCIAL_LIMIT":"Tienes muchas solicitudes u ofertas pendientes. Cierra alguna antes de continuar.",
	"AAMIX_CARD_NOT_TRADABLE":"Los Recursos y las Promocionales no se pueden intercambiar.",
	"AAMIX_TRADE_CATEGORY":"Las Singulares sólo pueden intercambiarse por Singulares. Normales y Especiales pueden intercambiarse entre sí.",
	"AAMIX_TRADE_NO_COPY":"Esa copia ya no está disponible o está ofrecida en otro intercambio.",
	"AAMIX_TRADE_INCOMPLETE":"Ambos jugadores deben elegir una carta antes de confirmar.",
	"AAMIX_TRADE_CHANGED":"La oferta cambió. Revisa las dos cartas y vuelve a confirmar.",
	"AAMIX_TRADE_CLOSED":"El intercambio terminó, se canceló o venció.",
	"AAMIX_TRADE_UNAVAILABLE":"Ese intercambio no está disponible para tu cuenta.",
	"AAMIX_INVITE_UNAVAILABLE":"La invitación ya no está disponible.",
	"AAMIX_ROOM_FORBIDDEN":"Esta sala está reservada para el amigo invitado.",
	"AAMIX_ALREADY_IN_ROOM":"Ya tienes una sala abierta. Ciérrala antes de crear otra.",
	"AAMIX_ROOMS_FULL":"Las salas están ocupadas. Inténtalo en un momento.",
	"AAMIX_DECK_DRAFT":"Completa el borrador antes de usarlo para una partida.",
	"AAMIX_REQUEST_REUSED":"La solicitud cambió. Recarga antes de continuar."
}
func setup(value): board = value; return self
func _ready():
	http = HTTPRequest.new(); http.timeout = 20; http.max_redirects = 0; http.body_size_limit = 1048576; add_child(http)
func clear():
	generation += 1
	if busy and http != null: http.cancel_request()
	busy = false; loaded = false; owner_id = ""; data = {}; last_reply = {}; pending = {}; status = ""; next_poll = 0
	inventory_dirty = false; refreshing_inventory = false; inventory_retry_tick = 0
func _process(_delta):
	if board == null: return
	board.social_ui.present_received()
	var current = board.account.player_id()
	if not owner_id.is_empty() and current != owner_id: clear(); changed.emit()
	if current.is_empty() or not board.collection.loaded or busy or refreshing_inventory or board.account.busy or board.collection.busy: return
	if inventory_dirty and Time.get_ticks_msec() >= inventory_retry_tick:
		flush_inventory(); return
	if board.screen in ["home", "friends", "trades", "multiplayer"] and Time.get_ticks_msec() >= next_poll:
		sync(true)
func sync(quiet = false):
	next_poll = Time.get_ticks_msec() + (3000 if board.screen == "trades" else (5000 if board.screen == "friends" else 30000))
	var current = room()
	if board.screen == "trades" and current.get("active",false): return await request("aamix_trade_room_poll",{"p_room":current.id},quiet)
	return await request("aamix_social_sync", {}, quiet)
func mutate(endpoint, payload):
	if busy: return false
	var signature = endpoint+JSON.stringify(payload)
	if not pending.is_empty() and pending.signature != signature:
		status = "Reintenta primero la operación pendiente para recuperar su confirmación."; changed.emit(); return false
	if pending.is_empty(): pending = {"endpoint":endpoint,"payload":payload.duplicate(true),"signature":signature,"id":board.collection.request_id()}
	return await retry_pending()
func retry_pending():
	if pending.is_empty() or busy: return false
	var body = pending.payload.duplicate(true); body.p_request_id = pending.id
	return await request(pending.endpoint, body)
func request(endpoint, payload, quiet = false):
	if busy or refreshing_inventory or board.collection.busy or not board.account.signed_in() or board.account.busy: return false
	if board.account.expires_at < Time.get_unix_time_from_system()+60:
		if not await board.account.refresh_session(): return false
	var who = board.account.player_id(); var expected_generation = generation
	owner_id = who; busy = true; last_error = ""
	if not quiet: status = "Confirmando…"; changed.emit()
	var error = http.request(board.account.service_url+"/rest/v1/rpc/"+endpoint, PackedStringArray(["Content-Type: application/json","apikey: "+board.account.publishable_key,"Authorization: Bearer "+board.account.access_token]),HTTPClient.METHOD_POST,JSON.stringify(payload))
	var reply = []
	if error == OK: reply = await http.request_completed
	if generation != expected_generation or who != board.account.player_id(): return false
	busy = false
	if error != OK or reply.is_empty() or reply[0] != HTTPRequest.RESULT_SUCCESS:
		status = "No pudimos confirmar la respuesta. Reintenta; la operación no se duplicará."; changed.emit(); return false
	var body = JSON.parse_string(reply[3].get_string_from_utf8())
	var code = int(reply[1])
	if code < 200 or code >= 300:
		last_error = str(body.get("message", "")) if body is Dictionary else ""
		status = MESSAGES.get(last_error, "No pudimos completar la operación. Recarga e inténtalo de nuevo.")
		if endpoint != "aamix_social_sync" and code >= 400 and code < 500 and code not in [408,429]: pending = {}; next_poll = 0
		changed.emit(); return false
	if not body is Dictionary or str(body.get("user_id", "")) != who or not body.get("friends") is Array:
		status = "El servicio devolvió una respuesta inesperada. Reintenta para confirmarla."; changed.emit(); return false
	last_reply = body.duplicate(true)
	var clean = body.duplicate(true); clean.erase("inventory"); clean.erase("room"); clean.erase("trade_id")
	var altered = not loaded or clean != data
	for completed in clean.get("trades", []):
		if completed.status == "completed" and trade(completed.id).get("status", "") != "completed": inventory_dirty = true
	var updated_room = clean.get("trade_room",{})
	if updated_room.get("status","") == "completed" and (room().get("id","") != updated_room.get("id","") or room().get("status","") != "completed"): inventory_dirty = true
	for notice in clean.get("trade_notifications",[]):
		if not data.get("trade_notifications",[]).any(func(old):return old.id == notice.id): inventory_dirty = true
	data = clean; loaded = true; status = ""
	if endpoint != "aamix_social_sync": pending = {}
	if body.get("inventory") is Dictionary:
		board.collection.apply_social_inventory(body.inventory)
		# Re-read after any overlapping inventory request, so an older reply cannot leave stale ownership.
		inventory_dirty = true
	await flush_inventory()
	if generation != expected_generation or who != board.account.player_id(): return false
	if body.get("room") is Dictionary and not body.room.is_empty():
		board.online.session_user = who; board.online_ui.section = "private"; board.online.receive(body.room)
		board.screen = "multiplayer"; board.render()
	if not quiet or altered: changed.emit()
	return true
func room():
	if owner_id != board.account.player_id() or not data.get("trade_room") is Dictionary: return {}
	return data.trade_room
func flush_inventory():
	if not inventory_dirty or refreshing_inventory or board.collection.busy or board.account.busy: return
	var expected_generation = generation
	refreshing_inventory = true; inventory_dirty = false
	var ok = await board.collection.load_inventory()
	if generation != expected_generation: return
	refreshing_inventory = false
	if not ok:
		inventory_dirty = true; inventory_retry_tick = Time.get_ticks_msec()+5000
func friends(): return data.get("friends", []) if owner_id == board.account.player_id() else []
func trade(id):
	for t in data.get("trades", []):
		if str(t.id) == str(id): return t
	return {}
