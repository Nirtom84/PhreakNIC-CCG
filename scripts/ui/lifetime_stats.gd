extends RefCounted
const PATH = "user://stats.json"
const MAX = 1000000000000
const TOTALS = ["turns", "damage_dealt", "damage_taken", "life_gained", "cards_played", "cards_bought", "hacking_spent", "play_time", "win_turns"]
var data: Dictionary
func _init():
 data = empty()
 read()
static func bucket() -> Dictionary:
 var b = {"games": 0, "wins": 0, "losses": 0, "streak": 0}
 for k in TOTALS: b[k] = 0
 return b
static func empty() -> Dictionary:
 var d = bucket()
 d.merge({"experimental": {"games": 0, "wins": 0, "losses": 0, "difficulties": {}, "decks": {}, "keys": []}, "version": 1, "streak": 0, "best_streak": 0, "modes": {}, "difficulties": {}, "players": {}, "sets": {}, "heroes": {}, "stars": {}, "played": {}, "bought": {}, "keys": [], "first_date": "", "last_date": "", "biggest_hit": 0, "biggest_hit_date": "", "most_damage": 0, "fastest_win": 0, "fastest_hero": "", "fastest_date": "", "longest_game": 0})
 return d
static func number(v):
 if not (v is int or v is float): return 0
 if not is_finite(float(v)) or v < 0 or v > MAX or v != floor(float(v)): return 0
 return int(v)
static func date(v) -> String:
 return v if v is String and v.length() == 10 and v[4] == "-" and v[7] == "-" else ""
static func heroes() -> Array:
 var ids = [""]
 for id in CardDB.originals:
  if "hero" in str(CardDB.originals[id].get("subtypes", "")).to_lower().split(" "): ids.append(id)
 return ids
func read():
 if not FileAccess.file_exists(PATH): return
 var file = FileAccess.open(PATH, FileAccess.READ)
 if file == null: bad(); return
 if file.get_length() > 4000000: file.close(); bad(); return
 var parser = JSON.new()
 var error = parser.parse(file.get_as_text())
 file.close()
 if error != OK or not parser.data is Dictionary: bad(); return
 var raw = parser.data
 for k in data:
  if data[k] is int: data[k] = number(raw.get(k))
 for k in ["first_date", "last_date", "biggest_hit_date", "fastest_date"]: data[k] = date(raw.get(k))
 data.fastest_hero = raw.get("fastest_hero", "") if raw.get("fastest_hero", "") in heroes() else ""
 for k in ["modes", "difficulties", "players", "sets", "heroes", "stars", "played", "bought"]:
  var source = raw.get(k, {})
  if not source is Dictionary: continue
  var allowed = {"modes": ["local", "online_humans", "online_bots"], "difficulties": ["0", "1", "2", "3"], "players": ["2", "3", "4"], "sets": ["2025", "2026", "2026mog"], "heroes": heroes(), "stars": CardDB.originals.keys(), "played": CardDB.originals.keys(), "bought": CardDB.originals.keys()}[k]
  for id in allowed:
   if not source.has(id): continue
   if k in ["stars", "played", "bought"]: data[k][id] = number(source[id])
   elif source[id] is Dictionary:
    var b = bucket()
    for field in b: b[field] = number(source[id].get(field))
    data[k][id] = b
 var keys = raw.get("keys", [])
 if keys is Array:
  for key in keys.slice(maxi(0, keys.size() - 50)):
   if key is String and key.length() <= 256 and key not in data.keys: data.keys.append(key)
 var experimental = raw.get("experimental", {})
 if experimental is Dictionary:
  for field in ["games", "wins", "losses"]: data.experimental[field] = number(experimental.get(field))
  for group in ["difficulties", "decks"]:
   var entries = experimental.get(group, {})
   if not entries is Dictionary: continue
   for id in entries:
    if not id is String or id.length() > 40 or not entries[id] is Dictionary: continue
    if group == "difficulties" and id not in ["0", "1", "2", "3"]: continue
    data.experimental[group][id] = {"games": number(entries[id].get("games")), "wins": number(entries[id].get("wins")), "losses": number(entries[id].get("losses"))}
  var recent = experimental.get("keys", [])
  if recent is Array:
   for key in recent.slice(maxi(0, recent.size() - 50)):
    if key is String and key.length() <= 256: data.experimental.keys.append(key)
 data.version = 1
func bad():
 DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bad"))
func save() -> bool:
 var f = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
 if f == null: return false
 f.store_string(JSON.stringify(data))
 f.flush()
 var ok = f.get_error() == OK
 f.close()
 return ok and DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK
func reset():
 data = empty()
 save()
