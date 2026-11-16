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
var clicks = 0
var style
func click_at(point: Vector2):
 for down in [true, false]:
  var event = InputEventMouseButton.new()
  event.position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  root.push_input(event, true)
func run():
 style = load("res://scripts/ui/style.gd")
 for path in ["user://settings.json", "user://settings.cfg.migrated", "user://settings.cfg", SaveGame.PATH]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 root.get_node("Sfx").visual_effects = false
 for web in [false, true]:
  style.web_override = web
  root.size = Vector2i(1600, 800)
  var menu = load("res://scenes/menu.tscn").instantiate()
  root.add_child(menu)
  await process_frame
  verify(find_button(menu, "Quit").visible == not web, "Quit visibility")
  for label in ["Windows", "Linux", "Android", "All releases"]:
   var link = find_button(menu, label)
   verify((link != null and link.visible) == web, "Download link " + label + " only on the web")
  if web: await check_rotate(menu)
  menu.queue_free()
  await process_frame
  var table = load("res://scenes/table.tscn").instantiate()
  table.auto_drive = false
  table.seed_value = 42
  root.add_child(table)
  current_scene = table
  await process_frame
  table.menu()
  verify(find_button(table, "Exit game").visible == not web, "Exit visibility")
  if web:
   await check_rotate(table)
   table.close_menu()
   SaveGame.remove()
   verify(table.can_save(), "Safe starting point")
   table.page_hidden()
   verify(FileAccess.file_exists(SaveGame.PATH), "Page hidden saves")
   for flag in ["pending", "acting", "driving", "saving"]:
    SaveGame.remove()
    table.set(flag, true)
    table.page_hidden()
    verify(not FileAccess.file_exists(SaveGame.PATH), "Unsafe page hidden: " + flag)
    table.set(flag, false)
  table.queue_free()
  await process_frame
 style.web_override = true
 style.web_android_override = true
 var touch = load("res://scripts/ui/touch.gd").new()
 root.add_child(touch)
 verify(touch.touch_mode, "web_android starts touch mode")
 touch._input(InputEventMouseMotion.new())
 verify(touch.touch_mode, "Phone mouse motion preserves touch mode")
 var emulated = InputEventMouseMotion.new()
 emulated.device = InputEvent.DEVICE_ID_EMULATION
 touch._input(emulated)
 verify(touch.touch_mode, "Emulated mouse preserves touch mode")
 touch.free()
 style.web_override = null
 style.web_android_override = null
 check_export_versions()
 quit_checks()
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("v07 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func remove_tree(path: String):
 var dir = DirAccess.open(path)
 if dir == null: return
 dir.include_hidden = true
 for name in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
 for name in dir.get_directories(): remove_tree(path.path_join(name))
 DirAccess.remove_absolute(path)
## Back and Escape on the main menu. A quit() would also end this suite (with exit code 0), so each case runs
## in a subprocess (menu_quit_helper.gd, next to this file) with an empty user:// of its own.
func quit_checks():
 var helper = get_script().resource_path.get_base_dir().path_join("menu_quit_helper.gd")
 var scratch = OS.get_user_data_dir().path_join("v07-subprocess-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(scratch)
 var had_xdg = OS.has_environment("XDG_DATA_HOME")
 var old_xdg = OS.get_environment("XDG_DATA_HOME")
 OS.set_environment("XDG_DATA_HOME", scratch)
 var alive = {}
 for scenario in ["desktop-escape", "menu-back", "stats-back", "web-escape"]:
  var output = []
  var code = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", helper, "--", scenario], output, true)
  var text = "\n".join(output)
  verify(code == 0 and ("MENU_QUIT_HELPER START " + scenario) in text and not "SCRIPT ERROR" in text, "Menu subprocess runs cleanly: " + scenario)
  alive[scenario] = "MENU_QUIT_HELPER ALIVE stats_open=false" in text
 if had_xdg: OS.set_environment("XDG_DATA_HOME", old_xdg)
 else: OS.unset_environment("XDG_DATA_HOME")
 remove_tree(scratch)
 verify(not alive["desktop-escape"], "Escape on the desktop main menu quits")
 verify(not alive["menu-back"], "Android Back on the main menu quits the app")
 verify(alive["stats-back"], "Android Back on Stats closes Stats and keeps the app running")
 verify(alive["web-escape"], "Escape on the web main menu keeps the game running")
func check_rotate(scene):
 var cover = get_first_node_in_group("rotate_cover")
 var probe = Button.new()
 probe.position = Vector2(100, 100)
 probe.size = Vector2(200, 100)
 probe.pressed.connect(func(): clicks += 1)
 var probe_layer = CanvasLayer.new()
 probe_layer.layer = 999
 scene.add_child(probe_layer)
 probe_layer.add_child(probe)
 root.size = Vector2i(400, 800)
 await process_frame
 await process_frame
 verify(cover.visible, "Portrait overlay on " + scene.name)
 verify(cover.mouse_filter == Control.MOUSE_FILTER_STOP, "Overlay stops GUI input")
 var before = clicks
 click_at(probe.get_global_rect().get_center())
 await process_frame
 verify(clicks == before, "Portrait blocks underlying clicks")
 root.size = Vector2i(1600, 800)
 await process_frame
 await process_frame
 verify(not cover.visible, "Landscape hides overlay")
 click_at(probe.get_global_rect().get_center())
 await process_frame
 verify(clicks == before + 1, "Landscape restores clicks")
 probe_layer.queue_free()
## The Android and Windows builds carry the version from project.godot, as every release since
## v0.04 has: "0.28" -> Android version/name "0.28" and version/code 28, Windows "0.0.28.0".
func check_export_versions():
 var version = str(ProjectSettings.get_setting("application/config/version", ""))
 var parts = version.split(".")
 var presets = ConfigFile.new()
 var readable = presets.load("res://export_presets.cfg") == OK and parts.size() == 2
 verify(readable, "Export presets and config/version " + version)
 if not readable: return
 var options = {}
 for section in presets.get_sections():
  if section.begins_with("preset.") and not section.ends_with(".options"): options[presets.get_value(section, "platform", "")] = section + ".options"
 var android = options.get("Android", "")
 var windows = options.get("Windows Desktop", "")
 var code = int(parts[0]) * 100 + int(parts[1])
 var file_version = "%d.0.%d.0" % [int(parts[0]), int(parts[1])]
 verify(str(presets.get_value(android, "version/name", "")) == version, "Android version/name is " + version)
 verify(str(presets.get_value(android, "version/code", "")) == str(code), "Android version/code is %d" % code)
 for key in ["application/file_version", "application/product_version"]:
  verify(str(presets.get_value(windows, key, "")) == file_version, "Windows %s is %s" % [key.get_file(), file_version])
