class_name GameEngine
extends Node
signal card_played(player, card)
signal card_bought(player, card)
signal card_reserved(player, card)
signal state_changed
signal log_message(text)
signal ice_counter_removed(card)
signal card_moved(card, from_zone, to_zone)
signal damage_dealt(source_player, target_player, amount)
signal damage_incoming(source_player, target_player, amount, source_card)
signal turn_started(player)
signal turn_ended(player)
signal game_over(winner)
signal turn_or_game_over
var secure_random = false
var state: GameState
var deciders: Array = []
var effects
var busy: bool = false
var reaction_depth: int = 0
var simultaneous_depth: int = 0
var turn_driver: Callable
# Pending triggers use departure generations, including leave/re-enter during reactions.
var play_versions: Dictionary = {}
func _init():
	turn_ended.connect(func(_p): turn_or_game_over.emit())
	game_over.connect(func(_winner): turn_or_game_over.emit())
	effects = preload("res://scripts/core/effects.gd").new(self)
func db() -> Node: return get_node("/root/CardDB").catalog(state.card_pool if state != null else "2026")
# Rejection sampling over 32 random bits avoids modulo bias.
static func crypto_int(n: int) -> int:
	assert(n > 0 and n <= 0x100000000)
	var limit = 0x100000000 - (0x100000000 % n)
	while true:
		var bytes = Crypto.new().generate_random_bytes(4)
		assert(bytes.size() == 4)
		var value = int(bytes.decode_u32(0))
		if value < limit: return value % n
	return 0
func rand_int(n: int) -> int:
	return crypto_int(n) if secure_random else state.rng.randi_range(0, n - 1)
func rand_range(low: int, high: int) -> int:
	return low + rand_int(high - low + 1)
func coin_flip() -> bool:
	return rand_int(2) == 0 if secure_random else state.rng.randf() < 0.5
func shuffle(cards: Array):
	for i in range(cards.size() - 1, 0, -1):
		var j = rand_int(i + 1)
		var card = cards[i]
		cards[i] = cards[j]
		cards[j] = card
func trim_log():
	if not secure_random: return
	while state.log.size() > 200: state.log.pop_front()
	var size = 0
	for i in range(state.log.size() - 1, -1, -1):
		size += state.log[i].to_utf8_buffer().size()
		if size > 65536:
			state.log = state.log.slice(i + 1)
			break
func setup(difficulties: Array, seed_value: int = 1, choices: Array = [], card_pool: String = "2026", starting_life: int = 0, banned: Array = []) -> bool:
	assert(difficulties.size() >= 2 and difficulties.size() <= 4)
	if not get_node("/root/CardDB").catalog(card_pool).bans_valid(banned, card_pool): return false
	state = GameState.new()
	state.card_pool = card_pool if card_pool in ["2025", "2026", "2026mog"] else "2026"
	state.banned = db().filter_banned(banned, state.card_pool)
	state.rng.seed = seed_value
	state.starting_life = starting_life if starting_life > 0 else (24 if difficulties.size() == 2 else 10 * difficulties.size())
	deciders = choices.duplicate()
	for seat in difficulties.size():
		var p = PlayerState.new(seat)
		p.life = state.starting_life
		p.difficulty = difficulties[seat]
		p.is_bot = difficulties[seat] >= 0
		state.players.append(p)
		if deciders.size() <= seat:
			var decider = preload("res://scripts/ai/bot_decider.gd").new(self, p.difficulty)
			deciders.append(decider)
		for i in 10: p.deck.append(state.create("Hacking" if i < 8 else "Damage", seat))
		shuffle(p.deck)
		draw(p, 5)
	for id in db().pool_ids(state.card_pool):
		if not db().get_card(id).starter and id not in state.banned: state.center_deck.append(state.create(id))
	shuffle(state.center_deck)
	for i in 5: refill(i)
	state.active_seat = rand_int(state.players.size())
	say("Seat %d goes first" % state.active_seat)
	state.initial_count = state.all_cards().size()
	for c in state.all_cards(): state.initial_ids[c.uid] = c.id
	return true
