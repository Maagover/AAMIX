extends SceneTree
func _initialize():run.call_deferred()
func run():
	var source=preload("res://game.gd").new();var bot=preload("res://ai.gd").new();var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/desafio_aamix.json"));var results=[];var failures=[]
	for deck in data.new_decks:
		var g=preload("res://game.gd").new();g.new_game(11000+deck.challenge_stage,[deck,source.decklists[1]]);var commands=0
		while g.winner==-1 and commands<3000:
			if not bot.step(g,g.actor):failures.append(deck.id+": stuck "+g.phase+" "+g.error);break
			g.take_visual_events();commands+=1
		if g.winner==-1:failures.append(deck.id+": no final result within command bound")
		failures.append_array(g.invariant_errors());results.append({"deck":deck.id,"commands":commands,"turns":g.turn,"winner":g.winner})
	print(JSON.stringify({"challenge_games_v1100":{"games":results,"failures":failures,"network_requests":0}}));quit(0 if failures.is_empty() else 1)
