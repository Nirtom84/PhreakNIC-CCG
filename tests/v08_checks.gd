extends SceneTree
var checks = 0
var failures = 0
var backups = {}
var style
var settings
func _initialize(): run.call_deferred()
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func button(node, prefix: String):
 if node is Button and node.text.begins_with(prefix): return node
 for child in node.get_children():
  var found = button(child, prefix)
  if found != null: return found
 return null
func settle():
 await process_frame
 await process_frame
func run():
 style = load("res://scripts/ui/style.gd")
 settings = root.get_node("Sfx")
 for path in ["user://settings.cfg", "user://savegame.json"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 settings.visual_effects = false
 settings.auto_end_turn = false
 root.size = Vector2i(1920, 1080)
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.seed_value = 1
 table.starting_life = 40
 root.add_child(table)
 await settle()
 var e = table.engine
 var p = e.state.players[0]
 e.state.active_seat = 0
 verify(p.life == 40, "Starting life reaches engine")
 var c = e.state.center_row[0]
 c.id = "Hacking"
 p.hacking = 100
 table.card_clicked(c, "market")
 await settle()
 verify(is_instance_valid(table.inspect_overlay) and button(table.inspect_overlay, "Buy") != null, "Market click opens actionable sheet")
 var sheet_panel = table.inspect_overlay.get_child(0).get_child(0)
 var sheet_background = sheet_panel.get_theme_stylebox("panel")
 verify(sheet_background is StyleBoxFlat and sheet_background.bg_color.a == 1.0, "Sheet has an opaque panel background")
 root.size = Vector2i(2400, 1080)
 await settle()
 var buy_button = button(table.inspect_overlay, "Buy")
 var close_button = button(table.inspect_overlay, "Close")
 verify(table.inspect_overlay.get_child(0).get_global_rect() == root.get_visible_rect() and buy_button is Button and close_button is Button and buy_button.custom_minimum_size.y >= 56 and close_button.custom_minimum_size.y >= 56, "Sheet dim covers wide viewport and actions have touch sized buttons")
 root.size = Vector2i(1920, 1080)
 await settle()
 button(table.inspect_overlay, "Buy").pressed.emit()
 await settle()
 verify(c in p.discard and c not in e.state.center_row, "Sheet buys card")
 p.turn_flags.clear()
 c = e.state.center_row[0]
 c.id = "Damage"
 table.card_clicked(c, "market")
 await settle()
 button(table.inspect_overlay, "Reserve").pressed.emit()
 await settle()
 verify(c in p.reserve, "Sheet reserves card")
 p.turn_flags.clear()
 table.card_clicked(c, "reserve")
 await settle()
 button(table.inspect_overlay, "Buy").pressed.emit()
 await settle()
 verify(c not in p.reserve and c in p.discard, "Sheet buys own reserved card")
 table.inspect_card(p.hand[0])
 await settle()
 verify(not table.nothing_left(), "Sheet pauses auto-end")
 verify(button(table.inspect_overlay, "Buy") == null and button(table.inspect_overlay, "Play") == null, "Long press sheet is read only")
 var hand = p.hand.duplicate()
 table.go_back()
 verify(table.inspect_overlay == null and p.hand == hand, "Back closes without playing")
 table.show_log_card("Hacking")
 await settle()
 verify(is_instance_valid(table.inspect_overlay) and button(table.inspect_overlay, "Play") == null, "Log link is read only")
 button(table.inspect_overlay, "Close").pressed.emit()
 await settle()
 verify(table.inspect_overlay == null and p.hand == hand, "Close preserves hand")
 var extra = e.state.create("Botnet1", 0)
 # Use an existing nonstarter card from the market so its definition is valid.
 extra.id = e.state.center_row[0].id
 p.hand.append(extra)
 await table.play_basics()
 verify(extra in p.hand and p.hand.all(func(card): return card.id not in ["Hacking", "Damage"]), "Basics plays starters only")
 settings.confirm_end_turn = true
 table.end_human_turn()
 await settle()
 verify(table.pending, "Moves remaining asks to end")
 table.answered.emit(1)
 await settle()
 verify(not table.pending and e.active() == p, "Keep playing preserves turn")
 settings.confirm_end_turn = false
 await table.end_human_turn()
 verify(not table.pending and e.active() != p, "Setting disables confirmation")
 e.state.active_seat = 0
 p.hand.clear()
 p.hacking = 0
 p.turn_flags["reserved"] = true
 for permanent in p.play_area: permanent.flags["used"] = true
 settings.confirm_end_turn = true
 verify(table.nothing_left(), "Empty turn has no moves")
 await table.end_human_turn()
 verify(not table.pending, "No moves skips confirmation")
 e.state.active_seat = 0
 var sources = [{"card": null, "name": "ICE A", "capacity": 2}, {"card": null, "name": "ICE B", "capacity": 2}]
 table.prevention_choice(3, sources)
 await settle()
 var overlay = table.get_child(table.get_child_count() - 1)
 var box = overlay.get_child(0)
 var confirm = button(overlay, "Confirm")
 verify(not confirm.disabled, "Suggested allocation legal")
 var first = box.get_child(1)
 first.get_child(1).pressed.emit()
 verify(confirm.disabled, "Underallocation cannot confirm")
 box.get_child(2).get_child(3).pressed.emit()
 verify(not confirm.disabled and box.get_child(2).get_child(3).disabled, "Transfer restores mandatory total")
 confirm.pressed.emit()
 await settle()
 table.queue_free()
 await settle()
 for count in [3, 4]:
  for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
   root.size = dimensions
   table = load("res://scenes/table.tscn").instantiate()
   table.auto_drive = false
   table.player_count = count
   table.seed_value = 42
   root.add_child(table)
   await settle()
   verify(table.engine.state.players[0].life == count * 10, "Standard multiplayer life")
   var hosts = table.body.get_child(0).get_child(0).get_child(0)
   verify(hosts.get_child_count() == count - 1, "All opponents rendered")
   for opponent in hosts.get_children():
    verify(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(opponent.get_global_rect()), "Opponent inside viewport")
   if count == 4 and dimensions == Vector2i(1920, 1440):
    # Exercise the table's four-seat engine to completion with the existing bot driver.
    table.engine.deciders[0] = BotDecider.new(table.engine, 0)
    table.engine.turn_driver = func(player): await BotPlayer.new(table.engine).take_turn(player)
    table.engine.state.players[0].is_bot = true
    for turn in 200:
     if table.engine.state.finished: break
     await BotPlayer.new(table.engine).take_turn(table.engine.active())
    verify(table.engine.state.finished, "Four-seat game finishes")
   table.queue_free()
   await settle()
 var helper = load("res://scripts/ui/bug_report.gd")
 var url = helper.build("Seed: 42 & cards\n".repeat(1000))
 verify(url.length() < 7000, "Bug URL bounded")
 verify("version=" in url and "platform=Running%20from%20source%20%28Godot%20editor%29" in url and "device=" in url and "%26" in url and "%0A" in url, "Bug fields encoded")
 verify(style.pool_label("2025") == "Base Set · PhreakNIC 26" and "Expansion 1" in style.pool_label("2026"), "Printed set names")
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("v08 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
