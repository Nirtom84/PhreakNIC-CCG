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
func find_button(node, prefix: String):
 if node is Button and node.text.begins_with(prefix): return node
 for child in node.get_children():
  var found = find_button(child, prefix)
  if found != null: return found
 return null
class NamingUI:
 extends RefCounted
 var engine
 var ids = []
 func decision(_prompt, names, _cards, _min, _max, _multi, _search):
  ids = names
  return 0
## The main menu builds itself anew after every game; it must come back with the same player count.
func player_count_memory():
 var settings = root.get_node("Sfx")
 var style = load("res://scripts/ui/style.gd")
 for phone in [false, true]:
  style.compact_override = phone
  var layout = " (phone layout)" if phone else " (desktop layout)"
  var menu = load("res://scenes/menu.tscn").instantiate()
  root.add_child(menu)
  await process_frame
  find_button(menu, "4 players").pressed.emit()
  menu.free()
  menu = load("res://scenes/menu.tscn").instantiate()
  root.add_child(menu)
  await process_frame
  var standard = menu.find_children("*", "OptionButton", true, false).filter(func(o): return o.item_count == 4 and o.get_item_text(0).begins_with("Standard"))
  verify(find_button(menu, "4 players").button_pressed and not find_button(menu, "2 players").button_pressed and menu.count.get_selected_id() == 4, "Reopened menu keeps 4 players" + layout)
  verify(standard.size() == 1 and standard[0].get_item_text(0) == "Standard · 40", "Starting life shows the 4-player standard" + layout)
  menu.free()
 style.compact_override = null
 var reloaded_settings = load("res://scripts/ui/sfx.gd").new()
 root.add_child(reloaded_settings)
 verify(reloaded_settings.get("player_count") == 4, "Settings reload keeps the player count")
 reloaded_settings.free()
 var config = OnlineAPI.settings()
 config.set_value("game", "player_count", 7)
 config.save("user://settings.json")
 reloaded_settings = load("res://scripts/ui/sfx.gd").new()
 root.add_child(reloaded_settings)
 verify(reloaded_settings.get("player_count") == 2, "Invalid player count loads as 2")
 reloaded_settings.free()
 settings.set("player_count", 2)
 settings.save()
## The menu finds its chosen custom deck by name, so renaming that deck must keep it chosen.
func renamed_deck_memory():
 var settings = root.get_node("Sfx")
 var Builder = load("res://scripts/ui/deck_builder.gd")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Builder.PATH))
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await process_frame
 find_button(menu, "Decks (experimental)").pressed.emit()
 var builder = menu.get_children().filter(func(child): return child.get_script() == Builder)[0]
 await process_frame
 for deck_name in ["Mine", "Other"]:
  var copy = Builder.builtins()[0].duplicate(true)
  copy.name = deck_name
  builder.edit(copy, -1)
  builder.save_deck()
 settings.custom_deck_name = "Mine"
 settings.save()
 builder.edit(builder.decks[1], 1)
 builder.deck.name = "Other v2"
 builder.save_deck()
 verify(settings.custom_deck_name == "Mine", "Renaming another deck keeps the chosen one")
 builder.edit(builder.decks[0], 0)
 builder.deck.name = "Mine v2"
 builder.save_deck()
 builder.back()
 await process_frame
 var config = OnlineAPI.settings()
 verify(menu.custom_tile.text.ends_with("Mine v2 · 60 cards") and config.get_value("game", "custom_deck_name") == "Mine v2", "Renaming the chosen custom deck keeps it chosen")
 menu.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Builder.PATH))
 settings.custom_deck_name = "Tag Team"
 settings.save()
