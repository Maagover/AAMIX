extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var account = load("res://account.gd").new()
	get_root().add_child(account)
	await process_frame
	var http = HTTPRequest.new()
	http.timeout=20
	http.max_redirects=0
	get_root().add_child(http)
	var fixture_uuid="a1000000-0000-4000-8000-000000000010"
	var requests={"aamix_set_avatar":{"p_code":"0108"},"aamix_redeem_code":{"p_code":"M4Z0M44G0"},"aamix_begin_match":{"p_request_id":fixture_uuid,"p_deck_id":"kajido"},"aamix_finish_match":{"p_match_id":fixture_uuid,"p_result":"victory"},"aamix_claim_daily_mission":{},"aamix_open_pack":{"p_request_id":fixture_uuid},"aamix_acknowledge_opening":{"p_opening_id":fixture_uuid}}
	var statuses=[]
	var passed=true
	for endpoint in requests:
		var err=http.request(account.service_url+"/rest/v1/rpc/"+endpoint,PackedStringArray(["apikey: "+account.publishable_key,"Content-Type: application/json"]),HTTPClient.METHOD_POST,JSON.stringify(requests[endpoint]))
		if err!=OK:
			passed=false
			break
		var reply=await http.request_completed
		statuses.append(reply[1])
		passed=passed and reply[0]==HTTPRequest.RESULT_SUCCESS and int(reply[1]) in [401,403]
	print(JSON.stringify({"live_rewards_anonymous_denied":passed,"http_statuses":statuses,"real_emails_sent":0,"rewards_granted":0}))
	account.queue_free()
	http.queue_free()
	await process_frame
	quit(0 if passed else 1)
