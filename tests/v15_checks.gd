extends SceneTree
var checks = 0
var failures = 0
var backups = {}
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 call_deferred("run")
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
func run():
 var settings = root.get_node("Sfx")
 var style = load("res://scripts/ui/style.gd")
 var script = load("res://scripts/ui/sfx.gd")
 var config = ConfigFile.new()
 verify(script.migrated_speed(config) == 0, "Default normal speed")
 for old in [false, true]:
  config.set_value("game", "bot_fast", old)
  verify(script.migrated_speed(config) == (2 if old else 0), "Legacy speed migration")
 config.set_value("game", "bot_speed", 1)
 verify(script.migrated_speed(config) == 1, "New speed overrides legacy")
 for value in [-1, 3, "1", true]:
  config.set_value("game", "bot_speed", value)
  verify(script.migrated_speed(config) == 2, "Invalid speed uses migration")
 for speed in 3:
  settings.bot_speed = speed
  settings.music_volume = 0.23
  settings.music_muted = true
  settings.save()
  var restored = script.new()
  root.add_child(restored)
  verify(restored.bot_speed == speed, "Speed persists")
  verify(is_equal_approx(restored.music_volume, 0.23) and restored.music_muted, "Music persists")
  restored.free()
 for invalid in [-1, 2, "0.5", true, INF, NAN]:
  verify(script.valid_volume(invalid, 0.35) == 0.35, "Invalid music volume")
 config = ConfigFile.new()
 config.set_value("sound", "music_volume", "bad")
 config.set_value("sound", "music_muted", 1)
 config.save("user://settings.cfg")
 var restored = script.new()
 root.add_child(restored)
 verify(restored.music_volume == 0.35 and not restored.music_muted, "Music settings validate on load")
 restored.free()
 var count = 0
 for file in DirAccess.get_files_at("res://assets/cards/mog"):
  if not file.ends_with(".jpg.import"): continue
  var text = FileAccess.get_file_as_string("res://assets/cards/mog/" + file)
  verify("compress/mode=1" in text and "compress/lossy_quality=0.8" in text, "Lossy Mog: " + file)
  count += 1
 verify(count == 48, "All Mog imports checked")
 var font_name = "JetBrainsMonoNerdFontMono-" + "ExtraBold.ttf"
 verify(not FileAccess.file_exists("res://assets/fonts/" + font_name) and not FileAccess.file_exists("res://assets/fonts/" + font_name + ".import"), "Unused font removed")
 verify(no_reference("res://scripts", font_name) and no_reference("res://scenes", font_name) and no_reference("res://assets", font_name) and font_name not in FileAccess.get_file_as_string("res://project.godot"), "Unused font unreferenced")
 for sound in ["card_play", "card_draw", "buy", "reserve", "shuffle", "button"]:
  verify(is_equal_approx(script.pitch_for(sound, 0), 0.94) and is_equal_approx(script.pitch_for(sound, 1), 1.06), "Pitch varies: " + sound)
 for sound in ["win", "lose", "turn_start", "your_turn", "warning", "eliminated", "damage", "life_gain", "hack", "ice"]:
  verify(script.pitch_for(sound, 0) == 1 and script.pitch_for(sound, 1) == 1, "Stable pitch: " + sound)
 for sound in ["your_turn.wav", "eliminated.wav", "warning.wav", "music_loop.ogg"]:
  verify(ResourceLoader.exists("res://assets/sounds/" + sound), "New audio imported: " + sound)
 var music = load("res://assets/sounds/music_loop.ogg")
 verify(music.loop and is_equal_approx(music.get_length(), 32.0), "Music loops for 32 seconds")
 verify(settings.pool.is_empty() and settings.music == null, "Headless creates no audio players")
 settings.visual_effects = false
 verify(style.motion(0.6) == 0, "Reduced motion")
 settings.visual_effects = true
 verify(style.motion(0.6) == 0.6, "Motion enabled")
 var target = Label.new()
 root.add_child(target)
 var tween = style.animation(target, true).set_loops()
 tween.tween_property(target, "modulate:a", 0.0, 1)
 settings.visual_effects = false
 settings.visuals_changed.emit(false)
 verify(not tween.is_valid() and target.modulate == Color.WHITE, "Live looping motion stops")
 target.free()
 settings.auto_end_turn = false
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.fast = true
 table.seed_value = 41
 root.add_child(table)
 await process_frame
 while table.engine.active().is_bot: await table.drive_reaction(table.engine.active())
 var human = table.engine.state.players[table.human_seat]
 var card = human.hand.filter(func(c): return table.engine.can_play(human, c))[0]
 var widget = table.card_widget(card, "hand", 100)
 verify(widget.find_child("LegalBadge", true, false) != null, "Playable hand has badge")
 verify(widget.find_child("LegalBadge", true, false).mouse_filter == Control.MOUSE_FILTER_IGNORE, "Badge ignores mouse")
 widget.free()
 await table.engine.play_card(human, card)
 widget = table.card_widget(card, "hand", 100)
 verify(widget.find_child("LegalBadge", true, false) == null, "Unplayable card has no badge")
 widget.free()
 for speed in 3:
  table.bot_speed = speed
  table.sync_options()
  verify(table.speed_button.text == "» " + ["Normal", "Fast", "Instant"][speed], "Speed label")
 # Stage 2: exercise the deferred path even on the headless test runner.
 settings.visual_effects = true
 table.bot_speed = 0
 table.redraw_now()
 await process_frame
 await process_frame
 table.synchronous_redraw = false
 var rebuilds = table.rebuild_count
 for i in 10: table.redraw()
 verify(table.rebuild_count == rebuilds, "Redraw requests are cheap")
 await process_frame
 verify(table.rebuild_count == rebuilds + 1, "Redraw requests coalesce per frame")
 table.synchronous_redraw = true
 var stable = human.hand[0]
 var stable_widget = table.shown_widgets[stable.uid]
 var stable_id = stable_widget.get_instance_id()
 table.redraw_now()
 verify(table.shown_widgets[stable.uid].get_instance_id() == stable_id, "Unchanged hand widget reused")
 verify(table.shown_widgets[stable.uid].get_child(0) in root.get_node("TouchInput").cards, "Reused widget stays registered for touch")
 var active_seat = table.engine.state.active_seat
 table.engine.state.active_seat = 1
 table.redraw_now()
 verify(table.shown_widgets[stable.uid].get_instance_id() != stable_id, "Illegal hand widget refreshed")
 verify(table.shown_widgets[stable.uid].find_child("LegalBadge", true, false) == null, "Illegal card loses badge")
 table.engine.state.active_seat = active_seat
 table.redraw_now()
 verify(table.shown_widgets[stable.uid].find_child("LegalBadge", true, false) != null, "Legal state refreshed")
 await create_timer(0.8).timeout
 var regex = RegEx.new()
 regex.compile("comes into play with ([0-9]+) ICE")
 for id in root.get_node("CardDB").cards:
  var found = regex.search(root.get_node("CardDB").cards[id].get("text", ""))
  var expected = int(found.get_string(1)) if found else 0
  verify(table.engine.effects.initial_ice(id) == expected and table.engine.effects.initial_ice(id) == expected, "ICE cache: " + id)
 for i in 3:
  verify(table.can_save() == table.can_save_uncached(), "Save cache parity")
  verify(table.nothing_left() == table.nothing_left_uncached(), "Action cache parity")
  var playable = human.hand.filter(func(c): return table.engine.can_play(human, c))
  if playable.is_empty(): break
  var played = playable[0]
  await process_frame
  var start = table.shown_widgets[played.uid].get_child(0).get_global_rect()
  await table.engine.play_card(human, played)
  await process_frame
  await process_frame
  var flights = table.ghosts.filter(func(g): return g.get_meta("uid") == played.uid)
  verify(not flights.is_empty(), "Played card has a ghost")
  if not flights.is_empty():
   verify(flights[0].get_meta("start_rect").position.distance_to(start.position) < 4, "Played ghost starts at card")
   var destination = table.shown_widgets[played.uid].get_child(0).get_global_rect() if table.shown_widgets.has(played.uid) else table.zone_anchors["0:discard"].get_global_rect()
   verify(flights[0].get_meta("end_rect").position.distance_to(destination.position) < 4, "Played ghost ends at destination")
  await create_timer(0.8).timeout
  verify(table.ghosts.is_empty(), "Played ghosts freed")
 human.hacking = 100
 table.redraw_now()
 await process_frame
 var bought = table.engine.state.center_row.filter(func(c): return c != null and table.engine.can_buy(human, c))[0]
 var start = table.shown_widgets[bought.uid].get_child(0).get_global_rect()
 await table.engine.buy_card(human, bought)
 verify(table.can_save() == table.can_save_uncached() and table.nothing_left() == table.nothing_left_uncached(), "Cache parity after buy")
 for busy_flag in ["pending", "acting", "driving"]:
  table.set(busy_flag, true)
  verify(table.can_save() == table.can_save_uncached() and table.nothing_left() == table.nothing_left_uncached(), "Cache parity: " + busy_flag)
  table.set(busy_flag, false)
 await process_frame
 await process_frame
 var flights = table.ghosts.filter(func(g): return g.get_meta("uid") == bought.uid)
 verify(not flights.is_empty(), "Bought card has a ghost")
 if not flights.is_empty():
  verify(flights[0].get_meta("start_rect").position.distance_to(start.position) < 4, "Buy starts at center card")
  verify(flights[0].get_meta("end_rect").position.distance_to(table.zone_anchors["0:discard"].get_global_rect().position) < 4, "Buy ends at discard")
 await create_timer(0.8).timeout
 verify(table.ghosts.is_empty(), "Buy ghosts freed")
 var opponent = table.engine.state.players[1]
 var hidden = opponent.hand[0]
 table.engine.move(hidden, opponent.play_area, "play_area")
 table.redraw_now()
 await process_frame
 await process_frame
 flights = table.ghosts.filter(func(g): return g.get_meta("uid") == hidden.uid)
 verify(not flights.is_empty(), "Opponent hand play has ghost")
 if not flights.is_empty(): verify(flights[0].texture == load(style.BACK), "Opponent hidden identity uses back")
 await create_timer(0.8).timeout
 for mode in [0, 1]:
  settings.visual_effects = mode == 1
  table.bot_speed = 2 if mode == 1 else 0
  var draw = human.deck.back()
  table.engine.move(draw, human.hand, "hand")
  table.redraw_now()
  await process_frame
  await process_frame
  verify(table.ghosts.is_empty(), "Reduced motion / Instant has no ghosts")
 # Legality explanations share the exact predicate used by the engine.
 var samples = 0
 var simulation = GameEngine.new()
 root.add_child(simulation)
 simulation.setup([0, 1, 2], 151503)
 var driver = BotPlayer.new(simulation)
 await simulation.start_turn()
 for round_index in 180:
  if simulation.state.finished:
   simulation.setup([0, 1, 2], 151503 + round_index)
   await simulation.start_turn()
  for player in simulation.state.players:
   for sample_card in player.hand + simulation.state.center_row + player.reserve:
    if sample_card == null: continue
    verify(simulation.can_play(player, sample_card) == simulation.why_not_play(player, sample_card).is_empty(), "Play reason consistency")
    verify(simulation.can_buy(player, sample_card) == simulation.why_not_buy(player, sample_card).is_empty(), "Buy reason consistency")
    samples += 1
  await driver.take_turn(simulation.active())
 verify(samples >= 2000, "At least 2000 legality samples across simulated turns")
 var buyer = simulation.active()
 var offer = simulation.state.center_row.filter(func(c): return c != null)[0]
 buyer.turn_flags.clear()
 for permanent in simulation.permanents().duplicate(): simulation.remove(permanent)
 buyer.hacking = -100
 verify(simulation.why_not_buy(buyer, offer).begins_with("Costs "), "Too expensive reason")
 var other = simulation.state.players[(buyer.seat + 1) % 3]
 verify(simulation.why_not_buy(other, offer) == "Not your turn", "Not your turn reason")
 var permanent_id = ""
 for id in simulation.db().cards:
  if simulation.db().get_card(id).kind == "Permanent": permanent_id = id; break
 var blocked_card = CardInstance.new(999901, permanent_id)
 buyer.hand.append(blocked_card)
 var blocker = CardInstance.new(999902, "Nashville 2600")
 buyer.play_area.append(blocker)
 verify(simulation.why_not_play(buyer, blocked_card) == "Nashville 2600 is in play: no one can play permanents", "Table rule reason")
 simulation.free()
 var original_open = table.log_open
 table.toggle_log()
 await process_frame
 verify(table.log_panel.visible == table.log_open and table.log_ticker.visible != table.log_open, "Log toggle visibility")
 verify(OnlineAPI.settings().get_value("ui", "log_open") == table.log_open, "Log preference persists")
 table.append_log("Latest ticker entry")
 verify(table.log_ticker.text == "Latest ticker entry", "Collapsed ticker text")
 if table.log_open != original_open: table.toggle_log()
 if not table.log_open: table.toggle_log()
 table.redraw_now()
 var width_card = human.hand[0]
 var open_hand_width = table.shown_widgets[width_card.uid].get_child(0).custom_minimum_size.x
 var market_card = table.engine.state.center_row.filter(func(c): return c != null)[0]
 var open_market_width = table.shown_widgets[market_card.uid].get_child(0).custom_minimum_size.x
 table.toggle_log()
 table.redraw_now()
 verify(table.shown_widgets[width_card.uid].get_child(0).custom_minimum_size.x > open_hand_width, "Hand grows when log closes")
 verify(table.shown_widgets[market_card.uid].get_child(0).custom_minimum_size.x > open_market_width, "Market grows when log closes")
 if human.play_area.is_empty() and human.reserve.is_empty():
  var frames = table.body.get_child(0).get_children().filter(func(c): return c.get("title") == "// YOUR RIG & RESERVED")
  verify(frames[0].size.y <= 64, "Empty rig is a slim placeholder")
 var desktop_card = human.hand.filter(func(c): return table.engine.can_play(human,c) and c.id == "Hacking")
 if not desktop_card.is_empty():
  table.card_clicked(desktop_card[0], "hand")
  await process_frame
  verify(desktop_card[0] not in human.hand, "Desktop single click plays immediately")
 table.engine.draw(human, 4)
 table.redraw_now()
 for dimensions in [Vector2i(1920,1080), Vector2i(2400,1080)]:
  root.size = dimensions
  style.compact_override = true
  table.redraw_now()
  await process_frame
  await process_frame
  check_buttons(table.body, Rect2(Vector2.ZERO, Vector2(dimensions)))
  for phone_widget in table.shown_widgets.values():
   if phone_widget.get_meta("zone") == "hand": verify(phone_widget.get_child(0).size.x >= 150, "Phone hand cards readable")
  var tap_card = human.hand.filter(func(c): return table.engine.can_play(human,c))
  if not tap_card.is_empty():
   var before_count = human.hand.size()
   table.selected_hand = null
   table.card_clicked(tap_card[0], "hand")
   verify(human.hand.size() == before_count and table.hand_selection != null, "Phone first tap selects and confirms")
   var play_actions: Array = []
   collect_buttons(table.hand_selection, play_actions)
   var confirmation = play_actions.filter(func(b): return b.text == "Play")[0]
   confirmation.pressed.emit()
   await process_frame
   verify(tap_card[0] not in human.hand, "Phone Play confirms selected card")
   table.clear_hand_selection()
  table.decision("Phone decision", ["Option A", "Option B"], [], 1, 1, false)
  await process_frame
  await process_frame
  check_buttons(table, Rect2(Vector2.ZERO, Vector2(dimensions)))
  table.answered.emit(0)
  await process_frame
  table.menu()
  await process_frame
  await process_frame
  check_buttons(table.game_menu, Rect2(Vector2.ZERO, Vector2(dimensions)))
  table.close_menu()
  var phone_menu = load("res://scripts/ui/menu.gd").new()
  root.add_child(phone_menu)
  phone_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  await process_frame
  await process_frame
  check_buttons(phone_menu, Rect2(Vector2.ZERO, Vector2(dimensions)))
  for path in phone_menu.hero_picker.loading_icons: ResourceLoader.load_threaded_get(path)
  phone_menu.free()
 style.compact_override = null
 table.free()
 await process_frame
 await stats_checks()
 star_card_checks()
 await tutorial_checks()
 countdown_checks()
 await emote_checks()
 await online_result_checks()
 print("v15 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func no_reference(path: String, needle: String) -> bool:
 for file in DirAccess.get_files_at(path):
  if file.get_extension() in ["gd", "tscn", "tres"] and needle in FileAccess.get_file_as_string(path + "/" + file): return false
 for directory in DirAccess.get_directories_at(path):
  if not no_reference(path + "/" + directory, needle): return false
 return true

func star_card_checks():
 # Starters (Hacker, Attack) are played most in every game, so they never count as the star card.
 var stats = load("res://scripts/ui/match_stats.gd").new()
 stats.setup(2, "2025", [0])
 var db = root.get_node("CardDB")
 var others = db.pool_ids("2025").filter(func(id): return not db.cards[id].get("starter", false))
 for i in 9: stats.played(0, "Hacking")
 for i in 4: stats.played(0, "Damage")
 verify(stats.star_card(0) == "", "Only starters played and nothing bought: no star card")
 stats.bought(0, others[0], 5)
 verify(stats.star_card(0) == others[0], "With no non-starter plays the priciest buy is the star card")
 stats.played(0, others[1])
 for i in 2: stats.played(0, others[2])
 verify(stats.star_card(0) == others[2], "The most-played non-starter card is the star card")
 verify(stats.seats[0].most_played_id == "Hacking" and stats.star_card(5) == "", "Raw most-played is unchanged and a bad seat is safe")
func check_buttons(node: Node, viewport: Rect2):
 var buttons: Array = []
 collect_buttons(node, buttons)
 for b in buttons:
  verify(b.size.y >= 72, "Phone button height: " + b.text)
  verify(viewport.encloses(b.get_global_rect()), "Phone button fits: " + b.text)
 for i in buttons.size():
  for j in range(i + 1, buttons.size()):
   verify(not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()), "Phone buttons do not overlap")
