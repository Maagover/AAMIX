extends RefCounted
## The editor keeps only unsaved selections in memory; saved decks belong to the server.
const Rules = preload("res://deck_rules.gd")
var board
var editing = {}
var original = {}
var owner = ""
var query = ""
var category = "Todas"
var counters = {}
var grid
var selected_list
var selected_scroll
var total_label
var hint_label
var save_button
var draft_button
var library_scroll
var filter_input
var picker_shade
var picker_selected = ""
var picker_intent = null
var picker_choices = {}
var design_chosen = false

func _init(owner_board):
	board = owner_board

func reset():
	design_chosen = false
	editing = {}
	original = {}
	owner = ""
	query = ""
	category = "Todas"
	counters.clear()
	picker_shade = null
	picker_selected = ""
	picker_intent = null
	picker_choices.clear()

func open(deck = {}):
	if board.collection.busy or not board.collection.loaded: return
	if not deck.is_empty() and not (bool(deck.get("custom", false)) or bool(deck.get("editable", false))): return
	owner = board.account.player_id()
	editing = deck.duplicate(true) if not deck.is_empty() else {"id":"", "nombre":"Mi mazo", "portada":"custom_transmision", "custom":true, "draft":true, "revision":0, "recurso_inicial":"0100", "cartas":[]}
	var unconfirmed = board.collection.pending_custom_deck()
	if not unconfirmed.is_empty(): editing = unconfirmed
	design_chosen = not deck.is_empty() or not unconfirmed.is_empty()
	original = editing.duplicate(true)
	query = ""
	category = "Todas"
	board.collection.status = ""
	board.screen = "deck_builder"
	board.render()

func dirty():
	return editing != original

func locked():
	return board.collection.busy or board.account.busy or not board.collection.pending_deck_save.is_empty()

func leave(destination = "cards"):
	if board.collection.busy or board.account.busy: return
	if not board.collection.pending_deck_save.is_empty():
		close(destination)
		return
	if not dirty():
		close(destination)
		return
	var center = board.overlay("detail")
	var shade = center.get_parent()
	var body = board.box(board.panel(center), true, 15)
	body.custom_minimum_size.x = 540
	body.add_child(board.centered_label("Cambios sin guardar", 28, board.GOLD))
	body.add_child(board.centered_label("Puedes guardar este mazo como borrador\npara continuar construyéndolo después.", 20))
	body.add_child(board.button("Seguir editando", board.close_overlay.bind(shade), false, true))
	body.add_child(board.button("Salir sin guardar", close.bind(destination)))

func close(destination = "cards"):
	reset()
	if destination == "home":
		board.go_home(); return
	board.cards_tab = "decks"
	board.screen = "cards"
	board.render()

func entries():
	return editing.get("cartas", [])

func quantity(code):
	for entry in entries():
		if str(entry.codigo) == str(code): return int(entry.cantidad)
	return 0

func total():
	var amount = 0
	for entry in entries(): amount += int(entry.cantidad)
	return amount

func maximum(code):
	var other=0
	for entry in entries():
		if str(entry.codigo)!=str(code) and Rules.canonical(entry.codigo)==Rules.canonical(code):other+=int(entry.cantidad)
	return mini(maxi(0,Rules.copy_limit(board.game.catalog[code])-other),int(board.collection.cards.get(code,0)))

func change(code, delta):
	if locked(): return
	var next = quantity(code) + delta
	if next < 0 or next > maximum(code) or total() + delta > 40: return
	var updated = []
	for entry in entries():
		if str(entry.codigo) != str(code): updated.append(entry.duplicate(true))
	if next > 0: updated.append({"codigo":str(code), "cantidad":next})
	updated.sort_custom(func(a, b): return a.codigo < b.codigo)
	editing.cartas = updated
	refresh_selection()

