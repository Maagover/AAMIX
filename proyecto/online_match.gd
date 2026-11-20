extends Node
## Private two-player rooms over the existing HTTPS service. No port forwarding.
## The creator runs the rules; the service controls membership, revisions and receipts.
signal changed
const Snapshot = preload("res://multiplayer_snapshot.gd")
const RULESET_VERSION = "1.9"
const VERSIONED_RPC = ["aamix_mp_create_room", "aamix_mp_join_room", "aamix_mp_active", "aamix_mp_poll", "aamix_mp_confirm", "aamix_mp_submit", "aamix_mp_commit", "aamix_mp_host_action"]
var board
var http
var busy = false
var session_user = ""
var generation = 0
var room = {}
var incompatible_room = {}
var revision = -1
var slot = -1
var connected = false
var status = ""
var last_error = ""
var next_poll = 0.0
var failures = 0
var pending_command = {}
var staged_commit = {}
var selected_deck = ""
var joining_code = ""
var lobby_mode = "choice"
var view_activations = []
var retry_operation = {}
var command_submitted = false
var commit_endpoint = "aamix_mp_commit"
var metrics = {"requests":{},"durations_ms":[]}
var priority_waiters = 0
var realtime
var presentations=[]
var visible_revision=-1
var force_polling=false
var receive_source="http"
var rematch_retry = {}
var retired_rooms = []

func setup(value):
	board = value
	return self

func _ready():
	http = HTTPRequest.new()
	http.timeout = 15.0
	http.max_redirects = 0
	http.body_size_limit = 262144
	add_child(http)
	realtime=preload("res://realtime_inbox.gd").new()
	realtime.account=board.account
	realtime.message.connect(receive_push)
	add_child(realtime)

func active():
	return not room.is_empty() and str(room.get("status","")) in ["ready","playing","finished"]

func in_match():
	return active() and not room.get("state",{}).is_empty()

func waiting_action():
	return not pending_command.is_empty() or not staged_commit.is_empty() or not connected or not presentations.is_empty()

func _process(_delta):
	if board == null or board.account == null: return
	var current = board.account.player_id()
	if not session_user.is_empty() and current != session_user:
		clear()
		return
	flush_presentation()
	if room.is_empty() or busy or priority_waiters>0 or current.is_empty(): return
	if realtime!=null: realtime.set_process(not force_polling)
	if force_polling and realtime!=null and realtime.socket!=null: realtime.stop()
	if Time.get_ticks_msec() / 1000.0 < next_poll: return
	pump.call_deferred()
	next_poll = Time.get_ticks_msec() / 1000.0 + .1

func clear():
	generation += 1
	if realtime!=null: realtime.stop()
	presentations.clear()
	visible_revision=-1
	if http != null and busy: http.cancel_request()
	busy = false
	session_user = ""
	room = {}
	incompatible_room = {}
	revision = -1
	slot = -1
	connected = false
	status = ""
	last_error = ""
	pending_command = {}
	staged_commit = {}
	command_submitted = false
	commit_endpoint = "aamix_mp_commit"
	retry_operation = {}
	rematch_retry = {}; retired_rooms.clear()
	view_activations = []
	lobby_mode = "choice"
	changed.emit()

func discover():
	if busy or not board.account.signed_in(): return
	session_user = board.account.player_id()
	status = "Buscando tu sala…"
	var reply = await request("aamix_mp_active",{})
	if reply.get("ok",false):
		if not has_room_id(reply.data):
			incompatible_room = {}
			status = "Crea una sala o únete con el código de tu amigo."
			changed.emit()
		else: receive(reply.data)

func create_room(deck_id):
	if busy: return
	session_user = board.account.player_id()
	selected_deck = str(deck_id)
	if retry_operation.get("method","") != "aamix_mp_create_room" or retry_operation.get("deck","") != selected_deck:
		retry_operation = {"method":"aamix_mp_create_room","deck":selected_deck,"id":board.collection.request_id()}
	var reply = await request("aamix_mp_create_room",{"p_request_id":retry_operation.id,"p_deck_id":selected_deck})
	if reply.get("ok",false):
		retry_operation = {}
		receive(reply.data)
	else: changed.emit()

