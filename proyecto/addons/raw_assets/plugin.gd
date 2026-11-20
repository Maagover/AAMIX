@tool
extends EditorPlugin

class OriginalAssets extends EditorExportPlugin:
	func _get_name(): return "AAMIXOriginalAssets"
	func _export_file(path, _type, _features):
		if path.get_extension().to_lower() in ["png", "jpg", "jpeg", "wav", "mp3"]:
			# AAMIX reads these bytes directly rather than loading imported Resources.
			var bytes=FileAccess.get_file_as_bytes(path)
			if "web" in _features and path.get_extension().to_lower() in ["png","jpg","jpeg"]:
				var card=path.begins_with("res://imagenes/") or (path.begins_with("res://assets/halloween_2026/H") and path.get_file().begins_with("H0"))
				var landscape=path.get_file() in ["valle.png","valle_halloween.png","madera_negra.png","mesa_madera.png","mesa_cuero_v03.png"]
				if card or landscape:
					var image=Image.new()
					var png=path.ends_with(".png")
					var error=image.load_png_from_buffer(bytes) if png else image.load_jpg_from_buffer(bytes)
					var maximum=650 if card else 1600
					if error==OK and image.get_width()>maximum:
						image.resize(maximum,roundi(float(image.get_height())*maximum/image.get_width()),Image.INTERPOLATE_LANCZOS)
						bytes=image.save_png_to_buffer() if png else image.save_jpg_to_buffer(0.9)
			add_file(path, bytes, false)
			skip()

var exporter
func _enter_tree():
	exporter = OriginalAssets.new()
	add_export_plugin(exporter)
func _exit_tree():
	remove_export_plugin(exporter)
