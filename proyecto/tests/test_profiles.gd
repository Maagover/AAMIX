extends SceneTree
## Isolated profile UI checks. All account data and RPC results are in memory.
## Run: AAMIX.exe --headless --path proyecto --script res://tests/test_profiles.gd
var failures = 0
var checks = 0

class FakeCollection:
	extends "res://collection.gd"
	var result = false
	var saved = []
	func set_avatar(code):
		saved.append(code)
		if result: profile.avatar_code = code
		return result

func _initialize():
	call_deferred("run")

func check(value, caption):
	checks += 1
	print(("PASS " if value else "FAIL ") + caption)
	if not value: failures += 1

func has_label(node):
	if node is Label: return true
	for child in node.get_children():
		if has_label(child): return true
	return false

func has_text(node, caption):
	if node is Label and node.text == caption: return true
	for child in node.get_children():
		if has_text(child, caption): return true
	return false

func screenshot(caption):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-screenshots=") and DisplayServer.get_name() != "headless":
			var folder = arg.trim_prefix("--profile-screenshots=")
			DirAccess.make_dir_recursive_absolute(folder)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(caption + ".png"))

func run():
	var board = load("res://main.tscn").instantiate()
	root.add_child(board)
	# A deliberately fake, unrefreshable session. No authorization call is made.
	board.account.user = {"id":"test-avatar-owner", "email":"test@example.invalid"}
	board.account.access_token = "not-a-real-token"
	board.account.expires_at = Time.get_unix_time_from_system() + 600
	board.collection.queue_free()
	board.collection = FakeCollection.new()
	board.collection.account = board.account
	board.collection.owner_id = "test-avatar-owner"
	board.collection.profile = {"avatar_code":"0108"}
	board.collection.loaded = true
	board.collection.gift = {"deck_id":"maago"}
	board.collection.status = "La conexión de prueba falló."
	board.add_child(board.collection)
	var profiles = load("res://profile_ui.gd").new(board)
	check(profiles.ally_codes().size() == 22, "Los 22 Aliados no promocionales están disponibles")
	check(profiles.current_code() == "0108", "Foto remota vinculada al ID")
	var neutral = profiles.avatar("0124", 80)
	check(neutral.avatar_code.is_empty() and not neutral.portrait.visible, "Una carta no Aliado no puede ser foto")
	neutral.free()
	board.collection.profile.avatar_code = "01f"
	check(profiles.current_code().is_empty(), "Una foto promocional guardada se oculta sin modificarla")
	check(board.collection.profile.avatar_code == "01f", "Ocultar una foto promocional no cambia los datos de la cuenta")
	var hidden_promo = profiles.avatar("01f", 80)
	check(hidden_promo.avatar_code.is_empty() and not hidden_promo.portrait.visible, "Una foto promocional usa la silueta neutral")
	hidden_promo.free()
	board.collection.profile.avatar_code = "0108"
	for code in profiles.ally_codes():
		var node = profiles.avatar(code, 92)
		var crop = node.crop_rect(code, node.portrait.texture)
		check(crop.x >= 0 and crop.y >= 0 and crop.x + crop.z <= 1 and crop.y + crop.w < 0.825, "Retrato dentro del arte: " + code)
		node.free()
	profiles.show_picker()
	check(profiles.choices.size() == 22, "Selector con 22 miniaturas no promocionales")
	var clean_images = true
	var names_in_tooltips = true
	for code in profiles.choices:
		clean_images = clean_images and not has_label(profiles.choices[code])
		names_in_tooltips = names_in_tooltips and profiles.choices[code].tooltip_text == board.game.catalog[code].nombre
	check(clean_images, "Las opciones muestran sólo imágenes, sin nombres debajo")
	check(names_in_tooltips, "Los nombres se conservan en los tooltips")
	var no_visible_names = true
	for code in board.game.catalog:
		no_visible_names = no_visible_names and not has_text(profiles.shade, board.game.catalog[code].nombre)
	check(no_visible_names, "La previsualización y el selector no muestran nombres de cartas")
	for code in ["01a", "01b", "01c", "01e", "01f"]:
		check(not profiles.choices.has(code), "Promocional reservada para futuros desbloqueos: " + code)
	await screenshot("01-elegir-foto")
	profiles.select("0117")
	check(profiles.selected_code == "0108", "Selección inválida ignorada")
	profiles.select("01f")
	check(profiles.selected_code == "0108", "Una promocional no se puede seleccionar")
	profiles.selected_code = "01f"
	await profiles.save()
	check(board.collection.saved.is_empty(), "El guardado también rechaza una promocional")
	for code in ["0107", "0127", "0108"]:
		profiles.select(code)
		await screenshot("02-rostro-" + code)
	profiles.select("0107")
	check(profiles.selected_code == "0107" and not profiles.save_button.disabled, "Selección local sin guardar")
	check(board.collection.profile.avatar_code == "0108", "Elegir no altera la foto remota")
	await profiles.save()
	check(is_instance_valid(profiles.shade) and profiles.message.text == board.collection.status and not profiles.save_button.disabled, "Error remoto visible y reintento habilitado")
	board.collection.result = true
	await profiles.save()
	check(board.collection.profile.avatar_code == "0107" and profiles.shade == null, "Guardar confirmado cierra y actualiza la cuenta")
	profiles.show_picker()
	profiles.select("0127")
	profiles.close()
	check(board.collection.profile.avatar_code == "0107", "Cancelar no cambia la foto")
	profiles.show_picker()
	profiles.select("0108")
	board.account.user.id = "different-player"
	var calls_before = board.collection.saved.size()
	await profiles.save()
	check(board.collection.saved.size() == calls_before, "Cambio de ID impide guardar una elección de la cuenta anterior")
	check(profiles.current_code().is_empty(), "No muestra la foto de otra cuenta")
	board.collection.clear()
	check(board.collection.profile.get("avatar_code", "").is_empty(), "Cerrar la colección borra la foto del usuario anterior")
	board.sound.shutdown()
	board.queue_free()
	await process_frame
	await process_frame
	print("PROFILE_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
