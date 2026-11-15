extends SceneTree
# Subprocess for tests/ui_smoke.gd: you are knocked out of a 3-player game at Bot pace Instant and leave with
# Menu > Main menu > Leave while the bots play on. Leaving used to hang in an endless error loop, so this runs in
# its own process with guards that work even when no frame ever ends: a logger ends the process at the 50th error
# (an error loop logs synchronously) and a watchdog thread kills it after 25 s.
# Markers: LEAVE_HELPER KNOCKED_OUT <bool>, LEAVE_HELPER DONE main_menu=<bool> errors=<n>; LOOP or WATCHDOG on a hang.
class LoopGuard extends Logger:
 var count = 0
 func _log_error(_f: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _type: int, _traces: Array[ScriptBacktrace]) -> void:
  count += 1
  if count == 50:
   printerr("LEAVE_HELPER LOOP")
   OS.kill(OS.get_process_id())
var guard = LoopGuard.new()
var watchdog = Thread.new()
var watchdog_stop = false
func _initialize(): run.call_deferred()
func frames(n = 4):
 for i in n: await process_frame
func find_button(node, text):
 if node is Button and node.text == text and node.is_visible_in_tree(): return node
 for child in node.get_children():
  var found = find_button(child, text)
  if found != null: return found
 return null
# A real click, queued like OS input: it is handled before the next process_frame, where the bots resume.
func tap(control: Control):
 var point = control.get_global_rect().get_center()
 for down in [true, false]:
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  event.position = point
  event.global_position = point
  Input.parse_input_event(event)
func run():
 OS.add_logger(guard)
 watchdog.start(func():
  var deadline = Time.get_ticks_msec() + 25000
  while not watchdog_stop and Time.get_ticks_msec() < deadline: OS.delay_msec(100)
  if not watchdog_stop:
   printerr("LEAVE_HELPER WATCHDOG")
   OS.kill(OS.get_process_id()))
 load("res://scripts/ui/style.gd").compact_override = false
 root.size = Vector2i(1920, 1080)
 var sfx = root.get_node("Sfx")
 sfx.visual_effects = false
 sfx.auto_end_turn = false
 sfx.confirm_end_turn = false
 sfx.auto_activate.clear()
 sfx.bot_pace = 0.0 # Instant: each bot action waits one frame
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = 3
 table.difficulty = 1 # Phreak bots aim at the opponent with the least life
 table.seed_value = 11
 root.add_child(table)
 current_scene = table
 var human = table.engine.state.players[0]
 for i in 600:
  if table.available(): break
  await process_frame
 # Worn down to 1 life: end your turn and the bots knock you out, then play on between themselves.
 human.life = 1
 table.engine.state_changed.emit()
 table.end_button.pressed.emit()
 for i in 1500:
  if not human.alive or table.engine.state.finished: break
  await process_frame
 print("LEAVE_HELPER KNOCKED_OUT ", not human.alive and not table.engine.state.finished)
 table.menu_button.pressed.emit()
 await frames(2)
 find_button(table.game_menu, "Main menu").pressed.emit()
 await frames(2)
 # Mid-turn there's no save point, so the game asks "Leave without saving?" first.
 var leave = find_button(table, "Leave")
 if leave != null: tap(leave)
 await frames(10)
 print("LEAVE_HELPER DONE main_menu=", current_scene != null and current_scene.get_script() == load("res://scripts/ui/menu.gd"), " errors=", guard.count)
 watchdog_stop = true
 watchdog.wait_to_finish()
 quit(0)
