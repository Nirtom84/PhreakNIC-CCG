extends SceneTree
## Subprocess for tests/v07_checks.gd: Back and Escape on the main menu. An input that quits the game would also
## end the calling suite (with exit code 0), so each scenario runs in its own process. It prints MARKER only if
## the game is still running after the input. The suite gives it an empty XDG_DATA_HOME.
## Guards, so it can never stall CI or flood its output: the 50th logged error kills the process, and so does a
## watchdog thread after 30 s.
const MARKER = "MENU_QUIT_HELPER ALIVE"
class ErrorGuard extends Logger:
 var count = 0
 func _log_error(_f: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _type: int, _traces: Array[ScriptBacktrace]) -> void:
  count += 1
  if count == 50: OS.kill(OS.get_process_id())
var guard = ErrorGuard.new()
var watchdog = Thread.new()
var stopping = false
func _initialize(): call_deferred("run")
func _finalize():
 stopping = true
 if watchdog.is_started(): watchdog.wait_to_finish()
func frames(n = 4):
 for i in n: await process_frame
func find_button(node, text):
 if node is Button and node.text == text and node.is_visible_in_tree(): return node
 for child in node.get_children():
  var found = find_button(child, text)
  if found != null: return found
 return null
## Android Back as the engine delivers it: the window first, then every child in tree order (internal ones too),
## skipping native sub-windows. So the main menu hears it before a screen opened on top of it.
func deliver_back(node: Node):
 node.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 var i = 0
 while i < node.get_child_count(true):
  var child = node.get_child(i, true)
  if not (child is Window and not child.is_embedded()): deliver_back(child)
  i += 1
func escape():
 for down in [true, false]:
  var event = InputEventKey.new()
  event.keycode = KEY_ESCAPE
  event.physical_keycode = KEY_ESCAPE
  event.pressed = down
  Input.parse_input_event(event)
func run():
 OS.add_logger(guard)
 watchdog.start(func():
  var deadline = Time.get_ticks_msec() + 30000
  while not stopping and Time.get_ticks_msec() < deadline: OS.delay_msec(100)
  if not stopping:
   printerr("MENU_QUIT_HELPER WATCHDOG")
   OS.kill(OS.get_process_id()))
 var args = OS.get_cmdline_user_args()
 var scenario = args[0] if not args.is_empty() else ""
 print("MENU_QUIT_HELPER START ", scenario)
 var style = load("res://scripts/ui/style.gd")
 root.get_node("Sfx").visual_effects = false
 root.size = Vector2i(1920, 1080)
 # Android Back comes from a phone (phone layout); the web scenario is a desktop browser.
 style.compact_override = scenario.ends_with("-back")
 style.web_override = true if scenario == "web-escape" else null
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 current_scene = menu
 await frames()
 if scenario == "stats-back":
  find_button(menu, "Stats").pressed.emit()
  await frames()
 if scenario.ends_with("-back"): deliver_back(root)
 else: escape()
 await frames()
 print(MARKER, " stats_open=", menu.has_node("LifetimeStats"))
 quit(0)