func say(message: String):
	state.log.append(message)
	trim_log()
	log_message.emit(message)
func dec(p): return deciders[p.seat]
func active(): return state.players[state.active_seat]
func opponents(p) -> Array: return state.players.filter(func(q): return q.alive and q != p)
func permanents() -> Array:
	var result: Array = []
	for p in state.players:
		if p.alive: result += p.play_area
	return result
func controlled(p, name: String) -> Array:
	return p.play_area.filter(func(c): return db().named(c.effect_id(), name))
func in_play(name: String) -> bool:
	return permanents().any(func(c): return db().named(c.effect_id(), name))
func played_name(p, name: String, contains: bool = false) -> bool:
	return p.played.any(func(c): return db().name_contains(c.id, name) if contains else db().named(c.id, name))
func draw(p, count: int):
	for i in count:
		if p.deck.is_empty():
			var shuffled = p.discard.duplicate()
			p.deck.append_array(p.discard)
			p.discard.clear()
			shuffle(p.deck)
			for card in shuffled: card_moved.emit(card, "discard", "deck")
		if p.deck.is_empty(): break
		move(p.deck.back(), p.hand, "hand")
func refill(slot: int):
	if state.center_row[slot] == null and not state.center_deck.is_empty():
		var card = state.center_deck.pop_back()
		state.center_row[slot] = card
		card_moved.emit(card, "center_deck", "center_row")
func detach(card) -> String:
	var slot = state.center_row.find(card)
	if slot >= 0:
		state.center_row[slot] = null
		refill(slot)
		return "center_row"
	for label in ["center_deck", "removed", "resolving"]:
		var zone = state.get(label)
		if card in zone:
			zone.erase(card)
			return label
	for p in state.players:
		for label in ["deck", "hand", "discard", "play_area", "reserve"]:
			var zone = p.get(label)
			if card in zone:
				zone.erase(card)
				return label
	for root in state.all_cards():
		if card in root.attached:
			root.attached.erase(card)
			return "attached"
	return "unplaced"
func move(card, destination: Array, label: String, origin_override: String = ""):
	if card.flags.get("virtual", false):
		card = card.flags.get("host")
		if card == null: return
	var origin = detach(card)
	destination.append(card)
	card_moved.emit(card, origin_override if not origin_override.is_empty() else origin, label)
func gain_owner(card, p):
	if card.flags.get("virtual", false) and card.flags.has("host"): gain_owner(card.flags.host, p)
	card.owner = p.seat
	card.controller = p.seat
func leave_play(card, remove: bool = false):
	play_versions[card.uid] = play_versions.get(card.uid, 0) + 1
	var owner = state.players[card.owner] if card.owner >= 0 else active()
	var attachment_recipient = state.players[card.controller] if card.controller >= 0 else owner
	for child in card.attached.duplicate():
		move(child, attachment_recipient.discard, "discard")
		gain_owner(child, attachment_recipient)
	move(card, state.removed if remove else attachment_recipient.discard, "removed" if remove else "discard")
	gain_owner(card, attachment_recipient)
	card.counters = 0
	card.flags.clear()
func discard(card):
	if card in permanents(): leave_play(card)
	else: move(card, state.players[card.owner].discard, "discard")
func remove(card):
	if card in permanents(): leave_play(card, true)
	else: move(card, state.removed, "removed")
func take_control(card, p):
	move(card, p.play_area, "play_area")
	card.controller = p.seat
func choose(p, prompt: String, cards: Array, min_n: int = 1, max_n: int = 1) -> Array:
	if cards.is_empty(): return []
	var selected = await dec(p).choose_cards(p, prompt, cards.duplicate(), mini(min_n, cards.size()), mini(max_n, cards.size()))
	var valid: Array = []
	for c in selected:
		if c in cards and c not in valid and valid.size() < max_n: valid.append(c)
	for c in cards:
		if valid.size() >= mini(min_n, cards.size()): break
		if c not in valid: valid.append(c)
	return valid
