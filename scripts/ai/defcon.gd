class_name DefconSearch
extends RefCounted
# DEFCON uses learned purchase values and doubled starting life. Search never uses hidden order or
# an opponent's actual hand: canonicalize their combined hand/deck, then redeal.
# Sandboxes have independent RNGs and no connections to the live UI or server.
const DECISION_MS = 80
const SERVER_MS = 80
const TURN_MS = 300
const LIVE_TURN_MS = 80
const LETHAL_MS = 40
const LETHAL_NODES = 128
const LIVE_ROLLOUTS = false # Retained in explicit count mode for regression tests.
const HORIZON_ROUNDS = 2
static var fixed_rollouts: int = -1 # >= 0: reproducible count mode, maximum rollout count; wall/node caps apply in every mode
static var force_error = false
static var measurements: Array = []
static var collect_measurements = false
var engine
var budget_ms = DECISION_MS
var thinking_ms = 0
var decision_index = 0
var deadline: int
var rollouts = 0
var yielded = 0
var expired = false
var order_searched = false
var lethal_nodes = 0
var lethal_deadline = 0
var exact_active = false
func _init(game):
	engine = game
func begin() -> int:
	deadline = Time.get_ticks_msec() + mini(budget_ms, maxi(0, TURN_MS - thinking_ms))
	expired = false
	rollouts = 0
	lethal_nodes = 0
	# Uses the original seed, never consumes the real RNG.
	var seed_value = int(engine.state.rng.seed) + engine.state.turn * 1000003 + engine.active().seat * 9176 + decision_index * 7919
	decision_index += 1
	return seed_value
func timed_out() -> bool:
	if not is_instance_valid(engine) or not engine.is_inside_tree() or engine.state.finished: return true
	if exact_active and Time.get_ticks_msec() >= lethal_deadline: return true
	expired = Time.get_ticks_msec() >= deadline
	return expired
static func clone_state(state):
	return SaveGame.clone_memory(state, false)
static func canonical_shuffle(game, cards: Array):
	cards.sort_custom(func(a, b): return a.uid < b.uid)
	game.shuffle(cards)
static func sandbox(source, seat: int, seed_value: int):
	var game = GameEngine.new()
	source.get_tree().root.add_child(game)
	game.state = clone_state(source.state)
	game.state.rng.seed = seed_value
	for p in game.state.players:
		p.is_bot = true
		p.difficulty = 2
		game.deciders.append(BotDecider.new(game, 2))
		if p.seat != seat:
			var count = p.hand.size()
			var unknown = p.hand + p.deck
			canonical_shuffle(game, unknown)
			p.hand = unknown.slice(0, count)
			p.deck = unknown.slice(count)
		else: canonical_shuffle(game, p.deck)
	canonical_shuffle(game, game.state.center_deck)
	return game
static func dispose(game):
	# Object-valued flags (notably attachment hosts) can form RefCounted cycles.
	# Break those only in the throw-away position before releasing its Node.
	for card in game.state.all_cards():
		card.flags.clear()
		card.attached.clear()
	for p in game.state.players: p.turn_flags.clear()
	game.turn_driver = Callable()
	game.free()
func evaluate(game, seat: int) -> float:
	var p = game.state.players[seat]
	if game.state.finished: return 10000.0 if game.state.winner == p else -10000.0
	if not p.alive: return -10000.0
	var best = -INF
	for q in game.opponents(p): best = maxf(best, strength(game, q))
	return strength(game, p) - best
func strength(game, p, public_only: bool = false) -> float:
	var cards = p.discard if public_only else p.deck + p.hand + p.discard
	var value = 0.0
	for c in cards: value += game.dec(p).value(c, null if public_only else p)
	var result = float(p.life) + 8.0 * value / maxf(1, cards.size()) + 0.3 * value
	for c in p.play_area: result += game.dec(p).value(c, null if public_only else p) * 0.8 + c.counters * 0.4
	for c in p.reserve: result += maxf(0, game.dec(p).value(c, null if public_only else p)) * 0.12
	return result
func install_policy(game):
	var driver = BotPlayer.new(game)
	driver.continue_turn = func(): return not timed_out()
	game.turn_driver = func(p): await driver.take_turn(p)
	return driver
