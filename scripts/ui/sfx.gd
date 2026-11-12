extends Node
## Shared, bounded sound pool. Headless runs never create audio players.
signal visuals_changed(enabled)
var visual_effects: bool = true
var volume: float = 0.65
var muted: bool = false
var handle: String = ""
var hero_id: String = ""
const BOT_PACES = BotPace.BOT_PACES
var bot_pace: float = 0.5:
 set(value): bot_pace = nearest(value)
static func nearest(value) -> float: return BotPace.nearest(value)
static func pace_label(value, short: bool = false) -> String: return BotPace.pace_label(value, short)
static func saved_pace(data: Dictionary) -> float: return BotPace.saved_pace(data)
func pace_option(parent: Node, value: float, changed: Callable) -> OptionButton:
 var row = HBoxContainer.new()
 parent.add_child(row)
 UIStyle.label(row, "Bot pace", 18)
 var choice = OptionButton.new()
 choice.name = "BotPace"
 choice.custom_minimum_size.y = 72 if UIStyle.compact() else 56
 row.add_child(choice)
 if UIStyle.compact(): choice.get_popup().add_theme_constant_override("v_separation", 56)
 for pace in BOT_PACES: choice.add_item(pace_label(pace))
 choice.select(BOT_PACES.find(nearest(value)))
 choice.item_selected.connect(func(n): changed.call(BOT_PACES[n]))
 return choice
var music_volume: float = 0.35
var music_muted: bool = false
var music: AudioStreamPlayer
var auto_end_turn: bool = true
var confirm_end_turn: bool = true
var auto_botnet: bool = false
var starting_life: int = 0
var card_pool: String = "2026"
var banned_by_pool: Dictionary = {"2025": [], "2026": [], "2026mog": []}
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
 v = config.get_value("game", "card_pool", "2026")
 if v is String and v in ["2025", "2026", "2026mog"]: card_pool = v
 CardDB.select_pool(card_pool)
 v = config.get_value("player", "handle", "")
 if v is String: handle = clean_handle(v)
 v = config.get_value("player", "hero_id", "")
 if v is String and CardDB.cards.has(v):
  hero_id = v
  handle = str(CardDB.cards[v].name)
 for entry in [["game", "auto_end_turn"], ["game", "confirm_end_turn"], ["game", "auto_botnet"], ["sound", "muted"], ["visual", "effects"]]:
  if not config.has_section_key(entry[0], entry[1]): continue
  v = config.get_value(entry[0], entry[1])
  if v is bool: set("visual_effects" if entry[1] == "effects" else entry[1], v)
 bot_pace = migrated_pace(config)
 v = config.get_value("sound", "music_volume", 0.35)
 music_volume = valid_volume(v, 0.35)
 v = config.get_value("sound", "music_muted", false)
 music_muted = v if v is bool else false
 v = config.get_value("game", "starting_life", 0)
 if v is int and v >= 0 and v <= 10000: starting_life = v
 for selected_pool in ["2025", "2026", "2026mog"]:
  var bans = config.get_value("game", "banned_" + selected_pool, [])
  if bans is Array and bans.size() <= 150: set_banned(selected_pool, bans)
 if DisplayServer.get_name() == "headless": return
 for bus in ["SFX", "Music"]:
  if AudioServer.get_bus_index(bus) < 0:
   AudioServer.add_bus()
   AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
 for i in 8:
  var player = AudioStreamPlayer.new()
  add_child(player)
  player.bus = "SFX"
  pool.append(player)
 start_music()
func save():
 var config = OnlineAPI.settings()
 handle = str(CardDB.cards[hero_id].name) if CardDB.cards.has(hero_id) else clean_handle(handle)
 config.set_value("player", "handle", handle)
 config.set_value("player", "hero_id", hero_id)
 config.set_value("game", "auto_end_turn", auto_end_turn)
 config.set_value("game", "confirm_end_turn", confirm_end_turn)
 config.set_value("game", "auto_botnet", auto_botnet)
 config.set_value("game", "starting_life", starting_life)
 config.set_value("game", "bot_pace", bot_pace)
 config.set_value("game", "card_pool", card_pool)
 for selected_pool in ["2025", "2026", "2026mog"]: config.set_value("game", "banned_" + selected_pool, banned_cards(selected_pool))
 config.set_value("visual", "effects", visual_effects)
 visuals_changed.emit(visual_effects)
 config.set_value("sound", "volume", volume)
 config.set_value("sound", "muted", muted)
 config.set_value("sound", "music_volume", music_volume)
 config.set_value("sound", "music_muted", music_muted)
 config.save("user://settings.cfg")
 apply_music()
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
   player.pitch_scale = pitch_for(sound, randf())
   player.play()
   return

static func migrated_pace(config: ConfigFile) -> float:
 var data = {}
 for key in ["bot_pace", "bot_speed", "bot_fast"]:
  if config.has_section_key("game", key): data[key] = config.get_value("game", key)
 return saved_pace(data)
static func valid_volume(value, fallback: float) -> float:
 return float(value) if (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= 1 else fallback
static func pitch_for(sound: String, sample: float) -> float:
 return lerpf(0.94, 1.06, clampf(sample, 0, 1)) if sound in ["card_play", "card_draw", "buy", "reserve", "shuffle", "button"] else 1.0
func music_audible() -> bool:
 return not music_muted and music_volume > 0
func apply_music():
 # A silenced track is paused rather than decoded at -80 dB.
 if not is_instance_valid(music): return
 music.volume_db = linear_to_db(maxf(music_volume, 0.001))
 music.stream_paused = not music_audible()
func start_music():
 if DisplayServer.get_name() == "headless": return
 if not is_instance_valid(music):
  music = AudioStreamPlayer.new()
  music.bus = "Music"
  music.stream = load("res://assets/sounds/music_loop.ogg")
  music.stream.loop = true
  add_child(music)
 if not music.playing and not music.stream_paused: music.play()
 apply_music()
func _input(event):
 # Browsers only allow audio after a gesture; one is enough.
 if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
  start_music()
  if is_instance_valid(music) and music.playing: set_process_input(false)