func discard_choices(p, cards: Array, count: int = 1):
	for c in await choose(p, "Discard cards", cards, count, count): discard(c)
func remove_choices(p, cards: Array, min_n: int = 0, max_n: int = 1) -> Array:
	var selected = await choose(p, "Remove cards from game", cards, min_n, max_n)
	for c in selected: remove(c)
	return selected
func start_turn(seat: int = -1):
	if state.finished: return
	if seat >= 0: state.active_seat = seat
	var p = active()
	if not p.alive: return
	var saved_busy = busy
	busy = true
	state.turn += 1
	p.turns += 1
	p.hacking = 0
	p.played.clear()
	p.turn_flags.clear()
	for q in state.players: q.turn_flags.erase("prevent_all")
	for c in permanents(): c.flags.erase("used")
	turn_started.emit(p)
	await effects.start_turn(p)
	busy = saved_busy
	state_changed.emit()
	if not p.alive and not state.finished: await end_turn(p)
func is_turn(p) -> bool: return not state.finished and p.alive and p == active()
func can_play(p, card) -> bool:
	if not is_turn(p) or card not in p.hand: return false
	return legal_effect(p, card)
func legal_effect(p, card) -> bool:
	var data = db().get_card(card.id)
	if data.kind == "Permanent" and in_play("Nashville 2600"): return false
	if card.id == "PhreakMyst" and p.turn_flags.get("bought", 0) > 0: return false
	if card.id == "Even More Logo" and played_name(p, "_NSAKEY", true): return false
	if db().name_contains(card.id, "_NSAKEY") and p.played.any(func(c): return c.id == "Even More Logo"): return false
	if data.kind == "Action":
		if card.id == "Nirtom Unleashed":
			for prior in p.played:
				if db().get_card(prior.id).kind == "Action" and not db().named(prior.id, "Reps4Thor"): return false
		elif p.played.any(func(c): return c.id == "Nirtom Unleashed") and not db().named(card.id, "Reps4Thor"): return false
	return true
func play_card(p, card) -> bool:
	if busy or not can_play(p, card): return false
	busy = true
	var permanent = db().get_card(card.id).kind == "Permanent"
	move(card, p.play_area if permanent else state.resolving, "play_area" if permanent else "resolving")
	card.controller = p.seat
	say("Seat %d plays %s" % [p.seat, db().get_card(card.id).name])
	await resolve_play(p, card)
	if card in state.resolving: discard(card)
	busy = false
	state_changed.emit()
	if not p.alive and not state.finished: await end_turn(p)
	return true
func resolve_play(p, card):
	if not p.alive or state.finished: return
	p.played.append(card)
	card_played.emit(p, card)
	state.coverage[card.id] = state.coverage.get(card.id, 0) + 1
	await effects.on_play(p, card)
	if p.alive and not state.finished: await effects.resolve(p, card)
	await effects.combos(p)
func effective_cost(p, card) -> int: return effects.cost(p, card)
func can_acquire(p) -> bool:
	return is_turn(p) and (not p.turn_flags.get("reserved", false) or p.turn_flags.get("tips", false))
func can_buy(p, card) -> bool:
	return card != null and can_acquire(p) and (card in state.center_row or card in p.reserve) and not p.turn_flags.get("no_buy", false) and not in_play("Grass") and p.hacking >= effective_cost(p, card)
