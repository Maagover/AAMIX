extends SceneTree
var ui
var checks = 0
var failures = []
class FixtureCollection extends "res://collection.gd":
	var requests = []
	var fail_next = false
	var delay = .02
	func request(endpoint,payload):
		requests.append({"endpoint":endpoint,"payload":payload})
		busy = true; changed.emit()
		await get_tree().create_timer(delay).timeout
		busy = false
		if fail_next:
			fail_next = false; changed.emit(); return false
		if endpoint == "aamix_acknowledge_opening": pending_opening = null
		else:
			var normal = endpoint == "aamix_open_normal_pack"
			pending_opening = {"opening_id":str(requests.size()),"kind":"normal_card" if normal else "tc","cards":["0104"] if normal else ["0100","0104","0104","0120","0119"]}
		changed.emit(); return true
func _initialize(): run.call_deferred()
func check(ok,message):
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle():
	for _i in range(8): await process_frame
func find_view(node):
	if node.has_meta("pack_reveal"): return node
	for child in node.get_children():
		var found = find_view(child)
		if found != null: return found
	return null
func cue_count(name): return ui.sound.recent.filter(func(cue):return cue.name == name).size()
func wait_view(view):
	while is_instance_valid(view) and view.animating: await process_frame
	await settle()
func run():
	ui = load("res://main.tscn").instantiate(); root.add_child(ui)
	ui.automation_pause = true; ui.animations_enabled = false
	ui.account.set_process(false); ui.account.configured = false; ui.account.refresh_token = ""
	ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false); ui.social.set_process(false)
	await settle()
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000171"}; ui.account.access_token = "local-fixture-not-a-credential"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600; ui.session_owner = ui.account.player_id(); ui.guest = false
	var previous = ui.collection; previous.changed.disconnect(ui.collection_changed)
	ui.collection = FixtureCollection.new(); ui.collection.account = ui.account; ui.add_child(ui.collection)
	ui.collection.changed.connect(ui.collection_changed); previous.queue_free()
	ui.collection.owner_id = ui.account.player_id(); ui.collection.loaded = true
	ui.collection.packs = 2; ui.collection.normal_packs = 2; ui.collection.restos_welcome_claimed = true; ui.collection.welcome_pack = {"claimed":true}
	ui.sound.muted = false; ui.sound.music_volume = .55; ui.sound.effects_volume = .7; ui.sound.apply_volumes()
	ui.screen = "packs"; ui.render(); await create_timer(.4).timeout
	check(ui.sound.music_player.playing and ui.sound.music_wanted,"Pack list retains menu music before choosing a pack")
	await ui.rewards.start_opening("tc")
	check(ui.sound.pack_suspense and not ui.sound.music_wanted,"TC click starts music suppression immediately")
	check(ui.sound.music_player.playing,"TC request completes while smooth fade is still in progress")
	var view = find_view(ui); var tears = cue_count("sobre_abrir")
	view.open_packet()
	check(view.animating and view.sealed and cue_count("sobre_abrir")==tears,"Fast opening gesture waits for silence before tearing")
	await create_timer(.18).timeout
	check(ui.sound.music_player.volume_db < -10 and ui.sound.music_player.volume_db > -60,"Fade has a gradual intermediate volume")
	ui.render(); await settle(); view = find_view(ui)
	check(ui.sound.pack_suspense and not ui.sound.music_wanted,"Inventory/UI redraw cannot restart music")
	check(view.sealed and not ui.rewards.reveal_open,"Redraw during fade does not commit or replay an abandoned tear")
	view.open_packet(); await create_timer(.4).timeout
	check(not ui.sound.music_player.playing and not view.sealed,"Music fully stops before the wrapper opens")
	check(cue_count("sobre_abrir")==tears+1,"Original wrapper sound plays once after silence")
	await wait_view(view)
	check(view.opening_stage=="cards" and not ui.sound.music_player.playing,"Music stays stopped while showing cards")
	var swipes = cue_count("sobre_carta")
	for _i in range(4): view.slide_card(); await wait_view(view)
	check(cue_count("sobre_carta")==swipes+4,"Every card retains its swipe sound")
	check(view.current.has_meta("singular_highlight") and view.current.material is ShaderMaterial,"Fifth Singular retains its shine")
	check(cue_count("singular")==1 and not ui.sound.music_player.playing,"Singular treasure/victory sound plays alone over stopped music")
	ui.render(); await settle(); view = find_view(ui)
	check(cue_count("singular")==1 and not ui.sound.music_player.playing,"Refreshing a Singular neither repeats its prize sound nor resumes music")
	view.slide_card(); await wait_view(view)
	check(ui.rewards.reveal_index==5 and not ui.sound.music_player.playing,"Summary remains in suspense until Continue")
	await ui.rewards.finish_opening(); await create_timer(.4).timeout
	check(ui.sound.music_wanted and ui.sound.music_player.playing and not ui.sound.pack_suspense,"Continue restores music with fade-in")
	check(ui.collection.requests.size()==2,"Presentation and redraws add no inventory mutations")
	await ui.rewards.start_opening("normal_card"); await create_timer(.55).timeout
	view = find_view(ui); check(view.pack_kind=="normal_card" and not ui.sound.music_player.playing,"Random-card pack also fades music to a complete stop")
	view.open_packet(); await wait_view(view); view.slide_card(); await wait_view(view)
	check(ui.rewards.reveal_index==1 and cue_count("singular")==1,"Random card keeps its normal presentation without Singular prize")
	await ui.rewards.finish_opening(); await create_timer(.4).timeout
	ui.collection.fail_next = true; ui.collection.delay = .1
	await ui.rewards.start_opening("tc"); await create_timer(.55).timeout
	check(ui.sound.music_wanted and ui.sound.music_player.playing,"Failed opening restores music even when the request ID is kept for retry")
	var retry_id = ui.rewards.opening_request
	await ui.rewards.start_opening("tc"); await create_timer(.55).timeout
	check(ui.collection.requests[-1].payload.p_request_id==retry_id and not ui.sound.music_player.playing,"Retry keeps its original idempotency key and suspends music again")
	ui.screen = "home"; ui.render(); await create_timer(.4).timeout
	check(ui.sound.music_player.playing and not ui.sound.pack_suspense,"Leaving an unfinished opening restores home music")
	ui.screen = "packs"; ui.render(); await create_timer(.55).timeout
	check(not ui.sound.music_player.playing and find_view(ui)!=null,"Returning to a pending opening restores suspense")
	ui.screen = "home"; ui.render(); await create_timer(.4).timeout
	ui.screen = "packs"; ui.render(); await create_timer(.1).timeout
	ui.screen = "home"; ui.render(); await create_timer(.6).timeout
	check(ui.sound.music_player.playing and ui.sound.music_player.volume_db > -1,"Leaving during fade cancels its delayed stop callback")
	ui.sound.set_screen("table",false,true)
	check(not ui.sound.music_player.playing,"Victory/Defeat screen still stops music immediately")
	ui.sound.set_screen("table",true,false); await create_timer(.4).timeout
	check(ui.sound.music_track=="challenge" and ui.sound.music_player.playing,"Challenge track resumes normally outside the pack")
	check(ui.sound.music_volume==.55 and ui.sound.effects_volume==.7 and not ui.sound.muted,"Suspense never changes saved volume or mute preferences")
	ui.sound.shutdown(); check(not ui.sound.music_player.playing and not ui.sound.pack_suspense,"Shutdown clears fade and music state")
	ui.queue_free(); await settle()
	print(JSON.stringify({"pack_audio_v171":{"checks":checks,"failures":failures,"network_requests":0,"random_simulations":0,"fixture_only":true}}))
	quit(0 if failures.is_empty() else 1)