func rollout(game, seat: int, stop: int) -> float:
	var driver = install_policy(game)
	while not game.state.finished and game.state.turn < stop and not timed_out():
		await driver.take_turn(game.active())
	var score = evaluate(game, seat)
	# Break Callable -> driver -> engine cycles before freeing the Node.
	game.turn_driver = Callable()
	return score
func between():
	if fixed_rollouts < 0 and is_instance_valid(engine) and engine.is_inside_tree():
		yielded += 1
		await engine.get_tree().process_frame
func record_measurement(kind: String, started: int):
	var elapsed = (Time.get_ticks_usec() - started) / 1000.0
	# Card animation/pacing delays do not spend the turn's thinking allowance.
	thinking_ms += ceili(elapsed)
	if collect_measurements: measurements.append({"kind": kind, "ms": elapsed, "rollouts": rollouts})
func choose_purchase(p, buys: Array, fallback: Dictionary) -> Dictionary:
	var started = Time.get_ticks_usec()
	var result = await _choose_purchase(p, buys, fallback)
	record_measurement("purchase", started)
	return result
func _choose_purchase(p, buys: Array, fallback: Dictionary) -> Dictionary:
	var seed_value = begin()
	if force_error or fixed_rollouts == 0 or (fixed_rollouts < 0 and not LIVE_ROLLOUTS) or timed_out(): return fallback
	var candidates: Array = [fallback]
	for card in buys.slice(0, 3):
		var option = {"kind": "buy", "uid": card.uid}
		if option not in candidates: candidates.append(option)
	var targets = engine.state.center_row.filter(func(c): return c != null and engine.can_reserve(p, c) and engine.dec(p).value(c, p) >= 3.0)
	targets.sort_custom(func(a, b): return engine.dec(p).value(a, p) > engine.dec(p).value(b, p))
	for card in targets.slice(0, 2):
		var option = {"kind": "reserve", "uid": card.uid}
		if option not in candidates: candidates.append(option)
	if {"kind": "stop", "uid": -1} not in candidates: candidates.append({"kind": "stop", "uid": -1})
	if candidates.size() == 1: return fallback
	return await rank_actions(p, candidates, fallback, seed_value)
func rank_actions(p, candidates: Array, fallback: Dictionary, seed_value: int) -> Dictionary:
	var totals = []
	totals.resize(candidates.size())
	totals.fill(0.0)
	var completed = 0
	while completed < (fixed_rollouts if fixed_rollouts >= 0 else 100000) and not timed_out():
		var scores = []
		for option in candidates:
			if timed_out(): break
			var game = sandbox(engine, p.seat, seed_value + completed * 104729)
			install_policy(game) # Candidate effects can themselves start reaction turns.
			var q = game.state.players[p.seat]
			var card = game.state.all_cards().filter(func(c): return c.uid == option.uid)
			if option.kind == "play" and not card.is_empty(): await game.play_card(q, card[0])
			elif option.kind == "buy" and not card.is_empty(): await game.buy_card(q, card[0])
			elif option.kind == "reserve" and not card.is_empty(): game.reserve_card(q, card[0])
			# Stop/reserve end acquisition; buys and plays continue with Elite.
			if option.kind in ["stop", "reserve"] and not game.state.finished: await game.end_turn(q)
			scores.append(await rollout(game, p.seat, engine.state.turn + engine.state.players.size() * HORIZON_ROUNDS))
			dispose(game)
			rollouts += 1
			await between()
		if scores.size() != candidates.size() or timed_out(): break
		for i in scores.size(): totals[i] += scores[i]
		completed += 1
	if completed == 0: return fallback
	var best = 0
	for i in candidates.size():
		if totals[i] > totals[best] + 0.00001: best = i
	return candidates[best]
