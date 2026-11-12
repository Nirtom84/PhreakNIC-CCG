extends SceneTree
var checks = 0
var failures = 0
const Director = preload("res://scripts/ui/music_director.gd")
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func run():
 var db = root.get_node("CardDB")
 for entry in [[24, "starter_deck"], [11, "starter_deck"], [10, "center_row_amber"], [6, "center_row_amber"], [5, "center_row_red"], [1, "center_row_red"]]:
  verify(Director.select({"players": [{"life": entry[0]}]}).rotation[0] == entry[1], "absolute life threshold %s" % entry[0])
 verify(Director.select({"players": [{"life": 0, "alive": false}, {"life": 48}]}).rotation == ["starter_deck"], "ignore eliminated players")
 for name in Director.PERMANENTS:
  var id = db.card_id_for_name(name)
  verify(not id.is_empty() and db.get_card(id).kind == "Permanent", "real permanent " + name)
  verify(Director.PERMANENTS[name] in Director.select({"permanents": [db.get_card(id).name]}).rotation, "cue " + name)
 for id in ["Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4"]:
  verify("botnet" in Director.select({"permanents": [db.get_card(id).name]}).rotation, "Botnet printed copy " + id)
 for name in Director.TURNS:
  verify(not db.card_id_for_name(name).is_empty(), "real turn card " + name)
  verify(Director.select({"played": [name]}).priority == Director.TURNS[name], "turn cue " + name)
 verify(db.get_card("TOCTOU").name == "TOCTOU Photo-Finish", "real TOCTOU name")
 verify(Director.select({"played": ["PhreakNIC"], "permanents": ["Botnet"], "toctou": true}).priority == "toctou", "TOCTOU priority")
 var d = Director.new()
 root.add_child(d)
 verify(d.players.is_empty(), "headless creates no audio players")
 d.set_context("menu")
 verify(d.current == "main_theme", "menu theme")
 d.set_context("lobby")
 verify(d.current == "phreaknic", "lobby theme")
 var overlay = Control.new()
 root.add_child(overlay)
 d.menu_overlay(overlay)
 verify(d.current == "main_theme", "Hero/rules overlay theme")
 overlay.free()
 verify(d.current == "phreaknic", "overlay restores lobby")
 d.set_table_state({"players": [{"life": 24}], "permanents": ["Botnet"]})
 verify(d.current == "botnet", "new permanent starts immediately")
 var duration = d.cues.botnet.length * 2 - d.cues.botnet.loop_offset
 d.advance(duration - 0.01)
 verify(d.current == "botnet", "intro and two loops have not ended")
 d.advance(0.02)
 verify(d.current == "starter_deck", "rotation after two loops using fake clock")
 d.set_table_state({"players": [{"life": 5}], "permanents": ["Botnet"]})
 verify(d.current == "center_row_red", "playing base changes immediately")
 d.set_table_state({"permanents": ["The Clarion Inn"]})
 verify(d.current == "the_clarion_inn", "Clarion starts")
 d.set_table_state({})
 verify(d.current == "the_clarion_inn_out", "Clarion collapse")
 d.advance(d.cues.the_clarion_inn.outro_length - 0.01)
 verify(d.current == "the_clarion_inn_out", "full collapse ending")
 d.advance(0.02)
 verify(d.current == "starter_deck", "resume after collapse")
 d.set_table_state({"played": ["O.P.R.A.H."], "permanents": ["Botnet"]})
 verify(d.current == "oprah", "turn priority over rotation")
 d.set_table_state({"played": [], "permanents": ["Botnet"]})
 verify(d.current != "oprah", "turn cue ends")
 d.sting(true)
 verify(d.current == "access_granted", "win sting")
 d.advance(100)
 d.sting(true)
 d.set_table_state({})
 verify(d.current.is_empty(), "result once then silence despite redraw")
 d.set_context("menu")
 d.sting(false)
 verify(d.current == "connection_terminated", "loss draw spectator sting")
 for slug in d.cues:
  var cue = d.cues[slug]
  verify(FileAccess.file_exists("res://assets/music/" + cue.file), "file " + slug)
  var stream = load("res://assets/music/" + cue.file)
  verify(stream is AudioStreamOggVorbis and absf(stream.get_length() - cue.length) < 0.01, "encoded length " + slug)
  d.cache[slug] = stream
  d.configure(slug)
  verify(stream.loop == cue.looping and is_equal_approx(stream.loop_offset, float(cue.loop_offset)), "runtime loop " + slug)
  verify(cue.loop_offset >= 0 and cue.loop_offset < cue.length, "offset " + slug)
  if cue.outro != null: verify(FileAccess.file_exists("res://assets/music/" + cue.outro), "outro " + slug)
 var config = ConfigFile.new()
 config.load("res://export_presets.cfg")
 for preset in ["preset.3", "preset.4"]:
  verify("assets/music/*" in str(config.get_value(preset, "exclude_filter")), "exclude " + preset)
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 root.add_child(table)
 for i in 4: await process_frame
 var public_state = table.music_public_state()
 verify(public_state.keys().size() == 5 and public_state.has_all(["players", "permanents", "played", "toctou", "time_travel"]), "public music schema")
 var script = FileAccess.get_file_as_string("res://scripts/ui/table.gd").split("func music_public_state() -> Dictionary:")[1]
 verify(not ".hand" in script and not ".deck" in script and not "effect_id" in script, "no hidden zones or copied effects")
 var authoritative = table.engine.state
 var mirrored = NetView.apply(NetView.build(table.engine, 0))
 table.engine.state = mirrored
 verify(table.music_public_state() == public_state, "online mirrored public board matches offline")
 table.engine.state = authoritative
 table.online_event({"kind": "soundtrack", "cue": "toctou", "seat": 1})
 verify(table.music_public_state().toctou, "online public TOCTOU event")
 table.music_event("turn_ended", 1)
 table.engine.state.active_seat = 0
 table.music_event("played", 0, "Oprah Wonka")
 verify(table.music_public_state().played == ["Oprah Wonka"], "public played event")
 table.engine.state.active_seat = 1
 table.music_event("turn_started", 1)
 table.music_event("turn_ended", 1)
 table.engine.state.active_seat = 0
 verify(table.music_public_state().played == ["Oprah Wonka"], "paused turn cue resumes after reaction")
 table.music_event("turn_ended", 0)
 verify(table.music_public_state().played.is_empty(), "turn ended clears cues")
 table.music_event("time_travel", 0)
 table.music_event("turn_ended", 0)
 verify(table.music_public_state().time_travel, "Time Travel survives original turn")
 table.music_event("turn_started", 0)
 table.music_event("turn_ended", 0)
 verify(not table.music_public_state().time_travel, "Time Travel ends after extra turn")
 table.music_event("toctou", 1)
 table.music_event("turn_started", 1)
 verify(table.music_public_state().toctou, "TOCTOU through reaction start")
 table.music_event("turn_ended", 1)
 verify(not table.music_public_state().toctou, "TOCTOU reaction ends")
 table.queue_free()
 d.queue_free()
 await process_frame
 print("v23 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
