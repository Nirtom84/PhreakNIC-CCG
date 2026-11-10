class_name GameState
extends RefCounted
var players: Array = []
var center_deck: Array = []
var center_row: Array = [null, null, null, null, null]
var removed: Array = []
var resolving: Array = []
var active_seat: int = 0
var turn: int = 0
var rng = RandomNumberGenerator.new()
var log: Array[String] = []
var finished: bool = false
var winner = null
var extra_turns: Array = []
var coverage: Dictionary = {}
var initial_count: int = 0
var initial_ids: Dictionary = {}
var next_uid: int = 1
func create(id: String, owner: int = -1):
	var card = CardInstance.new(next_uid, id, owner)
	next_uid += 1
	return card
func shuffle(cards: Array):
	for i in range(cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var item = cards[i]
		cards[i] = cards[j]
		cards[j] = item
func all_cards() -> Array:
	var result = center_deck + removed + resolving
	for card in center_row:
		if card != null: result.append(card)
	for p in players:
		result += p.deck + p.hand + p.discard + p.play_area + p.reserve
	var roots = result.duplicate()
	for card in roots: _attachments(card, result)
	return result
func _attachments(card, result: Array):
	for child in card.attached:
		result.append(child)
		_attachments(child, result)
func conservation_ok() -> bool:
	var seen = {}
	for card in all_cards():
		if seen.has(card.uid) or initial_ids.get(card.uid, "") != card.id: return false
		seen[card.uid] = true
	return seen.size() == initial_count
