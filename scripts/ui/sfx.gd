extends Node
## Shared, bounded sound pool. Headless runs never create audio players.
var volume: float = 0.65
var muted: bool = false
var pool: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_play: Dictionary = {}
func _ready():
 var config = ConfigFile.new()
 if config.load("user://settings.cfg") == OK:
  volume = clampf(float(config.get_value("sound", "volume", 0.65)), 0.0, 1.0)
  muted = bool(config.get_value("sound", "muted", false))
 if DisplayServer.get_name() == "headless": return
 for i in 8:
  var player = AudioStreamPlayer.new()
  add_child(player)
  pool.append(player)
func save():
 var config = ConfigFile.new()
 config.load("user://settings.cfg")
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
