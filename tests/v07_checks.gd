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
 for path in ["user://settings.cfg", SaveGame.PATH]:
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
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
 print("v07 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
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
