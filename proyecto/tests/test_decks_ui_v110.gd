extends SceneTree
## Focused UI checks using a local in-memory inventory. No network or real account.
const Rules = preload("res://deck_rules.gd")
var ui
var checks = 0
var failures = []
var captures = []
var destination = ""
var layout = []

class FixtureCollection:
	extends "res://collection.gd"
	var fixture_requests = []
	func request(endpoint, payload):
		fixture_requests.append({"endpoint":endpoint,"payload":payload.duplicate(true)})
		assert(endpoint == "aamix_save_custom_deck", "UI fixture cannot call other services")
		var deck_id = str(payload.p_deck_id)
		if deck_id.is_empty(): deck_id = "custom_00000000-0000-4000-8000-000000000110"
		var deck = {"id":deck_id,"nombre":payload.p_nombre,"portada":payload.p_portada,"cartas":payload.p_cartas.duplicate(true),"draft":payload.p_draft,"custom":true,"revision":int(payload.p_expected_revision)+1,"recurso_inicial":"0100"}
		var saved = false
		for index in range(decks.size()):
			if str(decks[index].id) == deck_id:
				decks[index] = deck
				saved = true
				break
		if not saved: decks.append(deck)
		last_reply = {"last_saved_deck":deck.duplicate(true)}
		last_http_code = 200
		return true

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="): destination = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, message):
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL ", checks, ": ", message)

func settle():
	for _i in range(10): await process_frame

func all_meta(node, key):
	var result = []
	if node.has_meta(key): result.append(node)
	for child in node.get_children(): result.append_array(all_meta(child,key))
	return result

func find_text(node, value):
	if (node is Label or node is Button) and node.text == value: return node
	for child in node.get_children():
		var found = find_text(child,value)
		if found != null: return found
	return null

func find_meta(node, key, value = null):
	for item in all_meta(node,key):
		if value == null or item.get_meta(key) == value: return item
	return null

func shot(name):
	if destination.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path = destination.path_join(name + ".png")
	check(root.get_texture().get_image().save_png(path) == OK,"Screenshot saved: " + name)
	captures.append(path)

func list_decks():
	ui.screen = "cards"
	ui.cards_tab = "decks"
	ui.render()
	await settle()

func apply_theme(dark):
	ui.dark_theme = dark
	ui.apply_visual_palette()
	ui.theme = ui.visual_theme.make_theme()
	ui.render()
	await settle()

func dismiss():
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())

func count_code(code):
	return ui.deck_builder.quantity(code)

func assert_deck_layout(theme_name):
	var grid = find_meta(ui,"owned_deck_grid")
	var tiles = all_meta(ui,"owned_deck_tile")
	var geometry = []
	for tile in tiles:
		geometry.append({"id":tile.get_meta("owned_deck_tile"),"position":[tile.position.x,tile.position.y],"size":[tile.size.x,tile.size.y]})
	layout.append({"theme":theme_name,"tiles":geometry,"grid_size":[grid.size.x,grid.size.y]})
	check(grid.alignment == FlowContainer.ALIGNMENT_CENTER and grid.last_wrap_alignment == FlowContainer.LAST_WRAP_ALIGNMENT_CENTER,"Deck rows are centered: " + theme_name)
	var rows = {}
	for child in grid.get_children():
		var line = roundi(child.position.y)
		if not rows.has(line): rows[line] = {"left":child.position.x,"right":child.position.x+child.size.x}
		else:
			rows[line].left = minf(rows[line].left,child.position.x)
			rows[line].right = maxf(rows[line].right,child.position.x+child.size.x)
	check(rows.values().all(func(row): return absf(row.left+row.right-grid.size.x) <= 2),"Actual rows including plus tile are centered within grid: " + theme_name)
	check(tiles.all(func(tile): return absf(tile.size.x-tile.size.y) <= 2),"Deck tiles are square in final layout: " + theme_name)
	check(tiles.all(func(tile): return tile.global_position.x >= 0 and tile.global_position.x+tile.size.x <= ui.size.x+1),"Deck tiles fit viewport width: " + theme_name)

