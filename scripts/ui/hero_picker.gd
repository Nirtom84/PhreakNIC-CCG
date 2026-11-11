extends Control
# Hero card art loads in the background so the picker opens instantly (a cold, synchronous load froze phones for seconds).
var overlays: Array[Control] = []
var hero_icons: Dictionary = {}
var loading_icons: Array[String] = []
var picker_buttons: Dictionary = {}
func _ready():
 z_index = 90
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for id in UIStyle.heroes():
  var path = CardDB.image_path(id)
  if ResourceLoader.load_threaded_request(path) == OK: loading_icons.append(path)
func open(selected: Callable) -> Control:
 get_parent().move_child(self, -1)
 var overlay = PanelContainer.new()
 overlays.append(overlay)
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.label(box, "Pick a Hero", 26)
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 box.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var grid = GridContainer.new()
 grid.columns = 6
 scroll.add_child(grid)
 for id in UIStyle.heroes():
  var button = UIStyle.button(grid, str(CardDB.cards[id].name), func(): selected.call(id); overlay.queue_free())
  var path = CardDB.image_path(id)
  if hero_icons.has(path): button.icon = hero_icons[path]
  elif path in loading_icons: picker_buttons[path] = button
  else: button.icon = load(path)
  TouchInput.register_card(button, func(): inspect_hero(id))
  button.expand_icon = true
  button.custom_minimum_size = Vector2(170, 260)
  button.clip_text = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  button.add_theme_constant_override("icon_max_width", 160)
 UIStyle.button(box, "Back", overlay.queue_free)
 UIStyle.dialog(overlay, Vector2(1100, 900))

 return overlay

func _process(_delta):
 for i in range(loading_icons.size() - 1, -1, -1):
  var path = loading_icons[i]
  var status = ResourceLoader.load_threaded_get_status(path)
  if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
  loading_icons.remove_at(i)
  if status != ResourceLoader.THREAD_LOAD_LOADED: continue
  hero_icons[path] = ResourceLoader.load_threaded_get(path)
  if picker_buttons.has(path) and is_instance_valid(picker_buttons[path]): picker_buttons[path].icon = hero_icons[path]
  picker_buttons.erase(path)

func inspect_hero(id: String):
 var overlay = UIStyle.panel()
 overlays.append(overlay)
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 box.add_child(UIStyle.picture(CardDB.image_path(id), Vector2(480, 656)))
 UIStyle.button(box, "Close", overlay.queue_free)
 UIStyle.dialog(overlay, Vector2(520, 750))

func close_top() -> bool:
 while not overlays.is_empty():
  var overlay = overlays.pop_back()
  if is_instance_valid(overlay) and not overlay.is_queued_for_deletion():
   overlay.queue_free()
   return true
 return false