func buy_card(p, card, mandatory: bool = false) -> bool:
	if busy and not mandatory: return false
	if not can_buy(p, card): return false
	var saved_busy = busy
	busy = true
	var from_row = card in state.center_row
	var price = effective_cost(p, card)
	p.hacking -= price
	effects.consume_free_buy(p, card, price)
	p.turn_flags.bought = p.turn_flags.get("bought", 0) + 1
	p.turn_flags.acquired = p.turn_flags.get("acquired", 0) + 1
	var slot = state.center_row.find(card)
	# Rickroll replaces the purchased row slot without consuming a center-deck refill.
	var roll = p.turn_flags.get("rickroll")
	if from_row and roll != null and roll != card:
		state.center_row[slot] = null
		detach(roll)
		state.center_row[slot] = roll
		roll.owner = -1
		roll.controller = -1
		p.turn_flags.erase("rickroll")
		card_moved.emit(roll, "discard", "center_row")
	gain_owner(card, p)
	move(card, p.discard, "discard", "center_row" if from_row else "reserve")
	say("Seat %d buys %s for %d" % [p.seat, db().get_card(card.id).name, price])
	card_bought.emit(p, card)
	await effects.bought(p, card, from_row)
	busy = saved_busy
	state_changed.emit()
	if not p.alive and not state.finished: await end_turn(p)
	return true
func acquire(p, card, destination = null) -> bool:
	if not can_acquire(p): return false
	gain_owner(card, p)
	move(card, p.discard if destination == null else destination, "acquired")
	p.turn_flags.acquired = p.turn_flags.get("acquired", 0) + 1
	return true
func can_reserve(p, card) -> bool:
	return is_turn(p) and card in state.center_row and card != null and not p.turn_flags.get("reserved", false) and (p.turn_flags.get("acquired", 0) == 0 or p.turn_flags.get("tips", false))
func reserve_card(p, card) -> bool:
	if busy or not can_reserve(p, card): return false
	gain_owner(card, p)
	move(card, p.reserve, "reserve")
	p.turn_flags.reserved = true
	card_reserved.emit(p, card)
	say("Seat %d reserves %s" % [p.seat, db().get_card(card.id).name])
	state_changed.emit()
	return true
func activatable_abilities(p, permanent) -> Array:
	return effects.abilities(p, permanent)
func activate(p, permanent, ability_index: int = 0) -> bool:
	if busy or not is_turn(p): return false
	for ability in activatable_abilities(p, permanent):
		if ability.index == ability_index and ability.enabled:
			busy = true
			await effects.activate(p, permanent, ability_index)
			busy = false
			state_changed.emit()
			if not p.alive and not state.finished: await end_turn(p)
			return true
	return false
func end_turn(p):
	if busy or p != active() or state.finished: return
	busy = true
	if p.alive:
		await effects.end_turn(p)
		if p.alive:
			for card in p.hand.duplicate(): discard(card)
			draw(p, 5)
	p.hacking = 0
	busy = false
	turn_ended.emit(p)
	state_changed.emit()
	if reaction_depth > 0: return
	if state.finished: return
	var next_seat = -1
	while not state.extra_turns.is_empty() and next_seat < 0:
		var candidate = state.extra_turns.pop_front()
		if state.players[candidate].alive: next_seat = candidate
	if next_seat < 0:
		for step in range(1, state.players.size() + 1):
			var seat = (p.seat + step) % state.players.size()
			if state.players[seat].alive:
				next_seat = seat
				break
	state.active_seat = next_seat if next_seat >= 0 else p.seat
	if not state.finished: await start_turn()
func counter_removed(card):
	ice_counter_removed.emit(card)
	if card.counters > 0 or card not in permanents(): return
	var id = card.effect_id()
	var p = state.players[card.controller]
	if id == "Walmart Parking Lot": return
	leave_play(card, id == "The Clarion Inn")
	if id == "Carpeted Pool": await deal(p, 1, card)
	if id == "The Clarion Inn": await damage(p, p, 4, card, false)
func deal(p, amount: int, source = null):
	if amount <= 0 or not p.alive: return
	if source != null and db().get_card(source.effect_id()).kind == "Permanent": amount += controlled(p, "CTF Bangers").size()
	for q in opponents(p): await damage(p, q, amount, source, true)
func damage(p, q, amount: int, source = null, dealing: bool = false):
	var saved_busy = busy
	busy = true
	await resolve_damage(p, q, amount, source, dealing)
	busy = saved_busy
