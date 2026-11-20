extends SceneTree
const Collection = preload("res://collection.gd")
const Rewards = preload("res://rewards_ui.gd")

func _initialize():
	var collection = Collection.new()
	var rewards = Rewards.new()
	var reply = {"reward_packs":1,"reward_restos":50,"reward_normal_packs":1,"reward_cards":[],"reward_deck_id":null}
	var message = collection.redemption_message(reply)
	var items = rewards.code_reward_items(reply)
	var ok = message.contains("1 sobre TC") and message.contains("50 Restos") and message.contains("1 carta aleatoria")
	ok = ok and items.size() == 3 and items.map(func(item): return item.kind) == ["tc_pack","restos","normal_pack"]
	ok = ok and items.map(func(item): return item.amount) == [1,50,1]
	ok = ok and items.all(func(item): return item.texture != null)
	reply.already_redeemed = true
	ok = ok and collection.redemption_message(reply).contains("Ya canjeaste")
	collection.free()
	rewards.free()
	if not ok:
		push_error("WALLET_GIFTS017_FAILED")
		quit(1)
		return
	print("WALLET_GIFTS017_OK checks=1")
	quit(0)
