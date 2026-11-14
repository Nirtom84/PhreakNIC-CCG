class_name CustomDeckPlanner
extends RefCounted
# Public composition only: subtract unique visible identities, remembering cards
# after they leave the row. Never inspect Center Deck or opponent hidden zones.
static var loaded = false
static var weights: Dictionary = {}
static var calls = 0
var engine
var seen: Dictionary = {}
var pairs: Dictionary = {}
var scores: Dictionary = {}
var remaining: Dictionary = {}
func _init(game):
	engine = game
	census()
	engine.card_moved.connect(observe_move)
	engine.state_changed.connect(invalidate)
func invalidate(): scores.clear()
func observe_move(card, origin, destination):
	scores.clear()
	if destination == "center_deck": seen.erase(card.uid)
	elif origin == "center_deck" or origin == "center_row" or destination in ["center_row", "discard", "play_area", "reserve", "removed"]:
		seen[card.uid] = CustomDeck.base_id(card.id)
static func load_weights(path = "res://data/custom_deck_weights.json"):
	loaded = true
	weights = {}
	if not FileAccess.file_exists(path): return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return
	var data = parser.data
	if not data is Dictionary or data.get("format") != "custom-weights-v1" or not data.get("adjustments") is Dictionary: return
	for values in data.adjustments.values():
		if not values is Array or values.size() != 3: return
		for v in values:
			if not (v is float or v is int) or not is_finite(float(v)): return
	weights = data.adjustments
func census() -> Dictionary:
	var visible = engine.state.center_row + engine.state.removed + engine.state.resolving
	for p in engine.state.players:
		visible += p.discard + p.play_area + p.reserve + p.played
	for c in visible:
		if c == null: continue
		seen[c.uid] = CustomDeck.base_id(c.id)
		for a in c.attached: seen[a.uid] = CustomDeck.base_id(a.id)
	remaining = {}
	for id in engine.state.custom_deck.cards:
		var base = CustomDeck.base_id(id)
		remaining[base] = remaining.get(base, 0) + int(engine.state.custom_deck.cards[id])
	for id in seen.values():
		if remaining.has(id): remaining[id] = maxi(0, remaining[id] - 1)
	return remaining
func synergy(a: String, b: String) -> float:
	var key = a + "|" + b
	if pairs.has(key): return pairs[key]
	var da = engine.db().get_card(a)
	var db = engine.db().get_card(b)
	var ta = str(da.text).to_lower()
	var tb = str(db.text).to_lower()
	var na = str(da.name).to_lower()
	var nb = str(db.name).to_lower()
	var score = 0.0
	if na != nb and (nb in ta or na in tb): score += 1.6
	for family in ["botnet", "mognet", "phone", "phreaknic", "fottr", "rick", "mog"]:
		if (family in na or family in ta) and (family in nb or family in tb): score += 0.35
	if CustomDeck.base_id(a) == "Botnet" and CustomDeck.base_id(b) == "Botnet": score += 1.5
	pairs[key] = score
	return score
func value(ai, card, p) -> float:
	calls += 1
	if not loaded: load_weights()
	var key = str([p.seat, card.uid, p.hacking, p.life, p.turns, engine.state.turn, weights.get(CustomDeck.base_id(card.id), [])])
	if scores.has(key): return scores[key]
	census()
	var base = CustomDeck.base_id(card.id)
	var fraction = float(engine.state.center_deck.size()) / maxf(1, CustomDeck.total(engine.state.custom_deck))
	var phase = 2 if fraction < 0.2 else DefconValues.phase(p)
	var score = ai.value(card, p) + float(weights.get(base, [0, 0, 0])[phase])
	var own = 0.0
	for c in p.deck + p.hand + p.discard + p.play_area + p.reserve: own += synergy(card.id, c.id)
	var future = 0.0
	var total = 0
	for id in remaining:
		total += remaining[id]
		future += remaining[id] * synergy(card.id, id)
	future /= maxf(1, total)
	var denial = 0.0
	var strongest = null
	for q in engine.opponents(p):
		if strongest == null or q.life + q.play_area.size() * 3 > strongest.life + strongest.play_area.size() * 3: strongest = q
	if strongest != null:
		for c in strongest.play_area + strongest.discard + strongest.reserve: denial += synergy(card.id, c.id)
	denial = minf(3, denial * 0.35) / maxf(1, engine.effective_cost(p, card) / 3.0)
	var d = engine.db().get_card(card.id)
	score += minf(6, own * 0.6) + future * fraction + denial
	score += float(d.hack) * (fraction - 0.4) * CustomDeck.total(engine.state.custom_deck) / 120.0
	score += float(d.damage) * (1 - fraction) * 0.5
	if p.difficulty == 1:
		# Stable seeded noise without consuming or perturbing game RNG.
		var noise = float(absi(hash(str([engine.state.rng.seed, engine.state.turn, card.uid]))) % 801) / 100.0 - 4.0
		score = ai.value(card, p) * 0.65 + score * 0.35 + noise
	scores[key] = score
	return score
