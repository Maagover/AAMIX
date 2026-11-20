extends SceneTree
## Two separate native processes and two temporary confirmed synthetic accounts.
## Uses actual HTTPS RPC and normal engine actions; never forces a game outcome.
var ui
var role=-1
var base=""
var fixture_path=""
var failures=[]
var actions=0
var last_revision=-1
var payment_uid=-1
var payment_finished=false
var recovered=false
var guest_payment_checked=false
var snapshots_private=true
var got_setup=false
var turns_seen=[]
var deadline=0
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=int(arg.trim_prefix("--role="))
		if arg.begins_with("--shared="): base=arg.trim_prefix("--shared=")
		if arg.begins_with("--fixture="): fixture_path=arg.trim_prefix("--fixture=")
	run.call_deferred()
func save(name,value):
	var f=FileAccess.open(base.path_join(name+".json"),FileAccess.WRITE)
	if f!=null: f.store_string(JSON.stringify(value))
func read(name):
	var p=base.path_join(name+".json")
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
func fail(message):
	failures.append(message)
	printerr("FAIL ROLE ",role,": ",message)
func tick(): await create_timer(.15).timeout
func until_ready():
	while Time.get_ticks_msec()<deadline:
		if ui.online.in_match() and not ui.online.waiting_action() and not ui.online.busy: return true
		await tick()
	return false
func submit(method,args=[]):
	if ui.online.submit(method,args): actions+=1;last_revision=ui.online.revision;return true
	return false
