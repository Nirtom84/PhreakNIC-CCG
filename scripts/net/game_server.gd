class_name GameServer
extends Node
signal snapshot(data: Dictionary)
class Decision extends RefCounted:
	signal done(value)
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
var announced_dead: Dictionary = {}
func version() -> String: return str(ProjectSettings.get_setting("application/config/version", ""))
func now() -> float: return float(clock.call())
func setup(config: Array, card_pool: String = "2026", starting_life: int = 0, seed_value: int = 1):
	assert(config.size() >= 2 and config.size() <= 4)
	seats = []
	for info in config:
		seats.append({"name": str(info.get("name", "Seat %d" % seats.size())), "hero": str(info.get("hero", "")), "bot": bool(info.get("bot", false)), "difficulty": int(info.get("difficulty", 1))})
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
	engine.setup(levels, seed_value, choices, card_pool, starting_life)
func _install_engine():
	engine = GameEngine.new()
	add_child(engine)
	engine.turn_driver = _drive_reaction
	engine.state_changed.connect(func(): dirty = true; _eliminations())
	engine.log_message.connect(func(text): _broadcast({"t": "log", "text": text, "seat": engine.state.active_seat}))
	engine.damage_dealt.connect(func(p, q, amount): _event({"kind": "damage_dealt", "source": p.seat, "target": q.seat, "amount": amount}))
	engine.turn_started.connect(func(p): _event({"kind": "turn_started", "seat": p.seat}))
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
	transport.received.connect(func(message): _receive(transport, NetTransport.normalize(message)))
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
func _error(transport, reason: String): transport.send({"t": "error", "reason": reason})
func _receive(transport, message: Dictionary):
	if message.get("t") == "hello":
		if message.get("version") != version(): _error(transport, "version mismatch"); return
		var seat = message.get("seat")
		if not seat is int or seat < 0 or seat >= seats.size() or seats[seat].bot or message.get("token") != tokens[seat]:
			_error(transport, "invalid credentials"); return
		if authenticated.has(transport) and authenticated[transport] != seat: _error(transport, "already authenticated"); return
		if connections.has(seat) and connections[seat] != transport: connections[seat].close()
		connections[seat] = transport
		authenticated[transport] = seat
		disconnected.erase(seat)
		engine.deciders[seat] = RemoteDecider.new(self, seat)
		engine.state.players[seat].difficulty = -1
		_send(seat, {"t": "welcome", "seat": seat, "seats": seats, "version": version(), "card_pool": engine.state.card_pool, "starting_life": engine.state.starting_life})
		_view(seat)
		for id in pending:
			if pending[id].seat == seat: _send(seat, pending[id].data)
		if engine.state.finished: _send(seat, {"t": "game_over", "winner": engine.state.winner.seat if engine.state.winner != null else -1})
		return
	if not authenticated.has(transport): _error(transport, "hello required"); return
	var seat = authenticated[transport]
	if message.get("t") == "answer":
		var id = message.get("id")
		if not id is String or not pending.has(id) or pending[id].seat != seat:
			_error(transport, "unknown prompt"); return
		var request = pending[id]
		if not RemoteDecider.valid(request.data, message.get("value"), engine.db()): _error(transport, "invalid answer"); return
		_complete(id, message.value)
	elif message.get("t") == "action":
		_action(transport, seat, message)
	else: _error(transport, "unknown message")
func available(seat: int) -> bool:
	return running and engine.is_turn(engine.state.players[seat]) and not engine.busy and not locks.has(engine.reaction_depth) and not pending.values().any(func(r): return r.seat == seat)
func _action(transport, seat: int, message: Dictionary):
	if not available(seat): _error(transport, "seat cannot act now"); return
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
	dirty = true
	_send(seat, data)
	return await decision.done
func _complete(id: String, value):
	var request = pending[id]
	pending.erase(id)
	_send(request.seat, {"t": "prompt_done", "id": id})
	request.decision.done.emit(value)
func _fallback(id: String):
	if not pending.has(id): return
	var request = pending[id]
	var answer = await BotDecider.new(engine, 1).callv(request.data.kind, request.args)
	if pending.has(id): _complete(id, RemoteDecider.wire_answer(request.data.kind, answer))
func _takeover(seat: int) -> bool:
	return not seats[seat].bot and disconnected.has(seat) and now() - disconnected[seat] >= 120.0
func _process(_delta):
	if engine == null or not running: return
	for id in pending.keys():
		if now() - pending[id].at >= 45.0 or _takeover(pending[id].seat): _fallback(id)
	for seat in seats.size():
		if _takeover(seat):
			engine.deciders[seat] = BotDecider.new(engine, 1)
			engine.state.players[seat].difficulty = 1
	if dirty:
		dirty = false
		for seat in connections: _view(seat)
	if not driving.has(engine.reaction_depth) and not engine.busy and not engine.state.finished and not locks.has(engine.reaction_depth):
		var p = engine.active()
		if seats[p.seat].bot or _takeover(p.seat): _drive()
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
	last_snapshot = {"version": version(), "content": SaveGame.content(), "game": SaveGame.snapshot(engine.state), "seats": seats.duplicate(true), "tokens": tokens.duplicate()}
	snapshot.emit(last_snapshot.duplicate(true))
func restore(data: Dictionary) -> bool:
	if data.get("version") != version() or data.get("content") != SaveGame.content(): return false
	var restored = SaveGame.restore(data.get("game", {}))
	if restored == null or not restored.resolving.is_empty() or not data.get("seats") is Array or not data.get("tokens") is Array: return false
	if data.seats.size() != restored.players.size() or data.tokens.size() != restored.players.size(): return false
	for i in data.seats.size():
		if not data.seats[i] is Dictionary or not data.tokens[i] is String: return false
		for key in ["name", "hero", "bot", "difficulty"]:
			if not data.seats[i].has(key): return false
	seats = data.seats.duplicate(true)
	tokens = data.tokens.duplicate()
	_install_engine()
	engine.state = restored
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