func collect_buttons(node: Node, result: Array):
 if node is Button and node.is_visible_in_tree():
  var clipped = false
  var parent = node.get_parent()
  while parent != null:
   if parent is ScrollContainer and not parent.get_global_rect().encloses(node.get_global_rect()): clipped = true
   parent = parent.get_parent()
  if not clipped: result.append(node)
 for child in node.get_children(): collect_buttons(child, result)

func stats_checks():
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.fast = true
 table.seed_value = 51
 root.add_child(table)
 await process_frame
 var engine = table.engine
 for p in engine.state.players: engine.deciders[p.seat] = BotDecider.new(engine, 0)
 var purchases = [0, 0]
 var dealt = [0, 0]
 engine.damage_dealt.connect(func(p, _q, amount): dealt[p.seat] += amount)
 engine.card_moved.connect(func(c, origin, target):
  if origin == "center_row" and target == "discard" and c.owner >= 0: purchases[c.owner] += 1)
 var driver = BotPlayer.new(engine)
 while engine.active().seat != 0 and not engine.state.finished: await driver.take_turn(engine.active())
 # Persist an actual mid-game table payload and load it, rather than only the data codec.
 verify(table.save_game(), "Stats game saves")
 var saved = SaveGame.read()
 verify(not saved.is_empty() and saved.table.has("match_stats"), "Save includes statistics")
 var resumed = load("res://scenes/table.tscn").instantiate()
 resumed.auto_drive = false
 resumed.resume_data = saved
 root.add_child(resumed)
 await process_frame
 verify(resumed.match_stats.to_dict() == table.match_stats.to_dict() or resumed.match_stats.seats == table.match_stats.seats, "Resume preserves counters")
 resumed.free()
 saved.table.erase("match_stats")
 var legacy = load("res://scenes/table.tscn").instantiate()
 legacy.auto_drive = false
 legacy.resume_data = saved
 root.add_child(legacy)
 await process_frame
 verify(legacy.match_stats.since_resume and legacy.match_stats.seats[0].cards_played == 0, "Legacy save starts counters since resume")
 legacy.free()
 for turn in 200:
  if engine.state.finished: break
  await driver.take_turn(engine.active())
 verify(engine.state.finished, "Statistics scripted game completes")
 await process_frame
 for p in engine.state.players:
  var stat = table.match_stats.seats[p.seat]
  verify(stat.damage_taken == engine.state.starting_life + stat.life_gained - p.life, "Damage and healing reconcile with life")
  verify(stat.cards_bought == purchases[p.seat], "Purchase count matches row-to-discard moves")
  verify(stat.final_life == p.life and stat.final_deck_size > 0, "Final state recorded")
 verify(table.match_stats.seats[0].damage_dealt == dealt[0] and table.match_stats.seats[1].damage_dealt == dealt[1], "Damage dealt matches engine signal totals")
 var serialized = JSON.parse_string(JSON.stringify(table.match_stats.to_dict()))
 var restored = table.match_stats.from_dict(serialized)
 verify(restored != null and restored.seats == table.match_stats.seats, "Stats JSON round trip")
 verify(SaveGame.valid_match_stats({"player_count": 2}) and not SaveGame.valid_match_stats({"player_count": 2, "match_stats": "bad"}), "Legacy saves accepted, malformed stats rejected")
 var summary = table.find_child("MatchSummary", true, false)
 verify(summary != null, "Summary exists")
 var buttons = []
 collect_buttons(summary, buttons)
 # Visibility clipping is tested separately by phone checks; find every summary button here.
 var deck_button = find_text(summary, "View final deck")
 verify(deck_button != null and find_text(summary, "Play Again") != null and find_text(summary, "Menu") != null, "Summary navigation and final deck controls")
 verify(find_text(summary, "Life") != null and find_text(summary, "Damage") != null and find_text(summary, "Bought") != null and find_text(summary, "Played") != null, "Summary seat columns")
 deck_button.pressed.emit()
 await process_frame
 verify(table.pending, "Final deck opens existing card viewer")
 table.answered.emit(null)
 await process_frame
 await share_checks(table, engine.state.winner)
 table.free()
 await process_frame
