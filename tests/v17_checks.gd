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
## One cell of a stats table, found by row title and column header; "" if the row isn't shown.
func record_cell(screen: Node, row_title: String, column: String) -> String:
 for grid in screen.find_children("*", "GridContainer", true, false):
  var cells = grid.get_children().filter(func(c): return c is Label)
  var row = cells.map(func(c): return c.text).find(row_title)
  if row < 0: continue
  var col = cells.slice(0, grid.columns).map(func(c): return c.text).find(column)
  return cells[row + col].text if col >= 0 and row + col < cells.size() else ""
 return ""
func run():
 Store = load("res://scripts/ui/lifetime_stats.gd")
 Share = load("res://scripts/ui/result_share.gd")
 style = load("res://scripts/ui/style.gd")
 var backups = {}
 for path in [Store.PATH, Store.PATH + ".tmp", Store.PATH + ".bad"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
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
 m.winner_seat = 1
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
 # A player with no Hero: the table names none with a dash, and neither the card nor the text says "as —".
 var no_hero = table.share_details(table.engine.state.players[0])
 no_hero.hero = ""
 no_hero.hero_name = table.stats_card_name("")
 result = Share.build_card(no_hero)
 verify(not "as —" in labels(result), "Result card without a Hero")
 result.free()
 verify(not "as —" in Share.copy_text(no_hero), "Result copy text without a Hero")
 verify(Share.copy_text({"victory": true, "all_bots": true, "difficulty": "Elite", "opponents": ["A", "B"], "turns": 14, "hero_name": "—", "version": "0.15", "damage": 38}) == "I beat 2 bots on Elite in 14 turns in PhreakNIC CCG v0.15 — 38 damage dealt. https://phreaknic-ccg.net", "Exact copy text without a Hero")
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
 # A stalemate (no winner) is a draw: a game, but neither a win nor a loss, and a win streak carries on.
 s.reset()
 m.winner_seat = 0
 s.record(m, 0, "", "local", "before draw")
 m.winner_seat = -1
 verify(s.record(m, 0, "", "local", "draw"), "Record draw")
 verify(s.data.games == 2 and s.data.wins == 1 and s.data.losses == 0 and s.data.modes.local.losses == 0, "A draw is not a loss")
 verify(s.data.streak == 1 and s.data.best_streak == 1 and s.data.modes.local.streak == 1, "A draw keeps the win streak")
 screen = load("res://scripts/ui/stats_screen.gd").open(root)
 await frames()
 verify(record_cell(screen, "Against bots", "Games") == "2" and record_cell(screen, "Against bots", "Losses") == "0", "Stats screen shows a draw as a game, not a loss")
 screen.free()
 # Those games were played without a Hero.
 verify(Share.copy_text(s.share_details()) == "My PhreakNIC CCG record: 1 wins in 2 games (50%), best streak 1. https://phreaknic-ccg.net", "Stats copy text without a Hero")
 # A game rejoined mid-match: its stats only saw the last turn, but the records use all the turns you played.
 var rejoined = load("res://scripts/ui/match_stats.gd").new()
 rejoined.setup(2, "2026", [-1, 0], true)
 rejoined.turn(0)
 var players = [PlayerState.new(0), PlayerState.new(1)]
 players[0].turns = 6
 players[1].turns = 5
 rejoined.finish(0, players)
 s.reset()
 s.record(rejoined, 0, "", "online_bots", "rejoined")
 verify(s.data.fastest_win == 6 and s.average_win_turns() == 6 and s.data.longest_game == 6, "A rejoined win counts all the turns you played")
 # Online custom-deck games count in the Experimental decks tab, but not under a bot difficulty
 # (human seats have difficulty -1 online).
 var custom = load("res://scripts/ui/match_stats.gd").new()
 custom.setup(2, "custom", [-1, -1])
 custom.custom_deck = load("res://scripts/ui/deck_builder.gd").builtins()[0]
 custom.finish(0, players)
 s.reset()
 verify(s.record(custom, 0, "", "online_humans", "online custom"), "Record online custom-deck game")
 var experimental = s.experimental()
 verify(experimental.games == 1 and experimental.decks[custom.custom_deck.name].games == 1 and experimental.difficulties.is_empty(), "Online custom-deck game is not filed under a bot difficulty")
 custom.bot_difficulties = [-1, 2]
 verify(s.record(custom, 0, "", "local", "offline custom") and s.experimental().difficulties.keys() == ["2"], "Offline custom-deck game goes by bot difficulty")
 custom.winner_seat = -1
 s.record(custom, 0, "", "local", "custom draw")
 verify(s.experimental().games == 3 and s.experimental().wins == 2 and s.experimental().losses == 0, "Custom-deck draw is not a loss")
 screen = load("res://scripts/ui/stats_screen.gd").open(root)
 await frames()
 buttons(screen, "Experimental decks")[0].pressed.emit()
 await frames()
 verify("offline and online games" in labels(screen.content), "Experimental decks tab covers online games too")
 screen.free()
 s.reset()
 style.compact_override = null
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("v17 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
