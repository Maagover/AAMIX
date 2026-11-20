extends RefCounted
## Private host recovery snapshot and a separate, deliberately redacted guest view.
## RNG's 64-bit values travel as strings so JSON never rounds their bits.
const FIELDS = ["players","instances","domain_uid","active","actor","turn","phase","setup_player","keeps","changes","pending","queue","log_lines","error","winner","attacks","blocks","combat_roles","event_access","passes","next_uid","manual_payment","reserved","payment_request","announced_play","visual_events"]
const METHODS = ["mulligan","keep_hand","skip_resource","request_play","reserve_resource","refund_resource","cancel_payment","activate","choose","skip_choice","discard_by_drag","declare_attack","assign_block","finish_blocks","pass_priority","finish_turn"]

static func capture(game):
	var result = {"protocol":1,"ruleset_version":game.RULESET_VERSION,"rng_seed":str(game.rng.seed),"rng_state":str(game.rng.state)}
	for field in FIELDS:
		var value = game.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

static func restore(game, source):
	if not source is Dictionary or not source.get("players") is Array or source.players.size() != 2 or not source.get("instances") is Dictionary: return false
	if str(source.get("ruleset_version", "1.2")) != game.RULESET_VERSION: return false
	var data = integers(source)
	for field in FIELDS:
		if not data.has(field): return false
	for field in FIELDS:
		var value = data[field]
		if field in ["instances","blocks","combat_roles"]:
			var keyed = {}
			for key in value: keyed[int(key)] = value[key]
			value = keyed
		game.set(field,value)
	game.rng.seed = int(str(source.get("rng_seed","0")))
	game.rng.state = int(str(source.get("rng_state","0")))
	return true

static func integers(value):
	if value is float: return int(value) if value == floor(value) else value
	if value is Array:
		var result = []
		for item in value: result.append(integers(item))
		return result
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = integers(value[key])
		return result
	return value

static func guest_view(game):
	var result = capture(game)
	var visible = {}
	for p in range(2):
		for zone in game.ZONES:
			if zone == "deck" or (p == 0 and zone == "hand"): continue
			for uid in game.players[p][zone]: visible[uid] = true
	for uid in game.all_permanents(): visible[uid] = true
	if not game.payment_request.is_empty():
		if int(game.payment_request.player) == 1: visible[int(game.payment_request.uid)] = true
		else: result.payment_request = {}
	if not game.announced_play.is_empty() and game.announced_play.has("uid"): visible[int(game.announced_play.uid)] = true
	if not game.pending.is_empty():
		if int(game.pending.player) == 1:
			for uid in game.pending.get("options",[]): visible[int(uid)] = true
			if game.pending.has("source"): visible[int(game.pending.source)] = true
		else:
			result.pending = {"kind":"waiting","player":0,"options":[],"min":0,"max":0,"optional":false,"title":"El rival está eligiendo"}
	result.instances = {}
	for uid in visible:
		if game.instances.has(uid): result.instances[uid] = game.instances[uid].duplicate(true)
	for p in range(2):
		var deck = []
		for i in range(game.players[p].deck.size()):
			var hidden_uid = -1000 - p * 100 - i
			deck.append(hidden_uid)
			result.instances[hidden_uid] = placeholder(hidden_uid,p)
		result.players[p].deck = deck
	var hidden_hand = []
	for i in range(game.players[0].hand.size()):
		var uid = -3000 - i
		hidden_hand.append(uid)
		result.instances[uid] = placeholder(uid,0)
	result.players[0].hand = hidden_hand
	result.queue = []
	result.log_lines = []
	result.error = ""
	result.visual_events = []
	result.rng_seed = "0"
	result.rng_state = "0"
	result.next_uid = 1
	result.legal_activations = []
	if game.actor == 1:
		for uid in game.all_permanents():
			if game.can_activate(uid): result.legal_activations.append(uid)
	return result

static func placeholder(uid, owner):
	return {"uid":uid,"code":"0100","owner":owner,"entered":-1,"object":-1,"used":-1,"papito_empowered":false}

static func visible_uids(state,viewer):
	var visible={}
	for p in range(2):
		for zone in ["hand","defense","attack","graveyard","burned","resources","paid","stack"]:
			if zone=="hand" and p!=viewer: continue
			for uid in state.players[p][zone]:
				visible[int(uid)]=true
				var instance=state.instances.get(uid,state.instances.get(str(uid),{}))
				if int(instance.get("object",-1))!=-1: visible[int(instance.object)]=true
	if int(state.get("domain_uid",-1))!=-1: visible[int(state.domain_uid)]=true
	var pending=state.get("pending",{})
	if int(pending.get("player",-1))==viewer:
		for uid in pending.get("options",[]): visible[int(uid)]=true
	return visible

static func presentation(game,before,viewer):
	var after=capture(game)
	var public_before=visible_uids(before,viewer)
	var public_after=visible_uids(after,viewer)
	var result=[]
	var anonymous={}
	for source in game.visual_events:
		if source.get("kind","") not in ["move","shuffle","reorder","attack","block","damage"]: continue
		var event=source.duplicate(true)
		if viewer==1:
			for key in ["uid","carrier","attacker","source_uid"]:
				if not event.has(key) or int(event[key])<0: continue
				var uid=int(event[key])
				if key=="uid" and event.kind=="move" and (public_before.has(uid) or public_after.has(uid) or event.get("reveal",false)==true):
					event.face_code=game.printed_code(uid)
				if not public_after.has(uid):
					if not anonymous.has(uid): anonymous[uid]=-8000-anonymous.size()
					event[key]=anonymous[uid]
			if event.has("uids"):
				event.uids=event.uids.filter(func(uid): return public_after.has(int(uid)))
		result.append(event)
	return result

static func dispatch(game, slot, method, args):
	if game.winner != -1 or game.actor != slot or method not in METHODS or not args is Array: return false
	var lengths = {"mulligan":0,"keep_hand":0,"skip_resource":0,"request_play":2,"reserve_resource":1,"refund_resource":1,"cancel_payment":0,"activate":1,"choose":1,"skip_choice":0,"discard_by_drag":1,"declare_attack":1,"assign_block":2,"finish_blocks":0,"pass_priority":0,"finish_turn":0}
	if args.size() != lengths[method]: return false
	if method in ["choose","declare_attack"]:
		if not args[0] is Array or args[0].size() > 40: return false
		for uid in args[0]:
			if not uid is int or not game.instances.has(uid): return false
	else:
		for item in args:
			if not item is int: return false
	if method in ["request_play","reserve_resource","refund_resource","activate","discard_by_drag"]:
		if not game.instances.has(args[0]) or int(game.instances[args[0]].owner) != slot: return false
	if method == "assign_block":
		# Reassigning a defender is one atomic command, even if it had a different attacker.
		if game.phase != "blocks" or slot != 1 - game.active: return false
		if args[1] != -1:
			if not game.instances.has(args[1]) or int(game.instances[args[1]].owner) != slot: return false
			for attacker in game.blocks.keys():
				if game.blocks[attacker] == args[1] and attacker != args[0]: game.assign_block(attacker,-1)
	return game.callv(method,args) == true