func find_text(node: Node, text: String):
 if (node is Label or node is Button) and node.text == text: return node
 for child in node.get_children():
  var found = find_text(child, text)
  if found != null: return found
 return null

func share_checks(table, winner):
 var share = load("res://scripts/ui/result_share.gd")
 var details = table.share_details(winner)
 var tree = share.build_card(details)
 verify(tree.size == Vector2i(1200, 630), "Share card embed dimensions")
 for text in [details.headline, details.handle, "phreaknic-ccg.net"]: verify(find_text(tree, text) != null, "Share card text: " + text)
 verify(has_text(tree, "v" + details.version), "Share card version")
 tree.free()
 verify(await share.render_card(table, details) == null, "Headless share rendering returns null")
 var text = "Hi & #/é"
 var encoded = "Hi%20%26%20%23%2F%C3%A9"
 var expected = {"X": "https://x.com/intent/post?text=" + encoded, "Bluesky": "https://bsky.app/intent/compose?text=" + encoded, "Reddit": "https://www.reddit.com/submit?title=" + encoded + "&url=https%3A%2F%2Fphreaknic-ccg.net", "Facebook": "https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fphreaknic-ccg.net"}
 for platform in expected: verify(share.compose_url(platform, text) == expected[platform], "Exact encoded URL: " + platform)
 for platform in ["Discord", "Mastodon", "javascript:alert(1)", "https://evil.test", ""]: verify(share.compose_url(platform, text) == "", "Unknown platform cannot open URL")
 details.merge({"victory": true, "all_bots": true, "difficulty": "Elite", "opponents": ["A", "B"], "turns": 14, "hero_name": "Elonka", "version": "0.15", "damage": 38}, true)
 verify(share.copy_text(details) == "I beat 2 bots on Elite in 14 turns as Elonka in PhreakNIC CCG v0.15 — 38 damage dealt. https://phreaknic-ccg.net", "Copy text content")
 verify(share.filename({"year": 2026, "month": 1, "day": 2, "hour": 3, "minute": 4, "second": 5}) == "phreaknic-ccg-20260102-030405.png", "Share filename")