func render_screen():
	if owner != board.account.player_id() or editing.is_empty():
		close()
		return
	counters.clear()
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 28)
	board.add_child(margin)
	var outer = board.box(margin, true, 13)
	var header = board.box(outer, false, 18)
	header.add_child(board.home_logo(175,44))
	header.add_child(board.fill(board.label("Crear mazo" if str(editing.id).is_empty() else "Editar mazo", 29, board.GOLD)))
	header.add_child(board.button("Volver", leave, board.collection.busy or board.account.busy))
	var details = board.box(outer, false, 18)
	var naming = board.box(details, true, 5)
	board.fill(naming)
	naming.add_child(board.label("Nombre del mazo", 16, board.MUTED))
	var name_input = LineEdit.new()
	name_input.text = str(editing.nombre)
	name_input.max_length = 48
	name_input.custom_minimum_size.y = 42
	name_input.editable = not locked()
	name_input.set_meta("deck_name", true)
	name_input.text_changed.connect(func(value): editing.nombre = value; refresh_validity())
	naming.add_child(name_input)
	naming.add_child(board.label("40 cartas para jugar · Al menos 1 Recurso · Máximo 3 copias por carta · 1 por Singular", 16, board.MUTED))
	naming.add_child(board.label("Recursos sin límite de copias. Sólo puedes usar cartas que tengas.", 16, board.MUTED))
	var cover = board.box(details, false, 12)
	cover.alignment = BoxContainer.ALIGNMENT_CENTER
	cover.add_child(board.deck_cover(editing, 74, 92))
	var cover_info = board.box(cover, true, 7)
	cover_info.add_child(board.label(Rules.cover_name(editing.portada) if editing.get("custom", false) else "Diseño original", 16, board.MUTED))
	var design_button = board.button("Elegir diseño", open_design_picker, locked())
	design_button.set_meta("choose_deck_design", true)
	if editing.get("custom", false): cover_info.add_child(design_button)
	else: design_button.free()
	var columns = board.box(outer, false, 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var library = board.box(columns, true, 10)
	board.fill(library)
	library.size_flags_stretch_ratio = 2.6
	var filters = board.box(library, false, 10)
	filter_input = LineEdit.new()
	filter_input.placeholder_text = "Buscar por nombre o número…"
	filter_input.text = query
	board.fill(filter_input)
	filter_input.custom_minimum_size.y = 40
	filter_input.set_meta("deck_search", true)
	filter_input.text_changed.connect(func(value): query = value; render_library())
	filters.add_child(filter_input)
	var categories = OptionButton.new()
	for value in ["Todas", "Aliado", "Recurso", "Objeto", "Evento", "Dominio", "Promocionales"]: categories.add_item(value)
	for index in categories.item_count:
		if categories.get_item_text(index) == category: categories.select(index)
	categories.item_selected.connect(func(index): category = categories.get_item_text(index); render_library())
	filters.add_child(categories)
	library_scroll = ScrollContainer.new()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library_scroll.set_meta("deck_library_scroll", true)
	library.add_child(library_scroll)
	grid = HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	library_scroll.add_child(grid)
	var selected_panel = board.panel(columns)
	selected_panel.custom_minimum_size.x = 380
	var selected = board.box(selected_panel, true, 10)
	selected.add_child(board.label("Tu mazo", 25, board.GOLD))
	total_label = board.label("", 23, board.GOLD)
	total_label.set_meta("deck_total", true)
	selected.add_child(total_label)
	selected_scroll = ScrollContainer.new()
	selected_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selected.add_child(selected_scroll)
	selected_list = board.box(selected_scroll, true, 6)
	board.fill(selected_list)
	hint_label = board.label("", 16, board.MUTED)
	hint_label.custom_minimum_size.x = 350
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected.add_child(hint_label)
	save_button = board.button("Guardar y usar", save.bind(false), false, true)
	save_button.set_meta("save_deck", true)
	selected.add_child(save_button)
	draft_button = board.button("Guardar borrador", save.bind(true))
	draft_button.set_meta("save_draft", true)
	selected.add_child(draft_button)
	if not board.collection.status.is_empty():
		var state = board.label(board.collection.status, 17, board.MINT)
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(state)
	render_library()
	refresh_selection()

func choose_cover(key):
	if locked() or key not in board.collection.available_covers(): return
	editing.portada = key
	design_chosen = true
	board.render()

func open_design_picker(save_intent = null):
	if locked() or owner != board.account.player_id(): return
	if is_instance_valid(picker_shade) and picker_shade.is_inside_tree(): return
	var designs = board.collection.available_covers()
	picker_intent = save_intent
	picker_selected = str(editing.get("portada", "custom_transmision"))
	if picker_selected not in designs: picker_selected = str(designs[0])
	picker_choices.clear()
	var center = board.overlay("deck_design")
	picker_shade = center.get_parent()
	picker_shade.set_meta("deck_design_picker", true)
	var body = board.box(board.panel(center), true, 18)
	body.custom_minimum_size.x = 1030
	body.add_child(board.centered_label("Elige el diseño de tu mazo", 29, board.GOLD))
	body.add_child(board.centered_label("El diseño identifica tu mazo. No consume cartas.", 17, board.MUTED))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1010, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var flow = HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	board.fill(flow)
	scroll.add_child(flow)
	for key in designs:
		var slot = board.box(flow, true, 8)
		slot.custom_minimum_size.x = 184
		var choose = board.button("", select_design.bind(str(key)), false, key == picker_selected)
		choose.custom_minimum_size = Vector2(184, 250)
		choose.set_meta("deck_design_option", key)
		choose.tooltip_text = Rules.cover_name(key)
		var picture = board.deck_cover({"custom":true, "portada":key}, 174, 236)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 6
		picture.offset_right = -6
		picture.offset_top = 6
		picture.offset_bottom = -6
		choose.add_child(picture)
		slot.add_child(choose)
		var caption = board.centered_label("", 17, board.TEXT)
		caption.custom_minimum_size.x = 184
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(caption)
		picker_choices[key] = {"button":choose, "caption":caption}
	refresh_design_selection()
	var controls = board.box(body, false, 14)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	var confirm_text = "Usar diseño" if save_intent == null else ("Guardar borrador" if save_intent else "Guardar y usar")
	var confirm = board.button(confirm_text, confirm_design, false, true)
	confirm.set_meta("confirm_deck_design", true)
	controls.add_child(confirm)
	var cancel = board.button("Cancelar", cancel_design)
	cancel.set_meta("cancel_deck_design", true)
	controls.add_child(cancel)
	body.add_child(board.centered_label("Los diseños especiales se desbloquean con códigos de regalo, eventos y misiones.", 16, board.MUTED))

func refresh_design_selection():
	for key in picker_choices:
		var selected = key == picker_selected
		var controls = picker_choices[key]
		controls.button.set_meta("selected_design", selected)
		for state in ["normal", "hover", "pressed"]:
			controls.button.add_theme_stylebox_override(state, board.button_style("gold" if selected else "white", state))
		controls.caption.text = ("✓ " if selected else "") + Rules.cover_name(key)

func select_design(key):
	if owner != board.account.player_id() or key not in board.collection.available_covers(): return
	if not is_instance_valid(picker_shade) or not picker_shade.is_inside_tree(): return
	picker_selected = str(key)
	refresh_design_selection()

func cancel_design():
	if is_instance_valid(picker_shade): board.close_overlay(picker_shade)
	picker_shade = null
	picker_choices.clear()
	picker_intent = null

func confirm_design():
	if locked() or owner != board.account.player_id() or picker_selected not in board.collection.available_covers(): return
	if not is_instance_valid(picker_shade) or not picker_shade.is_inside_tree(): return
	var save_intent = picker_intent
	editing.portada = picker_selected
	design_chosen = true
	cancel_design()
	if save_intent == null:
		board.render()
	else:
		persist_deck(save_intent)

func render_library():
	if not is_instance_valid(grid): return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	counters.clear()
	var codes = board.collection.cards.keys()
	codes.sort()
	for code in codes:
		if int(board.collection.cards[code]) <= 0 or not board.game.catalog.has(code): continue
		var definition = board.game.catalog[code]
		if not query.strip_edges().is_empty() and not (str(code) + " " + str(definition.nombre)).to_lower().contains(query.strip_edges().to_lower()): continue
		if category == "Promocionales" and definition.get("subcoleccion", "") != "promocionales": continue
		if category not in ["Todas", "Promocionales"] and definition.get("clase", "") != category: continue
		var slot = board.box(board.panel(grid), true, 5)
		slot.custom_minimum_size.x = 160
		slot.set_meta("builder_card", code)
		var picture = board.button("", board.catalog_detail.bind(code))
		picture.flat = true
		for state in ["normal","hover","pressed","focus","disabled"]: picture.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		picture.custom_minimum_size = Vector2(142, 185)
		picture.add_child(board.catalog_image(code, 142, 185))
		picture.get_child(0).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(picture)
		var title = board.centered_label(definition.nombre, 15, board.TEXT)
		title.custom_minimum_size.x = 145
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(title)
		slot.add_child(board.centered_label("Tienes %d · Máx. %d" % [int(board.collection.cards[code]), maximum(code)], 14, board.MUTED))
		var controls = board.box(slot, false, 5)
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		var minus = board.button("−", change.bind(code, -1))
		controls.add_child(minus)
		var amount = board.centered_label(str(quantity(code)), 18, board.GOLD)
		amount.custom_minimum_size.x = 36
		controls.add_child(amount)
		var plus = board.button("+", change.bind(code, 1))
		controls.add_child(plus)
		counters[code] = {"amount":amount, "minus":minus, "plus":plus}
	if grid.get_child_count() == 0: grid.add_child(board.label("No hay cartas para este filtro.", 19, board.MUTED))
	refresh_validity()

func refresh_selection():
	if not is_instance_valid(selected_list): return
	for child in selected_list.get_children():
		selected_list.remove_child(child)
		child.queue_free()
	if entries().is_empty():
		var empty = board.label("Elige cartas de tu colección\npara empezar a construir.", 18, board.MUTED)
		selected_list.add_child(empty)
	for entry in entries():
		var code = str(entry.codigo)
		var row = board.box(selected_list, false, 4)
		row.set_meta("selected_deck_card", code)
		var title = board.button("%d × %s" % [int(entry.cantidad), board.game.catalog[code].nombre], board.catalog_detail.bind(code))
		title.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.clip_text = true
		title.tooltip_text = "%s · %s" % [code, board.game.catalog[code].nombre]
		row.add_child(board.fill(title))
		row.add_child(board.button("−", change.bind(code, -1), locked()))
		row.add_child(board.button("+", change.bind(code, 1), locked() or quantity(code) >= maximum(code) or total() >= 40))
	refresh_validity()

func refresh_validity():
	if not is_instance_valid(total_label): return
	var count = total()
	total_label.text = "%d / 40 cartas" % count
	for code in counters:
		var controls = counters[code]
		controls.amount.text = str(quantity(code))
		controls.minus.disabled = locked() or quantity(code) == 0
		controls.plus.disabled = locked() or quantity(code) >= maximum(code) or count >= 40
	var ready = editing.duplicate(true)
	ready.draft = false
	var valid = Rules.validate(ready, board.game.catalog, board.collection.cards, true)
	save_button.disabled = board.collection.busy or board.account.busy or not valid.ok or str(editing.nombre).strip_edges().is_empty()
	var draft = editing.duplicate(true)
	draft.draft = true
	var valid_draft = Rules.validate(draft, board.game.catalog, board.collection.cards, true)
	draft_button.disabled = board.collection.busy or board.account.busy or not valid_draft.ok or str(editing.nombre).strip_edges().is_empty()
	hint_label.text = str(valid.message) if not valid.ok else ""
	if not board.collection.pending_deck_save.is_empty():
		var pending_draft = board.collection.pending_deck_save.payload.p_draft
		save_button.disabled = board.collection.busy or board.account.busy or pending_draft
		draft_button.disabled = board.collection.busy or board.account.busy or not pending_draft
		hint_label.text = "El último guardado aún no está confirmado. Reintenta el mismo guardado para recuperarlo sin duplicar el mazo."

func save(as_draft):
	if board.collection.busy or board.account.busy or owner != board.account.player_id(): return
	var payload = editing.duplicate(true)
	payload.nombre = str(payload.nombre).strip_edges()
	payload.draft = as_draft
	var valid = Rules.validate(payload, board.game.catalog, board.collection.cards, true)
	if not valid.ok:
		board.collection.status = valid.message
		board.render()
		return
	if not board.collection.pending_deck_save.is_empty():
		persist_deck(as_draft)
		return
	if not editing.get("custom", false) or (design_chosen and str(editing.portada) in board.collection.available_covers()):
		persist_deck(as_draft)
	else:
		open_design_picker(as_draft)

func persist_deck(as_draft):
	if board.collection.busy or board.account.busy or owner != board.account.player_id(): return
	var payload = editing.duplicate(true)
	payload.nombre = str(payload.nombre).strip_edges()
	payload.draft = as_draft
	var expected_owner = owner
	var ok = await board.collection.save_custom_deck(payload)
	if expected_owner != board.account.player_id() or owner != expected_owner: return
	if ok:
		close()
	else:
		board.render()

