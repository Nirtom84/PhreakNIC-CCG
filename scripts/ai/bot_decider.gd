class_name BotDecider
extends Decider
var engine
var difficulty: int
func _init(game = null, level: int = 0):
	engine = game
	difficulty = level
func value(card, player = null) -> float:
	var d = engine.db().get_card(card.id)
	var text = str(d.text).to_lower()
	var score = float(d.damage) + float(d.hack) * 0.9
	if "draw" in text:
		var count = 1
		if "draw 2" in text or "draw two" in text: count = 2
		if "draw 3" in text: count = 3
		score += count * 1.2
		if "then discard" in text: score -= 0.7
	if "gain" in text and "life" in text: score += 0.8
	if d.kind == "Permanent":
		score += 1.0 + engine.effects.initial_ice(card.id) * 0.6
		if "once per turn" in text: score += 2.8
	if "remove a card" in text: score += 1.8 if difficulty == 2 else 0.7
	match card.id:
		"Rickroll", "PhreakMyst": score = -3.0
		"Touch Grass": score = 0.0
		"Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4": score = 5.0
		"The Book", "The Fellowship of the Token Ring", "Foundation of Time Temporal Reconstruction", "Dick Van Dyke Stamp", "Kevin's Desk": score = 8.0
		"Ben the Phreak", "Oprah Wonka", "O.P.R.A.H.": score = 6.0
		"Lowes Shopping Cart": score = 3.0
		"Bribery", "White Python Boots": score = 5.5
		"The Juice": score = 3.0
		"Time Travel": score = 5.0
		"Nashville 2600": score = 1.0
		"Nirtom Unleashed": score = 1.5
	if difficulty > 0:
		# Text-only effects need explicit estimates; printed damage/hack omit them.
		match card.id:
			"Ben The Meek": score = 4.0
			"heartsh8ped": score = 1.3
			"Jenny": score = 3.5
			"Non-Infringing Game Show": score = 3.5
			"LAN Party": score = 3.0
			"Hotel Roof Chair Toss": score = 1.8
			"Two Hump Camel": score = 1.9
			"The Phreaknic Network": score = 7.0
			"FOTTR Greatest Hits Vol 2": score = 10.0
			"Clarion Inn Closet": score = 7.0
			"The Big Dipper": score = 5.0
			"Shell Speech": score = 8.0
			"Payphone": score = 8.0
			"Disassembled Sink": score = 7.0
			"FOTTR Greatest Hits": score = 7.0
			"Sticky Fingers": score = 6.0
			"Registration": score = 4.0
			"OSINT for Dummies": score = 5.0
			"Brimstone, Fabulous": score = 6.5
			"Lightning Talks": score = 4.5
			"The Clarion Inn": score = 3.5
			"Military-Grade Card Encapsulation": score = 4.0
			"The Juice": score = -2.0
			"AI Bens AI Camry": score = 2.0
			"Fivrr Friendship": score = 2.0
			"Tennessee Department of Health": score = 2.0
		if player != null and difficulty == 2:
			# Elite additionally evaluates the public board; Phreak uses the fixed estimates.
			if card.id == "pouipoui, AV Guy": score = 1.0 + engine.permanents().size()
			if card.id == "Hotel Roof Chair Toss": score += player.play_area.filter(func(c): return engine.db().has_subtype(c.id, "Location")).size()
			if card.id in ["Sticky Fingers", "AI Slop", "Still Not Spock"] and engine.permanents().any(func(c): return c.controller != player.seat): score += 2.0
			if card.id == "Clarion Inn Morning Coffee":
				for c in engine.permanents(): score += 1.5 if c.controller != player.seat else -2.0
	if player != null and difficulty == 2:
		var owned = player.deck + player.hand + player.discard + player.play_area
		if engine.db().named(card.id, "Botnet"): score += owned.filter(func(c): return engine.db().named(c.id, "Botnet")).size() * 2.0
		var pairs = {"5ud0": ["Bitwize", "crook3dfingers"], "Bitwize": ["5ud0", "crook3dfingers"], "crook3dfingers": ["5ud0", "Bitwize"], "Never Gonna Give You Up": ["Never Gonna Let You Down"], "Never Gonna Let You Down": ["Never Gonna Give You Up"], "Reps4Thor": ["nirtom", "Nirtom Unleashed"], "nirtom": ["Reps4Thor"], "DeMartian": ["m8trix310"], "m8trix310": ["DeMartian"]}
		if pairs.has(card.id):
			for c in owned:
				if c.id in pairs[card.id]: score += 1.6
		if engine.db().has_subtype(card.id, "FOTTR Hero") and not engine.controlled(player, "The Fellowship of the Token Ring").is_empty(): score += 3
		var enemy_life = 999
		for q in engine.opponents(player): enemy_life = mini(enemy_life, q.life)
		if enemy_life < 12: score += float(d.damage) * 0.8
	return score
