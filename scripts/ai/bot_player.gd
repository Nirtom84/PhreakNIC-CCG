class_name BotPlayer
extends RefCounted
const MAX_ACTIONS = 200
var engine
var action_delay: float = 0.0
func _init(game): engine = game
func take_turn(p):
	var actions = 0
	var declined: Dictionary = {}
	while engine.is_turn(p) and actions < MAX_ACTIONS:
		if action_delay > 0.0:
			await engine.get_tree().create_timer(action_delay).timeout
			if not engine.is_turn(p): break
		actions += 1
		var candidates = p.hand.filter(func(c): return engine.can_play(p, c))
		var ai = engine.dec(p)
		# Deck thinning activations happen before playing away the weakest cards.
		var activated = false
		var all = engine.permanents()
		for c in all:
			for ability in engine.activatable_abilities(p, c):
				var key = "%d:%d" % [c.uid, ability.index]
				if not ability.enabled or declined.has(key): continue
				if p.difficulty == 0 and ability.cost > 0: continue
				if ability.cost > 0 and not candidates.is_empty(): continue
				if ability.cost > 0 and want_buy(p) and not (p.difficulty == 2 and ability_wins(p, c)): continue
				if c.effect_id() == "Shell Speech" and ability.index == 1 and p.difficulty > 0:
					if not engine.opponents(p).all(func(q): return q.life <= 2): continue
				if c.effect_id() == "Tennessee Department of Health" and p.difficulty > 0:
					if not engine.permanents().any(func(x): return x.controller != p.seat and x.counters > 0 and engine.db().has_subtype(x.effect_id(), "Location")): continue
				if c.effect_id() == "Candy Factory" and p.difficulty > 0: continue
				if c.effect_id() == "AI Bens AI Camry" and engine.opponents(p).all(func(q): return q.hand.is_empty()): continue
				var before = fingerprint(p)
				await engine.activate(p, c, ability.index)
				if fingerprint(p) == before: declined[key] = true
				activated = true
				break
			if activated: break
		if activated: continue
		if not candidates.is_empty():
			if p.difficulty > 0:
				candidates.sort_custom(func(a, b): return play_priority(p, a) > play_priority(p, b))
			await engine.play_card(p, candidates[0])
			continue
		var buys = (engine.state.center_row + p.reserve).filter(func(c): return c != null and engine.can_buy(p, c))
		if not buys.is_empty():
			if p.difficulty == 0:
				engine.state.shuffle(buys)
				buys.sort_custom(func(a, b): return engine.effective_cost(p, a) > engine.effective_cost(p, b))
			else: buys.sort_custom(func(a, b): return ai.value(a, p) > ai.value(b, p))
			if p.difficulty == 0 or ai.value(buys[0], p) >= (1.8 if p.difficulty == 2 else 0.5):
				await engine.buy_card(p, buys[0])
				continue
		if p.difficulty == 2:
			var reserve = engine.state.center_row.filter(func(c): return c != null and engine.can_reserve(p, c) and ai.value(c, p) >= 4.0 and engine.effective_cost(p, c) <= estimate_hacking(p) + 2)
			if not reserve.is_empty():
				reserve.sort_custom(func(a, b): return reserve_priority(a, p) > reserve_priority(b, p))
				engine.reserve_card(p, reserve[0])
		break
	if p == engine.active() and not engine.state.finished: await engine.end_turn(p)
func fingerprint(p) -> String:
	return str([p.hacking, p.life, p.hand.size(), engine.state.removed.size(), engine.permanents().map(func(c): return [c.uid, c.counters, c.flags.get("used", false)]), engine.state.players.map(func(q): return [q.life, q.hand.size()])])
func want_buy(p) -> bool:
	for c in engine.state.center_row + p.reserve:
		if c != null and engine.can_buy(p, c) and engine.dec(p).value(c, p) >= 3.0: return true
	return false
func estimate_hacking(p) -> int:
	var total = 0.0
	var cards = p.deck + p.discard + p.hand
	for c in cards: total += engine.db().get_card(c.id).hack
	return int(total * 5.0 / maxf(1, cards.size()))
func play_priority(p, c) -> float:
	var data = engine.db().get_card(c.id)
	var score = engine.dec(p).value(c, p)
	if "draw" in str(data.text).to_lower(): score += 100 if p.difficulty == 1 else 30
	if c.id in ["Super r0nk", "DeMartian", "m8trix310"]: score += 40
	if data.kind == "Permanent": score += 45
	if "remove a card" in str(data.text).to_lower() or c.id == "O.P.R.A.H.": score += 50
	if c.id == "Nirtom Unleashed": score -= 90
	if p.difficulty == 2:
		if lethal_reachable(p): score += float(data.damage) * 100
	return score

func lethal_reachable(p) -> bool:
	var reachable = 0
	for x in p.hand:
		reachable += int(engine.db().get_card(x.id).damage)
		if engine.db().named(x.id, "Hacker"): reachable += engine.controlled(p, "Dick Van Dyke Stamp").size()
		if x.id == "Ben The Meek": reachable += 3
		if x.id == "heartsh8ped": reachable += 1
	for q in engine.opponents(p):
		if q.turn_flags.get("prevent_all", false) or not engine.controlled(q, "Military-Grade Card Encapsulation").is_empty() or not engine.controlled(q, "Phreaknic Network").is_empty(): return false
		var effective_life = q.life
		for x in q.play_area:
			if engine.db().has_subtype(x.effect_id(), "Location"): effective_life += x.counters
		if reachable < effective_life: return false
	return reachable > 0

func reserve_priority(card, p) -> float:
	var score = engine.dec(p).value(card, p)
	# Denial considers only public information about opponents' combinations.
	for q in engine.opponents(p):
		if engine.db().named(card.id, "Botnet"): score += engine.controlled(q, "Botnet").size() * 2.0
		if engine.db().has_subtype(card.id, "FOTTR Hero") and not engine.controlled(q, "The Fellowship of the Token Ring").is_empty(): score += 3.0
		if card.id in ["Never Gonna Give You Up", "Never Gonna Let You Down"] and (q.discard + q.play_area).any(func(x): return x.id in ["Never Gonna Give You Up", "Never Gonna Let You Down"] and x.id != card.id): score += 2.0
	return score

func ability_wins(p, card) -> bool:
	if card.effect_id() == "Lowes Shopping Cart": return p.hacking >= 25 - card.counters
	if card.effect_id() != "Bribery": return false
	var damage = floori(float(p.hacking) / 2.0) * (1 + engine.controlled(p, "CTF Bangers").size())
	for q in engine.opponents(p):
		if q.turn_flags.get("prevent_all", false) or not engine.controlled(q, "Military-Grade Card Encapsulation").is_empty() or not engine.controlled(q, "Phreaknic Network").is_empty(): return false
		var effective_life = q.life
		for c in q.play_area:
			if engine.db().has_subtype(c.effect_id(), "Location"): effective_life += c.counters
		if effective_life > damage: return false
	return damage > 0
