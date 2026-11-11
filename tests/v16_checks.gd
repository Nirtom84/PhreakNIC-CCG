extends SceneTree
var checks = 0
var failures = 0
var backups = {}
class FakeAPI extends Node:
 var calls = []
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body})
  return {"status": 200, "data": {"rooms": []}} if method == HTTPClient.METHOD_GET else {"status": 400, "data": {"error": "test"}}
class SessionSpy extends OnlineSession:
 var calls = []
 func lobby(action: String, fields: Dictionary = {}): calls.append({"action": action, "fields": fields})
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 run.call_deferred()
func _finalize():
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
func verify(value, text):
 checks += 1
 if not value: failures += 1; print("FAIL: ", text)
func frames(n = 3):
 for i in n: await process_frame
func options(node: Node) -> Array:
 var result = []
 if node is OptionButton and node.name == "BotPace": result.append(node)
 for child in node.get_children(): result.append_array(options(child))
 return result
func select(choice, index):
 choice.select(index)
 choice.item_selected.emit(index)
func run():
 var settings = root.get_node("Sfx")
 var cfg = ConfigFile.new()
 verify(settings.migrated_pace(cfg) == 0.5, "Missing preference defaults")
 for legacy in [false, true]:
  cfg.set_value("game", "bot_fast", legacy)
  verify(settings.migrated_pace(cfg) == (0 if legacy else 0.5), "Legacy bool migration")
 for old in 3:
  cfg.set_value("game", "bot_speed", old)
  verify(settings.migrated_pace(cfg) == [0.5, 0.25, 0][old], "Legacy speed migration")
  verify(settings.saved_pace({"bot_speed": float(old)}) == [0.5, 0.25, 0][old], "JSON numeric migration")
 for pair in [[-2,0], [0.2,0.25], [0.4,0.5], [1.3,1.5], [2.7,3], [8,5], [NAN,0.5], ["bad",0.5]]:
  verify(settings.nearest(pair[0]) == pair[1], "Nearest allowed pace")
 cfg.set_value("game", "bot_pace", 1.3)
 verify(settings.migrated_pace(cfg) == 1.5, "Pace overrides legacy and snaps")
 var labels = ["Instant", "0.25 s per card", "0.5 s per card", "1 s per card", "1.5 s per card", "2 s per card", "3 s per card", "5 s per card"]
 for i in settings.BOT_PACES.size():
  var pace = settings.BOT_PACES[i]
  verify(settings.pace_label(pace) == labels[i], "Pace label")
  settings.bot_pace = pace
  settings.save()
  var restored = load("res://scripts/ui/sfx.gd").new()
  root.add_child(restored)
  verify(restored.bot_pace == pace, "Pace persisted")
  restored.free()
 settings.bot_pace = 0
 settings.auto_end_turn = false
 settings.visual_effects = false
 var main = load("res://scenes/menu.tscn").instantiate()
 root.add_child(main)
 await frames()
 verify(options(main).size() == 1, "Main menu dropdown")
 if not options(main).is_empty():
  var choice = options(main)[0]
  verify(choice.item_count == 8 and choice.get_item_text(7) == labels[7], "All dropdown entries")
  select(choice, 4)
  verify(settings.bot_pace == 1.5, "Main menu selection applies")
 main.free()
 var table = load("res://scenes/table.tscn").instantiate()
 table.bot_pace = 0
 table.auto_drive = false
 table.seed_value = 41
 root.add_child(table)
 await frames()
 while table.engine.active().is_bot: await table.drive_reaction(table.engine.active())
 table.bot_pace = 5
 verify(table.spotlight_timeout() == 14, "Slow bot row timeout covers action gaps")
 table.bot_pace = 0
 verify(table.spotlight_timeout() == 6, "Instant row keeps six second timeout")
 table.menu()
 verify(options(table.game_menu).size() == 1, "In-game menu dropdown")
 select(options(table.game_menu)[0], 3)
 verify(table.bot_pace == 1 and settings.bot_pace == 1, "In-game selection applies")
 table.close_menu()
 table.open_pace_popup()
 verify(options(table.pace_popup).size() == 1, "Toolbar opens dropdown popup")
 select(options(table.pace_popup)[0], 1)
 verify(table.bot_pace == 0.25 and settings.bot_pace == 0.25 and table.speed_button.text == "» 0.25 s", "Toolbar selection applies")
 table.pace_popup.hide()
 verify(table.save_game(), "New pace save writes")
 var saved = SaveGame.read()
 verify(not saved.is_empty() and saved.table.bot_pace == 0.25 and not saved.table.has("fast") and not saved.table.has("bot_speed"), "Save stores only pace")
 if not saved.is_empty():
  for legacy in [{"bot_speed": 0}, {"bot_speed": 1}, {"bot_speed": 2}, {"fast": true}, {"fast": false}]:
   var payload = saved.duplicate(true)
   payload.table.erase("bot_pace")
   payload.table.merge(legacy, true)
   var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
   file.store_string(JSON.stringify(payload))
   file.close()
   var loaded = SaveGame.read()
   verify(not loaded.is_empty(), "Old save accepted")
   if loaded.is_empty(): continue
   var resumed = load("res://scenes/table.tscn").instantiate()
   resumed.auto_drive = false
   resumed.resume_data = loaded
   root.add_child(resumed)
   await frames()
   verify(resumed.bot_pace == settings.saved_pace(legacy), "Old save loads migrated pace")
   resumed.free()
 # Real engine events populate the recap, including more cards than can remain visible.
 table.bot_pace = 0
 await table.engine.end_turn(table.engine.active())
 var bot = table.engine.active()
 table.engine.deciders[bot.seat] = BotDecider.new(table.engine, 1)
 var k = 12
 for i in k:
  var card = CardInstance.new(90000 + i, "Hacking", bot.seat)
  bot.hand.append(card)
  await table.engine.play_card(bot, card)
 await table.engine.end_turn(bot)
 verify(table.recap_active and table.recap_count == k, "Human turn retains all counted plays")
 verify(table.spotlights.size() == table.SPOTLIGHT_THUMBS + 1, "Recap bounds visible cards")
 for panel in table.spotlights:
  verify(panel.get_child(0).get_child(0).custom_minimum_size == table.SPOTLIGHT_SMALL and not panel.get_child(0).get_child(1).visible, "Every recap card is thumbnail")
  verify(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Recap ignores clicks")
 verify(table.recap_chip.text == table.seat_name(bot.seat) + "'s turn: 12 cards · tap to dismiss", "Recap caption")
 table.recap_elapsed = 3
 await frames()
 verify(table.recap_active, "Recap remains beyond three seconds")
 var clicked = [false]
 var button = Button.new()
 button.position = Vector2(40, 40)
 button.size = Vector2(160, 90)
 button.z_index = 100
 table.add_child(button)
 button.pressed.connect(func(): clicked[0] = true)
 await frames()
 var press = InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.position = Vector2(60, 60)
 press.pressed = true
 root.push_input(press, true)
 await frames(1)
 press = press.duplicate()
 press.pressed = false
 root.push_input(press, true)
 await frames()
 verify(not table.recap_active and clicked[0], "First press dismisses without consuming button click")
 table.begin_recap()
 # Rebuild a recap using an opponent event, as in the online handler.
 table.engine.state.active_seat = bot.seat
 table.spotlight("Hacking", "Other")
 table.engine.state.active_seat = table.human_seat
 table.begin_recap()
 verify(table.recap_chip.text.begins_with("Since your turn: 13 cards"), "Several opponents caption")
 table.decision("Test", ["Close"], [], 1, 1, false)
 verify(not table.recap_active, "Decision opening dismisses recap")
 table.answered.emit(0)
 await frames()
 table.end_recap_turn()
 verify(table.recap_count == 0, "Human turn end resets count")
 for reduced in [false, true]:
  settings.visual_effects = not reduced
  table.engine.state.active_seat = bot.seat
  table.spotlight("Hacking", "Other")
  table.engine.state.active_seat = table.human_seat
  table.begin_recap()
  verify(table.recap_active, "Recap with motion preference")
  table.recap_elapsed = 20
  table._process(0)
  verify(not table.recap_active and table.spotlights.is_empty(), "Recap expires at twenty seconds")
  table.end_recap_turn()
 table.engine.state.active_seat = bot.seat
 table.online_event({"kind": "played", "seat": bot.seat, "id": "Hacking"})
 table.engine.state.active_seat = table.human_seat
 table.online_event({"kind": "turn_started", "seat": table.human_seat})
 verify(table.recap_active and table.recap_count == 1, "Online events produce recap")
 var key = InputEventKey.new()
 key.pressed = true
 key.keycode = KEY_A
 table._input(key)
 verify(not table.recap_active, "Key press dismisses recap")
 table.begin_recap()
 var touch = InputEventScreenTouch.new()
 touch.pressed = true
 table._input(touch)
 verify(not table.recap_active, "Touch press dismisses recap")
 table.online_event({"kind": "turn_ended", "seat": table.human_seat})
 verify(table.recap_count == 0, "Online human end resets counter")
 # The actual local driver reads a changed dropdown value before its next action.
 table.engine.state.active_seat = bot.seat
 bot.hand.clear()
 for i in 2: bot.hand.append(CardInstance.new(99000 + i, "Hacking", bot.seat))
 table.engine.state.center_row.clear()
 table.open_pace_popup()
 select(options(table.pace_popup)[0], 1)
 var local_times = []
 var local_delays = []
 var on_play = func(_p, _c):
  local_times.append(Time.get_ticks_msec())
  local_delays.append(table.last_bot_action_delay)
  if local_times.size() == 1: select(options(table.pace_popup)[0], 0)
 table.engine.card_played.connect(on_play)
 await table.drive_reaction(bot)
 table.engine.card_played.disconnect(on_play)
 verify(local_times.size() == 2, "Local driver plays both cards")
 if local_times.size() == 2:
  verify(local_delays[0] == 0.25, "Selected dropdown pace delays next action")
  verify(local_delays[1] == 0 and settings.bot_pace == 0, "Changing dropdown mid-turn affects following action")
 table.free()
 await online_checks()
 await server_checks()
 print("v16 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func online_checks():
 var api = FakeAPI.new()
 root.add_child(api)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 root.add_child(online)
 await frames()
 select(online.bot_pace_choice, 6)
 await online.create_game()
 verify(api.calls[-1].body.bot_pace == 3, "Create form sends selected pace")
 var session = SessionSpy.new()
 root.add_child(session)
 session.credential = {"seat": 0}
 online.session = session
 var room = {"code": "ABCD", "host_seat": 0, "started": false, "public": true, "card_pool": "2026", "starting_life": 20, "bot_pace": 1.5, "seats": [{"name": "Host", "hero": "", "bot": false, "difficulty": 0}, {"name": "Bot", "hero": "", "bot": true, "difficulty": 1}]}
 online.lobby(room)
 await frames()
 verify(options(online.content).size() == 1, "Host lobby pace dropdown")
 select(options(online.content)[0], 7)
 verify(session.calls[-1].fields.bot_pace == 5, "Host lobby sends selected pace")
 session.credential.seat = 1
 online.lobby(room)
 await frames()
 verify(options(online.content).is_empty(), "Guest cannot edit pace")
 online.free()
 session.free()
 api.free()
func server_checks():
 var link = LinkServer.new()
 root.add_child(link)
 var setup = {"t": "setup", "seats": [{"bot": false}, {"bot": false}]}
 for invalid in ["0.5", true, null, 0.1, -1, 6]:
  var data = setup.duplicate(true)
  data.bot_pace = invalid
  link._receive(data)
  verify(link.game == null, "Link refuses invalid pace")
 for pace in [null, 0, 0.25, 0.5, 1, 1.5, 2, 3, 5]:
  var data = setup.duplicate(true)
  if pace != null: data.bot_pace = pace
  link._receive(data)
  verify(link.game != null and link.game.bot_pace == (0.5 if pace == null else pace), "Link accepts allowed pace and defaults missing field")
  link.game.running = false
 link.free()
 for scenario in [{"pace": 0.0, "takeover": false}, {"pace": 0.25, "takeover": false}, {"pace": 0.25, "takeover": true}]:
  var pace = scenario.pace
  var server = GameServer.new()
  root.add_child(server)
  server.setup([{"bot": not scenario.takeover}, {"bot": false}], "2026", 10000, 41, [], pace)
  if scenario.takeover:
   server.idle_bot[0] = true
   server.engine.deciders[0] = BotDecider.new(server.engine, 1)
   server.engine.state.players[0].difficulty = 1
  server.engine.state.active_seat = 0
  var bot = server.engine.active()
  bot.hand.clear()
  for i in 2: bot.hand.append(CardInstance.new(95000 + i, "Hacking", 0))
  server.engine.state.center_row.clear()
  var times = []
  server.engine.card_played.connect(func(_p, _c): times.append(Time.get_ticks_msec()))
  if scenario.takeover: await server._drive()
  else: await server._drive_reaction(bot)
  verify(times.size() == 2, "Server drove two cards")
  if times.size() == 2: verify(times[1] - times[0] >= (240 if pace else 0) and (pace > 0 or times[1] - times[0] < 200), "Server waits configured pace")
  server.free()
 var original = GameServer.new()
 root.add_child(original)
 original.setup([{"bot": false}, {"bot": false}], "2026", 20, 41, [], 3)
 await original.start()
 var data = original.last_snapshot.duplicate(true)
 verify(not data.is_empty(), "Server checkpoints paced room")
 if not data.is_empty():
  var restored = GameServer.new()
  root.add_child(restored)
  verify(restored.restore(data) and restored.bot_pace == 3, "Restored room retains pace")
  restored.free()
  data.erase("bot_pace")
  restored = GameServer.new()
  root.add_child(restored)
  verify(restored.restore(data) and restored.bot_pace == 0.5, "Older snapshot defaults pace")
  restored.free()
 original.free()
