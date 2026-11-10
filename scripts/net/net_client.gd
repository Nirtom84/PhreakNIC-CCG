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
func answer(id: String, value): transport.send({"t": "answer", "id": id, "value": value})
func _receive(raw: Dictionary):
	var message = NetTransport.normalize(raw)
	message_received.emit(message)
	match message.get("t"):
		"welcome":
			waiting.clear()
			for id in prompts.keys():
				prompts.erase(id)
				prompt_done.emit(id)
			seat = message.seat
			seats = message.seats
		"view":
			engine.state = NetView.apply(message.state)
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
		"choose_cards": value = RemoteDecider.wire_answer(data.kind, await ai.choose_cards(p, data.text, data.cards.map(prompt_card), data.min, data.max))
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