func run():
	if not destination.is_empty(): DirAccess.make_dir_recursive_absolute(destination)
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
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000110","user_metadata":{"display_name":"QA de mazos"}}
	ui.account.access_token = "local_visual_fixture"
	ui.account.expires_at = Time.get_unix_time_from_system()+3600
	ui.session_owner = ui.account.player_id()
	var old_collection = ui.collection
	ui.remove_child(old_collection)
	old_collection.queue_free()
	ui.collection = FixtureCollection.new()
	ui.collection.account = ui.account
	ui.add_child(ui.collection)
	ui.collection.owner_id = ui.account.player_id()
	ui.collection.loaded = true
	ui.collection.restos_welcome_claimed = true
	ui.collection.welcome_pack = {"claimed":true}
	ui.collection.changed.connect(ui.collection_changed)
	for code in ui.game.catalog: ui.collection.cards[code] = 8
	ui.collection.cards["0100"] = 60
	var complete = ui.game.decklists[0].duplicate(true)
	complete.merge({"id":"custom_10000000-0000-4000-8000-000000000110","nombre":"Tormenta personal","custom":true,"draft":false,"portada":"custom_transmision","revision":1},true)
	var draft = {"id":"custom_20000000-0000-4000-8000-000000000110","nombre":"Manzanas por terminar","custom":true,"draft":true,"portada":"custom_restos","revision":1,"recurso_inicial":"0100","cartas":[{"codigo":"0100","cantidad":4},{"codigo":"01a","cantidad":3}]}
	ui.collection.decks = [ui.game.decklists[0].duplicate(true),complete,draft]
	ui.guest = false
	await list_decks()
	check(ui.account.signed_in() and ui.collection.loaded,"Local fixture owner can open actual collection scene")
	check(all_meta(ui,"owned_deck_tile").size() == 3,"Base, completed custom and draft all appear in Mis Mazos")
	assert_deck_layout("light")
	var base_tile = find_meta(ui,"owned_deck_tile",str(ui.collection.decks[0].id))
	var custom_tile = find_meta(ui,"owned_deck_tile",str(complete.id))
	check(find_text(base_tile,"Editar") == null and find_text(custom_tile,"Editar") != null,"Only custom decks offer Editar")
	check(find_text(base_tile,"Ver Mazo") != null and find_text(custom_tile,"Ver Mazo") != null,"Each base/custom deck offers Ver Mazo")
	await shot("01-mis-mazos-claro")
	find_text(custom_tile,"Ver Mazo").pressed.emit()
	await settle()
	var preview = all_meta(ui,"preview_deck_card")
	check(preview.size() == complete.cartas.size(),"Ver Mazo displays every distinct card")
	check(preview.all(func(slot): return slot.get_child(0).get_child(0) is TextureRect and slot.get_child(0).get_child(0).texture != null),"Every deck preview entry displays original card art")
	check(complete.cartas.all(func(entry): return find_text(ui,"%s · ×%d" % [entry.codigo,int(entry.cantidad)]) != null),"Ver Mazo labels actual quantities")
	await shot("02-ver-mazo-claro")
	dismiss()
	find_meta(ui,"create_deck").pressed.emit()
	await settle()
	check(ui.screen == "deck_builder" and ui.deck_builder.total() == 0,"Plus tile opens new empty builder")
	check(all_meta(ui,"builder_card").size() == ui.game.catalog.size(),"Builder offers all owned base, obtained and promotional cards")
	check(ui.deck_builder.save_button.disabled and not ui.deck_builder.draft_button.disabled,"Incomplete empty deck can be drafted and cannot be used")
	ui.deck_builder.change("0101",3)
	ui.deck_builder.change("0101",1)
	check(count_code("0101") == 3 and ui.deck_builder.counters["0101"].plus.disabled,"Normal card cannot exceed three copies")
	ui.deck_builder.change("0103",1)
	ui.deck_builder.change("0103",1)
	check(count_code("0103") == 1 and ui.deck_builder.counters["0103"].plus.disabled,"Singular cannot exceed one copy")
	ui.collection.cards["0102"] = 1
	ui.deck_builder.change("0102",1)
	ui.deck_builder.change("0102",1)
	check(count_code("0102") == 1,"Builder enforces owned copy count")
	ui.collection.cards["0102"] = 8
	ui.deck_builder.change("0100",10)
	check(count_code("0100") == 10,"Resources can exceed three copies")
	ui.deck_builder.change("01a",3)
	check(count_code("01a") == 3,"Owned promotional cards can be selected")
	var search = find_meta(ui,"deck_search")
	search.text = "kaji"
	search.text_changed.emit("kaji")
	await settle()
	check(all_meta(ui,"builder_card").size() == 1 and find_meta(ui,"builder_card","0105") != null,"Search filters cards by name")
	search.text = "0119"
	search.text_changed.emit("0119")
	await settle()
	check(all_meta(ui,"builder_card").size() == 1 and find_meta(ui,"builder_card","0119") != null,"Search filters cards by printed number")
	search.text = ""
	search.text_changed.emit("")
	ui.deck_builder.category = "Promocionales"
	ui.deck_builder.render_library()
	await settle()
	check(all_meta(ui,"builder_card").size() == 6 and all_meta(ui,"builder_card").all(func(slot): return ui.game.catalog[slot.get_meta("builder_card")].get("subcoleccion","") == "promocionales"),"Promotional filter shows all six owned promos")
	ui.deck_builder.category = "Todas"
	ui.deck_builder.render_library()
	ui.deck_builder.choose_cover("custom_restos")
	await settle()
	check(ui.deck_builder.editing.portada == "custom_restos" and find_meta(ui,"deck_cover","custom_restos") != null,"Second standard cover can be chosen")
	check(ui.deck_builder.library_scroll.size.y > 250 and ui.deck_builder.selected_scroll.size.y > 160,"Builder library and selected cards have useful scroll space")
	check(ui.deck_builder.save_button.get_global_rect().end.y <= ui.size.y and ui.deck_builder.draft_button.get_global_rect().end.y <= ui.size.y,"Builder save controls fit viewport")
	await shot("03-constructor-claro")
	ui.deck_builder.editing.cartas = [{"codigo":"0100","cantidad":40}]
	ui.deck_builder.refresh_selection()
	ui.deck_builder.change("0101",1)
	check(ui.deck_builder.total() == 40 and count_code("0101") == 0,"Total cannot exceed forty including Restos")
	check(not ui.deck_builder.save_button.disabled,"Valid forty-card selection can be saved for play")
	ui.deck_builder.editing.cartas = [{"codigo":"0100","cantidad":10},{"codigo":"01a","cantidad":2}]
	ui.deck_builder.editing.nombre = "Borrador de prueba"
	ui.deck_builder.refresh_selection()
	var original_cards = ui.collection.cards.duplicate(true)
	await ui.deck_builder.save(true)
	await settle()
	var saved = ui.collection.last_saved_deck.duplicate(true)
	check(ui.screen == "cards" and saved.get("draft",false) and saved.cartas.size() == 2,"Guardar borrador returns to Mis Mazos with unfinished deck")
	check(ui.collection.cards == original_cards,"Saving a deck does not consume collection cards")
	check(not ui.collection.playable_decks().any(func(deck): return deck.id == saved.id),"Drafts are excluded from playable deck pool")
	check(ui.collection.playable_decks().any(func(deck): return deck.id == complete.id),"Completed custom deck is in playable deck pool")
	ui.deck_builder.open(saved)
	await settle()
	check(ui.screen == "deck_builder" and ui.deck_builder.quantity("01a") == 2,"Saved draft reopens with its chosen card quantities")
	ui.deck_builder.editing.cartas = complete.cartas.duplicate(true)
	ui.deck_builder.editing.nombre = "Borrador completado"
	ui.deck_builder.refresh_selection()
	await ui.deck_builder.save(false)
	await settle()
	check(not ui.collection.last_saved_deck.draft and ui.collection.last_saved_deck.revision == 2 and ui.collection.last_saved_deck.id == saved.id,"Editing promotes the same draft to ready deck with next revision")
	ui.deck_builder.open(ui.collection.decks[0])
	check(ui.screen == "cards","Builder refuses opening immutable base deck")
	ui.screen = "decks"
	ui.render()
	await settle()
	check(all_meta(find_meta(ui,"deck_choices"),"deck_cover").size() == ui.collection.playable_decks().size(),"Single-player chooser includes completed custom decks and excludes drafts")
	ui.online.lobby_mode = "create"
	ui.screen = "multiplayer"
	ui.render()
	await settle()
	check(all_meta(ui,"mp_deck").size() == ui.collection.playable_decks().size(),"Multiplayer chooser includes same completed custom decks")
	await list_decks()
	await apply_theme(true)
	assert_deck_layout("dark")
	await shot("04-mis-mazos-oscuro")
	ui.deck_builder.open(complete)
	await settle()
	check(not ui.deck_builder.save_button.disabled and ui.deck_builder.library_scroll.size.y > 250,"Builder remains usable with completed deck in dark theme")
	await shot("05-constructor-oscuro")
	ui.preview_deck(complete)
	await settle()
	await shot("06-ver-mazo-oscuro")
	check(ui.collection.fixture_requests.size() == 2 and ui.account.service_url.begins_with("https://") and not ui.account.configured,"Only two local fixture saves occurred; real network stays disabled")
	var result = {"ui_v110_checks":checks,"failures":failures,"captures":captures,"layout":layout,"fixture_only":true,"network_requests":0,"real_accounts_used":0,"engine":Engine.get_version_info().string}
	print(JSON.stringify(result))
	if not destination.is_empty():
		var report = FileAccess.open(destination.path_join("ui_v110_results.json"),FileAccess.WRITE)
		if report != null: report.store_string(JSON.stringify(result,"  "))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
