extends SceneTree
var failures: int = 0
var checks: int = 0
var table
var touch
func _initialize(): run.call_deferred()
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func finger(point: Vector2, down: bool):
 var event = InputEventScreenTouch.new()
 event.position = point
 event.pressed = down
 root.push_input(event, true)
 # push_input does not synthesize the OS mouse stream: supply it explicitly.
 var mouse = InputEventMouseButton.new()
 mouse.device = InputEvent.DEVICE_ID_EMULATION
 mouse.position = point
 mouse.button_index = MOUSE_BUTTON_LEFT
 mouse.pressed = down
 root.push_input(mouse, true)
func drag(point: Vector2, relative: Vector2):
 var event = InputEventScreenDrag.new()
 event.position = point
 event.relative = relative
 root.push_input(event, true)
 var mouse = InputEventMouseMotion.new()
 mouse.device = InputEvent.DEVICE_ID_EMULATION
 mouse.position = point
 mouse.relative = relative
 mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
 root.push_input(mouse, true)
func card_button(zone: String) -> Control:
 for control in touch.cards:
  if control.get_parent().get_meta("zone", "") == zone: return control
 return null
func settle():
 await process_frame
 await process_frame
func find_button(node, label):
 if node is Button and node.text == label: return node
 for child in node.get_children():
  var found = find_button(child, label)
  if found != null: return found
 return null
func check_picker(menu):
 await settle()
 var point = find_button(menu, "Pick a Hero").get_global_rect().get_center()
 finger(point, true)
 finger(point, false)
 await settle()
 verify(is_instance_valid(menu.rules_overlay), "First tap opens Hero picker")
 if not is_instance_valid(menu.rules_overlay): return
 var scroll = menu.rules_overlay.get_child(0).get_child(1)
 var old_hero = root.get_node("Sfx").hero_id
 point = scroll.get_child(0).get_child(7).get_global_rect().get_center()
 verify(touch.button_at(root, point) == scroll.get_child(0).get_child(7), "Picker drag begins on a Hero button")
 finger(point, true)
 drag(point - Vector2(0, 100), Vector2(0, -100))
 drag(point - Vector2(0, 200), Vector2(0, -100))
 finger(point - Vector2(0, 200), false)
 await settle()
 verify(is_instance_valid(menu.rules_overlay) and root.get_node("Sfx").hero_id == old_hero, "Picker drag selects nothing")
 verify(abs(scroll.scroll_vertical - 200) <= 2, "Picker button drag scrolls exactly once")
 menu.rules_overlay.queue_free()
 await settle()
