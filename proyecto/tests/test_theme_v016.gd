extends SceneTree
## Eighteen focused visual checks. All identities/inventory are local in-memory fixtures.
const RestosArt = preload("res://restos_art.gd")
const NormalPackArt = preload("res://normal_pack_art.gd")
var ui
var checks = 0
var declared_checks = 0
var resume_persistence = false
var fixture_cfg_path = ""
var failures = []
var screenshot_path = ""
var had_visual_cfg = false
var previous_visual_cfg = PackedByteArray()
var fixture_owner = "76666666-1666-4666-8666-666666666666"

func _initialize():
	fixture_cfg_path = ProjectSettings.globalize_path("res://tests/.visual-v016-fixture.cfg")
	for arg in OS.get_cmdline_user_args():
		if arg == "--resume-persistence-v016": resume_persistence = true
		if arg.begins_with("--screenshots="): screenshot_path = arg.trim_prefix("--screenshots=")
	run.call_deferred()

func check(ok, description):
	declared_checks += 1
	if resume_persistence and declared_checks not in [3,10,18]: return
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAIL: ", description)

func text(node, value):
	if (node is Label or node is Button) and node.text == value: return node
	for child in node.get_children():
		var found = text(child, value)
		if found != null: return found
	return null

func meta(node, key, value = null):
	if node.has_meta(key) and (value == null or node.get_meta(key) == value): return node
	for child in node.get_children():
		var found = meta(child, key, value)
		if found != null: return found
	return null

func all_meta(node, key):
	var found = []
	if node.has_meta(key): found.append(node)
	for child in node.get_children(): found.append_array(all_meta(child, key))
	return found

func class_node(node, kind):
	if node.get_class() == kind: return node
	for child in node.get_children():
		var found = class_node(child, kind)
		if found != null: return found
	return null

func settle():
	for _i in range(10): await process_frame

func dismiss():
	while not ui.overlay_shades.is_empty(): ui.close_overlay(ui.overlay_shades.back())

func shot(name):
	if screenshot_path.is_empty() or resume_persistence: return
	DirAccess.make_dir_recursive_absolute(screenshot_path)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot_path.path_join(name + ".png"))

func switch_screen(value):
	dismiss()
	ui.screen = value
	ui.render()
	await settle()

func theme_on_disk():
	var saved = ConfigFile.new()
	if saved.load(fixture_cfg_path) != OK: return ""
	return str(saved.get_value("visuals", "theme", ""))

func restore_visual_cfg():
	if had_visual_cfg:
		var file = FileAccess.open(fixture_cfg_path, FileAccess.WRITE)
		file.store_buffer(previous_visual_cfg)
		file.close()
	elif FileAccess.file_exists(fixture_cfg_path):
		DirAccess.remove_absolute(fixture_cfg_path)

func contrast(high, low):
	var a = high.srgb_to_linear().get_luminance()
	var b = low.srgb_to_linear().get_luminance()
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func fixture():
	ui.account.user = {"id":fixture_owner,"email":"visuals@fixture.invalid","user_metadata":{"display_name":"Jugador de prueba"}}
	ui.account.access_token = "LOCAL_FIXTURE_NO_NETWORK"
	ui.account.refresh_token = ""
	ui.account.expires_at = Time.get_unix_time_from_system() + 3600
	ui.account.configured = false
	ui.session_owner = fixture_owner
	ui.guest = false
	ui.collection.loaded = true
	ui.collection.owner_id = fixture_owner
	ui.collection.restos = 100
	ui.collection.cards = {"0101":1}
	ui.collection.gift = {"deck_id":"maago"}
	ui.collection.decks = []
	ui.collection.profile = {"avatar_code":"0101"}
	ui.collection.welcome_pack = {"claimed":true}
	ui.collection.restos_welcome_claimed = true
	ui.collection.shop = []
	for code in ui.game.catalog:
		var definition = ui.game.catalog[code]
		if definition.clase == "Recurso" or definition.get("subcoleccion", "") == "promocionales": continue
		ui.collection.shop.append({"code":str(code),"price":500 if str(code) in ["0103","0105","0115","0119"] else 150})
	ui.collection.missions = [
		{"id":"play_one","title":"Juega 1 partida","scope":"daily","progress":0,"target":1,"claimed":false,"reward_kind":"restos","reward_amount":50},
		{"id":"win_one","title":"Gana 1 partida","scope":"daily","progress":0,"target":1,"claimed":false,"reward_kind":"normal_pack","reward_amount":1},
		{"id":"play_ten","title":"Juega 10 partidas","scope":"lifetime","progress":2,"target":10,"claimed":false,"reward_kind":"tc_pack","reward_amount":3},
		{"id":"win_ten","title":"Gana 10 partidas","scope":"lifetime","progress":1,"target":10,"claimed":false,"reward_kind":"tc_pack","reward_amount":5}
	]
	ui.collection.challenges = []
	for stage in range(1,6): ui.collection.challenges.append({"stage":stage,"unlocked":stage==1,"completed":false})

