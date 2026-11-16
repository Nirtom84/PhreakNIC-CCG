class_name NetClient
extends Node
signal view_changed
signal prompt(id, data)
signal prompt_done(id)
signal log(text)
signal event(data)
signal game_over
signal error(reason)
signal message_received(message)
var transport: NetTransport
var seat = -1
var seats: Array = []
var engine: GameEngine
var scripted = false
var can_act = false
var prompts: Dictionary = {}
var waiting: Dictionary = {}
var log_history: Array[String] = []
var actions_this_turn = 0
var last_turn = -1
var declined: Dictionary = {}
func _init():
	engine = GameEngine.new()
	add_child(engine)
func connect_to(endpoint: NetTransport, index: int, token: String, protocol_version: String = str(ProjectSettings.get_setting("application/config/version", ""))):
	bind_transport(endpoint)
	transport.send({"t": "hello", "seat": index, "token": token, "version": protocol_version})
func bind_transport(endpoint: NetTransport):
	if transport != null and transport.received.is_connected(_receive): transport.received.disconnect(_receive)
	transport = endpoint
	transport.received.connect(_receive)
	transport.closed.connect(func(): can_act = false)
func send_action(kind: String, uid = null, index = null):
	can_act = false
	var data = {"t": "action", "kind": kind}
	if uid != null: data.uid = uid
	if index != null: data.index = index
	transport.send(data)
func send_emote(id: int):
	if id >= 0 and id < 8 and transport != null: transport.send({"type": "emote", "id": id})
func answer(id: String, value): transport.send({"t": "answer", "id": id, "value": value})
func _receive(raw: Dictionary):
	var message = NetTransport.normalize(raw)
	if not message is Dictionary or not valid_message(message): return
	message_received.emit(message)
	match message.get("t"):
		"welcome":
			log_history.assign(message.get("log", []))
			waiting.clear()
			for id in prompts.keys():
				prompts.erase(id)
				prompt_done.emit(id)
			seat = message.seat
			seats = message.seats
		"view":
			var state = NetView.apply(message.state)
			if state == null: return
			engine.state = state
			engine.deciders.clear()
			for p in engine.state.players: engine.deciders.append(BotDecider.new(engine, 1))
			can_act = message.state.ready
			view_changed.emit()
		"prompt":
			prompts[message.id] = message
			prompt.emit(message.id, message)
			if scripted: _answer_scripted(message)
		"prompt_done":
			prompts.erase(message.id)
			prompt_done.emit(message.id)
		"log":
			log_history.append(str(message.text))
			if log_history.size() > 400: log_history.pop_front()
			log.emit(message.text)
		"event":
			if message.kind == "waiting": waiting[int(message.seat)] = message
			elif message.kind == "waiting_done": waiting.erase(int(message.seat))
			event.emit(message)
		"game_over": game_over.emit()
		"error": error.emit(message.reason)
static func valid_card(data) -> bool:
	if not data is Dictionary or not data.get("id") is String: return false
	for key in ["uid", "owner", "controller", "counters"]:
		if not data.get(key) is int: return false
	if data.owner < -1 or data.owner >= 4 or data.controller < -1 or data.controller >= 4 or data.counters < 0: return false
	return true
static func valid_seats(value) -> bool:
	if not value is Array or value.size() < 2 or value.size() > 4: return false
	for info in value:
		if not info is Dictionary: return false
		for key in ["name"]:
			if not info.get(key) is String: return false
		if info.has("hero") and not info.hero is String: return false
		if not info.get("bot") is bool or not info.get("difficulty") is int or info.difficulty < -1 or info.difficulty > 3: return false
		if info.has("connected") and not info.connected is bool: return false
		if info.has("deck") and info.deck != null:
			if not info.deck is Dictionary or not info.deck.get("name") is String or not info.deck.get("count") is int: return false
	return true
