extends Control

signal match_started(deck_id, challenge_stage)
signal match_finished(victory: bool)

const Game = preload("res://game.gd")
const Bot = preload("res://ai.gd")
const Surface = preload("res://drop_surface.gd")
const Motion = preload("res://motion.gd")
const CardImage = preload("res://card_image.gd")
const Sound = preload("res://sound.gd")
const Account = preload("res://account.gd")
const Collection = preload("res://collection.gd")
const HomeCards = preload("res://home_cards.gd")
const GiftBadge = preload("res://gift_badge.gd")
const ProfileUI = preload("res://profile_ui.gd")
const RewardsUI = preload("res://rewards_ui.gd")
const AAMIXTheme = preload("res://aamix_theme.gd")
const HomeBackdrop = preload("res://home_backdrop.gd")
const InterfaceMotion = preload("res://interface_motion.gd")
const DeckArt = preload("res://deck_art.gd")
const DeckBuilder = preload("res://deck_builder.gd")
const HoverFeedback = preload("res://hover_feedback.gd")
const LogoLink = preload("res://logo_link.gd")
const UIIcons = preload("res://ui_icons.gd")
const Intro = preload("res://intro.gd")
const RestosArt = preload("res://restos_art.gd")
const ShopUI = preload("res://shop_ui.gd")
const OnlineMatch = preload("res://online_match.gd")
const MultiplayerUI = preload("res://multiplayer_ui.gd")
const Social = preload("res://social.gd")
const SocialUI = preload("res://social_ui.gd")
const CHALLENGES = [
  {
    "stage": 1,
    "deck_id": "papito",
    "title": "Mazo Papito",
    "reward_packs": 1
  },
  {
    "stage": 2,
    "deck_id": "flaan",
    "title": "Mazo Flaan",
    "reward_packs": 1
  },
  {
    "stage": 3,
    "deck_id": "kajido",
    "title": "Mazo Kajido",
    "reward_packs": 1
  },
  {
    "stage": 4,
    "deck_id": "maago",
    "title": "Mazo Maagover",
    "reward_packs": 2
  },
  {
    "stage": 5,
    "deck_id": "girabl",
    "title": "Mazo Girabl",
    "reward_packs": 3
  },
  {
    "stage": 6,
    "deck_id": "dominios",
    "title": "Mazo Dominios",
    "reward_packs": 3,
    "reward_cover": "custom_dominios"
  },
  {
    "stage": 7,
    "deck_id": "miku",
    "title": "Mazo Miku",
    "reward_packs": 3,
    "reward_cover": "custom_miku"
  },
  {
    "stage": 8,
    "deck_id": "tsuki_akira",
    "title": "Mazo Tsuki y Akira",
    "reward_packs": 3,
    "reward_cover": "custom_tsuki_desafio"
  },
  {
    "stage": 9,
    "deck_id": "imbloqueable",
    "title": "Mazo Imbloqueable",
    "reward_packs": 3,
    "reward_cover": "custom_imbloqueable"
  },
  {
    "stage": 10,
    "deck_id": "chanchuus",
    "title": "Mazo Chanchuus",
    "reward_packs": 3,
    "reward_cover": "custom_chanchuus_aliado"
  },
  {
    "stage": 11,
    "deck_id": "transmision",
    "title": "Transmisión Caída",
    "reward_packs": 3,
    "reward_cover": "custom_transmision_desafio"
  }
]
var BG = Color("fffaf0")
var PANEL = Color("ffffff")
var FELT = Color(1.0, 0.985, 0.94, 0.76)
var BORDER = Color("cdb66d")
var TEXT = Color("493720")
var MUTED = Color("7f6042")
var MINT = Color("5d482f")
var GOLD = Color("7f6042")
var ACCENT = Color("ffde85")
const CARD_SIZE = Vector2(88, 120)
var TARGET_COLOR = Color("96724e")
var INVALID_COLOR = Color("a44635")
var game
var visual_theme
var dark_theme = false
var visual_settings_path = "user://visual.cfg"
var bot = Bot.new()
var human = 0
var computer = 1
var selected_deck_index = 0
var deck_rng = RandomNumberGenerator.new()
var started = false
var modal_open = false
var automation_pause = false
var bot_clock = 0.0
var draft = []
var focus_uid = -1
var textures = {}
var targets = []
var choice_selected = []
var choice_key = ""
var choice_scroll_offset = 0
var fx
var sound
var screen = "intro"
var animations_enabled = true
var presenting = false
var presentation_generation = 0
var moving_uids = {}
var hand_slots = {}
var count_labels = []
var visual_counts = {}
var overlay_shades = []
var quitting = false
var current_drag = {}
var hovered_target
var action_panel
var log_panel
var hand_scroll
var drag_hint
var account
var account_email = ""
var account_nickname = ""
var account_code = ""
var account_register = false
var guest = false
var session_owner = ""
var collection
var cards_tab = "collection"
var profiles
var rewards
var shop
var online
var online_ui
var social
var social_ui
var deck_builder
var last_online_hint = ""
var quit_dialog: ConfirmationDialog
var ui_layer: CanvasLayer
var modal_layer: CanvasLayer
var notice_layer: CanvasLayer
var inspection
var turn_banner
var announced_turn = 0
var winner_announced = false
var gift_intro_owner = ""
var home_background
var interface_motion = InterfaceMotion.new()
var last_navigation = ""
var last_overlay_semantic = ""
var selected_challenge_stage = 0
var challenge_scroll_offset = 0
var active_challenge_stage = 0
var active_deck_id = ""
var pending_match = {}
var choice_dismissed = false
var selected_event_battle = false
var active_event_battle = false
var last_opponent_deck = {}
var welcome_loading = false
var welcome_notified = {}
var challenge_page = 0
var challenge_ui
var force_badges=[]
var challenge_slide = 0
var automatic_cost = false
var gameplay_settings_path = "user://gameplay.cfg"
var ask_automatic_cost = true
var automatic_uid = -1
var practice_match = false
var tutorial
var compact_layout = OS.has_feature("web")
var mobile_layout = OS.has_feature("web")
var mobile
var tap_selection = {}
const PASSIVE_OVERLAYS = ["inspection","inspection_detail","detail","log","help","configuration","audio","visuals","game_settings","auto_cost","abandon_match","notice"]

func _ready():
	mobile = preload("res://mobile_ui.gd").new(self)
	DisplayServer.window_set_title("AAMIX Online v1.3.1")
	tutorial=preload("res://tutorial.gd").new(self)
	load_game_settings()
	deck_rng.randomize()
	get_tree().auto_accept_quit = false
	load_visual_settings()
	visual_theme = AAMIXTheme.new(self)
	self.theme = visual_theme.make_theme()
	game = Game.new()
	game.new_game()
	game.take_visual_events()
	sound = Sound.new()
	add_child(sound)
	account = Account.new()
	add_child(account)
	account.changed.connect(account_changed)
	account_email=account.remembered_email
	account_nickname=account.remembered_name
	collection = Collection.new()
	collection.account = account
	add_child(collection)
	collection.changed.connect(collection_changed)
	profiles = ProfileUI.new(self)
	rewards = RewardsUI.new().setup(self)
	add_child(rewards)
	shop = ShopUI.new().setup(self)
	add_child(shop)
	online = OnlineMatch.new().setup(self)
	add_child(online)
	online.changed.connect(online_changed)
	online_ui = MultiplayerUI.new(self)
	social = Social.new().setup(self)
	add_child(social)
	social_ui = SocialUI.new(self)
	social.changed.connect(social_ui.changed)
	deck_builder = DeckBuilder.new(self)
	match_started.connect(rewards.match_started)
	match_finished.connect(rewards.match_finished)
	fx = Motion.new()
	fx.board = self
	fx.layer = 100
	add_child(fx)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)
	modal_layer=CanvasLayer.new()
	modal_layer.layer=220
	add_child(modal_layer)
	notice_layer=CanvasLayer.new()
	notice_layer.layer=230
	add_child(notice_layer)
	inspection=preload("res://zone_inspection.gd").new(self)
	home_background = HomeBackdrop.new()
	home_background.texture = asset_texture("estetica_v014/valle.png")
	add_child(home_background)
	move_child(home_background, 0)
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.theme = self.theme
	quit_dialog.title = "Salir de AAMIX"
	quit_dialog.dialog_text = "¿Seguro que quieres salir?"
	quit_dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quit_dialog.exclusive = true
	quit_dialog.get_ok_button().text = "Confirmar"
	quit_dialog.get_cancel_button().text = "Cancelar"
	quit_dialog.confirmed.connect(confirm_exit_game)
	add_child(quit_dialog)
	render()

func _process(delta):
	update_drag_feedback()
	refresh_force_badges()
	if tutorial.active and screen=="table":
		tutorial.poll()
		refresh_passive_overlays()
		return
	advance_automatic_cost()
	refresh_passive_overlays()
	if active_deck_id == "online" or online.active() or quitting or (is_instance_valid(quit_dialog) and quit_dialog.visible) or screen != "table" or not started or modal_blocks_play() or presenting or fx.busy or automation_pause or game.winner != -1 or game.actor == human:
		bot_clock = 0.0
		return
	bot_clock += delta
	if bot_clock < 0.65: return
	bot_clock = 0.0
	if not perform(bot.step.bind(game, computer)):
		game.error = "El rival no pudo completar esta acción. Puedes iniciar otra partida."
		automation_pause = true

func style(color, border = Color.TRANSPARENT, radius = 9):
	if dark_theme and color.r > 0.85 and color.g > 0.8 and color.b > 0.65:
		color = Color(PANEL, maxf(color.a, 0.94))
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.50, 0.40, 0.25, 0.13)
	s.shadow_size = 3
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func label(text, size = 16, color = null):
	if color == null: color = TEXT
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func centered_label(text, size = 16, color = null):
	if color == null: color = TEXT
	var l = label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func fill(node):
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func box(parent, vertical = true, gap = 7):
	var b = VBoxContainer.new() if vertical else HBoxContainer.new()
	b.add_theme_constant_override("separation", gap)
	parent.add_child(b)
	return b

func panel_style(tone = "white"):
	return visual_theme.panel_style(tone)

func button_style(tone = "white", state = "normal"):
	return visual_theme.button_style(tone, state)

func panel(parent, color = null, tone = "white"):
	if color == null: color = PANEL
	var p = PanelContainer.new()
	p.theme = self.theme
	if screen == "table":
		p.add_theme_stylebox_override("panel", style(Color(PANEL, 0.94), BORDER))
	else:
		p.add_theme_stylebox_override("panel", panel_style(tone))
	parent.add_child(p)
	return p

func button(text, action, disabled = false, primary = false):
	var b = Button.new()
	b.theme = self.theme
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = disabled
	b.custom_minimum_size.y = 36
	if primary:
		b.set_meta("primary", true)
		b.add_theme_stylebox_override("normal", button_style("gold"))
		b.add_theme_stylebox_override("hover", button_style("gold", "hover"))
	b.pressed.connect(func():
		sound.play_effect("interfaz")
		action.call()
	)
	return b

func wood_label(parent, caption, size = 16, color = null, expand = false):
	if color == null: color = TEXT
	var paper = PanelContainer.new()
	paper.add_theme_stylebox_override("panel", style(Color(1.0, 0.985, 0.94, 0.96), BORDER, 6))
	paper.set_meta("wood_text_backplate", true)
	if expand: fill(paper)
	parent.add_child(paper)
	var text = label(caption, size, color)
	paper.add_child(text)
	return text

func zone(parent, name, p, uid = -1, color = null):
	if color == null: color = FELT
	var node = Surface.new()
	node.board = self
	node.zone = name
	node.card_owner = p
	node.uid = uid
	var base_style = style(color, BORDER)
	if tutorial!=null and tutorial.active:node.set_meta("tutorial_zone",name)
	if name in ["attack", "defense"] and uid == -1: base_style.bg_color = Color(PANEL, 0.84) if dark_theme else Color(1.0, 0.985, 0.94, 0.84)
	node.add_theme_stylebox_override("panel", base_style)
	node.set_meta("base_style", base_style)
	parent.add_child(node)
	targets.append(node)
	attach_indicator(node)
	return node

func texture(uid):
	return texture_code(game.printed_code(uid)) if game.instances.has(uid) else null

