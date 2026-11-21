extends SceneTree
var auth
var checks=0
var failures=[]
func _initialize():run.call_deferred()
func check(value,message):
	checks+=1
	if not value:failures.append(message);push_error(message)
func run():
	auth=preload("res://account.gd").new();root.add_child(auth)
	auth.set_process(false);auth.clear_session()
	check(auth.configure(OS.get_environment("AAMIX_TEST_AUTH_URL"),"sb_publishable_local_fixture",true),"Local HTTP fixture configured")
	check(auth.validate_credentials("bad","long-enough")!="","Reject malformed email")
	check(auth.validate_credentials("qa@example.invalid","short")!="","Reject short password")
	check(auth.validate_credentials("qa@example.invalid","x".repeat(129))!="","Reject oversized password")
	check(not await auth.sign_in_password("qa@example.invalid","short"),"Invalid password never reaches HTTP")
	check(await auth.sign_in_password("qa@example.invalid","FixturePass_9"),"Email/password login succeeds through HTTP")
	check(auth.signed_in(),"Login accepts verified session")
	check(auth.player_id()=="00000000-0000-4000-8000-000000000001","Auth server determines identity")
	check(not await auth.sign_in_password("qa@example.invalid","WrongPass_9"),"Wrong password rejected")
	check(auth.status.contains("contraseña incorrectos"),"Wrong password has readable error")
	auth.clear_session()
	check(not await auth.register_password("qa@example.invalid","FixturePass_9","X"),"Reject invalid nickname")
	check(await auth.register_password("qa@example.invalid","FixturePass_9","Prueba"),"Password signup uses HTTP")
	check(not auth.signed_in(),"Unconfirmed signup does not invent a session")
	check(auth.status.contains("enlace"),"Signup explains email confirmation link")
	check(await auth.request_password_reset("qa@example.invalid"),"Recovery email endpoint works")
	check(not await auth.save_recovery_password("FixturePass_9"),"Recovery cannot change password without verified session")
	await auth.sign_in_password("qa@example.invalid","FixturePass_9");auth.password_recovery=true
	check(await auth.save_recovery_password("NewFixturePass_9"),"Authenticated recovery uses PUT user")
	check(not auth.password_recovery,"Recovery state closes after success")
	check(await auth.refresh_session(),"Password login supports refresh")
	check(await auth.sign_out(),"Password session logout succeeds")
	check(not auth.signed_in() and auth.refresh_token.is_empty(),"Logout clears all local credentials")
	auth.queue_free()
	print(JSON.stringify({"password_auth":{"checks":checks,"failures":failures,"remote_writes":0}}));quit(0 if failures.is_empty() else 1)
