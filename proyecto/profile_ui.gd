extends RefCounted
## Account portraits. The authenticated collection service owns persistence.
const AvatarView = preload("res://avatar_view.gd")
var board
var shade
var preview
var message
var save_button
var cancel_button
var choices = {}
var selected_code = ""
var picker_owner = ""
var saving = false

func _init(game_board):
	board = game_board

func ally_codes():
	var result = []
	for code in board.game.catalog:
		var definition = board.game.catalog[code]
		if definition.get("clase", "") == "Aliado" and (definition.get("subcoleccion", "") != "promocionales" or str(code) in ["01a","01b"]):
			result.append(str(code))
	result.sort()
	return result

func selectable_codes():
	return ally_codes().filter(func(code):return code in board.collection.available_avatar_codes)

func current_code():
	if not board.account.signed_in() or board.collection.owner_id != board.account.player_id(): return ""
	var value = str(board.collection.profile.get("avatar_code", ""))
	return value if value in selectable_codes() else ""

func avatar(code = "", diameter = 96):
	var valid_code = str(code) if str(code) in ally_codes() else ""
	var picture = board.texture_code(valid_code) if not valid_code.is_empty() else null
	var result = AvatarView.new().configure(picture, valid_code, diameter)
	result.tooltip_text = board.game.catalog[valid_code].nombre if not valid_code.is_empty() else "Elige tu foto de perfil en Mi cuenta"
	return result

func show_picker():
	if not board.account.signed_in() or not board.collection.loaded or board.collection.busy or saving: return
	if is_instance_valid(shade): board.close_overlay(shade)
	selected_code = current_code()
	picker_owner = board.account.player_id()
	var center = board.overlay("profile")
	shade = center.get_parent()
	var content = board.box(board.panel(center), true, 10)
	content.custom_minimum_size.x = 820
	centered_label(content, "Elige tu foto de perfil", 28, board.GOLD)
	centered_label(content, "Un Aliado para acompañar tu nombre e ID de jugador.", 17, board.MUTED)
	preview = avatar(selected_code, 138)
	content.add_child(preview)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 310)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	choices.clear()
	var group = ButtonGroup.new()
	for code in selectable_codes():
		var pick = board.button("", select.bind(code))
		pick.disabled = code not in selectable_codes()
		pick.custom_minimum_size = Vector2(122, 108)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.focus_mode = Control.FOCUS_ALL
		pick.toggle_mode = true
		pick.button_group = group
		pick.button_pressed = code == selected_code
		pick.tooltip_text = board.game.catalog[code].nombre
		if pick.disabled: pick.tooltip_text += " · Completa su misión histórica para desbloquear esta foto."
		pick.set_meta("avatar_choice", code)
		pick.add_theme_stylebox_override("pressed", board.button_style("gold"))
		grid.add_child(pick)
		var cell = VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.offset_top = 6
		cell.offset_bottom = -5
		cell.add_theme_constant_override("separation", 3)
		pick.add_child(cell)
		cell.add_child(avatar(code, 92))
		if pick.disabled: cell.modulate.a = 0.35; pick.set_meta("avatar_locked",true)
		choices[code] = pick
	if choices.is_empty(): centered_label(content,"Aún no tienes fotos de perfil disponibles.",17,board.MUTED)
	message = centered_label(content, "Elige la imagen que acompañará tu perfil.", 15, board.MUTED)
	message.custom_minimum_size = Vector2(790, 42)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions = board.box(content, false, 12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	save_button = board.button("Guardar foto", save, selected_code.is_empty(), true)
	save_button.custom_minimum_size.x = 225
	save_button.set_meta("save_avatar", true)
	actions.add_child(save_button)
	cancel_button = board.button("Cancelar", close)
	cancel_button.custom_minimum_size.x = 225
	actions.add_child(cancel_button)
	if choices.has(selected_code): choices[selected_code].grab_focus()

func centered_label(parent, caption, font_size, color):
	var result = board.label(caption, font_size, color)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

func select(code):
	if saving or not str(code) in selectable_codes(): return
	selected_code = str(code)
	preview.configure(board.texture_code(selected_code), selected_code, 138)
	preview.tooltip_text = board.game.catalog[selected_code].nombre
	message.text = "La foto se guardará en tu cuenta y seguirá vinculada a tu ID."
	save_button.disabled = false
	for key in choices: choices[key].set_pressed_no_signal(key == selected_code)

func save():
	if saving or not is_instance_valid(shade) or not selected_code in selectable_codes(): return
	if not board.account.signed_in() or board.account.player_id() != picker_owner:
		close()
		return
	saving = true
	set_disabled(true)
	message.text = "Guardando tu foto de perfil…"
	var ok = await board.collection.set_avatar(selected_code)
	saving = false
	if not is_instance_valid(shade): return
	if board.account.player_id() != picker_owner:
		close()
		return
	if ok:
		close()
		board.render()
	else:
		set_disabled(false)
		message.text = board.collection.status if not board.collection.status.is_empty() else "No pudimos guardar la foto. Inténtalo de nuevo."

func set_disabled(value):
	if is_instance_valid(save_button): save_button.disabled = value or selected_code.is_empty()
	if is_instance_valid(cancel_button): cancel_button.disabled = value
	for code in choices:
		var pick = choices[code]
		if is_instance_valid(pick): pick.disabled = value or code not in selectable_codes()

func close():
	if saving: return
	if is_instance_valid(shade): board.close_overlay(shade)
	shade = null
	choices.clear()