func add(b: Dictionary, s: Dictionary, won: bool, duration):
 b.games = mini(MAX, b.games + 1)
 b.wins = mini(MAX, b.wins + int(won))
 b.losses = mini(MAX, b.losses + int(not won))
 b.streak = mini(MAX, b.streak + 1) if won else 0
 for k in TOTALS:
  var value = int(duration) if k == "play_time" else (s.turns if k == "win_turns" and won else s.get(k, 0))
  b[k] = mini(MAX, b[k] + number(value))
func record(stats, seat: int, hero: String, mode: String, key: String) -> bool:
 if not stats.finished or seat < 0 or seat >= stats.seats.size() or key in data.keys: return false
 if mode not in ["local", "online_humans", "online_bots"]: return false
 if stats.card_pool == "custom": return record_experimental(stats, seat, key)
 var s = stats.seats[seat]
 var won = stats.winner_seat == seat
 var today = Time.get_date_string_from_system()
 add(data, s, won, stats.duration)
 var groups = {"modes": mode, "sets": stats.card_pool, "heroes": hero if hero in heroes() else ""}
 if mode == "local":
  var level = 0
  for i in stats.bot_difficulties.size():
   if i != seat: level = maxi(level, stats.bot_difficulties[i])
  groups.difficulties = str(level)
  groups.players = str(stats.seats.size())
 for group in groups:
  var id = groups[group]
  if not data[group].has(id): data[group][id] = bucket()
  add(data[group][id], s, won, stats.duration)
 data.best_streak = maxi(data.best_streak, data.streak)
 if s.biggest_hit > data.biggest_hit: data.biggest_hit = s.biggest_hit; data.biggest_hit_date = today
 data.most_damage = maxi(data.most_damage, s.damage_dealt)
 data.longest_game = maxi(data.longest_game, s.turns)
 if won and (data.fastest_win == 0 or s.turns < data.fastest_win):
  data.fastest_win = s.turns
  data.fastest_hero = hero
  data.fastest_date = today
 for group in ["played", "bought"]:
  for id in s.get(group, {}):
   if CardDB.originals.has(id): data[group][id] = mini(MAX, data[group].get(id, 0) + number(s[group][id]))
 var star = stats.star_card(seat)
 if CardDB.originals.has(star): data.stars[star] = mini(MAX, data.stars.get(star, 0) + 1)
 if data.first_date == "": data.first_date = today
 data.last_date = today
 data.keys.append(key.left(256))
 if data.keys.size() > 50: data.keys.pop_front()
 save()
 return true
func win_rate() -> float:
 return 100.0 * data.wins / data.games if data.games else 0.0
func average_win_turns() -> float:
 return float(data.win_turns) / data.wins if data.wins else 0.0
func favourite_hero() -> String:
 var best = ""
 var games = -1
 var wins = -1
 for id in data.heroes:
  var b = data.heroes[id]
  if b.games > games or (b.games == games and b.wins > wins): best = id; games = b.games; wins = b.wins
 return best
func top(group: String) -> String:
 var best = ""
 for id in data[group]:
  if data[group][id] > 0 and (best == "" or data[group][id] > data[group][best]): best = id
 return best
func share_details(handle: String = "You") -> Dictionary:
 handle = handle.strip_edges().left(16)
 if handle == "": handle = "You"
 var d = data.duplicate(true)
 d.kind = "stats"
 d.handle = handle.left(32)
 d.headline = "My record" if handle == "You" else handle.left(32) + "'s record"
 d.hero = favourite_hero()
 d.hero_name = CardDB.get_card(d.hero).get("name", "No Hero")
 d.signature = top("stars")
 d.rate = "%d%%" % roundi(win_rate())
 d.date = Time.get_date_string_from_system()
 d.version = str(ProjectSettings.get_setting("application/config/version"))
 return d

## Returns an isolated copy for the future Experimental decks tab.
func experimental() -> Dictionary:
 return data.experimental.duplicate(true)
func record_experimental(stats, seat: int, key: String) -> bool:
 if not stats.finished or seat < 0 or seat >= stats.seats.size() or key in data.experimental.keys: return false
 if not CustomDeck.validate(stats.custom_deck).is_empty(): return false
 var won = stats.winner_seat == seat
 var level = 0
 for i in stats.bot_difficulties.size():
  if i != seat: level = maxi(level, stats.bot_difficulties[i])
 var buckets = [data.experimental]
 for entry in [["difficulties", str(level)], ["decks", stats.custom_deck.name]]:
  if not data.experimental[entry[0]].has(entry[1]): data.experimental[entry[0]][entry[1]] = {"games": 0, "wins": 0, "losses": 0}
  buckets.append(data.experimental[entry[0]][entry[1]])
 for b in buckets:
  b.games = mini(MAX, b.games + 1)
  b.wins = mini(MAX, b.wins + int(won))
  b.losses = mini(MAX, b.losses + int(not won))
 data.experimental.keys.append(key.left(256))
 if data.experimental.keys.size() > 50: data.experimental.keys.pop_front()
 save()
 return true
