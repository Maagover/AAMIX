extends SceneTree
## Visual acceptance of the requested screens, using in-memory account data only.
var ui
var checks = 0
var failures = []
var screenshots = ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): screenshots = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok:
		failures.append(caption)
		printerr("FAIL: ",caption)

func find_text(node, caption):
	if (node is Label or node is Button) and node.text == caption: return node
	for child in node.get_children():
		var result = find_text(child, caption)
		if result != null: return result
	return null

func find_meta(node, key):
	if node.has_meta(key): return node
	for child in node.get_children():
		var result = find_meta(child,key)
		if result != null: return result
	return null

func collection_slot(node, code):
	if node.get_meta("collection_code", "") == code: return node
	for child in node.get_children():
		var result = collection_slot(child, code)
		if result != null: return result
	return null

func settle():
	for i in range(8): await process_frame

func contrast(front, back):
	var f = front.srgb_to_linear()
	var b = back.srgb_to_linear()
	var first = f.r * 0.2126 + f.g * 0.7152 + f.b * 0.0722
	var second = b.r * 0.2126 + b.g * 0.7152 + b.b * 0.0722
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)

func shot(name):
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshots.path_join(name+".png"))

func run():
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause = true
	ui.animations_enabled = false
	ui.rewards.set_process(false)
	ui.account.user = {"id":"v013-ui-fixture","email":"fixture@example.invalid","user_metadata":{"display_name":"Jugador de prueba"}}
	ui.account.access_token = "memory-only-fixture"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.collection.owner_id = "v013-ui-fixture"
	ui.collection.loaded = true
	ui.collection.gift = {"deck_id":"kajido"}
	ui.collection.profile = {"avatar_code":"0108"}
	ui.collection.decks = ui.game.decklists.duplicate(true)
	for code in ui.game.catalog: ui.collection.cards[code] = 1
	ui.screen = "home"
	ui.render()
	await settle()
	var home
	for node in ui.find_children("*","Control",true,false):
		if node.get_script() == load("res://home_cards.gd"): home = node
	check(home != null,"Home artwork exists")
	check(home.floating_cards.size() == 3,"Two printed cards and sealed pack float together")
	check(home.floating_cards[0].get_meta("decorative_card") == "0119" and home.floating_cards[1].get_meta("decorative_card") == "0100","Transmission and Restos fronts")
	check(home.closed_pack.get_meta("decorative_pack", false) and home.closed_pack.texture != null,"Provided sealed-pack artwork appears behind logo")
	check(home.logo.get_index() > home.featured.get_index(),"Logo draws in front of both cards")
	var rotation = home.featured.rotation
	var resource_rotation = home.floating_cards[1].rotation
	var logo_rotation = home.logo.rotation
	var logo_position = home.logo.position
	var card_position = home.featured.position
	home.clock = 3
	home.update_cards()
	check(home.featured.rotation == rotation and home.featured.scale == Vector2.ONE,"No card spin or face flipping")
	check(home.floating_cards[1].rotation == resource_rotation and home.logo.rotation == logo_rotation,"Restos and logo never spin")
	check(home.logo.position != logo_position,"Logo floats gently")
	check(home.logo.position.distance_to(logo_position) < home.featured.position.distance_to(card_position),"Logo motion is subtler than card motion")
	check(home.featured.size.x > 175 and home.floating_cards[1].size.x > 164,"Both home cards are larger than 0.11")
	var first_center = home.featured.get_meta("rest_position") + home.featured.size * 0.5
	var second_center = home.floating_cards[1].get_meta("rest_position") + home.floating_cards[1].size * 0.5
	check(first_center.distance_to(second_center) < 268,"Home cards are closer together than 0.11")
	check(home.global_position.x > find_text(ui,"Partida individual").global_position.x,"Logo artwork is right of menu")
	check(find_text(ui,"JUEGO DE CARTAS · PRIMERA EDICIÓN") == null,"Home subtitle removed")
	check(find_text(ui,"AAMIX · versión 0.13.0") != null,"Home footer uses version terminology")
	check(ProjectSettings.get_setting("application/config/name") == "AAMIX · versión 0.13.0","Window title uses current version terminology")
	check(find_meta(ui,"screen_background").get_meta("screen_background") == "light","Home uses a light background without table wood")
	check(contrast(ui.TEXT, ui.BG) > 7 and contrast(ui.MUTED, ui.BG) > 4.5,"Dark text remains readable on the light interface")
	var menu_button = find_text(ui,"Partida individual")
	var menu_panel = menu_button.get_parent().get_parent()
	check(menu_panel.get_theme_stylebox("panel") is StyleBoxTexture and menu_panel.get_theme_stylebox("panel").texture.get_meta("source_art", "") == "estetica/panel_blanco.png","Home uses the supplied white panel artwork")
	check(menu_button.get_theme_stylebox("normal") is StyleBoxTexture and menu_button.get_theme_stylebox("normal").texture.get_meta("source_art", "") == "estetica/boton_dorado.png","Primary button uses supplied golden artwork")
	check(menu_button.get_theme_stylebox("normal").get_minimum_size().y <= 40,"Sliced button artwork does not inflate button height")
	var field_probe = LineEdit.new()
	ui.add_child(field_probe)
	check(field_probe.get_combined_minimum_size().y <= 52,"Themed input retains practical height")
	field_probe.queue_free()
	await shot("01-inicio")
	ui.screen = "cards"
	ui.cards_tab = "collection"
	ui.render()
	await settle()
	var grid = find_meta(ui,"collection_grid")
	check(grid is HFlowContainer and grid.alignment == FlowContainer.ALIGNMENT_CENTER,"Collection rows centered")
	check(grid.last_wrap_alignment == FlowContainer.LAST_WRAP_ALIGNMENT_CENTER,"Last collection row centered")
	check(grid.get_child_count() == 35,"Regular collection group contains 35 cards")
	var promotional = find_meta(ui,"collection_promotional_row")
	check(promotional is HBoxContainer and promotional.alignment == BoxContainer.ALIGNMENT_CENTER,"Promotional cards use a centered single row")
	check(promotional.get_child_count() == 6,"All six promotional cards remain in the collection")
	for slot in grid.get_children():
		check(ui.game.catalog[slot.get_meta("collection_code")].get("subcoleccion", "") != "promocionales","Regular group excludes promotional card " + str(slot.get_meta("collection_code")))
	for slot in promotional.get_children():
		check(ui.game.catalog[slot.get_meta("collection_code")].get("subcoleccion", "") == "promocionales","Promotional group contains only promotional cards " + str(slot.get_meta("collection_code")))
	check(find_meta(ui,"promotional_divider") != null and find_text(ui,"Promocionales") != null,"Promotional group has a visible separation")
	var last_regular_bottom = 0.0
	for slot in grid.get_children(): last_regular_bottom = maxf(last_regular_bottom, slot.get_global_rect().end.y)
	check(promotional.global_position.y > last_regular_bottom + 20,"Promotional group sits separately below every regular card")
	var promo_y = promotional.get_child(0).global_position.y
	for slot in promotional.get_children():
		check(absf(slot.global_position.y - promo_y) < 1,"Promotional card remains in the single row " + str(slot.get_meta("collection_code")))
	check(find_text(ui,"41 cartas · 41 de 41 cartas obtenidas").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,"Collection count centered")
	check(find_text(ui,"Tus cartas están al día.") == null,"No inventory boilerplate")
	await shot("02-coleccion")
	var collection_scroll = find_meta(ui,"collection_scroll")
	collection_scroll.scroll_vertical = int(collection_scroll.get_v_scroll_bar().max_value)
	await settle()
	var viewport = root.get_visible_rect()
	check(promotional.get_global_rect().position.x >= viewport.position.x and promotional.get_global_rect().end.x <= viewport.end.x,"Six promotional cards fit normal window width")
	check(promotional.get_global_rect().end.y <= viewport.end.y,"Promotional row can be fully reached by scrolling")
	await shot("03-promocionales")
	for code in ["0108", "01d"]:
		var slot = collection_slot(ui, code)
		check(find_text(slot,code+" · ×1") != null,"Quantity remains visible for " + code)
		var double_click = InputEventMouseButton.new()
		double_click.button_index = MOUSE_BUTTON_LEFT
		double_click.pressed = true
		double_click.double_click = true
		slot.get_child(0).gui_input.emit(double_click)
		check(find_text(ui,code+" · "+ui.game.catalog[code].nombre) != null,"Double click still opens full card detail for " + code)
		ui.close_overlay(ui.overlay_shades.back())
	ui.collection.cards.erase("0101")
	ui.collection.cards.erase("01f")
	ui.render()
	await settle()
	for code in ["0101", "01f"]:
		var slot = collection_slot(ui, code)
		check(slot != null and slot.get_child(0).get_child_count() == 0 and find_text(slot,code+" · —") != null,"Missing card retains its empty slot and quantity marker: " + code)
	check(find_meta(ui,"collection_grid").get_child_count() == 35 and find_meta(ui,"collection_promotional_row").get_child_count() == 6,"Missing cards do not change either collection group")
	ui.collection.cards["0101"] = 1
	ui.collection.cards["01f"] = 1
	ui.cards_tab = "decks"
	ui.render()
	await settle()
	check(find_text(ui,"Ver lista") != null,"Owned deck lists remain available")
	check(find_text(ui,"Obtenido · 40 cartas") != null and find_text(ui,"Obtenido · 40 cartas · guardado en tu cuenta") == null,"Owned deck wording is concise")
	for deck in ui.collection.decks: check(find_text(ui,"Jugar con "+deck.nombre) == null,"No play button in owned decks")
	await shot("04-mis-mazos")
	ui.screen = "decks"
	ui.render()
	await settle()
	var choices = find_meta(ui,"deck_choices")
	check(choices.alignment == BoxContainer.ALIGNMENT_CENTER,"Deck selection group centered")
	var first = choices.get_child(0)
	var last = choices.get_child(-1)
	check(absf((first.global_position.x+last.global_position.x+last.size.x)/2.0-(choices.global_position.x+choices.size.x/2.0))<2.0,"Multiple deck group truly centered")
	await shot("05-elegir-mazo")
	ui.collection.decks = [ui.collection.decks[0]]
	ui.render()
	await settle()
	choices = find_meta(ui,"deck_choices")
	var only = choices.get_child(0)
	check(absf(only.global_position.x+only.size.x/2.0-(choices.global_position.x+choices.size.x/2.0))<2.0,"Single obtained deck truly centered")
	await shot("06-elegir-un-mazo")
	ui.screen = "account"
	ui.render()
	await settle()
	check(find_text(ui,"Tu foto de perfil") == null,"Account photo caption removed")
	await shot("07-mi-cuenta")
	ui.profiles.show_picker()
	await settle()
	check(ui.profiles.choices.size() == 22,"Light profile picker preserves the allowed portraits")
	await shot("08-retratos")
	ui.profiles.close()
	ui.show_configuration()
	await settle()
	await shot("09-configuracion")
	ui.close_overlay(ui.overlay_shades.back())
	ui.show_audio_settings()
	await settle()
	var sliders = ui.find_children("*", "HSlider", true, false)
	check(sliders.size() == 2 and sliders[0].get_theme_icon("grabber") != null,"Audio settings preserve themed sliders")
	await shot("10-sonido")
	ui.close_overlay(ui.overlay_shades.back())
	ui.exit_game()
	await settle()
	check(ui.quit_dialog.theme == ui.theme,"Exit confirmation explicitly shares the light theme")
	await shot("11-confirmar-salida")
	ui.quit_dialog.hide()
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	check(find_text(ui,"ZONA DE\nDOMINIO") != null,"Domain label renamed")
	for caption in ["Libre","Sin Aliados","Arrastra tus Aliados aquí"]: check(find_text(ui,caption)==null,"Removed empty-zone label: "+caption)
	var rival_found = false
	for node in ui.find_children("*","Label",true,false):
		if node.text.begins_with("RIVAL ·"): rival_found = true
		check(not "computador" in node.text.to_lower(),"Table uses Rival terminology")
	check(rival_found,"Opponent label says Rival")
	check(find_text(ui,"AAMIX · versión 0.13.0  ·  VS. RIVAL") != null,"Match header version is current")
	var table_background = find_meta(ui,"screen_background")
	check(table_background is TextureRect and table_background.get_meta("screen_background") == "wood" and table_background.material is ShaderMaterial,"Only the match uses supplied wood with restored visible RGB")
	var table_labels_safe = find_text(ui,"AAMIX · versión 0.13.0  ·  VS. RIVAL").get_parent().get_meta("wood_text_backplate", false)
	for node in ui.find_children("*", "Label", true, false):
		if node.text.begins_with("RIVAL ·") or (node.text.begins_with("Mano ") and node.text.trim_prefix("Mano ").is_valid_int()):
			table_labels_safe = table_labels_safe and node.get_parent().get_meta("wood_text_backplate", false)
	check(table_labels_safe,"Text that was directly on wood has an opaque cream backplate")
	await shot("12-partida")
	ui.game.lose(ui.computer)
	ui.render()
	await settle()
	check(find_text(ui,"Victoria") != null,"Light result dialog preserves victory and actions")
	await shot("13-victoria")
	ui.account.user = {}
	ui.account.access_token = ""
	ui.session_owner = ""
	ui.account.status = ""
	ui.screen = "account"
	ui.render()
	await settle()
	await shot("14-acceso")
	ui.account.code_sent = true
	ui.account.pending_email = "fixture@example.invalid"
	ui.render()
	await settle()
	await shot("15-verificacion")
	print(JSON.stringify({"ui_v013_checks":checks,"failures":failures,"real_emails_sent":0}))
	ui.sound.shutdown()
	await create_timer(0.12).timeout
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