# Enumerate legal play orders for <=6 initial playable cards, within budget.
# Drawn cards are handled by Elite afterwards. A returned line is a proven win
# in the determinized position, rather than a sum-of-printed-damage estimate.
func lethal_line(game, seat: int, remaining: Array) -> Array:
	if timed_out(): return []
	# Fixed-count mode bounds exact tree work deterministically too. Live mode
	# uses the shared wall-clock deadline; an unfinished tree falls back.
	if lethal_nodes >= LETHAL_NODES or Time.get_ticks_msec() >= lethal_deadline: return []
	lethal_nodes += 1
	if lethal_nodes % 16 == 0:
		await between()
		if timed_out(): return []
	if game.state.finished: return [-1] if game.state.winner == game.state.players[seat] else []
	var p = game.state.players[seat]
	var equivalent = {}
	for uid in remaining:
		var cards = p.hand.filter(func(c): return c.uid == uid and game.can_play(p, c))
		if cards.is_empty(): continue
		var key = str([cards[0].id, cards[0].counters, cards[0].flags])
		if equivalent.has(key): continue
		equivalent[key] = true
		var child = GameEngine.new()
		engine.get_tree().root.add_child(child)
		child.state = clone_state(game.state)
		child.state.rng.seed = game.state.rng.seed
		child.state.rng.state = game.state.rng.state
		for q in child.state.players: child.deciders.append(BotDecider.new(child, 2))
		install_policy(child)
		var card = child.state.players[seat].hand.filter(func(c): return c.uid == uid)[0]
		await child.play_card(child.state.players[seat], card)
		var rest = remaining.duplicate()
		rest.erase(uid)
		var line = await lethal_line(child, seat, rest)
		dispose(child)
		if not line.is_empty(): return [uid] + line
	return []
func choose_play(p, candidates: Array):
	var started = Time.get_ticks_usec()
	var result = await _choose_play(p, candidates)
	record_measurement("play", started)
	return result
func _choose_play(p, candidates: Array):
	var seed_value = begin()
	if force_error or fixed_rollouts == 0 or timed_out(): return candidates[0]
	if candidates.size() <= 6 and lethal_possible(p):
		lethal_deadline = mini(deadline, Time.get_ticks_msec() + LETHAL_MS)
		exact_active = true
		var game = sandbox(engine, p.seat, seed_value)
		var line = await lethal_line(game, p.seat, candidates.map(func(c): return c.uid))
		dispose(game)
		exact_active = false
		await between()
		if not line.is_empty():
			for card in candidates:
				if card.uid == line[0]: return card
	# One ordering comparison per turn: Elite, draw first, Hacking first. The
	# rollout plays the remaining hand with Elite. Subsequent plays still get
	# their bounded exact lethal check when the remaining hand is small.
	if order_searched or (fixed_rollouts < 0 and not LIVE_ROLLOUTS) or timed_out(): return candidates[0]
	order_searched = true
	var options: Array = [{"kind": "play", "uid": candidates[0].uid}]
	var draw = candidates.filter(func(c): return "draw" in str(engine.db().get_card(c.id).text).to_lower())
	var hacking = candidates.duplicate()
	hacking.sort_custom(func(a, b): return engine.db().get_card(a.id).hack > engine.db().get_card(b.id).hack)
	for group in [draw, hacking]:
		if group.is_empty(): continue
		var option = {"kind": "play", "uid": group[0].uid}
		if option not in options: options.append(option)
	if options.size() < 2: return candidates[0]
	var chosen = await rank_actions(p, options, options[0], seed_value)
	for card in candidates:
		if card.uid == chosen.uid: return card
	return candidates[0]

func lethal_possible(p) -> bool:
	# Upper bound using printed hand values and known public/own bonuses only.
	var damage = 0
	var hacking = p.hacking
	for c in p.hand: hacking += int(engine.db().get_card(c.id).hack)
	for c in p.hand:
		damage += int(engine.db().get_card(c.id).damage)
		if engine.db().named(c.id, "Hacker"): damage += engine.controlled(p, "Dick Van Dyke Stamp").size()
		if CustomDeck.rules_id(c.effect_id()) == "Ben The Meek": damage += 3
		if CustomDeck.rules_id(c.effect_id()) == "heartsh8ped": damage += 1
		if CustomDeck.rules_id(c.effect_id()) == "Jenny": damage += hacking
		if CustomDeck.rules_id(c.effect_id()) in ["Non-Infringing Game Show", "LAN Party"]: damage += 3
	for q in engine.opponents(p):
		var life = q.life
		for c in q.play_area:
			if engine.db().has_subtype(c.effect_id(), "Location"): life += c.counters
		if damage >= life: return true
	return false