func has_text(node: Node, text: String) -> bool:
 if (node is Label or node is Button) and text in node.text: return true
 for child in node.get_children():
  if has_text(child, text): return true
 return false

func tutorial_checks():
 var style = load("res://scripts/ui/style.gd")
 var original = FileAccess.get_file_as_bytes(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else null
 var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
 file.store_string("existing real game")
 file.close()
 for compact in [false, true]:
  style.compact_override = compact
  var table = load("res://scenes/table.tscn").instantiate()
  table.tutorial_mode = true
  table.auto_drive = false
  table.fast = true
  root.add_child(table)
  await process_frame
  var engine = table.engine
  engine.deciders[0] = BotDecider.new(engine, 0)
  var coach = table.tutorial_coach
  verify(engine.state.card_pool == "2025" and engine.state.banned.is_empty() and engine.state.players[1].difficulty == 0, "Tutorial fixed base pool and easiest bot")
  verify(not table.can_save() and not table.save_game(), "Tutorial cannot save")
  var visited = []
  for iteration in 50:
   if coach.stopped: break
   var step = coach.step
   visited.append(step)
   var p = engine.state.players[0]
   match coach.STEPS[step][2]:
    "": coach.advance()
    "play":
     var hackers = p.hand.filter(func(c): return c.id == "Hacking" and engine.can_play(p, c))
     if not hackers.is_empty(): await engine.play_card(p, hackers[0])
    "buy":
     await engine.play_all(p, true)
     var cards = engine.state.center_row.filter(func(c): return c != null and engine.can_buy(p, c))
     if not cards.is_empty(): await engine.buy_card(p, cards[0])
    "inspect":
     if not p.hand.is_empty(): table.inspect_card(p.hand[0], true)
    "end": await table.end_human_turn(true)
    "bot":
     if engine.active().seat != 0: await BotPlayer.new(engine).take_turn(engine.active())
   if not coach.stopped: coach._process(0)
   if is_instance_valid(table.inspect_overlay): table.close_inspect()
  verify(coach.stopped and 10 in visited, "Tutorial completes scripted inputs in layout " + str(compact))
  verify(FileAccess.get_file_as_string(SaveGame.PATH) == "existing real game", "Tutorial preserves real save")
  for step in coach.STEPS.size():
   coach.step = step
   coach.stopped = false
   coach.show()
   coach.set_process(true)
   coach.enter_step()
   if step % 2 == 0: table.go_back()
   else: find_text(coach, "Skip tutorial").pressed.emit()
   verify(coach.stopped, "Escape or Skip works at tutorial step " + str(step))
  coach.step = 1
  coach.stopped = false
  coach.enter_step()
  await engine.play_all(engine.state.players[0], true)
  coach._process(0)
  verify(coach.step != 1, "Impossible Hacker wait advances")
  table.free()
  await process_frame
 style.compact_override = null
 if original == null: SaveGame.remove()
 else:
  file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
  file.store_buffer(original)
  file.close()

func countdown_checks():
 var timer = load("res://scripts/ui/turn_countdown.gd").new()
 root.add_child(timer)
 verify(not timer.visible, "Countdown hidden initially")
 timer.configure(45, 45, "prompt")
 verify(timer.visible and timer.phase == "normal" and timer.text.text == "Auto-answer in 45s", "Prompt countdown visible")
 timer._process(16)
 verify(timer.phase == "amber" and not timer.warned, "Countdown amber")
 timer._process(19)
 verify(timer.phase == "red" and timer.warned, "Countdown red and warning at ten seconds")
 timer._process(15)
 verify(timer.remaining == 0 and timer.warned, "Countdown clamps at zero, warning stays latched")
 timer.configure(45, 180, "turn", false)
 verify(timer.text.text == "idle 0:45" and not timer.bar.visible, "Other seat idle tag")
 timer.clear()
 verify(not timer.visible and not timer.active, "Countdown clears")
 timer.free()
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{"bot": false, "name": "A"}, {"bot": false, "name": "B"}], "2025", 0, 41)
 server.clock = func(): return 30.0
 server.disconnected = {0: 0.0, 1: 10.0}
 var timers = server.timer_state()
 verify(timers.size() == 2 and timers[0].remaining_seconds == 90 and timers[1].remaining_seconds == 100, "Server exposes authoritative disconnected deadlines")
 server.engine.finish(null)
 verify(server.timer_state().is_empty(), "Finished game has no deadlines")
 server.free()

