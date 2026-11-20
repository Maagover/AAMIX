extends SceneTree
const Social = preload("res://social.gd")
const Collection = preload("res://collection.gd")
var fixture_path = ""
var checks = 0
var failures = []
var clients = []
var confirmations = {}
class LiveAccount extends Node:
	var service_url = ""; var publishable_key = ""; var access_token = ""; var expires_at = 0.0
	var busy = false; var fixture_user = ""
	func player_id(): return fixture_user
	func signed_in(): return not fixture_user.is_empty() and not access_token.is_empty()
	func refresh_session(): return false
class OnlineStub extends RefCounted:
	var session_user = ""; var room = {}
	func receive(value): room = value
class UIStub extends RefCounted:
	var section = ""
class Harness extends Node:
	var account; var collection; var social; var screen = "trades"
	var online = OnlineStub.new(); var online_ui = UIStub.new()
	func render(): pass
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--private-fixture="): fixture_path = arg.trim_prefix("--private-fixture=")
	run.call_deferred()
func check(value, caption):
	checks += 1
	if not value: failures.append(caption)
	return value
func done():
	for client in clients: client.queue_free()
	for _i in range(3): await process_frame
	print(JSON.stringify({"social_http_v150":{"checks":checks,"failures":failures,"synthetic_accounts":2,"real_emails_sent":0,"concurrent_confirmations":true,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)
func confirm_async(client, payload, key): confirmations[key] = await client.social.request("aamix_trade_action", payload)
func run():
	if fixture_path.is_empty(): check(false,"Explicit synthetic fixture required"); await done(); return
	var f = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not f is Dictionary or not f.get("synthetic_only", false) or f.users.size() != 2: check(false,"Synthetic guard"); await done(); return
	for u in f.users:
		var h = Harness.new(); root.add_child(h); clients.append(h)
		h.account = LiveAccount.new(); h.account.service_url = f.url; h.account.publishable_key = f.publishable_key
		h.account.access_token = u.access_token; h.account.expires_at = u.expires_at; h.account.fixture_user = u.id; h.add_child(h.account)
		h.collection = Collection.new(); h.collection.account = h.account; h.add_child(h.collection)
		h.social = Social.new().setup(h); h.add_child(h.social); h.social.set_process(false)
		if not check(await h.collection.load_inventory() and await h.social.sync(),"Native HTTPS inventory and social sync"): await done(); return
	var a = clients[0]; var b = clients[1]
	check(a.social.data.friend_code != b.social.data.friend_code and a.social.data.friends.is_empty(),"Distinct personal codes and empty isolated list")
	check(await a.social.mutate("aamix_friend_request",{"p_code":b.social.data.friend_code}),"Send friend request with native transport")
	await b.social.sync(); check(b.social.data.incoming.size() == 1,"Incoming request arrives on other session")
	check(await b.social.mutate("aamix_friend_respond",{"p_peer":a.account.player_id(),"p_accept":true}),"Accept friendship")
	await a.social.sync(); check(a.social.friends().size() == 1 and b.social.friends().size() == 1,"Both sessions recover friend after refresh")
	check(await a.social.mutate("aamix_trade_create",{"p_peer":b.account.player_id(),"p_code":"0101"}),"Offer last copy used in base deck")
	var t = str(a.social.last_reply.trade_id)
	await b.social.sync(); check(b.social.trade(t).peer_code == "0101","Other session sees offered face only")
	check(await b.social.mutate("aamix_trade_action",{"p_trade":t,"p_action":"offer","p_code":"0128","p_revision":1}),"Special answers Normal offer")
	await a.social.sync(); check(a.social.trade(t).revision == 2 and not a.social.trade(t).own_confirmed,"Final pair has shared offer revision")
	var payload_a = {"p_trade":t,"p_action":"confirm","p_code":"","p_revision":2,"p_request_id":a.collection.request_id()}
	var payload_b = payload_a.duplicate(); payload_b.p_request_id = b.collection.request_id()
	confirm_async(a,payload_a,"a"); confirm_async(b,payload_b,"b")
	var deadline = Time.get_ticks_msec()+25000
	while confirmations.size() < 2 and Time.get_ticks_msec() < deadline: await process_frame
	if not check(confirmations.get("a",false) and confirmations.get("b",false),"Concurrent final confirmations both succeed"): await done(); return
	await a.social.sync(); await b.social.sync()
	check(a.social.trade(t).status == "completed" and b.social.trade(t).status == "completed","Both sessions recover one completed transaction")
	check(int(a.collection.cards.get("0101",0)) == 0 and int(b.collection.cards.get("0128",0)) == 0,"Peer completion automatically refreshes both collections without manual reload")
	check(a.collection.decks[0].draft and a.collection.decks[0].editable,"Peer completion automatically reveals editable base draft")
	await a.collection.load_inventory(); await b.collection.load_inventory()
	check(int(a.collection.cards.get("0101",0)) == 0 and int(a.collection.cards.get("0128",0)) == 2 and int(b.collection.cards.get("0101",0)) == 2 and int(b.collection.cards.get("0128",0)) == 0,"HTTP transfer conserves both cards")
	var deck = a.collection.decks[0]
	check(deck.draft and deck.editable and deck.revision == 2 and a.collection.playable_decks().is_empty(),"Affected base returned as editable non-playable draft")
	check(await a.social.request("aamix_trade_action",payload_a),"Ambiguous-response retry reuses exact UUID")
	check(int(a.collection.cards.get("0128",0)) == 2,"Retry inventory has no extra incoming copy")
	deck.cartas = [{"codigo":"0100","cantidad":39},{"codigo":"0128","cantidad":1}]; deck.draft = false
	check(await a.collection.save_custom_deck(deck) and a.collection.playable_decks().size() == 1,"Native client repairs base deck to forty playable cards")
	check(await a.social.mutate("aamix_duel_create",{"p_peer":b.account.player_id(),"p_deck":"kajido"}),"Friend battle creates existing private lobby")
	await b.social.sync(); var duels = b.social.data.duels
	if check(duels.size() == 1 and duels[0].direction == "incoming","Friend receives battle invitation"):
		check(await b.social.mutate("aamix_duel_respond",{"p_invite":duels[0].id,"p_accept":true,"p_deck":"kajido"}) and b.online.room.status == "ready","Accept invitation enters ready lobby without auto-confirming battle")
	check(a.collection.missions.size() == 9,"Native client receives nine daily and historical missions")
	await done()
