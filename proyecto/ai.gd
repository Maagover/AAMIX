extends RefCounted
## Decide con su mano, su mazo y la información pública de la mesa.
## Nunca consulta las cartas de la mano ni el orden del mazo del rival.

const NEW_PLANS=["dominios","miku","tsuki_akira","imbloqueable","chanchuus","transmision"]

func strategy(g,p):return str(g.players[p].get("deck_id",""))
func count_zone(g,p,z,code):return g.players[p][z].filter(func(u):return g.code(u)==code).size()
func owns_combo_card(g,p,code):
	for z in ["hand","deck","graveyard","defense","attack"]:
		if count_zone(g,p,z,code)>0:return true
	return false
func known_count(g,p,code,selected=[]):
	return g.field(p).filter(func(u):return g.code(u)==code).size()+count_zone(g,p,"hand",code)+selected.filter(func(u):return g.code(u)==code).size()
func spent_support(g,uid,p):
	return strategy(g,p) in NEW_PLANS and uid in g.field(p) and g.instances[uid].object==-1 and g.code(uid) in ["0101","0104","0114","0110","0108"]
func strategic_value(g,uid,p):
	var c=g.code(uid);var plan=strategy(g,p)
	if plan=="papito":
		if c=="0106" and g.count_code(p,"0115")==0 and owns_combo_card(g,p,"0115"):return 18.0 if g.count_code(p,"0106")+count_zone(g,p,"hand","0106")<3 else 12.0
		if c=="0115":return 24.0
	if plan in ["flaan","halloween"]:
		if c in ["0112","0113"]:return 20.0 if g.count_code(p,c)==0 else 12.0
		if c=="0103":return 24.0
	if plan=="kajido":
		if c=="0105":return 30.0
		if g.definition(uid).get("tipo_aliado","") in ["Lucha","Fundamental"]:return 7.0
	if plan=="maago":
		if c in ["0107","0108","0124"]:return 14.0
		if c=="0109" and g.domain_uid!=-1:return 15.0
	if plan=="girabl" and c in ["0127","01a"]:return 24.0
	if spent_support(g,uid,p):return 0.0
	var priorities={
		"dominios":{"0109":22.0,"0114":12.0,"0101":8.0,"0111":7.0,"0132":12.0},
		"miku":{"0107":24.0,"0108":16.0,"0124":20.0,"01b":12.0,"0114":8.0},
		"tsuki_akira":{"01c":30.0,"0127":22.0,"01a":22.0,"0103":25.0,"0112":17.0,"0113":17.0},
		"imbloqueable":{"0107":24.0,"0128":24.0,"0129":18.0,"0124":18.0,"0108":15.0,"0102":16.0},
		"chanchuus":{"0125":25.0,"01d":20.0,"0118":12.0,"0128":12.0,"0119":18.0,"0116":14.0},
		"transmision":{"01c":30.0,"0107":22.0,"0129":15.0,"0126":16.0,"0105":28.0,"0108":20.0,"0111":10.0}}
	return float(priorities.get(plan,{}).get(c,0.0))

