extends SceneTree
## Local fixtures only: this creates no remote account, room or receipt.
var ui
var checks = 0
var failures = []
var legacy_game_path = ""

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-game="): legacy_game_path = arg.trim_prefix("--legacy-game=")
	run.call_deferred()
func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)
func nodes(parent):
	var result = [parent]
	for child in parent.get_children(): result.append_array(nodes(child))
	return result

func run():
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause = true
	ui.animations_enabled = false
	ui.account.set_process(false)
	ui.account.configured = false
	ui.online.set_process(false)
	ui.online.realtime.set_process(false)
	ui.rewards.set_process(false)
	for _i in range(3): await process_frame
	ui.account.user = {"id":"00000000-0000-4000-8000-000000000110"}
	ui.account.access_token = "local-fixture-not-a-credential"
	ui.account.expires_at = Time.get_unix_time_from_system() + 3600
	ui.account.configured = false
	ui.guest = false
	ui.session_owner = ui.account.player_id()
	ui.collection.owner_id = ui.account.player_id()
	ui.collection.loaded = true
	ui.collection.cards = {"0100":50,"0102":5,"01c":2}
	var custom = {"id":"custom_local_fixture","nombre":"Mazo propio multijugador de nombre largo de prueba","portada":"custom_transmision","custom":true,"draft":false,"revision":1,"recurso_inicial":"0100","cartas":[{"codigo":"0100","cantidad":36},{"codigo":"0102","cantidad":3},{"codigo":"01c","cantidad":1}]}
	var draft = custom.duplicate(true)
	draft.id = "custom_draft"
	draft.nombre = "Borrador pendiente"
	draft.draft = true
	ui.collection.decks = [ui.game.decklists[0],custom,draft]
	ui.online.lobby_mode = "create"
	ui.online.selected_deck = str(custom.id)
	ui.screen = "multiplayer"
	ui.render()
	for _i in range(3): await process_frame
	var choices = nodes(ui).filter(func(node): return node.has_meta("mp_deck"))
	check(choices.size() == 2 and choices.any(func(node): return str(node.get_meta("mp_deck")) == custom.id) and not choices.any(func(node): return str(node.get_meta("mp_deck")) == draft.id),"Selector multijugador incluye propios y excluye borradores")
	ui.online_ui.select_deck(draft.id)
	check(ui.online.selected_deck == custom.id,"Selección directa tampoco acepta un borrador")
	check(ui.deck_cover_texture(custom) != null,"Portada propia disponible en selector multijugador")
	var frozen = custom.duplicate(true)
	ui.collection.decks[1].cartas = [{"codigo":"0100","cantidad":40}]
	ui.online.room = {"room_id":"local-frozen-fixture","code":"TEST1100","status":"ready","players":[{"name":"Host"},{"name":"Guest"}],"confirmed":[true,true],"host_deck":frozen,"guest_deck":ui.game.decklists[0].duplicate(true),"commands":[],"state":{},"revision":0,"room_version":1,"slot":0}
	ui.online.revision = 0
	ui.online.slot = 0
	ui.online.start_host_game()
	var normal_count = 0
	for instance in ui.game.instances.values():
		if instance.owner == 0 and instance.code == "0102": normal_count += 1
	check(normal_count == 3 and not ui.online.staged_commit.is_empty() and ui.online.staged_commit.p_host_state.players[0].deck_id == custom.id,"Sala inicia lista congelada y genera snapshot propio aunque inventario cambie")
	if not legacy_game_path.is_empty():
		var old_host = load(legacy_game_path).new()
		old_host.new_game(110,[ui.game.decklists[0],frozen])
		var custom_count = 0
		for instance in old_host.instances.values():
			if instance.owner == 1 and instance.code == "0102": custom_count += 1
		check(custom_count == 3 and old_host.players[1].deck_id == frozen.id and old_host.invariant_errors().is_empty(),"Motor oficial1.0 puede alojar invitado1.1 con lista personalizada congelada")
	print(JSON.stringify({"custom_decks_online_v110":{"checks":checks,"failures":failures,"network_requests":0}}))
	ui.sound.shutdown()
	ui.queue_free()
	for _i in range(4): await process_frame
	quit(0 if failures.is_empty() else 1)