func run():
 var backups = {}
 for path in ["user://settings.cfg", SaveGame.PATH]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 root.size = Vector2i(1920, 1080)
 touch = root.get_node("TouchInput")
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await check_picker(menu)
 menu.queue_free()
 await settle()
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.seed_value = 1234
 root.add_child(table)
 await settle()
 var p = table.engine.state.players[0]
 var button = card_button("hand")
 var point = button.get_global_rect().get_center()
 var before = p.hand.size()
 finger(point, true)
 finger(point, false)
 await settle()
 verify(p.hand.size() == before - 1, "Short tap plays a hand card")
 verify(table.zoom == null, "Touch tap leaves no hover zoom")
 button = card_button("hand")
 point = button.get_global_rect().get_center()
 var hand = p.hand.duplicate()
 var discard = p.discard.duplicate()
 var play_area = p.play_area.duplicate()
 finger(point, true)
 await create_timer(0.55).timeout
 verify(is_instance_valid(table.inspect_overlay), "Long press opens inspect")
 finger(point, false)
 await settle()
 verify(p.hand == hand and p.discard == discard and p.play_area == play_area, "Long press suppresses hand play and preserves zones")
 finger(point, true)
 finger(point, false)
 await settle()
 verify(table.inspect_overlay == null and p.hand == hand, "Closing tap does not play underlying card")
 button = card_button("market")
 point = button.get_global_rect().get_center()
 finger(point, true)
 await create_timer(0.55).timeout
 finger(point, false)
 await settle()
 verify(is_instance_valid(table.inspect_overlay) and not table.pending, "Center long press inspects without buy dialog")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 verify(table.inspect_overlay == null, "Back closes inspect")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 verify(is_instance_valid(table.game_menu) and not table.pending, "Back opens in-game menu")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await settle()
 verify(table.game_menu == null and table.is_inside_tree(), "Back resumes game")
 # Back on the buy dialog picks its Cancel option instead of being ignored.
 var row_before = table.engine.state.center_row.duplicate()
 var discard_before = p.discard.size()
 button = card_button("market")
 point = button.get_global_rect().get_center()
 finger(point, true)
 finger(point, false)
 await settle()
 verify(is_instance_valid(table.inspect_overlay) and not table.pending, "Tap on Center Row card opens the card sheet")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await settle()
 verify(not table.pending and table.game_menu == null and table.engine.state.center_row == row_before and p.discard.size() == discard_before, "Back cancels the buy dialog without buying")
 var dialog
 var grid
 # Exercise a toggle button in a pending card decision too.
 var choices = []
 for i in 70: choices.append(p.hand[i % p.hand.size()])
 table.decision("Inspect choice", [], choices, 0, 1, true)
 await settle()
 dialog = table.get_child(table.get_child_count() - 1)
 grid = dialog.get_child(0).get_child(3).get_child(0)
 button = grid.get_child(7)
 point = button.get_global_rect().get_center()
 finger(point, true)
 drag(point - Vector2(0, 100), Vector2(0, -100))
 finger(point - Vector2(0, 100), false)
 await settle()
 verify(not button.button_pressed and table.pending, "Decision drag toggles nothing")
 verify(abs(grid.get_parent().scroll_vertical - 100) <= 2, "Decision button drag scrolls exactly once")
 point = button.get_global_rect().get_center()
 finger(point, true)
 finger(point, false)
 await settle()
 verify(button.button_pressed, "Quick tap selects decision card")
 finger(point, true)
 finger(point, false)
 await settle()
 finger(point, true)
 await create_timer(0.55).timeout
 finger(point, false)
 await settle()
 verify(table.pending and not button.button_pressed and is_instance_valid(table.inspect_overlay), "Decision long press does not toggle selection")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 verify(table.pending and table.inspect_overlay == null, "Back from inspect preserves pending decision")
 table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 verify(table.pending, "Back ignores a pending decision")
 dialog.get_child(0).get_child(4).pressed.emit()
 await settle()
 table.log_view.clear()
 table.log_view.scroll_following = false
 table.log_view.append_text("[url=Hacking]Hacker[/url]\n")
 await settle()
 table.log_view.get_v_scroll_bar().value = 0
 # Find the rendered link through pointer routing (font metrics vary).
 var log_point = table.log_view.global_position + Vector2(20, 12)
 finger(log_point, true)
 finger(log_point, false)
 await settle()
 verify(is_instance_valid(table.inspect_overlay), "Log link tap opens inspect")
 table.close_inspect()
 for i in 100: table.log_view.append_text("Network line %d\n" % i)
 await settle()
 table.log_view.get_v_scroll_bar().value = 0
 point = table.log_view.global_position + Vector2(100, 300)
 finger(point, true)
 drag(point - Vector2(0, 100), Vector2(0, -100))
 finger(point - Vector2(0, 100), false)
 await settle()
 verify(abs(table.log_view.get_v_scroll_bar().value - 100) <= 2, "Network log drag scrolls exactly once")
 var rules = load("res://scripts/ui/rules_page.gd").open(table)
 await settle()
 var rules_text = rules.get_child(0).get_child(0)
 rules_text.get_v_scroll_bar().value = 0
 point = rules_text.get_global_rect().get_center()
 finger(point, true)
 drag(point - Vector2(0, 150), Vector2(0, -150))
 finger(point - Vector2(0, 150), false)
 await settle()
 verify(abs(rules_text.get_v_scroll_bar().value - 150) <= 2, "Rules drag scrolls exactly once")
 rules.queue_free()
 await settle()
 button = card_button("hand")
 point = button.get_global_rect().get_center()
 hand = p.hand.duplicate()
 finger(point, true)
 drag(point + Vector2(30, 0), Vector2(30, 0))
 await create_timer(0.55).timeout
 finger(point + Vector2(30, 0), false)
 await settle()
 verify(p.hand == hand and table.inspect_overlay == null, "Dragging card cancels tap and long press")
 verify(table.zoom == null, "Touch leaves no zoom popup")
 var motion = InputEventMouseMotion.new()
 motion.position = Vector2(10, 10)
 root.push_input(motion, true)
 verify(not touch.touch_mode or OS.has_feature("mobile"), "Real mouse motion restores desktop mode")
 motion.device = InputEvent.DEVICE_ID_EMULATION
 root.push_input(motion, true)
 verify(touch.touch_mode, "Emulated mouse restores touch mode")
 current_scene = table
 await table.leave_game(false)
 await settle()
 await check_picker(current_scene)
 current_scene.queue_free()
 await settle()
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("Touch checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
