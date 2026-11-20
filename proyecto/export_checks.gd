extends SceneTree
var failures = []
var checks = 0
func _initialize():
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalogo_edicion_1.json"))
	for card in catalog.cartas:
		var path = "res://" + card.imagen.ruta
		var bytes = FileAccess.get_file_as_bytes(path)
		var image = Image.new()
		var result = image.load_png_from_buffer(bytes) if path.ends_with(".png") else image.load_jpg_from_buffer(bytes)
		checks += 1
		if result != OK or image.is_empty(): failures.append(path)
	for path in ["res://assets/estetica_v014/valle.png", "res://assets/aamix_a_white.png", "res://audio/menu_arcade_coins.mp3", "res://audio/batalla.wav"]:
		checks += 1
		if FileAccess.get_file_as_bytes(path).is_empty(): failures.append(path)
	print(JSON.stringify({"export_assets": {"checks": checks, "failures": failures}}))
	quit(0 if failures.is_empty() else 1)