func resolve_damage(p, q, amount: int, source = null, dealing: bool = false):
	if not q.alive or state.finished or amount <= 0: return
	var guards = controlled(q, "Military-Grade Card Encapsulation") + controlled(q, "Phreaknic Network")
	var ice = q.play_area.filter(func(c): return c.counters > 0 and db().has_subtype(c.effect_id(), "Location"))
	damage_incoming.emit(p, q, amount, source)
	var sources: Array = []
	if q.turn_flags.get("prevent_all", false):
		sources.append({"card": null, "name": "Phreaknic Network (rest of turn)", "capacity": amount, "full": true})
	for c in guards + ice:
		sources.append({"card": c, "capacity": amount if c in guards else c.counters, "full": c in guards})
	if not sources.is_empty():
		var total = 0
		for entry in sources: total += entry.capacity
		var allocation: Array = []
		if sources.size() > 1 and total > amount:
			allocation = await dec(q).allocate_prevention(q, amount, sources)
		# Clamp invalid decisions and fill any unallocated mandatory prevention.
		var remaining = amount
		var points: Array = []
		for i in sources.size():
			var n = clampi(int(allocation[i]) if i < allocation.size() else sources[i].capacity, 0, mini(remaining, sources[i].capacity))
			points.append(n)
			remaining -= n
		for i in sources.size():
			var n = mini(remaining, sources[i].capacity - points[i])
			points[i] += n
			remaining -= n
		var depleted: Array = []
		for i in sources.size():
			if points[i] == 0: continue
			var c = sources[i].card
			if c not in permanents(): continue
			if sources[i].full:
				if c.effect_id() == "The Phreaknic Network":
					leave_play(c)
					q.turn_flags.prevent_all = true
			else:
				c.counters -= points[i]
				if c.counters == 0 and c.effect_id() != "Walmart Parking Lot":
					depleted.append({"card": c, "commutes": c.effect_id() not in ["Carpeted Pool", "The Clarion Inn"], "resolve": counter_removed.bind(c)})
				else: ice_counter_removed.emit(c)
		amount = remaining
		await resolve_triggers(depleted, false)
	if not q.alive or state.finished: return
	if amount > 0:
		q.life -= amount
		if dealing: damage_dealt.emit(p, q, amount)
		say("Seat %d takes %d damage (%d life)" % [q.seat, amount, q.life])
		if q.life <= 0: await eliminate(q)
	state_changed.emit()
func eliminate(p, forced: bool = false):
	if not p.alive: return
	var reactions = p.hand.filter(func(c): return c.id == "TOCTOU")
	if not reactions.is_empty() and await dec(p).confirm(p, "Use TOCTOU to avoid losing?"):
		remove(reactions[0])
		p.life = 1
		await reaction_turn(p)
		return
	p.alive = false
	for c in p.play_area.duplicate(): leave_play(c, true)
	for c in p.reserve.duplicate():
		detach(c)
		c.owner = -1
		c.controller = -1
		state.center_deck.push_front(c)
		card_moved.emit(c, "reserve", "center_deck")
	for slot in 5: refill(slot)
	say("Seat %d eliminated%s" % [p.seat, " by card" if forced else ""])
	check_win()