func run():
 for path in ["user://settings.json", SaveGame.PATH, "user://decks.json", "user://decks.json.tmp"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 var settings = root.get_node("Sfx")
 settings.visual_effects = false
 SaveGame.remove()
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await process_frame
 find_button(menu, "Base Set — PhreakNIC 26").pressed.emit()
 var config = OnlineAPI.settings()
 verify(settings.card_pool == "2025" and config.get_value("game", "card_pool") == "2025", "Menu choice persists")
 var reloaded_settings = load("res://scripts/ui/sfx.gd").new()
 root.add_child(reloaded_settings)
 verify(reloaded_settings.card_pool == "2025", "Settings reload keeps menu choice")
 reloaded_settings.queue_free()
 menu.queue_free()
 await process_frame
 for pool in ["2025", "2026"]:
  var e = GameEngine.new()
  root.add_child(e)
  e.setup([-1, 1], 42, [], pool)
  var center = e.state.center_deck + e.state.center_row
  var expected = root.get_node("CardDB").pool_ids(pool).filter(func(id): return not root.get_node("CardDB").get_card(id).starter)
  verify(center.size() == (102 if pool == "2025" else 150), "Center count " + pool)
  var actual = center.map(func(c): return c.id)
  actual.sort()
  expected.sort()
  verify(actual == expected, "Exact Center contents " + pool)
  verify(e.state.conservation_ok(), "Conservation " + pool)
  var naming = NamingUI.new()
  naming.engine = e
  await HumanDecider.new(naming).name_a_card(e.active(), "Name a card")
  verify(naming.ids.size() == expected.size() + 2, "Name choices use pool " + pool)
  if pool == "2025":
   var expansion_names = root.get_node("CardDB").cards.values().filter(func(c): return c.set == "2026" and c.name != "Botnet").map(func(c): return c.name)
   verify(naming.ids.all(func(name): return name not in expansion_names), "No expansion naming choices")
  await e.start_turn(0)
  var snapshot = SaveGame.snapshot(e.state)
  var restored = SaveGame.restore(JSON.parse_string(JSON.stringify(snapshot)))
  verify(restored != null and restored.card_pool == pool, "Save pool round trip " + pool)
  if pool == "2026":
   snapshot.state.erase("card_pool")
   restored = SaveGame.restore(JSON.parse_string(JSON.stringify(snapshot)))
   verify(restored != null and restored.card_pool == "2026", "Legacy save defaults to 2026")
   var metadata = {"seat_names": ["You", "Bot"], "seat_heroes": ["", ""], "player_count": 2, "difficulties": [-1, 1], "handle": "You", "hero_id": "", "fast": false, "log": ""}
   verify(SaveGame.write(e, metadata), "Write full 2026 save")
   var legacy = SaveGame.read()
   legacy.game.state.erase("card_pool")
   var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
   file.store_string(JSON.stringify(legacy))
   file.close()
   var loaded = SaveGame.read()
   verify(not loaded.is_empty() and SaveGame.restore(loaded.game).card_pool == "2026", "Legacy save file accepted")
  e.free()
 var table = load("res://scenes/table.tscn").instantiate()
 table.card_pool = "2025"
 table.auto_drive = false
 table.seed_value = 42
 root.add_child(table)
 current_scene = table
 await process_frame
 verify(table.seat_heroes.slice(1).all(func(id): return root.get_node("CardDB").in_pool(id, "2025") and root.get_node("CardDB").has_subtype(id, "Hero")), "Base bot Heroes")
 while table.engine.active().is_bot: await table.drive_reaction(table.engine.active())
 verify(table.save_game(), "Base save written")
 var saved = SaveGame.read()
 verify(not saved.is_empty(), "Base save validates")
 table.queue_free()
 await process_frame
 var resumed = load("res://scenes/table.tscn").instantiate()
 resumed.auto_drive = false
 resumed.resume_data = saved
 root.add_child(resumed)
 current_scene = resumed
 await process_frame
 verify(resumed.engine.state.card_pool == "2025" and resumed.card_pool == "2025", "Resume keeps pool")
 resumed.queue_free()
 await process_frame
 menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
  root.size = dimensions
  await process_frame
  await process_frame
  verify(find_button(menu, "Resume game") != null, "Save present")
  var bottom = find_button(menu, "Quit").get_global_rect()
  verify(bottom.end.y <= dimensions.y and bottom.end.x <= dimensions.x, "Menu fits " + str(dimensions))
  for prefix in ["Base Set — PhreakNIC 26", "Base Set + Expansion 1 — PhreakNIC 27", "Resume game"]:
   var rect = find_button(menu, prefix).get_global_rect()
   verify(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= dimensions.x and rect.end.y <= dimensions.y, "Choice fits " + prefix + str(dimensions))
 menu.queue_free()
 await process_frame
 await player_count_memory()
 await renamed_deck_memory()
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("v06 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
