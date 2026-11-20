extends SceneTree
var ui
var role=0
var shared=""
var fixture=""
var deadline=0
var failures=[]
var old_room=""
var new_room=""
func _initialize():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):role=int(a.trim_prefix("--role="))
		if a.begins_with("--shared="):shared=a.trim_prefix("--shared=")
		if a.begins_with("--fixture="):fixture=a.trim_prefix("--fixture=")
	run.call_deferred()
func save(name,value):
	var f=FileAccess.open(shared.path_join(name+str(role)+".json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
func read(name):
	var p=shared.path_join(name+".json")
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
func wait_for(test,label):
	while Time.get_ticks_msec()<deadline:
		if test.call():return true
		await create_timer(.1).timeout
	failures.append(label);printerr("FAIL: ",label);return false
func nodes(n):
	var all=[n]
	for c in n.get_children():all.append_array(nodes(c))
	return all
func press(text):
	for n in nodes(ui):
		if n is Button and n.text==text and not n.disabled:n.pressed.emit();return true
	failures.append("Missing enabled button "+text);return false
func run():
	deadline=Time.get_ticks_msec()+180000
	var f=JSON.parse_string(FileAccess.get_file_as_string(fixture));var own=f.users[role]
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=true
	ui.account.set_process(false);ui.social.set_process(false);ui.rewards.set_process(false)
	ui.account.remember_me=false;ui.account.refresh_token=""
	ui.account.user={"id":own.id};ui.account.access_token=own.access_token;ui.account.expires_at=own.expires_at
	ui.account.service_url=f.url;ui.account.publishable_key=f.publishable_key
	ui.session_owner=own.id;ui.guest=false;ui.welcome_notified[own.id]=true;ui.screen="multiplayer"
	if not await ui.collection.load_inventory():failures.append("HTTPS inventory: "+ui.collection.status);await finish();return
	if role==0:
		await ui.online.create_room("papito")
		if ui.online.room.is_empty():failures.append("Create room: "+ui.online.status);await finish();return
		save("room",{"id":ui.online.room.room_id,"code":ui.online.room.code})
	else:
		if not await wait_for(func():return read("room0")!=null,"Host room"):await finish();return
		await ui.online.join_room(read("room0").code,"flaan")
	await ui.online.confirm()
	if not await wait_for(func():return ui.online.in_match() and ui.started and ui.screen=="table","First game starts"):await finish();return
	old_room=str(ui.online.room.room_id)
	save("connected",{"room_id":old_room,"user_id":own.id})
	# The harness closes this first game with a server-side synthetic result.
	# The rematch itself must start through the real two-client protocol.
	if not await wait_for(func():return ui.game.winner!=-1 and not ui.presenting and not ui.fx.busy,"Fixture result received"):await finish();return
	if not press("Revancha"):await finish();return
	if not await wait_for(func():return not ui.online.busy and ui.online.room.get("rematch",{}).get("requested",[false,false])[role],"Revancha request"):await finish();return
	var chosen="kajido" if role==0 else "girabl"
	var chooser=null
	for n in nodes(ui):
		if n is OptionButton and n.has_meta("rematch_deck"):chooser=n
	var decks=ui.collection.playable_decks()
	if chooser==null:failures.append("Deck chooser missing");await finish();return
	for i in range(decks.size()):
		if str(decks[i].id)==chosen:chooser.select(i);chooser.item_selected.emit(i)
	if not await wait_for(func():return not ui.online.busy and ui.online.room.get("rematch",{}).get("deck_id","")==chosen,"Changed deck acknowledged"):await finish();return
	if not await wait_for(func():return ui.online.room.get("rematch",{}).get("requested",[false,false])==[true,true],"Both requested"):await finish();return
	ui.render()
	if not press("Confirmar revancha"):await finish();return
	if not await wait_for(func():return ui.online.in_match() and str(ui.online.room.room_id)!=old_room and ui.started and ui.screen=="table","Second game starts with both ready"):await finish();return
	new_room=str(ui.online.room.room_id)
	if ui.game.winner!=-1 or ui.game.phase!="setup":failures.append("New game retains old outcome or skips setup")
	if role==0 and (ui.game.players[0].deck_id!="kajido" or ui.game.players[1].deck_id!="girabl"):failures.append("Chosen decks not frozen")
	if role==1:
		for p in range(2):
			if ui.game.players[p].deck.any(func(u):return u>=0):failures.append("Hidden deck leaked")
	var current=str(ui.online.room.room_id)
	ui.online.receive({"room_id":old_room,"ruleset_version":ui.online.RULESET_VERSION,"revision":999,"room_version":999})
	if str(ui.online.room.room_id)!=current:failures.append("Late old response replaced new room")
	save("rematched",{"room":new_room,"chosen":chosen,"winner":ui.game.winner})
	await wait_for(func():return read("rematched0")!=null and read("rematched1")!=null,"Both clients rematched")
	if role==1:await ui.online.leave()
	else:await wait_for(func():return str(ui.online.room.get("status",""))=="finished","Peer leave closes new game")
	await finish()
func finish():
	var result={"role":role,"failures":failures,"old_room":old_room,"new_room":new_room,"actual_https":true,"synthetic_first_result":true,"two_remote_PCs":false}
	save("result",result);print(JSON.stringify(result))
	if ui!=null:ui.sound.shutdown();ui.queue_free()
	for i in range(5):await process_frame
	quit(0 if failures.is_empty() else 1)
