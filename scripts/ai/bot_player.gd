class_name BotPlayer
extends RefCounted
const MAX_ACTIONS = 200
var engine
var continue_turn: Callable
var action_completed: Callable
var action_delay: float = 0.0
var pace_provider: Callable
var yield_frame: bool = false
var purchase_policy: Callable # Offline randomized purchase experiments only.
var search_budget_ms = 0 # 0 uses DefconSearch.DECISION_MS; server overrides it.
func _init(game): engine = game
func take_turn(p):
	var turn_search = null
	if p.difficulty == 3:
		turn_search = DefconSearch.new(engine)
		if search_budget_ms > 0: turn_search.budget_ms = search_budget_ms
	var actions = 0
	var started_us = Time.get_ticks_usec()
	var pacing_us = 0
	var declined: Dictionary = {}
	var random_reserve_checked = false
	while is_instance_valid(engine) and engine.is_turn(p) and actions < MAX_ACTIONS and (not continue_turn.is_valid() or continue_turn.call()):
		if p.difficulty == 3 and Time.get_ticks_usec() - started_us - pacing_us >= mini(DefconSearch.LIVE_TURN_MS, turn_search.budget_ms) * 1000: break
		var pacing_started = Time.get_ticks_usec()
		if pace_provider.is_valid():
			action_delay = float(pace_provider.call())
		if action_delay > 0.0:
			await engine.get_tree().create_timer(action_delay).timeout
		elif yield_frame:
			await engine.get_tree().process_frame
		pacing_us += Time.get_ticks_usec() - pacing_started
		if not is_instance_valid(engine) or not engine.is_turn(p) or (continue_turn.is_valid() and not continue_turn.call()): break
		actions += 1
		var candidates = p.hand.filter(func(c): return engine.can_play(p, c))
		if p.difficulty > 0:
			candidates = candidates.filter(func(c): return not (c.id == "TOCTOU" and p.life <= 6))
		if p.difficulty == 3:
			# Draw-only self-recycling can otherwise consume all 200 actions while
			# useful buys wait forever. Count identity, never inspect deck order.
			candidates = candidates.filter(func(c): return p.played.count(c) < 3 or int(engine.db().get_card(c.id).damage) > 0 or c.effect_id() in ["Ben The Meek", "heartsh8ped", "Jenny", "Non-Infringing Game Show", "LAN Party"])
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
				if ability.cost > 0 and want_buy(p) and not (p.difficulty >= 2 and ability_wins(p, c)): continue
				if c.effect_id() == "Nashville 2600":
					if p.difficulty == 0 or not p.hand.any(func(x): return engine.db().get_card(x.id).kind == "Permanent"): continue
					if (engine.state.center_row + p.reserve).any(func(x): return x != null and engine.can_buy(p, x) and purchase_value(ai, x, p) >= purchase_threshold(p)): continue
				if c.effect_id() == "Shell Speech" and ability.index == 1 and p.difficulty > 0:
					if not engine.opponents(p).all(func(q): return q.life <= 2): continue
				if c.effect_id() == "Tennessee Department of Health" and p.difficulty > 0:
					if not engine.permanents().any(func(x): return x.controller != p.seat and x.counters > 0 and engine.db().has_subtype(x.effect_id(), "Location")): continue
				if c.effect_id() == "Candy Factory" and p.difficulty > 0: continue
				if c.effect_id() == "AI Bens AI Camry" and engine.opponents(p).all(func(q): return q.hand.is_empty()): continue
				var before = fingerprint(p)
				await engine.activate(p, c, ability.index)
				completed()
				if fingerprint(p) == before: declined[key] = true
				activated = true
				break
			if activated: break
		if activated: continue
		if not candidates.is_empty():
			if p.difficulty > 0:
				candidates.sort_custom(func(a, b): return play_priority(p, a) > play_priority(p, b))
			var chosen = await turn_search.choose_play(p, candidates) if turn_search != null else candidates[0]
			if not is_instance_valid(engine) or not engine.is_turn(p): break
			await engine.play_card(p, chosen)
			completed()
			continue
		var buys = (engine.state.center_row + p.reserve).filter(func(c): return c != null and engine.can_buy(p, c))
		if not buys.is_empty():
			if p.difficulty == 0:
				engine.shuffle(buys)
				buys.sort_custom(func(a, b): return engine.effective_cost(p, a) > engine.effective_cost(p, b))
			else: buys.sort_custom(func(a, b): return buy_priority(a, p) > buy_priority(b, p))
		var target = null
		if p.difficulty == 0:
			if not random_reserve_checked and p.turn_flags.get("acquired", 0) == 0:
				random_reserve_checked = true
				var row = engine.state.center_row.filter(func(c): return c != null and engine.can_reserve(p, c))
				if not row.is_empty() and engine.rand_range(0, 99) < 10: target = row[engine.rand_range(0, row.size() - 1)]
		else: target = reserve_target(p, buys)
		if turn_search != null or purchase_policy.is_valid():
			var fallback = {"kind": "stop", "uid": -1}
			if target != null: fallback = {"kind": "reserve", "uid": target.uid}
			elif not buys.is_empty() and purchase_value(ai, buys[0], p) >= purchase_threshold(p): fallback = {"kind": "buy", "uid": buys[0].uid}
			var choice = purchase_policy.call(p, buys, fallback) if purchase_policy.is_valid() else await turn_search.choose_purchase(p, buys, fallback)
			if not is_instance_valid(engine) or not engine.is_turn(p): break
			if choice.kind == "stop": break
			var found = (engine.state.center_row + p.reserve).filter(func(c): return c != null and c.uid == choice.uid)
			if found.is_empty(): break
			if choice.kind == "reserve":
				engine.reserve_card(p, found[0])
				completed()
				break
			await engine.buy_card(p, found[0])
			completed()
			continue
		if target != null:
			engine.reserve_card(p, target)
			completed()
			break
		if not buys.is_empty():
			if p.difficulty == 0 or purchase_value(ai, buys[0], p) >= purchase_threshold(p):
				await engine.buy_card(p, buys[0])
				completed()
				continue
		break
	if is_instance_valid(engine) and p == engine.active() and not engine.state.finished and (not continue_turn.is_valid() or continue_turn.call()):
		await engine.end_turn(p)
		completed()
