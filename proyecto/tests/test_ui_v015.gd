extends SceneTree
## Focused release checks against an isolated loopback fixture; no real accounts.
var ui
var checks = 0
var failures = []
var fixture_url = ""
var screenshot_path = ""
var starts = []
var resume_checks = false
var executed_checks = 0

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg == "--resume-v015": resume_checks = true
		if arg.begins_with("--auth-test-url="): fixture_url = arg.trim_prefix("--auth-test-url=")
		if arg.begins_with("--screenshots="): screenshot_path = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, message):
	checks += 1
	# A repair pass resumes only the failed assertion and unexecuted result flow.
	if resume_checks and checks < 51 and checks != 27: return
	executed_checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ",message)

func find_text(node,value):
	if (node is Label or node is Button) and node.text == value: return node
	for child in node.get_children():
		var found = find_text(child,value)
		if found != null: return found
	return null

func meta(node,key,value=null):
	if node.has_meta(key) and (value == null or node.get_meta(key) == value): return node
	for child in node.get_children():
		var found = meta(child,key,value)
		if found != null: return found
	return null

func texts(node):
	var result = []
	if node is Label or node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(texts(child))
	return result

func buttons(node):
	var result = []
	if node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(buttons(child))
	return result

func settle():
	for _i in range(8): await process_frame

func wait_network():
	var deadline = Time.get_ticks_msec()+15000
	await settle()
	while (ui.account.busy or ui.collection.busy or ui.rewards.pumping or ui.welcome_loading) and Time.get_ticks_msec()<deadline: await process_frame
	await settle()

func total_cards():
	return ui.collection.cards.values().reduce(func(total,n): return total+int(n),0)

func shot(name):
	if screenshot_path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(screenshot_path)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot_path.path_join(name+".png"))

func dismiss():
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())

func finish(victory):
	ui.automation_pause=true
	ui.game.pending={}
	ui.game.winner=ui.human if victory else ui.computer
	ui.game.phase="finished"
	ui.render()
	await settle()

