extends "res://tests/test_ui_v02.gd"
const Game = preload("res://tests/fixtures/legacy_game.gd")

func find_button(node, caption):
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var found = find_button(child, caption)
		if found != null: return found
	return null

func find_meta(node, key):
	if node.has_meta(key): return node
	for child in node.get_children():
		var found = find_meta(child, key)
		if found != null: return found
	return null

func fresh_ui():
	ui.game.new_game(19)
	ui.game.keep_hand()
	ui.game.keep_hand()
	ui.game.active = 0
	ui.game.actor = 0
	ui.game.turn = 10
	ui.game.phase = "main"
	ui.game.manual_payment = [false, false]
	ui.game.take_visual_events()
	ui.draft.clear()
	ui.choice_selected.clear()
	ui.render()

func empty_hand():
	ui.game.players[0].deck.append_array(ui.game.players[0].hand)
	ui.game.players[0].hand.clear()

func resources(amount):
	while ui.game.players[0].resources.size() < amount: take(0, "0100", "resources")

func click(node):
	await settle()
	var point = node.get_global_rect().get_center()
	move_mouse(point, Vector2.ZERO)
	await process_frame
	mouse_button(point, true)
	await process_frame
	mouse_button(point, false)
	await settle()

func hold_drag(source, destination, allowed):
	var a = source.get_global_rect().get_center()
	var b = destination.get_global_rect().get_center()
	move_mouse(a, Vector2.ZERO)
	await process_frame
	mouse_button(a, true)
	await process_frame
	var previous = a
	for i in range(1, 7):
		var point = a.lerp(b, float(i) / 6.0)
		move_mouse(point, point - previous, MOUSE_BUTTON_MASK_LEFT)
		previous = point
		await process_frame
	await settle()
	check(get_root().gui_is_dragging() and source.get_meta("indicator_role") == "source", "El arrastre nativo ilumina la carta de origen")
	var role = "hover" if allowed else "invalid"
	check(destination.get_meta("indicator_role") == role and destination.get_meta("indicator").visible, "El destino muestra un contorno visible: " + role)
	return b

func release(point):
	mouse_button(point, false)
	await settle()

func shot(name):
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v05-screenshots=") and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--v05-screenshots="))
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(arg.trim_prefix("--v05-screenshots=").path_join(name + ".png"))

