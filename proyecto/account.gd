extends Node
## Client for Supabase Auth. An ID exists only after the server verifies the code.
## Opt-in remembered sessions are encrypted with Windows DPAPI CurrentUser.
## Only a refresh token and autofill fields are persisted; never OTP/access tokens.
signal changed
var service_url = ""
var publishable_key = ""
var configured = false
var registration_ready = false
var restricted_delivery = true
var busy = false
var user = {}
var access_token = ""
var refresh_token = ""
var expires_at = 0.0
var pending_email = ""
var code_sent = false
var resend_at = 0.0
var status = ""
var http
var remember_me = false
var remembered_email = ""
var remembered_name = ""
var remembered_session_path = "user://remembered_session.bin"
var refresh_retry_at = 0.0
var storage_error = ""
var _saved_refresh_token = ""

func _ready():
	http = HTTPRequest.new()
	http.timeout = 15.0
	http.max_redirects = 0
	http.body_size_limit = 1048576
	add_child(http)
	if FileAccess.file_exists("res://data/cuentas.json"):
		var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/cuentas.json"))
		if config is Dictionary:
			configure(str(config.get("url", "")), str(config.get("publishable_key", "")))
			registration_ready = config.get("email_templates_ready", false) == true
			restricted_delivery = config.get("email_delivery", "project_team_only") == "project_team_only"
	status = availability_message()
	_load_remembered()
	_restore_remembered.call_deferred()

func availability_message():
	if not configured: return "Las cuentas en línea todavía no están habilitadas. Puedes seguir jugando en Partida individual."
	if not registration_ready: return "El servicio de cuentas está conectado. Falta completar la configuración de correos para habilitar el registro y el ingreso."
	return "Crea tu cuenta o ingresa con tu correo y el código que recibirás."

func configure(url, key, allow_loopback_for_tests = false):
	service_url = str(url).strip_edges().trim_suffix("/")
	publishable_key = str(key).strip_edges()
	var uri = RegEx.new()
	uri.compile("^https://[A-Za-z0-9.-]+(:[0-9]+)?$")
	var valid_url = uri.search(service_url) != null
	if allow_loopback_for_tests:
		uri.compile("^http://127\\.0\\.0\\.1:[0-9]+$")
		valid_url = valid_url or uri.search(service_url) != null
	configured = valid_url and publishable_key.begins_with("sb_publishable_") and not "\n" in publishable_key and not "\r" in publishable_key
	registration_ready = allow_loopback_for_tests
	return configured

func signed_in():
	return not user.is_empty() and not access_token.is_empty() and expires_at > Time.get_unix_time_from_system()

func player_id():
	return str(user.get("id", "")) if signed_in() else ""

func display_name():
	var metadata = user.get("user_metadata", {})
	if not metadata is Dictionary: return "Jugador"
	var nickname = str(metadata.get("display_name", "")).strip_edges()
	return nickname if not nickname.is_empty() else "Jugador"

func _process(_delta):
	if not busy and not refresh_token.is_empty() and Time.get_unix_time_from_system() >= maxf(expires_at - 60, refresh_retry_at):
		refresh_session()

func fail(message):
	status = message
	changed.emit()
	return false

func request_code(email, nickname = "", create_user = false):
	if busy: return false
	if not configured: return fail("Las cuentas en línea todavía no están habilitadas. Puedes jugar en Partida individual.")
	if not registration_ready: return fail(availability_message())
	var address = str(email).strip_edges().to_lower()
	var valid_email = RegEx.new()
	valid_email.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
	if address.length() > 254 or valid_email.search(address) == null: return fail("Escribe un correo válido.")
	var name_to_use = str(nickname).strip_edges()
	if create_user and (name_to_use.length() < 2 or name_to_use.length() > 24 or "\n" in name_to_use or "\r" in name_to_use):
		return fail("Tu nombre visible debe tener entre 2 y 24 caracteres.")
	if remember_me:
		remembered_email = address
		remembered_name = name_to_use
		_persist_remembered()
	var remaining = ceili(resend_at - Time.get_unix_time_from_system())
	if remaining > 0: return fail("Espera %d segundos antes de pedir otro código." % remaining)
	var body = {"email":address, "create_user":create_user}
	if create_user: body.data = {"display_name":name_to_use}
	var reply = await send("/otp", body)
	if not reply.ok: return fail(reply.message)
	pending_email = address
	code_sent = true
	resend_at = Time.get_unix_time_from_system() + 60
	status = "Si el correo es válido, recibirás un código. Escríbelo aquí para continuar."
	changed.emit()
	return true

