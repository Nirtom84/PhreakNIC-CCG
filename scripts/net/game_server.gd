class_name GameServer
extends Node
signal snapshot(data: Dictionary)
signal diagnostic(text: String)
class Decision extends RefCounted:
	signal done(value)
var setup_error = ""
var engine: GameEngine
var seats: Array = []
var tokens: Array = []
var connections: Dictionary = {}
var authenticated: Dictionary = {}
var disconnected: Dictionary = {}
var pending: Dictionary = {}
var clock: Callable = func(): return Time.get_ticks_msec() / 1000.0
var dirty = false
var running = false
var locks: Dictionary = {}
var driving: Dictionary = {}
var view_frames: Dictionary = {}
var last_snapshot: Dictionary = {}
var idle_at = 0.0
var idle_warned = false
var idle_turn = -1
var idle_seat = -1
var idle_streak: Dictionary = {}
var idle_bot: Dictionary = {}
var permanent_idle: Dictionary = {}
var announced_dead: Dictionary = {}
# Diagnostics: one line per notable server event, printed to stdout and forwarded over the room link.
# Never includes card identities, hands or deck contents; only seats, prompt kinds, sizes and timings.
var room_label = ""
var diag_budget: Dictionary = {}
var taken_over: Dictionary = {}
func diag(text: String, key: String = ""):
	if key != "":
		var minute = int(Time.get_ticks_msec() / 60000)
		var entry = diag_budget.get(key, [minute, 0])
		if entry[0] != minute: entry = [minute, 0]
		entry[1] += 1
		diag_budget[key] = entry
		var budget = 60 if key.begins_with("action:") else 20
		if entry[1] > budget: return
		if entry[1] == budget: text += " (further '%s' lines muted this minute)" % key
	var turn = engine.state.turn if engine != null and engine.state != null else 0
	print("room %s t%d %s" % [room_label, turn, text])
	diagnostic.emit("t%d %s" % [turn, text])
func why_not(seat: int) -> String:
	var reasons = []
	if not running: reasons.append("game not running")
	if idle_bot.has(seat): reasons.append("bot is finishing an idle turn")
	if permanent_idle.has(seat): reasons.append("seat handed to a bot after repeated idling")
	if engine.state != null and not engine.is_turn(engine.state.players[seat]): reasons.append("not their turn (active seat %d, reaction depth %d)" % [engine.state.active_seat, engine.reaction_depth])
	if engine.busy: reasons.append("engine busy resolving")
	if locks.has(engine.reaction_depth): reasons.append("locked at reaction depth %d" % engine.reaction_depth)
	for id in pending:
		if pending[id].seat == seat: reasons.append("own %s prompt %s pending for %.1fs" % [pending[id].data.kind, id.left(6), now() - pending[id].at])
	return ", ".join(reasons) if not reasons.is_empty() else "unknown"
func prompt_shape(data: Dictionary) -> String:
	var parts = [str(data.get("kind", "?"))]
	for key in ["options", "cards", "players", "allowed", "sources"]:
		if data.get(key) is Array: parts.append("%s=%d" % [key, data[key].size()])
	for key in ["min", "max", "count", "amount"]:
		if data.has(key): parts.append("%s=%s" % [key, str(data[key])])
	return " ".join(parts)
func value_shape(value) -> String:
	if value is Array: return "array[%d]" % value.size()
	return type_string(typeof(value))
func version() -> String: return str(ProjectSettings.get_setting("application/config/version", ""))
func now() -> float: return float(clock.call())
func setup(config: Array, card_pool: String = "2026", starting_life: int = 0, seed_value: int = 1, banned: Array = []) -> bool:
	assert(config.size() >= 2 and config.size() <= 4)
	setup_error = ""
	if not get_node("/root/CardDB").bans_valid(banned, card_pool):
		setup_error = "At least 40 center-deck cards must remain."
		return false
	seats = []
	for info in config:
		seats.append({"name": str(info.get("name", "Bot" if info.get("bot", false) else "Seat %d" % seats.size())), "hero": str(info.get("hero", "")), "bot": bool(info.get("bot", false)), "difficulty": int(info.get("difficulty", 1))})
	_pick_bot_names(card_pool)
	var levels = []
	for i in seats.size():
		var info = seats[i]
		info.difficulty = clampi(int(info.difficulty), 0, 2)
		levels.append(info.difficulty if info.bot else -1)
		tokens.append(Crypto.new().generate_random_bytes(24).hex_encode())
		disconnected[i] = now()
	_install_engine()
	var choices = []
	for i in seats.size(): choices.append(BotDecider.new(engine, seats[i].difficulty) if seats[i].bot else RemoteDecider.new(self, i))
	return engine.setup(levels, seed_value, choices, card_pool, starting_life, banned)
