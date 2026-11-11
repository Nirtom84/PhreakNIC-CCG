extends SceneTree
var checks = 0
var failures = 0
var backups = {}
func _initialize(): run.call_deferred()
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func serialized(state) -> String:
 return JSON.stringify(SaveGame.snapshot(state))
func clone_engine(engine):
 var copy = GameEngine.new()
 root.add_child(copy)
 copy.state = SaveGame.restore(JSON.parse_string(serialized(engine.state)))
 if copy.state != null:
  for p in copy.state.players: copy.deciders.append(BotDecider.new(copy, p.difficulty))
 return copy
func round_trips():
 for count in [2, 3, 4]:
  for seed_value in range(1, 13):
   var engine = GameEngine.new()
   root.add_child(engine)
   var levels = []
   for i in count: levels.append((seed_value + i) % 3)
   engine.setup(levels, seed_value)
   await engine.start_turn()
   for turn in seed_value % count:
    await BotPlayer.new(engine).take_turn(engine.active())
   # Save after a varying number of actual mid-turn plays.
   for action in seed_value % 5:
    var p = engine.active()
    var playable = p.hand.filter(func(c): return engine.can_play(p, c))
    if playable.is_empty(): break
    await engine.play_card(p, playable[0])
   if engine.state.finished: engine.free(); continue
   verify(SaveGame.safe(engine, engine.active().seat), "Safe mid-turn phase")
   var copy = clone_engine(engine)
   verify(copy.state != null, "Restore seed %d seats %d" % [seed_value, count])
   if copy.state == null: engine.free(); copy.free(); continue
   verify(serialized(engine.state) == serialized(copy.state), "Exact JSON round trip")
   for turn in 200:
    if engine.state.finished: break
    await BotPlayer.new(engine).take_turn(engine.active())
    await BotPlayer.new(copy).take_turn(copy.active())
    verify(serialized(engine.state) == serialized(copy.state), "Identical continued turn seed %d turn %d" % [seed_value, turn])
   verify(engine.state.finished and copy.state.finished, "Both games finish")
   verify(engine.state.rng.randi() == copy.state.rng.randi(), "Identical next RNG draw")
   engine.free()
   copy.free()
func focused():
 var e = GameEngine.new()
 root.add_child(e)
 e.setup([-1, 1, 2], 42, [BotDecider.new(e, 1)])
 await e.start_turn(0)
 var p = e.active()
 p.turn_flags = {"bought": 1, "acquired": 2, "reserved": false, "tips": true, "no_buy": false, "reductions": {"Hero": 2}, "free_names": ["Hacker", "Hacker"], "demartian": 2, "matrix": true, "super_ronk": true, "combos": {0: true, 2: true}, "zenthere": true}
 var grass = e.state.all_cards().filter(func(c): return c.id == "Touch Grass")[0]
 e.gain_owner(grass, p)
 e.move(grass, p.play_area, "play_area")
 grass.flags = {"used": true, "expires": p.turns + 1}
 var roll = e.state.all_cards().filter(func(c): return c.id == "Rickroll")[0]
 e.gain_owner(roll, p)
 e.move(roll, p.discard, "discard")
 p.turn_flags.rickroll = roll
 var once = e.state.all_cards().filter(func(c): return c.id == "Tableskirts")[0]
 e.gain_owner(once, p)
 e.move(once, p.play_area, "play_area")
 await e.activate(p, once)
 verify(once.flags.get("used", false), "Once-per-turn ability used before save")
 var ice = e.state.all_cards().filter(func(c): return c.id == "Walmart Parking Lot")[0]
 e.gain_owner(ice, p)
 e.move(ice, p.play_area, "play_area")
 ice.counters = 4
 var child = p.hand[0]
 e.move(child, grass.attached, "attached")
 grass.counters = 7
 var virtual = CardInstance.new(-roll.uid, roll.id, p.seat)
 virtual.flags = {"virtual": true, "host": grass, "copy_id": "Hacking"}
 var virtual2 = CardInstance.new(-roll.uid, roll.id, p.seat)
 virtual2.flags = virtual.flags.duplicate()
 p.played = [roll, virtual, virtual2, virtual]
 e.state.players[2].alive = false
 e.state.players[2].life = 0
 e.state.players[1].turn_flags.prevent_all = true
 e.state.extra_turns = [0, 1, 0]
 var copy = clone_engine(e)
 verify(copy.state != null, "Focused mid-turn restore")
 if copy.state != null:
  var q = copy.active()
  verify(serialized(e.state) == serialized(copy.state), "Flags, reductions, free buys, expiry, ICE and eliminated seat preserved")
  var restored_once = q.play_area.filter(func(c): return c.id == "Tableskirts")[0]
  verify(not copy.activatable_abilities(q, restored_once)[0].enabled, "Used ability stays unavailable")
  verify(copy.effective_cost(q, q.turn_flags.rickroll) == e.effective_cost(p, roll), "Active reductions preserve effective cost")
  verify(q.played[1] != q.played[2] and q.played[1] == q.played[3], "Repeated virtual objects keep identity independently of UID")
  verify(q.turn_flags.rickroll == q.played[0], "Rickroll reference preserved")
  verify(q.played[1].flags.host.attached.size() == 1, "Host and recursive attachment references preserved")
  await e.buy_card(p, e.state.center_row.filter(func(c): return c != null)[0], true)
  await copy.buy_card(q, copy.state.center_row.filter(func(c): return c != null)[0], true)
  verify(serialized(e.state) == serialized(copy.state), "Rickroll replacement continues identically")
  await e.end_turn(p)
  await copy.end_turn(q)
  verify(serialized(e.state) == serialized(copy.state), "Queued extra turn continues identically")
  await e.end_turn(e.active())
  await copy.end_turn(copy.active())
  verify(serialized(e.state) == serialized(copy.state), "Touch Grass expiry continues identically")
  verify(grass in e.state.removed, "Touch Grass actually expires")
 e.busy = true
 verify(not SaveGame.safe(e, e.active().seat), "Busy refused")
 e.busy = false
 e.reaction_depth = 1
 verify(not SaveGame.safe(e, e.active().seat), "Reaction refused")
 e.reaction_depth = 0
 e.simultaneous_depth = 1
 verify(not SaveGame.safe(e, e.active().seat), "Simultaneous damage refused")
 e.simultaneous_depth = 0
 e.state.active_seat = 1
 verify(not SaveGame.safe(e), "Bot turn refused")
 e.free()
 copy.free()