func choose_option(player, prompt: String, options: Array[String]) -> int:
	if "simultaneous" in prompt or "attached Action" in prompt:
		var priorities = ["Clarion Inn Air Conditioning", "Rickroll", "Clarion Inn Storage Closet", "pTFS", "The Book", "Zenthere, Mind Goblin", "The Phreaknic Network", "Military-Grade Card Encapsulation"]
		if "attached Action" in prompt: priorities = ["Rookie Numbers", "heartsh8ped"]
		for name in priorities:
			if name in options: return options.find(name)
		return 0
	# Payphone may be cancelled by humans, but a bot must resolve its free power.
	if prompt == "Choose one" and options.size() == 3 and options[2] == "Cancel" and options[0] == "+2 hacking" and options[1] == "Deal 2 damage":
		return engine.rand_range(0, 1) if difficulty == 0 else 1
	if difficulty == 0: return engine.rand_range(0, options.size() - 1)
	if prompt.begins_with("Choose pile"):
		# The split dialog contains stable ids, allowing equal evaluation of each pile.
		var sections = prompt.trim_prefix("Choose pile: ").split(" / ")
		var best = 0
		var best_score = -INF
		for i in mini(2, sections.size()):
			var score = 0.0
			for id in engine.db().pool_ids(engine.state.card_pool):
				if ('"' + id + '"') in sections[i]: score += value(CardInstance.new(0, id), player)
			if score > best_score:
				best_score = score
				best = i
		return best
	var best = 0
	var best_score = -INF
	for i in options.size():
		var text = options[i].to_lower()
		var score = 0.0
		if "draw" in text: score = 4.0
		if "hacking" in text: score = 2.0 if engine.state.turn < 18 else 1.0
		if "damage" in text: score = 2.7
		if "life" in text: score = 3.5 if player.life <= 5 else 0.5
		if score > best_score:
			best_score = score
			best = i
	return best
func choose_options(player, prompt: String, options: Array[String], count: int) -> Array[int]:
	var remaining = options.duplicate()
	var indices: Array[int] = []
	for i in mini(count, options.size()):
		var strings: Array[String] = []
		strings.assign(remaining)
		var chosen = await choose_option(player, prompt, strings)
		indices.append(options.find(remaining[chosen]))
		remaining.remove_at(chosen)
	return indices
func choose_cards(player, prompt: String, cards: Array, min_n: int, max_n: int) -> Array:
	var sorted = cards.duplicate()
	if difficulty == 0:
		engine.shuffle(sorted)
		return sorted.slice(0, engine.rand_range(min_n, max_n))
	if "full prevention" in prompt:
		sorted.sort_custom(func(a, b): return a.effect_id() == "Military-Grade Card Encapsulation" and b.effect_id() != "Military-Grade Card Encapsulation")
		return sorted.slice(0, 1)
	if "ICE prevention" in prompt:
		sorted.sort_custom(func(a, b): return a.counters < b.counters)
		return sorted.slice(0, 1)
	if "Split cards" in prompt:
		sorted.sort_custom(func(a, b): return value(a, player) > value(b, player))
		var pile: Array = []
		var totals = [0.0, 0.0]
		for c in sorted:
			var index = 0 if totals[0] <= totals[1] else 1
			totals[index] += value(c, player)
			if index == 0: pile.append(c)
		return pile
	if "Discard" in prompt and sorted.any(func(c): return c in engine.permanents() and c.controller != player.seat):
		sorted = sorted.filter(func(c): return c.controller != player.seat)
		sorted.sort_custom(func(a, b): return value(a, player) > value(b, player))
		return sorted.slice(0, maxi(min_n, 1))
	if "Take control of permanent" in prompt:
		var enemies = sorted.filter(func(c): return c.controller != player.seat)
		if not enemies.is_empty(): sorted = enemies
	var removing = "Remove cards" in prompt or "Discard" in prompt
	if "Take phone" in prompt or "Take Clarion" in prompt or "Give Rickroll" in prompt: removing = false
	sorted.sort_custom(func(a, b): return value(a, player) < value(b, player) if removing else value(a, player) > value(b, player))
	if "Remove center" in prompt:
		sorted.sort_custom(func(a, b): return value(a, player) < value(b, player))
	if "Remove location counter" in prompt:
		sorted = sorted.filter(func(c): return c.controller != player.seat)
		return sorted.slice(0, 1)
	if min_n > 0: return sorted.slice(0, min_n)
	if "Remove cards" in prompt:
		return thinning_choices(sorted, player, max_n)
	if "Discard to redraw" in prompt or "Discard for hacking" in prompt:
		return sorted.filter(func(c): return value(c, player) < 1.5).slice(0, max_n)
	if "Discard hero to add ICE" in prompt: return []
	if "Copy location" in prompt: return sorted.filter(func(c): return engine.effects.initial_ice(c.effect_id()) > 3).slice(0, 1)
	return sorted.slice(0, maxi(1, min_n))
