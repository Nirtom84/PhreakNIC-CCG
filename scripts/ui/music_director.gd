extends Node
## Selection and clock are usable without an audio device or scene tree.
const PERMANENTS = {
 "The Fellowship of the Token Ring": "the_fellowship", "The Clarion Inn": "the_clarion_inn",
 "Nashville 2600": "nashville_2600", "The Juice": "the_juice",
 "Military-Grade Card Encapsulation": "military_grade_card_encapsulation",
 "pTFS": "ptfs", "CTF Bangers": "ctf_bangers", "Time Travel": "time_travel"}
const TURNS = {"O.P.R.A.H.": "oprah", "Oprah Wonka": "oprah_wonka", "PhreakNIC": "phreaknic"}
var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music_cues.json"))
var context = "none"
var state: Dictionary = {}
var current = ""
var elapsed = 0.0
var rotation: Array = []
var outro = false
var result_played = false
var menu_overlays = 0
var players: Array[AudioStreamPlayer] = []
var active = 0
var cache: Dictionary = {}
var pending: Dictionary = {}
var failed: Dictionary = {}
var tween: Tween
var gain = -80.0
var paused = false
var unlocked = false

static func select(public_state: Dictionary) -> Dictionary:
 var base = "starter_deck"
 for p in public_state.get("players", []):
  if not p.get("alive", true): continue
  if p.life <= 5: base = "center_row_red"; break
  if p.life <= 10: base = "center_row_amber"
 var list: Array = [base]
 for name in public_state.get("permanents", []):
  var cue = "botnet" if "Botnet" in name else str(PERMANENTS.get(name, ""))
  if not cue.is_empty() and cue not in list: list.append(cue)
 if public_state.get("time_travel", false) and "time_travel" not in list: list.append("time_travel")
 var priority = ""
 for name in public_state.get("played", []):
  if TURNS.has(name): priority = TURNS[name]
 if public_state.get("toctou", false): priority = "toctou"
 return {"rotation": list, "priority": priority}

func _ready():
 if DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server"): return
 unlocked = not OS.has_feature("web")
 for i in 2:
  var player = AudioStreamPlayer.new()
  player.bus = "Music"
  add_child(player)
  players.append(player)

func set_context(value: String):
 if context == value: return
 context = value
 result_played = false
 state = {}
 rotation = []
 choose("main_theme" if menu_overlays > 0 or value == "menu" else "phreaknic" if value == "lobby" else "")

func set_table_state(value: Dictionary):
 if context == "result": return
 if context != "table": set_context("table")
 if state == value: return
 var old = select(state)
 state = value.duplicate(true)
 var selection = select(state)
 rotation = selection.rotation
 if outro or menu_overlays > 0: return
 if not selection.priority.is_empty(): choose(selection.priority); return
 if current == "the_clarion_inn" and current not in rotation:
  choose(current + "_out"); return
 for cue in rotation:
  if cue != rotation[0] and cue not in old.rotation:
   choose(cue); return
 if current not in rotation or (current == old.rotation[0] and rotation[0] != current): choose(rotation[0])

func menu_overlay(overlay: Control):
 menu_overlays += 1
 choose("main_theme")
 overlay.tree_exited.connect(func():
  menu_overlays = maxi(0, menu_overlays - 1)
  if menu_overlays > 0: return
  if context == "table":
   var selection = select(state)
   choose(selection.priority if not selection.priority.is_empty() else selection.rotation[0])
  else:
   choose("main_theme" if context == "menu" else "phreaknic" if context == "lobby" else ""))

func sting(win: bool):
 if context == "result" and result_played: return
 context = "result"
 result_played = true
 choose("access_granted" if win else "connection_terminated")

func restart_time_travel():
 if menu_overlays == 0 and state.get("time_travel", false) and select(state).priority.is_empty(): choose("time_travel", true)

func choose(slug: String, restart = false):
 if slug == current and not restart: return
 if restart and slug == current and not players.is_empty(): players[active].stop()
 current = slug
 elapsed = 0
 outro = slug.ends_with("_out")
 apply_choice()