func verify_code(code):
	if busy: return false
	if not code_sent or pending_email.is_empty(): return fail("Primero solicita un código para tu correo.")
	var token = str(code).strip_edges()
	var digits = RegEx.new()
	digits.compile("^[0-9]{6,10}$")
	if digits.search(token) == null: return fail("Escribe el código numérico que recibiste por correo.")
	var reply = await send("/verify", {"email":pending_email, "token":token, "type":"email"})
	if not reply.ok: return fail(reply.message)
	if not accept_session(reply.data): return fail("No pudimos validar la sesión. Solicita un código nuevo.")
	code_sent = false
	pending_email = ""
	status = "Tu cuenta está lista. Este ID se mantiene al ingresar con el mismo correo."
	changed.emit()
	return true

func accept_session(data):
	if not data is Dictionary or not data.get("user") is Dictionary: return false
	var identity = RegEx.new()
	identity.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	if identity.search(str(data.user.get("id", ""))) == null: return false
	if not data.get("access_token") is String or str(data.access_token).is_empty(): return false
	if not data.get("refresh_token") is String or str(data.refresh_token).is_empty(): return false
	var lifetime = float(data.get("expires_in", 0))
	if lifetime <= 60 or lifetime > 86400: return false
	user = data.user.duplicate(true)
	access_token = data.access_token
	refresh_token = data.refresh_token
	expires_at = Time.get_unix_time_from_system() + lifetime
	refresh_retry_at = 0.0
	if remember_me:
		remembered_email = str(user.get("email", remembered_email)).strip_edges().to_lower()
		remembered_name = display_name()
		_saved_refresh_token = refresh_token
		_persist_remembered()
	return true

func refresh_session():
	if busy or refresh_token.is_empty(): return false
	var reply = await send("/token?grant_type=refresh_token", {"refresh_token":refresh_token})
	if not reply.ok and reply.get("retryable", false):
		# Losing connectivity must not throw away the only refresh token. Retry
		# with a bounded delay; do not identify an unverified remembered user.
		refresh_retry_at = Time.get_unix_time_from_system() + 30.0
		return fail("No pudimos recuperar tu sesión. Reintentaremos cuando haya conexión.")
	if not reply.ok or not accept_session(reply.data):
		clear_session(false)
		return fail("Tu sesión terminó. Vuelve a ingresar con un código para recuperar tu mismo ID.")
	changed.emit()
	return true

func sign_out():
	if busy: return false
	var token_to_revoke = access_token
	# Clear locally even if the connection fails during revocation.
	clear_session()
	var revoked = true
	if configured and not token_to_revoke.is_empty():
		var reply = await send("/logout?scope=local", {}, token_to_revoke)
		revoked = reply.ok
	status = "" if revoked else "La sesión se cerró aquí. Sin conexión, no pudimos confirmar su cierre en el servicio."
	changed.emit()
	return revoked

func clear_session(forget = true):
	user.clear()
	access_token = ""
	refresh_token = ""
	expires_at = 0
	pending_email = ""
	code_sent = false
	refresh_retry_at = 0.0
	_saved_refresh_token = ""
	if forget:
		forget_remembered()
	elif remember_me:
		_persist_remembered()

func _session_helper_path():
	if OS.get_name() != "Windows": return ""
	var executable_dir = OS.get_executable_path().get_base_dir()
	var candidates = [
		executable_dir.path_join("AAMIX.Session.exe"),
		executable_dir.path_join("motor/AAMIX.Session.exe"),
		ProjectSettings.globalize_path("res://../motor/AAMIX.Session.exe")
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate): return candidate
	return ""

func remember_available():
	return not _session_helper_path().is_empty()

func set_remember_me(enabled, email = "", nickname = ""):
	if not bool(enabled):
		forget_remembered()
		return true
	if not remember_available():
		return fail("No pudimos activar Recuérdame en este equipo.")
	remember_me = true
	remembered_email = str(user.get("email", email)).strip_edges().to_lower()
	remembered_name = display_name() if signed_in() else str(nickname).strip_edges()
	_saved_refresh_token = refresh_token
	if not _persist_remembered():
		forget_remembered()
		return fail("No pudimos guardar Recuérdame de forma segura. Puedes ingresar con tu código.")
	return true

