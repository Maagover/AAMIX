extends SceneTree
var checks=0
var failures=[]
var ui
class EventCollection extends "res://collection.gd":
	var calls=[]
	var confirmed={}
	func request(endpoint,body):
		calls.append({"endpoint":endpoint,"body":body.duplicate(true)})
		last_reply={"match_id":"fixture-event-receipt","match_deck":confirmed.duplicate(true),"event_opponent":JSON.parse_string(FileAccess.get_file_as_string("res://data/mazo_halloween.json"))}
		return true
func _initialize():run.call_deferred()
func check(ok,message):
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func run():
	ui=load("res://main.tscn").instantiate();root.add_child(ui)
	ui.automation_pause=true;ui.animations_enabled=false
	for n in [ui.account,ui.online,ui.online.realtime,ui.rewards,ui.social]:n.set_process(false)
	ui.account.configured=false;ui.account.user={"id":"00000000-0000-4000-8000-000000000191"};ui.account.access_token="local-fixture-not-a-credential";ui.account.expires_at=Time.get_unix_time_from_system()+3600
	ui.session_owner=ui.account.player_id();ui.guest=false
	var old=ui.collection;old.changed.disconnect(ui.collection_changed)
	var c=EventCollection.new();ui.collection=c;c.account=ui.account;ui.add_child(c);c.changed.connect(ui.collection_changed);old.queue_free()
	c.owner_id=ui.account.player_id();c.loaded=true;c.gift={"deck_id":"papito"};c.restos_welcome_claimed=true;c.welcome_pack={"claimed":true}
	c.decks=ui.game.decklists.duplicate(true)
	for code in ui.game.catalog:c.cards[code]=80 if code=="0100" else 3
	for e in JSON.parse_string(FileAccess.get_file_as_string("res://data/eventos.json")).events:
		if e.id=="halloween_2026":c.events=[e.duplicate(true)]
	c.events_deadline_tick=Time.get_ticks_msec()+3600000
	c.confirmed=c.decks[0].duplicate(true)
	ui.open_event_battle();check(ui.screen=="decks" and ui.selected_event_battle,"Event route opens owned deck choice")
	ui.start_match(0);check(ui.screen=="versus" and ui.pending_match.event_battle,"Versus remembers event mode")
	await ui.begin_prepared_match()
	check(c.calls.size()==1 and c.calls[0].endpoint=="aamix_begin_event_match","Event uses its own server receipt endpoint")
	check(ui.started and ui.screen=="table" and ui.active_event_battle,"Confirmed event starts actual board")
	check(ui.game.players[ui.computer].deck_id=="halloween","Server-frozen Halloween opponent used")
	check(ui.rewards.active_receipt.get("event_battle",false) and ui.rewards.active_receipt.get("match_id")=="fixture-event-receipt","Prepared event receipt consumed by existing result queue")
	check(ui.game.invariant_errors().is_empty(),"Event has forty physical cards per player")
	ui.open_random();check(not ui.selected_event_battle,"Random route clears event selection")
	ui.sound.shutdown();ui.queue_free()
	for i in range(6):await process_frame
	print(JSON.stringify({"event_battle_receipt_hw01":{"checks":checks,"failures":failures,"network_requests":0}}))
	quit(0 if failures.is_empty() else 1)