func run():
	if not fixture_url.begins_with("http://127.0.0.1:"): quit(1);return
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause=true
	ui.match_started.connect(func(deck,stage): starts.append([deck,stage]))
	await settle()
	var intro=meta(ui,"intro")
	check(ui.screen=="intro" and intro!=null,"Intro is the initial screen")
	check(buttons(intro).is_empty() and intro.prompt.text=="Haz click para jugar","Intro prompt is plain text")
	check(intro.logo.modulate.a<.5,"Logo starts transparent during fade")
	check(ui.sound.music_player.stream is AudioStreamMP3 and ui.sound.music_player.stream.loop,"Supplied menu MP3 loops from intro")
	await create_timer(2.85).timeout
	check(intro.logo.modulate.a>.99 and intro.prompt.modulate.a>.99,"Intro fade completes in 2–3 seconds")
	await shot("01-intro")
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=Vector2(50,50)
	intro._gui_input(click)
	ui.animations_enabled=false
	await settle()
	check(ui.screen=="home" and ui.guest,"Click anywhere opens home")
	var identity=meta(ui,"home_account")
	check(identity.flat and identity.get_theme_stylebox("normal") is StyleBoxEmpty,"Profile has no button background")
	check(find_text(identity,"Invitado").get_theme_color("font_color")==Color("fffaf0"),"Profile name is light")
	var gift=meta(ui,"ui_icon","gift")
	check(gift!=null and gift.get_parent().get_parent().size.y<=43,"Small gift action uses palette icon")
	check(find_text(ui,"Configuración").size.y<=43,"Settings action is compact")
	var pack=meta(ui,"decorative_pack")
	var logo=meta(ui,"home_logo")
	check(pack.get_index()<meta(ui,"decorative_card","0119").get_index() and logo.get_index()>meta(ui,"decorative_card","0100").get_index(),"Home layers are pack, cards, logo")
	await shot("02-inicio")
	ui.open_single()
	await settle()
	var random_button=find_text(ui,"Partida Aleatoria")
	var challenge_button=find_text(ui,"Desafío AAMIX")
	check(random_button.global_position.x<challenge_button.global_position.x and absf(random_button.global_position.y-challenge_button.global_position.y)<2,"Single modes are horizontal, random left")
	check(meta(ui,"ui_icon","dice").global_position.y<random_button.global_position.y and meta(ui,"ui_icon","swords").global_position.y<challenge_button.global_position.y,"Mode icons appear above buttons")
	check(find_text(ui,"Volver").global_position.y>random_button.global_position.y,"Centered back action is below both modes")
	await shot("03-individual")
	ui.open_random()
	ui.start_match(0)
	await settle()
	check(ui.screen=="versus" and not ui.started and starts.is_empty(),"Random match waits at confirmation without starting")
	var prepared=ui.pending_match.opponent.id
	check(find_text(ui,"Partida Aleatoria: "+ui.pending_match.opponent.nombre)!=null and find_text(ui,"Comenzar")!=null,"Random preview names actual opponent")
	await shot("04-combate-aleatorio")
	find_text(ui,"Volver").pressed.emit()
	await settle()
	check(not ui.started and starts.is_empty(),"Cancel preview has no match or receipt")
	ui.start_match(0)
	prepared=ui.pending_match.opponent.id
	ui.begin_prepared_match()
	ui.automation_pause=true
	await settle()
	check(ui.started and ui.last_opponent_deck.id==prepared and starts.size()==1,"Confirm starts exactly the previewed random rival")
	check(ui.sound.music_track=="random","Random battle keeps its battle track")
	await finish(false)
	dismiss()
	ui.go_home()
	ui.account.configure(fixture_url,"sb_publishable_contract_fixture",true)
	await ui.account.request_code("v015@fixture.invalid","Prueba AAMIX",true)
	await ui.account.verify_code("123456")
	await wait_network()
	check(ui.collection.loaded and ui.collection.packs==1,"New account automatically receives one TC pack")
	check(ui.collection.gift==null and ui.collection.decks.is_empty() and total_cards()==0,"Login grants no starter deck")
	check(ui.screen=="home" and find_text(ui,"Abrir mi sobre")!=null,"Welcome pack popup opens from home")
	await shot("05-bienvenida")
	find_text(ui,"Abrir mi sobre").pressed.emit()
	await settle()
	check(ui.screen=="packs" and not ui.modal_open,"Welcome action opens packs directly")
	await ui.collection.claim_welcome_pack()
	await wait_network()
	check(ui.collection.packs==1 and find_text(ui,"¡Tu primer sobre TC!")==null,"Welcome retry never duplicates pack or popup")
	ui.open_collection()
	await settle()
	check(ui.screen=="cards" and find_text(ui,"Elegir mazo")==null,"Collection is accessible before starter choice")
	ui.rewards.open_screen("packs")
	await settle()
	var tile=meta(ui,"pack_expansion")
	check(tile is Button and absf(tile.size.x-tile.size.y)<2,"Available pack is a square clickable tile")
	check(absf(tile.get_global_rect().get_center().x-ui.size.x*.5)<3,"Pack tile is horizontally centered")
	check(find_text(tile,"Transmisión Caída")!=null and find_text(tile,"Cantidad: 1")!=null and find_text(ui,"Abrir un sobre")==null,"Pack tile contains cover, expansion and count without extra action")
	await shot("06-mis-sobres")
	tile.pressed.emit()
	await wait_network()
	var request_id=ui.rewards.opening_request
	check(ui.collection.pending_opening==null and not request_id.is_empty(),"Lost opening response preserves request ID")
	await ui.rewards.start_opening()
	await wait_network()
	check(ui.collection.pending_opening is Dictionary and ui.collection.packs==0 and total_cards()==5,"Retry opens exactly one pack with five cards")
	var reveal=meta(ui,"pack_reveal")
	check(reveal.sealed and reveal.layers.get_children().all(func(card):return not card.visible),"Sealed packet hides every card")
	reveal.open_packet()
	await create_timer(.3).timeout
	check(reveal.opening_stage=="opened" and reveal.packet_opened_art.modulate.a>.99,"Torn packet remains visible after transition")
	await shot("07-sobre-roto")
	await create_timer(.75).timeout
	check(reveal.opening_stage=="opened","Opened wrapper holds over one extra second")
	await create_timer(.65).timeout
	await settle()
	check(reveal.layers.get_children().filter(func(card):return card.visible).size()==1,"Only current front card is visible")
	check(reveal.layers.get_children().all(func(card):return card.position==reveal.origin and card.rotation==0),"All future cards share exact origin without tilt or edges")
	var motion=InputEventMouseMotion.new()
	motion.relative=Vector2(50,0)
	reveal.dragging=true
	reveal._gui_input(motion)
	reveal.dragging=false
	check(reveal.current.rotation==0 and reveal.layers.get_children().filter(func(card):return card.visible).size()==1,"Dragging cannot reveal future card borders")
	await shot("08-carta-frontal")
	for _i in range(4):
		await reveal.slide_card()
		await settle()
	check(reveal.revealed==4 and reveal.current.has_meta("singular_highlight"),"Fifth Singular still receives its shine")
	check(ui.rewards.singular_seen_openings.has(reveal.opening_id),"Singular arrival is remembered once per opening")
	await shot("09-singular")
	await reveal.slide_card()
	await settle()
	check(find_text(ui,"¡Cinco cartas para tu colección!")!=null,"Last slide reaches five-card summary")
	check(not "\n".join(texts(ui)).contains("aunque cierres el juego"),"Redundant saved-card messages are removed")
	await ui.rewards.finish_opening()
	await ui.rewards.finish_opening()
	await wait_network()
	check(ui.collection.pending_opening==null and total_cards()==5,"Acknowledgement retry retains five cards exactly")
	check(meta(ui,"pack_expansion")==null and find_text(ui,"Cantidad: 0")==null,"Zero packs display no expansion tile or zero quantity")
	await shot("10-sin-sobres")
	await ui.open_challenges()
	await wait_network()
	check(ui.screen=="gift" and ui.collection.welcome_pack.challenge_entered,"Starter selection appears only after entering challenge")
	check(find_text(ui,"Tu mazo para el Desafío AAMIX")!=null and ui.collection.gift==null,"Challenge offers original starter choices without auto-selecting")
	await shot("11-mazo-inicial")
	ui.confirm_gift(ui.game.decklists[0])
	find_text(ui,"Confirmar mi regalo").pressed.emit()
	await wait_network()
	check(ui.collection.gift!=null and ui.collection.decks.size()==1 and total_cards()==45,"Starter grants exactly 40 additional cards")
	check(ui.screen=="challenges" and meta(ui,"reward_icon")!=null,"Starter reward uses deck cover then returns to levels")
	dismiss()
	await settle()
	var levels=meta(ui,"challenge_stages")
	check(levels.get_child_count()==2 and meta(levels,"challenge_stage",1)!=null and meta(levels,"challenge_stage",2)!=null,"Only current level and next locked level are shown")
	check(find_text(levels,"Mazo Papito")!=null and find_text(levels,"Mazo Flaan")==null and meta(levels,"ui_icon","lock")!=null,"Locked level hides next deck behind padlock")
	check(find_text(levels,"Recompensa: 1 sobre TC")!=null and find_text(levels,"Etapa 1")==null,"Levels identify TC reward and use Nivel wording")
	await shot("12-desafio")
	ui.choose_challenge(1)
	ui.start_match(0)
	await settle()
	check(ui.screen=="versus" and find_text(ui,"Nivel 1: Mazo Papito")!=null and starts.size()==1,"Challenge also requires combat confirmation")
	await shot("13-confirmacion-nivel")
	ui.begin_prepared_match()
	ui.automation_pause=true
	await wait_network()
	check(ui.active_challenge_stage==1 and ui.last_opponent_deck.id=="papito" and ui.sound.music_track=="challenge","Challenge starts correct rival with new battle music")
	await finish(false)
	check(buttons(ui.overlay_shades.back())==["Revancha","Volver"],"Challenge defeat has only Rematch and Back")
	await shot("14-derrota")
	find_text(ui.overlay_shades.back(),"Revancha").pressed.emit()
	await settle()
	check(ui.screen=="versus" and ui.pending_match.opponent.id=="papito","Rematch returns to confirmation with same rival")
	ui.begin_prepared_match()
	ui.automation_pause=true
	await wait_network()
	await finish(true)
	check(buttons(ui.overlay_shades.back())==["Siguiente"],"Challenge victory has only Next")
	await wait_network()
	check(find_text(ui,"¡Desafío superado!")==null,"Challenge reward waits until levels screen")
	await shot("15-victoria")
	ui.collection.busy=true
	find_text(ui.overlay_shades.back(),"Siguiente").pressed.emit()
	check(ui.screen=="challenges","Next returns immediately even while inventory is busy")
	ui.collection.busy=false
	await wait_network()
	check(find_text(ui,"¡Desafío superado!")!=null and ui.collection.packs==1,"Victory reward appears on levels with one pack")
	await shot("16-premio-nivel")
	dismiss()
	levels=meta(ui,"challenge_stages")
	check(find_text(meta(levels,"challenge_stage",1),"Completado")!=null and not "\n".join(texts(meta(levels,"challenge_stage",1))).contains("Recompensa"),"Completed level shows no reward or prize-received text")
	check(levels.get_child_count()==3 and find_text(levels,"Mazo Flaan")!=null and find_text(levels,"Mazo Kajido")==null,"Progress reveals Flaan and only the next hidden level")
	await shot("17-nivel-desbloqueado")
	ui.rewards.open_screen("missions")
	await wait_network()
	check(meta(ui,"reload")!=null and meta(ui,"reload").text.is_empty() and meta(ui,"ui_icon","reload")!=null and find_text(ui,"Actualizar")==null,"Refresh action is PNG icon instead of text")
	check(ui.sound.music_track=="menu" and ui.sound.music_player.stream is AudioStreamMP3,"Leaving challenge restores supplied menu track")
	var position=ui.sound.music_player.get_playback_position()
	ui.render()
	await settle()
	check(ui.sound.music_player.get_playback_position()>=position,"Ordinary renders do not restart menu music")
	print(JSON.stringify({"ui_v015_checks":checks,"executed_checks":executed_checks,"resume_checks":resume_checks,"failures":failures,"real_emails_sent":0,"real_rewards_claimed":0,"fixture_only":true}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