func search_value(g,uid,p,selected=[],context=""):
	var c=g.code(uid);var rank=value(g,uid,p)
	if strategy(g,p)=="papito" and c=="0106" and g.count_code(p,"0106")+count_zone(g,p,"hand","0106")<3:rank+=45.0
	if strategy(g,p) in ["flaan","halloween"] and c in ["0112","0113"] and g.count_code(p,c)+count_zone(g,p,"hand",c)==0:rank+=35.0
	if strategy(g,p)=="girabl" and c in ["0127","01a"] and g.count_code(p,c)==0:rank+=40.0
	var plan=strategy(g,p);var known=known_count(g,p,c,selected)
	if plan=="dominios":
		if c=="0109":rank+=maxf(0,80-known*25)
		if c=="0114":rank+=70 if known==0 else 5
		if c=="0132" and g.domain_uid==-1 and not g.players[p].hand.any(func(u):return g.definition(u).clase=="Dominio"):rank+=90
		if c=="0116":rank+=60 if g.field(1-p).any(func(u):return int(g.definition(u).coste)<=2) else 8
		if g.definition(uid).clase=="Dominio":
			rank+=35 if g.domain_uid==-1 else 0
			if c=="0131" and g.field(p).size()>4:rank-=80
			if c=="0122" and g.field(1-p).any(func(u):return g.unblockable(u)):rank+=55
	if plan=="miku":
		if c=="0107":rank+=maxf(0,85-known*25)
		if c=="0108" and known==0:rank+=55
		if c=="0124":rank+=80
		if c=="01b" and known==0:rank+=55
		if c=="0116":rank+=50
	if plan=="tsuki_akira":
		if c in ["0112","0113"]:rank+=95 if known==0 else 5
		if c=="01a":rank+=75 if known==0 else 15
		if c=="0127":rank+=60 if known_count(g,p,"01a",selected)>0 else 20
		if c=="0103" and "Desaparición" in context:rank+=120
	if plan=="imbloqueable":
		if c=="0107":rank+=maxf(0,85-known*20)
		if c=="0129" and known==0:rank+=65
		if c=="0108" and known==0:rank+=55
		if c=="0124":rank+=80
	if plan=="chanchuus":
		if c=="01d" and g.domain_uid==-1:rank+=90
		if c=="0118":rank+=75 if g.players[1-p].graveyard.any(func(u):return g.definition(u).clase=="Aliado") else 0
		if c in ["0111","0108"]:rank+=maxf(0,50-known*15)
	if plan=="transmision":
		if c in ["01c","0107"]:rank+=maxf(0,85-known*20)
		if c=="0129" and known==0:rank+=65
		if c=="0108" and known==0:rank+=55
		if c=="0124":rank+=80
	return rank

func oscars_possible(g,p):
	var available = 0
	for z in ["hand","deck","defense","attack"]:available += count_zone(g,p,z,"0106")
	return available >= 3

func hold_oscars(g,uid,p):
	if strategy(g,p)!="papito" or g.code(uid)!="0106" or not owns_combo_card(g,p,"0115") or not oscars_possible(g,p):return false
	var missing=maxi(0,3-g.count_code(p,"0106"))
	return count_zone(g,p,"hand","0106")<missing or g.players[p].resources.size()<missing

func value(g, uid, p):
	var d = g.definition(uid)
	var n = 0.0
	if d.clase == "Aliado":
		# Las elecciones de conservar/descartar respetan los bonos públicos y
		# los Objetos equipados, no sólo la Fuerza impresa de la carta.
		var strength = g.force(uid) if uid in g.field(p) else int(d.fuerza)
		n = float(strength) * 2.0 + 3.0 - float(d.coste) * 0.25
		if uid in g.field(p) and g.instances[uid].object != -1: n += 3.0
		if g.agile(uid): n += 2.0
		if g.unblockable(uid): n += 2.0
		if g.code(uid) in ["0104", "0107", "01b"]: n += 3.0
		if g.code(uid) == "0108": n += 1.0
		if g.code(uid) == "0112": n += 2.0 * g.count_code(p, "0113")
		if g.code(uid) == "0113": n += 2.0 * g.count_code(p, "0112")
		if g.code(uid) == "0127" and g.count_code(p, "01a") > 0: n += 4.0
		if g.code(uid) == "01a" and g.count_code(p, "0127") > 0: n += 4.0
	elif d.clase == "Recurso":
		n = 9.0 if g.players[p].resources.size() + g.players[p].paid.size() < 5 else 0.5
	elif d.clase == "Objeto":
		n = 5.0 if not g.field(p).is_empty() else 1.0
	elif d.clase == "Evento":
		n = {"0116": 5.0, "0120": 6.0, "0132": 2.0, "0133": 7.0}.get(g.code(uid), 1.0)
	elif d.clase == "Dominio":
		n = 3.0
	return n+strategic_value(g,uid,p)

