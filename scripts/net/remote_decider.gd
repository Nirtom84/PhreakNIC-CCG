class_name RemoteDecider
extends Decider
var server
var seat: int
func _init(room, index: int):
	server = room
	seat = index
static func card_data(card) -> Dictionary:
	return {"uid": card.uid, "id": card.id, "owner": card.owner, "controller": card.controller, "counters": card.counters}
func request(kind: String, text: String, data: Dictionary, args: Array):
	data.kind = kind
	data.text = text
	return await server.ask(seat, data, args)
func choose_option(p, text: String, options: Array[String]) -> int:
	return await request("choose_option", text, {"options": options}, [p, text, options])
func choose_options(p, text: String, options: Array[String], count: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(await request("choose_options", text, {"options": options, "count": count}, [p, text, options, count]))
	return result
func choose_cards(p, text: String, cards: Array, min_n: int, max_n: int) -> Array:
	var ids = await request("choose_cards", text, {"cards": cards.map(card_data), "min": min_n, "max": max_n}, [p, text, cards, min_n, max_n])
	return ids.map(func(uid): return cards.filter(func(c): return c.uid == uid)[0])
func choose_player(p, text: String, players: Array) -> PlayerState:
	var index = await request("choose_player", text, {"players": players.map(func(q): return q.seat)}, [p, text, players])
	for q in players:
		if q.seat == index: return q
	return null
func choose_number(p, text: String, allowed: Array[int]) -> int:
	return await request("choose_number", text, {"allowed": allowed}, [p, text, allowed])
func confirm(p, text: String) -> bool:
	return await request("confirm", text, {}, [p, text])
func name_a_card(p, text: String) -> String:
	return await request("name_a_card", text, {"card_pool": server.engine.state.card_pool}, [p, text])
func allocate_prevention(p, amount: int, sources: Array) -> Array:
	var entries = []
	for source in sources:
		entries.append({"card": card_data(source.card) if source.card != null else null, "capacity": source.capacity, "full": source.full, "name": source.get("name", "")})
	return await request("allocate_prevention", "Allocate prevention", {"amount": amount, "sources": entries}, [p, amount, sources])
static func wire_answer(kind: String, value):
	if kind == "choose_cards": return value.map(func(c): return c.uid)
	if kind == "choose_player": return value.seat if value != null else -1
	return value
static func valid(data: Dictionary, value, database) -> bool:
	match data.kind:
		"confirm": return value is bool
		"choose_option": return value is int and value >= 0 and value < data.options.size()
		"choose_number": return value is int and value in data.allowed
		"choose_player": return value is int and value in data.players
		"name_a_card": return value is String and database.in_pool(value, data.card_pool)
		"choose_cards", "choose_options", "allocate_prevention":
			if not value is Array or value.any(func(v): return not v is int): return false
			if data.kind == "allocate_prevention":
				if value.size() != data.sources.size(): return false
				var total = 0
				var capacity = 0
				for i in value.size():
					if value[i] < 0 or value[i] > data.sources[i].capacity: return false
					total += value[i]
					capacity += data.sources[i].capacity
				return total == mini(data.amount, capacity)
			var choices = data.cards.map(func(c): return c.uid) if data.kind == "choose_cards" else range(data.options.size())
			var minimum = data.min if data.kind == "choose_cards" else mini(data.count, choices.size())
			var maximum = data.max if data.kind == "choose_cards" else minimum
			if value.size() < minimum or value.size() > maximum: return false
			var seen = []
			for item in value:
				if item not in choices or item in seen: return false
				seen.append(item)
			return true
	return false