func completed():
	if action_completed.is_valid(): action_completed.call()
func fingerprint(p) -> String:
	return str([p.hacking, p.life, p.hand.size(), engine.state.removed.size(), engine.permanents().map(func(c): return [c.uid, c.counters, c.flags.get("used", false)]), engine.state.players.map(func(q): return [q.life, q.hand.size()])])
func want_buy(p) -> bool:
	for c in engine.state.center_row + p.reserve:
		if c != null and engine.can_buy(p, c) and purchase_value(engine.dec(p), c, p) >= 3.0: return true
	return false
func estimate_hacking(p) -> int:
	var total = 0.0
	var cards = p.deck + p.discard + p.hand
	for c in cards: total += engine.db().get_card(c.id).hack
	return int(total * 5.0 / maxf(1, cards.size()))
func purchase_value(ai, card, p) -> float:
	var result = ai.buy_value(card, p) if ai is BotDecider and ai.defcon else ai.value(card, p)
	if p.difficulty == 3 and p.turns >= 10 and engine.effective_cost(p, card) <= 3:
		result -= float(DefconValues.knobs(engine.state.card_pool, p.starting_life > engine.state.starting_life).late_filler)
	return result
func purchase_threshold(p) -> float:
	return DefconValues.threshold(p, engine.state.card_pool, p.starting_life > engine.state.starting_life) if p.difficulty == 3 else (1.8 if p.difficulty >= 2 else 0.5)
func buy_priority(card, p) -> float:
	var value = purchase_value(engine.dec(p), card, p)
	return value + (2.0 if card in p.reserve and value >= purchase_threshold(p) else 0.0)
