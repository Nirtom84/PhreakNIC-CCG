extends "res://scripts/ui/hero_picker.gd"
# Share threaded art loading, inspection and modal Back handling with HeroPicker.
var selected_pool = "2026"
var banned: Array = []
var changed: Callable
var readonly = false
var cards: Dictionary = {}
var search: LineEdit
var remaining: Label
var grid: GridContainer
func _ready():
 z_index = 91
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func open_bans(pool: String, value: Array, callback: Callable = Callable(), read_only: bool = false) -> Control:
 while close_top(): pass
 CardDB.select_pool(pool)
 selected_pool = pool
 banned = CardDB.filter_banned(value, pool)
 changed = callback
 readonly = read_only
 cards.clear()
 get_parent().move_child(self, -1)
 var overlay = UIStyle.panel()
 overlays.append(overlay)
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.label(box, "// BANNED CARDS" + (" · View only" if readonly else " · Party leader"), 26)
 search = LineEdit.new()
 search.placeholder_text = "Search cards by name"
 search.custom_minimum_size.y = 56
 box.add_child(search)
 search.text_changed.connect(filter_cards)
 remaining = UIStyle.label(box, "", 20)
 remaining.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 box.add_child(scroll)
 TouchInput.register_scroll(scroll)
 grid = GridContainer.new()
 grid.columns = 6
 grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(grid)
 for id in CardDB.center_choices(pool):
  if readonly and id not in banned: continue
  var button = UIStyle.button(grid, "", toggle_card.bind(id))
  cards[id] = button
  button.expand_icon = true
  button.custom_minimum_size = Vector2(170, 280)
  button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  button.clip_text = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  button.add_theme_constant_override("icon_max_width", 160)
  button.add_theme_font_size_override("font_size", 16)
  TouchInput.register_card(button, func(): inspect_hero(id))
  var path = CardDB.image_path(id)
  if hero_icons.has(path): button.icon = hero_icons[path]
  else:
   picker_buttons[path] = button
   if path not in loading_icons and ResourceLoader.load_threaded_request(path) == OK: loading_icons.append(path)
 var row = HBoxContainer.new()
 box.add_child(row)
 if not readonly: UIStyle.button(row, "Clear all", func(): banned.clear(); publish()).custom_minimum_size.y = 56
 UIStyle.button(row, "Done", overlay.queue_free).custom_minimum_size.y = 56
 UIStyle.dialog(overlay, Vector2(1160, 920))
 refresh()
 return overlay
func toggle_card(id: String):
 if readonly or not cards.has(id): return
 var copies = CardDB.center_copies(id, selected_pool)
 if id in banned:
  for copy in copies: banned.erase(copy)
 else:
  if CardDB.center_ids(selected_pool).size() - banned.size() - copies.size() < CardDB.MIN_CENTER_CARDS:
   remaining.text = "At least 40 center-deck cards must remain (35 after dealing the row)."
   return
  banned.append_array(copies)
 banned = CardDB.filter_banned(banned, selected_pool)
 publish()
func publish():
 refresh()
 if changed.is_valid(): changed.call(banned.duplicate())
func refresh():
 remaining.text = "%d cards banned · %d center-deck cards remain · Minimum 40 (35 after dealing the row)" % [banned.size(), CardDB.center_ids(selected_pool).size() - banned.size()]
 for id in cards:
  var button = cards[id]
  var marked = id in banned
  button.text = ("BANNED\n" if marked else "") + str(CardDB.cards[id].name) + "\nCost %d · Copies %d" % [int(CardDB.cards[id].cost), CardDB.center_copies(id, selected_pool).size()]
  button.self_modulate = Color(0.55, 0.55, 0.55) if marked else Color.WHITE
  button.add_theme_color_override("font_color", UIStyle.RED if marked else UIStyle.TEXT)
  button.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, UIStyle.RED if marked else UIStyle.CYAN, 0))
func filter_cards(value: String):
 for id in cards: cards[id].visible = value.to_lower() in str(CardDB.cards[id].name).to_lower()
