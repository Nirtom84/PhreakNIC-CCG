extends Node
## Immutable printed card definitions; instances keep only their stable id.
const POOLS = ["2025", "2026", "2026mog"]
var cards: Dictionary = {}
var originals: Dictionary = {}
var variants: Dictionary = {}
var catalogs: Dictionary = {}
var selected_pool = "2026"
func _init(load_data: bool = true):
	if not load_data: return
	for data in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")):
		originals[data.id] = data
	cards = originals.duplicate(true)
	for data in JSON.parse_string(FileAccess.get_file_as_string("res://data/mog_variants.json")):
		var ids = [data.original_id]
		if data.original_id == "Botnet": ids = ["Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4"]
		for original_id in ids:
			var definition = originals[original_id].duplicate(true)
			definition.name = data.name
			definition.image = "res://" + data.file
			definition.flavor = data.flavor_text
			definition.text = data.rules_text
			definition.aliases = definition.get("aliases", []) + [data.name.replace("’", "'")]
			if data.rules_comparison == "DIFFERENT":
				definition.id = original_id.replace("Botnet", "Mognet")
				definition.set = "2026mog"
			variants[original_id] = definition
	for definition in variants.values():
		if definition.set == "2026mog": originals[definition.id] = definition
	select_pool("2026")
func catalog(pool: String = "2026") -> Node:
	if not catalogs.has(pool):
		var book = get_script().new(false)
		book.originals = originals
		book.variants = variants
		book.select_pool(pool)
		catalogs[pool] = book
	return catalogs[pool]
func _exit_tree():
	for book in catalogs.values(): book.free()
func select_pool(pool: String):
	selected_pool = pool
	cards = originals.duplicate(true)
	if pool == "2026mog":
		for id in variants:
			cards[variants[id].id] = variants[id]
			if variants[id].id != id: cards.erase(id)
	else:
		for id in originals:
			if originals[id].get("set") == "2026mog": cards.erase(id)
func image_path(id: String) -> String:
	return str(get_card(id).get("image", "res://assets/cards/phreaknic_fottr_tcg_card_back.jpg"))
func get_card(id: String) -> Dictionary:
	if id == "hidden":
		return {"id": "hidden", "name": "Hidden card", "cost": 0, "kind": "Hidden", "subtypes": "", "type_line": "", "hack": 0, "damage": 0, "text": "", "image": "res://assets/cards/phreaknic_fottr_tcg_card_back.jpg", "starter": false}
	return cards.get(id, originals.get(id, {}))
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
## A card name mapped to its id in the current pool, or "" when no card is named that.
func card_id_for_name(name: String) -> String:
	var target = str(name).to_lower().strip_edges()
	if target.is_empty(): return ""
	for id in cards:
		if str(cards[id].name).to_lower() == target: return id
	return ""
func in_pool(id: String, pool: String = "2026") -> bool:
	if not originals.has(id) or pool not in POOLS: return false
	if pool == "2026mog":
		return id not in ["Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4"]
	return str(originals[id].get("set", "2025")) != "2026mog" and (pool == "2026" or str(originals[id].get("set", "2025")) == "2025")
func pool_ids(pool: String = "2026") -> Array:
	return originals.keys().filter(func(id): return in_pool(id, pool))

# Physical center-deck copies: each catalog ID represents one printed copy.
const MIN_CENTER_CARDS = 40
func center_ids(pool: String = "2026") -> Array:
	return pool_ids(pool).filter(func(id): return not originals[id].starter)
func filter_banned(value: Array, pool: String = "2026") -> Array:
	if pool != selected_pool: return catalog(pool).filter_banned(value, pool)
	var eligible = center_ids(pool)
	var names_banned = []
	for id in value:
		if id is String and id in eligible: names_banned.append(cards[id].name)
	return eligible.filter(func(id): return cards[id].name in names_banned)
func bans_valid(value: Array, pool: String = "2026") -> bool:
	return center_ids(pool).size() - filter_banned(value, pool).size() >= MIN_CENTER_CARDS
func center_choices(pool: String = "2026") -> Array:
	if pool != selected_pool: return catalog(pool).center_choices(pool)
	var seen = []
	var result = []
	for id in center_ids(pool):
		if cards[id].name in seen: continue
		seen.append(cards[id].name)
		result.append(id)
	return result
func center_copies(id: String, pool: String = "2026") -> Array:
	if pool != selected_pool: return catalog(pool).center_copies(id, pool)
	return center_ids(pool).filter(func(copy): return cards[copy].name == cards[id].name)
