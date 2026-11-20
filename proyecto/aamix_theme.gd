extends RefCounted
## Compact, opaque surfaces share a persistent light or dark warm palette.
const WHITE = Color("ffffff")
const CREAM = Color("fffaf0")
const YELLOW = Color("ffde85")
const COFFEE = Color("96724e")
const GOLDEN = Color("cdb66d")
const DEEP = Color("7f6042")
const INK = Color("493720")
var board
var cache = {}

func _init(owner_board):
	board = owner_board

func panel_style(tone = "white"):
	var color = board.PANEL
	if tone == "gold": color = Color("3d3528") if board.dark_theme else Color("f6e7b9")
	elif tone == "coffee": color = Color("34302c") if board.dark_theme else Color("e0c8aa")
	var result = flat(color, board.BORDER, 9)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	result.shadow_color = Color(0,0,0,0.18 if board.dark_theme else 0.07)
	result.shadow_size = 4
	return result

func button_style(tone = "white", state = "normal"):
	var color = Color("33383b") if board.dark_theme else Color("fffdf7")
	if tone == "gold": color = Color("51442e") if board.dark_theme else Color("ffde85")
	elif tone == "coffee": color = Color("494035") if board.dark_theme else Color("d9bd96")
	if state == "hover": color = color.lightened(0.10) if board.dark_theme else color.darkened(0.035)
	elif state == "disabled": color = Color("292d30") if board.dark_theme else Color("e4dfd3")
	var result = flat(color, board.BORDER, 7)
	result.content_margin_left = 14
	result.content_margin_right = 14
	result.content_margin_top = 7
	result.content_margin_bottom = 8
	return result

func textured(filename, is_button):
	var result = StyleBoxTexture.new()
	if not cache.has(filename):
		# Work at UI scale in memory, so the original large artwork's bevel does
		# not become a 54-pixel edge on a small control. Source PNG stays intact.
		var source = board.asset_texture("estetica/" + filename).get_image()
		source.resize(maxi(1, roundi(source.get_width() * 0.25)), maxi(1, roundi(source.get_height() * 0.25)), Image.INTERPOLATE_LANCZOS)
		cache[filename] = ImageTexture.create_from_image(source)
		cache[filename].set_meta("source_art", "estetica/" + filename)
	result.texture = cache[filename]
	# Preserve curved edges and bevels without swallowing compact button labels.
	for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(edge, 10 if is_button else 16)
	result.content_margin_left = 12 if is_button else 13
	result.content_margin_right = 14 if is_button else 15
	result.content_margin_top = 6 if is_button else 10
	result.content_margin_bottom = 8 if is_button else 12
	return result

func flat(color, border = Color.TRANSPARENT, radius = 7):
	var result = StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1 if border.a > 0 else 0)
	result.set_corner_radius_all(radius)
	return result

func icon(name):
	var key = name + (":dark" if board.dark_theme else ":light")
	if cache.has(key): return cache[key]
	var drawing = ""
	if name == "grabber":
		drawing = '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22"><circle cx="11" cy="11" r="9" fill="#ffde85" stroke="#7f6042" stroke-width="2"/></svg>'
	else:
		drawing = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect x="2" y="2" width="20" height="20" rx="4" fill="#fffaf0" stroke="#96724e" stroke-width="2"/>'
		if name == "checked": drawing += '<path d="M6 12l4 4 8-9" fill="none" stroke="#7f6042" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
		drawing += '</svg>'
	if board.dark_theme:
		drawing = drawing.replace("#fffaf0", "#33383b").replace("#7f6042", "#e6cd9a").replace("#96724e", "#c8bca5")
	var image = Image.new()
	image.load_svg_from_string(drawing)
	cache[key] = ImageTexture.create_from_image(image)
	return cache[key]

