extends RefCounted
var b
var scroll
var previous
var following
var movement
var pitch=0.0
func _init(board):b=board
func render_screen():
	if is_instance_valid(movement):movement.kill()
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,30)
	b.add_child(margin);var content=b.box(margin,true,12)
	var logo=CenterContainer.new();content.add_child(logo);logo.add_child(b.asset_image("logo_color.png",280,60,true))
	content.add_child(b.centered_label("Desafío AAMIX",28,Color("fff0d2")))
	var center=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(center)
	scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(b.get_viewport_rect().size.x-60,minf(650,b.get_viewport_rect().size.y-220))
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_meta("challenge_carousel",true);center.add_child(scroll)
	var row=b.box(scroll,false,24);row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var width=b.get_viewport_rect().size.x*0.82;pitch=width+24
	var edge=(scroll.custom_minimum_size.x-width)/2
	var start=Control.new();start.custom_minimum_size.x=edge;row.add_child(start)
	for definition in b.CHALLENGES:level_card(row,definition,width,scroll.custom_minimum_size.y)
	var end=Control.new();end.custom_minimum_size.x=edge;row.add_child(end)
	b.challenge_page=clampi(b.challenge_page,0,b.CHALLENGES.size()-1)
	var controls=b.box(content,false,16);controls.alignment=BoxContainer.ALIGNMENT_CENTER
	previous=b.button("‹",change_page.bind(-1));previous.set_meta("challenge_previous",true);previous.custom_minimum_size.x=64;previous.tooltip_text="Nivel anterior";controls.add_child(previous)
	following=b.button("›",change_page.bind(1));following.set_meta("challenge_next",true);following.custom_minimum_size.x=64;following.tooltip_text="Nivel siguiente";controls.add_child(following)
	controls.add_child(b.button("Volver",b.open_single));update_arrows()
	scroll.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			change_page(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1);scroll.accept_event())
	position_initial.call_deferred(scroll)
func position_initial(target):
	await b.get_tree().process_frame
	await b.get_tree().process_frame
	if is_instance_valid(target) and target==scroll:target.scroll_horizontal=roundi(b.challenge_page*pitch)
func level_card(parent,definition,width,height):
	var holder=b.panel(parent);holder.custom_minimum_size=Vector2(width,height);holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var item=b.box(holder,true,10);item.set_meta("challenge_stage",definition.stage)
	item.add_child(b.centered_label("Nivel %d"%definition.stage,23,b.GOLD))
	var state=b.challenge_state(definition.stage)
	if not state.get("unlocked",false):
		holder.modulate.a=0.42;holder.set_meta("locked_challenge",definition.stage)
		var center=CenterContainer.new();center.size_flags_vertical=Control.SIZE_EXPAND_FILL;item.add_child(center)
		var locked=b.box(center,true,12);locked.add_child(b.UIIcons.view("lock",150));locked.add_child(b.centered_label("Bloqueado",23,b.GOLD));return
	item.add_child(b.centered_label(definition.title,21,b.GOLD))
	var row=b.box(item,false,22);row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var cover=CenterContainer.new();cover.custom_minimum_size.x=270;row.add_child(cover);cover.add_child(b.deck_cover(definition.deck_id,250,315))
	var missions=b.box(row,true,10);missions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;missions.alignment=BoxContainer.ALIGNMENT_CENTER
	var completed=bool(state.get("completed",false))
	mission_row(missions,definition.stage,{"id":"first_victory","title":"Primera victoria","goal":1,"progress":1 if completed else 0,"claimed":completed,"can_claim":false,"reward_packs":definition.reward_packs,"reward_cover":definition.has("reward_cover")})
	for m in state.get("missions",[]):mission_row(missions,definition.stage,m)
	var play=CenterContainer.new();item.add_child(play)
	var play_button=b.button("Volver a jugar" if completed else "Jugar nivel",b.choose_challenge.bind(definition.stage),b.collection.busy,true)
	play_button.custom_minimum_size.x=380;play_button.set_meta("play_challenge",definition.stage);play.add_child(play_button)
func update_arrows():
	previous.disabled=b.challenge_page<=0;following.disabled=b.challenge_page>=b.CHALLENGES.size()-1
func change_page(delta):
	b.challenge_page=clampi(b.challenge_page+delta,0,b.CHALLENGES.size()-1);update_arrows()
	if not is_instance_valid(scroll):return
	if is_instance_valid(movement):movement.kill()
	if not b.animations_enabled:scroll.scroll_horizontal=roundi(b.challenge_page*pitch);return
	movement=b.create_tween();movement.tween_property(scroll,"scroll_horizontal",roundi(b.challenge_page*pitch),0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func mission_row(parent,stage,m):
	var reward="%d sobre%s TC"%[int(m.reward_packs),"s" if int(m.reward_packs)!=1 else ""]
	if m.get("reward_cover",false):reward+=" + diseño de mazo"
	var model={"title":m.title,"caption":reward,"scope":"Única","progress":m.progress,"goal":m.goal,"claimed":m.get("claimed",false),"ready":m.get("can_claim",false),"prizes":[{"kind":"tc_pack","amount":int(m.reward_packs),"texture":preload("res://pack_art.gd").texture(false)}]}
	if m.id=="first_victory":model.pending_hint="Primera victoria: entrega automática al ganar"
	var ui=preload("res://mission_row.gd").render(b,parent,model,claim.bind(stage,str(m.id)))
	ui.shell.set_meta("level_mission",m.id);ui.icon.set_meta("challenge_reward",m.id)
	if ui.bar!=null:ui.bar.set_meta("challenge_progress",true)
func claim(stage,id):
	if id=="first_victory":return
	if await b.collection.claim_challenge_mission(stage,id):b.celebrate_reward("¡Misión completada!","Los sobres están en Mis sobres.")
