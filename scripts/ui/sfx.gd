extends Node
## Shared, bounded sound pool. Headless runs never create audio players.
signal visuals_changed(enabled)
var visual_effects: bool = true
var volume: float = 0.65
var muted: bool = false
var handle: String = ""
var hero_id: String = ""
var bot_fast: bool = false
var auto_end_turn: bool = true
var confirm_end_turn: bool = true
var starting_life: int = 0
var card_pool: String = "2026"
var banned_by_pool: Dictionary = {"2025": [], "2026": []}
func banned_cards(selected_pool: String) -> Array:
 return banned_by_pool.get(selected_pool, []).duplicate()
func set_banned(selected_pool: String, value: Array):
 var clean = CardDB.filter_banned(value, selected_pool)
 if CardDB.bans_valid(clean, selected_pool): banned_by_pool[selected_pool] = clean
func clean_handle(value: String) -> String:
 return value.replace("[", "").replace("]", "").strip_edges().left(16)
var pool: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_play: Dictionary = {}
func _ready():
 var config = OnlineAPI.settings()
 var v = config.get_value("sound", "volume", 0.65)
 if (v is float or v is int) and is_finite(float(v)) and v >= 0 and v <= 1: volume = float(v)
 v = config.get_value("player", "handle", "")
 if v is String: handle = clean_handle(v)
 v = config.get_value("player", "hero_id", "")
 if v is String and CardDB.cards.has(v):
  hero_id = v
  handle = str(CardDB.cards[v].name)
 v = config.get_value("game", "card_pool", "2026")
 if v is String and v in ["2025", "2026"]: card_pool = v
 for entry in [["game", "bot_fast"], ["game", "auto_end_turn"], ["game", "confirm_end_turn"], ["sound", "muted"], ["visual", "effects"]]:
  if not config.has_section_key(entry[0], entry[1]): continue
  v = config.get_value(entry[0], entry[1])
  if v is bool: set("visual_effects" if entry[1] == "effects" else entry[1], v)
 v = config.get_value("game", "starting_life", 0)
 if v is int and v >= 0 and v <= 10000: starting_life = v
 for selected_pool in ["2025", "2026"]:
  var bans = config.get_value("game", "banned_" + selected_pool, [])
  if bans is Array and bans.size() <= 150: set_banned(selected_pool, bans)
 if DisplayServer.get_name() == "headless": return
 for i in 8:
  var player = AudioStreamPlayer.new()
  add_child(player)
  pool.append(player)
func save():
 var config = OnlineAPI.settings()
 handle = str(CardDB.cards[hero_id].name) if CardDB.cards.has(hero_id) else clean_handle(handle)
 config.set_value("player", "handle", handle)
 config.set_value("player", "hero_id", hero_id)
 config.set_value("game", "auto_end_turn", auto_end_turn)
 config.set_value("game", "confirm_end_turn", confirm_end_turn)
 config.set_value("game", "starting_life", starting_life)
 config.set_value("game", "bot_fast", bot_fast)
 config.set_value("game", "card_pool", card_pool)
 for selected_pool in ["2025", "2026"]: config.set_value("game", "banned_" + selected_pool, banned_cards(selected_pool))
 config.set_value("visual", "effects", visual_effects)
 visuals_changed.emit(visual_effects)
 config.set_value("sound", "volume", volume)
 config.set_value("sound", "muted", muted)
 config.save("user://settings.cfg")
 for player in pool: player.volume_db = linear_to_db(volume) if not muted and volume > 0 else -80.0
func play(sound: String):
 if muted or volume <= 0 or pool.is_empty(): return
 var now = Time.get_ticks_msec()
 if now - int(last_play.get(sound, -1000)) < 60: return
 last_play[sound] = now
 if not streams.has(sound):
  var path = "res://assets/sounds/" + sound + ".wav"
  if not ResourceLoader.exists(path): return
  streams[sound] = load(path)
 for player in pool:
  if not player.playing:
   player.stream = streams[sound]
   player.volume_db = linear_to_db(volume)
   player.play()
   return