func emote_checks():
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 root.add_child(table)
 await process_frame
 var session = OnlineSession.new()
 root.add_child(session)
 var pair = LoopbackTransport.pair(false)
 session.client.bind_transport(pair[0])
 table.online_session = session
 var emotes = load("res://scripts/ui/emotes.gd").new()
 emotes.table = table
 table.add_child(emotes)
 emotes.mute(false)
 emotes.open()
 verify(emotes.popup != null and find_text(emotes.popup, "Rickrolled!") != null, "Eight-preset emote picker")
 emotes.send(7)
 verify(pair[1].queue == [{"type": "emote", "id": 7}], "Emote UI sends preset wire message")
 emotes.close()
 var before = table.log_entries.size()
 emotes.receive({"type": "emote", "seat": 1, "id": 0})
 verify(emotes.bubbles.has(1) and table.log_entries.size() == before + 1, "Incoming emote bubble and log")
 emotes.mute(true)
 emotes.receive({"type": "emote", "seat": 1, "id": 1})
 verify(emotes.bubbles.is_empty() and table.log_entries.size() == before + 1, "Muted emotes hidden and not logged")
 emotes.mute(false)
 for data in [{"type": "emote", "seat": -1, "id": 0}, {"type": "emote", "seat": 0, "id": "1"}, {"type": "emote", "seat": 0, "id": 8}]: emotes.receive(data)
 verify(emotes.bubbles.is_empty(), "UI rejects malformed emotes")
 table.online_session = null
 pair[0].close()
 session.free()
 table.free()
 await process_frame

func online_result_checks():
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{"name": "Player", "bot": false}, {"name": "Opponent", "bot": false}], "2025", 0, 15)
 await server.engine.start_turn()
 var session = OnlineSession.new()
 root.add_child(session)
 var pair = LoopbackTransport.pair()
 server.attach(pair[0])
 session.client.connect_to(pair[1], 0, server.tokens[0])
 pair[1].received.connect(session._message)
 for i in 3: await process_frame
 var table = load("res://scenes/table.tscn").instantiate()
 table.online_session = session
 root.add_child(table)
 await process_frame
 var before = table.engine.state.players[0].life
 server.engine.state.players[0].life = -8
 server.engine.finish(server.engine.state.players[1])
 for i in 3: await process_frame
 verify(before > 0 and table.match_stats.seats[0].final_life == -8, "Online summary receives final life before coalesced view")
 verify(table.online_over and table.engine.state.finished and table.find_child("MatchSummary", true, false) != null, "Online summary completes once")
 pair[1].close()
 table.free()
 session.free()
 server.free()
 await process_frame
