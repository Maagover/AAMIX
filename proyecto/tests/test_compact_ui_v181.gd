extends "res://tests/test_online_final_ui_v180.gd"

func mission(id,title,scope,progress,target,claimed):
	return {"id":id,"title":title,"scope":scope,"progress":progress,"target":target,"claimed":claimed,"reward_kind":"restos","reward_amount":25}

func check_mission_rows(scope):
	for entry in [{"id":"pending","dim":false,"disabled":true},{"id":"ready","dim":false,"disabled":false},{"id":"claimed","dim":true,"disabled":true}]:
		var row=metas("mission_row").filter(func(n):return n.get_meta("mission_row")==entry.id)[0]
		var button=nodes(row).filter(func(n):return n.has_meta("claim_mission"))[0]
		check(is_equal_approx(row.get_parent().modulate.a,.72 if entry.dim else 1.0) and button.disabled==entry.disabled,scope+": "+entry.id+" has the correct opacity and claim availability")

func run():
	root.size=Vector2i(1600,1000)
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	ui.account.set_process(false);ui.account.configured=false;ui.account.remember_me=false;ui.account.refresh_token=""
	ui.online.set_process(false);ui.online.realtime.set_process(false);ui.rewards.set_process(false);ui.social.set_process(false)
	await settle()
	ui.account.user={"id":"00000000-0000-4000-8000-000000000181"};ui.account.access_token="local-fixture-not-a-credential"
	ui.account.expires_at=Time.get_unix_time_from_system()+3600;ui.session_owner=ui.account.player_id();ui.guest=false
	var previous=ui.collection;previous.changed.disconnect(ui.collection_changed)
	ui.collection=FixtureCollection.new();ui.collection.account=ui.account;ui.add_child(ui.collection);ui.collection.changed.connect(ui.collection_changed);previous.queue_free()
	ui.collection.owner_id=ui.account.player_id();ui.collection.loaded=true;ui.collection.cards={"0100":62,"0101":3,"0117":1};ui.collection.restos=1000
	ui.collection.restos_welcome_claimed=true;ui.collection.welcome_pack={"claimed":true};ui.collection.event_refresh_tick=Time.get_ticks_msec()+999999
	ui.screen="cards";ui.cards_tab="collection";ui.render();await settle()
	check(labels("(x62) 0100 - Restos").size()==1,"Owned cards use the compact quantity, number and name format")
	var absent=metas("collection_code").filter(func(n):return n.get_meta("collection_code")=="0105")[0]
	var absent_labels=nodes(absent).filter(func(n):return n is Label)
	check(absent_labels.size()==1 and absent_labels[0].text=="0105","Unowned card shows its number only")
	var caption=metas("collection_card_caption").filter(func(n):return n.get_meta("collection_card_caption")=="0117")[0]
	check(caption.max_lines_visible==2 and caption.get_theme_font_size("font_size") in range(11,15) and caption.size.x<=156 and caption.get_line_count()<=2,"Long names fit a compact caption of at most two lines")
	check(not nodes(ui).any(func(n):return n is Label and n.text.begins_with("Cantidad:")),"Collection no longer adds a separate quantity line")
	await shot("01-coleccion-compacta")
	ui.collection.shop=[{"code":"0101","price":150},{"code":"0105","price":500}];ui.screen="shop";ui.render();await settle()
	check(metas("shop_card_details").size()==2 and metas("shop_card_details").all(func(n):return n.get_theme_constant("separation")==2),"Shop number and name share a compact two-pixel gap")
	check(labels("0101").size()==1 and labels("Nonungus").size()==1,"Shop retains separate number and name")
	await shot("02-tienda-espaciado")
	ui.shop.confirm_purchase("0101",150);await settle()
	check(labels("(Tienes: 3)").size()==1 and ui.collection.calls.is_empty(),"Owned quantity remains in confirmation and opening it does not purchase")
	for scope in ["daily","lifetime"]:
		ui.collection.missions=[mission("pending","Misión en progreso",scope,1,3,false),mission("ready","Misión lista para reclamar",scope,3,3,false),mission("claimed","Recompensa reclamada",scope,3,3,true)]
		ui.screen="missions";ui.rewards.mission_tab=scope;ui.render();await settle();check_mission_rows(scope)
		await shot("03-misiones-"+scope)
	ui.collection.missions=[mission("play_one","Juega 1 partida","daily",0,1,false)]
	ui.rewards.mission_tab="daily";ui.render();await settle()
	check(metas("completed_mission_dimmed").is_empty() and metas("claim_mission")[0].disabled,"Daily mission returns to normal after the next server day resets its claim state")
	var event=JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events[0]
	event.missions=event.missions.slice(0,3)
	for i in range(3):event.missions[i].progress=0 if i==0 else event.missions[i].target;event.missions[i].claimed=i==2
	ui.collection.events=[event];ui.collection.events_deadline_tick=Time.get_ticks_msec()+60000
	ui.screen="event";ui.render();await settle()
	for i in range(3):
		var state=event.missions[i]
		var row=metas("event_mission_row").filter(func(n):return n.get_meta("event_mission_row")==state.id)[0]
		var claim=nodes(row).filter(func(n):return n.has_meta("claim_event_mission"))[0]
		check(is_equal_approx(row.get_parent().modulate.a,.72 if i==2 else 1.0) and claim.disabled==(i!=1),"Event mission state "+str(i)+" matches standard mission opacity")
	await shot("04-evento-estados")
	ui.screen="account";ui.render();await settle()
	var base=ui.profiles.ally_codes().filter(func(code):return code not in ["0112","0113","0114","0126","01a","01b"]).slice(0,2)
	ui.collection.available_avatar_codes=base.duplicate();ui.profiles.show_picker();await settle()
	check(ui.profiles.choices.keys()==base and metas("avatar_locked").is_empty(),"Picker shows only server-enabled photos, with no locked placeholders")
	ui.profiles.select("0114");check(ui.profiles.selected_code!="0114","Hidden locked photo cannot be selected through its callback")
	await shot("05-fotos-disponibles")
	ui.profiles.close();await settle();ui.collection.available_avatar_codes.append_array(["0114","01b"]);ui.profiles.show_picker();await settle()
	check(ui.profiles.choices.has("0114") and ui.profiles.choices.has("01b") and ui.profiles.choices.size()==4,"Mission and gift-code photos appear after their server entitlements are received")
	ui.profiles.select("01b");check(ui.profiles.selected_code=="01b" and not ui.profiles.save_button.disabled,"Newly unlocked photo can be selected for saving")
	await shot("06-fotos-desbloqueadas")
	ui.profiles.close();await settle();ui.collection.cards.clear();ui.profiles.show_picker();await settle()
	check(ui.profiles.choices.has("0114") and ui.profiles.choices.has("01b"),"Permanent photo unlocks remain available independently of traded card copies")
	ui.profiles.close();await settle();ui.collection.available_avatar_codes=[];ui.profiles.show_picker();await settle()
	check(ui.profiles.choices.is_empty() and ui.profiles.save_button.disabled,"Empty photo availability does not expose locked options or allow saving")
	ui.profiles.close();await settle()
	ui.game=game_fixture();ui.game.winner=0;ui.started=true;ui.human=0;ui.computer=1;ui.screen="table";ui.render();await settle()
	ui.rewards.show_challenge_bonus(5);await settle()
	var toast=metas("challenge_repeat_bonus")[0];var icon=nodes(toast).filter(func(n):return n.has_meta("restos_icon"))[0];var text=labels("+5 Restos")[0]
	check(toast.size.x<300 and text.get_theme_font_size("font_size")==18,"Post-match bonus notice is smaller than the previous 300px/23pt notice")
	check(icon.texture!=null and icon.custom_minimum_size==Vector2(25,25) and icon.get_global_rect().end.x<text.get_global_rect().position.x,"Original Restos artwork appears to the left of the bonus text")
	await shot("07-bono-con-restos")
	check(ui.collection.calls.is_empty(),"All presentation checks avoid external requests and account mutations")
	ui.sound.shutdown();ui.queue_free();await settle()
	print(JSON.stringify({"compact_ui_v181":{"checks":checks,"failures":failures,"captures":captures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
