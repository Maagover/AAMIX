extends RefCounted
## Layout coordinates follow the author's 916 x 1717 board reference.
var b
var stage
func _init(board):b=board
func place(node, rect):
	stage.add_child(node);node.position=rect.position;node.size=rect.size
	return node
func label_at(value,rect,size=24,center=false,color=Color("493720")):
	var node=b.label(value,size,color);node.set_meta("reference_text",true);node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return place(node,rect)
func skin(node,button=false,gold=false):
	var texture=b.visual_theme.textured(("boton_dorado.png" if gold else "boton_blanco.png") if button else "panel_blanco.png",button)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:texture.set_content_margin(side,0)
	if node is Button:
		for state in ["normal","hover","pressed","focus"]:node.add_theme_stylebox_override(state,texture)
	else:node.add_theme_stylebox_override("panel",texture)
func render():
	var bg=ColorRect.new();bg.color=Color("141414");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.add_child(bg)
	stage=Control.new();stage.name="ReferenceBoard";stage.mouse_filter=Control.MOUSE_FILTER_PASS;stage.size=Vector2(916,1717);stage.set_meta("reference_size",stage.size);b.add_child(stage)
	fit()
	b.mobile.page_root=stage
	var logo=b.home_logo(190,60);place(logo,Rect2(42,110,190,60))
	var badge=Panel.new();skin(badge);place(badge,Rect2(255,121,245,46))
	label_at(("TU TURNO" if b.game.active==b.human else "TURNO RIVAL")+" · Turno %d"%b.game.turn,Rect2(265,121,225,46),22,true)
	header_button("Ajustes",b.show_configuration,680)
	header_button("Registro",b.show_log,758)
	header_button("Salir",b.confirm_abandon_match,835)
	var rival=b.game.players[b.computer].hand
	var card_width=78.0;var step=minf(42,280.0/maxi(1,rival.size()-1));var start=(916-card_width-step*(rival.size()-1))/2.0
	b.hand_slots[b.computer]={}
	for i in range(rival.size()):b.hand_slots[b.computer][rival[i]]=place(b.asset_image("dorso.jpg",78,110),Rect2(start+i*step,251,78,110))
	var pile_names=["resources","paid","deck","graveyard","burned"]
	for i in range(5):pile(pile_names[i],b.computer,Rect2(17+i*180,390,161,83),false)
	lane(b.computer,"defense","DEFENSA\nRIVAL",Rect2(15,488,886,123))
	lane(b.computer,"attack","ATAQUE\nRIVAL",Rect2(15,633,886,123))
	var domain=b.zone(stage,"domain",-1,b.game.domain_uid);domain.position=Vector2(346,783);domain.size=Vector2(224,138);domain.set_meta("shared_domain",true);domain.set_meta("pile",true)
	var domain_style=b.style(Color("151515"),Color("ac8a25"),27);domain.add_theme_stylebox_override("panel",domain_style);domain.set_meta("base_style",domain_style)
	var word=b.centered_label("DOMINIO",25,Color("fff0d3"));domain.add_child(word)
	if b.game.domain_uid!=-1:word.hide();domain.add_child(b.image_card(b.game.domain_uid,90,126))
	b.attach_indicator(domain)
	pile("paid",b.human,Rect2(70,946,53,70),true)
	pile("deck",b.human,Rect2(55,1021,82,113),true)
	pile("resources",b.human,Rect2(70,1141,53,70),true)
	pile("graveyard",b.human,Rect2(40,1220,114,123),true)
	pile("burned",b.human,Rect2(40,1356,114,123),true)
	lane(b.human,"attack","TU\nATAQUE",Rect2(163,948,738,123))
	lane(b.human,"defense","TU\nDEFENSA",Rect2(163,1084,738,123))
	var hand=b.zone(stage,"hand",b.human);hand.position=Vector2(175,1240);hand.size=Vector2(715,238);hand.add_theme_stylebox_override("panel",b.card_style())
	var hand_content=Control.new();hand_content.mouse_filter=Control.MOUSE_FILTER_PASS;hand.add_child(hand_content)
	var cards=b.game.players[b.human].hand;var spacing=minf(85,575.0/maxi(1,cards.size()-1));var total=130+spacing*(cards.size()-1)
	b.hand_slots[b.human]={}
	for i in range(cards.size()):
		var uid=cards[i];var card=b.card(hand_content,uid,"hand",b.human,130,184,uid==int(b.tap_selection.get("uid",-1)))
		card.position=Vector2((715-total)/2+i*spacing,12+25*absf((i-(cards.size()-1)/2.0)/maxf(1,(cards.size()-1)/2.0)))
		card.size=Vector2(130,184);card.set_meta("hand_fan",true)
		b.hand_slots[b.human][uid]=card
	var quiet_main=b.game.phase in ["main","after_combat"] and b.game.pending.is_empty() and b.game.payment_request.is_empty() and b.game.error.is_empty()
	b.action_panel=PanelContainer.new();b.action_panel.set_meta("actions",true);b.action_panel.add_theme_stylebox_override("panel",b.card_style());place(b.action_panel,Rect2(89,1537 if quiet_main else 1490,738,72 if quiet_main else 155));b.action_bar(b.action_panel)
	for node in b.interface_nodes(b.action_panel):
		if node is Label:
			node.custom_minimum_size.x=0;node.add_theme_font_size_override("font_size",18)
			node.text=node.text.replace("→"," / ").replace("Arrastra","Toca").replace("arrastra","toca").replace("Doble clic","Mantén pulsado").replace("doble clic","pulsación larga")
			if node.text=="ACCIONES" or node.text.is_empty() or quiet_main:node.hide()
		if node is Button:
			node.custom_minimum_size=Vector2(358,72);node.add_theme_font_size_override("font_size",25);skin(node,true,node.get_meta("primary",false))
			if node.text.begins_with("Declarar ataque"):node.icon=b.UIIcons.texture("swords");node.expand_icon=true;node.add_theme_constant_override("icon_max_width",42)
			elif node.text=="Robar y terminar":node.icon=svg_icon('<path d="M4 4l15 16L4 36zm18 0l15 16-15 16z" fill="#715121"/>');node.expand_icon=true;node.add_theme_constant_override("icon_max_width",38)
	if b.tutorial.active:b.tutorial.decorate_board()
	for uid in b.moving_uids:b.hide_visual_uid(uid)
	if not b.presenting:
		if not b.game.pending.is_empty() and int(b.game.pending.player)==b.human and b.game.pending.kind not in ["end_discard","limit_keep"] and not b.choice_dismissed:b.show_choice()
		elif b.game.winner!=-1 and not b.overlay_shades.any(func(n):return n.get_meta("overlay_kind","")=="result"):b.show_winner()