func make_theme():
	var result = Theme.new()
	result.default_font_size = 17
	var ink = board.TEXT
	var muted = board.MUTED
	var accent = board.GOLD
	var disabled = Color("8d887d") if board.dark_theme else Color("8a7b66")
	for type in ["Label", "Button", "LineEdit", "TextEdit", "PopupMenu", "CheckBox", "CheckButton", "OptionButton", "TabBar"]:
		result.set_color("font_color", type, ink)
		result.set_color("font_hover_color", type, ink)
		result.set_color("font_hover_pressed_color", type, ink)
		result.set_color("font_focus_color", type, ink)
		result.set_color("font_disabled_color", type, disabled)
		result.set_color("font_outline_color", type, Color.TRANSPARENT)
	result.set_color("default_color", "RichTextLabel", ink)
	result.set_color("font_selected_color", "LineEdit", ink)
	result.set_color("font_uneditable_color", "LineEdit", muted)
	result.set_color("font_placeholder_color", "LineEdit", muted)
	result.set_color("caret_color", "LineEdit", muted)
	result.set_color("selection_color", "LineEdit", Color("665638") if board.dark_theme else YELLOW)
	result.set_stylebox("normal", "Button", button_style("white"))
	result.set_stylebox("hover", "Button", button_style("gold", "hover"))
	result.set_stylebox("pressed", "Button", button_style("coffee"))
	result.set_stylebox("hover_pressed", "Button", button_style("coffee", "hover"))
	result.set_stylebox("disabled", "Button", button_style("white", "disabled"))
	result.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, muted))
	# Opaque flat controls keep text crisp without bevels or outline shadows.
	result.set_color("font_pressed_color", "Button", ink)
	result.set_color("font_outline_color", "Button", Color.TRANSPARENT)
	result.set_constant("outline_size", "Button", 0)
	for type in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog", "PopupMenu"]:
		result.set_stylebox("panel", type, panel_style())
	result.set_stylebox("hover", "PopupMenu", button_style("gold"))
	result.set_stylebox("normal", "LineEdit", panel_style())
	result.set_stylebox("read_only", "LineEdit", panel_style())
	result.set_stylebox("focus", "LineEdit", flat(Color.TRANSPARENT, board.BORDER, 6))
	result.set_stylebox("normal", "TextEdit", panel_style())
	result.set_stylebox("focus", "TextEdit", flat(Color.TRANSPARENT, board.BORDER, 6))
	result.set_stylebox("panel", "TooltipPanel", panel_style())
	result.set_color("font_color", "TooltipLabel", ink)
	result.set_color("title_color", "Window", ink)
	result.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)
	var window_border = panel_style()
	window_border.content_margin_top = 34
	result.set_stylebox("embedded_border", "Window", window_border)
	for type in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, flat(Color("202427") if board.dark_theme else Color("e0d8c8"), board.BORDER, 5))
		result.set_stylebox("grabber", type, flat(Color("74664d") if board.dark_theme else COFFEE, board.BORDER, 5))
		result.set_stylebox("grabber_highlight", type, flat(accent, board.BORDER, 5))
		result.set_stylebox("grabber_pressed", type, flat(accent, board.BORDER, 5))
	for type in ["HSlider", "VSlider"]:
		result.set_stylebox("slider", type, flat(Color("202427") if board.dark_theme else Color("e0d8c8"), board.BORDER, 4))
		result.set_stylebox("grabber_area", type, flat(accent, board.BORDER, 4))
		result.set_stylebox("grabber_area_highlight", type, flat(accent, board.BORDER, 4))
		for state in ["grabber", "grabber_highlight", "grabber_disabled"]: result.set_icon(state, type, icon("grabber"))
	for state in ["checked", "checked_disabled", "radio_checked", "radio_checked_disabled"]: result.set_icon(state, "CheckBox", icon("checked"))
	for state in ["unchecked", "unchecked_disabled", "radio_unchecked", "radio_unchecked_disabled"]: result.set_icon(state, "CheckBox", icon("unchecked"))
	result.set_color("font_pressed_color", "CheckBox", ink)
	var divider = flat(board.BORDER)
	divider.content_margin_top = 1
	result.set_stylebox("separator", "HSeparator", divider)
	return result
