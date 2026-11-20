extends SceneTree
const Game=preload("res://game.gd")
const Bot=preload("res://ai.gd")
var failures=[]
var records=[]
func _initialize():run.call_deferred()
func run():
	var source=Game.new();var bot=Bot.new()
	var halloween=JSON.parse_string(FileAccess.get_file_as_string("res://data/mazo_halloween.json"))
	var challenge=JSON.parse_string(FileAccess.get_file_as_string("res://challenge_decks.json")).mazos
	for sample in [{"deck":source.decklists[1],"seed":1901},{"deck":challenge[1],"seed":1902}]:
		var g=Game.new();g.new_game(sample.seed,[halloween,sample.deck]);var commands=0
		while g.winner==-1 and commands<2500:
			var ok=bot.step(g,g.actor);g.take_visual_events();commands+=1
			if not ok:failures.append("AI stuck: "+str(g.phase)+" "+str(g.error));break
		if g.winner==-1:failures.append("Game did not finish within command bound")
		if not g.invariant_errors().is_empty():failures.append_array(g.invariant_errors())
		records.append({"opponent":sample.deck.id,"seed":sample.seed,"commands":commands,"turns":g.turn,"winner":g.winner})
	print(JSON.stringify({"halloween_games01":{"games":records,"failures":failures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