func target_value(g,uid,p):
	var result=public_threat(g,uid)
	if g.code(uid)=="0122" and strategy(g,p) in ["miku","imbloqueable","tsuki_akira","transmision"]:result+=80
	return result

func public_threat(g, uid):
	var d = g.definition(uid)
	if d.clase == "Aliado":
		return float(g.force(uid)) * 3.0 + float(d.coste) + (3.0 if g.unblockable(uid) else 0.0)
	if d.clase == "Objeto": return 6.0
	return 4.0

func ordered(g, cards, p):
	var result = cards.duplicate()
	result.sort_custom(func(a, b):
		var av = value(g, a, p)
		var bv = value(g, b, p)
		return av > bv if not is_equal_approx(av, bv) else a < b)
	return result

func has_in_deck(g, p, card_class):
	for uid in g.players[p].deck:
		if g.definition(uid).clase == card_class: return true
	return false

func safe_search(g, p, filter):
	var effect = filter.duplicate(true)
	effect.player = p
	# Buscar no debe agotar el propio Mazo. El Cementerio no tiene ese riesgo.
	for uid in g.search_options(effect):
		if uid not in g.players[p].deck or g.players[p].deck.size() >= 15: return true
	return false

func useful_activation(g, uid, p):
	match g.code(uid):
		"01b": return safe_search(g, p, {"class":"Objeto"})
		"0106": return safe_search(g, p, {"code":"0115", "zones":["deck", "graveyard"]})
		"0123": return safe_search(g, p, {"class":"Aliado", "max_cost":2})
		"0126": return g.phase == "main" and g.can_attack(uid) and not sacrifice_candidates(g, uid, p).is_empty()
		"0129": return not unblockable_candidates(g, p).is_empty()
	return true

func sacrifice_candidates(g, source, p, available = []):
	var options = g.field(p) if available.is_empty() else available
	var result = options.filter(func(uid): return uid != source and uid in g.field(p) and (value(g, uid, p) <= 6.0 or spent_support(g,uid,p)))
	if strategy(g,p)=="transmision":result=result.filter(func(uid):return g.code(uid) not in ["0107","0108","01c"])
	result.sort_custom(func(a, b):
		var av = value(g, a, p)
		var bv = value(g, b, p)
		return av < bv if not is_equal_approx(av, bv) else a < b)
	return result

func unblockable_candidates(g, p, available = []):
	# Sólo merece pagar antes de declarar ataque y cuando el rival sí podría
	# bloquear. No supone que Imbloqueable deshaga bloqueos ya asignados.
	if g.phase != "main" or g.players[1-p].defense.is_empty(): return []
	if g.domain_uid != -1 and g.code(g.domain_uid) == "0122": return []
	var options = g.field(p) if available.is_empty() else available
	var result = options.filter(func(uid): return uid in g.field(p) and g.can_attack(uid) and not g.unblockable(uid))
	result.sort_custom(func(a, b):
		var av = float(g.force(a)) * 3.0 + value(g, a, p) * 0.25
		var bv = float(g.force(b)) * 3.0 + value(g, b, p) * 0.25
		return av > bv if not is_equal_approx(av, bv) else a < b)
	return result