func _pick_bot_names(card_pool: String):
	var db = get_node("/root/CardDB").catalog(card_pool)
	var used_names = []
	var used_ids = []
	for info in seats:
		if not info.bot or info.name not in ["", "Bot"]:
			used_names.append(info.name.to_lower())
			used_ids.append(info.hero)
	var heroes = []
	var names = []
	for id in db.pool_ids(card_pool):
		var card = db.cards[id]
		var title = str(card.name).to_lower()
		if not card.get("starter", false) and db.has_subtype(id, "Hero") and title not in used_names and id not in used_ids and title not in names:
			heroes.append(id)
			names.append(title)
	for info in seats:
		if info.bot and info.name in ["", "Bot"] and not heroes.is_empty():
			var id = heroes.pop_at(GameEngine.crypto_int(heroes.size()))
			info.name = str(db.cards[id].name)
			info.hero = id
func _waiting(seat: int, done: bool = false):
	for other in connections:
		if other != seat:
			var data = {"t": "event", "kind": "waiting_done" if done else "waiting", "seat": seat}
			if not done: data.text = seats[seat].name + " is choosing…"
			_send(other, data)
func _install_engine():
	engine = GameEngine.new()
	engine.secure_random = true
	add_child(engine)
	engine.turn_driver = _drive_reaction
	engine.state_changed.connect(func(): dirty = true; _eliminations())
	engine.log_message.connect(func(text): _broadcast({"t": "log", "text": text, "seat": engine.state.active_seat}))
	engine.damage_dealt.connect(func(p, q, amount): _event({"kind": "damage_dealt", "source": p.seat, "target": q.seat, "amount": amount}))
	engine.turn_started.connect(_turn_started)
	engine.turn_ended.connect(func(p): _event({"kind": "turn_ended", "seat": p.seat}))
	engine.ice_counter_removed.connect(func(c): _event({"kind": "ice_counter_removed", "uid": c.uid}))
	engine.card_moved.connect(_moved)
	engine.card_played.connect(func(p, c): _event({"kind": "played", "seat": p.seat, "uid": c.uid, "id": c.id}))
	engine.card_bought.connect(func(p, c): _event({"kind": "bought", "seat": p.seat, "uid": c.uid, "id": c.id}))
	engine.card_reserved.connect(func(p, c): _event({"kind": "reserved", "seat": p.seat, "uid": c.uid, "id": c.id}))
	engine.game_over.connect(func(winner): dirty = true; _broadcast({"t": "game_over", "winner": winner.seat if winner != null else -1}))
func start():
	running = true
	await engine.start_turn()
	dirty = true
	_checkpoint()
func attach(transport: NetTransport):
	transport.received.connect(func(message):
		if NetTransport.safe_value(message): _receive(transport, NetTransport.normalize(message)))
	transport.closed.connect(func(): _closed(transport))
func _send(seat: int, message: Dictionary):
	if connections.has(seat): connections[seat].send(message)
func _broadcast(message: Dictionary):
	for seat in connections: _send(seat, message)
func _event(data: Dictionary):
	data.t = "event"
	_broadcast(data)
func _moved(card, _origin: String, destination: String):
	dirty = true
	# Never broadcast identities entering hidden zones (including reshuffles).
	if destination == "hand":
		# Control changes can leave an attachment with its original owner.
		# Visibility follows the receiving hand, never the owner metadata.
		for p in engine.state.players:
			if card in p.hand:
				_send(p.seat, {"t": "event", "kind": "draw", "seat": p.seat, "uid": card.uid, "id": card.id})
				break
func _eliminations():
	for p in engine.state.players:
		if not p.alive and not announced_dead.has(p.seat):
			announced_dead[p.seat] = true
			_event({"kind": "eliminated", "seat": p.seat})
