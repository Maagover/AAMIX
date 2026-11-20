extends Node
## Local audio, independent of game rules and hidden card identities.
const SOUND_NAMES = ["robo", "carta", "pago", "ataque", "bloqueo", "descarte", "barajar", "dano", "interfaz", "regalo", "regalo_recibido", "victoria", "derrota", "turno", "sobre_abrir", "sobre_carta", "popup", "singular"]
const MUSIC_BUS = "AAMIX Musica"
const EFFECT_BUS = "AAMIX Efectos"
var settings_path = "user://audio.cfg"
var music_volume = 0.55
var effects_volume = 0.70
var muted = false
var music_wanted = false
var music_player: AudioStreamPlayer
var voices = []
var streams = {}
var recent = []
var last_play = {}
var next_voice = 0
var fade: Tween
var music_streams = {}
var music_track = ""
var pack_suspense = false
var halloween_menu = false
var halloween_battle = false
const PACK_FADE_SECONDS = 0.5

func _ready():
	for bus in [MUSIC_BUS, EFFECT_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var config = ConfigFile.new()
	if config.load(settings_path) == OK:
		var stored_music = config.get_value("audio", "music", music_volume)
		var stored_effects = config.get_value("audio", "effects", effects_volume)
		if typeof(stored_music) in [TYPE_FLOAT, TYPE_INT]: music_volume = clampf(stored_music, 0.0, 1.0)
		if typeof(stored_effects) in [TYPE_FLOAT, TYPE_INT]: effects_volume = clampf(stored_effects, 0.0, 1.0)
		muted = config.get_value("audio", "muted", false) == true
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	music_player.volume_db = -60.0
	var menu = AudioStreamMP3.new()
	menu.data = FileAccess.get_file_as_bytes("res://audio/menu_arcade_coins.mp3")
	menu.loop = true
	music_streams["menu"] = menu
	for track in ["random","challenge"]:
		var stream = AudioStreamWAV.load_from_file("res://audio/combate_desafio.wav" if track == "challenge" else "res://audio/batalla.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		music_streams[track] = stream
	var halloween=AudioStreamWAV.load_from_file("res://audio/halloween_preview.wav")
	halloween.loop_mode=AudioStreamWAV.LOOP_FORWARD
	halloween.loop_begin=0;halloween.loop_end=roundi(halloween.get_length()*halloween.mix_rate)
	music_streams["halloween"]=halloween
	add_child(music_player)
	for name in SOUND_NAMES:
		var filename = "sobre_rasgar" if name == "sobre_abrir" else name
		streams[name] = AudioStreamWAV.load_from_file("res://audio/" + filename + ".wav")
	for i in range(10):
		var voice = AudioStreamPlayer.new()
		voice.bus = EFFECT_BUS
		voice.max_polyphony = 1
		add_child(voice)
		voices.append(voice)
	apply_volumes()

func apply_volumes():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(EFFECT_BUS), linear_to_db(maxf(effects_volume, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), muted or music_volume == 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(EFFECT_BUS), muted or effects_volume == 0)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "muted", muted)
	config.save(settings_path)

func set_music_volume(value):
	music_volume = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()

func set_effects_volume(value):
	effects_volume = clampf(value, 0.0, 1.0)
	apply_volumes()
	save_settings()

func set_muted(value):
	muted = value
	apply_volumes()
	save_settings()

func set_screen(screen, challenge = false, result_visible = false, opening_pack = false):
	var wanted = screen != "quitting" and not result_visible and not opening_pack
	var track = ("challenge" if challenge else "random") if screen == "table" else "menu"
	if halloween_menu and screen!="table":track="halloween"
	if music_wanted == wanted and music_track == track and pack_suspense == opening_pack: return
	music_wanted = wanted
	pack_suspense = opening_pack
	if fade != null and fade.is_valid(): fade.kill()
	if not wanted:
		if opening_pack and music_player.playing:
			fade = create_tween()
			fade.tween_property(music_player,"volume_db",-60.0,PACK_FADE_SECONDS)
			fade.tween_callback(music_player.stop)
		else:
			music_player.stop()
		return
	if music_track != track:
		music_player.stop()
		music_track = track
		music_player.stream = music_streams[track]
		music_player.volume_db = -30
	if not music_player.playing: music_player.play()
	fade = create_tween()
	fade.tween_property(music_player,"volume_db",0.0,.35)

func wait_for_pack_silence():
	# The wrapper cannot tear before the fade finishes, even on a fast response.
	while pack_suspense and music_player.playing:
		await get_tree().process_frame

func play_effect(name):
	if muted or effects_volume <= 0 or not streams.has(name) or streams[name] == null: return
	var now = Time.get_ticks_msec()
	# Prevent a large, simultaneous batch from becoming a loud stack of sounds.
	if now - int(last_play.get(name, -1000)) < 35: return
	last_play[name] = now
	var voice = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = streams[name]
	voice.play()
	recent.append({"name":name, "time":now})
	if recent.size() > 200: recent.pop_front()

func play_move(event):
	if event.to == "graveyard" or event.to == "burned": play_effect("descarte")
	elif event.from == "deck" and event.to == "hand": play_effect("robo")
	elif event.to == "paid": play_effect("pago")
	else: play_effect("carta")

func play_action(event):
	var names = {"attack":"ataque", "block":"bloqueo", "shuffle":"barajar", "reorder":"barajar", "damage":"dano"}
	if names.has(event.kind): play_effect(names[event.kind])

func play_packet(packet):
	for event in packet:
		if event.kind == "move": play_move(event)
		else: play_action(event)

func stop_effects():
	for voice in voices: voice.stop()
	last_play.clear()

func shutdown():
	music_wanted = false
	pack_suspense = false
	if fade != null and fade.is_valid(): fade.kill()
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	streams.clear()

func _exit_tree():
	shutdown()