func choose_pending(g, p):
	var c = g.pending
	var options = c.options.duplicate()
	if c.kind == "sacrifice_ally":
		var useful = sacrifice_candidates(g, int(c.get("source", -1)), p, options)
		return g.choose([useful[0]]) if not useful.is_empty() else g.skip_choice()
	if c.kind == "grant_unblockable":
		var useful = unblockable_candidates(g, p, options)
		return g.choose([useful[0]]) if not useful.is_empty() else g.skip_choice()
	if c.kind == "counter":
		var source = c.source
		var threat = public_threat(g, source)
		var targeted = g.announced_play.get("target", -1)
		if targeted != -1 and g.instances[targeted].owner == p: threat += 8.0
		if g.code(source) == "0119" and g.field(p).size() > g.field(1 - p).size(): threat += 12.0
		return g.choose([options[0]]) if threat >= 8.0 else g.skip_choice()
	if c.kind == "remove_permanent":
		options = options.filter(func(u): return g.instances[u].owner != p)
		options.sort_custom(func(a, b): return target_value(g, a,p) > target_value(g, b,p))
		return g.choose([options[0]]) if not options.is_empty() else g.skip_choice()
	if c.kind == "play_target":
		var source = g.definition(c.source)
		if source.clase == "Objeto":
			options = options.filter(func(u): return object_score(g, u, c.source) > 0.0)
			options.sort_custom(func(a, b): return object_score(g, a, c.source) > object_score(g, b, c.source))
		else:
			options = options.filter(func(u): return g.instances[u].owner != p)
			options.sort_custom(func(a, b): return removal_value(g, a,p) > removal_value(g, b,p))
		if options.is_empty(): return g.skip_choice()
		return g.choose([options[0]])
	options = ordered(g, options, p)
	if c.kind == "end_discard":
		options.reverse()
		return g.choose(options.slice(0, int(c.max)))
	if c.kind == "search_hand":
		if "Javieriv" in str(c.get("title","")):options=options.filter(func(u):return g.code(u)!="0104")
		var selected=[]
		var deck_remaining=g.players[p].deck.size()
		while not options.is_empty() and selected.size()<int(c.max):
			options.sort_custom(func(a,b):return search_value(g,a,p,selected,str(c.get("title","")))>search_value(g,b,p,selected,str(c.get("title",""))) if not is_equal_approx(search_value(g,a,p,selected,str(c.get("title",""))),search_value(g,b,p,selected,str(c.get("title","")))) else a<b)
			var uid=options.pop_front()
			if uid in g.players[p].deck:
				if deck_remaining<15 and c.get("optional",true):continue
				if deck_remaining<=1:continue
				deck_remaining-=1
			selected.append(uid)
		return g.choose(selected)
	return g.choose(options.slice(0, int(c.max)))

func object_score(g, uid, object_uid = -1):
	# Chanchuus no recibe Fuerza de otras cartas. Un Objeto sí activa el
	# bono propio de Dragón, además del efecto que tenga ese Objeto.
	if object_uid != -1 and g.code(object_uid) == "0124" and g.code(uid) == "0125": return -100.0
	return (20.0 if strategy(g,g.instances[uid].owner) in ["miku","imbloqueable","transmision"] and g.code(uid)=="0107" else 0.0) + (12.0 if g.code(uid) in ["0107", "0108"] else 3.0) + float(g.force(uid)) + (4.0 if g.code(uid) == "01e" else 0.0)

func combat_pair(g, uid):
	# Sólo información pública y bloqueos aún válidos. Una respuesta posterior
	# puede cambiar la Fuerza o quitar el bloqueador: se recalcula en cada decisión.
	if g.phase != "events": return []
	for attacker in g.attacks:
		var blocker = int(g.blocks.get(attacker, -1))
		if attacker not in g.players[g.active].attack or blocker not in g.players[1-g.active].defense: continue
		if uid == attacker or uid == blocker: return [attacker, blocker]
	return []