func find_button(node, text: String):
 if node is Button and node.text == text: return node
 for child in node.get_children():
  var result = find_button(child, text)
  if result != null: return result
 return null
func invalid_files(saved):
 for defect in ["reference", "card_id", "duplicate", "next_uid", "bot_phase", "version"]:
  var bad = JSON.parse_string(JSON.stringify(saved))
  match defect:
   "reference": bad.game.state.center_deck[0] = {"ref": 999999}
   "card_id":
    for record in bad.game.objects:
     if record.type == "card": record.data.id = "missing card"; break
   "duplicate": bad.game.state.center_deck[0] = bad.game.state.center_deck[1]
   "next_uid": bad.game.state.next_uid = 1
   "bot_phase": bad.game.state.active_seat = 1
   "version": bad.version = 0
  var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
  file.store_string(JSON.stringify(bad))
  file.close()
  verify(SaveGame.read().is_empty(), "Invalid file rejected: " + defect)
 var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
 file.store_string(JSON.stringify(saved))
 file.close()
func ui():
 var settings = root.get_node("Sfx")
 settings.auto_end_turn = false
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.seed_value = 41
 table.fast = true
 root.add_child(table)
 current_scene = table
 await process_frame
 while table.engine.active().is_bot: await table.drive_reaction(table.engine.active())
 verify(table.can_save(), "Table safe")
 for card in table.engine.active().hand.duplicate():
  if table.engine.can_play(table.engine.active(), card): await table.engine.play_card(table.engine.active(), card)
 var hp = table.engine.state.players[table.human_seat]
 var botnet = table.engine.state.all_cards().filter(func(c): return c.id == "Botnet")[0]
 table.engine.gain_owner(botnet, hp)
 table.engine.move(botnet, hp.play_area, "play_area")
 var hacking_before = hp.hacking
 var life_before = hp.life
 var hand_before = hp.hand.size()
 settings.auto_botnet = true
 await table.auto_activate_botnet()
 var botnets = table.engine.controlled(hp, "Botnet").size()
 var gain = botnets * botnets + hp.play_area.filter(func(c): return c.effect_id() == "Tableskirts" or c.effect_id() == "Unattended Phone").size(); verify(hp.hacking == hacking_before + gain, "Auto-activate granted +%d hacking" % gain); verify(hp.life == life_before + hp.play_area.filter(func(c): return c.effect_id() == "The Big Dipper").size(), "Auto-activate granted life from The Big Dipper"); verify(hp.hand.size() == hand_before + hp.play_area.filter(func(c): return c.effect_id() == "Shell Speech").size(), "Auto-activate drew cards from Shell Speech")
 settings.save()
 var ab_config = ConfigFile.new()
 ab_config.load("user://settings.cfg")
 verify(ab_config.get_value("game", "auto_botnet", false) == true, "Auto-activate Botnet persists")
 settings.auto_botnet = false
 settings.save()
 for viewport_size in [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1920, 1440)]:
  table.size = viewport_size
  await process_frame
  table.menu()
  await process_frame
  await process_frame
  var panel = table.game_menu.get_child(0)
  verify(panel.get_global_rect().end.x <= viewport_size.x and panel.get_global_rect().end.y <= viewport_size.y, "Menu fits viewport " + str(viewport_size))
  verify(panel.size.y < viewport_size.y * 0.8, "In-game menu sizes to content")
  verify(panel.position.y >= table.menu_button.global_position.y + table.menu_button.size.y, "Menu anchored below toolbar")
  table.close_menu()
  await process_frame
 table.menu_button.pressed.emit()
 verify(is_instance_valid(table.game_menu), "Toolbar opens menu")
 table.menu_button.pressed.emit()
 verify(table.game_menu == null, "Toolbar closes menu")
 table.go_back()
 verify(is_instance_valid(table.game_menu), "Back opens menu")
 await process_frame
 var sound = find_button(table.game_menu, "Sound enabled")
 sound.button_pressed = not sound.button_pressed
 verify(settings.muted == not sound.button_pressed, "Sound applies live")
 var config = ConfigFile.new()
 config.load("user://settings.cfg")
 verify(config.get_value("sound", "muted") == settings.muted, "Sound persisted")
 var effects = find_button(table.game_menu, "Visual effects")
 effects.button_pressed = not effects.button_pressed
 verify(settings.visual_effects == effects.button_pressed, "Effects apply live")
 var auto_end = find_button(table.game_menu, "Auto-end turn")
 auto_end.button_pressed = not auto_end.button_pressed
 verify(settings.auto_end_turn == auto_end.button_pressed, "Auto-end applies live")
 settings.auto_end_turn = false
 var speed = table.bot_speed
 table.toggle_speed()
 verify(table.bot_speed == (speed + 1) % 3 and settings.bot_speed == table.bot_speed and table.speed_button.text == "» " + ["Normal", "Fast", "Instant"][table.bot_speed], "Speed sync")
 table.pending = true
 table.update_save_button()
 verify(table.save_button.disabled and not table.save_game(), "Dialog save refused and disabled")
 table.pending = false
 table.close_menu()
 table.acting = true
 table.leave_game(false)
 await process_frame
 verify(table.pending, "Unsafe leave asks")
 var stay = find_button(table, "Stay")
 verify(stay != null, "Unsafe leave has Stay")
 if stay != null: stay.pressed.emit()
 await process_frame
 verify(table.is_inside_tree() and not table.pending, "Stay keeps game")
 table.acting = false
 table.menu()
 table.engine.busy = true
 table.update_save_button()
 verify(table.save_button.disabled and not table.save_game(), "Busy UI save refused")
 table.engine.busy = false
 table.acting = true
 verify(not table.save_game(), "Acting refused")
 table.acting = false
 table.driving = true
 verify(not table.save_game(), "Driving refused")
 table.driving = false
 table.go_back()
 verify(table.game_menu == null, "Back closes menu")
 table.append_log("Save regression log")
 var before = serialized(table.engine.state)
 var log_text = table.log_view.get_parsed_text()
 verify(not log_text.is_empty(), "Real card play produces displayed log")
 var names = table.seat_names.duplicate()
 var heroes = table.seat_heroes.duplicate()
 await table.leave_game(false)
 await process_frame
 await process_frame
 var menu_scene = current_scene
 menu_scene.start()
 await process_frame
 var confirmation = menu_scene.rules_overlay
 var asks = is_instance_valid(confirmation) and find_button(confirmation, "Keep my save") != null and find_button(confirmation, "Yes, new game") != null
 var label_found = false
 if is_instance_valid(confirmation):
  for node in confirmation.find_children("*", "Label", true, false):
   if node.text == "Start a new game? Your saved game will be replaced.": label_found = true
 verify(asks and label_found, "New game asks before replacing save")
 if asks: find_button(confirmation, "Keep my save").pressed.emit()
 await process_frame
 verify(not is_instance_valid(menu_scene.rules_overlay) and SaveGame.read().size() > 0, "Keeping the save closes the question and keeps the save")
 verify(find_button(menu_scene, "Resume game") != null, "Main menu shows Resume after leave")
 for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
  root.size = dimensions
  await process_frame
  await process_frame
  var bottom = find_button(menu_scene, "Quit")
  verify(bottom.get_global_rect().end.y <= dimensions.y, "Main menu bottom fits " + str(dimensions))
 var saved = SaveGame.read()
 verify(not saved.is_empty(), "Save file validates")
 invalid_files(saved)
 var resumed = load("res://scenes/table.tscn").instantiate()
 resumed.auto_drive = false
 resumed.resume_data = saved
 root.add_child(resumed)
 current_scene = resumed
 menu_scene.queue_free()
 await process_frame
 verify(serialized(resumed.engine.state) == before, "Resume does not set up or start a turn")
 verify(resumed.log_view.get_parsed_text() == log_text and resumed.seat_names == names and resumed.seat_heroes == heroes, "Resume restores log, names and avatars")
 resumed.engine.finish(resumed.engine.active())
 verify(not FileAccess.file_exists(SaveGame.PATH), "Game over removes save")
 resumed.queue_free()
 current_scene = null
 await process_frame
 for corrupt in ["{broken", '{"version":0}', JSON.stringify({"version": SaveGame.VERSION, "content": SaveGame.content(), "game": {}, "table": {}})]:
  var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
  file.store_string(corrupt)
  file.close()
  verify(SaveGame.read().is_empty(), "Corrupt/old file ignored")
func run():
 for path in ["user://settings.cfg", SaveGame.PATH]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 await round_trips()
 await focused()
 await ui()
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("Save checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