func texture_code(code):
	if textures.has(code): return textures[code]
	var path = "res://" + game.catalog[code].imagen.ruta
	var img = read_image(path)
	if img == null: return null
	img.resize(650, int(650.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var tex = ImageTexture.create_from_image(img)
	tex.set_meta("printed_card", true)
	textures[code] = tex
	return tex

func read_image(path):
	var data = FileAccess.get_file_as_bytes(path)
	var image = Image.new()
	var err = image.load_png_from_buffer(data) if path.ends_with(".png") else image.load_jpg_from_buffer(data)
	return image if err == OK else null

func asset_texture(name, trim = false):
	var cache_key = "asset:" + name + (":trim" if trim else "")
	if textures.has(cache_key): return textures[cache_key]
	var image = read_image("res://assets/" + name)
	if image == null: return null
	var tex = ImageTexture.create_from_image(image)
	var result = tex
	if trim:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(image.get_used_rect())
		result = atlas
	textures[cache_key] = result
	return result

func asset_image(name, width, height, trim = false):
	var image = CardImage.new() if name == "dorso.jpg" else TextureRect.new()
	image.texture = asset_texture(name, trim)
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func deck_cover_texture(deck):
	return DeckArt.texture(self, deck)

func deck_cover(deck, width, height):
	return DeckArt.view(self, deck, width, height)

func background():
	home_background.visible = true
	var wood=screen in ["table","challenges"]
	home_background.animated = animations_enabled and not wood
	home_background.halloween = halloween_style_active() and not wood
	home_background.texture=asset_texture("actualizacion_v111/madera_negra.png" if wood else ("halloween_2026/valle_halloween.png" if halloween_style_active() else "estetica_v014/valle.png"))
	var shade=ColorRect.new()
	shade.color=Color(0,0,0,0.08 if wood else 0.20)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.set_meta("screen_background","shade")
	add_child(shade)

func image_card(uid, width, height):
	var image = CardImage.new()
	image.texture = texture(uid)
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func card(parent, uid, source_zone, p, width = 79, height = 96, selection = false):
	var c = zone(parent, source_zone, p, uid)
	var ability_target = game.payment_request.get("kind", "") == "ability" and int(game.payment_request.get("player", -1)) == human and int(game.payment_request.get("target", -1)) == uid
	selection = selection or ability_target
	if ability_target: c.set_meta("ability_payment_target", true)
	var face = texture(uid)
	var actual_width = minf(width, height * face.get_width() / face.get_height())
	c.custom_minimum_size = Vector2(actual_width, height)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.set_meta("card_surface", true)
	var surface_style = card_style(selection)
	c.add_theme_stylebox_override("panel", surface_style)
	c.set_meta("base_style", surface_style)
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var image = image_card(uid, actual_width, height)
	c.add_child(image)
	var d = game.definition(uid)
	if d.clase=="Aliado" and source_zone not in ["choice","inspection"]:add_force_badge(image,uid)
	var annotation = ""
	if d.clase == "Aliado":
		annotation = "F %d" % game.force(uid)
		if source_zone in ["hand", "choice"]: annotation = "C %d · F %d" % [int(d.coste), game.force(uid)]
		if game.instances[uid].object != -1: annotation += " · Miku"
		if uid in game.attacks: annotation += " · A%d" % (game.attacks.find(uid) + 1)
		if block_marker_visible(uid): annotation += " · B%d" % (game.attacks.find(game.blocks.find_key(uid)) + 1)
		if uid in draft: annotation += " · LISTO"
		if ability_target: annotation += " · OBJETIVO"
	elif d.clase == "Recurso": annotation = "RECURSO"
	else: annotation = "Coste %d · %s" % [int(d.coste), d.clase]
	if d.clase == "Aliado" and game.instances[uid].object != -1:
		var object_uid = game.instances[uid].object
		var equipment = Surface.new()
		equipment.board = self
		equipment.zone = "object"
		equipment.card_owner = p
		equipment.uid = object_uid
		var equipment_style = card_style()
		equipment.add_theme_stylebox_override("panel", equipment_style)
		equipment.set_meta("base_style", equipment_style)
		equipment.set_meta("compact", true)
		equipment.set_meta("card_surface", true)
		equipment.add_child(image_card(object_uid, 22, 31))
		attach_indicator(equipment)
		equipment.tooltip_text = game.title(object_uid) + " · Doble clic para leer"
		targets.append(equipment)
		equipment.anchor_left = 1.0
		equipment.anchor_right = 1.0
		equipment.anchor_top = 1.0
		equipment.anchor_bottom = 1.0
		equipment.offset_left = -24
		equipment.offset_right = -2
		equipment.offset_top = -33
		equipment.offset_bottom = -2
		image.add_child(equipment)
	c.tooltip_text = game.title(uid) + " · " + annotation + "\nDoble clic para leer"
	attach_indicator(c, selection)
	if source_zone == "choice" and selection:
		var badge = PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style = style(ACCENT, BORDER, 5)
		for edge in ["left", "right", "top", "bottom"]: badge_style.set("content_margin_" + edge, 2.0)
		badge.add_theme_stylebox_override("panel", badge_style)
		var mark = str(choice_selected.find(uid) + 1) if game.pending.get("kind") == "reorder" else "✓"
		badge.add_child(label(mark, 17, TEXT))
		badge.set_meta("selection_badge", true)
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.offset_left = -29
		badge.offset_right = -1
		badge.offset_top = 1
		badge.offset_bottom = 29
		badge.z_index = 12
		image.add_child(badge)
	return c

func card_style(selected = false):
	var s = StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = GOLD
	s.set_border_width_all(2 if selected else 0)
	s.set_corner_radius_all(4)
	for edge in ["left", "right", "top", "bottom"]: s.set("content_margin_" + edge, 0.0)
	return s

func visible_to_human(uid):
	if not game.instances.has(uid): return false
	var loc = game.location(uid)
	return not (loc.get("player", human) != human and loc.get("zone", "") in ["hand", "deck"])

func render():
	interface_motion.cancel_all()
	_render_content()
	decorate_navigation()
	apply_backdrop_contrast()
	if inspection!=null:inspection.refresh()
	var navigation = screen + (":" + cards_tab if screen == "cards" else "")
	if navigation != last_navigation and screen != "intro":
		last_navigation = navigation
		sound.play_effect("popup")
		for child in get_children():
			if child is Control and child != home_background and not child.has_meta("screen_background") and not child.has_meta("interface_decoration") and not child.has_meta("overlay_kind"):
				pop_in.call_deferred(child)
	if overlay_shades.is_empty(): last_overlay_semantic = ""
	if mobile_layout: mobile.fit_overlays.call_deferred()

func _render_content():
	clear_tap_selection()
	if screen != "table": clear_turn_banner()
	var preserved=[]
	if modal_layer!=null:
		for shade in modal_layer.get_children():
			if screen=="table" and shade.get_meta("overlay_kind","") in PASSIVE_OVERLAYS:
				preserved.append(shade)
			else:
				modal_layer.remove_child(shade);shade.queue_free()
	overlay_shades=preserved
	modal_open=not preserved.is_empty()
	force_badges.clear()
	targets.clear()
	hand_slots.clear()
	count_labels.clear()
	hovered_target = null
	draft = draft.filter(func(u): return game.phase == "main" and game.active == human and game.can_attack(u))
	if game.pending.is_empty():
		choice_key = ""
		choice_selected.clear()
		choice_scroll_offset = 0
	else:
		var key = str(game.pending)
		if key != choice_key:
			choice_dismissed = false
			choice_key = key
			choice_selected.clear()
			choice_scroll_offset = 0
	for node in get_children():
		if node == fx or node == sound or node == account or node == collection or node == quit_dialog or node == ui_layer or node == modal_layer or node == notice_layer or node == rewards or node == shop or node == online or node == social or node == home_background: continue
		remove_child(node)
		node.queue_free()
	background()
	sound.halloween_menu = halloween_style_active()
	sound.halloween_battle = active_event_battle
	sound.set_screen(screen, active_challenge_stage > 0, screen == "table" and started and game.winner != -1 and not presenting, rewards.pack_music_suspended())
	if mobile_layout and mobile.render_screen(): return
	if screen == "intro":
		var intro = Intro.new().configure(self)
		intro.continued.connect(play_guest)
		add_child(intro)
		return
	if screen == "versus":
		render_versus()
		return
	if screen == "multiplayer":
		online_ui.render_screen()
		return
	if screen in ["friends", "trades"]:
		social_ui.render_screen()
		return
	if screen == "shop":
		shop.render_screen()
		return
	if screen in ["gift_code", "missions", "event", "packs"]:
		rewards.render_screen()
		return
	if screen == "gift":
		render_starter()
		return
	if screen == "cards":
		render_cards()
		return
	if screen == "deck_builder":
		deck_builder.render_screen()
		return
	if screen == "home":
		render_home()
		return
	if screen == "decks":
		render_decks()
		return
	if screen == "single":
		render_single()
		return
	if screen == "challenges":
		render_challenges()
		return
	if screen == "tutorial":
		tutorial.render_screen();return
	if screen == "account":
		render_account()
		return
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 15)
	add_child(margin)
	var root = box(margin, true, 6)
	var header = box(root, false)
	header.add_child(home_logo(174,38))
	var rival_name=game.players[computer].name if online.in_match() else "RIVAL"
	var rival_deck=owned_or_guest_deck_name(str(game.players[computer].deck_id))
	if online.in_match() and online.room.get("players",[]).size()>computer:rival_deck=str(online.room.players[computer].get("deck_name",rival_deck))
	if not online.in_match():rival_deck=game.players[computer].name
	wood_label(header,str(rival_name)+" - "+rival_deck+"\n"+("TU TURNO" if game.active==human else "TURNO RIVAL")+" · Turno %d"%game.turn,13,MUTED,true)
	opponent_hand(header)
	header.add_child(fill(Control.new()))
	header.add_child(settings_icon())
	header.add_child(button("Registro",show_log))
	if tutorial.active:
		header.add_child(button("Saltar tutorial",tutorial.leave))
	else:
		var abandon=button("Abandonar partida",confirm_abandon_match,game.winner!=-1 or online.busy)
		abandon.set_meta("abandon_match",true);header.add_child(abandon)
	if tutorial.active:tutorial.render_guide(root)
	var board_surface = zone(root, "board", human)
	board_surface.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	board_surface.set_meta("base_style", StyleBoxEmpty.new())
	board_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table = box(board_surface, true, 6)
	table.mouse_filter = Control.MOUSE_FILTER_PASS
	player_table(table, computer)
	shared_domain(table)
	player_table(table, human)
	var bottom_center=CenterContainer.new();root.add_child(bottom_center)
	var bottom = box(bottom_center, false, 9)
	human_hand(bottom)
	action_panel = panel(bottom, Color(1.0, 0.985, 0.94, 0.91))
	action_panel.set_meta("actions", true)
	action_panel.custom_minimum_size.x = 340 if compact_layout else 420
	action_bar(action_panel)
	if tutorial.active:tutorial.decorate_board()
	for uid in moving_uids: hide_visual_uid(uid)
	if not presenting:
		if not game.pending.is_empty() and int(game.pending.player) == human and game.pending.kind not in ["end_discard", "limit_keep"] and not choice_dismissed: show_choice()
		elif game.winner != -1 and not overlay_shades.any(func(n):return n.get_meta("overlay_kind","")=="result"): show_winner()

func opponent_hand(parent):
	var center=CenterContainer.new();center.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(center)
	var row=box(center,false,4)
	hand_slots[computer]={}
	for uid in game.players[computer].hand:
		var back=asset_image("dorso.jpg",24,34);row.add_child(back);hand_slots[computer][uid]=back

func player_table(parent, p):
	if p == human:
		human_table(parent)
		return
	var row = box(parent, false, 6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 175 if compact_layout else (205 if tutorial.active else 245)
	lanes(row, p)
	resource_piles(row, p)
	meta_piles(row, p)

func meta_piles(parent, p):
	var v = box(parent, true, 5)
	v.custom_minimum_size.x = 95
	var order = ["graveyard", "burned"] if p == human else ["burned", "graveyard"]
	for z in order: pile(v, z, p, "CEMENTERIO" if z == "graveyard" else "QUEMADAS", 78)

func resource_piles(parent, p):
	var v = box(parent, true, 5)
	v.custom_minimum_size.x = 100
	var order = ["paid", "deck", "resources"] if p == human else ["resources", "deck", "paid"]
	for z in order:
		pile(v, z, p, {"resources":"RECURSOS", "paid":"PAGADAS", "deck":"MAZO"}[z], 62)

func pile(parent, source_zone, p, title, height):
	var cards = game.players[p][source_zone]
	var uid = -1
	if not cards.is_empty() and source_zone != "deck": uid = cards.back()
	if source_zone == "paid" and not game.reserved[p].is_empty(): uid = game.reserved[p].back()
	var holder = zone(parent, source_zone, p, uid, Color(1.0, 0.985, 0.94, 0.76))
	holder.set_meta("pile", true)
	holder.custom_minimum_size = Vector2(95, height)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h = box(holder, false, 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image
	if source_zone == "deck" and not cards.is_empty(): image = asset_image("dorso.jpg", 24 if compact_layout else 39, 34 if compact_layout else 54)
	elif uid != -1: image = image_card(uid, 24 if compact_layout else (30 if height < 80 else 37), 34 if compact_layout else (44 if height < 80 else 58))
	if image != null:
		h.add_child(image)
		holder.set_meta("pile_image", image)
	var v = box(h, true, 0)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(label(title, 10, MUTED))
	var count = label("", 24, TEXT)
	v.add_child(count)
	register_count(count, p, source_zone)
	if source_zone == "paid" and not game.reserved[p].is_empty(): v.add_child(label("%d sin gastar" % game.reserved[p].size(), 9, MINT))
	if source_zone in ["graveyard", "burned"]:
		var inspect = button("Ver", inspect_zone.bind(p, source_zone))
		inspect.custom_minimum_size.y = 22
		inspect.add_theme_font_size_override("font_size", 11)
		forward_drag_from(inspect, holder)
		v.add_child(inspect)
	holder.tooltip_text = title + " · " + game.players[p].name
	if uid != -1: holder.tooltip_text += " · Doble clic para leer la carta superior"

func lanes(parent, p):
	var v = box(parent, true, 5)
	fill(v)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var order = ["attack", "defense"] if p == human else ["defense", "attack"]
	for z in order:
		var holder = zone(v, z, p)
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.custom_minimum_size.y = 78 if compact_layout else 96
		var h = box(holder, false, 5)
		h.mouse_filter = Control.MOUSE_FILTER_PASS
		var title = label("LÍNEA DE\n" + ("ATAQUE" if z == "attack" else "DEFENSA"), 11, MUTED)
		title.custom_minimum_size.x = 76
		h.add_child(title)
		var scroll = ScrollContainer.new()
		fill(scroll)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(scroll)
		var cards = box(scroll, false, 5)
		cards.mouse_filter = Control.MOUSE_FILTER_PASS
		var current = game.players[p][z].duplicate()
		if p == human and z == "defense": current = current.filter(func(u): return u not in draft)
		if p == human and z == "attack": current.append_array(draft)
		for uid in current: card(cards, uid, "draft_attack" if uid in draft else z, p, 60 if compact_layout else (CARD_SIZE.x if p == human else 88), 82 if compact_layout else (90 if tutorial.active else (CARD_SIZE.y if p == human else 106)), uid in draft or block_marker_visible(uid))

func human_table(parent):
	var row = box(parent, false, 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 175 if compact_layout else (205 if tutorial.active else 245)
	meta_piles(row, human)
	var resources_column = box(row, true, 5)
	resources_column.custom_minimum_size.x = 105
	resources_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for z in ["paid", "deck", "resources"]: own_resource_pile(resources_column, z)
	lanes(row, human)

func own_resource_pile(parent, z):
	var cards = game.players[human][z]
	var uid = -1 if cards.is_empty() or z == "deck" else cards.back()
	if z == "paid" and not game.reserved[human].is_empty(): uid = game.reserved[human].back()
	var holder = zone(parent, z, human, uid, Color(1.0, 0.985, 0.94, 0.76))
	holder.set_meta("pile", true)
	holder.set_meta("resource_column", true)
	holder.custom_minimum_size = Vector2(105, (80 if compact_layout else 105) if z == "deck" else 52)
	var row = box(holder, false, 7)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var size = (Vector2(50, 68) if compact_layout else CARD_SIZE) if z == "deck" else (Vector2(28, 38) if compact_layout else Vector2(36, 49))
	var picture
	if z == "deck" and not cards.is_empty(): picture = asset_image("dorso.jpg", size.x, size.y)
	elif uid != -1: picture = image_card(uid, size.x, size.y)
	else:
		picture = Control.new()
		picture.custom_minimum_size = size
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.set_meta("pile_image", picture)
	attach_indicator(holder, false, picture)
	var info = box(row, true, 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title = {"paid":"PAGADAS", "deck":"MAZO", "resources":"RECURSOS"}[z]
	info.add_child(label(title, 10, MUTED))
	var count = label("", 24, TEXT)
	info.add_child(count)
	register_count(count, human, z)
	if z == "paid" and not game.reserved[human].is_empty(): info.add_child(label("%d libres" % game.reserved[human].size(), 9, MINT))
	holder.tooltip_text = title + (" · " + game.title(uid) + " · Doble clic para leer" if uid != -1 else "")

func shared_domain(parent):
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(center)
	# Neutral UI destination; the engine retains the card's owner for disposal.
	var holder = zone(center, "domain", -1, game.domain_uid, Color(1.0, 0.985, 0.94, 0.82))
	holder.custom_minimum_size = Vector2(300, 82 if compact_layout else 128)
	holder.set_meta("pile", true)
	holder.set_meta("shared_domain", true)
	holder.modulate.a=1.0
	var row = box(holder, false, 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label("ZONA DE\nDOMINIO", 12, GOLD))
	var mount = Control.new()
	var domain_size = Vector2(42,60) if compact_layout else Vector2(70,100)
	mount.custom_minimum_size = domain_size
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mount)
	if game.domain_uid != -1:
		var picture = image_card(game.domain_uid, domain_size.x, domain_size.y)
		picture.size = domain_size
		picture.pivot_offset=picture.size/2
		picture.rotation=0.0 if game.instances[game.domain_uid].owner==human else PI
		mount.add_child(picture)
	holder.set_meta("pile_image", mount)
	attach_indicator(holder, false, mount)
	var info = box(row, true, 0)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	if game.domain_uid != -1: info.add_child(label("En juego", 12, MUTED))
	var inspect = button("Ver", open_card_detail.bind(game.domain_uid), game.domain_uid == -1)
	inspect.custom_minimum_size.y = 24
	inspect.add_theme_font_size_override("font_size", 11)
	forward_drag_from(inspect, holder)
	info.add_child(inspect)
	holder.tooltip_text = "Un único Dominio para ambos jugadores. Arrastra un Dominio aquí."
	if game.domain_uid != -1: holder.tooltip_text += "\n" + game.title(game.domain_uid) + " · Doble clic para leer"

func human_hand(parent):
	var holder = zone(parent, "hand", human, -1, Color(1.0, 0.985, 0.94, 0.90))
	fill(holder)
	holder.custom_minimum_size.x = 650 if compact_layout else 850
	var v = box(holder, true, 5)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var header = box(v, false)
	var count = fill(label("", 14, MINT))
	header.add_child(count)
	register_count(count, human, "hand", "TU MANO · " + game.players[human].name + " · ", " cartas")
	hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = (96 if compact_layout else (100 if tutorial.active else CARD_SIZE.y)) + 12
	fill(hand_scroll)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(hand_scroll)
	var h = box(hand_scroll, false, 5)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	for uid in game.players[human].hand: card(h, uid, "hand", human, 70 if compact_layout else CARD_SIZE.x, 96 if compact_layout else (100 if tutorial.active else CARD_SIZE.y))

func compact_log(parent):
	log_panel = panel(parent, Color(1.0, 0.985, 0.94, 0.94))
	var v = box(log_panel, true, 3)
	v.custom_minimum_size.x = 280
	var head = box(v, false)
	head.add_child(fill(label("REGISTRO", 11, MUTED)))
	var more = button("Ampliar", show_log)
	more.custom_minimum_size.y = 24
	more.add_theme_font_size_override("font_size", 11)
	head.add_child(more)
	var history = RichTextLabel.new()
	history.custom_minimum_size = Vector2(280, 100)
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.scroll_following = true
	history.add_theme_font_size_override("normal_font_size", 12)
	history.text = "\n".join(game.log_lines.slice(maxi(0, game.log_lines.size() - 5)))
	v.add_child(history)

func show_detail(uid):
	if visible_to_human(uid): focus_uid = uid

func open_card_detail(uid):
	if mobile_layout:
		if screen=="table" and visible_to_human(uid): mobile.detail(game.printed_code(uid),uid)
		return
	var passive=true
	if screen != "table" or not visible_to_human(uid): return
	show_detail(uid)
	var center = overlay("inspection_detail" if passive else "detail")
	var shade = center.get_parent()
	var outer = box(panel(center), true, 10)
	outer.custom_minimum_size = Vector2(980, 665)
	var row = box(outer, false, 25)
	row.add_child(image_card(uid, 375, 565))
	var text = box(row, true, 14)
	text.custom_minimum_size.x = 520
	var d = game.definition(uid)
	var title = label(d.nombre, 32, GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	text.add_child(label(d.clase + " · Código " + d.codigo, 17, MUTED))
	if d.clase != "Recurso": text.add_child(label("Coste %d" % int(d.coste), 22, MINT))
	if d.clase == "Aliado":
		var stats = "Fuerza impresa %d" % int(d.fuerza)
		if uid in game.field(game.instances[uid].owner): stats += " · Actual %d" % game.force(uid)
		text.add_child(label(stats, 21, MINT))
		text.add_child(label("Tipo " + d.tipo_aliado, 17, MUTED))
	var ability = RichTextLabel.new()
	ability.custom_minimum_size = Vector2(500, 300)
	ability.add_theme_font_size_override("normal_font_size", 22)
	ability.add_theme_color_override("default_color", TEXT)
	ability.set_meta("card_ability_text",true)
	ability.text = d.texto_juego if not d.texto_juego.is_empty() else "Paga el coste de tus cartas moviendo este Recurso a Pagadas."
	text.add_child(ability)
	if game.phase in ["blocks", "events"] and uid in game.blocks.values():
		text.add_child(label("Bloquea a " + game.title(game.blocks.find_key(uid)), 18, GOLD))
	if game.phase in ["blocks", "events"] and game.blocks.has(uid): text.add_child(label("Bloqueado por " + game.title(game.blocks[uid]), 18, GOLD))
	if game.actor == human and can_activate(uid):
		text.add_child(button("Usar habilidad", use_card_action.bind(uid, true), false, true))
	if game.actor == human and game.code(uid) == "0134" and game.location(uid).get("zone") == "graveyard" and game.can_play(uid):
		text.add_child(button("Jugar desde Cementerio · Coste 7", use_card_action.bind(uid, false), false, true))
	outer.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func use_card_action(uid, ability):
	if not overlay_shades.is_empty():close_overlay(overlay_shades.back())
	if ability:perform(game.activate.bind(uid))
	else:request_card(uid)


func action_bar(parent):
	var v = box(parent, true, 6)
	if tutorial.active:
		tutorial.render_actions(v);return
	v.add_child(label("ACCIONES", 11, MUTED))
	var instruction = label("", 15, MINT)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size.x = 305 if compact_layout else 385
	v.add_child(instruction)
	var controls = HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 6)
	v.add_child(controls)
	var yours = game.actor == human
	if yours and choice_dismissed and not game.pending.is_empty():controls.add_child(button("Resolver elección",resume_choice,false,true))
	if online.in_match() and online.waiting_action():
		instruction.text = online.status
	elif presenting:
		instruction.text = "Resolviendo el movimiento de las cartas…"
	elif not game.payment_request.is_empty() and yours:
		instruction.text = "%s: arrastra %d Recurso(s) más a PAGADAS." % [game.title(game.payment_request.uid), int(game.payment_request.cost) - game.reserved[human].size()]
		if game.payment_request.get("kind", "") == "ability":
			instruction.text = "%s → %s: arrastra %d Recurso(s) a PAGADAS para activar la habilidad." % [game.title(game.payment_request.uid),game.title(game.payment_request.target),int(game.payment_request.cost)-game.reserved[human].size()]
		controls.add_child(button("Cancelar habilidad" if game.payment_request.get("kind", "") == "ability" else "Cancelar jugada", cancel_payment))
	elif not game.pending.is_empty():
		if yours and game.pending.kind == "end_discard": instruction.text = "Arrastra %d carta(s) de tu Mano al Cementerio para quedar con ocho." % int(game.pending.max)
		elif yours and game.pending.kind == "limit_keep": instruction.text = "Escuela de Vuelo: descarta %d Aliado(s) al Cementerio para quedar con cuatro." % (game.field(human).size() - 4)
		else: instruction.text = "Completa la elección de cartas." if yours else "El rival está eligiendo sus cartas…"
	elif not yours:
		instruction.text = "El rival está jugando. Puedes consultar tus cartas con doble clic."
	else:
		match game.phase:
			"setup":
				instruction.text = "Mano inicial · cambios 6 → 5 → 5 · usados %d/2" % game.changes[human]
				controls.add_child(button("Cambiar mano", change_hand, game.changes[human] >= 2))
				controls.add_child(button("Conservar mano", keep_hand, false, true))
			"resource":
				instruction.text = "Arrastra un Recurso de tu Mano a RECURSOS."
				controls.add_child(button("Continuar sin Recurso", skip_resource, false, true))
			"main":
				instruction.text = "Arrastra cartas para jugarlas o Aliados a ATAQUE. Los Eventos se sueltan sobre el tablero o su objetivo."
				controls.add_child(button("Declarar ataque (%d)" % draft.size(), declare_attack, draft.is_empty(), true))
				controls.add_child(button("Robar y terminar", finish_turn, false, true))
			"blocks":
				instruction.text = "Arrastra cada defensor sobre el atacante que bloqueará."
				controls.add_child(button("Confirmar bloqueos", finish_blocks, false, true))
			"events":
				instruction.text = "Puedes responder con Eventos sobre el tablero o su objetivo, antes del daño."
				controls.add_child(button("Pasar daño", pass_priority, false, true))
			"after_combat":
				instruction.text = "Arrastra tu Mazo a tu Mano para robar y terminar."
				controls.add_child(button("Robar y terminar", finish_turn, false, true))
	if not presenting and yours and game.payment_request.is_empty() and not game.reserved[human].is_empty(): controls.add_child(button("Devolver pago (%d)" % game.reserved[human].size(), cancel_payment))
	if not game.error.is_empty():
		var error_text = label(game.error, 13, GOLD)
		error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(error_text)
	drag_hint = label("", 12, TARGET_COLOR)
	drag_hint.custom_minimum_size.y = 18
	drag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(drag_hint)

func drag_payload(uid, source_zone, p):
	if online.in_match() and online.waiting_action(): return null
	if screen != "table" or presenting or fx.busy or not started or modal_open or game.winner != -1 or game.actor != human or p != human: return null
	if source_zone == "deck":
		if game.phase in ["main", "after_combat"] and game.pending.is_empty() and game.payment_request.is_empty(): return {"kind":"deck", "uid":-1, "owner":p, "from":"deck"}
		return null
	if not game.instances.has(uid): return null
	var loc = game.location(uid)
	if loc.get("player", -1) != human: return null
	var allowed = false
	if not game.pending.is_empty(): allowed = game.pending.kind in ["end_discard", "limit_keep"] and uid in game.pending.options
	elif loc.zone == "resources": allowed = game.can_reserve(uid)
	elif loc.zone == "paid": allowed = uid in game.reserved[human]
	elif loc.zone in ["hand", "graveyard"]: allowed = game.can_play(uid)
	elif loc.zone == "object": allowed = can_activate(uid)
	elif loc.zone in ["defense", "attack"]: allowed = (game.phase == "main" and game.can_attack(uid)) or can_activate(uid) or (game.phase == "blocks" and loc.zone == "defense")
	if not allowed: return null
	return {"kind":"card", "uid":uid, "owner":p, "from":source_zone}

func valid_target(source, target):
	if not game.instances.has(target): return false
	var d = game.definition(source)
	if d.clase == "Objeto": return target in game.field(human) and game.instances[target].object == -1
	if game.code(source) == "0116": return target in game.field(computer) and int(game.definition(target).coste) <= 2
	if game.code(source) == "0133": return target in game.all_permanents()
	return false

func can_drop(data, destination):
	if online.in_match() and online.waiting_action(): return false
	if presenting or fx.busy or screen != "table": return false
	if typeof(data) != TYPE_DICTIONARY or not data.has("kind") or not data.has("owner") or data.owner != human or game.actor != human or game.winner != -1 or not started: return false
	if tutorial.active and not tutorial.allows_drop(data,destination):return false
	var z = destination.zone
	var p = destination.owner
	var target = destination.get("target", -1)
	if data.kind == "deck": return p == human and z == "hand" and game.phase in ["main", "after_combat"] and game.pending.is_empty() and game.payment_request.is_empty()
	var uid = data.get("uid", -1)
	if not game.instances.has(uid): return false
	var loc = game.location(uid)
	if loc.get("player", -1) != human: return false
	if not game.pending.is_empty(): return int(game.pending.player) == human and game.pending.kind in ["end_discard", "limit_keep"] and uid in game.pending.options and p == human and z == "graveyard"
	if loc.zone == "resources": return p == human and z == "paid" and game.can_reserve(uid)
	if loc.zone == "paid": return p == human and z == "resources" and uid in game.reserved[human]
	if not game.payment_request.is_empty(): return false
	if loc.zone in ["hand", "graveyard"]:
		if not game.can_play(uid): return false
		var d = game.definition(uid)
		if d.clase == "Recurso": return p == human and z == "resources"
		if d.clase == "Aliado": return p == human and z == "defense"
		if d.clase == "Dominio": return z == "domain"
		if d.clase == "Objeto": return valid_target(uid, target)
		if d.clase == "Evento":
			if valid_target(uid, target): return true
			if game.code(uid) in ["0116", "0133"] and target != -1 and (destination.get("card", false) or z == "domain"): return false
			return z in ["board", "attack", "defense", "deck", "resources", "paid", "graveyard", "burned", "domain"]
	if p == human and z == "deck" and can_activate(uid): return true
	if uid in game.field(human):
		if game.phase == "main" and game.can_attack(uid): return p == human and ((z == "attack" and uid not in draft) or (z == "defense" and uid in draft))
		if game.phase == "blocks" and uid in game.players[human].defense:
			if p == human and z == "defense": return uid in game.blocks.values()
			if target not in game.attacks or p != computer: return false
			if game.unblockable(target) and not (game.domain_uid != -1 and game.code(game.domain_uid) == "0122"): return false
			return true
	return false

func apply_drop(data, destination):
	if not can_drop(data, destination): return false
	var source_uid=int(data.get("uid",-1))
	if source_uid!=-1 and game.location(source_uid).get("zone","") in ["hand","graveyard"] and game.pending.is_empty():
		var requested_target=destination.get("target",-1)
		return request_card(source_uid,requested_target if valid_target(source_uid,requested_target) else -1)
	if online.in_match(): return apply_online_drop(data,destination)
	var old_layout = capture_layout()
	game.error = ""
	var success = false
	var uid = data.get("uid", -1)
	var z = destination.zone
	var target = destination.get("target", -1)
	if data.kind == "deck": success = game.finish_turn()
	elif not game.pending.is_empty(): success = game.discard_by_drag(uid)
	else:
		var loc = game.location(uid)
		if loc.zone == "resources": success = game.reserve_resource(uid)
		elif loc.zone == "paid": success = game.refund_resource(uid)
		elif loc.zone in ["hand", "graveyard"]: success = game.request_play(uid, target if valid_target(uid, target) else -1)
		elif z == "deck": success = game.activate(uid)
		elif game.phase == "main":
			if z == "attack":
				draft.append(uid)
				game.visual_move(uid, "defense", "attack", {"visual_only":true})
			else:
				draft.erase(uid)
				game.visual_move(uid, "attack", "defense", {"visual_only":true})
			success = true
		elif game.phase == "blocks":
			if z == "defense" and destination.owner == human:
				for a in game.blocks.keys():
					if game.blocks[a] == uid: success = game.assign_block(a, -1)
			else:
				for a in game.blocks.keys():
					if game.blocks[a] == uid and a != target: game.assign_block(a, -1)
				success = game.assign_block(target, uid)
	schedule_presentation(old_layout)
	return success

func drag_preview(uid, _source_zone):
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style())
	p.modulate.a = 0.9
	if uid != -1: p.add_child(image_card(uid, CARD_SIZE.x, CARD_SIZE.y))
	else: p.add_child(asset_image("dorso.jpg", CARD_SIZE.x, CARD_SIZE.y))
	attach_indicator(p, true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func clear_tap_selection():
	tap_selection.clear()
	clear_highlights()

func tap_surface(surface):
	if screen != "table" or surface.zone in ["choice", "inspection"]: return false
	if presenting or fx.busy or modal_blocks_play(): return false
	if tutorial.active: return tutorial.click_surface(surface)
	var destination = surface.descriptor()
	if not tap_selection.is_empty():
		var source_uid = int(tap_selection.get("uid", -1))
		if surface.uid == source_uid and source_uid != -1:
			clear_tap_selection()
			return true
		if can_drop(tap_selection, destination):
			var payload = tap_selection.duplicate(true)
			clear_tap_selection()
			return apply_drop(payload, destination)
	var data = drag_payload(surface.uid, surface.zone, surface.card_owner)
	if data == null: return false
	clear_tap_selection()
	tap_selection = data.duplicate(true)
	highlight_destinations(tap_selection)
	if is_instance_valid(drag_hint): drag_hint.text = "Toca el destino resaltado. Mantén pulsada una carta para leerla."
	return true

func highlight_destinations(data):
	current_drag = data.duplicate()
	for node in targets:
		if is_instance_valid(node):
			paint_indicator(node, "candidate" if can_drop(data, node.descriptor()) else ("selected" if node.get_meta("persistent_selected", false) else "idle"))
	update_drag_feedback()
	refresh_force_badges()
	if tutorial.active and screen=="table":
		tutorial.poll()
		return
	advance_automatic_cost()
	refresh_passive_overlays()

func clear_highlights():
	if current_drag.is_empty() and not is_instance_valid(hovered_target): return
	current_drag.clear()
	hovered_target = null
	for node in targets:
		if is_instance_valid(node): paint_indicator(node, "selected" if node.get_meta("persistent_selected", false) else "idle")
	if is_instance_valid(drag_hint): drag_hint.text = ""

func attach_indicator(node, selected = false, picture = null):
	if node.has_meta("indicator"):
		var old = node.get_meta("indicator")
		if is_instance_valid(old):
			old.get_parent().remove_child(old)
			old.queue_free()
	var outline = Panel.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.z_index = 10
	var anchor = picture if picture != null else node
	anchor.add_child(outline)
	node.set_meta("indicator", outline)
	node.set_meta("persistent_selected", selected)
	paint_indicator(node, "selected" if selected else "idle")

func paint_indicator(node, role):
	if not node.has_meta("indicator"): return
	var outline = node.get_meta("indicator")
	if not is_instance_valid(outline): return
	node.set_meta("indicator_role", role)
	if outline.get_meta("painted_role", "") == role: return
	outline.set_meta("painted_role", role)
	outline.visible = role != "idle"
	var color = TARGET_COLOR if role == "hover" else (INVALID_COLOR if role == "invalid" else GOLD)
	var s = StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = Color(color, 0.55 if role == "candidate" else 1.0)
	s.set_border_width_all(1 if role == "candidate" else 3)
	s.set_corner_radius_all(6)
	s.set_expand_margin_all(3)
	s.shadow_size = 7 if role in ["hover", "selected", "source"] else 0
	s.shadow_color = Color(color, 0.30)
	outline.add_theme_stylebox_override("panel", s)

func forward_drag_from(control, holder):
	control.set_drag_forwarding(holder._get_drag_data, holder._can_drop_data, holder._drop_data)

func mouse_surface():
	var node = get_viewport().gui_get_hovered_control()
	while node != null:
		if node in targets: return node
		node = node.get_parent()
	return null

func effective_destination(fallback):
	var target = mouse_surface() if not current_drag.is_empty() else null
	return target.descriptor() if is_instance_valid(target) else fallback.descriptor()

func update_drag_feedback():
	if not tap_selection.is_empty(): return
	if current_drag.is_empty() or presenting or screen != "table": return
	var target = mouse_surface()
	if is_instance_valid(hovered_target) and hovered_target != target:
		paint_indicator(hovered_target, "candidate" if can_drop(current_drag, hovered_target.descriptor()) else ("selected" if hovered_target.get_meta("persistent_selected", false) else "idle"))
	for node in targets:
		if not is_instance_valid(node): continue
		var source_match = node.card_owner == human and ((current_drag.kind == "deck" and node.zone == "deck") or (current_drag.get("uid", -1) != -1 and node.uid == current_drag.uid))
		if source_match: paint_indicator(node, "source")
	hovered_target = target
	if not is_instance_valid(target):
		if is_instance_valid(drag_hint): drag_hint.text = "Suelta sobre una zona o carta resaltada."
		return
	if current_drag.get("uid", -1) != -1 and target.uid == current_drag.uid: return
	var allowed = can_drop(current_drag, target.descriptor())
	paint_indicator(target, "hover" if allowed else "invalid")
	if is_instance_valid(drag_hint):
		drag_hint.text = "Suelta para aplicar la acción." if allowed else "Ese destino no admite esta carta."
		drag_hint.add_theme_color_override("font_color", TARGET_COLOR if allowed else INVALID_COLOR)

func overlay(kind = "generic"):
	modal_open = true
	var shade = ColorRect.new()
	shade.theme = self.theme
	shade.color = Color(BG, 0.96)
	shade.set_meta("overlay_kind", kind)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(shade)
	add_interface_close(shade)
	if kind not in PASSIVE_OVERLAYS and overlay_shades.any(func(n):return n.get_meta("overlay_kind","") in PASSIVE_OVERLAYS):
		modal_layer.move_child(shade,0)
		overlay_shades.push_front(shade)
	else:overlay_shades.append(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	shade.move_child(shade.get_child(0),shade.get_child_count()-1)
	var semantic = screen + ":" + kind + ":" + str(overlay_shades.size())
	if screen == "table" and kind == "generic": semantic += ":" + str(game.pending)
	if semantic != last_overlay_semantic:
		last_overlay_semantic = semantic
		sound.play_effect("popup")
		pop_in.call_deferred(center)
	if mobile_layout: mobile.fit_overlays.call_deferred()
	return center

func interface_nodes(node):
	var found=[node]
	for child in node.get_children():
		if not child.is_queued_for_deletion():found.append_array(interface_nodes(child))
	return found

func decorate_navigation():
	for node in interface_nodes(self):
		if node is LineEdit and not node.has_meta("enter_confirm") and node.get_signal_connection_list("text_submitted").is_empty():
			node.set_meta("enter_confirm",true)
			node.text_submitted.connect(func(_value):
				var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ENTER;_unhandled_key_input(event))
	# Existing return/close controls keep their original labels.
	if screen == "account" and not interface_nodes(self).any(func(n):return n is Button and (n.text.begins_with("Volver") or n.text=="Inicio")):
		var back=button("←",account_back)
		back.set_meta("navigation_control",true);back.custom_minimum_size=Vector2(36,32)
		back.position=Vector2(get_viewport_rect().size.x-52,10);back.tooltip_text="Volver"
		add_child(back)
	for shade in overlay_shades: remove_redundant_close(shade)

func remove_redundant_close(shade):
	if not is_instance_valid(shade):return
	var controls=interface_nodes(shade)
	var has_return=controls.any(func(n):return n is Button and not n.has_meta("interface_close") and (n.text.begins_with("Volver") or n.text in ["Inicio","Cerrar","Continuar","Cancelar","Salir de la sala","Salir","Listo","Entendido"]))
	if has_return:
		for node in controls:
			if node.has_meta("interface_close"):
				node.get_parent().remove_child(node);node.queue_free()

func account_back():
	if account.signed_in() or guest:go_home()
	else:screen="intro";render()

func table_back():
	if game.winner==-1:confirm_abandon_match()
	elif online.in_match():online.leave()
	else:go_home()

func add_interface_close(shade):
	var close=button("✕",close_interface.bind(shade))
	close.set_meta("interface_close",true);close.set_meta("navigation_control",true)
	close.tooltip_text="Cerrar";close.custom_minimum_size=Vector2(36,32)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-52;close.offset_right=-16;close.offset_top=10;close.offset_bottom=42
	shade.add_child(close)
	remove_redundant_close.call_deferred(shade)

func close_interface(shade):
	if not is_instance_valid(shade):return
	var kind=shade.get_meta("overlay_kind","")
	if kind=="inspection":inspection.close();return
	if kind=="auto_cost":close_overlay(shade);return
	if kind=="deck_design":deck_builder.cancel_design();return
	# Closing a receipt uses its real acknowledge action, never loses the reward.
	for node in interface_nodes(shade):
		if node is Button and str(node.get_meta("navigation_original",node.text))=="Continuar":
			if not node.disabled:node.pressed.emit()
			return
	if kind=="result":table_back();return
	if kind=="generic" and screen=="table" and not game.pending.is_empty():
		choice_dismissed=true;close_overlay(shade);render();return
	close_overlay(shade)

func resume_choice():
	choice_dismissed=false;render()

func show_start():
	open_random()

func start_match(p, fixed_opponent = {}):
	if not online.room.is_empty():
		show_notice("Sala multijugador","Cierra tu sala multijugador antes de iniciar una partida individual.")
		return
	if not can_enter_play() or p<0 or p>=play_decks().size(): return
	if selected_challenge_stage>0 and not bool(challenge_state(selected_challenge_stage).get("unlocked",false)): return
	var opponent = fixed_opponent.duplicate(true)
	if opponent.is_empty() and selected_event_battle: opponent = JSON.parse_string(FileAccess.get_file_as_string("res://data/mazo_halloween.json"))
	if opponent.is_empty(): opponent = challenge_opponent(selected_challenge_stage) if selected_challenge_stage>0 else game.decklists[deck_rng.randi_range(0,game.decklists.size()-1)].duplicate(true)
	pending_match = {"deck_id":str(play_decks()[p].id),"stage":selected_challenge_stage,"event_battle":selected_event_battle,"opponent":opponent}
	screen = "versus"
	render()

func begin_prepared_match():
	if pending_match.is_empty() or rewards.preparing or collection.busy or account.busy: return
	practice_match=false
	var expected_pending = pending_match.duplicate(true)
	var expected_owner = account.player_id()
	var p = -1
	for index in range(play_decks().size()):
		if play_decks()[index].id == pending_match.deck_id: p=index
	selected_challenge_stage = int(pending_match.stage)
	if not can_enter_play(): return
	if p < 0 or p >= play_decks().size(): return
	if not guest:
		var obtained = owned_deck(play_decks()[p].id)
		if obtained.is_empty(): return
	if selected_challenge_stage > 0:
		var stage_state = challenge_state(selected_challenge_stage)
		if guest or not bool(stage_state.get("unlocked", false)): return
	var confirmed_deck = play_decks()[p].duplicate(true)
	if not guest:
		confirmed_deck = await rewards.prepare_match(str(expected_pending.deck_id), int(expected_pending.stage),bool(expected_pending.get("event_battle",false)))
		if expected_owner != account.player_id() or pending_match != expected_pending or screen != "versus": return
		if confirmed_deck.is_empty():
			render()
			return
	presentation_generation += 1
	fx.cancel()
	sound.stop_effects()
	selected_deck_index = p
	active_deck_id = str(confirmed_deck.id)
	human = p % 2
	computer = 1 - human
	game.manual_payment = [human == 0, human == 1]
	var match_decks = [null, null]
	match_decks[human] = confirmed_deck
	active_challenge_stage = selected_challenge_stage
	active_event_battle = bool(expected_pending.get("event_battle",false))
	if active_event_battle:
		var confirmed_opponent = collection.last_reply.get("event_opponent",{})
		if confirmed_opponent.is_empty(): return
		pending_match.opponent = confirmed_opponent.duplicate(true)
	match_decks[computer] = pending_match.opponent.duplicate(true)
	last_opponent_deck = match_decks[computer].duplicate(true)
	if match_decks[computer] == null or match_decks[computer].is_empty(): return
	game.new_game(-1, match_decks)
	pending_match = {}
	announced_turn = 0
	winner_announced = false
	clear_turn_banner()
	match_started.emit(str(match_decks[human].id), active_challenge_stage)
	started = true
	screen = "table"
	automation_pause = false
	bot_clock = 0.0
	draft.clear()
	focus_uid = -1
	schedule_presentation({})

func show_choice():
	if mobile_layout and mobile.choice(): return
	var c = game.pending
	if c.kind == "counter":
		show_counter_choice()
		return
	var v = box(panel(overlay()))
	v.custom_minimum_size = Vector2(1080, 650)
	v.add_child(centered_label(c.title, 24, MINT))
	var instruction = "Pulsa para seleccionar. Seleccionadas %d / %d." % [choice_selected.size(), int(c.max)]
	if c.kind == "reorder": instruction = "Elige primero la carta que quedará arriba del Mazo, después la segunda y la tercera."
	elif c.kind == "sacrifice_ally": instruction = "Envía un Aliado propio al Cementerio. Si Viborín sigue en juego, gana +3 de Fuerza hasta el final del turno."
	elif c.kind == "grant_unblockable": instruction = "Elige un Aliado propio. Al confirmar, paga 1 Recurso para que sea Imbloqueable hasta el final del turno."
	var choice_instruction = centered_label(instruction, 15, MUTED)
	choice_instruction.custom_minimum_size.x = 1020
	choice_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(choice_instruction)
	if c.kind == "reorder":
		var names = []
		for i in range(choice_selected.size()): names.append("%d. %s" % [i + 1, game.title(choice_selected[i])])
		v.add_child(centered_label(" · ".join(names), 14, GOLD))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1050, minf(495,get_viewport_rect().size.y-270))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("choice_scroll",true)
	scroll.scroll_vertical = choice_scroll_offset
	scroll.set_deferred("scroll_vertical",choice_scroll_offset)
	restore_choice_scroll.call_deferred(scroll,choice_scroll_offset)
	v.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	var choices_center = CenterContainer.new()
	choices_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(choices_center)
	choices_center.add_child(grid)
	var shown_options = c.options.duplicate()
	if c.kind=="search_hand": shown_options.sort_custom(func(a,b):return game.code(a)<game.code(b) if game.code(a)!=game.code(b) else a<b)
	for uid in shown_options:
		var view = card(grid, uid, "choice", human, 137, 183, uid in choice_selected)
		view.clicked = select_choice.bind(uid)
	var controls = box(v, false)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	if c.kind == "search_hand": v.add_child(centered_label("La carta buscada se mostrará en el registro.", 14, MUTED))
	elif c.kind in ["sacrifice_ally", "grant_unblockable"]: v.add_child(centered_label("Cancelar conserva el uso de esta habilidad y no paga su coste.", 14, MUTED))
	if c.optional: controls.add_child(button("Omitir / cancelar", skip_choice))
	controls.add_child(button("Confirmar", confirm_choice, choice_selected.size() < int(c.min) or choice_selected.size() > int(c.max), true))

func show_counter_choice():
	var c = game.pending
	var v = box(panel(overlay("counter")), true, 15)
	v.custom_minimum_size = Vector2(940, 610)
	v.add_child(centered_label("Tu rival juega " + game.title(c.source), 26, GOLD))
	var row = box(v, false, 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card(row, c.source, "announced", computer, 240, 340)
	var explanation = box(row, true, 14)
	explanation.custom_minimum_size.x = 620
	var info = label("Puedes barajar tu Serandimini para anular esta carta antes de que se resuelva. El rival ya pagó su Coste.", 21, TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.add_child(info)
	explanation.add_child(centered_label("Elige la Serandimini que barajarás:", 17, MUTED))
	var options = box(explanation, false, 12)
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	for uid in c.options:
		var view = card(options, uid, "choice", human, 130, 178, uid in choice_selected)
		view.clicked = select_choice.bind(uid)
	var controls = box(v, false, 14)
	controls.add_child(fill(button("Dejar jugar", skip_choice)))
	controls.add_child(fill(button("Anular con Serandimini", confirm_choice, choice_selected.size() != 1, true)))

func restore_choice_scroll(scroll,offset):
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll): scroll.scroll_vertical=offset

func select_choice(uid):
	for node in find_children("*","ScrollContainer",true,false):
		if node.has_meta("choice_scroll"): choice_scroll_offset = node.scroll_vertical
	if uid in choice_selected: choice_selected.erase(uid)
	elif choice_selected.size() < int(game.pending.max): choice_selected.append(uid)
	elif int(game.pending.max) == 1: choice_selected = [uid]
	render()

func confirm_choice():
	var selected = choice_selected.duplicate()
	choice_selected.clear()
	choice_key = ""
	perform(game.choose.bind(selected))

func skip_choice():
	choice_selected.clear()
	choice_key = ""
	perform(game.skip_choice)

func inspect_zone(p, source_zone):
	inspection.open(p,source_zone)

func modal_blocks_play():
	return false

func cancel_block_on_click(uid):
	if modal_open or presenting or fx.busy or game.phase!="blocks" or game.actor!=human:return false
	if game.location(uid).get("player",-1)!=human:return false
	for attacker in game.blocks:
		if game.blocks[attacker]==uid:
			return perform(game.assign_block.bind(attacker,-1))
	return false

func show_help():
	var v = box(panel(overlay("help")))
	v.custom_minimum_size = Vector2(1000, 700)
	v.add_child(label("JUEGA ARRASTRANDO TUS CARTAS", 28, GOLD))
	var t = RichTextLabel.new()
	t.custom_minimum_size = Vector2(970, 585)
	t.add_theme_font_size_override("normal_font_size", 19)
	t.text = "ACCIONES Y ZONAS\nEl panel Acciones reúne las instrucciones y los botones junto al registro. El Dominio es compartido y queda al centro de la mesa. Pagadas, Mazo y Recursos se ordenan de arriba hacia abajo. Cementerio y Quemadas tienen casillas separadas; Ver abre su contenido.\n\nINDICADORES\nDorado: carta de origen o seleccionada. Verde: destino válido bajo el cursor. Rojizo: destino no permitido. Las búsquedas muestran una marca y el reordenamiento muestra números.\n\nLECTURA Y REGISTRO\nHaz doble clic sobre una carta visible para ampliarla. Esc cierra el detalle. El registro compacto se puede ampliar desde su botón.\n\nRECURSOS Y PAGOS\nMano → Recursos: baja tu Recurso al empezar el turno. Si no tienes Recursos en Mano, se pasa a Acciones automáticamente después de reagrupar.\nRecursos → Pagadas: prepara el pago de una carta. También puedes arrastrar primero la carta y pagar después, moviendo los Recursos que pide.\nUn Recurso preparado y sin gastar puede volver de Pagadas a Recursos. Los ya gastados se reagrupan en tu siguiente turno.\n\nJUGAR Y COMBATIR\nMano → Defensa: juega un Aliado.\nMano → Aliado propio: equipa un Objeto.\nMano → Dominio: reemplaza el Dominio activo.\nMano → tablero o sobre un objetivo válido: juega un Evento, pagando su coste. No requiere una zona propia.\nDefensa → Ataque: prepara tus atacantes. Puedes devolverlos a Defensa antes de pulsar Declarar ataque.\nDefensor → Atacante rival: asigna un bloqueo. Puedes cambiarlo arrastrando sobre otro atacante, o quitarlo volviendo a tu línea de Defensa. Haz doble clic en una carta para consultar su bloqueo.\nMazo → Mano: roba y termina el turno. También puedes usar el botón.\nMano → Cementerio: descarta cuando superas ocho al terminar.\nEscuela de Vuelo: arrastra al Cementerio los Aliados que no conservarás.\n\nHABILIDADES ACLARADAS\nBigotes → tu Mazo: busca un Objeto una vez en cada turno de su dueño.\nOscarksss → tu Mazo: con tres en juego, busca a Papito en Mazo o Cementerio.\nPastelito de manjar → tu Mazo: si el portador es Lucha, busca un Aliado de Coste 2 o menos, una vez por turno propio. También puedes usar la habilidad desde el detalle.\nGuitarramala: arrástralo del Cementerio a Defensa, o ábrelo en Ver → doble clic y pulsa Jugar desde Cementerio. Su Coste se paga igual que desde la Mano.\nSerandimini: al jugar el rival una carta que no sea Recurso, puedes elegir anularla en la ventana de respuesta.\nAzul: tiene +1 mientras está en Ataque y +2 mientras bloquea. En Defensa sin bloquear no tiene bono.\n\nAUTOMATISMOS Y ELECCIONES\nEl juego reagrupa al iniciar el turno, aplica daño y completa el mínimo de tres cartas. Las búsquedas y el orden del Mazo se eligen pulsando cartas en una ventana. Declarar ataque y confirmar bloqueos conservan botones para cerrar la elección del grupo.\n\nEl rival recibe al azar Mazo Kajido, Mazo Papito o Mazo Flaan, incluso el mismo que tú, y juega con las mismas reglas. No ve tu Mano ni el orden de tu Mazo. Multijugador permite una sala privada para dos cuentas: comparte el código de 8 caracteres. El creador debe mantener su juego abierto."
	v.add_child(t)
	v.add_child(button("Volver a la mesa", render))

func new_match_dialog():
	var v = box(panel(overlay()))
	v.add_child(label("¿Comenzar otra partida?", 25, GOLD))
	v.add_child(label("La partida actual se reemplazará. Elige tu mazo.", 17))
	v.add_child(button("Partida Aleatoria", open_random))
	v.add_child(button("Desafío AAMIX", open_challenges))
	v.add_child(button("Continuar la partida actual", render))

func block_marker_visible(uid):
	return (game.winner == -1 or presenting) and game.combat_roles.get(uid, "") == "block"

func show_winner():
	fx.cancel(false)
	clear_highlights()
	clear_turn_banner()
	sound.set_screen(screen, active_challenge_stage > 0, true)
	var victory = game.winner == human
	var v = box(panel(overlay("result"),PANEL,"gold"),true,22)
	v.custom_minimum_size = Vector2(740,390)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var result_art = asset_image("estetica_v014/resultado_victoria.png" if victory else "estetica_v014/resultado_derrota.png",680,230,true)
	result_art.set_meta("result_art","victory" if victory else "defeat")
	v.add_child(result_art)
	var controls = box(v,false,18)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	if online.in_match():
		controls.add_child(button("Revancha",online_ui.request_rematch,false,true))
		controls.add_child(button("Salir de la sala",online.leave))
	elif practice_match:
		controls.add_child(button("Volver",open_single,false,true))
	elif active_challenge_stage>0:
		if victory: controls.add_child(button("Siguiente",open_challenges,false,true))
		else:
			controls.add_child(button("Revancha",rematch,false,true))
			controls.add_child(button("Volver",open_challenges))
	else:
		controls.add_child(button("Revancha",rematch,false,true))
		controls.add_child(button("Volver",go_home))
	if not winner_announced:
		winner_announced=true
		sound.play_effect("victoria" if victory else "derrota")
		if not online.in_match() and not practice_match: match_finished.emit(victory)

func change_hand():
	perform(game.mulligan)

func keep_hand():
	perform(game.keep_hand)

func skip_resource():
	perform(game.skip_resource)

func cancel_payment():
	perform(game.cancel_payment)

func declare_attack():
	var attackers = draft.duplicate()
	draft.clear()
	perform(game.declare_attack.bind(attackers))

func finish_blocks():
	perform(game.finish_blocks)

func pass_priority():
	perform(game.pass_priority)

func finish_turn():
	draft.clear()
	perform(game.finish_turn)

func perform(action):
	if presenting or fx.busy or screen != "table": return false
	if tutorial.active and not tutorial.allows_action(str(action.get_method()),action.get_bound_arguments()):return false
	if online.in_match():
		if action.get_object() != game: return false
		return online.submit(str(action.get_method()),action.get_bound_arguments())
	var old_layout = capture_layout()
	var result = action.call()
	schedule_presentation(old_layout)
	return result

func schedule_presentation(old_layout):
	var packet = game.take_visual_events()
	clear_highlights()
	presentation_generation += 1
	presenting = true
	start_presentation.call_deferred(old_layout, packet, presentation_generation)

func start_presentation(old_layout, packet, generation):
	if generation != presentation_generation: return
	moving_uids.clear()
	if not animations_enabled or packet.is_empty():
		sound.play_packet(packet)
		visual_counts.clear()
		presenting = false
		render()
		announce_turn_if_needed()
		return
	for e in packet:
		if e.kind == "move": moving_uids[e.uid] = true
	initialize_visual_counts(packet)
	fx.begin(self, packet, old_layout)
	render()
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != presentation_generation: return
	fx.play(capture_layout())
	await fx.finished
	if generation != presentation_generation: return
	presenting = false
	moving_uids.clear()
	visual_counts.clear()
	render()
	announce_turn_if_needed()

func announce_turn_if_needed():
	# game.turn changes only after the ending draw and any required discard.
	# This runs after that entire visual packet, including regrouping, finishes.
	if tutorial.active:return
	if screen != "table" or game.turn <= announced_turn or game.winner != -1 or game.phase in ["setup", "closing", "finished"]: return
	announced_turn = game.turn
	clear_turn_banner()
	turn_banner = CenterContainer.new()
	turn_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_banner.set_meta("turn", game.turn)
	ui_layer.add_child(turn_banner)
	var banner = panel(turn_banner, Color(1.0, 0.94, 0.78, 0.96))
	banner.custom_minimum_size = Vector2(430, 105)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title = centered_label("Tu turno" if game.active == human else "Turno rival", 42, GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(title)
	turn_banner.modulate.a = 0.0
	var tween = turn_banner.create_tween()
	tween.tween_property(turn_banner, "modulate:a", 1.0, 0.12)
	tween.tween_interval(0.78)
	tween.tween_property(turn_banner, "modulate:a", 0.0, 0.23)
	tween.tween_callback(turn_banner.queue_free)
	sound.play_effect("turno")

func clear_turn_banner():
	if is_instance_valid(turn_banner):
		turn_banner.queue_free()
	turn_banner = null

func pop_in(node):
	if is_instance_valid(node): interface_motion.enter(node, animations_enabled)

func capture_layout():
	var layout = {"cards":{}, "zones":{}}
	for node in targets:
		if not is_instance_valid(node) or not node.is_inside_tree() or node.zone in ["choice", "inspection"]: continue
		var rect = node.get_global_rect()
		if node.has_meta("pile_image"):
			var image = node.get_meta("pile_image")
			if is_instance_valid(image): rect = image.get_global_rect()
		if node.uid == -1 or node.has_meta("pile") or node.zone == "domain":
			layout.zones[fx.key(node.card_owner, node.zone)] = rect
		if node.zone == "domain":
			for p in [-1, human, computer]: layout.zones[fx.key(p, "domain")] = rect
		if node.uid != -1:
			layout.cards[node.uid] = {"rect":rect, "player":node.card_owner, "zone":node.zone}
	for p in hand_slots:
		var hand_rect=Rect2()
		for uid in hand_slots[p]:
			var node = hand_slots[p][uid]
			if is_instance_valid(node):
				var rect=node.get_global_rect()
				layout.cards[uid] = {"rect":rect, "player":p, "zone":"hand"}
				hand_rect=rect if hand_rect.size==Vector2.ZERO else hand_rect.merge(rect)
		layout.zones[fx.key(p, "hand")] = hand_rect if hand_rect.size!=Vector2.ZERO else Rect2(Vector2(900, 95), Vector2(120, 35))
	return layout

func hide_visual_uid(uid):
	set_visual_uid_alpha(uid, 0.0)
func reveal_visual_uid(uid):
	set_visual_uid_alpha(uid, 1.0)

func set_visual_uid_alpha(uid, alpha):
	for node in targets:
		if not is_instance_valid(node) or node.uid != uid or node.zone=="inspection": continue
		if node.has_meta("pile_image"):
			var image = node.get_meta("pile_image")
			if is_instance_valid(image): image.modulate.a = alpha
		else: node.modulate.a = alpha
	for p in hand_slots:
		if hand_slots[p].has(uid) and is_instance_valid(hand_slots[p][uid]): hand_slots[p][uid].modulate.a = alpha

func initialize_visual_counts(packet):
	visual_counts.clear()
	for p in range(2):
		for z in game.ZONES: visual_counts[fx.key(p, z)] = game.players[p][z].size()
	for e in packet:
		if e.kind != "move" or e.get("visual_only", false): continue
		var source = fx.key(e.player, e.from)
		var destination = fx.key(e.player, e.to)
		if visual_counts.has(source): visual_counts[source] += 1
		if visual_counts.has(destination): visual_counts[destination] -= 1

func visual_count(p, z):
	return int(visual_counts.get(fx.key(p, z), game.players[p][z].size()))

func register_count(node, p, z, prefix = "", suffix = ""):
	count_labels.append({"node":node, "player":p, "zone":z, "prefix":prefix, "suffix":suffix})
	node.text = prefix + str(visual_count(p, z)) + suffix

func visual_move_finished(e):
	if e.get("visual_only", false): return
	var source = fx.key(e.player, e.from)
	var destination = fx.key(e.player, e.to)
	if visual_counts.has(source): visual_counts[source] -= 1
	if visual_counts.has(destination): visual_counts[destination] += 1
	for entry in count_labels:
		if is_instance_valid(entry.node): entry.node.text = entry.prefix + str(visual_count(entry.player, entry.zone)) + entry.suffix

func render_home():
	if halloween_style_active():
		for right in [false,true]:
			var web=preload("res://halloween_web.gd").new()
			web.mirror=right;web.animated=animations_enabled
			web.size=Vector2(140,140)
			web.position=Vector2(get_viewport_rect().size.x-145 if right else 5,105)
			add_child(web)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 38)
	add_child(margin)
	var column = box(margin, true, 24)
	var top = box(column, false, 15)
	var identity = button("", open_account)
	identity.custom_minimum_size = Vector2(420, 78)
	identity.set_meta("home_account", true)
	identity.flat = true
	hover_feedback(identity,1.025)
	for state in ["normal","hover","pressed","focus"]: identity.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	identity.tooltip_text = "Mi cuenta" if account.signed_in() else "Acceder a Mi cuenta"
	top.add_child(identity)
	var identity_row = HBoxContainer.new()
	identity_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	identity_row.offset_left = 16
	identity_row.offset_right = -16
	identity_row.add_theme_constant_override("separation", 14)
	identity_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(identity_row)
	identity_row.add_child(profiles.avatar(profiles.current_code(), 58))
	var player_name = label(account.display_name() if account.signed_in() else "Invitado", 22, Color("fffaf0"))
	player_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.tooltip_text = player_name.text
	var identity_text = VBoxContainer.new()
	identity_text.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_text.add_theme_constant_override("separation", 3)
	identity_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(identity_text)
	identity_text.add_child(player_name)
	if account.signed_in() and collection.owner_id == account.player_id():
		var wallet = HBoxContainer.new()
		wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet.add_theme_constant_override("separation", 6)
		wallet.set_meta("home_restos", true)
		wallet.add_child(RestosArt.view(24))
		var balance = label("%d Restos" % int(collection.restos), 16, Color("ffde85"))
		balance.set_meta("restos_balance", int(collection.restos))
		balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wallet.add_child(balance)
		identity_text.add_child(wallet)
	top.add_child(fill(Control.new()))
	var code_button = button("", open_account_feature.bind("gift_code"))
	code_button.custom_minimum_size = Vector2(54,42)
	code_button.tooltip_text = "Código de regalo"
	code_button.set_meta("gift_icon_button",true)
	code_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var code_content = HBoxContainer.new()
	code_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	code_content.offset_left = 9
	code_content.offset_right = -9
	code_content.alignment = BoxContainer.ALIGNMENT_CENTER
	code_content.add_child(UIIcons.view("gift",28))

	code_button.add_child(code_content)
	var shop_button = button("Tienda",go_shop)
	shop_button.custom_minimum_size = Vector2(110,42)
	shop_button.add_theme_font_size_override("font_size",15)
	shop_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(shop_button)
	var friends_button = button("Amigos", social_ui.open_friends)
	friends_button.custom_minimum_size = Vector2(100,42)
	friends_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friends_button.add_theme_font_size_override("font_size",15)
	top.add_child(friends_button)
	top.add_child(code_button)
	var settings_button = button("",show_configuration)
	settings_button.tooltip_text = "Configuración"
	settings_button.set_meta("settings_icon_button",true)
	var gear = TextureRect.new()
	gear.texture = asset_texture("estetica_v150/configuracion.png")
	gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_button.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear.offset_top = 6; gear.offset_bottom = -6
	settings_button.add_theme_font_size_override("font_size",15)
	settings_button.custom_minimum_size = Vector2(54,42)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(settings_button)
	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var row = box(center, false, 80)
	var menu = box(panel(row, PANEL), true, 12)
	menu.custom_minimum_size.x = 410
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.set_meta("home_main_menu", true)
	for item in [["Partida individual", open_single], ["Multijugador", show_multiplayer], ["Mi Colección", open_collection], ["Misiones", open_account_feature.bind("missions")]]:
		var option = button(item[0], item[1], false, item[0] == "Partida individual")
		option.custom_minimum_size.y = 56
		option.add_theme_font_size_override("font_size", 23)
		menu.add_child(option)
		if halloween_style_active() and item[0] in ["Partida individual","Misiones"]:
			var web=preload("res://halloween_web.gd").new()
			web.animated=animations_enabled;web.mirror=true
			web.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			web.position=Vector2(-53,0);web.size=Vector2(53,53)
			option.add_child(web)
	var fan = HomeCards.new()
	fan.custom_minimum_size = Vector2(520, 360)
	fan.featured_texture = texture_code("0119")
	fan.resource_texture = texture_code("0100")
	fan.logo_texture = asset_texture("logo_color.png", true)
	fan.animated = animations_enabled
	row.add_child(fan)
	if not collection.active_events().is_empty():
		var event_button = rewards.home_event_button()
		event_button.position = Vector2(295, 286)
		fan.add_child(event_button)
	var footer = box(column, true, 14)
	footer.add_child(centered_label("AAMIX Online v1.3.1", 13, Color("fffaf0")))
	var exit_center = CenterContainer.new()
	footer.add_child(exit_center)
	var exit_button = button("Salir", exit_game)
	exit_button.custom_minimum_size.x = 145
	exit_center.add_child(exit_button)

func render_single():
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content = box(panel(center),true,24)
	content.custom_minimum_size = Vector2(890,570)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(asset_image("logo_color.png",390,95,true))
	content.add_child(centered_label("Partida individual",34,GOLD))
	var row = box(content,false,38)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for option in [["dice","Partida Aleatoria",open_random],["swords","Desafío AAMIX",open_challenges]]:
		var item = box(row,true,14)
		item.custom_minimum_size.x = 350
		item.add_child(UIIcons.floating(option[0],230,animations_enabled))
		item.add_child(button(option[1],option[2],false,true))
	if event_battle_available():
		var event_row = box(content,false,12)
		event_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var pumpkin = preload("res://pumpkin_icon.gd").new().configure(64)
		event_row.add_child(pumpkin)
		var event_button = button("Partida de Evento · Halloween",open_event_battle,false,true)
		event_button.custom_minimum_size.x = 420
		event_button.set_meta("event_battle_button",true)
		event_row.add_child(event_button)
	content.add_child(button("TUTORIAL",tutorial.start,false,true))
	if started and game.winner == -1: content.add_child(button("Continuar partida",func(): screen="table"; render()))
	var back = CenterContainer.new()
	content.add_child(back)
	var back_button = button("Volver",go_home)
	back_button.custom_minimum_size.x = 200
	back.add_child(back_button)

func challenge_state(stage):
	if guest or not account.signed_in() or collection.owner_id != account.player_id(): return {}
	for item in collection.challenges:
		if int(item.get("stage", 0)) == int(stage): return item
	return {}

func render_challenges():
	if challenge_ui==null:challenge_ui=preload("res://challenge_ui.gd").new(self)
	challenge_ui.render_screen()

func challenge_opponent(stage):
	if stage < 1 or stage > CHALLENGES.size(): return {}
	var deck_id = CHALLENGES[stage - 1].deck_id
	for deck in game.decklists:
		if deck.id == deck_id: return deck.duplicate(true)
	var special = JSON.parse_string(FileAccess.get_file_as_string("res://challenge_decks.json"))
	for deck in special.mazos:
		if deck.id == deck_id: return deck.duplicate(true)
	return {}

func choose_challenge(stage):
	selected_event_battle = false
	if not bool(challenge_state(stage).get("unlocked", false)) or not can_enter_play(): return
	selected_challenge_stage = stage
	screen = "decks"
	render()

func open_random():
	selected_event_battle = false
	if not can_enter_play(): return
	selected_challenge_stage = 0
	screen = "decks"
	render()

func open_challenges():
	if screen=="table" and game.winner==human and active_challenge_stage>0:challenge_page=mini(active_challenge_stage,CHALLENGES.size()-1)
	selected_event_battle = false
	if guest or not account.signed_in():
		show_notice("Desafío AAMIX","Accede a tu cuenta para guardar tu progreso y recibir tu mazo inicial.")
		return
	if collection.loaded and collection.gift != null:
		screen = "challenges"
		render()
		return
	if collection.busy or welcome_loading: return
	if not collection.loaded:
		if not await collection.load_inventory(): return
	if collection.gift == null:
		if not await collection.enter_challenge(): return
		screen = "gift"
	else:
		screen = "challenges"
	render()

func rematch():
	selected_event_battle = active_event_battle
	selected_challenge_stage = active_challenge_stage
	for i in range(play_decks().size()):
		if str(play_decks()[i].id) == active_deck_id:
			start_match(i,last_opponent_deck)
			return
	open_single()

func show_multiplayer(private_room = false):
	online_ui.section = "private" if private_room or not online.room.is_empty() else "hub"
	screen = "multiplayer"
	render()
	if account.signed_in() and online.room.is_empty() and not online.busy: online.discover()

func go_shop():
	if guest or not account.signed_in():
		show_notice("Tienda", "Accede a tu cuenta para comprar cartas con tus Restos.")
		return
	screen = "shop"
	render()
	if not collection.loaded and not collection.busy: collection.load_inventory()

func open_account_feature(destination):
	if guest or not account.signed_in():
		show_notice("Accede a tu cuenta", "Inicia sesión para guardar tu progreso y recibir recompensas.")
		return
	rewards.open_screen(destination)

func open_collection():
	if guest or not account.signed_in():
		show_notice("Mi Colección", "Accede a tu cuenta para consultar tus cartas, mazos y sobres.")
		return
	open_cards()

func render_decks():
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 36)
	add_child(margin)
	var outer = box(margin, true, 17)
	outer.add_child(centered_label("Elige tu mazo", 30, GOLD))
	if selected_challenge_stage > 0:
		outer.add_child(centered_label("Desafío AAMIX · Nivel %d · %s" % [selected_challenge_stage, CHALLENGES[selected_challenge_stage - 1].title], 20, MUTED))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var row = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
	fill(row)
	row.add_theme_constant_override("h_separation", 20)
	row.add_theme_constant_override("v_separation", 20)
	scroll.add_child(row)
	row.set_meta("deck_choices", true)
	for i in range(play_decks().size()):
		var deck = play_decks()[i]
		if not guest and owned_deck(deck.id).is_empty(): continue
		var item = box(panel(row, PANEL), true, 12)
		item.custom_minimum_size = Vector2(260, 350)
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_child(deck_cover(deck, 230, 205))
		var name_label = label(deck.nombre, 23, GOLD)
		name_label.custom_minimum_size.x = 230
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(name_label)
		var resources = 0
		for entry in deck.cartas:
			if game.catalog[entry.codigo].clase == "Recurso": resources += int(entry.cantidad)
		var count = label("40 cartas · %d Recursos" % resources, 16, MUTED)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.add_child(count)
		item.add_child(button("Jugar", start_match.bind(i), false, true))
		item.add_child(button("Ver Mazo", preview_deck.bind(deck)))
	var rival = label("El rival recibe al azar uno de los mazos base." if selected_challenge_stage == 0 else "Elige uno de tus mazos para enfrentar este nivel.", 17, MUTED)
	rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(rival)
	outer.add_child(button("Volver", open_single if selected_challenge_stage == 0 else open_challenges))

func open_account():
	screen = "account"
	render()

func account_changed():
	var current = account.player_id()
	if not current.is_empty():
		account_code = ""
		account_email = ""
		account_nickname = ""
		if current != session_owner:
			deck_builder.reset()
			online.clear()
			social.clear()
			social_ui.reset()
			session_owner = current
			guest = false
			reset_match()
			collection.clear()
			screen = "home"
			load_initial_inventory.call_deferred(current)
	elif not session_owner.is_empty():
		deck_builder.reset()
		online.clear()
		social.clear()
		social_ui.reset()
		session_owner = ""
		guest = false
		reset_match()
		collection.clear()
		screen = "account"
	if screen in ["home", "account", "cards", "deck_builder", "gift", "decks", "single", "challenges", "shop"]: render()

func collection_changed():
	if rewards != null: rewards.inventory_changed()
	var gift_received = collection.loaded and collection.gift != null and screen == "gift"
	if gift_received: screen = "challenges"
	if screen in ["home","cards","deck_builder","gift","decks","single","challenges","gift_code","missions","event","packs","shop","versus"]: render()
	if collection.loaded and collection.last_reply.get("welcome_awarded",false) and not welcome_notified.has(collection.owner_id):
		welcome_notified[collection.owner_id]=true
		show_welcome_pack.call_deferred(collection.owner_id)
	if gift_received: celebrate_reward("¡Tu mazo inicial!","Todo listo para el Desafío AAMIX.",deck_cover_texture(collection.gift.get("deck_id","")))

func reset_match():
	selected_event_battle = false
	active_event_battle = false
	selected_challenge_stage = 0
	active_challenge_stage = 0
	active_deck_id = ""
	announced_turn = 0
	winner_announced = false
	clear_turn_banner()
	presentation_generation += 1
	if fx != null:
		fx.cancel()
		fx.speed=1.0
	presenting = false
	moving_uids.clear()
	visual_counts.clear()
	started = false
	draft.clear()

func play_guest():
	if account.busy or account.signed_in(): return
	guest = true
	reset_match()
	collection.clear()
	account_code = ""
	account_email = ""
	account_nickname = ""
	account.pending_email = ""
	account.code_sent = false
	screen = "home"
	render()

func return_to_access():
	if account.busy: return
	guest = false
	reset_match()
	screen = "account"
	render()

func play_decks():
	return game.decklists if guest else collection.playable_decks()

func owned_deck(deck_id):
	if not collection.loaded or collection.owner_id != account.player_id(): return {}
	for deck in collection.decks:
		if deck.id == deck_id: return deck
	return {}

func can_enter_play():
	if guest: return true
	if not account.signed_in():
		open_account()
		return false
	if not collection.loaded: return false
	if play_decks().is_empty():
		show_notice("Tus mazos","Guarda un mazo listo para jugar o entra al Desafío AAMIX para elegir tu primer mazo de regalo.")
		return false
	return true

func account_mode(create):
	if account.busy: return
	account_register = create
	account_code = ""
	account.pending_email = ""
	account.code_sent = false
	account.status = account.availability_message()
	render()

func account_field(parent, caption, value, hint, key, locked = false):
	if not caption.is_empty(): parent.add_child(label(caption, 15, MUTED))
	var input = LineEdit.new()
	input.text = value
	input.placeholder_text = hint
	input.custom_minimum_size = Vector2(0, 48) if mobile_layout else Vector2(640, 44)
	input.max_length = 254 if key == "account_email" else (24 if key == "account_nickname" else (36 if key == "unused_identity" else 10))
	input.editable = not locked
	input.add_theme_color_override("font_color", TEXT)
	input.add_theme_color_override("font_uneditable_color", MUTED)
	input.add_theme_color_override("caret_color", GOLD)
	input.add_theme_stylebox_override("normal", style(Color.WHITE, BORDER, 6))
	input.add_theme_stylebox_override("read_only", style(Color("fff8e9"), BORDER, 6))
	input.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, GOLD, 6))
	input.text_changed.connect(func(text): set(key, text))
	parent.add_child(input)
	return input

func render_account():
	if not account.signed_in() and account.remember_me:
		if account_email.is_empty(): account_email=account.remembered_email
		if account_nickname.is_empty(): account_nickname=account.remembered_name
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var outer = box(panel(center, PANEL), true, 13)
	outer.custom_minimum_size.x = 700
	outer.add_child(asset_image("logo_color.png", 300, 65, true))
	outer.add_child(label("Mi cuenta" if account.signed_in() else "Iniciar sesión", 30, GOLD))
	if account.signed_in():
		var portrait_row = box(outer, false, 20)
		portrait_row.add_child(profiles.avatar(profiles.current_code(), 86))
		var portrait_info = box(portrait_row, true, 8)
		portrait_info.alignment = BoxContainer.ALIGNMENT_CENTER
		portrait_info.add_child(button("Elegir foto de perfil", profiles.show_picker, collection.busy or account.busy))
		outer.add_child(label(account.display_name(), 25, TEXT))
		outer.add_child(label(str(account.user.get("email", "")), 16, MUTED))
		outer.add_child(label("Tu ID de jugador", 15, GOLD))
		var identity = account_field(outer, "", account.player_id(), "", "unused_identity", true)
		identity.set_meta("player_id", true)
		outer.add_child(button("Copiar ID", copy_player_id, false, true))
		var note = label("Este ID identifica tu cuenta en cualquier computador. Tu nombre visible puede coincidir con el de otro jugador.", 17, MUTED)
		note.custom_minimum_size.x = 640
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(note)
		outer.add_child(button("Cerrar sesión", account.sign_out, account.busy or collection.busy))
	else:
		var tabs = box(outer, false, 10)
		tabs.add_child(fill(button("Crear cuenta", account_mode.bind(true), account.busy, account_register)))
		tabs.add_child(fill(button("Ingresar", account_mode.bind(false), account.busy, not account_register)))
		var intro = label("Usa tu correo y un código de acceso para conservar tu ID en distintos computadores.", 17, MUTED)
		intro.custom_minimum_size.x = 640
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(intro)
		if account_register and not account.code_sent:
			account_field(outer, "Nombre visible", account_nickname, "Cómo te verán tus amigos", "account_nickname", account.busy)
		account_field(outer, "Correo", account.pending_email if account.code_sent else account_email, "tu@correo.com", "account_email", account.busy or account.code_sent)
		var remember=CheckBox.new()
		remember.text="Recuérdame"
		remember.button_pressed=account.remember_me
		remember.disabled=account.busy or not account.remember_available()
		remember.set_meta("remember_me",true)
		remember.toggled.connect(func(enabled): account.set_remember_me(enabled,account_email,account_nickname))
		outer.add_child(remember)
		if account.code_sent:
			var code = account_field(outer, "Código recibido", account_code, "Código del correo", "account_code", account.busy)
			code.text_submitted.connect(func(_text): account.verify_code(account_code))
			outer.add_child(button("Verificar e ingresar", func(): account.verify_code(account_code), account.busy, true))
			var more = box(outer, false, 10)
			more.add_child(button("Reenviar código", send_account_code, account.busy))
			more.add_child(button("Usar otro correo", account_mode.bind(account_register), account.busy))
		else:
			outer.add_child(button("Enviar código", send_account_code, not account.configured or not account.registration_ready or account.busy, true))
		if account.registration_ready and account.restricted_delivery:
			var delivery = label("Registro en prueba: los códigos sólo se envían a los correos autorizados del proyecto.", 14, GOLD)
			delivery.custom_minimum_size.x = 640
			delivery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			outer.add_child(delivery)
		var privacy = label("Recuérdame conserva tu acceso cifrado en este usuario de Windows, también al cambiar de versión. Actívalo sólo en tu equipo.", 14, MUTED)
		privacy.custom_minimum_size.x = 640
		privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(privacy)
	var message = label(account.status, 16, MINT)
	message.custom_minimum_size = Vector2(640, 58)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(message)
	if account.signed_in():
		outer.add_child(button("Volver al inicio", go_home))
	else:
		outer.add_child(button("Jugar como invitado", play_guest, account.busy))

func send_account_code():
	account_code = ""
	account.request_code(account.pending_email if account.code_sent else account_email, account_nickname, account_register)

func copy_player_id():
	if not account.signed_in(): return
	DisplayServer.clipboard_set(account.player_id())
	account.status = "ID copiado."
	render()

func event_battle_available():
	return not guest and collection.active_events().any(func(e):return bool(e.get("battle",false)))

func halloween_style_active():
	return collection.active_events().any(func(e):return str(e.get("id",""))=="halloween_2026")

func open_event_battle():
	if not event_battle_available() or not can_enter_play():return
	selected_event_battle = true
	selected_challenge_stage = 0
	screen = "decks"
	render()

func open_single():
	screen = "single"
	render()

func go_home():
	clear_highlights()
	presentation_generation += 1
	fx.cancel()
	sound.stop_effects()
	presenting = false
	moving_uids.clear()
	visual_counts.clear()
	screen = "home" if guest or account.signed_in() else "account"
	render()

func exit_game():
	if quitting: return
	if not quit_dialog.visible:
		sound.play_effect("popup")
		quit_dialog.popup_centered(Vector2i(490, 180))
		animate_quit_content.call_deferred()

func animate_quit_content():
	if not quit_dialog.visible: return
	# Window itself is not a CanvasItem. Animate its content, keeping native sizing
	# and the confirmation/cancel hit areas under the dialog's own layout control.
	for content in [quit_dialog.get_label(), quit_dialog.get_ok_button().get_parent()]:
		if content is Control:
			if content.has_meta("interface_entered"): content.remove_meta("interface_entered")
			pop_in(content)

func confirm_exit_game():
	if quitting: return
	quitting = true
	fx.cancel()
	sound.shutdown()
	# Let the audio mixer release its final playback before closing the driver.
	await get_tree().create_timer(0.10).timeout
	get_tree().quit()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST: exit_game()

func show_notice(title, text):
	var center = overlay("notice")
	var shade = center.get_parent()
	var v = box(panel(center), true, 15)
	v.custom_minimum_size = Vector2(720, 230)
	v.add_child(label(title, 30, GOLD))
	var body = label(text, 21)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 670
	v.add_child(body)
	v.add_child(button("Volver", close_overlay.bind(shade)))

func celebrate_reward(title, description, icon_texture = null):
	var center = overlay("reward")
	var shade = center.get_parent()
	var body = box(panel(center), true, 18)
	body.custom_minimum_size = Vector2(710, 330)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge_center = CenterContainer.new()
	body.add_child(badge_center)
	if icon_texture != null:
		var picture = CardImage.new() if icon_texture.get_meta("printed_card", false) else TextureRect.new()
		picture.texture = icon_texture
		picture.custom_minimum_size = Vector2(180, 220)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_meta("reward_icon", true)
		badge_center.add_child(picture)
	else:
		var badge = GiftBadge.new()
		badge.animated = animations_enabled
		badge_center.add_child(badge)
	body.add_child(centered_label(title, 35, GOLD))
	var detail = centered_label(description, 21, TEXT)
	detail.custom_minimum_size.x = 660
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(detail)
	var controls = box(body, false)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_child(button("Continuar", close_overlay.bind(shade), false, true))
	sound.play_effect("regalo_recibido")

func show_configuration():
	var center = overlay("configuration")
	var shade = center.get_parent()
	var v = box(panel(center), true, 18)
	v.custom_minimum_size = Vector2(650, 330)
	v.add_child(label("Configuración", 30, GOLD))
	v.add_child(button("Juego",show_game_settings,false,true))
	v.add_child(button("Sonido", show_audio_settings, false, true))
	v.add_child(button("Visuales", func():
		close_overlay(shade)
		show_visual_settings()
	))
	v.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func load_visual_settings():
	var preferences = ConfigFile.new()
	if preferences.load(visual_settings_path) == OK:
		dark_theme = str(preferences.get_value("visuals", "theme", "light")) == "dark"
	apply_visual_palette()

func apply_visual_palette():
	BG = Color("171a1d") if dark_theme else Color("e8e4d9")
	PANEL = Color("292d30") if dark_theme else Color("fffdf6")
	FELT = Color("292d30") if dark_theme else Color("fffaf0")
	BORDER = Color("685b45") if dark_theme else Color("cbb98c")
	TEXT = Color("f8f0de") if dark_theme else Color("493720")
	MUTED = Color("c8bca5") if dark_theme else Color("7f6042")
	MINT = Color("e6cd9a") if dark_theme else Color("5d482f")
	GOLD = Color("f0d084") if dark_theme else Color("7f6042")
	ACCENT = Color("e6bf68") if dark_theme else Color("ffde85")
	TARGET_COLOR = Color("f0d084") if dark_theme else Color("96724e")
	INVALID_COLOR = Color("ff9c86") if dark_theme else Color("a44635")

func set_visual_theme(dark):
	dark_theme = bool(dark)
	apply_visual_palette()
	var preferences = ConfigFile.new()
	preferences.load(visual_settings_path)
	preferences.set_value("visuals", "theme", "dark" if dark_theme else "light")
	preferences.save(visual_settings_path)
	self.theme = visual_theme.make_theme()
	quit_dialog.theme = self.theme
	for shade in overlay_shades.duplicate():
		if shade.get_meta("overlay_kind","") in ["configuration","audio","visuals","game_settings"]:close_overlay(shade)
	render()
	show_visual_settings()

func show_visual_settings():
	var center = overlay("visuals")
	var shade = center.get_parent()
	var v = box(panel(center), true, 15)
	v.custom_minimum_size = Vector2(650, 310)
	v.add_child(label("Visuales", 30, GOLD))
	var group = ButtonGroup.new()
	for option in [["Tema Claro", false], ["Tema Oscuro", true]]:
		var choose = button(option[0], set_visual_theme.bind(option[1]))
		choose.toggle_mode = true
		choose.button_group = group
		choose.set_pressed_no_signal(dark_theme == option[1])
		choose.set_meta("visual_theme", "dark" if option[1] else "light")
		v.add_child(choose)
	v.add_child(button("Volver", func():
		close_overlay(shade)
		show_configuration()
	))

func show_audio_settings():
	var center = overlay("audio")
	var shade = center.get_parent()
	var v = box(panel(center), true, 18)
	v.custom_minimum_size = Vector2(650, 370)
	v.add_child(label("Sonido", 30, GOLD))
	for entry in [["Música", sound.music_volume, sound.set_music_volume], ["Efectos de las cartas", sound.effects_volume, sound.set_effects_volume]]:
		var row = box(v, false, 14)
		row.add_child(fill(label(entry[0], 21)))
		var amount = label("%d %%" % roundi(entry[1] * 100), 18, MINT)
		row.add_child(amount)
		var slider = HSlider.new()
		slider.custom_minimum_size = Vector2(610, 30)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = entry[1] * 100
		var setter = entry[2]
		slider.value_changed.connect(func(value):
			amount.text = "%d %%" % roundi(value)
			setter.call(value / 100.0)
		)
		v.add_child(slider)
	var mute = CheckButton.new()
	mute.text = "Silenciar todo"
	mute.button_pressed = sound.muted
	mute.toggled.connect(sound.set_muted)
	v.add_child(mute)
	v.add_child(button("Probar sonido", sound.play_effect.bind("robo")))
	v.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func show_log():
	var center = overlay("log")
	var shade = center.get_parent()
	var v = box(panel(center), true, 15)
	v.custom_minimum_size = Vector2(900, 640)
	v.add_child(label("Registro de la partida", 28, GOLD))
	var text = RichTextLabel.new()
	text.custom_minimum_size = Vector2(860, 530)
	text.add_theme_font_size_override("normal_font_size", 18)
	text.text = "\n".join(game.log_lines)
	text.scroll_following = true
	text.set_meta("live_log",true)
	v.add_child(text)
	v.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func close_overlay(shade):
	if not is_instance_valid(shade): return
	overlay_shades.erase(shade)
	shade.get_parent().remove_child(shade)
	shade.queue_free()
	modal_open = not overlay_shades.is_empty()
	last_overlay_semantic = ""

func open_cards():
	if guest or not account.signed_in(): return
	screen = "cards"
	render()
	if not collection.loaded and not collection.busy: collection.load_inventory()

func select_cards_tab(value):
	cards_tab = value
	render()

func collection_card_visible(code):
	var definition=game.catalog[code]
	if not definition.get("event_exclusive",false):return true
	var event_id=str(definition.get("event_id",""))
	if not event_id.is_empty() and collection.active_events().any(func(event):return str(event.get("id",""))==event_id):return true
	var release_day=str(definition.get("collection_visible_from",""))
	# Use only the server's calendar. Released collections stay visible afterwards.
	return release_day.length()==10 and collection.server_day.length()==10 and collection.server_day>=release_day

func render_cards():
	if guest or not account.signed_in():
		screen = "account"
		render_account()
		return
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 38)
	add_child(margin)
	var outer = box(margin, true, 16)
	var heading = box(outer, false, 22)
	heading.add_child(home_logo(210,50))
	heading.add_child(fill(label("Tu primer mazo" if screen == "gift" else "Mi Colección", 30, GOLD)))
	heading.add_child(reload_button(collection.load_inventory,collection.busy or account.busy))
	heading.add_child(button("Inicio", go_home))
	var tabs = box(outer, false, 12)
	tabs.add_child(button("Mi Colección", select_cards_tab.bind("collection"), false, cards_tab == "collection"))
	tabs.add_child(button("Mis Mazos", select_cards_tab.bind("decks"), false, cards_tab == "decks"))
	tabs.add_child(button("Mis sobres · %d" % collection.packs, rewards.open_screen.bind("packs")))
	if not collection.status.is_empty():
		var state = label(collection.status, 16, MINT)
		state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		outer.add_child(state)
	if not collection.loaded:
		outer.add_child(label("Conecta para consultar tus cartas y comprobar si tienes un regalo pendiente.", 18, MUTED))
		return
	var scroll = ScrollContainer.new()
	scroll.set_meta("collection_scroll", true)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body = box(scroll, true, 20)
	fill(body)
	if cards_tab == "collection":
		var codes = game.catalog.keys().filter(collection_card_visible)
		codes.sort()
		var total = 0
		var collected = 0
		for code in codes:
			var amount=int(collection.cards.get(code,0))
			total+=amount
			if amount>0:collected+=1
		body.add_child(centered_label("%d cartas · %d de %d cartas coleccionadas" % [total, collected, codes.size()], 21, GOLD))
		var grid = HFlowContainer.new()
		grid.alignment = FlowContainer.ALIGNMENT_CENTER
		grid.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
		grid.set_meta("collection_grid", true)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 20)
		body.add_child(grid)
		var promotional = []
		var exclusive = []
		for code in codes:
			if game.catalog[code].get("event_exclusive",false):
				exclusive.append(code)
			elif game.catalog[code].get("subcoleccion", "") == "promocionales":
				promotional.append(code)
			else:
				collection_slot(grid, code)
		if not promotional.is_empty():
			var divider = HSeparator.new()
			divider.set_meta("promotional_divider", true)
			body.add_child(divider)
			body.add_child(centered_label("Promocionales", 23, GOLD))
			var promo_row = box(body, false, 22)
			promo_row.alignment = BoxContainer.ALIGNMENT_CENTER
			promo_row.set_meta("collection_promotional_row", true)
			fill(promo_row)
			for code in promotional: collection_slot(promo_row, code)
		if not exclusive.is_empty():
			body.add_child(HSeparator.new())
			body.add_child(centered_label("Cartas Exclusivas",23,GOLD))
			var exclusive_grid = HFlowContainer.new()
			exclusive_grid.alignment = FlowContainer.ALIGNMENT_CENTER
			exclusive_grid.set_meta("collection_exclusive_grid",true)
			exclusive_grid.add_theme_constant_override("h_separation",22)
			exclusive_grid.add_theme_constant_override("v_separation",20)
			body.add_child(fill(exclusive_grid))
			for code in exclusive:collection_slot(exclusive_grid,code)
	else:
		body.add_child(centered_label("Mis Mazos", 26, GOLD))
		var deck_grid = HFlowContainer.new()
		deck_grid.alignment = FlowContainer.ALIGNMENT_CENTER
		deck_grid.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER
		deck_grid.add_theme_constant_override("h_separation", 22)
		deck_grid.add_theme_constant_override("v_separation", 22)
		deck_grid.set_meta("owned_deck_grid", true)
		fill(deck_grid)
		body.add_child(deck_grid)
		for deck in collection.decks:
			var tile = panel(deck_grid)
			tile.custom_minimum_size = Vector2(300, 300)
			tile.set_meta("owned_deck_tile", str(deck.id))
			var info = box(tile, true, 5)
			info.alignment = BoxContainer.ALIGNMENT_CENTER
			info.add_child(deck_cover(deck, 270, 168))
			var name_label = centered_label(deck.nombre, 22, GOLD)
			name_label.custom_minimum_size.x = 270
			name_label.max_lines_visible = 1
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			name_label.tooltip_text = str(deck.nombre)
			info.add_child(name_label)
			var count = 0
			for entry in deck.cartas: count += int(entry.cantidad)
			info.add_child(centered_label(("Borrador" if deck.get("draft", false) else ("Personalizado" if deck.get("custom", false) else "Obtenido")) + " · %d cartas" % count, 16, MUTED))
			var actions = box(info, false, 8)
			actions.add_child(fill(button("Ver Mazo", preview_deck.bind(deck))))
			if deck.get("custom", false) or deck.get("editable", false): actions.add_child(fill(button("Editar", deck_builder.open.bind(deck), collection.busy)))
			if deck.get("custom",false):
				var remove = button("Eliminar Mazo",confirm_delete_deck.bind(deck),collection.busy or not collection.pending_deck_save.is_empty())
				remove.set_meta("delete_deck",str(deck.id))
				info.add_child(remove)
		var create = button("+\nCrear Mazo", deck_builder.open, collection.busy, true)
		create.custom_minimum_size = Vector2(300, 300)
		create.add_theme_font_size_override("font_size", 29)
		create.set_meta("create_deck", true)
		deck_grid.add_child(create)