func removal_value(g, uid, p):
	var score = target_value(g, uid, p)
	var pair = combat_pair(g, uid)
	if pair.is_empty():
		if g.phase == "events" and uid in g.players[1-p].attack:
			# Quitar un atacante libre evita daño, y todavía más si sería letal.
			score += float(g.force(uid)) * 2.0
			if g.force(uid) >= g.players[p].deck.size(): score += 200.0
		return score
	var attacker = pair[0]; var blocker = pair[1]
	var attack_force = g.force(attacker); var block_force = g.force(blocker)
	if uid == attacker:
		if block_force >= attack_force:
			# Ya moriría al combatir. Sólo tiene valor gastar eliminación aquí
			# si evita también la pérdida de nuestro bloqueador en un empate.
			score = value(g, blocker, p) * .65 if block_force == attack_force else -100.0
		else:
			score += value(g, blocker, p) * .65 + float(attack_force-block_force) * 2.0
			if attack_force-block_force >= g.players[p].deck.size(): score += 200.0
	else:
		# Retirar un bloqueador deja pasar toda la Fuerza del ataque y puede
		# salvar a nuestro atacante; no se confunde con retirar un atacante.
		if attack_force >= block_force: score *= .15
		else: score += value(g, attacker, p) * .65
		score += float(mini(attack_force, block_force)) * 2.0
		if attack_force >= g.players[1-p].deck.size(): score += 200.0
	return score

func best_target(g, source, p):
	var eligible = []
	if g.definition(source).clase == "Objeto":
		for uid in g.field(p):
			if g.instances[uid].object == -1 and object_score(g, uid, source) > 0.0: eligible.append(uid)
		eligible.sort_custom(func(a, b): return object_score(g, a, source) > object_score(g, b, source))
	elif g.code(source) == "0116":
		for uid in g.field(1 - p):
			if int(g.definition(uid).coste) <= 2: eligible.append(uid)
	else:
		eligible = g.all_permanents().filter(func(u): return g.instances[u].owner != p)
	if g.definition(source).clase != "Objeto":
		eligible.sort_custom(func(a, b):
			var av = removal_value(g, a, p)
			var bv = removal_value(g, b, p)
			return av > bv if not is_equal_approx(av, bv) else a < b)
	return eligible[0] if not eligible.is_empty() else -1

func play_score(g, uid, p):
	var d = g.definition(uid)
	var plan=strategy(g,p)
	if hold_oscars(g,uid,p):return -100.0
	if plan in ["miku","transmision"] and g.code(uid)=="0110" and not g.all_permanents().any(func(u):return g.instances[u].owner!=p and g.definition(u).clase in ["Dominio","Objeto"]):return -100.0
	if plan=="transmision" and g.code(uid)=="0105" and g.field(p).size()<3 and g.players[p].deck.size()>=15:return -100.0
	if plan=="dominios" and d.clase=="Dominio":
		if g.domain_uid!=-1:return -100.0
		if g.code(uid)=="0131" and g.field(p).size()>4:return -100.0
		return 30.0

	if plan=="papito" and g.code(uid)=="0115":
		if g.count_code(p,"0106")<3 and oscars_possible(g,p):return -100.0
		if g.field(p).any(func(u):return g.code(u)=="0106" and g.instances[u].entered==g.turn):return -100.0
	if plan in ["flaan","tsuki_akira"] and g.code(uid)=="0103" and (g.count_code(p,"0112")==0 or g.count_code(p,"0113")==0) and g.players[p].deck.size()>=15:return -100.0
	if g.code(uid)=="0108":
		for other in g.instances:
			var instance = g.instances[other]
			if instance.owner==p and instance.code=="0108" and int(instance.entered)==g.turn: return -100.0
	if d.clase == "Objeto" or g.code(uid) in ["0116", "0133"]:
		var target = best_target(g, uid, p)
		if target == -1: return -100.0
		if d.clase == "Objeto": return object_score(g, target, uid) + 2.0
		return removal_value(g, target, p) - float(d.coste)
	if g.code(uid) == "0118":
		return 3.0 if g.players[1-p].graveyard.any(func(card): return g.definition(card).clase == "Aliado") else -100.0
	if g.code(uid) == "0120":
		return 8.0 if g.players[p].hand.size() <= 6 and safe_search(g, p, {"class":"Aliado", "max_cost":2}) else -100.0
	if g.code(uid) == "0117":
		return 7.0 if safe_search(g, p, {"class":"Aliado", "singular":true}) else -100.0
	if g.code(uid) == "0119":
		var our_value = 0.0
		var their_value = 0.0
		for ally in g.field(p): our_value += public_threat(g, ally)
		for ally in g.field(1 - p): their_value += public_threat(g, ally)
		return their_value - our_value - 2.0
	if g.code(uid) == "0132":
		return 3.0 if safe_search(g, p, {"class":"Dominio"}) else -100.0
	if d.clase == "Dominio":
		if g.domain_uid != -1 and g.code(g.domain_uid) == g.code(uid): return -100.0
		if g.code(uid) == "0131":
			if g.field(p).size() > 4: return -100.0
			return 10.0 if g.field(1 - p).size() > 4 else (4.0 if g.count_code(p, "0109") > 0 else -1.0)
		if g.code(uid) == "0122":
			var theirs = g.field(1 - p).filter(func(a): return g.unblockable(a)).size()
			var ours = g.field(p).filter(func(a): return g.unblockable(a)).size()
			return 7.0 if theirs > ours else -1.0
	if d.clase == "Aliado" and g.code(uid) != "0134" and g.domain_uid != -1 and g.code(g.domain_uid) == "0131" and g.field(p).size() >= 4:
		# No pagar por un quinto Aliado para luego descartarlo o deshacer
		# nuestra propia mesa. Se conserva la Mano y el pago para otra jugada.
		# Guitarramala retira el Dominio antes de comprobar el límite.
		return -100.0
	return value(g, uid, p)