func advance(seconds: float):
 if current.is_empty() or paused: return
 elapsed += seconds
 if outro:
  var source = current.trim_suffix("_out")
  if elapsed >= float(cues[source].outro_length):
   outro = false
   var selection = select(state)
   choose(selection.priority if not selection.priority.is_empty() else selection.rotation[0])
  return
 if not cues.has(current): return
 var cue = cues[current]
 if not cue.looping:
  if elapsed >= float(cue.length): choose("")
  return
 if menu_overlays > 0 or context != "table" or not select(state).priority.is_empty() or rotation.size() < 2: return
 # Intro plus two complete loop traversals, independent of frame/wrap precision.
 if elapsed >= float(cue.length) * 2.0 - float(cue.loop_offset):
  choose(rotation[(rotation.find(current) + 1) % rotation.size()])

func _process(delta):
 if players.is_empty() or not unlocked: return
 # A pending download has no playback clock yet.
 if not current.is_empty() and players[active].get_meta("cue", "") == current: advance(delta)
 if not current.is_empty() and not cache.has(current): apply_choice()

func volume(value: float, audible: bool):
 var next_gain = linear_to_db(maxf(value, 0.001)) - 8.0
 if next_gain != gain and tween != null and tween.is_running():
  tween.kill()
  players[1 - active].stop()
 gain = next_gain
 paused = not audible
 for p in players: p.stream_paused = paused
 if not players.is_empty() and (tween == null or not tween.is_running()): players[active].volume_db = gain

func unlock():
 unlocked = true
 apply_choice()

func apply_choice():
 if players.is_empty() or not unlocked: return
 if current.is_empty(): fade_to(null); return
 if cache.has(current):
  if players[active].get_meta("cue", "") != current or not players[active].playing:
   fade_to(cache[current])
  return
 var slug = current
 var source = slug.trim_suffix("_out")
 if not cues.has(source): return
 var file = cues[source].outro if slug.ends_with("_out") else cues[source].file
 if not OS.has_feature("web"):
  cache[slug] = load("res://assets/music/" + file)
  configure(slug)
  apply_choice()
  return
 var now = Time.get_ticks_msec()
 if pending.has(slug) or now - int(failed.get(slug, -60001)) < 60000: return
 var request = HTTPRequest.new()
 request.timeout = 30.0
 add_child(request)
 pending[slug] = true
 request.request_completed.connect(func(result, code, _headers, body):
  pending.erase(slug)
  request.queue_free()
  if result == HTTPRequest.RESULT_SUCCESS and code == 200:
   var stream = AudioStreamOggVorbis.load_from_buffer(body)
   if stream != null:
    cache[slug] = stream
    configure(slug)
   else: failed[slug] = Time.get_ticks_msec()
  else: failed[slug] = Time.get_ticks_msec()
  apply_choice())
 # Resolve against the document without eval, including sites hosted in subdirectories.
 var window = JavaScriptBridge.get_interface("window")
 var url = str(JavaScriptBridge.create_object("URL", "music/" + file, window.document.baseURI).href)
 var error = request.request(url)
 if error != OK:
  pending.erase(slug)
  failed[slug] = now
  request.queue_free()

func configure(slug: String):
 var cue = cues[slug.trim_suffix("_out")]
 cache[slug].loop = not slug.ends_with("_out") and cue.looping
 cache[slug].loop_offset = float(cue.loop_offset) if cache[slug].loop else 0.0

func fade_to(stream):
 if tween != null: tween.kill()
 var old = players[active]
 active = 1 - active
 var next = players[active]
 next.stop()
 next.stream = stream
 next.set_meta("cue", current)
 next.volume_db = -80
 next.stream_paused = paused
 if stream != null: next.play()
 elapsed = 0
 tween = create_tween().set_parallel(true)
 tween.tween_property(old, "volume_db", -80.0, 0.8)
 tween.tween_property(next, "volume_db", gain, 0.8)
 tween.chain().tween_callback(old.stop)
