extends SceneTree
const Game = preload("res://game.gd")
var ui
var checks = 0
var failures = []
var capture_dir = ""
var captures = []

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): capture_dir = arg.trim_prefix("--screenshots=")
	run.call_deferred()
func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)
func all_nodes(node):
	var result = [node]
	for child in node.get_children(): result.append_array(all_nodes(child))
	return result
func labels(): return all_nodes(ui).filter(func(node):return node is Label).map(func(node):return node.text)
func buttons(value): return all_nodes(ui).filter(func(node):return node is Button and node.text == value)
func add(g,p,code,zone):
	var uid = g.spawn(code,p)
	g.players[p][zone].append(uid)
	g.instances[uid].entered = 1
	return uid
func fresh():
	var g = Game.new()
	for p in range(2):
		var player = {"name":"Prueba","deck_id":"fixture"}
		for zone in g.ZONES: player[zone] = []
		g.players.append(player)
		for _i in range(12): add(g,p,"0100","deck")
		for _i in range(3): add(g,p,"0100","resources")
	g.active = 0
	g.actor = 0
	g.turn = 5
	g.phase = "main"
	g.manual_payment = [true,false]
	return g
func settle():
	for _i in range(8): await process_frame
func capture(name):
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var destination = capture_dir.path_join(name+".png")
	if root.get_texture().get_image().save_png(destination) == OK: captures.append(destination)
	else: failures.append("No se pudo guardar captura: "+name)
func run():
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	ui.account.set_process(false)
	ui.account.configured = false
	ui.account.remember_me = false
	ui.account.refresh_token = ""
	ui.online.set_process(false)
	ui.online.realtime.set_process(false)
	ui.rewards.set_process(false)
	ui.game = fresh()
	ui.started = true
	ui.human = 0
	ui.computer = 1
	ui.screen = "table"
	var viborin = add(ui.game,0,"0126","defense")
	var other = add(ui.game,0,"0106","defense")
	ui.game.activate(viborin)
	ui.render()
	await settle()
	check(labels().any(func(text):return text.contains("Si Viborín sigue en juego")) and not labels().has("La carta buscada se mostrará en el registro.") and buttons("Omitir / cancelar").size() == 1,"Elección de Viborín explica sacrificio y cancelación sin texto de búsqueda")
	await capture("01-viborin-eleccion")
	ui.game.skip_choice()
	ui.game = fresh()
	var almenta = add(ui.game,0,"0129","defense")
	other = add(ui.game,0,"01e","defense")
	ui.game.activate(almenta)
	ui.render()
	await settle()
	check(labels().any(func(text):return text.contains("Al confirmar, paga 1 Recurso")) and labels().any(func(text):return text.contains("Cancelar conserva el uso")),"Almenta informa coste y cancelación antes de elegir")
	ui.game.choose([other])
	ui.render()
	await settle()
	var highlighted = all_nodes(ui).filter(func(node):return node.get_meta("ability_payment_target",false))
	check(highlighted.size() == 1 and highlighted[0].uid == other and highlighted[0].get_meta("persistent_selected",false),"Objetivo de Almenta permanece resaltado durante el pago manual")
	check(buttons("Cancelar habilidad").size() == 1 and labels().any(func(text):return text.contains("Almenta → Dragón") and text.contains("activar la habilidad")),"Pago manual se describe como habilidad sobre objetivo, no como jugar Almenta")
	await capture("02-almenta-pago")
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000130"}
	ui.account.access_token = "local-fixture-not-a-credential"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.session_owner = ui.account.player_id()
	ui.screen = "multiplayer"
	ui.online.receive({"room_id":"old-fixture","status":"playing","ruleset_version":"1.2"})
	ui.render()
	await settle()
	check(buttons("Cerrar sala anterior").size() == 1 and buttons("Crear sala").is_empty() and buttons("Volver a la partida").is_empty(),"Sala incompatible ofrece cierre sin permitir restaurarla como partida")
	ui.online_ui.confirm_incompatible_leave()
	await settle()
	check(buttons("Abandonar y cerrar").size() == 1 and labels().has("Abandonar la partida en curso se contará como derrota."),"Cierre de sala antigua en curso requiere confirmación explícita")
	print(JSON.stringify({"cards_ui_v130":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