func _closed(transport):
	if not authenticated.has(transport): return
	var seat = authenticated[transport]
	authenticated.erase(transport)
	view_frames.erase(transport)
	if connections.get(seat) == transport:
		connections.erase(seat)
		disconnected[seat] = now()
		diag("seat %d disconnected" % seat)
func _error(transport, reason: String):
	var seat = authenticated.get(transport, -1)
	diag("seat %d refused: %s" % [seat, reason], "error:%d" % seat)
	transport.send({"t": "error", "reason": reason})
func _receive(transport, message: Dictionary):
	if not NetTransport.safe_value(message) or not message.get("t") is String: return
	if message.get("t") == "hello":
		if not message.get("version") is String or message.version != version(): _error(transport, "version mismatch"); return
		var seat = message.get("seat")
		if not seat is int or seat < 0 or seat >= seats.size() or seats[seat].bot or not message.get("token") is String or message.token != tokens[seat]:
			_error(transport, "invalid credentials"); return
		if authenticated.has(transport) and authenticated[transport] != seat: _error(transport, "already authenticated"); return
		var replaced = connections.has(seat) and connections[seat] != transport
		if replaced: connections[seat].close()
		diag("seat %d connected%s; %d prompt(s) pending for it" % [seat, " (replaced older socket)" if replaced else "", pending.values().filter(func(r): return r.seat == seat).size()])
		connections[seat] = transport
		authenticated[transport] = seat
		disconnected.erase(seat)
		engine.deciders[seat] = BotDecider.new(engine, 1) if _takeover(seat) else RemoteDecider.new(self, seat)
		engine.state.players[seat].difficulty = 1 if _takeover(seat) else -1
		_send(seat, {"t": "welcome", "seat": seat, "seats": seats, "version": version(), "card_pool": engine.state.card_pool, "starting_life": engine.state.starting_life})
		_view(seat)
		for id in pending:
			if pending[id].seat == seat: _send(seat, pending[id].data)
			else: _send(seat, {"t": "event", "kind": "waiting", "seat": pending[id].seat, "text": seats[pending[id].seat].name + " is choosing…"})
		if engine.state.finished: _send(seat, {"t": "game_over", "winner": engine.state.winner.seat if engine.state.winner != null else -1})
		return
	if not authenticated.has(transport): _error(transport, "hello required"); return
	var seat = authenticated[transport]
	if message.get("t") == "answer":
		var id = message.get("id")
		if not id is String or not pending.has(id) or pending[id].seat != seat:
			_error(transport, "unknown prompt"); return
		var request = pending[id]
		if not RemoteDecider.valid(request.data, message.get("value"), engine.db()):
			diag("seat %d invalid answer to %s: got %s" % [seat, prompt_shape(request.data), value_shape(message.get("value"))], "answer:%d" % seat)
			_error(transport, "invalid answer"); return
		idle_at = now()
		idle_warned = false
		_complete(id, message.value)
	elif message.get("t") == "action":
		_action(transport, seat, message)
	else: _error(transport, "unknown message")
func available(seat: int) -> bool:
	return not idle_bot.has(seat) and not permanent_idle.has(seat) and running and engine.is_turn(engine.state.players[seat]) and not engine.busy and not locks.has(engine.reaction_depth) and not pending.values().any(func(r): return r.seat == seat)
func _action(transport, seat: int, message: Dictionary):
	if not available(seat):
		diag("seat %d action %s refused: %s" % [seat, str(message.get("kind", "?")), why_not(seat)], "act:%d" % seat)
		_error(transport, "seat cannot act now"); return
	var p = engine.state.players[seat]
	var card = null
	if message.has("uid"):
		if not message.uid is int: _error(transport, "invalid uid"); return
		for c in p.hand + p.reserve + engine.state.center_row + engine.permanents():
			if c != null and c.uid == message.uid: card = c; break
	var kind = message.get("kind", "")
	var index = message.get("index", 0)
	var legal = false
	match kind:
		"play": legal = card != null and engine.can_play(p, card)
		"buy": legal = card != null and engine.can_buy(p, card)
		"reserve": legal = card != null and engine.can_reserve(p, card)
		"activate": legal = card != null and index is int and engine.activatable_abilities(p, card).any(func(a): return a.index == index and a.enabled)
		"end_turn", "play_all", "play_basics": legal = true
	if not legal: _error(transport, "illegal action"); return
	diag("seat %d action %s" % [seat, kind], "action:%d" % seat)
	idle_at = now()
	idle_warned = false
	var depth = engine.reaction_depth
	locks[depth] = true
	match kind:
		"play": await engine.play_card(p, card)
		"buy": await engine.buy_card(p, card)
		"reserve": engine.reserve_card(p, card)
		"activate": await engine.activate(p, card, index)
		"end_turn": await engine.end_turn(p)
		"play_all", "play_basics": await engine.play_all(p, kind == "play_basics")
	locks.erase(depth)
	dirty = true
	_checkpoint()
