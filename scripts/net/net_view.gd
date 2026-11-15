class_name NetView
extends SaveGame
# The object codec preserves object-valued flags and dictionary keys. Only this
# explicit public field list is encoded, never the authoritative save envelope.
const PUBLIC_STATE = ["starting_life", "card_pool", "custom_deck", "banned", "players", "center_deck", "center_row", "removed", "resolving", "active_seat", "turn", "finished", "winner"]
var visible: Array = []
var masks: Dictionary = {}
static func hidden_cards(count: int) -> Array:
	var result = []
	for i in count:
		# Independent entropy, never the game's seeded RNG. Negative IDs cannot
		# collide with authoritative action targets.
		var bytes = Crypto.new().generate_random_bytes(6)
		var serial = 0
		for byte in bytes: serial = (serial << 8) | byte
		result.append(CardInstance.new(-1 - serial, "hidden"))
	return result
func encode(value):
	if value is CardInstance and value.id != "hidden" and value not in visible:
		if not masks.has(value): masks[value] = hidden_cards(1)[0]
		return super.encode(masks[value])
	return super.encode(value)
func expose(cards: Array):
	for card in cards:
		if card == null or card in visible: continue
		visible.append(card)
		expose(card.attached)
static func build(engine, seat: int) -> Dictionary:
	assert(seat >= 0 and seat < engine.state.players.size())
	var codec = NetView.new()
	var state = engine.state
	codec.expose(state.center_row + state.removed + state.resolving)
	for p in state.players:
		codec.expose(p.discard + p.play_area + p.reserve + p.played)
		if p.seat == seat: codec.expose(p.hand)
	# Encode player records explicitly so hidden physical zones always contain
	# placeholders, even when played[] still refers to a now reshuffled card.
	for p in state.players:
		codec.objects.append(p)
		codec.records.append({})
	for p in state.players:
		var data = {}
		for field in PLAYER_FIELDS:
			var value = p.get(field)
			if field == "deck" or (field == "hand" and p.seat != seat): value = hidden_cards(value.size())
			data[field] = codec.encode(value)
		codec.records[p.seat] = {"type": "player", "data": data}
	var data = {}
	for field in PUBLIC_STATE:
		if field == "custom_deck" and state.card_pool != "custom": continue
		data[field] = codec.encode(hidden_cards(state.center_deck.size()) if field == "center_deck" else state.get(field))
	return {"state": data, "objects": codec.records, "seat": seat, "ready": not engine.busy, "counts": {"center_deck": state.center_deck.size(), "players": state.players.map(func(p): return {"deck": p.deck.size(), "hand": p.hand.size()})}}
# NetClient installs this public state on a GameEngine, including its shared
# why_not_play / why_not_buy predicates; hidden cards never become buy targets.
static func apply(view: Dictionary) -> GameState:
	if not SaveGame.bounded(view) or not view.get("objects") is Array or not view.get("state") is Dictionary: return null
	var codec = SaveGame.new()
	for record in view.objects:
		if not record is Dictionary or record.get("type") not in ["card", "player"] or not record.get("data") is Dictionary: return null
		codec.objects.append(CardInstance.new() if record.type == "card" else PlayerState.new())
	for i in view.objects.size():
		var object = codec.objects[i]
		var fields = CARD_FIELDS if object is CardInstance else PLAYER_FIELDS
		for field in view.objects[i].data:
			if field not in fields: continue
			codec.valid = true
			var value = codec.decode(view.objects[i].data[field])
			if not codec.valid or typeof(value) != typeof(object.get(field)): return null
			if field in ["attached", "deck", "hand", "discard", "play_area", "reserve", "played"] and value.any(func(c): return not c is CardInstance): return null
			object.set(field, value)
	var state = GameState.new()
	for field in PUBLIC_STATE:
		if field == "custom_deck" and not view.state.has(field): continue
		if not view.state.has(field): return null
		var value = codec.decode(view.state[field])
		if not codec.valid or (field != "winner" and typeof(value) != typeof(state.get(field))): return null
		state.set(field, value)
	if state.players.size() < 2 or state.players.size() > 4 or state.players.any(func(p): return not p is PlayerState): return null
	for i in state.players.size():
		if state.players[i].seat != i: return null
	if state.active_seat < 0 or state.active_seat >= state.players.size(): return null
	if state.winner != null and state.winner not in state.players: return null
	for zone in [state.center_deck, state.center_row, state.removed, state.resolving]:
		if zone.any(func(c): return not c is CardInstance and (c != null or zone != state.center_row)): return null
	if state.card_pool not in ["2025", "2026", "2026mog", "custom"]: return null
	Engine.get_main_loop().root.get_node("CardDB").select_pool(state.card_pool)
	return state