func join_room(code,deck_id):
	if busy: return
	session_user = board.account.player_id()
	selected_deck = str(deck_id)
	joining_code = str(code).strip_edges().to_upper()
	if joining_code.length() != 8:
		status = "Ingresa el código de 8 caracteres."
		changed.emit()
		return
	if retry_operation.get("method","") != "aamix_mp_join_room" or retry_operation.get("code","") != joining_code or retry_operation.get("deck","") != selected_deck:
		retry_operation = {"method":"aamix_mp_join_room","deck":selected_deck,"code":joining_code,"id":board.collection.request_id()}
	var reply = await request("aamix_mp_join_room",{"p_code":joining_code,"p_deck_id":selected_deck,"p_request_id":retry_operation.id})
	if reply.get("ok",false):
		retry_operation = {}
		receive(reply.data)
	else: changed.emit()

func pump():
	if busy or room.is_empty(): return
	var next_room = rematch_room_id()
	if not next_room.is_empty() and not room.get("rematch",{}).get("cancelled",false):
		var reply = await request("aamix_mp_poll",{"p_room_id":next_room,"p_since_revision":-1})
		if reply.get("ok",false): receive(reply.data)
		return
	if not staged_commit.is_empty():
		var reply = await request(commit_endpoint,staged_commit)
		if reply.get("ok",false):
			staged_commit = {}
			commit_endpoint = "aamix_mp_commit"
			receive(reply.data)
		else: recover_commit_failure()
		return
	if not pending_command.is_empty() and not command_submitted:
		var reply = await request("aamix_mp_submit",pending_command)
		if reply.get("ok",false):
			command_submitted=true
			receive(reply.data)
		elif last_error in ["AAMIX_STALE_REVISION","AAMIX_NOT_YOUR_TURN","AAMIX_ROOM_NOT_PLAYING","AAMIX_ACTION_PENDING","AAMIX_INVALID_ACTION","AAMIX_REQUEST_REUSED","AAMIX_ROOM_EXPIRED"]:
			pending_command = {}
			command_submitted=false
			next_poll = 0.0
		return
	if slot==0 and str(room.get("status",""))=="playing" and not room.get("commands",[]).is_empty():
		host_execute(room.commands[0])
		if not staged_commit.is_empty(): return
	var reply = await request("aamix_mp_poll",{"p_room_id":room.room_id,"p_since_revision":revision})
	if reply.get("ok",false): receive(reply.data)

func submit(method,args = []):
	if not in_match() or waiting_action() or board.game.actor != slot or board.game.winner != -1 or method not in Snapshot.METHODS: return false
	if method == "request_play" and args.size() == 1: args.append(-1)
	if slot==0: return stage_host_action(method,args)
	pending_command = {"p_room_id":room.room_id,"p_request_id":board.collection.request_id(),"p_expected_revision":revision,"p_method":method,"p_args":args.duplicate(true)}
	command_submitted=false
	status = "Enviando jugada…"
	next_poll = 0.0
	changed.emit()
	return true

func stage_host_action(method,args):
	var before=Snapshot.capture(board.game)
	if not Snapshot.dispatch(board.game,0,method,Snapshot.integers(args)):
		Snapshot.restore(board.game,before)
		status="La jugada no está disponible."
		changed.emit()
		return false
	stage(board.collection.request_id(),"",before)
	staged_commit.p_method=method
	staged_commit.p_args=args.duplicate(true)
	commit_endpoint="aamix_mp_host_action"
	Snapshot.restore(board.game,before)
	changed.emit()
	return true

func confirm():
	if room.is_empty() or not await acquire_control(): return false
	var reply=await request("aamix_mp_confirm",{"p_room_id":room.room_id})
	if not reply.get("ok",false): return false
	receive(reply.data)
	return true

func acquire_control():
	# A background poll must never swallow an explicit confirmation or abandon.
	var expected_generation=generation
	var deadline=Time.get_ticks_msec()+16000
	priority_waiters+=1
	while busy and Time.get_ticks_msec()<deadline and generation==expected_generation:
		await get_tree().process_frame
	priority_waiters-=1
	return generation==expected_generation and not busy and board.account.signed_in()

func poll_interval():
	# Heartbeats/recovery only when server push is subscribed. No animation-speed shortcut.
	if not force_polling and realtime!=null and realtime.joined:
		if not pending_command.is_empty(): return 2.0
		return 8.0
	if str(room.get("status","")) in ["finished","cancelled"]: return 8.0
	if str(room.get("status","")) not in ["playing","ready"]: return 1.0
	if not pending_command.is_empty(): return .16
	if str(room.get("status",""))=="ready": return .4
	if int(room.get("actor_slot",-1))==slot: return 1.2
	return .24 if slot==0 else .32

func has_room_id(data):
	return data is Dictionary and data.get("room_id") is String and not str(data.room_id).is_empty()