func fit():
	if not is_instance_valid(stage):return
	var size=b.get_viewport_rect().size;var ratio=minf(size.x/916.0,size.y/1717.0)
	stage.scale=Vector2.ONE*ratio;stage.position=(size-Vector2(916,1717)*ratio)/2
func header_button(caption,action,x):
	var button=b.button("",action);button.tooltip_text=caption;skin(button,true);place(button,Rect2(x,108,64,60))
	var icon
	if caption=="Ajustes":icon=b.asset_image("estetica_v150/configuracion.png",38,38)
	elif caption=="Registro":
		icon=TextureRect.new();icon.texture=svg_icon('<path d="M9 3h16l9 9v25H9zM25 3v10h9M15 20h13M15 26h13" fill="none" stroke="#493720" stroke-width="2.6" stroke-linejoin="round"/>');icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:icon=b.centered_label("×",46,b.TEXT)
	button.add_child(icon);icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if caption=="Registro":icon.offset_left=13;icon.offset_right=-13;icon.offset_top=10;icon.offset_bottom=-10
func svg_icon(content):
	var image=Image.new();image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40">'+content+'</svg>')
	return ImageTexture.create_from_image(image)
func pile(zone,owner,rect,own):
	var cards=b.game.players[owner][zone];var uid=-1 if cards.is_empty() or zone=="deck" else cards.back()
	if zone=="paid" and not b.game.reserved[owner].is_empty():uid=b.game.reserved[owner].back()
	var holder=b.zone(stage,zone,owner,uid);holder.position=rect.position;holder.size=rect.size;holder.set_meta("pile",true)
	var titles={"resources":"RECURSOS","paid":"PAGADAS","deck":"MAZO","graveyard":"CEMENTERIO","burned":"QUEMADAS"}
	var graphic=own and zone in ["resources","paid","deck"]
	if graphic:
		holder.add_theme_stylebox_override("panel",b.card_style())
		if zone=="deck" or uid!=-1:
			var art=b.asset_image("dorso.jpg",rect.size.x,rect.size.y) if zone=="deck" else b.image_card(uid,rect.size.x,rect.size.y);holder.add_child(art);holder.set_meta("pile_image",art)
	else:
		var box=b.style(Color("bbb7ad"),Color.TRANSPARENT,15);for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:box.set_content_margin(side,0)
		holder.add_theme_stylebox_override("panel",box);holder.set_meta("base_style",box)
		var title=b.centered_label(titles[zone],24 if own else 17,b.TEXT);title.vertical_alignment=VERTICAL_ALIGNMENT_TOP;holder.add_child(title)
	var count=b.centered_label("",16,Color("fff3d9") if graphic else b.TEXT);
	if graphic:count.add_theme_color_override("font_outline_color",Color.BLACK);count.add_theme_constant_override("outline_size",2)
	count.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM;count.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(count);b.register_count(count,owner,zone)
	if own and zone in ["graveyard","burned"]:holder.clicked=b.inspect_zone.bind(owner,zone)
	holder.tooltip_text=titles[zone];b.attach_indicator(holder)
func lane(owner,zone,title,rect):
	var holder=b.zone(stage,zone,owner);holder.position=rect.position;holder.size=rect.size
	var box=b.style(Color("bbb7ad"),Color.TRANSPARENT,13);box.content_margin_left=0;box.content_margin_top=0;box.content_margin_bottom=0;box.content_margin_right=0;holder.add_theme_stylebox_override("panel",box)
	var content=Control.new();content.mouse_filter=Control.MOUSE_FILTER_PASS;holder.add_child(content)
	var caption=b.label(title,24,b.TEXT);caption.position=Vector2(18,14);content.add_child(caption)
	var scroll=ScrollContainer.new();scroll.position=Vector2(155 if owner==b.computer else 140,5);scroll.size=Vector2(rect.size.x-scroll.position.x-10,113);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.scroll_deadzone=24;content.add_child(scroll)
	var row=b.box(scroll,false,10);row.mouse_filter=Control.MOUSE_FILTER_PASS
	var cards=b.game.players[owner][zone].duplicate()
	if owner==b.human and zone=="defense":cards=cards.filter(func(u):return u not in b.draft)
	if owner==b.human and zone=="attack":cards.append_array(b.draft)
	for uid in cards:
		var card=b.card(row,uid,"draft_attack" if uid in b.draft else zone,owner,80,110,uid in b.draft or b.block_marker_visible(uid))
		if owner==b.computer:
			for art in card.get_children():
				if art is TextureRect:
					card.remove_child(art)
					var wrapper=Control.new();wrapper.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(wrapper);wrapper.add_child(art)
					art.size=Vector2(80,110);art.pivot_offset=Vector2(40,55);art.rotation=PI
