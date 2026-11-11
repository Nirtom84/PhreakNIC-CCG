extends Node
## Immutable printed card definitions; instances keep only their stable id.
var cards: Dictionary = {}
func _ready():
	for data in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")):
		cards[data.id] = data
func get_card(id: String) -> Dictionary:
	if id == "hidden":
		return {"id": "hidden", "name": "Hidden card", "cost": 0, "kind": "Hidden", "subtypes": "", "type_line": "", "hack": 0, "damage": 0, "text": "", "image": "res://assets/cards/phreaknic_fottr_tcg_card_back.jpg", "starter": false}
	return cards.get(id, {})
func has_subtype(id: String, subtype: String) -> bool:
	var words = str(get_card(id).get("subtypes", "")).to_lower().split(" ")
	if get_card(id).get("legendary", false): words.append("legendary")
	for word in subtype.to_lower().split(" "):
		if word not in words: return false
	return true
func named(id: String, name: String) -> bool:
	return id == "What is Truth" or names(id).any(func(n): return n.to_lower() == name.to_lower())
func name_contains(id: String, part: String) -> bool:
	return id == "What is Truth" or names(id).any(func(n): return part.to_lower() in n.to_lower())
func names(id: String) -> Array:
	return [str(get_card(id).get("name", ""))] + get_card(id).get("aliases", [])
func in_pool(id: String, pool: String = "2026") -> bool:
	return cards.has(id) and (pool == "2026" or str(cards[id].get("set", "2025")) == "2025")
func pool_ids(pool: String = "2026") -> Array:
	return cards.keys().filter(func(id): return in_pool(id, pool))

# Physical center-deck copies: each catalog ID represents one printed copy.
const MIN_CENTER_CARDS = 40
func center_ids(pool: String = "2026") -> Array:
	return pool_ids(pool).filter(func(id): return not cards[id].starter)
func filter_banned(value: Array, pool: String = "2026") -> Array:
	var eligible = center_ids(pool)
	var names_banned = []
	for id in value:
		if id is String and id in eligible: names_banned.append(cards[id].name)
	return eligible.filter(func(id): return cards[id].name in names_banned)
func bans_valid(value: Array, pool: String = "2026") -> bool:
	return center_ids(pool).size() - filter_banned(value, pool).size() >= MIN_CENTER_CARDS
func center_choices(pool: String = "2026") -> Array:
	var seen = []
	var result = []
	for id in center_ids(pool):
		if cards[id].name in seen: continue
		seen.append(cards[id].name)
		result.append(id)
	return result
func center_copies(id: String, pool: String = "2026") -> Array:
	return center_ids(pool).filter(func(copy): return cards[copy].name == cards[id].name)