func recover_commit_failure():
	if last_error not in ["AAMIX_STALE_REVISION","AAMIX_ROOM_EXPIRED","AAMIX_ROOM_NOT_PLAYING","AAMIX_UNKNOWN_COMMAND","AAMIX_CONFIRM_REQUIRED"]: return false
	staged_commit = {}
	pending_command = {}
	command_submitted=false
	commit_endpoint="aamix_mp_commit"
	revision = -1
	next_poll = 0.0
	return true

func receive_push(data):
	if force_polling or room.is_empty() or str(data.get("room_id",""))!=str(room.get("room_id","")): return
	receive_source="push"
	receive(data)
	receive_source="http"

func receive(data):
	if not has_room_id(data): return
	if str(data.room_id) in retired_rooms:return
	if str(data.get("ruleset_version", "1.2")) != RULESET_VERSION:
		reject_incompatible(data)
		return
	var incoming_state = data.get("state", {})
	if incoming_state is Dictionary and not incoming_state.is_empty() and str(incoming_state.get("ruleset_version", "1.2")) != RULESET_VERSION:
		reject_incompatible(data)
		return
	# An earlier HTTP response can arrive after its committed WebSocket update.
	if str(data.get("room_id",""))==str(room.get("room_id","")):
		if int(data.get("revision",-1))<revision or int(data.get("room_version",0))<int(room.get("room_version",0)): return
	var old_revision = revision
	var old_room = str(room.get("room_id",""))
	var old_state = room.get("state",{}).duplicate(true)
	var old_commands=room.get("commands",[]).duplicate(true)
	if old_room!=str(data.room_id):
		if not old_room.is_empty():
			retired_rooms.append(old_room)
			board.reset_match()
			pending_command = {}; staged_commit = {}; command_submitted = false
			board.screen = "multiplayer"
		presentations.clear()
		visible_revision=-1
	room = Snapshot.integers(data)
	incompatible_room = {}
	if not room.get("state") is Dictionary: room.state = old_state if old_room == str(room.room_id) else {}
	if old_room==str(room.room_id) and int(room.get("revision",-1))==old_revision and receive_source=="http" and room.get("commands",[]).is_empty() and not old_commands.is_empty(): room.commands=old_commands
	slot = int(room.get("slot",-1))
	revision = int(room.get("revision",-1))
	connected = true
	failures = 0
	status = "Conectado" if str(room.get("status","")) in ["playing","ready"] else "Esperando al otro jugador…"
	if room.get("last_error","") == "AAMIX_INVALID_ACTION": status = "La jugada ya no era válida. Puedes intentarlo de nuevo."
	elif room.get("opponent_online") == false and str(room.get("status","")) == "playing": status = "Esperando que tu rival vuelva a conectar…"
	if not pending_command.is_empty() and revision > int(pending_command.p_expected_revision):
		pending_command = {}
		command_submitted=false
	next_poll = Time.get_ticks_msec() / 1000.0 + poll_interval()
	if not rematch_room_id().is_empty():next_poll=0.0
	if str(room.get("status","")) in ["cancelled","expired","abandoned"]:
		# An expired room can still carry its last, unfinished recovery snapshot.
		# Never restore it as a playable offline table after multiplayer closes.
		room.state = {}
		presentations.clear()
		pending_command = {}
		staged_commit = {}
		status = "La sala se cerró. Puedes crear otra partida."
		if board.active_deck_id == "online":
			board.reset_match()
			board.screen = "multiplayer"
		changed.emit()
		return
	if slot == 0 and staged_commit.is_empty() and str(room.get("status","")) == "ready" and revision == 0 and room.state.is_empty() and room.get("confirmed",[false,false])==[true,true]:
		start_host_game()
		return
	if not room.state.is_empty() and (revision != old_revision or old_room != str(room.room_id) or not board.started):
		presentations.append({"revision":revision,"state":room.state.duplicate(true),"slot":slot,"room":str(room.room_id),"status":str(room.get("status","")),"winner":int(room.get("winner",-1)),"error":str(room.get("last_error",""))})
		flush_presentation()
	if slot == 0 and str(room.get("status","")) == "playing" and not room.get("commands",[]).is_empty() and staged_commit.is_empty():
		var command = room.commands[0]
		host_execute(command)
	changed.emit()

func reject_incompatible(data):
	# Keep only enough membership metadata for an explicit close. An old ruleset
	# must never restore cards, pending commands or a host engine after upgrading.
	incompatible_room = {"room_id":str(data.room_id),"status":str(data.get("status", "waiting")),"ruleset_version":str(data.get("ruleset_version", "1.2"))}
	session_user = board.account.player_id()
	room = {}
	presentations.clear()
	pending_command = {}
	staged_commit = {}
	view_activations.clear()
	command_submitted = false
	connected = false
	if realtime != null: realtime.stop()
	status = "Esta sala usa otra versión de las reglas. Ambos jugadores deben actualizar AAMIX a la versión 1.3."
	if board.active_deck_id == "online":
		board.reset_match()
		board.screen = "multiplayer"
	changed.emit()

