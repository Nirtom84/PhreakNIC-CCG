class_name SaveGame
extends RefCounted
const PATH = "user://savegame.json"
const VERSION = 1
const STATE_FIELDS = ["starting_life", "card_pool", "banned", "players", "center_deck", "center_row", "removed", "resolving", "active_seat", "turn", "log", "finished", "winner", "extra_turns", "coverage", "initial_count", "initial_ids", "next_uid"]
const PLAYER_FIELDS = ["seat", "life", "alive", "is_bot", "difficulty", "deck", "hand", "discard", "play_area", "reserve", "hacking", "played", "turn_flags", "turns"]
const CARD_FIELDS = ["uid", "id", "owner", "controller", "counters", "attached", "flags"]
var objects: Array = []
var records: Array = []
var valid = true
func encode(value):
 if value is CardInstance or value is PlayerState:
  var index = objects.find(value)
  if index < 0:
   index = objects.size()
   objects.append(value)
   records.append({})
   var fields = CARD_FIELDS if value is CardInstance else PLAYER_FIELDS
   var record = {"type": "card" if value is CardInstance else "player", "data": {}}
   for field in fields: record.data[field] = encode(value.get(field))
   records[index] = record
  return {"ref": index}
 if value is Dictionary:
  var pairs = []
  for key in value: pairs.append([encode(key), encode(value[key])])
  return {"dict": pairs}
 if value is Array:
  return value.map(encode)
 return value
func decode(value):
 if value is Dictionary:
  if value.has("ref"):
   if not (value.ref is int or value.ref is float) or float(value.ref) != floor(float(value.ref)):
    valid = false
    return null
   var index = int(value.ref)
   if index < 0 or index >= objects.size(): valid = false; return null
   return objects[index]
  if value.has("dict") and value.dict is Array:
   var result = {}
   for pair in value.dict:
    if not pair is Array or pair.size() != 2: valid = false; return {}
    var key = decode(pair[0])
    if not (key is String or key is StringName or key is int or key is CardInstance or key is PlayerState): valid = false; return {}
    result[key] = decode(pair[1])
   return result
  valid = false
  return null
 if value is Array: return value.map(decode)
 if value is float and value == floor(value): return int(value)
 return value
static func snapshot(state) -> Dictionary:
 var codec = SaveGame.new()
 var data = {}
 for field in STATE_FIELDS: data[field] = codec.encode(state.get(field))
 data.rng_seed = str(state.rng.seed)
 data.rng_state = str(state.rng.state)
 return {"state": data, "objects": codec.records}
static func restore(data: Dictionary):
 if not bounded(data): return null
 if not data.get("objects") is Array or not data.get("state") is Dictionary: return null
 var codec = SaveGame.new()
 for record in data.objects:
  if not record is Dictionary or not record.get("data") is Dictionary: return null
  if record.get("type") not in ["card", "player"]: return null
  codec.objects.append(CardInstance.new() if record.type == "card" else PlayerState.new())
 for i in data.objects.size():
  var object = codec.objects[i]
  var fields = CARD_FIELDS if object is CardInstance else PLAYER_FIELDS
  var record = data.objects[i].data
  for field in fields:
   if not record.has(field): return null
   var value = codec.decode(record[field])
   if typeof(value) != typeof(object.get(field)): return null
   object.set(field, value)
 var state = GameState.new()
 for field in STATE_FIELDS:
  if field in ["card_pool", "starting_life", "banned"] and not data.state.has(field): continue
  if not data.state.has(field): return null
  var value = codec.decode(data.state[field])
  if field != "winner" and typeof(value) != typeof(state.get(field)): return null
  if field == "log":
   if value.any(func(line): return not line is String): return null
   state.log.assign(value)
  else: state.set(field, value)
 if not data.state.has("starting_life"): state.starting_life = 24 if state.players.size() == 2 else 10 * state.players.size()
 if not codec.valid or state.card_pool not in ["2025", "2026"]: return null
 if state.players.size() < 2 or state.players.size() > 4 or state.center_row.size() != 5: return null
 if state.starting_life < 1 or state.starting_life > 10000: return null
 if state.turn < 1: return null
 if state.active_seat < 0 or state.active_seat >= state.players.size(): return null
 for i in state.players.size():
  var player = state.players[i]
  if not player is PlayerState or player.seat != i: return null
  if player.difficulty < -1 or player.difficulty > 2: return null
 for object in codec.objects:
  if object is CardInstance:
   if object.counters < 0 or object.counters > 1000000: return null
   if object.flags.has("copy_id") and not object.flags.copy_id is String: return null
   var cards = Engine.get_main_loop().root.get_node("CardDB").cards
   if not Engine.get_main_loop().root.get_node("CardDB").in_pool(object.id, state.card_pool): return null
   if object.flags.has("copy_id") and not Engine.get_main_loop().root.get_node("CardDB").in_pool(object.flags.copy_id, state.card_pool): return null
   if object.owner < -1 or object.owner >= state.players.size() or object.controller < -1 or object.controller >= state.players.size(): return null
   for child in object.attached:
    if not child is CardInstance: return null
 # Traverse physical roots without recursion; reject cycles and duplicate objects/UIDs.
 var queue = state.center_deck + state.removed + state.resolving
 for card in state.center_row:
  if card != null: queue.append(card)
 for player in state.players:
  for zone in [player.deck, player.hand, player.discard, player.play_area, player.reserve]: queue.append_array(zone)
 var seen = {}
 var identities = []
 while not queue.is_empty():
  var card = queue.pop_back()
  if not card is CardInstance or card in identities: return null
  if card.uid <= 0 or seen.has(card.uid) or card.flags.get("virtual", false): return null
  if not state.initial_ids.get(card.uid) is String or state.initial_ids.get(card.uid) != card.id or card.uid >= state.next_uid: return null
  seen[card.uid] = true
  identities.append(card)
  queue.append_array(card.attached)
 if seen.size() != state.initial_count or state.initial_ids.size() != state.initial_count: return null
 var expected = {"Hacking": 8 * state.players.size(), "Damage": 2 * state.players.size()}
 var database = Engine.get_main_loop().root.get_node("CardDB")
 if state.banned != database.filter_banned(state.banned, state.card_pool) or not database.bans_valid(state.banned, state.card_pool): return null
 for id in database.center_ids(state.card_pool):
  if id not in state.banned: expected[id] = 1
 for card in identities: expected[card.id] = expected.get(card.id, 0) - 1
 if expected.values().any(func(count): return count != 0): return null
 if state.next_uid != state.initial_count + 1: return null
 for seat in state.extra_turns:
  if not seat is int or seat < 0 or seat >= state.players.size(): return null
 for player in state.players:
  if player.turns < 0: return null
  for card in player.played:
   if not card is CardInstance: return null
  if player.turn_flags.has("rickroll") and not player.turn_flags.rickroll is CardInstance: return null
 for object in codec.objects:
  if not object is CardInstance: continue
  if object.flags.has("host") and not object.flags.host is CardInstance: return null
  if object not in identities:
   if not object.flags.get("virtual", false) or object.uid >= 0 or object.flags.get("host") not in identities: return null
 if state.winner != null and state.winner not in state.players: return null
 if not data.state.get("rng_seed", "") is String or not data.state.get("rng_state", "") is String: return null
 if not data.state.rng_seed.is_valid_int() or not data.state.rng_state.is_valid_int(): return null
 state.rng.seed = int(data.state.rng_seed)
 state.rng.state = int(data.state.rng_state)
 return state