func forget_remembered():
	remember_me = false
	remembered_email = ""
	remembered_name = ""
	_saved_refresh_token = ""
	for path in [remembered_session_path, remembered_session_path + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _protect_session(mode, payload):
	var helper = _session_helper_path()
	if helper.is_empty() or payload.size() > 32768: return PackedByteArray()
	# The executable receives only a public operation name as an argument.
	# Sensitive bytes travel through anonymous pipes, never the command line.
	var child = OS.execute_with_pipe(helper, PackedStringArray([mode]), true)
	if child.is_empty(): return PackedByteArray()
	var pipe = child.get("stdio")
	if pipe == null: return PackedByteArray()
	pipe.store_string(Marshalls.raw_to_base64(payload) + "\n")
	pipe.flush()
	var answer = pipe.get_line()
	pipe.close()
	if child.get("stderr") != null: child.stderr.close()
	if not answer.begins_with("OK:"): return PackedByteArray()
	return Marshalls.base64_to_raw(answer.trim_prefix("OK:"))

func _persist_remembered():
	if not remember_me: return false
	var record = {"version":1, "service_url":service_url, "email":remembered_email, "name":remembered_name, "refresh_token":_saved_refresh_token}
	var encrypted = _protect_session("protect", JSON.stringify(record).to_utf8_buffer())
	if encrypted.is_empty():
		storage_error = "No se pudo proteger la sesión."
		return false
	var temporary_path = remembered_session_path + ".tmp"
	var file = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		storage_error = "No se pudo guardar la sesión protegida."
		return false
	file.store_buffer(encrypted)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK: return false
	var result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(remembered_session_path))
	if result != OK:
		storage_error = "No se pudo actualizar la sesión protegida."
		return false
	storage_error = ""
	return true

func _load_remembered():
	if not FileAccess.file_exists(remembered_session_path) or not remember_available(): return false
	var file = FileAccess.open(remembered_session_path, FileAccess.READ)
	if file == null: return false
	if file.get_length() > 32768:
		file.close()
		forget_remembered()
		return false
	var bytes = file.get_buffer(file.get_length())
	file.close()
	var decrypted = _protect_session("unprotect", bytes)
	var record = JSON.parse_string(decrypted.get_string_from_utf8()) if not decrypted.is_empty() else null
	if not record is Dictionary or record.get("version") != 1 or record.get("service_url") != service_url:
		forget_remembered()
		return false
	if not record.get("email") is String or not record.get("name") is String or not record.get("refresh_token") is String:
		forget_remembered()
		return false
	if record.email.length() > 254 or record.name.length() > 24 or record.refresh_token.length() > 4096:
		forget_remembered()
		return false
	remember_me = true
	remembered_email = record.email
	remembered_name = record.name
	_saved_refresh_token = record.refresh_token
	return true

func _restore_remembered():
	changed.emit() # Populate the sign-in fields even when there is no session.
	if not configured or not remember_me or _saved_refresh_token.is_empty() or signed_in() or busy: return false
	refresh_token = _saved_refresh_token
	expires_at = 0
	return await refresh_session()

func send(path, body, bearer = ""):
	if not configured or busy: return {"ok":false, "message":"El servicio de cuentas no está disponible."}
	busy = true
	status = "Conectando…"
	changed.emit()
	var headers = PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key])
	if not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)
	var error = http.request(service_url + "/auth/v1" + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		busy = false
		return {"ok":false, "retryable":true, "message":"No pudimos conectar. Revisa tu conexión e inténtalo otra vez."}
	var completed = await http.request_completed
	busy = false
	if completed[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok":false, "retryable":true, "message":"No pudimos conectar. Revisa tu conexión e inténtalo otra vez."}
	var code = int(completed[1])
	if code == 429: return {"ok":false, "retryable":true, "message":"Se solicitaron demasiados códigos. Espera un momento y vuelve a intentarlo."}
	if code < 200 or code >= 300:
		var message = "El código no es válido o venció. Solicita uno nuevo." if path == "/verify" else "El servicio no pudo completar la solicitud. Revisa el correo e inténtalo más tarde."
		return {"ok":false, "retryable":code >= 500, "status_code":code, "message":message}
	if code == 204: return {"ok":true, "data":{}}
	var json = JSON.new()
	if json.parse(completed[3].get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"ok":false, "retryable":true, "message":"El servicio devolvió una respuesta inesperada. Inténtalo otra vez."}
	return {"ok":true, "data":json.data}