func collection_slot(parent, code):
	var slot = box(parent, true, 4)
	slot.set_meta("collection_code", code)
	var quantity = int(collection.cards.get(code, 0))
	var surface = PanelContainer.new()
	surface.custom_minimum_size = Vector2(155, 212)
	surface.add_theme_stylebox_override("panel", card_style() if quantity > 0 else style(Color(1.0,0.985,0.94,0.76),BORDER,4))
	slot.add_child(surface)
	if quantity > 0:
		surface.add_child(catalog_image(code, 150, 210))
		surface.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hover_feedback(surface,1.045)
		surface.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click: catalog_detail(code)
		)
	var caption = centered_label("(x%d) %s - %s" % [quantity,code,game.catalog[code].nombre] if quantity>0 else str(code),14,TEXT if quantity>0 else MUTED)
	caption.custom_minimum_size = Vector2(155,36)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.set_meta("collection_card_caption",code)
	if quantity>0: caption.tooltip_text = caption.text
	slot.add_child(caption)
	var font = caption.get_theme_font("font")
	var font_size = 14
	var wrap_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	while font_size>11 and font.get_multiline_string_size(caption.text,HORIZONTAL_ALIGNMENT_CENTER,155,font_size,-1,wrap_flags).y>font.get_height(font_size)*2.0+.1:
		font_size-=1
	caption.add_theme_font_size_override("font_size",font_size)
	return slot

