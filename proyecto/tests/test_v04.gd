extends SceneTree
const CardImage = preload("res://card_image.gd")
const Sound = preload("res://sound.gd")
var ui
var checks = 0
var failures = []
var settings_path = "user://test_v04_audio.cfg"

func check(value, message):
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize(): run.call_deferred()

func nodes_of_type(node, type_name):
	var result = [node] if node.is_class(type_name) else []
	for child in node.get_children(): result.append_array(nodes_of_type(child, type_name))
	return result

func wait_motion():
	var deadline = Time.get_ticks_msec() + 10000
	while (ui.presenting or ui.fx.busy) and Time.get_ticks_msec() < deadline: await process_frame
	check(not ui.presenting and not ui.fx.busy, "Las animaciones devuelven el control con audio habilitado")

func peak(capture):
	var frames = capture.get_buffer(capture.get_frames_available())
	var value = 0.0
	for frame in frames: value = maxf(value, maxf(absf(frame.x), absf(frame.y)))
	return value

func run():
	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	ui.sound.settings_path = settings_path
	ui.sound.set_muted(false)
	ui.sound.set_music_volume(0.55)
	ui.sound.set_effects_volume(0.70)
	await process_frame
	check(ui.sound.music_wanted and ui.sound.music_player.playing, "La pantalla de inicio reproduce música")
	check(ui.sound.music_player.stream.get_length() > 40, "La música tiene un ciclo completo de más de cuarenta segundos")
	check(ui.sound.music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "La música está configurada para repetirse")
	for name in Sound.SOUND_NAMES:
		check(ui.sound.streams[name] != null and ui.sound.streams[name].get_length() > 0.09, "Archivo de sonido disponible: " + name)
	var music_bus = AudioServer.get_bus_index(Sound.MUSIC_BUS)
	var effect_bus = AudioServer.get_bus_index(Sound.EFFECT_BUS)
	# Windows audio startup and menu fade can outlast the first quarter-second.
	# Measure the steady mixer signal after that transition has completed.
	await create_timer(0.65).timeout
	var music_capture = AudioEffectCapture.new()
	var effect_capture = AudioEffectCapture.new()
	music_capture.buffer_length = 0.6
	effect_capture.buffer_length = 0.6
	AudioServer.add_bus_effect(music_bus, music_capture)
	AudioServer.add_bus_effect(effect_bus, effect_capture)
	await create_timer(0.25).timeout
	check(peak(music_capture) > 0.0001, "El mezclador recibe muestras audibles de la música")
	ui.sound.play_effect("robo")
	await create_timer(0.15).timeout
	check(peak(effect_capture) > 0.0001, "El mezclador recibe muestras del sonido de robo")

	ui.show_audio_settings()
	var sliders = nodes_of_type(ui.overlay_shades.back(), "HSlider")
	sliders[0].value = 35
	check(is_equal_approx(ui.sound.music_volume, 0.35) and is_equal_approx(ui.sound.effects_volume, 0.70), "El control de música no cambia el volumen de efectos")
	sliders[1].value = 62
	check(is_equal_approx(ui.sound.effects_volume, 0.62), "El control de efectos actualiza su volumen")
	var mute = nodes_of_type(ui.overlay_shades.back(), "CheckButton")[0]
	mute.button_pressed = true
	check(ui.sound.muted and AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(effect_bus), "Silenciar todo desactiva ambos canales")
	var stored = ConfigFile.new()
	check(stored.load(settings_path) == OK and stored.get_value("audio", "muted") and is_equal_approx(stored.get_value("audio", "music"), 0.35), "Los ajustes se guardan de forma persistente")
	var recovered = Sound.new()
	recovered.settings_path = settings_path
	get_root().add_child(recovered)
	check(recovered.muted and is_equal_approx(recovered.music_volume, 0.35) and is_equal_approx(recovered.effects_volume, 0.62), "Los ajustes se recuperan al abrir una nueva sesión de audio")
	recovered.queue_free()
	await process_frame
	ui.sound.set_muted(false)
	ui.sound.set_music_volume(0)
	check(AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(effect_bus), "Música a cero permite conservar los efectos")
	ui.sound.set_music_volume(0.35)
	ui.close_overlay(ui.overlay_shades.back())
	ui.open_single()
	check(ui.sound.music_wanted and ui.sound.music_player.playing, "La música continúa durante la selección de mazo")
	ui.fx.speed = 0.3
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	await wait_motion()
	check(not ui.sound.music_wanted and not ui.sound.music_player.playing, "La música del menú se desvanece y termina al entrar a jugar")
	check(ui.sound.recent.any(func(e): return e.name == "robo") and ui.sound.recent.any(func(e): return e.name == "barajar"), "El reparto sincroniza sonidos de robo y barajado")
	var hand = ui.targets.filter(func(n): return n.zone == "hand" and n.uid != -1)
	check(hand.size() == 6, "Las seis cartas de la Mano conservan sus superficies de interacción")
	for c in hand:
		check(nodes_of_type(c, "Label").is_empty() and c.get_theme_stylebox("panel").bg_color.a == 0 and c.get_theme_stylebox("panel").border_width_top == 0, "La carta no tiene casilla ni textos duplicados")
	check(hand[0].get_child(0).material is ShaderMaterial, "Las cartas usan el redondeado por shader")
	ui.open_card_detail(hand[0].uid)
	check(ui.modal_open and nodes_of_type(ui.overlay_shades.back(), "RichTextLabel").size() == 1, "El detalle sigue mostrando la habilidad completa")
	ui.close_overlay(ui.overlay_shades.back())
	var before_audio = JSON.stringify([ui.game.players, ui.game.instances, ui.game.rng.state])
	for e in [{"kind":"attack"}, {"kind":"block"}, {"kind":"damage"}, {"kind":"shuffle"}]: ui.sound.play_action(e)
	for e in [{"from":"hand", "to":"defense"}, {"from":"resources", "to":"paid"}, {"from":"deck", "to":"graveyard"}]: ui.sound.play_move(e)
	for name in ["ataque", "bloqueo", "dano", "barajar", "carta", "pago", "descarte"]:
		check(ui.sound.recent.any(func(e): return e.name == name), "Acción con sonido: " + name)
	check(JSON.stringify([ui.game.players, ui.game.instances, ui.game.rng.state]) == before_audio, "El audio no modifica las reglas ni la aleatoriedad")
	ui.sound.set_muted(true)
	var sound_count = ui.sound.recent.size()
	ui.sound.play_effect("ataque")
	check(ui.sound.recent.size() == sound_count, "El silencio también impide efectos nuevos")
	ui.sound.set_muted(false)
	ui.go_home()
	await create_timer(0.15).timeout
	check(ui.sound.music_wanted and ui.sound.music_player.playing, "Volver al inicio recupera la música")
	ui.show_audio_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(arg.trim_prefix("--screenshot="))
	ui.close_overlay(ui.overlay_shades.back())
	if DisplayServer.get_name() != "headless":
		var layer = CanvasLayer.new()
		layer.layer = 250
		get_root().add_child(layer)
		var black = ColorRect.new()
		black.color = Color.BLACK
		black.size = Vector2(200, 200)
		layer.add_child(black)
		var white = Image.create(64, 88, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		var fixture = CardImage.new()
		fixture.texture = ImageTexture.create_from_image(white)
		fixture.position = Vector2(32, 32)
		fixture.size = Vector2(64, 88)
		layer.add_child(fixture)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var frame = get_root().get_texture().get_image()
		var scale = frame.get_width() / get_root().get_visible_rect().size.x
		check(frame.get_pixel(roundi(32 * scale), roundi(32 * scale)).r < 0.7, "El renderizado recorta la esquina exterior de la carta")
		check(frame.get_pixel(roundi(64 * scale), roundi(76 * scale)).r > 0.95, "El redondeado conserva el centro y los colores originales")
		check(frame.get_pixel(roundi(45 * scale), roundi(32.5 * scale)).r > 0.90, "El borde recto entre esquinas conserva la imagen")
		layer.queue_free()
	AudioServer.remove_bus_effect(music_bus, 0)
	AudioServer.remove_bus_effect(effect_bus, 0)
	ui.sound.shutdown()
	await create_timer(0.10).timeout
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(settings_path)
	print(JSON.stringify({"v04_checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
