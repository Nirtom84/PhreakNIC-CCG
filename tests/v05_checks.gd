extends SceneTree
var checks = 0
var failures = 0
func _initialize(): run.call_deferred()
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func settle():
 await process_frame
 await process_frame
func run():
 var save_backup = FileAccess.get_file_as_bytes(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else null
 var path = "user://settings.cfg"
 var existed = FileAccess.file_exists(path)
 var backup = FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
 var settings = root.get_node("Sfx")
 var saved = [settings.handle, settings.hero_id, settings.auto_end_turn]
 settings.auto_end_turn = false
 root.size = Vector2i(1920, 1080)
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.seed_value = 1234
 root.add_child(table)
 await settle()
 var e = table.engine
 var p = e.state.players[0]
 var hand = p.hand.duplicate()
 p.hand.clear()
 p.hacking = 0
 p.turn_flags.reserved = true
 # Direct fixture edits request redraws to invalidate the cached action state.
 table.redraw()
 verify(table.nothing_left(), "Empty turn has no moves")
 p.hand.append(hand[0])
 table.redraw()
 verify(not table.nothing_left(), "Playable card prevents auto-end")
 p.hand.clear()
 p.turn_flags.reserved = false
 table.redraw()
 verify(not table.nothing_left(), "Reserve prevents auto-end")
 p.turn_flags.acquired = 1
 p.hacking = 100
 table.redraw()
 verify(not table.nothing_left(), "Affordable market prevents auto-end")
 var reserved = e.state.center_row[0]
 e.state.center_row[0] = null
 p.reserve.append(reserved)
 var market = e.state.center_row.duplicate()
 e.state.center_row.fill(null)
 table.redraw()
 verify(not table.nothing_left(), "Affordable reserve prevents auto-end")
 p.reserve.clear()
 e.state.center_row.assign(market)
 e.state.center_row[0] = reserved
 p.hacking = 0
 p.turn_flags.reserved = true
 var botnet = CardInstance.new(9999, "Botnet", 0)
 p.play_area.append(botnet)
 table.redraw()
 verify(not table.nothing_left(), "Enabled ability prevents auto-end")
 p.play_area.clear()
 table.redraw()
 var turn = e.state.turn
 table._process(1.3)
 verify(e.state.turn == turn, "Setting off prevents auto-end")
 settings.auto_end_turn = true
 table.pending = true
 table._process(1.3)
 verify(e.state.turn == turn, "Pending decision prevents auto-end")
 table.pending = false
 table._process(0.6)
 table.pending = true
 table._process(0.8)
 verify(table.auto_end_elapsed == 0, "Dialog cancels countdown")
 table.pending = false
 table._process(1.3)
 await settle()
 verify(e.state.turn > turn, "Auto-end advances empty turn")
 settings.auto_end_turn = false
 for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
  root.size = dimensions
  await settle()
  table.inspect_card(reserved, true)
  await settle()
  var dim = table.inspect_overlay.get_child(0)
  verify(dim.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO, Vector2(dimensions))), "Sheet backdrop covers viewport")
  var rect = dim.get_child(0).get_global_rect()
  verify(rect.size.x < dimensions.x * 0.6 and rect.size.y < dimensions.y, "Card sheet fits content")
  verify(rect.get_center().distance_to(Vector2(dimensions) / 2) < 3, "Card sheet centered")
  table.close_inspect()
  await settle()
 for dimensions in [Vector2i(1920, 1200), Vector2i(1920, 1440)]:
  root.size = dimensions
  await settle()
  var regions = table.body.get_child(0).get_children()
  verify(regions[4].get_global_rect().end.y <= dimensions.y, "Hand fits tall viewport")
 root.size = Vector2i(2400, 1080)
 await settle()
 table.inspect_card(reserved)
 await settle()
 verify(table.inspect_overlay.get_child(0).size.is_equal_approx(Vector2(2400, 1080)), "Inspect covers wide viewport")
 table.close_inspect()
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await settle()
 var hero = load("res://scripts/ui/style.gd").heroes()[0]
 menu.rules()
 await settle()
 verify(menu.rules_overlay.size.is_equal_approx(Vector2(2400, 1080)), "Rules cover wide viewport")
 menu.rules_overlay.queue_free()
 await settle()
 menu.select_hero(hero)
 var config = ConfigFile.new()
 config.load(path)
 verify(config.get_value("player", "hero_id") == hero and config.get_value("player", "handle") == root.get_node("CardDB").cards[hero].name, "Hero selection persists")
 verify(menu.avatar_preview.get_child(0).texture is AtlasTexture, "Hero uses cropped art")
 menu.handle_input.text_changed.emit("Custom")
 verify(settings.hero_id.is_empty() and menu.avatar_preview.get_child(0).texture.resource_path == "res://assets/icon/icon.png", "Custom name uses logo")
 var face_id = root.get_node("CardDB").card_id_for_name("notlarry")
 if not face_id.is_empty():
  menu.handle_input.text_changed.emit("notlarry")
  var face_tex = menu.avatar_preview.get_child(0).texture
  verify(face_tex is AtlasTexture and face_tex.atlas.resource_path == root.get_node("CardDB").image_path(face_id), "Card-named handle uses that card's art")
  menu.handle_input.text_changed.emit("Custom")
 settings.hero_id = hero
 settings.handle = root.get_node("CardDB").cards[hero].name
 table.player_count = 4
 for seed_id in 100:
  table.pick_seat_names(seed_id)
  verify(hero not in table.seat_heroes.slice(1), "Bots exclude human hero")
 menu.queue_free()
 table.queue_free()
 await settle()
 settings.handle = saved[0]
 settings.hero_id = saved[1]
 settings.auto_end_turn = saved[2]
 if existed:
  var file = FileAccess.open(path, FileAccess.WRITE)
  file.store_buffer(backup)
  file.close()
 else: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 if save_backup == null:
  if FileAccess.file_exists(SaveGame.PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))
 else:
  var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
  file.store_buffer(save_backup)
  file.close()
 print("v05 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
