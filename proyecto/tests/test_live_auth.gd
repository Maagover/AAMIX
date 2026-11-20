extends SceneTree

func _initialize(): run.call_deferred()

func run():
	var account = load("res://account.gd").new()
	get_root().add_child(account)
	await process_frame
	assert(account.configured)
	# Read-only check: no account, OTP, or email is created by this smoke test.
	var http = HTTPRequest.new()
	http.timeout = 15
	http.max_redirects = 0
	get_root().add_child(http)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-proxy="):
			var parts = arg.trim_prefix("--test-proxy=").split(":")
			http.set_https_proxy(parts[0],int(parts[1]))
	var err = http.request(account.service_url + "/auth/v1/settings", PackedStringArray(["apikey: " + account.publishable_key]))
	if err != OK:
		print(JSON.stringify({"godot_https_auth_settings":false,"request_error":err,"emails_sent":0}))
		quit(1)
		return
	var result = await http.request_completed
	var parser = JSON.new()
	parser.parse(result[3].get_string_from_utf8())
	var data = parser.data
	var passed = result[0] == HTTPRequest.RESULT_SUCCESS and result[1] == 200 and data is Dictionary and data.get("external",{}).get("email",false) and not data.get("disable_signup",true) and not data.get("mailer_autoconfirm",true)
	print(JSON.stringify({"godot_https_auth_settings":passed,"status":result[1],"transport_result":result[0],"email_verification_required":true,"emails_sent":0}))
	account.queue_free()
	http.queue_free()
	await process_frame
	quit(0 if passed else 1)
