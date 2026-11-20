extends SceneTree
var clients = []
var checks = 0
var failures = []
var fixture_path = ""
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--private-fixture="): fixture_path = arg.trim_prefix("--private-fixture=")
	run.call_deferred()
func check(ok, text):
	checks += 1
	if not ok: failures.append(text); printerr("FAIL: ",text)
	return ok
func nodes(n):
	var all = [n]
	for c in n.get_children(): all.append_array(nodes(c))
	return all
func button(ui,text):
	for n in nodes(ui):
		if n is Button and n.text == text and not n.disabled: return n
	return null
func meta(ui,key,value):
	for n in nodes(ui):
		if n is Button and n.has_meta(key) and n.get_meta(key) == value and not n.disabled: return n
	return null
func settle():
	for _i in range(6): await process_frame
func idle(ui):
	var deadline = Time.get_ticks_msec()+30000
	while (ui.social_ui.sending or ui.social.busy or ui.social.refreshing_inventory or ui.collection.busy or ui.account.busy) and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	return check(not ui.social_ui.sending and not ui.social.busy and not ui.collection.busy,"UI operation becomes idle")
func press(ui,n,label):
	if not check(n != null,"Enabled button: "+label): return false
	n.pressed.emit(); await idle(ui)
	return check(ui.social.last_error.is_empty(),label+" completes without server error: "+ui.social.last_error)
func poll(ui):
	await ui.social.sync(true); ui.render(); await settle()
func done():
	for ui in clients: ui.sound.shutdown(); ui.get_parent().queue_free()
	await settle()
	print(JSON.stringify({"trade_rooms_http_v160":{"checks":checks,"failures":failures,"synthetic_accounts":2,"real_emails_sent":0,"actual_ui_buttons":true,"concurrent_confirmations":true,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)
func run():
	var f = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not check(f is Dictionary and f.get("synthetic_only",false) and f.users.size()==2,"Explicit synthetic fixture guard"): await done(); return
	for u in f.users:
		var viewport = SubViewport.new(); viewport.size = Vector2i(1600,1000); root.add_child(viewport)
		var ui = load("res://main.tscn").instantiate(); viewport.add_child(ui); clients.append(ui)
		ui.animations_enabled = false; ui.automation_pause = true; ui.account.set_process(false); ui.social.set_process(false)
		ui.online.set_process(false); ui.online.realtime.set_process(false); ui.rewards.set_process(false)
		ui.account.remember_me = false; ui.account.refresh_token = ""; ui.account.user = {"id":u.id}
		ui.account.service_url = f.url; ui.account.publishable_key = f.publishable_key; ui.account.access_token = u.access_token; ui.account.expires_at = u.expires_at
		ui.session_owner = u.id; ui.welcome_notified[u.id] = true; ui.guest = false
		if not check(await ui.collection.load_inventory() and await ui.social.sync(),"Native HTTPS loads own inventory and friends"): await done(); return
	var a = clients[0]; var b = clients[1]
	check(a.social.friends().size()==1 and b.social.friends().size()==1,"Accepted friendship recovered in both sessions")
	a.screen = "trades"; a.render(); await settle()
	# A real click during an in-flight quiet poll must be queued, not discarded.
	a.social.sync(true)
	if not await press(a,meta(a,"trade_invite_friend",b.account.player_id()),"Invite friend while background poll runs"): await done(); return
	check(a.social.room().status == "invited","Host sees single waiting room")
	b.screen = "friends"; await poll(b)
	if not await press(b,button(b,"Entrar a la sala"),"Guest accepts from Friends"): await done(); return
	check(b.screen == "trades" and b.social.room().status == "host_offer","Accept enters shared trade room")
	await poll(a)
	if not await press(a,meta(a,"trade_choose_card",true),"Host opens first picker"): await done(); return
	if not await press(a,meta(a,"trade_picker_card","0101"),"Host chooses owned Normal"): await done(); return
	check(a.social.room().status == "guest_offer","Host choice advances room once")
	await poll(b)
	if not await press(b,meta(b,"trade_choose_card",true),"Guest opens second picker"): await done(); return
	if not await press(b,meta(b,"trade_picker_card","0128"),"Guest chooses owned Special"): await done(); return
	await poll(a); await poll(b)
	check(a.social.room().own_code=="0101" and a.social.room().peer_code=="0128" and b.social.room().own_code=="0128","Both see identical final pair from own perspective")
	if not await press(a,meta(a,"trade_confirm",true),"Host opens confirmation"): await done(); return
	if not await press(b,meta(b,"trade_confirm",true),"Guest opens confirmation"): await done(); return
	var ac = button(a,"Confirmar intercambio"); var bc = button(b,"Confirmar intercambio")
	if not check(ac != null and bc != null,"Both final confirmation buttons enabled"): await done(); return
	ac.pressed.emit(); bc.pressed.emit(); await idle(a); await idle(b)
	check(a.social.last_error.is_empty() and b.social.last_error.is_empty(),"Concurrent UI confirmations accepted")
	await poll(a); await poll(b)
	check(a.social.room().status=="completed" and b.social.room().status=="completed","Both sessions reach completed receipt")
	check(int(a.collection.cards.get("0101",0))==0 and int(a.collection.cards.get("0128",0))==2 and int(b.collection.cards.get("0101",0))==2 and int(b.collection.cards.get("0128",0))==0,"Both collections refresh exact conserved copies without manual reload")
	check(a.collection.decks[0].draft and a.collection.decks[0].editable and a.collection.playable_decks().is_empty(),"Last copy removed from base deck and draft becomes editable")
	if not await press(a,meta(a,"trade_invite_friend",b.account.player_id()),"Open one new room after completion"): await done(); return
	await poll(b)
	if not await press(b,button(b,"Cancelar intercambio"),"Guest reviews cancellation"): await done(); return
	if not await press(b,button(b,"Cancelar la sala"),"Guest cancels room"): await done(); return
	await poll(a)
	check(a.social.room().status=="cancelled" and not a.social.room().active,"Cancelled room releases both players")
	check(int(a.collection.cards.get("0128",0))==2 and int(b.collection.cards.get("0101",0))==2,"Cancellation preserves ownership")
	await done()
