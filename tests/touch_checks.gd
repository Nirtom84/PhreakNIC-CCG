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
func card_button(zone: String) -> Control:
 for control in touch.cards:
  if control.get_parent().get_meta("zone", "") == zone: return control
 return null
func settle():
 await process_frame
 await process_frame
func run():
 root.size = Vector2i(1920, 1080)
 touch = root.get_node("TouchInput")
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.seed_value = 1234
 root.add_child(table)
 await settle()
 # Probe native controls with our helper disabled, using actual routed events.
 touch.set_process_input(false)
 var probe = Control.new()
 probe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(probe)
 var rich = RichTextLabel.new()
 rich.position = Vector2(100, 100)
 rich.size = Vector2(300, 300)
 for i in 100: rich.text += "line %d\n" % i
 probe.add_child(rich)
 var scroll = ScrollContainer.new()
 scroll.position = Vector2(500, 100)
 scroll.size = Vector2(300, 300)
 probe.add_child(scroll)
 var content = Control.new()
 content.custom_minimum_size = Vector2(280, 3000)
 scroll.add_child(content)
 await settle()
 for control in [rich, scroll]:
  var point = control.global_position + Vector2(100, 200)
  finger(point, true)
  drag(point - Vector2(0, 100), Vector2(0, -100))
  finger(point - Vector2(0, 100), false)
  await settle()
  print("Native touch scroll %s: %s (touchscreen=%s)" % [control.get_class(), rich.get_v_scroll_bar().value if control == rich else scroll.scroll_vertical, DisplayServer.is_touchscreen_available()])
 probe.queue_free()
 await settle()
 touch.set_process_input(true)
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
 verify(table.pending, "Back opens leave dialog")
 var dialog = table.get_child(table.get_child_count() - 1)
 var grid = dialog.get_child(0).get_child(3).get_child(0)
 grid.get_child(1).pressed.emit()
 await settle()
 verify(not table.pending and table.is_inside_tree(), "Keep playing keeps game")
 # Exercise a toggle button in a pending card decision too.
 table.decision("Inspect choice", [], p.hand, 0, 1, true)
 await settle()
 dialog = table.get_child(table.get_child_count() - 1)
 grid = dialog.get_child(0).get_child(3).get_child(0)
 button = grid.get_child(0)
 point = button.get_global_rect().get_center()
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
 verify(table.log_view.get_v_scroll_bar().value > 0, "Finger drag scrolls network log")
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
 table.queue_free()
 await settle()
 print("Touch checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