func try_play(g, p):
	var best = -1
	var score = 0.0
	var candidates = g.players[p].hand + g.players[p].graveyard.filter(func(u): return g.code(u) == "0134")
	for uid in candidates:
		if not g.can_play(uid): continue
		var current = play_score(g, uid, p)
		if current > score:
			score = current
			best = uid
	if best == -1: return false
	var target = -1
	if g.definition(best).clase == "Objeto" or g.code(best) in ["0116", "0133"]:
		target = best_target(g, best, p)
	return g.request_play(best, target)

func block(g, p):
	var attackers = g.attacks.duplicate()
	attackers.sort_custom(func(a, b): return g.force(a) > g.force(b))
	var incoming = 0
	for a in attackers: incoming += g.force(a)
	# Resolve profitable exchanges before assigning a disposable defender to a
	# stronger attacker. Azul's blocking bonus is public and included here.
	var available=g.players[p].defense.duplicate()
	var pairs=[]
	for a in attackers:
		if g.unblockable(a) and not (g.domain_uid!=-1 and g.code(g.domain_uid)=="0122"):continue
		for b in available:
			var f=g.force(b)+(2 if g.code(b)=="0111" else 0)
			if f<g.force(a):continue
			var protected_card=strategy(g,p) in ["flaan","halloween","tsuki_akira"] and g.code(b) in ["0112","0113"]
			if strategy(g,p)=="papito" and g.code(b)=="0106" and g.count_code(p,"0115")==0 and oscars_possible(g,p):protected_card=true
			var rank=public_threat(g,a)*2.0+mini(f,g.force(a))*2.0-value(g,b,p)*(0.25 if f>g.force(a) else 0.8)
			if f==g.force(a) and protected_card:rank-=70
			if incoming>=g.players[p].deck.size():rank+=100+mini(f,g.force(a))*10
			pairs.append({"a":a,"b":b,"score":rank})
	pairs.sort_custom(func(x,y):return x.score>y.score)
	for pair in pairs:
		if pair.score<=0 or pair.a in g.blocks or pair.b in g.blocks.values():continue
		if g.assign_block(pair.a,pair.b):incoming-=mini(g.force(pair.b),g.force(pair.a))
	for a in attackers:
		if a in g.blocks:continue
		if g.unblockable(a) and not (g.domain_uid != -1 and g.code(g.domain_uid) == "0122"): continue
		var best = -1
		var best_score = -999.0
		for b in g.players[p].defense:
			if b in g.blocks.values(): continue
			var f = g.force(b) + (2 if g.code(b) == "0111" else 0)
			var score = float(mini(f, g.force(a))) * 2.0
			# Entre bloqueos que ganan, conservar el Aliado más valioso para
			# otra amenaza en vez de gastar siempre el mayor sobre el menor.
			if f > g.force(a): score += 15.0 - value(g, b, p) * 0.35
			elif f == g.force(a): score += 7.0 - value(g, b, p) * 0.25
			else: score -= value(g, b, p) + 4.0
			if g.code(b) in ["0110","0104","0108","0111"] or spent_support(g,b,p):score+=14.0
			if strategy(g,p) in ["chanchuus","imbloqueable"] and g.code(b)=="0128" and f<=g.force(a):score+=15.0
			if f<=g.force(a) and strategy(g,p) in ["flaan","halloween","tsuki_akira"] and g.code(b) in ["0112","0113"]:score-=22.0
			if strategy(g,p)=="papito" and g.code(b)=="0106" and owns_combo_card(g,p,"0115") and oscars_possible(g,p) and g.count_code(p,"0115")==0:score-=60.0
			if incoming >= g.players[p].deck.size(): score += 15.0
			if incoming >= g.players[p].deck.size():score+=100.0
			if score > best_score:
				best_score = score
				best = b
		if best != -1 and best_score > 0.0:
			if g.assign_block(a, best):
				# La Fuerza de Azul ya incluye su bono una vez asignado.
				incoming -= mini(g.force(best), g.force(a))
	return g.finish_blocks()