func close_incompatible_room():
	if incompatible_room.is_empty() or not await acquire_control(): return false
	var reply = await request("aamix_mp_leave", {"p_room_id":str(incompatible_room.room_id)})
	if not reply.get("ok", false): return false
	clear()
	status = "Sala anterior cerrada. Ya puedes crear una sala con las reglas 1.3."
	board.screen = "multiplayer"
	board.render()
	return true

func flush_presentation():
	if presentations.is_empty() or board.presenting or board.fx.busy: return
	var next=presentations.pop_front()
	if next.room!=str(room.get("room_id","")): return
	var layout=board.capture_layout() if board.started and board.screen=="table" and board.active_deck_id=="online" else {}
	var packet=[]
	if visible_revision>=0 and int(next.revision)==visible_revision+1 and str(next.get("error",""))!="AAMIX_INVALID_ACTION": packet=next.state.get("presentation",[])
	if Snapshot.restore(board.game,next.state):
		visible_revision=int(next.revision)
		view_activations=next.state.get("legal_activations",[])
		board.accept_online_state(int(next.slot),packet,layout,next)

func start_host_game():
	if not staged_commit.is_empty(): return
	var decks = []
	for p in range(2):
		var value = room.get("host_deck" if p == 0 else "guest_deck",{})
		if value.is_empty() and room.get("players",[]).size() > p: value = room.players[p].get("deck",{})
		if not value is Dictionary or not value.get("cartas") is Array:
			status = "No se pudo preparar el mazo de esta sala. Vuelve a conectar."
			changed.emit()
			return
		decks.append(value)
	board.game.manual_payment = [true,true]
	# These are the server's frozen room lists, never a later inventory edit.
	if board.game.new_game(-1,decks) == false:
		status = "El mazo de la sala no está listo para jugar. Vuelve a conectar."
		changed.emit()
		return
	for p in range(2): board.game.players[p].name = str(room.players[p].get("name","Jugador %d" % (p+1)))
	var empty_before=Snapshot.capture(board.game)
	for p in range(2):
		for zone in board.game.ZONES: empty_before.players[p][zone]=[]
	empty_before.instances={}
	empty_before.domain_uid=-1
	empty_before.pending={}
	stage(board.collection.request_id(),"",empty_before)
	changed.emit()

func host_execute(command):
	if int(command.get("revision",revision)) != revision: return
	var displayed = Snapshot.capture(board.game)
	if not Snapshot.restore(board.game,room.state): return
	var before = Snapshot.capture(board.game)
	var args = Snapshot.integers(command.get("args",[]))
	var valid = Snapshot.dispatch(board.game,int(command.get("slot",-1)),str(command.get("method","")),args)
	if not valid:
		Snapshot.restore(board.game,before)
	stage(str(command.request_id),"" if valid else "AAMIX_INVALID_ACTION",before)
	Snapshot.restore(board.game,displayed)
	changed.emit()

func stage(request_id,error_text = "",before = {}):
	board.game.error = ""
	var full = Snapshot.capture(board.game)
	var guest_state = Snapshot.guest_view(board.game)
	if error_text.is_empty():
		var packet=board.game.visual_events.duplicate(true)
		var guest_packet=Snapshot.presentation(board.game,before,1)
		full.presentation=packet
		full.guest_presentation=guest_packet
		guest_state.presentation=guest_packet
	else:
		full=room.state.duplicate(true)
		guest_state.presentation=full.get("guest_presentation",[])
	full.visual_events=[]
	board.game.visual_events.clear()
	staged_commit = {"p_room_id":room.room_id,"p_request_id":request_id,"p_expected_revision":revision,"p_host_state":full,"p_guest_view":guest_state,"p_actor_slot":board.game.actor,"p_winner":board.game.winner,"p_error":error_text}
	commit_endpoint="aamix_mp_commit"
	next_poll = 0.0
	status = "Sincronizando jugada…"