static func valid_room(data: Dictionary, listing: bool = false) -> bool:
	if not valid_seats(data.get("seats")) or not data.get("code") is String or not OnlineAPI.valid_code(data.code): return false
	if not data.get("card_pool") is String or data.card_pool not in ["2025", "2026", "2026mog", "custom"]: return false
	if not data.get("starting_life") is int or data.starting_life < 0 or data.starting_life > 10000: return false
	if data.has("bot_pace") and not (data.bot_pace is int or data.bot_pace is float): return false
	if data.has("banned") and (not data.banned is Array or not data.banned.all(func(v): return v is String)): return false
	if data.has("deck_roll") and not data.deck_roll is Array: return false
	if listing: return data.get("host") is String and data.get("banned_count", 0) is int
	return data.get("host_seat") is int and data.host_seat >= 0 and data.host_seat < data.seats.size() and data.get("started") is bool and data.get("public") is bool
static func valid_timer(value) -> bool:
	if not value is Dictionary or not value.get("seat") is int or value.seat < 0 or value.seat >= 4 or not value.get("kind") is String: return false
	for field in ["remaining_seconds", "limit"]:
		if not (value.get(field) is int or value.get(field) is float) or not is_finite(float(value[field])) or value[field] < 0: return false
	if value.has("host_seat") and (not value.host_seat is int or value.host_seat < 0 or value.host_seat >= 4): return false
	return not value.has("handable") or value.handable is bool
func valid_event(data: Dictionary) -> bool:
	if not data.get("kind") is String: return false
	var count = engine.state.players.size() if engine.state != null else 4
	if data.kind in ["waiting", "waiting_done", "damage_taken", "life_gained", "purchase_paid", "removed", "idle_warning", "soundtrack", "turn_started", "turn_ended", "played", "bought", "reserved", "eliminated"]:
		if not data.get("seat") is int or data.seat < (-1 if data.kind == "removed" else 0) or data.seat >= count: return false
	if data.kind == "damage_dealt":
		if not data.get("source") is int or data.source < -1 or data.source >= count or not data.get("target") is int or data.target < 0 or data.target >= count: return false
	if data.kind in ["damage_dealt", "damage_taken", "life_gained"] and not data.get("amount") is int: return false
	if data.kind == "purchase_paid" and not data.get("cost") is int: return false
	if data.kind in ["played", "bought", "reserved", "purchase_paid"] and not data.get("id") is String: return false
	if data.kind == "waiting" and not data.get("text") is String: return false
	if data.kind == "soundtrack" and not data.get("cue") is String: return false
	return true
func valid_message(data: Dictionary) -> bool:
	if data.get("type") == "emote": return data.size() == 3 and data.get("seat") is int and data.seat >= 0 and data.seat < 4 and data.get("id") is int and data.id >= 0 and data.id < 8
	if not data.get("t") is String: return false
	match data.t:
		"welcome":
			return data.get("seat") is int and valid_seats(data.get("seats")) and data.seat >= 0 and data.seat < data.seats.size() and data.get("log", []) is Array and data.get("log", []).all(func(v): return v is String)
		"timers": return data.get("timers") is Array and data.timers.size() <= 8 and data.timers.all(valid_timer)
		"view": return data.get("state") is Dictionary and data.state.get("ready") is bool and data.get("timers", []) is Array and data.get("timers", []).all(valid_timer)
		"room": return valid_room(data)
		"prompt_done": return data.get("id") is String
		"log": return data.get("text") is String
		"error": return data.get("reason") is String
		"event": return valid_event(data)
		"game_over":
			if not data.get("winner", -1) is int or data.get("winner", -1) < -1 or data.get("winner", -1) >= 4: return false
			return data.get("final_players", []) is Array and data.get("final_players", []).all(func(v): return v is Dictionary and v.get("life") is int and v.get("deck_size") is int)
		"prompt":
			if data.has("remaining_seconds") and not (data.remaining_seconds is int or data.remaining_seconds is float): return false
			if not data.get("id") is String or not data.get("kind") is String or not data.get("text") is String: return false
			if scripted and (engine.state == null or seat < 0 or seat >= engine.state.players.size()): return false
			match data.kind:
				"choose_option", "choose_options":
					return data.get("options") is Array and data.options.all(func(v): return v is String) and (data.kind == "choose_option" or data.get("count") is int)
				"choose_cards": return data.get("cards") is Array and data.cards.all(valid_card) and data.get("min") is int and data.get("max") is int
				"choose_player": return data.get("players") is Array and data.players.all(func(v): return v is int and v >= 0 and engine.state != null and v < engine.state.players.size())
				"choose_number": return data.get("allowed") is Array and data.allowed.all(func(v): return v is int)
				"allocate_prevention":
					return data.get("amount") is int and data.get("sources") is Array and data.sources.all(func(v): return v is Dictionary and (v.get("card") == null or valid_card(v.card)) and v.get("capacity") is int and v.get("full") is bool and v.get("name", "") is String)
				"name_a_card": return data.get("card_pool") is String
				"confirm": return true
			return false
	return true
