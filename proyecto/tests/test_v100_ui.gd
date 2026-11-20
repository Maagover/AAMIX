extends SceneTree
var ui
var checks=0
var failures=[]
func check(ok,message):
	checks+=1
	if not ok: failures.append(message)
func nodes(n):
	var result=[n]
	for c in n.get_children(): result.append_array(nodes(c))
	return result
func _initialize(): run.call_deferred()
func run():
	ui=load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.automation_pause=true
	ui.online.set_process(false)
	ui.online.realtime.set_process(false)
	for _i in range(3): await process_frame
	ui.screen="account"
	ui.render()
	var remember=[]
	for n in nodes(ui):
		if n.get_meta("remember_me",false): remember.append(n)
	check(remember.size()==1 and remember[0].text=="Recuérdame","Remember checkbox integrated")
	var Snapshot=load("res://multiplayer_snapshot.gd")
	var full=Snapshot.capture(ui.game)
	var uid="00000000-0000-4000-8000-000000000101"
	ui.account.user={"id":uid}
	ui.account.access_token="local-fixture-not-a-credential"
	ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.online.session_user=uid
	var data={"room_id":"local-fixture","room_version":8,"code":"AABBCCDD","protocol":3,"status":"playing","revision":1,"slot":0,"actor_slot":0,"winner":-1,"confirmed":[true,true],"commands":[],"players":[{"name":"A","avatar_code":"0108"},{"name":"B","avatar_code":"0109"}],"state":full}
	ui.online.receive(data)
	check(ui.fx.speed==1.0,"Normal online animation duration")
	var has_home=false
	for n in nodes(ui):
		if n is Button and n.text=="Inicio": has_home=true
	check(not has_home,"No redundant Inicio on table")
	ui.screen="multiplayer"
	ui.render()
	var portraits=0
	has_home=false
	for n in nodes(ui):
		if n.get_script()!=null and "avatar_code" in n and str(n.avatar_code) in ["0108","0109"]: portraits+=1
		if n is Button and n.text=="Inicio": has_home=true
	check(portraits==2,"Both room portraits rendered")
	check(not has_home,"No redundant Inicio in room")
	var stale=data.duplicate(true)
	stale.room_version=7
	stale.status="ready"
	stale.confirmed=[false,false]
	ui.online.receive(stale)
	check(ui.online.room.status=="playing" and ui.online.room.confirmed==[true,true],"Older same-revision metadata ignored")
	ui.fx.busy=true
	var next=data.duplicate(true)
	next.revision=2
	next.room_version=9
	ui.online.receive_push(next)
	check(ui.online.presentations.size()==1 and ui.online.revision==2,"Push accepted while animation running")
	ui.fx.busy=false
	ui.online.busy=true
	ui.online.next_poll=Time.get_ticks_msec()/1000.0+9999
	ui.online._process(0)
	check(ui.online.visible_revision==2 and ui.online.presentations.is_empty(),"Presentation flush independent of pending HTTP")
	ui.online.busy=false
	ui.fx.busy=true
	var earlier=next.duplicate(true)
	earlier.revision=3
	earlier.room_version=10
	ui.online.receive_push(earlier)
	var final=earlier.duplicate(true)
	final.revision=4
	final.room_version=11
	final.status="finished"
	final.winner=0
	ui.online.receive_push(final)
	ui.fx.busy=false
	ui.online.flush_presentation()
	check(ui.online.visible_revision==3 and ui.game.winner==-1,"Queued older move does not display future final result")
	ui.online.presentations.clear()
	ui.online.staged_commit={"p_request_id":"already-initializing"}
	var ready=data.duplicate(true)
	ready.room_id="local-ready"
	ready.room_version=10
	ready.revision=0
	ready.status="ready"
	ready.state={}
	ui.online.receive(ready)
	check(ui.online.staged_commit.get("p_request_id","")=="already-initializing","Duplicate ready cannot restart initial engine")
	print(JSON.stringify({"v100_ui_checks":checks,"failures":failures}))
	ui.account.user={}
	ui.account.access_token=""
	ui.online.clear()
	ui.sound.shutdown()
	ui.queue_free()
	for _i in range(3): await process_frame
	quit(0 if failures.is_empty() else 1)