func leave():
	if room.is_empty() or not await acquire_control(): return false
	if str(room.get("status","")) == "finished":
		var cancelled = await rematch_action("cancel")
		if not cancelled:return false
		if not await acquire_control():return false
	var reply = await request("aamix_mp_leave",{"p_room_id":room.room_id})
	if not reply.get("ok",false): return false
	clear()
	status="Abandonaste la partida." if str(reply.data.get("status",""))=="finished" else "Sala cerrada."
	board.reset_match()
	board.screen = "multiplayer"
	board.render()
	board.collection.load_inventory.call_deferred()
	return true

func rematch_action(action,deck_id=""):
	if room.is_empty() or str(room.get("status",""))!="finished" or not await acquire_control():return false
	var body = {"p_room_id":str(room.room_id),"p_action":action,"p_deck_id":deck_id if not deck_id.is_empty() else null}
	if rematch_retry.get("body",{}) != body:rematch_retry={"body":body.duplicate(true),"id":board.collection.request_id()}
	body.p_request_id=rematch_retry.id
	var reply=await request("aamix_mp_rematch",body)
	if not reply.get("ok",false):
		if not last_error.is_empty():rematch_retry={}
		changed.emit();return false
	rematch_retry={}
	receive(reply.data)
	return true

func rematch_room_id():
	var id=room.get("rematch",{}).get("next_room_id",null)
	return "" if id==null else str(id)

func request(endpoint,body):
	if busy or not board.account.signed_in(): return {"ok":false}
	if board.account.expires_at < Time.get_unix_time_from_system()+60:
		if not await board.account.refresh_session(): return {"ok":false}
	var request_generation = generation
	var request_owner = board.account.player_id()
	busy = true
	var sent_at=Time.get_ticks_msec()
	metrics.requests[endpoint]=int(metrics.requests.get(endpoint,0))+1
	var headers = PackedStringArray(["Content-Type: application/json","apikey: "+board.account.publishable_key,"Authorization: Bearer "+board.account.access_token])
	var code = http.request(board.account.service_url+"/rest/v1/rpc/"+rpc_endpoint(endpoint),headers,HTTPClient.METHOD_POST,JSON.stringify(body))
	var reply = []
	if code == OK: reply = await http.request_completed
	metrics.durations_ms.append(Time.get_ticks_msec()-sent_at)
	if request_generation != generation or request_owner != board.account.player_id(): return {"ok":false}
	busy = false
	if code != OK or reply.is_empty() or reply[0] != HTTPRequest.RESULT_SUCCESS:
		connection_failed()
		return {"ok":false}
	var data = JSON.parse_string(reply[3].get_string_from_utf8())
	if int(reply[1]) < 200 or int(reply[1]) >= 300 or not data is Dictionary:
		last_error = str(data.get("message","")) if data is Dictionary else ""
		var messages = {"AAMIX_ROOM_UNAVAILABLE":"Esa sala ya no está disponible para unirse.","AAMIX_INVALID_ROOM":"No encontramos una sala disponible con ese código.","AAMIX_ROOM_FORBIDDEN":"La sala ya no está disponible para tu cuenta.","AAMIX_ROOMS_FULL":"Todas las salas están ocupadas. Inténtalo en un momento.","AAMIX_UNOWNED_DECK":"Elige uno de tus mazos obtenidos.","AAMIX_ALREADY_IN_ROOM":"Ya tienes una sala. Usa Retomar sala.","AAMIX_STALE_REVISION":"La partida avanzó. Estamos sincronizando…","AAMIX_NOT_YOUR_TURN":"Espera tu turno.","AAMIX_ACTION_PENDING":"Confirmando la jugada anterior…","AAMIX_ROOM_EXPIRED":"La sala expiró. Puedes crear otra partida."}
		messages.merge(board.collection.custom_deck_errors(),true)
		messages["AAMIX_RULESET_MISMATCH"] = "Esta sala usa otra versión de las reglas. Ambos jugadores deben actualizar AAMIX a la versión 1.3."
		status = messages.get(last_error,"No pudimos completar esta acción. Reintenta para recuperar tu sala.")
		if data is Dictionary and str(data.get("code", "")) == "PGRST202": status = "El servicio de Multijugador necesita la actualización de AAMIX 1.3. Inténtalo de nuevo en un momento."
		connection_failed(false)
		return {"ok":false}
	last_error = ""
	connected = true
	return {"ok":true,"data":data}

static func rpc_endpoint(endpoint):
	return str(endpoint)+"_v190" if endpoint in VERSIONED_RPC else str(endpoint)

func connection_failed(network = true):
	failures += 1
	connected = false
	if network: status = "Reconectando… Conservamos tu sala y la jugada pendiente."
	next_poll = Time.get_ticks_msec() / 1000.0 + minf(15.0,pow(2.0,min(failures,4)))
	changed.emit()