func confirm_delete_deck(deck):
	if not deck.get("custom",false) or collection.busy: return
	var expected_owner = account.player_id()
	var center = overlay("detail")
	var shade = center.get_parent()
	var body = box(panel(center),true,16)
	body.custom_minimum_size.x = 560
	body.add_child(centered_label("¿Eliminar %s?" % str(deck.nombre),26,GOLD))
	body.add_child(centered_label("Las cartas se conservan en tu colección.",18,TEXT))
	var actions = box(body,false,14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(button("Eliminar",func():
		if expected_owner != account.player_id(): return
		close_overlay(shade)
		delete_deck(deck)
	,false,true))
	actions.add_child(button("Cancelar",close_overlay.bind(shade)))

func delete_deck(deck):
	if not deck.get("custom",false) or collection.busy: return
	var expected_owner = account.player_id()
	var ok = await collection.delete_custom_deck(str(deck.id),int(deck.get("revision",0)))
	if expected_owner != account.player_id(): return
	if ok: collection.status = "Mazo eliminado."
	if screen=="cards": render()

func catalog_image(code, width, height):
	var image = CardImage.new()
	image.texture = texture_code(code)
	image.custom_minimum_size = Vector2(width, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func catalog_detail(code):
	if mobile_layout: mobile.detail(code); return
	var center = overlay("detail")
	var shade = center.get_parent()
	var row = box(panel(center), false, 25)
	row.add_child(catalog_image(code, 410, 590))
	var info = box(row, true, 18)
	info.custom_minimum_size.x = 430
	var definition = game.catalog[code]
	info.add_child(label(code + " · " + definition.nombre, 27, GOLD))
	var text = label(str(definition.get("texto_juego", definition.get("texto_impreso", ""))), 21)
	text.custom_minimum_size.x = 420
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(text)
	info.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func preview_deck(deck):
	if mobile_layout: mobile.preview_deck(deck); return
	var center = overlay("detail")
	var shade = center.get_parent()
	var body = box(panel(center), true, 12)
	body.custom_minimum_size.x = 1080
	var total = 0
	for entry in deck.cartas: total += int(entry.cantidad)
	body.add_child(centered_label(deck.nombre + " · %d cartas" % total + (" · Borrador" if deck.get("draft", false) else ""), 27, GOLD))
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060, 590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list = HFlowContainer.new()
	list.alignment = FlowContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("h_separation", 15)
	list.add_theme_constant_override("v_separation", 15)
	scroll.add_child(list)
	fill(list)
	var entries = deck.cartas.duplicate(true)
	entries.sort_custom(func(a,b): return a.codigo < b.codigo)
	for entry in entries:
		var slot = box(list, true, 5)
		slot.custom_minimum_size.x = 155
		slot.set_meta("preview_deck_card", entry.codigo)
		var picture = button("", catalog_detail.bind(entry.codigo))
		picture.custom_minimum_size = Vector2(155, 210)
		var image = catalog_image(entry.codigo, 155, 210)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.add_child(image)
		slot.add_child(picture)
		slot.add_child(centered_label("%s · ×%d" % [entry.codigo, int(entry.cantidad)], 18, GOLD))
		var name_label = centered_label(game.catalog[entry.codigo].nombre, 15, TEXT)
		name_label.custom_minimum_size.x = 150
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(name_label)
	body.add_child(button("Volver · Esc", close_overlay.bind(shade)))

func confirm_gift(deck):
	if collection.busy or not collection.loaded or collection.gift != null: return
	var center = overlay("detail")
	var shade = center.get_parent()
	var body = box(panel(center), true, 18)
	body.custom_minimum_size.x = 660
	body.add_child(centered_label("¿Elegir " + deck.nombre + "?", 28, GOLD))
	body.add_child(deck_cover(deck, 220, 270))
	body.add_child(centered_label("Recibirás sus 40 cartas y el mazo guardado.\nEl regalo se elige una sola vez por cuenta.", 21, TEXT))
	body.add_child(button("Confirmar mi regalo", func():
		close_overlay(shade)
		collection.claim(deck.id)
	, false, true))
	body.add_child(button("Seguir revisando", close_overlay.bind(shade)))

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if tutorial.active and screen=="tutorial":tutorial.leave();return
		if not overlay_shades.is_empty():close_interface(overlay_shades.back());return
		if screen=="deck_builder":deck_builder.leave();return
		if screen=="table":show_configuration();return
		if screen=="challenges":open_single();return
		if screen!="home":go_home()
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		var root_node=self
		if not overlay_shades.is_empty():root_node=overlay_shades.back()
		elif screen=="table" and is_instance_valid(action_panel):root_node=action_panel
		var buttons=interface_nodes(root_node).filter(func(n):return n is Button and not n.disabled and control_on_screen(n))
		if buttons.is_empty():return
		var selected=buttons.filter(func(b):return b.has_meta("primary"))
		var preferred=selected[0] if not selected.is_empty() else buttons[0]
		if event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			var focused=get_viewport().gui_get_focus_owner()
			if focused is Button and focused in buttons:focused.pressed.emit()
			else:preferred.pressed.emit()
		else:preferred.grab_focus()
		get_viewport().set_input_as_handled()

func reload_button(action, disabled = false):
	var control = button("",action,disabled)
	control.flat = true
	control.custom_minimum_size = Vector2(44,44)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.tooltip_text = "Actualizar"
	control.set_meta("reload",true)
	control.add_child(UIIcons.view("reload",40))
	return control

func render_versus():
	if pending_match.is_empty():
		open_single()
		return
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column = box(panel(center),true,20)
	column.custom_minimum_size = Vector2(730,720)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var stage = int(pending_match.stage)
	column.add_child(centered_label("Nivel %d: %s" % [stage,pending_match.opponent.nombre] if stage>0 else ("Partida de Evento: %s" if pending_match.get("event_battle",false) else "Partida Aleatoria: %s") % pending_match.opponent.nombre,29,GOLD))
	column.add_child(deck_cover(pending_match.opponent,290,360))
	column.add_child(centered_label("Tu mazo: %s" % owned_or_guest_deck_name(pending_match.deck_id),22,TEXT))
	if not rewards.match_status.is_empty():
		column.add_child(centered_label(rewards.match_status, 17, MUTED))
	column.add_child(button("Preparando…" if rewards.preparing else "Comenzar",begin_prepared_match,rewards.preparing or collection.busy or account.busy,true))
	column.add_child(button("Volver",func(): screen="decks";render(),rewards.preparing or collection.busy))

func owned_or_guest_deck_name(id):
	for deck in play_decks():
		if str(deck.id)==id: return str(deck.nombre)
	return str(id)

func load_initial_inventory(owner):
	while collection.busy:
		await get_tree().process_frame
		if account.player_id()!=owner: return
	if account.player_id()!=owner: return
	welcome_loading=true
	await collection.load_inventory()
	welcome_loading=false

func show_welcome_pack(owner):
	if owner != account.player_id(): return
	celebrate_reward("¡Tu primer sobre TC!","Un sobre Transmisión Caída para comenzar.",rewards.PackArt.texture(false))
	var controls = overlay_shades.back().find_children("*","Button",true,false)
	for control in controls:
		if control.text=="Continuar":
			control.text="Abrir mi sobre"
			control.pressed.connect(func(): rewards.open_screen("packs"))

func render_starter():
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content = box(center,true,20)
	content.custom_minimum_size = Vector2(1060,720)
	content.add_child(centered_label("Tu mazo para el Desafío AAMIX",32,GOLD))
	var choices = box(content,false,24)
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	for deck in game.decklists:
		var item = box(panel(choices),true,16)
		item.add_child(deck_cover(deck,250,330))
		item.add_child(centered_label(deck.nombre,24,GOLD))
		item.add_child(button("Elegir mazo",confirm_gift.bind(deck),collection.busy,true))
	content.add_child(button("Volver",open_single))


func online_changed():
	var hint = online.status + str(online.waiting_action())
	if screen == "multiplayer": render()
	elif screen == "table" and online.in_match() and hint != last_online_hint: render()
	last_online_hint = hint

func accept_online_state(local_slot,packet = [],old_layout = {},outcome = {}):
	active_event_battle=false
	selected_event_battle=false
	var entering = not started or human != local_slot or active_deck_id != "online"
	if entering:
		presentation_generation += 1
		fx.cancel()
		presenting = false
		moving_uids.clear()
		visual_counts.clear()
		draft.clear()
		announced_turn = 0
		winner_announced = false
	game.manual_payment = [true,true]
	human = local_slot
	computer = 1-local_slot
	active_deck_id = "online"
	active_challenge_stage = 0
	selected_challenge_stage = 0
	if str(outcome.get("status",online.room.get("status",""))) == "finished":
		game.winner = int(outcome.get("winner",online.room.get("winner",game.winner)))
		game.phase = "finished"
		game.pending.clear()
	started = true
	automation_pause = true
	bot_clock = 0.0
	if entering or screen == "multiplayer": screen = "table"
	fx.speed=1.0
	if screen=="table" and not packet.is_empty():
		clear_highlights()
		presentation_generation+=1
		presenting=true
		start_presentation.call_deferred(old_layout,packet,presentation_generation)
	else:
		render()
		announce_turn_if_needed()
	if game.winner != -1 and not collection.busy: collection.load_inventory.call_deferred()

func confirm_abandon_match():
	if not started or game.winner!=-1: return
	var center=overlay("abandon_match");var shade=center.get_parent()
	var content=box(panel(center),true,18)
	content.custom_minimum_size.x=560
	content.add_child(centered_label("¿Abandonar la partida?",27,TEXT))
	content.add_child(centered_label("Se contará como derrota.",18,MUTED))
	var buttons=box(content,false,16)
	buttons.alignment=BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Abandonar",abandon_match,online.busy,true))
	buttons.add_child(button("Cancelar",close_overlay.bind(shade)))

func abandon_match():
	if not started or game.winner!=-1: return
	if online.in_match():
		await online.leave()
		return
	presentation_generation+=1
	fx.cancel()
	presenting=false
	automation_pause=true
	moving_uids.clear()
	visual_counts.clear()
	draft.clear()
	game.winner=computer
	game.phase="finished"
	game.pending.clear()
	game.payment_request.clear()
	winner_announced=false
	render()

func can_activate(uid):
	if online.in_match() and online.slot == 1:
		return uid in online.view_activations and game.actor == human and game.winner == -1
	return game.can_activate(uid)

func apply_online_drop(data,destination):
	var uid = int(data.get("uid",-1))
	var zone_name = str(destination.zone)
	var target = int(destination.get("target",-1))
	if data.kind == "deck": return online.submit("finish_turn",[])
	if not game.pending.is_empty(): return online.submit("discard_by_drag",[uid])
	var location = game.location(uid)
	if location.zone == "resources": return online.submit("reserve_resource",[uid])
	if location.zone == "paid": return online.submit("refund_resource",[uid])
	if location.zone in ["hand","graveyard"]: return online.submit("request_play",[uid,target if valid_target(uid,target) else -1])
	if zone_name == "deck": return online.submit("activate",[uid])
	if game.phase == "main":
		if zone_name == "attack": draft.append(uid)
		else: draft.erase(uid)
		render()
		return true
	if game.phase == "blocks":
		if zone_name == "defense" and destination.owner == human:
			for attacker in game.blocks:
				if game.blocks[attacker] == uid: return online.submit("assign_block",[int(attacker),-1])
		else: return online.submit("assign_block",[target,uid])
	return false


func hover_feedback(node, amount = 1.04): return HoverFeedback.attach(node,amount,animations_enabled)

func home_logo(width, height):
	var logo = LogoLink.new(); logo.texture = asset_texture("logo_color.png",true)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(width,height); logo.mouse_filter = Control.MOUSE_FILTER_STOP
	logo.focus_mode = Control.FOCUS_ALL; logo.tooltip_text = "Ir al inicio"; logo.action = logo_home
	logo.set_meta("home_logo_link",true); hover_feedback(logo,1.06); return logo

func logo_home():
	if screen == "deck_builder": deck_builder.leave("home"); return
	if screen == "table" and started and game.winner == -1:
		var content = box(panel(overlay("logo_home")),true,18); content.custom_minimum_size.x = 590
		content.add_child(centered_label("¿Volver al inicio?",27,TEXT))
		content.add_child(centered_label("Abandonar esta partida cuenta como derrota.",18,MUTED))
		content.add_child(button("Abandonar e ir al inicio",abandon_to_home,online.busy,true))
		content.add_child(button("Seguir jugando",render)); return
	go_home()

func abandon_to_home():
	await abandon_match()
	if online.in_match(): return
	go_home()

func settings_icon():
	var control=button("",show_configuration)
	control.tooltip_text="Configuración";control.custom_minimum_size=Vector2(44,36)
	var gear=asset_image("estetica_v150/configuracion.png",28,28)
	control.add_child(gear);gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear.offset_left=7;gear.offset_right=-7;gear.offset_top=4;gear.offset_bottom=-4
	return control

func load_game_settings():
	var config=ConfigFile.new()
	if config.load(gameplay_settings_path)==OK:
		automatic_cost=bool(config.get_value("game","automatic_cost",false))
		ask_automatic_cost=bool(config.get_value("game","ask_automatic_cost",true))

func save_game_settings():
	var config=ConfigFile.new()
	config.set_value("game","automatic_cost",automatic_cost)
	config.set_value("game","ask_automatic_cost",ask_automatic_cost)
	config.save(gameplay_settings_path)

func show_game_settings():
	var center=overlay("game_settings");var shade=center.get_parent()
	var v=box(panel(center),true,20);v.custom_minimum_size=Vector2(620,270)
	v.add_child(centered_label("Juego",30,GOLD))
	var check=CheckButton.new();check.text="Pago de coste automático";check.button_pressed=automatic_cost
	check.toggled.connect(func(value):automatic_cost=value;ask_automatic_cost=not value;save_game_settings())
	v.add_child(check)
	v.add_child(button("Volver",close_overlay.bind(shade)))

func request_card(uid,target=-1):
	if not game.can_play(uid) or game.actor!=human:return false
	if tutorial.active:return perform(game.request_play.bind(uid,target))
	automatic_uid=-1
	var needs=game.definition(uid).clase!="Recurso" and game.reserved[human].size()<int(game.definition(uid).coste)
	if needs and not automatic_cost and ask_automatic_cost:
		var center=overlay("auto_cost");var shade=center.get_parent()
		var v=box(panel(center),true,20);v.custom_minimum_size=Vector2(650,260);v.alignment=BoxContainer.ALIGNMENT_CENTER
		v.add_child(centered_label("Para jugar esta carta necesitas %d Restos"%int(game.definition(uid).coste),22,GOLD))
		v.add_child(centered_label("¿Pagar automáticamente?",24,TEXT))
		var check=CheckBox.new();check.text="No volver a preguntar"
		var row=box(v,false,20);row.alignment=BoxContainer.ALIGNMENT_CENTER
		for yes in [true,false]:
			row.add_child(button("Sí" if yes else "No",func():
				if check.button_pressed:automatic_cost=yes;ask_automatic_cost=false;save_game_settings()
				close_overlay(shade)
				if yes and game.can_play(uid) and game.actor==human:
					automatic_uid=uid;perform(game.request_play.bind(uid,target))
			,false,yes))
		v.add_child(check)
		return true
	if needs and automatic_cost:automatic_uid=uid
	return perform(game.request_play.bind(uid,target))

func advance_automatic_cost():
	if tutorial.active:return
	if automatic_uid<0 or screen!="table" or game.actor!=human or game.winner!=-1:return
	if presenting or fx.busy or (online.in_match() and online.waiting_action()):return
	if not game.payment_request.is_empty() and int(game.payment_request.uid)==automatic_uid:
		if not game.players[human].resources.is_empty():perform(game.reserve_resource.bind(game.players[human].resources.front()))
	elif game.location(automatic_uid).get("zone","") not in ["hand","graveyard"]:
		automatic_uid=-1

func refresh_passive_overlays():
	for shade in overlay_shades:
		if not is_instance_valid(shade):continue
		if shade.get_meta("overlay_kind","")=="log":
			for node in interface_nodes(shade):
				if node.has_meta("live_log"):
					var history="\n".join(game.log_lines)
					if node.text!=history:node.text=history
	for target in targets:
		if is_instance_valid(target) and target.get_meta("shared_domain",false):
			var dragging_domain=not current_drag.is_empty() and game.instances.has(current_drag.get("uid",-1)) and game.definition(current_drag.uid).clase=="Dominio"
			var active=game.domain_uid!=-1 or dragging_domain
			if target.has_meta("domain_lit") and target.get_meta("domain_lit")==active:continue
			target.set_meta("domain_lit",active)
			var skin=target.get_meta("base_style").duplicate()
			if not active:
				skin.bg_color=Color(0.08,0.09,0.11,0.60);skin.border_color=Color("7b715c")
			target.add_theme_stylebox_override("panel",skin)
			for node in interface_nodes(target):
				if node is Label:node.add_theme_color_override("font_color",TEXT if active else Color("fff1d0"))

func add_force_badge(picture,uid):
	var badge=PanelContainer.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	badge.set_meta("current_force_uid",uid)
	var skin=style(Color("eee6d4"),Color("a89a80"),4)
	skin.bg_color=Color("eee6d4");skin.bg_color.a=0.88
	for edge in ["left","right","top","bottom"]:skin.set("content_margin_"+edge,2.0)
	badge.add_theme_stylebox_override("panel",skin)
	var text=centered_label(str(game.force(uid)),15,force_badge_color(uid));badge.add_child(text)
	picture.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	badge.offset_left=2;badge.offset_right=29;badge.offset_top=-26;badge.offset_bottom=-2;badge.z_index=11
	force_badges.append({"uid":uid,"text":text})

func refresh_force_badges():
	for entry in force_badges:
		if is_instance_valid(entry.text) and game.instances.has(entry.uid):
			entry.text.text=str(game.force(entry.uid));entry.text.add_theme_color_override("font_color",force_badge_color(entry.uid))

func force_badge_color(uid):
	var current=game.force(uid);var printed=int(game.definition(uid).get("fuerza",0))
	return Color("246044") if current>printed else Color("a43937") if current<printed else Color("342613")

func apply_backdrop_contrast():
	for node in interface_nodes(self):
		if not node is Label:continue
		var parent=node.get_parent();var plated=false
		while parent!=null and parent!=self:
			if parent is PanelContainer or parent is Panel or parent is Button:plated=true;break
			parent=parent.get_parent()
		if plated:continue
		node.set_meta("backdrop_text",true)
		node.add_theme_color_override("font_color",Color("fff3d9"))
		node.add_theme_color_override("font_outline_color",Color("171716"))
		node.add_theme_constant_override("outline_size",2 if node.get_theme_font_size("font_size")<22 else 3)

func control_on_screen(control):
	if not control.is_visible_in_tree():return false
	var rect=control.get_global_rect().intersection(get_viewport_rect())
	var parent=control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:rect=rect.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	return rect.has_area()