static func prompt_card(data):
	if data == null: return null
	var card = CardInstance.new(data.uid, data.id, data.owner)
	card.controller = data.controller
	card.counters = data.counters
	return card
func _answer_scripted(data: Dictionary):
	# Only prompt payload and mirror are available here. No server reference.
	if engine.state == null: return
	var p = engine.state.players[seat]
	var ai = BotDecider.new(engine, 1)
	var value
	var options: Array[String] = []
	match data.kind:
		"choose_option", "choose_options":
			options.assign(data.options)
			if data.kind == "choose_option": value = await ai.choose_option(p, data.text, options)
			else: value = await ai.choose_options(p, data.text, options, data.count)
		"choose_cards":
			# The bot decides from this client's mirror, which can lag the prompt (a start-of-turn prompt arrives
			# before the new view). An out-of-range pick would be refused and leave the prompt to the 45 s fallback.
			var offered = data.cards.map(prompt_card)
			var picked = await ai.choose_cards(p, data.text, offered, data.min, data.max)
			if picked.size() < data.min or picked.size() > data.max or picked.any(func(c): return c not in offered):
				picked = offered.slice(0, data.min)
			value = RemoteDecider.wire_answer(data.kind, picked)
		"choose_player": value = RemoteDecider.wire_answer(data.kind, await ai.choose_player(p, data.text, data.players.map(func(i): return engine.state.players[i])))
		"choose_number":
			var allowed: Array[int] = []
			allowed.assign(data.allowed)
			value = await ai.choose_number(p, data.text, allowed)
		"confirm": value = await ai.confirm(p, data.text)
		"name_a_card": value = await ai.name_a_card(p, data.text)
		"allocate_prevention":
			var sources = []
			for entry in data.sources:
				var source = entry.duplicate()
				source.card = prompt_card(entry.card)
				sources.append(source)
			value = await ai.allocate_prevention(p, data.amount, sources)
	answer(data.id, value)
func _process(_delta):
	if not scripted or not can_act or engine.state == null or seat < 0 or not prompts.is_empty(): return
	var p = engine.state.players[seat]
	if not engine.is_turn(p): return
	if last_turn != engine.state.turn:
		last_turn = engine.state.turn
		actions_this_turn = 0
		declined.clear()
	actions_this_turn += 1
	if actions_this_turn >= BotPlayer.MAX_ACTIONS: send_action("end_turn"); return
	var ai = engine.dec(p)
	var policy = BotPlayer.new(engine)
	var candidates = p.hand.filter(func(c): return engine.can_play(p, c))
	for c in engine.permanents():
		for ability in engine.activatable_abilities(p, c):
			var key = "%d:%d" % [c.uid, ability.index]
			if not ability.enabled or declined.has(key): continue
			if ability.cost > 0 and (not candidates.is_empty() or policy.want_buy(p)): continue
			# Bound repeat activations without mutating the mirror with rules.
			declined[key] = true
			send_action("activate", c.uid, ability.index)
			return
	if not candidates.is_empty():
		candidates.sort_custom(func(a, b): return policy.play_priority(p, a) > policy.play_priority(p, b))
		send_action("play", candidates[0].uid)
		return
	var buys = (engine.state.center_row + p.reserve).filter(func(c): return c != null and engine.can_buy(p, c))
	buys.sort_custom(func(a, b): return ai.value(a, p) > ai.value(b, p))
	if not buys.is_empty() and ai.value(buys[0], p) >= 0.5:
		send_action("buy", buys[0].uid)
		return
	send_action("end_turn")