func step(g, p):
	if g.winner != -1 or g.actor != p: return false
	if not g.pending.is_empty(): return choose_pending(g, p)
	if not g.payment_request.is_empty(): return false
	match g.phase:
		"setup":
			var resources = 0
			for uid in g.players[p].hand:
				if g.definition(uid).clase == "Recurso": resources += 1
			if (resources == 0 or resources >= 5) and g.changes[p] < 2: return g.mulligan()
			return g.keep_hand()
		"resource":
			for uid in g.players[p].hand:
				if g.definition(uid).clase == "Recurso": return g.request_play(uid)
			return g.skip_resource()
		"main":
			for uid in g.all_permanents():
				if not g.can_activate(uid): continue
				if not useful_activation(g, uid, p): continue
				return g.activate(uid)
			if try_play(g, p): return true
			var ready = g.players[p].defense.filter(func(u): return g.can_attack(u))
			if strategy(g,p)=="papito" and g.count_code(p,"0115")==0 and owns_combo_card(g,p,"0115") and oscars_possible(g,p):ready=ready.filter(func(u):return g.code(u)!="0106")
			var defenders = g.players[1 - p].defense
			var max_force = 0
			for b in defenders: max_force = maxi(max_force, g.force(b) + (2 if g.code(b) == "0111" else 0))
			var attacks = ready.filter(func(u):
				return (g.unblockable(u) and not (g.domain_uid != -1 and g.code(g.domain_uid) == "0122")) or g.force(u) + (1 if g.code(u) == "0111" else 0) >= max_force or ready.size() > defenders.size())
			if strategy(g,p) in ["flaan","halloween","tsuki_akira"]:
				attacks=attacks.filter(func(u):return g.code(u) not in ["0112","0113"] or g.force(u)>max_force or (g.unblockable(u) and not (g.domain_uid!=-1 and g.code(g.domain_uid)=="0122")))
			if strategy(g,p)=="girabl":attacks=ready
			return g.declare_attack(attacks) if not attacks.is_empty() else g.finish_turn()
		"blocks": return block(g, p)
		"events":
			if try_play(g, p): return true
			return g.pass_priority()
		"after_combat": return g.finish_turn()
	return false
