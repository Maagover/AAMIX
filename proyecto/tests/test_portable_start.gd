extends SceneTree
var ui
var checks = 0
var failures = []
func _initialize(): run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok: failures.append(message)
func settle():
	for _i in range(8): await process_frame
func run():
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	await settle()
	check(ui.screen=="intro" and not ui.account.signed_in(),"Fresh portable opens intro without a session")
	check(ui.sound.music_player.stream is AudioStreamMP3 and ui.sound.music_player.stream.loop,"Supplied menu music loads and loops without import cache")
	ui.play_guest()
	await settle()
	check(ui.screen=="home" and ui.guest,"Intro can continue to guest home")
	ui.open_random()
	ui.start_match(0)
	await settle()
	check(ui.screen=="versus" and not ui.started,"Portable match waits for confirmation")
	ui.begin_prepared_match()
	ui.automation_pause=true
	await create_timer(.3).timeout
	check(ui.started and ui.game.invariant_errors().is_empty(),"Confirmed guest match starts with valid game state")
	check(ui.texture_code("0105")!=null and ui.asset_texture("dorso.jpg")!=null and ui.RestosArt.texture()!=null and ui.rewards.NormalPackArt.texture(false)!=null and ui.rewards.NormalPackArt.texture(true)!=null and ui.sound.music_streams.challenge!=null,"Original art, Restos, both brown wrappers and challenge music load")
	print(JSON.stringify({"portable_v018_checks":checks,"failures":failures,"portable_access_and_guest_match":failures.is_empty(),"engine":Engine.get_version_info().string}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