func ask(seat: int, data: Dictionary, args: Array):
	var id = Crypto.new().generate_random_bytes(16).hex_encode()
	data = data.duplicate(true)
	data.t = "prompt"
	data.id = id
	var decision = Decision.new()
	pending[id] = {"seat": seat, "data": data, "args": args, "at": now(), "decision": decision}
	diag("seat %d prompt %s sent: %s%s" % [seat, id.left(6), prompt_shape(data), "" if connections.has(seat) else " (seat offline)"])
	dirty = true
	_send(seat, data)
	_waiting(seat)
	return await decision.done
func _complete(id: String, value, how: String = "answered"):
	var request = pending[id]
	pending.erase(id)
	diag("seat %d prompt %s %s after %.1fs" % [request.seat, id.left(6), how, now() - request.at])
	_waiting(request.seat, true)
	_send(request.seat, {"t": "prompt_done", "id": id})
	request.decision.done.emit(value)
func _fallback(id: String):
	if not pending.has(id) or pending[id].get("falling_back", false): return
	var request = pending[id]
	request.falling_back = true
	var answer = await BotDecider.new(engine, 1).callv(request.data.kind, request.args)
	if pending.has(id): _complete(id, RemoteDecider.wire_answer(request.data.kind, answer), "auto-answered by bot (%s)" % ("seat taken over" if _takeover(request.seat) else "45 s timeout"))
func _takeover(seat: int) -> bool:
	return permanent_idle.has(seat) or idle_bot.has(seat) or (not seats[seat].bot and disconnected.has(seat) and now() - disconnected[seat] >= 120.0)
func _process(_delta):
	if engine == null or not running: return
	_idle_tick()
	for id in pending.keys():
		if now() - pending[id].at >= 45.0 or _takeover(pending[id].seat): _fallback(id)
	for seat in seats.size():
		if _takeover(seat):
			if not taken_over.has(seat):
				taken_over[seat] = true
				diag("seat %d handed to a bot: %s" % [seat, "repeated idling" if permanent_idle.has(seat) else "idle turn" if idle_bot.has(seat) else "disconnected for 120 s"])
			engine.deciders[seat] = BotDecider.new(engine, 1)
			engine.state.players[seat].difficulty = 1
		elif taken_over.has(seat):
			taken_over.erase(seat)
			diag("seat %d back under human control" % seat)
	if dirty:
		dirty = false
		for seat in connections: _view(seat)
	if not driving.has(engine.reaction_depth) and not engine.busy and not engine.state.finished and not locks.has(engine.reaction_depth):
		var p = engine.active()
		if seats[p.seat].bot or _takeover(p.seat): _drive()
func _turn_started(p):
	diag("turn start seat %d (%s%s)" % [p.seat, "bot" if seats[p.seat].bot else "human", "" if seats[p.seat].bot or connections.has(p.seat) else ", offline"] if engine.reaction_depth == 0 else "reaction turn seat %d at depth %d" % [p.seat, engine.reaction_depth])
	_event({"kind": "turn_started", "seat": p.seat})
	if engine.reaction_depth == 0: _begin_idle_turn(p)
func _begin_idle_turn(p):
	if idle_seat >= 0 and not idle_bot.has(idle_seat) and not permanent_idle.has(idle_seat): idle_streak[idle_seat] = 0
	for seat in idle_bot:
		if not permanent_idle.has(seat):
			engine.deciders[seat] = RemoteDecider.new(self, seat)
			engine.state.players[seat].difficulty = -1
	idle_bot.clear()
	idle_turn = engine.state.turn
	idle_seat = p.seat
	idle_at = now()
	idle_warned = false