static func safe(engine, human: int = 0) -> bool:
 if engine == null or engine.state == null: return false
 var state = engine.state
 return not state.finished and human >= 0 and human < state.players.size() and state.active_seat == human and state.players[human].alive and not engine.busy and engine.reaction_depth == 0 and engine.simultaneous_depth == 0 and state.resolving.is_empty()
static func content() -> String:
 var ids = Engine.get_main_loop().root.get_node("CardDB").cards.keys()
 ids.sort()
 return JSON.stringify(ids).sha256_text()
static func write(engine, table: Dictionary) -> bool:
 if not safe(engine): return false
 var state = engine.state
 if state.players[0].is_bot or state.players.slice(1).any(func(p): return not p.is_bot): return false
 var data = {"version": VERSION, "content": content(), "saved_at": int(Time.get_unix_time_from_system()), "game": snapshot(state), "table": table}
 var file = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
 if file == null: return false
 file.store_string(JSON.stringify(data))
 file.flush()
 var error = file.get_error()
 file.close()
 if error != OK: return false
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK
static func bounded(data) -> bool:
 # Saves have a larger node budget than wire messages, but never recursive depth.
 var queue = [[data, 0]]
 var count = 0
 while not queue.is_empty():
  var item = queue.pop_back()
  var value = item[0]
  count += 1
  if count > 100000 or item[1] > 32: return false
  if value is float and (not is_finite(value) or absf(value) > 9007199254740991.0): return false
  if value is Array:
   if value.size() > 100000: return false
   for child in value: queue.append([child, item[1] + 1])
  if value is Dictionary:
   for key in value:
    if not (key is String or key is StringName): return false
    queue.append([value[key], item[1] + 1])
 return true
static func read() -> Dictionary:
 if not FileAccess.file_exists(PATH): return {}
 var file = FileAccess.open(PATH, FileAccess.READ)
 if file == null or file.get_length() > 2 * 1024 * 1024: return {}
 var parser = JSON.new()
 if parser.parse(file.get_as_text()) != OK: return {}
 var data = parser.data
 if not data is Dictionary or not (data.get("version") is int or data.get("version") is float) or not data.get("content") is String: return {}
 if data.version != VERSION or data.content != content(): return {}
 if not data.get("game") is Dictionary or not data.get("table") is Dictionary: return {}
 var state = restore(data.game)
 if state == null: return {}
 var engine = GameEngine.new()
 engine.state = state
 var ok = safe(engine) and not state.players[0].is_bot and state.players.slice(1).all(func(p): return p.is_bot)
 engine.free()
 var table = data.table
 if not table.get("seat_names") is Array or not table.get("seat_heroes") is Array: return {}
 if table.seat_names.size() != state.players.size() or table.seat_heroes.size() != state.players.size(): return {}
 for name in table.seat_names:
  if not name is String: return {}
 for hero in table.seat_heroes:
  if not hero is String or (hero != "" and not Engine.get_main_loop().root.get_node("CardDB").cards.has(hero)): return {}
 if table.has("log_entries"):
  if not table.log_entries is Array: return {}
  for entry in table.log_entries:
   if not entry is String: return {}
 if not table.get("log") is String or not table.get("fast") is bool: return {}
 if not (table.get("player_count") is int or table.get("player_count") is float) or table.player_count != state.players.size(): return {}
 if not table.get("difficulties") is Array or table.difficulties.size() != state.players.size(): return {}
 for i in state.players.size():
  if not (table.difficulties[i] is int or table.difficulties[i] is float) or table.difficulties[i] != state.players[i].difficulty: return {}
 if not table.get("handle") is String or not table.get("hero_id") is String: return {}
 if table.handle != table.seat_names[0] or table.hero_id != table.seat_heroes[0]: return {}
 if not (data.get("saved_at") is float or data.get("saved_at") is int) or not is_finite(float(data.saved_at)) or data.saved_at < 0: return {}
 return data if ok else {}
static func remove():
 if FileAccess.file_exists(PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
