extends "res://game.gd"

func _init():
	super()
	decklists = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mazos_legacy.json")).mazos

func new_game(seed_value = -1, _selected_decks = []):
	super.new_game(seed_value)