func _idle_tick():
	if engine.reaction_depth > 0:
		idle_at = now()
		return
	var p = engine.active()
	if idle_turn != engine.state.turn or idle_seat != p.seat: _begin_idle_turn(p)
	if engine.state.finished or seats[p.seat].bot or not connections.has(p.seat) or _takeover(p.seat): return
	if engine.busy or not pending.is_empty() or not locks.is_empty():
		idle_at = now()
		return
	var elapsed = now() - idle_at
	if elapsed >= 120 and not idle_warned:
		idle_warned = true
		diag("seat %d idle warning after %.0fs" % [p.seat, elapsed])
		_send(p.seat, {"t": "event", "kind": "idle_warning", "seconds_left": 60})
	if elapsed >= 180:
		idle_streak[p.seat] = idle_streak.get(p.seat, 0) + 1
		idle_bot[p.seat] = true
		if idle_streak[p.seat] >= 3: permanent_idle[p.seat] = true
		diag("seat %d idle for %.0fs; bot finishes the turn (streak %d%s)" % [p.seat, elapsed, idle_streak[p.seat], ", seat now bot-controlled" if permanent_idle.has(p.seat) else ""])
		engine.say(seats[p.seat].name + " was idle; a bot finished their turn")
func _drive_reaction(p):
	var driver = BotPlayer.new(engine)
	driver.action_completed = _checkpoint
	await driver.take_turn(p)
func _drive():
	var depth = engine.reaction_depth
	driving[depth] = true
	var p = engine.active()
	var driver = BotPlayer.new(engine)
	driver.action_completed = _checkpoint
	driver.continue_turn = func(): return seats[p.seat].bot or _takeover(p.seat)
	await driver.take_turn(p)
	driving.erase(depth)
	dirty = true
	_checkpoint()
func _checkpoint():
	if not pending.is_empty() or not locks.is_empty() or engine.busy or engine.reaction_depth != 0 or engine.simultaneous_depth != 0 or not engine.state.resolving.is_empty(): return
	if not engine.state.finished and not SaveGame.safe(engine, engine.state.active_seat): return
	engine.trim_log()
	last_snapshot = {"version": version(), "content": SaveGame.content(), "game": SaveGame.snapshot(engine.state), "seats": seats.duplicate(true), "tokens": tokens.duplicate()}
	snapshot.emit(last_snapshot.duplicate(true))
func restore(data: Dictionary) -> bool:
	if not SaveGame.bounded(data) or not data.get("version") is String or not data.get("content") is String or not data.get("game") is Dictionary: return false
	if data.version != version() or data.content != SaveGame.content(): return false
	var restored = SaveGame.restore(data.get("game", {}))
	if restored == null or not restored.resolving.is_empty() or not data.get("seats") is Array or not data.get("tokens") is Array: return false
	if data.seats.size() != restored.players.size() or data.tokens.size() != restored.players.size(): return false
	for i in data.seats.size():
		if not data.seats[i] is Dictionary or not data.tokens[i] is String: return false
		if not data.seats[i].get("name") is String or not data.seats[i].get("hero") is String or not data.seats[i].get("bot") is bool: return false
		if not data.seats[i].get("difficulty") is int or data.seats[i].difficulty < 0 or data.seats[i].difficulty > 2: return false
		for key in ["name", "hero", "bot", "difficulty"]:
			if not data.seats[i].has(key): return false
	seats = data.seats.duplicate(true)
	tokens = data.tokens.duplicate()
	_install_engine()
	engine.state = restored
	engine.trim_log()
	for i in seats.size():
		engine.deciders.append(BotDecider.new(engine, seats[i].difficulty) if seats[i].bot else RemoteDecider.new(self, i))
		disconnected[i] = now()
		if not restored.players[i].alive: announced_dead[i] = true
	running = true
	dirty = true
	last_snapshot = data.duplicate(true)
	return true

func _view(seat: int):
	var frame = Engine.get_process_frames()
	var endpoint = connections.get(seat)
	if view_frames.get(endpoint, -1) == frame:
		dirty = true
		return
	view_frames[endpoint] = frame
	var view = NetView.build(engine, seat)
	view.ready = available(seat)
	_send(seat, {"t": "view", "state": view})
