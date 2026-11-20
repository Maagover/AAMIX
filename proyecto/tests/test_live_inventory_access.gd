extends SceneTree
func _initialize(): run.call_deferred()

func run():
	var account = load("res://account.gd").new()
	get_root().add_child(account)
	await process_frame
	var http = HTTPRequest.new()
	http.timeout = 20
	http.max_redirects = 0
	get_root().add_child(http)
	var statuses = []
	var ok = true
	for endpoint in ["aamix_inventory", "aamix_claim_starter"]:
		var body = {"p_deck_id":"kajido"} if endpoint.ends_with("starter") else {}
		var err = http.request(account.service_url + "/rest/v1/rpc/" + endpoint, PackedStringArray(["apikey: " + account.publishable_key,"Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))
		if err != OK:
			ok = false
			break
		var result = await http.request_completed
		statuses.append(result[1])
		ok = ok and result[0] == HTTPRequest.RESULT_SUCCESS and int(result[1]) in [401,403]
	print(JSON.stringify({"live_anonymous_rpc_denied":ok,"http_statuses":statuses,"emails_sent":0,"gifts_claimed":0}))
	account.queue_free()
	http.queue_free()
	await process_frame
	quit(0 if ok else 1)
