extends SceneTree

const Account = preload("res://account.gd")
const PATH = "res://tests/fixtures/remember_v1.tmp.bin"
var checks = 0
var failures = []

class StubAccount extends "res://account.gd":
	var next_reply = {}
	func send(_path, _body, _bearer = ""):
		return next_reply

func _init():
	run.call_deferred()

func check(condition, title):
	checks += 1
	if not condition: failures.append(title)
	print(("PASS " if condition else "FAIL ") + title)

func session(token = "refresh-synthetic-v1"):
	return {"user":{"id":"b82ec4be-b9f5-41b9-877c-55b715c23805","email":"synthetic@example.invalid","user_metadata":{"display_name":"Prueba"}},"access_token":"access-synthetic-v1","refresh_token":token,"expires_in":3600}

func client():
	var value = StubAccount.new()
	value.remembered_session_path = PATH
	value.configure("http://127.0.0.1:8173", "sb_publishable_synthetic", true)
	return value

func run():
	var first = client()
	first.forget_remembered()
	check(first.remember_available(), "Windows DPAPI helper available")
	check(first.set_remember_me(true, "synthetic@example.invalid", "Prueba"), "opt-in encrypts autofill")
	check(first.accept_session(session()), "verified session accepted")
	var ciphertext = FileAccess.get_file_as_bytes(PATH)
	check(not "synthetic" in ciphertext.get_string_from_ascii(), "disk bytes contain no plaintext email or tokens")
	var second = client()
	check(second._load_remembered() and second.remember_me and second.remembered_email == "synthetic@example.invalid", "new client reloads opt-in autofill")
	check(not second.signed_in() and second.user.is_empty() and second.access_token.is_empty(), "saved refresh token never establishes identity without server")
	second.next_reply = {"ok":true,"data":session("refresh-rotated-v1")}
	check(await second._restore_remembered(), "saved token refresh restores verified session")
	var third = client()
	check(third._load_remembered() and third._saved_refresh_token == "refresh-rotated-v1", "rotated refresh token replaces encrypted previous token")
	second.next_reply = {"ok":false,"retryable":true,"message":"offline"}
	check(not await second.refresh_session() and not second.refresh_token.is_empty() and second.refresh_retry_at > Time.get_unix_time_from_system(), "transient failure preserves token with retry delay")
	second.next_reply = {"ok":false,"retryable":false,"message":"expired"}
	check(not await second.refresh_session() and not second.signed_in() and second.refresh_token.is_empty() and second._saved_refresh_token.is_empty(), "revoked session clears credentials")
	check(second.set_remember_me(false) and not FileAccess.file_exists(PATH), "opt-out removes stored session")
	second.set_remember_me(true, "synthetic@example.invalid", "Prueba")
	second.accept_session(session())
	second.next_reply = {"ok":true,"data":{}}
	check(await second.sign_out() and not second.remember_me and not FileAccess.file_exists(PATH), "sign-out revokes and forgets local session")
	first.set_remember_me(true, "synthetic@example.invalid", "Prueba")
	var other = client()
	other.service_url = "http://127.0.0.1:8174"
	check(not other._load_remembered() and not other.remember_me, "stored credentials are bound to configured service")
	first.set_remember_me(true, "synthetic@example.invalid", "Prueba")
	var damaged = FileAccess.get_file_as_bytes(PATH)
	damaged[damaged.size() - 1] = damaged[damaged.size() - 1] ^ 255
	var damaged_file = FileAccess.open(PATH, FileAccess.WRITE)
	damaged_file.store_buffer(damaged)
	damaged_file.close()
	check(not third._load_remembered() and not FileAccess.file_exists(PATH), "tampered ciphertext is rejected and forgotten")
	var invalid_session = session()
	invalid_session.expires_in = 0
	check(not third.accept_session(invalid_session) and not third.signed_in(), "invalid server session lifetime is still rejected")
	for value in [first,second,third,other]: value.free()
	print("REMEMBER_V1_RESULTS " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
