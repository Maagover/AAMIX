extends RefCounted
## Shared layout; reward eligibility and delivery remain server-owned.
static func render(b,parent,model,action):
	var holder=b.panel(parent);holder.set_meta("mission_card",true)
	var claimed=bool(model.get("claimed",false));holder.modulate.a=0.60 if claimed else 1.0
	if claimed:holder.set_meta("completed_mission_dimmed",true)
	var row=b.box(holder,false,14);row.alignment=BoxContainer.ALIGNMENT_CENTER
	var texts=b.box(row,true,5);texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var title=b.label(model.title,16,b.TEXT);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texts.add_child(title)
	var progress=int(model.progress);var goal=int(model.goal)
	var subtitle=b.label("%s \u00b7 %s \u00b7 %d/%d"%[model.caption,model.scope,progress,goal],12,b.MUTED)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texts.add_child(subtitle)
	var bar=null
	if goal>1:
		bar=ProgressBar.new();bar.max_value=goal;bar.value=progress;bar.show_percentage=false;bar.custom_minimum_size.y=12
		bar.add_theme_stylebox_override("background",b.style(Color("ddd1b8") if not b.dark_theme else Color("171b1d"),b.BORDER,6))
		bar.add_theme_stylebox_override("fill",b.style(Color("bd8625"),Color("e8b94a"),6));texts.add_child(bar)
	var ready=bool(model.get("ready",false)) and not claimed
	var icon=b.button("",action,not ready or b.collection.busy,ready);icon.set_meta("mission_reward_button",true)
	icon.custom_minimum_size=Vector2(maxi(72,model.prizes.size()*64),65);icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.tooltip_text="Reclamar "+model.caption if ready else ("Recompensa entregada" if claimed else model.get("pending_hint",model.caption))
	if ready:
		icon.add_theme_stylebox_override("normal",b.style(Color("41674d"),Color("afce87"),7))
		icon.add_theme_stylebox_override("hover",b.style(Color("547f5e"),Color("e3efaa"),7))
	for i in range(model.prizes.size()):
		var prize=model.prizes[i];var art
		if prize.get("kind","")=="avatar":art=b.profiles.avatar(prize.code,38)
		else:
			art=TextureRect.new();art.texture=prize.texture;art.custom_minimum_size=Vector2(37,50)
			art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.set_meta("mission_reward_icon",prize.get("kind","tc_pack"));icon.add_child(art);art.position=Vector2(12+i*64,5)
		var number=b.label("\u2713" if claimed else "\u00d7%d"%int(prize.amount),12,Color.WHITE if ready else b.MUTED)
		icon.add_child(number);number.position=Vector2(4+i*64,43);number.size=Vector2(60,18);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(icon)
	return {"shell":holder,"row":row,"icon":icon,"bar":bar,"subtitle":subtitle}
