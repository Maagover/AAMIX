extends SceneTree
## Exactly two sequential native processes, one temporary synthetic QA account.
## No main UI, real-account vault, email delivery or game-data writes.
const Account = preload("res://account.gd")
var phase = -1
var fixture_path = ""
var vault_path = ""
var result_path = ""
var checks = 0
var failures = []
var account

func _init():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = int(arg.trim_prefix("--phase="))
		if arg.begins_with("--fixture="): fixture_path = arg.trim_prefix("--fixture=")
		if arg.begins_with("--vault="): vault_path = arg.trim_prefix("--vault=")
		if arg.begins_with("--result="): result_path = arg.trim_prefix("--result=")
	run.call_deferred()

func check(condition, title):
	checks += 1
	if not condition: failures.append(title)
	print(("PASS " if condition else "FAIL ") + title)

func run():
	if phase not in [0,1] or fixture_path.is_empty() or vault_path.is_empty() or result_path.is_empty():
		quit(2)
		return
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var credentials = fixtures.users[0]
	if not str(credentials.email).contains("qa-mp-v100-") or not str(credentials.email).ends_with(".invalid"):
		# Reject any accidental real account fixture before authentication.
		printerr("Invalid synthetic account fixture")
		quit(2)
		return
	account = Account.new()
	account.remembered_session_path = vault_path # Must precede _ready.
	root.add_child(account)
	if phase == 0:
		var reply = await account.send("/token?grant_type=password", {"email":credentials.email,"password":credentials.password})
		var accepted = reply.get("ok", false) and account.accept_session(reply.get("data", {}))
		var stored = accepted and account.set_remember_me(true)
		check(stored and account.player_id() == credentials.user_id and FileAccess.file_exists(vault_path), "synthetic remote sign-in persists protected session")
		if stored:
			var bytes = FileAccess.get_file_as_bytes(vault_path)
			var visible = bytes.get_string_from_ascii()
			check(not str(credentials.email) in visible and not account.refresh_token in visible and not account.access_token in visible, "private vault contains no plaintext credentials")
		else:
			check(false, "private vault contains no plaintext credentials")
	else:
		check(account.remember_me and account.remembered_email == credentials.email and not account.signed_in() and account.user.is_empty(), "fresh process loads autofill without trusting saved identity")
		var previous_refresh = account._saved_refresh_token
		var deadline = Time.get_ticks_msec() + 25000
		while not account.signed_in() and Time.get_ticks_msec() < deadline:
			await process_frame
		check(account.signed_in() and account.player_id() == credentials.user_id and account.user.get("email") == credentials.email and account.refresh_token != previous_refresh, "fresh process restores same account through remote refresh rotation")
		var revoked = await account.sign_out()
		check(revoked and not account.signed_in() and not account.remember_me and not FileAccess.file_exists(vault_path), "remote sign-out revokes session and removes private test vault")
	var result = {"phase":phase,"checks":checks,"failures":failures,"actual_supabase_https":true,"emails_sent":0}
	var file = FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result))
		file.close()
	print("REMEMBER_REMOTE_V1 " + JSON.stringify(result))
	account.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
