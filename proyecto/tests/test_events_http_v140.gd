extends SceneTree
## One short-lived synthetic HTTPS session. No passwords, DPAPI or real users.
const Collection = preload("res://collection.gd")
var fixture_path = ""
var collection
var account
var checks = 0
var failures = []
class LiveAccount extends Node:
	var service_url = ""
	var publishable_key = ""
	var access_token = ""
	var expires_at = 0.0
	var busy = false
	var fixture_user = ""
	func player_id(): return fixture_user
	func signed_in(): return not fixture_user.is_empty() and not access_token.is_empty()
	func refresh_session(): return false
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--private-fixture="): fixture_path = arg.trim_prefix("--private-fixture=")
	run.call_deferred()
func check(ok, caption):
	checks += 1
	if not ok: failures.append(caption)
	return ok
func done():
	if is_instance_valid(collection): collection.queue_free()
	if is_instance_valid(account): account.queue_free()
	for _i in range(3): await process_frame
	print(JSON.stringify({"events_http_v140":{"checks":checks,"failures":failures,"synthetic_accounts":1,"real_emails_sent":0,"realtime_tested":false,"remote_pcs_tested":false}}))
	quit(0 if failures.is_empty() else 1)
func run():
	if fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		check(false,"Explicit synthetic fixture required"); await done(); return
	var f = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	if not f is Dictionary or f.get("synthetic_only",false) != true:
		check(false,"Synthetic guard"); await done(); return
	account = LiveAccount.new(); account.service_url = f.url; account.publishable_key = f.publishable_key
	account.access_token = f.access_token; account.expires_at = f.expires_at; account.fixture_user = f.id; root.add_child(account)
	collection = Collection.new(); collection.account = account; root.add_child(collection)
	if not check(await collection.load_inventory() and collection.active_events().size() == 1 and collection.active_events()[0].id == "bienvenida_2026", "Native HTTPS loads current server event and verifies login"):
		await done(); return
	check(collection.active_events()[0].missions[0].progress == 1 and collection.restos == 100 and collection.packs == 0, "Daily login eligibility preserves preexisting starter-gift state")
	check(await collection.claim_event_mission("bienvenida_2026","login") and collection.restos == 125, "Event login grants 25 Restos")
	check(await collection.claim_event_mission("bienvenida_2026","login") and collection.restos == 125 and collection.last_reply.get("already_claimed",false), "HTTP retry cannot double login prize")
	check(await collection.redeem_code("BIENVENIDAA") and collection.restos == 225 and collection.packs == 1 and collection.normal_packs == 1, "Active event code exact bundle")
	check(await collection.redeem_code("BIENVENIDAA") and collection.restos == 225 and collection.last_reply.get("already_redeemed",false), "Code retry idempotent")
	check(not await collection.redeem_code("GATONEGRO") and collection.last_error_code == "AAMIX_CODE_INACTIVE", "Future event code denied by server")
	check(not await collection.claim_event_mission("halloween_2026","play_one") and collection.last_error_code == "AAMIX_EVENT_INACTIVE", "Future event mission denied")
	check(not await collection.claim_event_mission("bienvenida_2026","play_one") and collection.last_error_code == "AAMIX_MISSION_NOT_READY", "No completion fabricated by client")
	var request = collection.request_id()
	check(await collection.begin_match(request,"papito"), "Begin real receipt with immutable base list")
	var receipt = str(collection.last_reply.get("match_id", ""))
	check(not receipt.is_empty() and await collection.finish_match(receipt,false) and collection.active_events()[0].missions[1].progress == 1, "Completed receipt advances event play mission")
	check(await collection.finish_match(receipt,false) and collection.active_events()[0].missions[3].progress == 1, "Finish retry does not count match twice")
	check(await collection.claim_event_mission("bienvenida_2026","play_one") and collection.restos == 250, "Event completion grants 25 separately")
	check(await collection.claim_mission("play_one") and collection.restos == 275, "Original daily reward coexists without reset or collision")
	var body = {"p_request_id":collection.request_id(),"p_deck_id":"","p_nombre":"Sin recurso","p_portada":"custom_restos","p_cartas":[],"p_draft":true,"p_expected_revision":0}
	check(not await collection.request("aamix_save_custom_deck",body) and collection.last_error_code == "AAMIX_DECK_INITIAL_RESOURCE", "HTTP server rejects draft without Resource")
	check(await collection.load_inventory() and collection.restos == 275 and collection.active_events()[0].missions[0].claimed, "Reconnect preserves event and daily claim receipts")
	await done()
