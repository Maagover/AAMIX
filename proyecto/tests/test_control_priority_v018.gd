extends SceneTree
const Fixture=preload("res://tests/online_fixture_v018.gd")
func _initialize(): run.call_deferred()
func run():
	var ui=load("res://main.tscn").instantiate();root.add_child(ui);ui.animations_enabled=false
	for _i in range(8): await process_frame
	ui.account.user={"id":"00000000-0000-4000-8000-000000000018"};ui.account.access_token="fixture";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.account.set_process(false);ui.online.set_process(false);ui.rewards.set_process(false)
	var fake=Fixture.new().setup(ui);ui.add_child(fake);fake.set_process(false)
	fake.room={"room_id":"priority","status":"waiting","slot":0,"revision":0,"state":{}}
	fake.busy=true
	fake.replies=[{"ok":true,"data":{"room_id":"priority","status":"waiting","slot":0,"revision":0,"confirmed":[true,false]}}]
	(func():fake.busy=false).call_deferred()
	var result=await fake.confirm()
	var valid=result and fake.priority_waiters==0 and fake.calls.size()==1 and fake.calls[0].endpoint=="aamix_mp_confirm" and fake.room.confirmed==[true,false]
	print(JSON.stringify({"control_priority_v018_checks":1,"failures":[] if valid else ["Background poll swallowed confirmation"]}))
	ui.sound.shutdown();ui.queue_free()
	for _i in range(8): await process_frame
	quit(0 if valid else 1)
