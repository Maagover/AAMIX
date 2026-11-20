extends SceneTree
## Focused acceptance for the v0.13 light theme and decorative pack artwork.
## Synthetic in-memory inventory only: no HTTP, grants, Auth or SQL is exercised.
## This checks the presentation boundary rather than reimplementing a pack draw.
var ui
var checks = 0
var failures = []
var screenshots = ""

class FakeCollection:
	extends "res://collection.gd"
	var open_calls = []
	var acknowledge_calls = []
	var forbidden_requests = []
	func _ready():
		pass
	func request(endpoint, body):
		forbidden_requests.append([endpoint, body])
		return false
	func load_inventory():
		changed.emit()
		return true
	func open_pack(request_uuid):
		open_calls.append(request_uuid)
		# An uncertain response: the presentation must keep this request UUID.
		return false
	func acknowledge_opening(opening_uuid):
		acknowledge_calls.append(opening_uuid)
		if acknowledge_calls.size() == 1:
			return false
		pending_opening = null
		changed.emit()
		return true

func _initialize():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			screenshots = argument.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, caption):
	checks += 1
	if not ok:
		failures.append(caption)
		printerr("FAIL: ", caption)

func settle():
	for index in range(6): await process_frame

func find_meta(node, key):
	if node.has_meta(key): return node
	for child in node.get_children():
		var found = find_meta(child, key)
		if found != null: return found
	return null

func first_control(node, type_name):
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found = first_control(child, type_name)
		if found != null: return found
	return null

func linear_channel(value):
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

func luminance(color):
	return 0.2126 * linear_channel(color.r) + 0.7152 * linear_channel(color.g) + 0.0722 * linear_channel(color.b)

func blend(foreground, background):
	return Color(foreground.r * foreground.a + background.r * (1.0 - foreground.a), foreground.g * foreground.a + background.g * (1.0 - foreground.a), foreground.b * foreground.a + background.b * (1.0 - foreground.a), 1.0)

func contrast(first, second):
	var a = luminance(first)
	var b = luminance(second)
	return (maxf(a,b) + 0.05) / (minf(a,b) + 0.05)

func style_background(stylebox, fallback):
	if stylebox is StyleBoxFlat: return blend(stylebox.bg_color, fallback)
	if stylebox is StyleBoxTexture and stylebox.texture != null:
		var image = stylebox.texture.get_image()
		if image != null and not image.is_empty():
			if image.is_compressed(): image.decompress()
			return blend(image.get_pixel(image.get_width() / 2, image.get_height() / 2), fallback)
	return fallback

func inventory_snapshot():
	return {"cards":ui.collection.cards.duplicate(true), "decks":ui.collection.decks.duplicate(true), "gift":ui.collection.gift.duplicate(true), "packs":ui.collection.packs}

func dispatch_swipe(reveal, distance):
	var start = reveal.origin + Vector2(140, 110)
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	reveal._gui_input(press)
	var move = InputEventMouseMotion.new()
	move.position = start + Vector2(distance, 0)
	move.relative = Vector2(distance, 0)
	reveal._gui_input(move)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = move.position
	release.pressed = false
	reveal._gui_input(release)

func swipe(reveal, distance):
	dispatch_swipe(reveal, distance)
	var elapsed = 0.0
	while is_instance_valid(reveal) and reveal.animating and elapsed < 4.0:
		await create_timer(0.05).timeout
		elapsed += 0.05
	await create_timer(0.22).timeout
	await settle()

func shot(caption):
	if screenshots.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(screenshots)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshots.path_join(caption + ".png"))