func thinning_choices(cards: Array, player, count: int) -> Array:
	# Composition only: never use the order of the deck or opponents' hidden cards.
	var owned = player.deck + player.hand + player.discard
	var hacking = 0
	var damage = 0
	for c in owned:
		var d = engine.db().get_card(c.id)
		hacking += int(d.hack)
		damage += int(d.damage)
		if c.id in ["Ben The Meek", "Non-Infringing Game Show", "LAN Party"]: damage += 3
	for c in player.play_area:
		if engine.db().named(c.id, "Botnet"): hacking += engine.controlled(player, "Botnet").size() * 2
		if c.id in ["Payphone", "Unattended Phone", "Tableskirts"]: hacking += 2
		if c.id in ["Payphone", "Bribery", "FOTTR Greatest Hits Vol 2", "Dick Van Dyke Stamp"]: damage += 3
	var result: Array = []
	for c in cards:
		if result.size() >= count: break
		if c.id not in ["Hacking", "Damage", "Rickroll"] and value(c, player) >= 1.5: continue
		if c.id == "Hacking":
			if hacking <= 6 or not engine.controlled(player, "Dick Van Dyke Stamp").is_empty(): continue
			hacking -= 1
		if c.id == "Damage":
			if damage <= 2: continue
			damage -= 1
		result.append(c)
	return result

func choose_player(_player, _prompt: String, players: Array) -> PlayerState:
	if players.is_empty(): return null
	if difficulty == 0: return players[engine.rand_range(0, players.size() - 1)]
	var sorted = players.duplicate()
	sorted.sort_custom(func(a, b): return a.life < b.life)
	return sorted[0]
func choose_number(player, prompt: String, allowed: Array[int]) -> int:
	if allowed.is_empty(): return 0
	if difficulty == 0: return allowed[engine.rand_range(0, allowed.size() - 1)]
	if "acquire matching" in prompt:
		var best = 0
		var best_score = -INF
		for id in engine.db().pool_ids(engine.state.card_pool):
			var c = CardInstance.new(0, id)
			var cost = int(engine.db().get_card(c.id).cost)
			if cost in allowed and value(c, player) > best_score:
				best_score = value(c, player)
				best = cost
		return best
	if "gain life" in prompt: return allowed.max() if player.life < 8 else allowed.min()
	return allowed.max()
func confirm(player, prompt: String) -> bool:
	if "TOCTOU" in prompt: return true
	if difficulty == 0: return engine.coin_flip()
	if "Put bought" in prompt or "Store bought" in prompt or "Put discard" in prompt: return true
	if "Shuffle John" in prompt: return true
	if "Give Merry" in prompt: return true
	if "Discard permanent" in prompt or "discard a permanent" in prompt:
		return engine.permanents().any(func(c): return c.controller != player.seat)
	if "O.P.R.A.H." in prompt:
		return engine.state.center_row.any(func(c): return c != null and c.id == "O.P.R.A.H.")
	if "Remove this" in prompt: return true
	return false
func name_a_card(_player, _prompt: String) -> String:
	# Use public card frequencies; bots do not inspect hidden opponent hands.
	return "Hacking"