func run():
	had_visual_cfg = FileAccess.file_exists(fixture_cfg_path)
	if had_visual_cfg: previous_visual_cfg = FileAccess.get_file_as_bytes(fixture_cfg_path)
	root.size = Vector2i(1600,1000)
	ui = load("res://main.tscn").instantiate()
	ui.visual_settings_path = fixture_cfg_path
	root.add_child(ui)
	ui.animations_enabled = false
	ui.automation_pause = true
	await settle()
	fixture()
	ui.screen = "home"
	ui.set_visual_theme(false)
	dismiss()
	ui.show_configuration()
	await settle()
	var configuration = ui.overlay_shades.back()
	var visual_button = text(configuration,"Visuales")
	var configuration_ok = text(configuration,"Sonido") != null and visual_button != null
	if visual_button != null: visual_button.pressed.emit()
	await settle()
	check(configuration_ok and text(ui.overlay_shades.back(),"Tema Claro") != null and text(ui.overlay_shades.back(),"Tema Oscuro") != null,"Configuration exposes Sound and functional Visuals choices") # 1
	await shot("02-visuales-claro")
	var light_panel = ui.panel_style()
	check(not ui.dark_theme and light_panel is StyleBoxFlat and light_panel.bg_color.a == 1 and ui.BG.get_luminance() < light_panel.bg_color.get_luminance() and contrast(ui.TEXT,light_panel.bg_color)>7,"Light theme has opaque panels above a darker background and readable ink") # 2
	check(theme_on_disk() == "light","Light preference is persisted in visual.cfg") # 3
	await switch_screen("home")
	var name_label = text(meta(ui,"home_account"),"Jugador de prueba")
	var wallet = meta(ui,"home_restos")
	var amount = meta(wallet,"restos_balance") if wallet != null else null
	check(wallet != null and amount != null and amount.text == "100 Restos" and wallet.global_position.y >= name_label.global_position.y + name_label.size.y - 1 and meta(wallet,"restos_icon").texture != null,"Home shows 100 Restos with apple beneath the signed-in name") # 4
	var rear = meta(ui,"decorative_card","0119")
	var pack = meta(ui,"decorative_pack")
	var front = meta(ui,"decorative_card","0100")
	var logo = meta(ui,"home_logo")
	check(rear.get_index()<pack.get_index() and pack.get_index()<front.get_index() and front.get_index()<logo.get_index(),"Floating layers are Transmission, pack, Resource, logo") # 5
	await shot("01-inicio-claro")
	await switch_screen("challenges")
	var levels = meta(ui,"challenge_stages")
	check(levels.get_child_count()==5 and all_meta(levels,"ui_icon").filter(func(node):return node.get_meta("ui_icon")=="lock").size()==4 and text(levels,"Mazo Papito") != null and text(levels,"Mazo Flaan")==null and text(levels,"Mazo Kajido")==null and text(levels,"Mazo Maagover")==null and text(levels,"Mazo Girabl")==null,"All five levels are visible; four locks reveal no future decks") # 6
	await shot("03-niveles-claro")
	await switch_screen("missions")
	var rows = all_meta(ui,"compact_mission")
	check(rows.size()==4 and rows.all(func(row):return row.size.y<=110) and rows[-1].get_global_rect().end.y < ui.size.y-40,"Four smaller mission rows fit the screen without crowding") # 7
	await shot("04-misiones-claro")
	ui.collection.restos = 650
	await switch_screen("shop")
	var grid = meta(ui,"shop_grid")
	check(grid != null and grid.columns==6 and grid.get_global_rect().position.x>=36 and grid.get_global_rect().end.x<=ui.size.x-36 and meta(ui,"shop_balance").text=="650 Restos","Six-column shop fits 1600px and keeps balance in header") # 8
	var price = meta(ui,"shop_price",150)
	check(price != null and not price.disabled and price.get_theme_stylebox("normal") is StyleBoxFlat and contrast(price.get_theme_color("font_color"),price.get_theme_stylebox("normal").bg_color)>4.5,"Light shop price controls have readable text and warm flat surfaces") # 9
	await shot("05-tienda-claro")
	ui.show_configuration()
	text(ui.overlay_shades.back(),"Visuales").pressed.emit()
	text(ui.overlay_shades.back(),"Tema Oscuro").pressed.emit()
	await settle()
	check(ui.dark_theme and theme_on_disk()=="dark" and text(ui.overlay_shades.back(),"Tema Oscuro").button_pressed,"Dark choice applies immediately and persists") # 10
	await shot("06-visuales-oscuro")
	var dark_panel = ui.panel_style()
	check(dark_panel is StyleBoxFlat and dark_panel.bg_color.a==1 and dark_panel.bg_color.get_luminance()<0.3 and ui.BG.get_luminance()<dark_panel.bg_color.get_luminance() and contrast(ui.TEXT,dark_panel.bg_color)>7,"Dark theme uses opaque dark panels, darker background and light lettering") # 11
	ui.collection.restos = 100
	await switch_screen("home")
	var home_menu = meta(ui,"home_main_menu")
	check(text(meta(ui,"home_account"),"Jugador de prueba").get_theme_color("font_color")==Color("fffaf0") and meta(ui,"restos_balance").text=="100 Restos" and home_menu.get_parent().get_theme_stylebox("panel").bg_color.get_luminance()<0.3 and text(ui,"Tienda") != null,"Dark home retains light identity and wallet beside compact store access") # 12
	await shot("07-inicio-oscuro")
	ui.collection.restos = 650
	await switch_screen("shop")
	price = meta(ui,"shop_price",150)
	grid = meta(ui,"shop_grid")
	check(price.get_theme_color("font_color")==ui.TEXT and price.get_theme_stylebox("normal").bg_color.get_luminance()<0.4 and contrast(ui.TEXT,price.get_theme_stylebox("normal").bg_color)>4.5 and meta(ui,"shop_balance").text=="650 Restos" and grid.get_global_rect().end.x<=ui.size.x-36,"Dark shop keeps light prices and header balance inside the viewport") # 13
	await shot("08-tienda-oscuro")
	await switch_screen("missions")
	rows = all_meta(ui,"compact_mission")
	check(rows.size()==4 and rows.all(func(row):return row.size.y<=110 and row.get_theme_stylebox("panel").bg_color.get_luminance()<0.3) and text(ui,"Juega 1 partida").get_theme_color("font_color")==ui.TEXT and RestosArt.texture()!=null and NormalPackArt.texture(false)!=null and NormalPackArt.texture(true)!=null,"Dark missions remain compact and display all new reward artwork") # 14
	await shot("09-misiones-oscuro")
	check(ui.quit_dialog.get_label().get_theme_color("font_color")==ui.TEXT and ui.quit_dialog.get_theme_stylebox("panel","AcceptDialog").bg_color.get_luminance()<0.3,"Exit confirmation follows the dark theme too") # 15
	ui.show_help()
	var help_rich = class_node(ui.overlay_shades.back(),"RichTextLabel")
	var help_ok = help_rich != null and help_rich.get_theme_color("default_color")==ui.TEXT
	dismiss()
	ui.show_log()
	var log_rich = class_node(ui.overlay_shades.back(),"RichTextLabel")
	check(help_ok and log_rich != null and log_rich.get_theme_color("default_color")==ui.TEXT,"Help and match log retain readable light RichText content") # 16
	dismiss()
	await switch_screen("shop")
	var code = ui.collection.shop[0].code
	var old_amount = ui.collection.restos
	ui.shop.confirm_purchase(code,int(ui.collection.shop[0].price))
	var escape = InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	ui._unhandled_key_input(escape)
	check(ui.overlay_shades.is_empty() and ui.shop.pending_purchase.is_empty() and ui.collection.restos==old_amount and not ui.collection.busy,"Escape cancels purchase confirmation without request or currency change") # 17
	ui.dark_theme = false
	ui.apply_visual_palette()
	ui.load_visual_settings()
	check(ui.dark_theme and ui.TEXT==Color("f8f0de") and not ui.account.busy and not ui.collection.busy,"Saved dark setting reloads independently of accounts and network") # 18
	await switch_screen("challenges")
	await shot("10-niveles-oscuro")
	restore_visual_cfg()
	var restored = FileAccess.get_file_as_bytes(fixture_cfg_path)==previous_visual_cfg if had_visual_cfg else not FileAccess.file_exists(fixture_cfg_path)
	print(JSON.stringify({"theme_v016_checks":checks,"declared_checks":declared_checks,"resume_persistence":resume_persistence,"fixture_preferences_only":true,"failures":failures,"fixture_only":true,"network_requests":0,"real_rewards_claimed":0,"preferences_restored":restored}))
	ui.sound.shutdown()
	ui.queue_free()
	await settle()
	quit(0 if failures.is_empty() and restored else 1)
