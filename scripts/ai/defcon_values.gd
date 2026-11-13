class_name DefconValues
extends RefCounted
const PATH = "res://data/defcon_weights.json"
static var loaded = false
static var weights: Dictionary = {}
static var bonus_weights: Dictionary = {}
static var scale = 1.0 # Offline benchmark multiplier; shipped coefficients already scaled.
static var settings: Dictionary = defaults()
static func defaults() -> Dictionary:
	return {"threshold": [1.8, 1.8, 1.8], "reserve_margin": 2.5, "late_filler": 0.0}
static func numeric(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func valid_tables(tables) -> bool:
	if not tables is Dictionary: return false
	for pool in tables:
		if pool not in ["2025", "2026"] or not tables[pool] is Dictionary: return false
		for values in tables[pool].values():
			if not values is Array or values.size() != 3 or not values.all(numeric): return false
	return true
static func valid_knobs(knobs) -> bool:
	return knobs is Dictionary and knobs.get("threshold") is Array and knobs.threshold.size() == 3 and knobs.threshold.all(numeric) and numeric(knobs.get("reserve_margin")) and numeric(knobs.get("late_filler"))
static func load_weights(path: String = PATH):
	loaded = true
	weights = {}
	bonus_weights = {}
	settings = defaults()
	if not FileAccess.file_exists(path): return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return
	var parsed = parser.data
	if not parsed is Dictionary or not valid_tables(parsed.get("pools")): return
	if not parsed.pools.has("2025") or not parsed.pools.has("2026"): return
	if not valid_tables(parsed.get("bonus_pools", {})): return
	weights = parsed.pools
	bonus_weights = parsed.get("bonus_pools", {})
	var knobs = parsed.get("settings", {})
	if valid_knobs(knobs):
		for key in defaults(): settings[key] = knobs[key]
	if knobs is Dictionary:
		for group in ["pools", "bonus"]:
			if not knobs.get(group) is Dictionary: continue
			for pool in ["2025", "2026"]:
				if valid_knobs(knobs[group].get(pool)):
					if not settings.has(group): settings[group] = {}
					settings[group][pool] = knobs[group][pool]
static func phase(p) -> int:
	return 0 if p.turns <= 4 else (1 if p.turns <= 9 else 2)
static func original_id(db, id: String) -> String:
	id = db.rules_id(id)
	for original in db.variants:
		if db.variants[original].id == id: return original
	return id
static func adjustment(engine, card, p) -> float:
	if not loaded: load_weights()
	var pool = "2025" if engine.state.card_pool == "2025" else "2026"
	var id = original_id(engine.db(), card.id) if engine.state.card_pool in ["2026mog", "custom"] else card.id
	var tables = bonus_weights if p.starting_life > engine.state.starting_life and bonus_weights.has(pool) else weights
	return float(tables.get(pool, {}).get(id, [0.0, 0.0, 0.0])[phase(p)]) * scale
static func knobs(pool: String, bonus: bool = false) -> Dictionary:
	pool = "2025" if pool == "2025" else "2026"
	var base = settings.get("pools", {}).get(pool, settings)
	return settings.get("bonus", {}).get(pool, base) if bonus else base
static func threshold(p, pool: String = "2026", bonus: bool = false) -> float:
	if not loaded: load_weights()
	return float(knobs(pool, bonus).threshold[phase(p)])
