extends "res://tests/test_v05.gd"
const AccountClient = preload("res://account.gd")
var fixture_url = ""

func wait_request(client):
	var deadline = Time.get_ticks_msec() + 18000
	while client.busy and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not client.busy, "Las solicitudes terminan sin bloquear la interfaz")

func field(node, placeholder):
	if node is LineEdit and node.placeholder_text == placeholder: return node
	for child in node.get_children():
		var result = field(child, placeholder)
		if result != null: return result
	return null

func write_field(placeholder, value):
	var input = field(ui, placeholder)
	input.text = value
	input.text_changed.emit(value)

func account_shot(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--account-screenshots=") and DisplayServer.get_name() != "headless":
			var path = arg.trim_prefix("--account-screenshots=")
			DirAccess.make_dir_recursive_absolute(path)
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(path.path_join(name + ".png"))

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--auth-test-url="): fixture_url = arg.trim_prefix("--auth-test-url=")
	if not fixture_url.begins_with("http://127.0.0.1:"):
		push_error("Ejecuta esta prueba mediante herramientas/probar_cuentas.py; sólo usa HTTP local.")
		quit(1)
		return
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	await settle()
	var a = ui.account
	# Keep the disconnected-state regression independent of the shipped live config.
	a.configure("", "")
	check(not a.configured and a.player_id().is_empty() and not a.signed_in(), "Sin servicio conectado no se genera un ID local ni se simula una cuenta")
	check(find_button(ui, "Jugar como invitado") != null and find_button(ui, "Enviar código") != null, "El acceso inicial ofrece ingreso e invitado")
	await account_shot("01-inicio")
	ui.open_account()
	await settle()
	check(find_button(ui, "Enviar código").disabled, "La pantalla explica el estado pendiente y no envía correos sin configuración")
	await account_shot("17-mi-cuenta-pendiente")
	check(not a.configure("http://example.com", "sb_publishable_fixture"), "Se exige HTTPS para los servicios remotos")
	check(not a.configure("https://example.com", "sb_secret_do_not_ship"), "El cliente rechaza claves secretas")
	check(not a.configure("https://example.com/path", "sb_publishable_fixture"), "La URL del servicio no acepta rutas añadidas")
	check(not a.configure("https://example.com", "sb_publishable_x\r\nx:y"), "La configuración rechaza cabeceras inyectadas")
	check(a.configure(fixture_url, "sb_publishable_contract_fixture", true), "Sólo la prueba habilita el servidor HTTP en loopback")
	check(not await a.request_code("sin-arroba", "Amix", true) and a.player_id().is_empty(), "Un correo inválido se rechaza antes de contactar al servicio")
	check(not await a.request_code("a@fixture.invalid", "A", true), "Crear una cuenta exige un nombre visible válido")
	ui.account_mode(true)
	write_field("Cómo te verán tus amigos", "Amix")
	write_field("tu@correo.com", "  A@fixture.invalid  ")
	await click(find_button(ui, "Enviar código"))
	await wait_request(a)
	check(a.code_sent and a.pending_email == "a@fixture.invalid" and not a.signed_in(), "El envío normaliza el correo y espera verificación, sin conceder una sesión")
	check(not await a.request_code("a@fixture.invalid", "Amix", true) and a.status.contains("Espera"), "El reenvío respeta la espera local entre códigos")
	check(not await a.verify_code("000000") and not a.signed_in(), "Un código rechazado o vencido no crea una sesión")
	write_field("Código del correo", "123456")
	await click(find_button(ui, "Verificar e ingresar"))
	await wait_request(a)
	var first_id = a.player_id()
	check(a.signed_in() and first_id.length() == 36 and a.display_name() == "Amix", "La verificación por el botón usa el código escrito y el ID emitido por el servidor")
	if not a.signed_in():
		print(JSON.stringify({"account_checks":checks, "failures":failures, "status":a.status}))
		quit(1)
		return
	check(ui.account_code.is_empty() and ui.account_email.is_empty(), "Tras ingresar se limpian los campos de correo y código")
	ui.open_account()
	await settle()
	check(find_meta(ui, "player_id").text == first_id, "La cuenta muestra el ID completo, sin truncarlo")
	if DisplayServer.get_name() != "headless":
		await click(find_button(ui, "Copiar ID"))
		check(DisplayServer.clipboard_get() == first_id, "Copiar ID coloca la identidad completa en el portapapeles")
	var second_device = AccountClient.new()
	get_root().add_child(second_device)
	second_device.configure(fixture_url, "sb_publishable_contract_fixture", true)
	check(await second_device.request_code("a@fixture.invalid", "", false) and await second_device.verify_code("123456"), "Otro cliente puede ingresar a la misma cuenta")
	check(second_device.player_id() == first_id, "El ID se conserva en un segundo cliente, sin copiar archivos locales")
	var other = AccountClient.new()
	get_root().add_child(other)
	other.configure(fixture_url, "sb_publishable_contract_fixture", true)
	check(await other.request_code("b@fixture.invalid", "Amix", true) and await other.verify_code("123456"), "Otra cuenta puede usar el mismo nombre visible")
	check(other.player_id() != first_id and other.display_name() == a.display_name(), "La identidad depende del ID del servidor, no del nombre visible")
	var refresh_before = a.refresh_token
	check(await a.refresh_session() and a.player_id() == first_id and refresh_before != a.refresh_token, "Renovar la sesión conserva el ID y reemplaza el token de renovación")
	a.refresh_token = "fixture-expired"
	check(not await a.refresh_session() and a.player_id().is_empty() and a.access_token.is_empty(), "Una renovación rechazada limpia la sesión y permite volver a ingresar")
	check(await second_device.sign_out() and second_device.user.is_empty() and second_device.refresh_token.is_empty(), "Cerrar sesión solicita revocación y elimina sus credenciales de memoria")
	other.service_url = fixture_url + "/not-found"
	check(not await other.sign_out() and not other.signed_in() and other.refresh_token.is_empty(), "El cierre local se completa también si la revocación remota falla")
	a.resend_at = 0
	check(not await a.request_code("rate@fixture.invalid", "Amix", true) and a.status.contains("demasiados"), "El límite del servicio se muestra sin exponer su respuesta interna")
	a.resend_at = 0
	check(await a.request_code("malformed@fixture.invalid", "Amix", true) and not await a.verify_code("123456") and a.player_id().is_empty(), "Una respuesta incompleta del servidor nunca se acepta como sesión")
	ui.go_home()
	ui.animations_enabled = false
	ui.play_guest()
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	var preserved = JSON.stringify([ui.game.players, ui.game.instances, ui.game.phase, ui.game.rng.state])
	ui.go_home()
	ui.open_account()
	ui.go_home()
	ui.open_single()
	await settle()
	check(ui.screen == "table" and JSON.stringify([ui.game.players, ui.game.instances, ui.game.phase, ui.game.rng.state]) == preserved, "Consultar Mi cuenta conserva la partida individual en curso")
	check(not ui.game.log_lines.any(func(line): return line.contains("fixture.invalid") or line.contains("fixture-access")), "El registro de la partida no recibe correos ni credenciales")
	second_device.queue_free()
	other.queue_free()
	print(JSON.stringify({"account_checks":checks, "failures":failures, "live_service_tested":false}))
	ui.sound.shutdown()
	await create_timer(0.1).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