func run():
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause = true
	ui.animations_enabled = false
	ui.rewards.set_process(false)
	await settle()
	var tear_stream = ui.sound.streams.get("sobre_abrir")
	check(tear_stream != null and absf(tear_stream.get_length() - 0.82) < 0.03, "The logical opening cue uses the new 0.82-second foil tear rather than the old arpeggio")
	var background_is_light = luminance(ui.BG) >= 0.75
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var visible_background = root.get_texture().get_image().get_pixel(80,80)
		background_is_light = background_is_light and absf(visible_background.r-ui.BG.r) < 0.02 and absf(visible_background.g-ui.BG.g) < 0.02 and absf(visible_background.b-ui.BG.b) < 0.02
	check(background_is_light, "The global background renders its light palette without an unintended full-screen tint")
	var clear_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.WHITE)
	check(luminance(clear_color) >= 0.75, "Viewport clear color stays light outside the main controls")
	check(contrast(ui.TEXT, ui.BG) >= 4.5, "Normal text remains readable on the light background")
	var input = first_control(ui, "LineEdit")
	check(input != null, "The access form exposes its real input control")
	if input != null:
		var input_background = style_background(input.get_theme_stylebox("normal"), ui.BG)
		check(contrast(blend(input.get_theme_color("font_color"), input_background), input_background) >= 4.5, "Entered text contrasts with the actual input artwork")
		check(contrast(blend(input.get_theme_color("font_placeholder_color"), input_background), input_background) >= 3.0, "Input placeholder remains distinguishable on its light artwork")
	var dialog_background = style_background(ui.quit_dialog.get_theme_stylebox("panel", "AcceptDialog"), ui.BG)
	check(luminance(dialog_background) >= 0.5, "The exit confirmation uses a light panel")
	check(contrast(ui.quit_dialog.get_label().get_theme_color("font_color"), dialog_background) >= 4.5, "Exit confirmation text is readable independently of the main Control theme")

	var provenance = JSON.parse_string(FileAccess.get_file_as_string("res://assets/estetica/PROCEDENCIA.json"))
	check(provenance is Dictionary and provenance.get("assets", []).size() == 9, "All nine supplied aesthetic originals have a provenance record")
	if provenance is Dictionary:
		for entry in provenance.get("assets", []):
			var path = "res://assets/estetica/" + str(entry.file)
			check(FileAccess.get_sha256(path) == str(entry.sha256), "The supplied bitmap remains byte-identical: " + str(entry.file))
			var picture = ui.asset_texture("estetica/" + str(entry.file))
			check(picture != null and picture.get_width() > 0 and picture.get_height() > 0, "The supplied artwork loads at runtime: " + str(entry.file))
	var pack_art = load("res://pack_art.gd")
	var closed_art = pack_art.view(Vector2(326,478))
	var opened_art = pack_art.view(Vector2(326,478),true)
	check(closed_art.texture != null and opened_art.texture != null, "Closed and opened pack originals both load through the actual artwork component")
	check(closed_art.get_meta("pack_art") == "closed" and opened_art.get_meta("pack_art") == "open", "The two visible states use distinct supplied originals")
	check(closed_art.get_meta("pack_registration") == opened_art.get_meta("pack_registration"), "Closed and opened states share a common artwork registration")
	check(closed_art.size == opened_art.size and closed_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and opened_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Switching wrapper state preserves dimensions and aspect ratio")
	closed_art.free()
	opened_art.free()

	# Replace the remote component with an in-memory boundary recorder.
	ui.account.user = {"id":"aesthetic-v013-fixture", "email":"fixture@example.invalid"}
	ui.account.access_token = "memory-only-fixture"
	ui.account.expires_at = Time.get_unix_time_from_system() + 3600
	var original_collection = ui.collection
	ui.remove_child(original_collection)
	original_collection.queue_free()
	ui.collection = FakeCollection.new()
	ui.collection.account = ui.account
	ui.collection.owner_id = "aesthetic-v013-fixture"
	ui.collection.loaded = true
	ui.collection.gift = {"deck_id":"kajido"}
	ui.collection.profile = {"avatar_code":"0108"}
	ui.collection.cards = {"0100":1,"0104":2,"0116":1,"0105":1}
	ui.collection.packs = 2
	var ordered = ["0100","0104","0116","0104","0105"]
	var opening_id = "a0130000-0000-4000-8000-000000000001"
	ui.collection.pending_opening = {"opening_id":opening_id,"cards":ordered.duplicate(),"opened_at":"fixture","revealed_at":null}
	ui.add_child(ui.collection)
	ui.collection.changed.connect(ui.collection_changed)
	ui.rewards.account_owner = ui.account.player_id()
	ui.screen = "home"
	ui.render()
	await settle()
	var home
	for node in ui.find_children("*","Control",true,false):
		if node.get_script() == load("res://home_cards.gd"): home = node
	check(home != null and home.floating_cards.size() == 3, "Home preserves two printed cards and adds exactly one floating pack")
	if home != null:
		check(home.closed_pack.get_meta("pack_art") == "closed" and home.closed_pack.get_meta("decorative_pack"), "The home decoration uses the real supplied closed pack")
		check(home.logo.get_index() > home.closed_pack.get_index() and home.logo.get_index() > home.featured.get_index(), "The logo stays in front of the pack and printed cards")
		var rest = home.closed_pack.position
		home.clock += 3.0
		home.update_cards()
		check(home.closed_pack.position != rest and home.closed_pack.scale == Vector2.ONE, "The closed pack floats without flipping its artwork")
	await shot("v013-inicio-claro")
	ui.screen = "table"
	ui.render()
	await settle()
	var wood = find_meta(ui,"screen_background")
	check(wood != null and wood.get_meta("screen_background") == "wood" and wood is TextureRect, "Only the match surface uses the supplied wood texture")
	if wood is TextureRect:
		check(wood.material is ShaderMaterial and wood.modulate == Color.WHITE, "The low-alpha wood is presented through a material without a darkening tint")
	check(ui.game.invariant_errors().is_empty(), "Rendering the new table leaves the game state valid")
	await shot("v013-mesa-madera")
	ui.screen = "packs"
	ui.render()
	await settle()
	var baseline = inventory_snapshot()
	var reveal = find_meta(ui, "pack_reveal")
	check(reveal != null and reveal.sealed, "A stored opening starts with the actual sealed wrapper")
	if reveal != null:
		check(reveal.packet_closed.get_global_rect() == reveal.packet_opened_art.get_global_rect(), "The real closed/open layers are registered at the same visible rectangle")
		var opening_stages = []
		reveal.opening_stage_changed.connect(func(value):
			opening_stages.append(value)
			if value == "opened": await shot("v013-envoltorio-abierto")
		)
		check(reveal.cards == ordered, "Decorative artwork retains the server's exact order, including repeated normals")
		reveal.cards[0] = "0104"
		check(ui.collection.pending_opening.cards == ordered, "The visual card array cannot rewrite the stored result")
		reveal.cards[0] = ordered[0]
		await shot("v013-sobre-cerrado")
		await swipe(reveal, 18)
		check(reveal.sealed and ui.rewards.reveal_index == 0, "An incomplete drag neither opens nor reveals a card")
		await swipe(reveal, 100)
		check(not reveal.sealed and ui.rewards.reveal_open, "A completed drag opens the wrapper and records local presentation state")
		check(opening_stages == ["transition","opened","cards"], "The completed effect passes through closed-to-open transition before exposing the cards")
		check(ui.sound.recent.any(func(effect): return effect.name == "sobre_abrir"), "The real opening effect requests its existing audio cue")
		check(ui.collection.open_calls.is_empty() and ui.collection.acknowledge_calls.is_empty(), "Changing sealed/open artwork sends no grant or confirmation request")
		check(inventory_snapshot() == baseline, "Opening artwork never changes inventory quantities or pack balance")
		await shot("v013-sobre-abierto")
		await ui.collection.load_inventory()
		await settle()
		reveal = find_meta(ui, "pack_reveal")
		check(reveal != null and not reveal.sealed and reveal.revealed == 0, "Refreshing after the opening effect preserves its unsealed state")
		if reveal != null:
			await swipe(reveal, 150)
			check(ui.rewards.reveal_index == 1, "The first card is revealed only by its own completed slide")
		ui.go_home()
		await settle()
		ui.screen = "packs"
		ui.render()
		await settle()
		reveal = find_meta(ui, "pack_reveal")
		check(reveal != null and not reveal.sealed and reveal.revealed == 1, "Leaving and returning resumes the same opening at its actual card index")
		check(ui.collection.pending_opening.opening_id == opening_id and ui.collection.pending_opening.cards == ordered, "Returning never rerolls or replaces the stored opening ID")
		for index in range(1, 5):
			reveal = find_meta(ui, "pack_reveal")
			if reveal == null:
				check(false, "The next unrevealed card remains available at index " + str(index))
				break
			await swipe(reveal, -150 if index % 2 else 150)
			check(ui.rewards.reveal_index == index + 1, "Each left/right slide advances exactly one stored card: " + str(index + 1))
		check(ui.rewards.reveal_index == 5 and ui.collection.acknowledge_calls.is_empty(), "Five reveal animations do not acknowledge until the player continues")
		check(inventory_snapshot() == baseline and ui.collection.open_calls.is_empty(), "All artwork and reveal actions leave granted quantities untouched")
		await ui.rewards.finish_opening()
		check(ui.collection.pending_opening != null and ui.rewards.reveal_index == 5, "An uncertain confirmation keeps the completed opening available")
		await ui.rewards.finish_opening()
		check(ui.collection.acknowledge_calls == [opening_id,opening_id], "Confirmation retries use the same stored opening UUID")
		check(ui.collection.pending_opening == null and ui.rewards.reveal_id.is_empty(), "Confirmed completion clears only the pending presentation")
		check(inventory_snapshot() == baseline, "Acknowledgement never grants another copy or consumes another pack")

	await ui.rewards.start_opening()
	await ui.rewards.start_opening()
	check(ui.collection.open_calls.size() == 2 and ui.collection.open_calls[0] == ui.collection.open_calls[1] and not str(ui.collection.open_calls[0]).is_empty(), "Uncertain opening retries retain a nonempty request UUID")
	check(inventory_snapshot() == baseline, "A request without an authoritative response creates no local reward")
	# A second stored opening tests refresh during, rather than after, the effect.
	# It is fixture state only; changing this visual fixture does not grant cards.
	var second_id = "a0130000-0000-4000-8000-000000000002"
	ui.collection.pending_opening = {"opening_id":second_id,"cards":ordered.duplicate(),"opened_at":"fixture","revealed_at":null}
	ui.screen = "packs"
	ui.render()
	await settle()
	reveal = find_meta(ui, "pack_reveal")
	check(reveal != null and reveal.sealed, "A different stored opening starts sealed independently of the previous effect")
	if reveal != null:
		dispatch_swipe(reveal,100)
		check(reveal.animating and ui.rewards.reveal_open and not reveal.sealed, "The opening gesture commits presentation state before awaiting its transition")
		var calls_before_refresh = ui.collection.open_calls.duplicate()
		await ui.collection.load_inventory()
		await settle()
		reveal = find_meta(ui,"pack_reveal")
		check(reveal != null and not reveal.sealed and reveal.revealed == 0, "Refreshing mid-transition resumes an open wrapper without repeating the tear")
		check(ui.collection.pending_opening.opening_id == second_id and ui.collection.pending_opening.cards == ordered and ui.collection.open_calls == calls_before_refresh, "Mid-transition refresh keeps the same ordered result and sends no new opening request")
		check(inventory_snapshot() == baseline, "Cancelling and rebuilding the opening effect changes no inventory quantity")
	check(ui.collection.forbidden_requests.is_empty(), "The aesthetic acceptance test makes no HTTP or backend call")
	print(JSON.stringify({"aesthetic_v013_checks":checks,"failures":failures,"real_emails_sent":0,"backend_requests":0,"complete_ai_matches":0}))
	ui.sound.shutdown()
	await create_timer(0.12).timeout
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