func run():
	for p in range(2):
		var g = Game.new()
		g.new_game(19)
		for uid in g.players[p].hand.duplicate():
			if g.definition(uid).clase == "Recurso":
				g.players[p].hand.erase(uid)
				g.players[p].deck.append(uid)
		var paid = g.players[p].resources.pop_back()
		g.players[p].paid.append(paid)
		var ally = g.players[p].deck.filter(func(u): return g.definition(u).clase == "Aliado")[0]
		g.players[p].deck.erase(ally)
		g.players[p].attack.append(ally)
		var hand_before = g.players[p].hand.duplicate()
		g.active = p
		g.start_turn()
		check(g.phase == "main" and g.actor == p, "Sin Recurso en Mano se pasa a Acciones para jugador %d" % p)
		check(paid in g.players[p].resources and ally in g.players[p].defense and g.players[p].paid.is_empty(), "La reagrupación sucede antes del salto automático")
		check(g.players[p].hand == hand_before and g.invariant_errors().is_empty(), "El salto no roba, paga ni mueve cartas de la Mano")
		g.players[p].resources.erase(paid)
		g.players[p].hand.append(paid)
		g.start_turn()
		check(g.phase == "resource" and g.can_play(paid), "Con un Recurso en Mano se conserva la oportunidad de bajarlo")

	ui = load("res://main.tscn").instantiate()
	get_root().add_child(ui)
	ui.play_guest()
	ui.animations_enabled = false
	ui.game = preload("res://tests/fixtures/legacy_game.gd").new()
	ui.start_match(0)
	ui.automation_pause = true
	await settle()
	fresh_ui()
	resources(4)
	take(0, "0100", "paid")
	take(0, "0109", "defense")
	take(0, "0108", "attack")
	take(0, "0104", "graveyard")
	take(0, "0116", "burned")
	var domain = take(0, "0122", "hand")
	ui.game.players[0].hand.erase(domain)
	ui.game.domain_uid = domain
	while ui.game.players[0].hand.size() < 8: ui.game.draw(0, 1)
	ui.game.take_visual_events()
	ui.render()
	await settle()
	check(not ui.targets.any(func(n): return n.zone == "events"), "No existe una zona específica de Eventos")
	check(ui.action_panel.get_global_rect().end.x <= ui.log_panel.get_global_rect().position.x and absf(ui.action_panel.position.y - ui.log_panel.position.y) < 1, "Acciones y botones están juntos a la izquierda del registro")
	check(not ui.hand_scroll.get_h_scroll_bar().visible, "Las ocho cartas de la Mano caben sin desplazarse")
	var paid = surface("paid", 0)
	var deck = surface("deck", 0)
	var resource = surface("resources", 0)
	var grave = surface("graveyard", 0)
	var burned = surface("burned", 0)
	var central = surface("domain", -1)
	check(paid.get_global_rect().end.y <= deck.get_global_rect().position.y and deck.get_global_rect().end.y <= resource.get_global_rect().position.y, "Columna propia: Pagadas arriba, Mazo al centro, Recursos abajo")
	check(absf(paid.global_position.x - deck.global_position.x) < 1 and absf(deck.global_position.x - resource.global_position.x) < 1, "Las tres zonas de recursos comparten una columna vertical")
	check(deck.get_meta("pile_image").size.is_equal_approx(ui.CARD_SIZE) and deck.size.y > paid.size.y and deck.size.y > resource.size.y, "El Mazo mantiene la carta grande entre Recursos y Pagadas compactos")
	var own_cards = ui.targets.filter(func(n): return n.card_owner == 0 and n.get_meta("card_surface", false) and not n.get_meta("compact", false))
	check(own_cards.all(func(n): return absf(n.size.y - ui.CARD_SIZE.y) < 1 and absf(n.size.x - ui.CARD_SIZE.x) < 2), "Las cartas propias de Mano, Ataque y Defensa conservan su tamaño")
	var bounds = get_root().get_visible_rect()
	check([paid, deck, resource, grave, burned, central, ui.action_panel].all(func(n): return bounds.encloses(n.get_global_rect())), "Casillas y controles caben dentro de la ventana")
	var primary = find_button(ui, "Robar y terminar")
	check(primary.get_meta("primary", false) and primary.get_theme_color("font_color").r < 0.3 and primary.get_theme_stylebox("normal").bg_color.r > 0.8, "El botón de uso frecuente conserva fondo claro y letras oscuras")
	check(grave.get_global_rect().end.y <= burned.get_global_rect().position.y and absf(grave.global_position.x - burned.global_position.x) < 1, "Cementerio y Quemadas son casillas separadas, una sobre otra")
	check(central != null and absf(central.get_global_rect().get_center().x - bounds.get_center().x) < 1 and not ui.targets.any(func(n): return n.zone == "domain" and n.card_owner != -1), "El único Dominio es neutral y está centrado en la mesa")
	check(surface("attack", 1, -1).get_global_rect().end.y <= central.get_global_rect().position.y and central.get_global_rect().end.y <= surface("attack", 0, -1).get_global_rect().position.y, "El Dominio separa los campos de ambos jugadores")
	var layout = ui.capture_layout()
	check(layout.zones["0:graveyard"] != layout.zones["0:burned"] and layout.zones["0:domain"] == layout.zones["1:domain"], "Descartes separados y Dominio compartido mantienen los destinos de animación")
	await shot("13-ocho-cartas")

	ui.game.queue.append({"kind":"search", "player":0, "class":"Aliado", "count":1, "optional":true, "shuffle":true, "name":"Prueba de selección"})
	ui.game.drain()
	ui.render()
	await settle()
	var selected = ui.game.pending.options[0]
	await click(surface("choice", 0, selected))
	var selected_card = surface("choice", 0, selected)
	check(ui.choice_selected == [selected] and selected_card.get_meta("indicator").visible and selected_card.get_meta("indicator_role") == "selected", "Una selección por clic tiene borde visible sobre la imagen")
	check(find_meta(selected_card, "selection_badge") != null, "La carta seleccionada muestra una marca de confirmación")
	await shot("14-seleccion")
	find_button(ui, "Confirmar").pressed.emit()
	await settle()
	check(selected in ui.game.players[0].hand and ui.game.pending.is_empty(), "Confirmar la carta resaltada completa la búsqueda")
	var order = ui.game.players[0].deck.slice(0, 3)
	ui.game.set_choice({"kind":"reorder", "player":0, "title":"Orden del Mazo", "options":order, "min":3, "max":3, "optional":true})
	ui.render()
	await settle()
	var arranged = [order[2], order[0], order[1]]
	for uid in arranged: await click(surface("choice", 0, uid))
	check(arranged.all(func(uid): return find_meta(surface("choice", 0, uid), "selection_badge").get_child(0).text == str(arranged.find(uid) + 1)), "El reordenamiento muestra números según el orden elegido")
	find_button(ui, "Confirmar").pressed.emit()
	await settle()
	check(ui.game.players[0].deck.slice(0, 3) == arranged, "El orden mostrado coincide con el orden aplicado al Mazo")

	fresh_ui()
	empty_hand()
	resources(7)
	var raid = take(0, "0120", "hand")
	ui.render()
	await settle()
	var empty_line = surface("attack", 0, -1)
	var point = await hold_drag(surface("hand", 0, raid), empty_line, true)
	await shot("15-evento-tablero")
	await release(point)
	check(raid in ui.game.players[0].graveyard and ui.game.pending.get("kind") == "search_hand", "Un Evento se juega al soltarlo sobre el tablero")
	ui.skip_choice()
	await settle()
	var ally = take(0, "0109", "defense")
	var object_uid = take(0, "0124", "hand")
	ui.render()
	await settle()
	point = await hold_drag(surface("hand", 0, object_uid), surface("defense", 0, ally), true)
	await shot("16-portador-resaltado")
	await release(point)
	check(ui.game.instances[ally].object == object_uid, "El portador resaltado recibe el Objeto")
	var conflict = take(0, "0116", "hand")
	var enemy = take(1, "0104", "defense")
	ui.render()
	await settle()
	var available = ui.game.players[0].resources.size()
	point = await hold_drag(surface("hand", 0, conflict), surface("defense", 0, ally), false)
	await release(point)
	check(conflict in ui.game.players[0].hand and ui.game.players[0].resources.size() == available and ui.game.pending.is_empty(), "Un objetivo inválido se rechaza sin pago ni selección indirecta")
	point = await hold_drag(surface("hand", 0, conflict), surface("defense", 1, enemy), true)
	await release(point)
	check(conflict in ui.game.players[0].graveyard and enemy in ui.game.players[1].deck, "El Evento soltado sobre un objetivo válido resuelve su efecto")
	check(ui.current_drag.is_empty() and not get_root().gui_is_dragging(), "Al soltar desaparecen los indicadores transitorios")

	fresh_ui()
	empty_hand()
	ui.game.draw(0, 9)
	ui.game.take_visual_events()
	ui.render()
	await settle()
	ui.finish_turn()
	await settle()
	check(ui.game.pending.get("kind") == "end_discard" and surface("graveyard", 0) != null and surface("burned", 0) != null, "Ambas zonas de descarte permanecen visibles durante el cierre")
	var excess = int(ui.game.pending.max)
	for i in range(excess): await drag(surface("hand", 0, ui.game.players[0].hand[0]), surface("graveyard", 0))
	check(ui.game.players[0].hand.size() == 8 and ui.game.active == 1, "El cierre sigue descartando a ocho antes del rival")
	fresh_ui()
	for uid in ui.game.players[0].hand.duplicate():
		if ui.game.definition(uid).clase == "Recurso":
			ui.game.players[0].hand.erase(uid)
			ui.game.players[0].deck.append(uid)
	ui.perform(ui.game.start_turn)
	await settle()
	check(ui.game.phase == "main" and find_button(ui, "Continuar sin Recurso") == null and find_button(ui, "Robar y terminar") != null, "Sin Recursos la interfaz muestra Acciones directamente")
	check(ui.game.invariant_errors().is_empty(), "Las nuevas interacciones conservan las 80 cartas")
	print(JSON.stringify({"v05_checks":checks, "failures":failures}))
	ui.sound.shutdown()
	await create_timer(0.10).timeout
	ui.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