func reserve_target(p, buys):
	if p.difficulty == 1 and p.turn_flags.get("acquired", 0) > 0: return null
	if p.difficulty >= 2 and lethal_reachable(p): return null
	var ai = engine.dec(p)
	var threshold = purchase_threshold(p)
	var best = -INF
	for c in buys: best = maxf(best, purchase_value(ai, c, p))
	var reserve_until = engine.state.players.size() * (8 if engine.state.players.size() == 2 else 4)
	var save_until = engine.state.players.size() * (10 if engine.state.players.size() == 2 else 6)
	var held = p.reserve.filter(func(c): return purchase_value(ai, c, p) >= threshold).size()
	var economy = 0
	var income = (p.deck + p.discard + p.hand).map(func(c): return int(engine.db().get_card(c.id).hack))
	income.sort()
	income.reverse()
	var ceiling = 0
	for amount in income.slice(0, 5): ceiling += amount
	var budget = mini(estimate_hacking(p) + 2, ceiling)
	# Public persistent economy supplements printed Hacking in the deck estimate.
	economy += engine.controlled(p, "Botnet").size() * engine.controlled(p, "Botnet").size()
	for c in p.play_area:
		if c.id == "Payphone": economy += 2
		elif c.id in ["Unattended Phone", "Tableskirts"]: economy += 1
	budget += economy
	var targets = engine.state.center_row.filter(func(c): return c != null and engine.can_reserve(p, c))
	targets.sort_custom(func(a, b): return purchase_value(ai, a, p) > purchase_value(ai, b, p) if p.difficulty == 1 else reserve_priority(a, p) > reserve_priority(b, p))
	for c in targets:
		var value = purchase_value(ai, c, p)
		if p.difficulty == 1:
			if engine.state.turn <= engine.state.players.size() * (10 if engine.state.players.size() == 2 else 6) and p.reserve.is_empty() and best < threshold and value >= 3.0 and engine.effective_cost(p, c) <= budget: return c
			continue
		# Denial may exceed the inventory cap, but never sacrifices a worthwhile buy.
		if engine.state.turn <= reserve_until and best < threshold and reserve_priority(c, p) - value >= 2.0: return c
		if held >= 2 or engine.effective_cost(p, c) > budget: continue
		if engine.state.turn <= reserve_until and best < threshold and value >= 3.0: return c
		# Saving a turn's economy is worthwhile only early and without urgent pressure.
		var margin = float(DefconValues.knobs(engine.state.card_pool, p.starting_life > engine.state.starting_life).reserve_margin) if p.difficulty == 3 else 2.5
		var pressure = engine.opponents(p).any(func(q): return q.life <= 8 or p.life + 4 < q.life)
		if engine.state.turn <= save_until and not pressure and not lethal_reachable(p) and best < 2.5 and value >= maxf(3.5, best + margin) and engine.effective_cost(p, c) > p.hacking: return c
	return null
func play_priority(p, c) -> float:
	var data = engine.db().get_card(c.id)
	var score = engine.dec(p).value(c, p)
	if "draw" in str(data.text).to_lower(): score += 100 if p.difficulty == 1 else 30
	if c.id in ["Super r0nk", "DeMartian", "m8trix310"]: score += 40
	if data.kind == "Permanent": score += 45
	if "remove a card" in str(data.text).to_lower() or c.id == "O.P.R.A.H.": score += 50
	if c.id == "Nirtom Unleashed": score -= 90
	if p.difficulty > 0:
		# Spend effects wait until the hand has generated its Hacking.
		if c.id in ["Jenny", "Non-Infringing Game Show", "Treasure Hunters", "Mogs Pancake Breakfast"]: score -= 150
		if c.id == "Mog's Ice Cream" and p.hand.any(func(x): return x.id == "Rookie Numbers"): score -= 120
		if c.id in ["hardwarez", "Pooping in the Dark", "tipsybacchus"]: score -= 100
	if p.difficulty >= 2:
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
	var score = purchase_value(engine.dec(p), card, p)
	# Denial considers only public information about opponents' combinations.
	for q in engine.opponents(p):
		if engine.db().named(card.id, "Botnet"): score += engine.controlled(q, "Botnet").size() * 2.0
		if engine.db().has_subtype(card.id, "FOTTR Hero") and not engine.controlled(q, "The Fellowship of the Token Ring").is_empty(): score += 3.0
		if card.id in ["Never Gonna Give You Up", "Never Gonna Let You Down"] and (q.discard + q.play_area + q.reserve).any(func(x): return x.id in ["Never Gonna Give You Up", "Never Gonna Let You Down"] and x.id != card.id): score += 2.0
		var partners = {"5ud0": ["Bitwize", "crook3dfingers"], "Bitwize": ["5ud0", "crook3dfingers"], "crook3dfingers": ["5ud0", "Bitwize"], "Reps4Thor": ["nirtom", "Nirtom Unleashed"], "nirtom": ["Reps4Thor"], "DeMartian": ["m8trix310"], "m8trix310": ["DeMartian"]}
		if partners.has(card.id) and (q.play_area + q.discard + q.reserve).any(func(x): return x.id in partners[card.id]): score += 2.0
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
