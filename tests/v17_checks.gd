extends SceneTree
var checks = 0
var failures = 0
var Store
var Share
var style
func _initialize(): run.call_deferred()
func verify(value, text):
 checks += 1
 if not value: failures += 1; print("FAIL: ", text)
func frames():
 for i in 4: await process_frame
func labels(node: Node) -> String:
 var text = node.text + "\n" if node is Label or node is Button else ""
 for child in node.get_children(): text += labels(child)
 return text
func buttons(node: Node, title: String) -> Array:
 var found = []
 if node is Button and node.text == title: found.append(node)
 for child in node.get_children(): found.append_array(buttons(child, title))
 return found
func controls(node: Node):
 if node is Button: verify(node.custom_minimum_size.y >= 72, "Compact button: " + node.text)
 if node is Label: verify(node.get_theme_font_size("font_size") >= 22, "Compact label")
 for child in node.get_children(): controls(child)
func run():
 Store = load("res://scripts/ui/lifetime_stats.gd")
 Share = load("res://scripts/ui/result_share.gd")
 style = load("res://scripts/ui/style.gd")
 var s = Store.new()
 s.reset()
 verify(s.win_rate() == 0 and s.average_win_turns() == 0, "Empty divisions")
 var m = load("res://scripts/ui/match_stats.gd").new()
 m.setup(2, "2026", [-1, 2])
 var hero = style.heroes()[0]
 var card = "Elonka" if root.get_node("CardDB").cards.has("Elonka") else root.get_node("CardDB").cards.keys()[0]
 m.turn(0)
 m.damage(0, 1, 13)
 m.damage(1, 0, 4)
 m.gain(0, 3)
 m.played(0, card)
 m.bought(0, card, 5)
 m.duration = 123
 verify(not s.record(m, 0, hero, "local", "unfinished"), "Unfinished ignored")
 m.finished = true
 m.winner_seat = 0
 verify(s.record(m, 0, hero, "local", "win"), "Record win")
 verify(not s.record(m, 0, hero, "local", "win"), "Persistent key guard")
 verify(s.data.games == 1 and s.data.wins == 1 and s.data.best_streak == 1, "Win and streak")
 verify(s.data.modes.local.games == 1 and s.data.difficulties["2"].wins == 1 and s.data.players["2"].wins == 1 and s.data.sets["2026"].wins == 1 and s.data.heroes[hero].wins == 1, "Splits")
 for k in ["turns", "damage_dealt", "damage_taken", "life_gained", "cards_played", "cards_bought", "hacking_spent"]: verify(s.data[k] == m.seats[0][k], "Total " + k)
 verify(s.data.play_time == 123 and s.data.bought[card] == 1 and s.data.played[card] == 1, "Time and cards")
 m.winner_seat = -1
 s.record(m, 0, hero, "local", "loss")
 verify(s.data.losses == 1 and s.data.streak == 0 and s.data.best_streak == 1 and s.data.modes.local.streak == 0, "Loss resets streak")
 verify(s.data.biggest_hit == 13 and s.data.biggest_hit_date != "" and s.data.most_damage == 13 and s.data.fastest_win == 1 and s.data.fastest_hero == hero and s.data.fastest_date != "" and s.data.longest_game == 1, "Records and dates")
 verify(s.win_rate() == 50 and s.average_win_turns() == 1 and s.top("bought") == card, "Derived totals")
 verify(s.data.first_date == s.data.last_date and s.data.first_date != "", "First and last dates")
 var restored = Store.new()
 verify(restored.data == s.data, "Persistence round trip")
 verify(restored.favourite_hero() == hero and restored.top("stars") == m.star_card(0), "Derived favourites")
 restored.data.heroes[""] = {"games": 2, "wins": 2}
 verify(restored.favourite_hero() == "", "Hero win tie break")
 var d = s.share_details()
 verify(Share.copy_text(d) == "My PhreakNIC CCG record: 1 wins in 2 games (50%%), best streak 1, favourite Hero %s. https://phreaknic-ccg.net" % d.hero_name, "Copy exact text")
 verify(Share.filename({"year": 2026, "month": 11, "day": 11, "hour": 9, "minute": 2, "second": 3}, "stats") == "phreaknic-ccg-stats-20261111-090203.png", "Filename exact")
 var tree = Share.build_card(d)
 var text = labels(tree)
 for label in ["My record", "GAMES", "WINS", "WIN RATE", "50%", "BEST STREAK", "BIGGEST HIT", "phreaknic-ccg.net"]: verify(label in text, "Share label " + label)
 tree.free()
 d.signature = ""
 tree = Share.build_card(d)
 verify(not "SIGNATURE CARD" in labels(tree), "No empty signature")
 tree.free()
 verify(await Share.render_card(root, d) == null, "Headless null image")
 var screen = load("res://scripts/ui/stats_screen.gd").open(root)
 await frames()
 verify("2 games" in labels(screen) and "Lifetime stats" in labels(screen), "Populated screen")
 for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
  root.size = dimensions
  for compact in [false, true]:
   style.compact_override = compact
   style.touch_fit(screen)
   await frames()
   verify(screen.size.x <= dimensions.x and screen.size.y <= dimensions.y and screen.content.size.x <= dimensions.x - 64, "Populated screen fits")
   if compact: controls(screen)
 style.compact_override = false
 screen.confirm_reset()
 verify(screen.confirmation.visible, "Reset confirmation")
 screen.confirmation.canceled.emit()
 screen.confirmation.hide()
 verify(screen.store.data.games == 2, "Reset cancel preserves")
 screen.confirm_reset()
 screen.confirmation.confirmed.emit()
 screen.confirmation.hide()
 await frames()
 verify("No finished games yet." in labels(screen), "Reset empty state")
 for width in [1920, 2400]:
  root.size = Vector2i(width, 1080)
  for compact in [false, true]:
   style.compact_override = compact
   style.touch_fit(screen)
   await frames()
   verify(screen.size.x <= width and screen.size.y <= 1080, "Screen fits")
   if compact: controls(screen)
 var event = InputEventKey.new()
 event.keycode = KEY_ESCAPE
 event.pressed = true
 screen._unhandled_key_input(event)
 await frames()
 verify(not is_instance_valid(screen), "Escape closes")
 style.compact_override = false
 var main = load("res://scenes/menu.tscn").instantiate()
 root.add_child(main)
 await frames()
 verify(buttons(main, "Stats").size() == 1, "Menu Stats button")
 buttons(main, "Stats")[0].pressed.emit()
 await frames()
 verify(main.has_node("LifetimeStats"), "Menu opens screen")
 main.free()
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.bot_pace = 0
 table.lifetime_test_enabled = true
 root.add_child(table)
 await frames()
 table.record_lifetime()
 verify(Store.new().data.games == 0, "Unfinished table ignored")
 table.match_stats.finished = true
 table.match_stats.winner_seat = 0
 table.tutorial_mode = true
 table.record_lifetime()
 verify(Store.new().data.games == 0, "Tutorial ignored")
 table.tutorial_mode = false
 table.record_lifetime()
 table.record_lifetime()
 verify(Store.new().data.games == 1, "Table double record")
 table.game_over(table.engine.state.players[0])
 await frames()
 verify(Store.new().data.games == 1, "Summary rebuilding deduplicated")
 verify(buttons(table, "Lifetime stats").size() == 1, "Summary stats button")
 buttons(table, "Lifetime stats")[0].pressed.emit()
 await frames()
 verify(table.has_node("LifetimeStats"), "Summary opens stats")
 var result = Share.build_card(table.share_details(table.engine.state.players[0]))
 var result_text = labels(result)
 for label in ["Victory", "LIFE LEFT", "TURNS", "DAMAGE DEALT", "CARDS BOUGHT", "BIGGEST HIT", "phreaknic-ccg.net"]: verify(label in result_text, "Match card unchanged: " + label)
 result.free()
 table.show_result(table.engine.state.players[0])
 await frames()
 verify(Store.new().data.games == 1, "Rebuilt finished summary deduplicated")
 table.lifetime_recorded = false
 var session = OnlineSession.new()
 table.add_child(session)
 table.online_session = session
 table.engine.state.players[1].is_bot = false
 table.record_lifetime()
 verify(Store.new().data.modes.online_humans.games == 1, "Online human bucket")
 table.lifetime_recorded = false
 session.room = {"code": "TEST", "seed": 25}
 table.engine.state.players[1].is_bot = true
 table.record_lifetime()
 verify(Store.new().data.modes.online_bots.games == 1, "Online bot bucket")
 table.free()
 var lost = load("res://scenes/table.tscn").instantiate()
 lost.auto_drive = false
 lost.lifetime_test_enabled = true
 root.add_child(lost)
 await frames()
 lost.game_over(lost.engine.state.players[1])
 await frames()
 verify(Store.new().data.losses == 1 and Store.new().data.modes.local.losses == 1, "Scripted local loss through game over")
 lost.free()
 var f = FileAccess.open(Store.PATH, FileAccess.WRITE)
 f.store_string("garbage")
 f.close()
 s = Store.new()
 verify(s.data.games == 0 and FileAccess.file_exists(Store.PATH + ".bad"), "Corrupt quarantine")
 var raw = {"games": -1, "wins": "bad", "best_streak": 1e30, "played": {"unknown": 5, card: -4}, "modes": {"local": {"games": []}}}
 for i in 10000: raw.played["unknown%d" % i] = 4
 f = FileAccess.open(Store.PATH, FileAccess.WRITE)
 f.store_string(JSON.stringify(raw))
 f.close()
 s = Store.new()
 verify(s.data.games == 0 and s.data.wins == 0 and s.data.best_streak == 0 and s.data.modes.local.games == 0 and s.data.played.size() == 1 and s.data.played[card] == 0, "Strict bounded fields")
 verify(Store.number(NAN) == 0 and Store.number(INF) == 0, "Nonfinite validation")
 s.reset()
 for i in 55: s.record(m, 0, hero, "local", "bounded%d" % i)
 verify(s.data.keys.size() == 50 and s.data.keys[0] == "bounded5", "Last fifty keys only")
 verify(Store.new().data.keys.size() == 50, "Bounded keys persist")
 var saved_stats = m.to_dict()
 for seat in saved_stats.seats: seat.erase("bought")
 verify(m.from_dict(saved_stats) != null, "Legacy match stats remain loadable")
 s.reset()
 style.compact_override = null
 print("v17 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
