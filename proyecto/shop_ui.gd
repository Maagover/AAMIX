extends Node
const RestosArt = preload("res://restos_art.gd")
var board
var account_owner = ""
var pending_purchase = {}

func setup(value):
	board = value
	return self

func _process(_delta):
	if board != null and account_owner != board.account.player_id():
		account_owner = board.account.player_id()
		pending_purchase.clear()

func render_screen():
	if board.guest or not board.account.signed_in():
		board.screen = "account"
		board.render_account()
		return
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,38)
	board.add_child(margin)
	var outer = board.box(margin,true,18)
	var header = board.box(outer,false,18)
	header.add_child(board.home_logo(210,50))
	header.add_child(board.fill(board.label("Tienda",30,board.GOLD)))
	var balance = board.box(header,false,8)
	balance.alignment = BoxContainer.ALIGNMENT_CENTER
	balance.add_child(RestosArt.view(32))
	var amount = board.label("%d Restos" % board.collection.restos,23,board.TEXT)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.set_meta("shop_balance",true)
	balance.add_child(amount)
	header.add_child(board.reload_button(board.collection.load_inventory,board.collection.busy))
	header.add_child(board.button("Inicio",board.go_home))
	if not board.collection.loaded:
		outer.add_child(board.centered_label("Cargando tienda…",22,board.MUTED))
		return
	if not pending_purchase.is_empty():
		var retry = board.box(board.panel(outer),false,16)
		retry.add_child(board.fill(board.label("Confirmando tu compra de %s…" % board.game.catalog[pending_purchase.code].nombre,18,board.MUTED)))
		retry.add_child(board.button("Reintentar",complete_purchase,board.collection.busy))
	if not board.collection.status.is_empty():
		outer.add_child(board.label(board.collection.status,17,board.MUTED))
	var icon_center = CenterContainer.new(); outer.add_child(icon_center)
	icon_center.add_child(preload("res://floating_icon.gd").new().configure(preload("res://cart_icon.gd").new().configure(96),Vector2(96,108),board.animations_enabled))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",18)
	grid.set_meta("shop_grid",true)
	center.add_child(grid)
	var available = board.collection.shop.filter(func(entry): return entry is Dictionary and board.game.catalog.has(str(entry.get("code",""))))
	available.sort_custom(func(a,b):
		if int(a.price)!=int(b.price): return int(a.price)<int(b.price)
		return str(a.code).naturalnocasecmp_to(str(b.code))<0
	)
	for entry in available:
		if not board.game.catalog.has(entry.code): continue
		var card = board.game.catalog[entry.code]
		if card.clase == "Recurso" or str(card.get("subcoleccion","")) in ["promocional","promocionales"]: continue
		var item = board.box(board.panel(grid),true,9)
		item.custom_minimum_size.x = 184
		item.set_meta("shop_card",entry.code)
		item.tooltip_text = card.nombre
		var picture = board.catalog_image(entry.code,154,210)
		picture.set_meta("shop_card_image",entry.code)
		item.add_child(picture)
		var details = board.box(item,true,2)
		details.set_meta("shop_card_details",entry.code)
		details.add_child(board.centered_label(str(entry.code),15,board.GOLD))
		var name_label = board.centered_label(card.nombre,15,board.TEXT)
		name_label.custom_minimum_size = Vector2(154,38)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.set_meta("shop_card_name",entry.code)
		details.add_child(name_label)
		var price = board.button("%d Restos" % entry.price,confirm_purchase.bind(str(entry.code),int(entry.price)),board.collection.busy or not pending_purchase.is_empty() or board.collection.restos<int(entry.price),true)
		price.add_theme_font_size_override("font_size",17)
		price.set_meta("shop_price",int(entry.price))
		price.tooltip_text = "Comprar " + card.nombre
		item.add_child(price)

func confirm_purchase(code,price):
	if board.collection.busy or not pending_purchase.is_empty() or board.collection.restos<price: return
	var expected_owner = board.account.player_id()
	var center = board.overlay("purchase")
	var shade = center.get_parent()
	var content = board.box(board.panel(center),true,16)
	content.custom_minimum_size = Vector2(550,430)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(board.centered_label("¿Comprar %s?" % board.game.catalog[code].nombre,27,board.GOLD))
	content.add_child(board.catalog_image(code,170,230))
	var owned = board.centered_label("(Tienes: %d)" % int(board.collection.cards.get(code,0)),15,board.MUTED)
	owned.set_meta("purchase_owned",code)
	content.add_child(owned)
	content.add_child(board.centered_label("%d Restos" % price,23,board.TEXT))
	var actions = board.box(content,false,16)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(board.button("Comprar",func():
		if expected_owner != board.account.player_id(): return
		board.close_overlay(shade)
		pending_purchase={"id":board.collection.request_id(),"code":code,"owner":board.account.player_id()}
		complete_purchase()
	,false,true))
	actions.add_child(board.button("Cancelar",board.close_overlay.bind(shade)))

func complete_purchase():
	if pending_purchase.is_empty() or board.collection.busy: return
	var expected = pending_purchase.duplicate(true)
	var ok = await board.collection.purchase_card(expected.id,expected.code)
	if expected.owner != board.account.player_id(): return
	if ok:
		pending_purchase.clear()
		board.collection.status = ""
		if board.screen=="shop":
			board.render()
			board.celebrate_reward("¡Carta obtenida!",board.game.catalog[expected.code].nombre,board.texture_code(expected.code))
	else:
		if board.collection.last_http_code>=400 and board.collection.last_http_code<500:
			pending_purchase.clear()
		if board.screen=="shop": board.render()