func reaction_turn(p):
	var saved_busy = busy
	busy = false
	var paused = active()
	var saved = {"flags": paused.turn_flags.duplicate(true), "played": paused.played.duplicate(), "hack": paused.hacking}
	var prevention: Array = []
	for q in state.players: prevention.append(q.turn_flags.get("prevent_all", false))
	var used = {}
	for c in permanents(): used[c.uid] = c.flags.get("used", false)
	var saved_extra = state.extra_turns
	state.extra_turns = []
	reaction_depth += 1
	await start_turn(p.seat)
	if p.alive and not state.finished:
		if p.is_bot:
			if turn_driver.is_valid(): await turn_driver.call(p)
			else: await preload("res://scripts/ai/bot_player.gd").new(self).take_turn(p)
		else:
			await turn_or_game_over
			# Let end_turn finish while reaction_depth still describes its turn.
			await Engine.get_main_loop().process_frame
	while not state.extra_turns.is_empty() and not state.finished:
		var next_seat = state.extra_turns.pop_front()
		var next_player = state.players[next_seat]
		if not next_player.alive: continue
		await start_turn(next_seat)
		if not next_player.alive or state.finished: continue
		if next_player.is_bot:
			if turn_driver.is_valid(): await turn_driver.call(next_player)
			else: await preload("res://scripts/ai/bot_player.gd").new(self).take_turn(next_player)
		else:
			await turn_or_game_over
			# Let end_turn finish while reaction_depth still describes its turn.
			await Engine.get_main_loop().process_frame
	state.extra_turns = saved_extra
	reaction_depth -= 1
	busy = saved_busy
	state.active_seat = paused.seat
	paused.turn_flags = saved.flags
	paused.played = saved.played
	paused.hacking = saved.hack
	for q in state.players: q.turn_flags.prevent_all = prevention[q.seat]
	for c in permanents():
		if used.has(c.uid): c.flags.used = used[c.uid]
	state_changed.emit()
func check_win():
	if state.finished or simultaneous_depth > 0: return
	var alive = state.players.filter(func(p): return p.alive)
	if alive.size() <= 1: finish(alive[0] if alive.size() == 1 else null)
func finish(winner):
	if state.finished: return
	state.finished = true
	state.winner = winner
	game_over.emit(winner)

func option(p, prompt: String, choices: Array) -> int:
	var strings: Array[String] = []
	strings.assign(choices)
	return clampi(await dec(p).choose_option(p, prompt, strings), 0, strings.size() - 1)
func options(p, prompt: String, choices: Array, count: int) -> Array[int]:
	var strings: Array[String] = []
	strings.assign(choices)
	return await dec(p).choose_options(p, prompt, strings, count)

func simultaneous_loss(source, targets: Array, amounts: Array, card = null):
	# Prevention and elimination still happen immediately, but the group determines one winner.
	simultaneous_depth += 1
	for i in targets.size(): await damage(source, targets[i], amounts[i], card)
	simultaneous_depth -= 1
	check_win()

func transfer_to_discard(p, card) -> bool:
	var gaining = card.owner != p.seat
	if gaining and not can_acquire(p): return false
	if card in permanents(): leave_play(card)
	gain_owner(card, p)
	move(card, p.discard, "discard")
	if gaining: p.turn_flags.acquired = p.turn_flags.get("acquired", 0) + 1
	return true

func reveal(p, cards: Array):
	if not cards.is_empty():
		say("Seat %d reveals %s" % [p.seat, ", ".join(cards.map(func(c): return db().get_card(c.id).name))])

func resolve_triggers(pending: Array, stop_on_active_death: bool = true):
	var saved_busy = busy
	busy = true
	for trigger in pending:
		if trigger.get("card") != null: trigger.generation = play_versions.get(trigger.card.uid, 0)
	while not pending.is_empty() and not state.finished and (active().alive or not stop_on_active_death):
		pending = pending.filter(func(t): return t.get("card") == null or (t.generation == play_versions.get(t.card.uid, 0) and (t.card in state.center_row if t.get("row", false) else t.card in permanents())))
		if pending.is_empty(): break
		var index = 0
		var names = pending.map(func(t): return db().get_card(t.card.id).name if t.get("card") != null else t.name)
		if pending.size() > 1 and names.any(func(n): return n != names[0]) and not pending.all(func(t): return t.get("commutes", false)):
			index = await option(active(), "Choose next simultaneous effect", names)
		var trigger = pending.pop_at(index)
		await trigger.resolve.call()
	busy = saved_busy

# Shared bounded convenience action, used by local and remote humans.
func play_all(p, basics: bool = false):
	for action in BotPlayer.MAX_ACTIONS:
		var playable = p.hand.filter(func(c): return can_play(p, c) and (not basics or c.id in ["Hacking", "Damage"]))
		if playable.is_empty(): break
		await play_card(p, playable[0])