func run():
	if role not in [0,1] or base.is_empty() or fixture_path.is_empty(): quit(1);return
	deadline=Time.get_ticks_msec()+180000
	DirAccess.make_dir_recursive_absolute(base)
	var fixtures=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var credentials=fixtures.users[role]
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.animations_enabled=false
	ui.automation_pause=true
	for _i in range(8): await process_frame
	var reply=await ui.account.send("/token?grant_type=password",{"email":credentials.email,"password":credentials.password})
	if not reply.get("ok",false) or not ui.account.accept_session(reply.data):
		fail("Synthetic password sign-in failed")
		await finish();return
	ui.session_owner=ui.account.player_id()
	ui.guest=false
	ui.screen="multiplayer"
	await ui.collection.load_inventory()
	ui.render()
	if role==0:
		await ui.online.create_room("papito")
		if ui.online.room.is_empty(): fail("Host create failed: "+ui.online.status);await finish();return
		save("room",{"code":ui.online.room.code,"id":ui.online.room.room_id})
	else:
		while read("room")==null and Time.get_ticks_msec()<deadline: await tick()
		if read("room")==null: fail("No host room code");await finish();return
		await ui.online.join_room(read("room").code,"papito")
	if not await until_ready(): fail("Match start timed out: "+ui.online.status);await finish();return
	got_setup=ui.game.phase=="setup" or ui.game.turn>0
	if ui.online.slot!=role or ui.game.manual_payment!=[true,true] or ui.active_deck_id!="online": fail("Role or engine integration failed")
	save("connected"+str(role),{"ok":failures.is_empty(),"revision":ui.online.revision})
	while Time.get_ticks_msec()<deadline and actions<40:
		await tick()
		if ui.online.busy or ui.online.waiting_action(): continue
		if role==1:
			var state=ui.online.room.get("state",{})
			if not state.get("queue",[]).is_empty() or not state.get("log_lines",[]).is_empty() or str(state.get("rng_state",""))!="0": snapshots_private=false
			for p in range(2):
				for uid in ui.game.players[p].deck:
					if uid>=0: snapshots_private=false
			for uid in ui.game.players[0].hand:
				if uid>=0: snapshots_private=false
			var payment=read("payment")
			if payment!=null and not guest_payment_checked and ui.online.revision>=int(payment.revision):
				guest_payment_checked=true
				var private_ok=not ui.game.instances.has(int(payment.uid)) and ui.game.payment_request.is_empty()
				if not private_ok: fail("Host pending payment leaked or could not synchronize")
				save("payment_private",{"ok":private_ok,"revision":ui.online.revision})
			if read("reconnect")!=null and not recovered:
				var saved_revision=ui.online.revision
				ui.online.clear()
				ui.reset_match()
				ui.screen="multiplayer"
				await ui.online.discover()
				recovered=ui.online.in_match() and ui.online.revision>=saved_revision and ui.started and ui.human==1
				if not recovered: fail("Guest could not recover after losing local room state")
				save("recovered",{"ok":recovered})
				continue
			if recovered:
				var id=ui.online.room.room_id
				if not await ui.online.leave(): fail("Guest leave failed")
				var result=await ui.online.request("aamix_mp_poll",{"p_room_id":id,"p_since_revision":-1})
				if not result.get("ok",false) or result.data.status!="finished" or int(result.data.winner)!=0: fail("Guest final outcome is wrong")
				var repeat=await ui.online.request("aamix_mp_leave",{"p_room_id":id})
				if not repeat.get("ok",false) or int(repeat.data.winner)!=0: fail("Leave retry changed result")
				await ui.collection.load_inventory()
				save("guest_finished",{"ok":failures.is_empty(),"room_id":id,"private_views":snapshots_private,"recovered":recovered})
				break
		else:
			if str(ui.online.room.get("status",""))=="finished":
				if ui.game.winner!=0 or ui.game.phase!="finished": fail("Host final result not reflected in engine/UI")
				break
			if ui.game.turn>=5 and payment_finished:
				save("reconnect",{"ok":true,"revision":ui.online.revision})
				continue
		if ui.game.actor!=role or ui.online.revision==last_revision: continue
		var g=ui.game
		if g.turn not in turns_seen: turns_seen.append(g.turn)
		if not g.pending.is_empty():
			if int(g.pending.player)==role:
				var count=int(g.pending.min)
				submit("choose",[g.pending.options.slice(0,count)])
			continue
		if not g.payment_request.is_empty():
			if role==0 and not payment_finished:
				if read("payment_private")==null: continue
				if not read("payment_private").ok: fail("Payment privacy assertion failed");break
				if not g.players[role].resources.is_empty(): submit("reserve_resource",[g.players[role].resources[0]])
			continue
		match g.phase:
			"setup": submit("keep_hand")
			"resource":
				var resource=-1
				for uid in g.players[role].hand:
					if g.definition(uid).clase=="Recurso": resource=uid;break
				if resource!=-1: submit("request_play",[resource,-1])
				else: submit("skip_resource")
			"main","after_combat":
				if role==0 and payment_uid!=-1: payment_finished=true
				if role==0 and payment_uid==-1:
					for uid in g.players[role].hand:
						var d=g.definition(uid)
						if d.clase=="Aliado" and int(d.coste)>0 and int(d.coste)<=g.players[role].resources.size() and g.can_play(uid):
							payment_uid=uid
							save("payment",{"uid":uid,"revision":ui.online.revision+1})
							# Exercise the same Callable bridge used by gameplay buttons.
							if ui.perform(g.request_play.bind(uid,-1)): actions+=1;last_revision=ui.online.revision
							break
					if payment_uid!=-1: continue
				ui.finish_turn()
				actions+=1
				last_revision=ui.online.revision
			"events": submit("pass_priority")
			"blocks": submit("finish_blocks")
	if Time.get_ticks_msec()>=deadline: fail("Bounded live flow timed out: "+ui.online.status+" / "+ui.online.last_error)
	if actions>=40: fail("Stopped at 40 commands per client")
	if role==0 and not payment_finished: fail("No natural host card payment completed")
	if role==1 and (not snapshots_private or not guest_payment_checked or not recovered): fail("Private view or reconnection case did not pass")
	await finish()
func finish():
	save("result"+str(role),{"role":role,"failures":failures,"actions":actions,"got_setup":got_setup,"turns_seen":turns_seen,"payment_finished":payment_finished,"private_views":snapshots_private,"recovered":recovered,"room_id":ui.online.room.get("room_id","") if ui!=null else ""})
	print(JSON.stringify({"native_online_role":role,"failures":failures,"actions":actions,"synthetic_users_only":true}))
	if ui!=null:
		ui.sound.shutdown()
		ui.queue_free()
		for _i in range(5): await process_frame
	quit(0 if failures.is_empty() else 1)
