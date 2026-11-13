extends Control
## Emitted when the player closes the builder (not when the app quits with it open).
signal closed
const PATH = "user://decks.json"
var decks: Array = []
var starters: Array = []
var deck: Dictionary = {}
var editing = -1
var layout: VBoxContainer
var body: VBoxContainer
var status: Label
var selected: Callable
var modal: Control
var inspector
var grid: GridContainer
var chosen: VBoxContainer
var problems: Label
var save_button: Button
var name_input: LineEdit
var search: LineEdit
var type_filter: OptionButton
var cost_filter: OptionButton
var set_filter: OptionButton
var printing_buttons = {}
var printings: Array = []
var cards_view: ScrollContainer
var deck_view: ScrollContainer
var cards_tab: Button
var deck_tab: Button
const TILE_WIDTH = 180
static func saved() -> Array:
 if not FileAccess.file_exists(PATH): return []
 var file = FileAccess.open(PATH, FileAccess.READ)
 if file == null or file.get_length() > 1000000: return []
 var parser = JSON.new()
 if parser.parse(file.get_as_text()) != OK or not parser.data is Array: return []
 var result = []
 for value in parser.data.slice(0, 50):
  if not value is Dictionary or not value.get("name") is String or not value.get("cards") is Dictionary: continue
  if value.name.strip_edges().is_empty() or value.name.length() > 40 or value.cards.size() > 200: continue
  var safe = true
  for id in value.cards:
   var n = value.cards[id]
   if not id is String or not (n is int or n is float): safe = false; break
   if not is_finite(float(n)) or n < 1 or n > 200 or n != floor(float(n)): safe = false; break
  if safe: result.append(CustomDeck.normalize(value))
 return result
static func builtins() -> Array:
 var result = []
 for value in JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json")): result.append(CustomDeck.normalize(value))
 return result
static func playable() -> Array:
 return (builtins() + saved()).filter(func(d): return CustomDeck.validate(d).is_empty())
func _ready():
 z_index = 95
 add_to_group("touch_modal")
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 UIStyle.apply(self)
 UIStyle.background(self)
 decks = saved()
 starters = builtins()
 printings = CustomDeck.printings()
 inspector = load("res://scripts/ui/hero_picker.gd").new()
 var margin = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
 add_child(margin)
 layout = VBoxContainer.new()
 margin.add_child(layout)
 var top = HBoxContainer.new()
 layout.add_child(top)
 UIStyle.label(top, "Decks (experimental)", 30).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 UIStyle.button(top, "Close", back)
 status = UIStyle.label(layout, "Offline games only. Stats are separate.")
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body = VBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(body)
 add_child(inspector)
 show_list()
func clear_body():
 for child in body.get_children(): body.remove_child(child); child.queue_free()
func scroll_box(parent: Node) -> VBoxContainer:
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 parent.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(box)
 return box
func show_list():
 deck = {}
 clear_body()
 var actions = HBoxContainer.new()
 body.add_child(actions)
 UIStyle.button(actions, "New", func(): edit({"name": unique_name("New deck"), "cards": {}}, -1))
 UIStyle.button(actions, "Import", show_import)
 var list = scroll_box(body)
 for i in starters.size(): list_entry(list, starters[i], -1, true)
 for i in decks.size(): list_entry(list, decks[i], i, false)
func list_entry(parent: Node, value: Dictionary, index: int, builtin: bool):
 var panel = UIStyle.panel()
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var valid = CustomDeck.validate(value).is_empty()
 UIStyle.label(box, "%s · %d cards%s" % [value.name, CustomDeck.total(value), " · Starter (read-only)" if builtin else ("" if valid else " · Incomplete")])
 var row = HFlowContainer.new()
 box.add_child(row)
 if selected.is_valid():
  UIStyle.button(row, "Use deck", func(): selected.call(value.duplicate(true)); queue_free()).disabled = not valid
 else:
  if not builtin:
   UIStyle.button(row, "Edit", func(): edit(value, index))
   UIStyle.button(row, "Delete", func(): confirm_delete(index))
  UIStyle.button(row, "Duplicate", func():
   var copy = value.duplicate(true)
   copy.name = unique_name(value.name)
   edit(copy, -1))
  UIStyle.button(row, "Share", func(): share(value)).disabled = not valid
func unique_name(value: String, except: int = -1) -> String:
 var names = []
 for d in starters: names.append(d.name)
 for i in decks.size():
  if i != except: names.append(decks[i].name)
 var candidate = value.left(40)
 var n = 2
 while candidate in names:
  var suffix = " (%d)" % n
  candidate = value.left(40 - suffix.length()) + suffix
  n += 1
 return candidate
func persist() -> bool:
 var file = FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
 if file == null: status.text = "Could not save decks."; return false
 file.store_string(JSON.stringify(decks))
 file.flush()
 var ok = file.get_error() == OK
 file.close()
 if ok: ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".tmp"), ProjectSettings.globalize_path(PATH)) == OK
 if not ok: status.text = "Could not save decks."
 return ok
func save_deck(draft: bool = false) -> bool:
 deck.name = deck.name.strip_edges()
 if deck.name.is_empty() or deck.name.length() > 40: status.text = "Name must be 1–40 characters."; return false
 if not draft and not CustomDeck.validate(deck).is_empty(): return false
 if editing < 0 and decks.size() >= 50: status.text = "Limit: 50 saved decks. Delete one first."; return false
 var previous = decks.duplicate(true)
 deck.name = unique_name(deck.name, editing)
 if editing < 0: decks.append(CustomDeck.normalize(deck))
 else: decks[editing] = CustomDeck.normalize(deck)
 if not persist(): decks = previous; return false
 status.text = "Draft saved · Incomplete" if not CustomDeck.validate(deck).is_empty() else "Deck saved"
 show_list()
 return true
func popup(title: String) -> VBoxContainer:
 if is_instance_valid(modal): modal.queue_free()
 modal = UIStyle.panel()
 modal.add_to_group("touch_modal")
 add_child(modal)
 var box = VBoxContainer.new()
 modal.add_child(box)
 UIStyle.label(box, title, 26)
 UIStyle.dialog(modal, Vector2(1100, 540))
 return box
func confirm_delete(index: int):
 var box = popup("Delete %s?" % decks[index].name)
 UIStyle.button(box, "Delete", func():
  var old = decks.duplicate(true)
  decks.remove_at(index)
  if not persist(): decks = old
  modal.queue_free()
  show_list())
 UIStyle.button(box, "Cancel", func(): modal.queue_free())
func show_import():
 var box = popup("Paste deck code or file contents")
 var input = TextEdit.new()
 input.custom_minimum_size = Vector2(0, 220)
 input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 box.add_child(input)
 var error = UIStyle.label(box, "")
 UIStyle.button(box, "Import", func():
  if import_text(input.text): modal.queue_free()
  else: error.text = "Invalid deck code or file. Check the complete code.")
 UIStyle.button(box, "Cancel", func(): modal.queue_free())
func import_text(value: String) -> bool:
 var imported = CustomDeck.from_file_text(value)
 if imported.is_empty(): status.text = "Invalid deck code or file."; return false
 imported.name = unique_name(imported.name)
 edit(imported, -1)
 return true
func copy_code(value: Dictionary) -> String:
 var code = CustomDeck.encode(value)
 DisplayServer.clipboard_set(code)
 status.text = "Copied"
 return code
func share(value: Dictionary):
 var box = popup("Share " + value.name)
 var code = TextEdit.new()
 code.editable = false
 code.text = CustomDeck.encode(value)
 code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 code.custom_minimum_size.y = 180
 box.add_child(code)
 var message = UIStyle.label(box, "Select the code to copy if clipboard is unavailable.")
 message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 UIStyle.button(box, "Copy deck code", func(): copy_code(value); message.text = "Copied")
 UIStyle.button(box, "Download deck", func(): message.text = download(value))
 UIStyle.button(box, "Close", func(): modal.queue_free())
func download(value: Dictionary) -> String:
 var filename = value.name.validate_filename() + ".phreakdeck.json"
 var text = CustomDeck.to_file_text(value)
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(text.to_utf8_buffer(), filename, "application/json")
  return "Download started"
 var folder = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
 var path = folder.path_join(filename) if not folder.is_empty() else "user://" + filename
 var file = FileAccess.open(path, FileAccess.WRITE)
 if file == null:
  path = "user://" + filename
  file = FileAccess.open(path, FileAccess.WRITE)
 if file == null: return "Could not download. Copy the deck code instead."
 file.store_string(text)
 file.flush()
 var ok = file.get_error() == OK
 file.close()
 return "Saved: " + ProjectSettings.globalize_path(path) if ok else "Could not save. Copy the deck code instead."
func edit(value: Dictionary, index: int):
 deck = value.duplicate(true)
 status.text = "Tap to add · − to remove · Hold/right-click to inspect. Copies combine all printings."
 editing = index
 clear_body()
 var header = HBoxContainer.new()
 body.add_child(header)
 name_input = LineEdit.new()
 name_input.max_length = 40
 name_input.text = deck.name
 name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 header.add_child(name_input)
 name_input.text_changed.connect(func(v): deck.name = v; refresh_counts())
 save_button = UIStyle.button(header, "Save", func(): save_deck())
 UIStyle.button(header, "Keep draft", func(): save_deck(true))
 UIStyle.button(header, "Back", show_list)
 var filters = HBoxContainer.new()
 body.add_child(filters)
 search = LineEdit.new()
 search.placeholder_text = "Search cards"
 search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 filters.add_child(search)
 search.text_changed.connect(func(_v): filter_cards())
 type_filter = option(filters, ["All types", "Hero", "Exploit", "Event", "Technology", "Location", "Organization"])
 var costs = ["All costs"]
 var found = []
 for p in printings:
  if int(p.cost) not in found: found.append(int(p.cost))
 found.sort()
 for n in found: costs.append(str(n))
 cost_filter = option(filters, costs)
 set_filter = option(filters, ["All sets", "Base Set", "Expansion 1", "Mog Variant"])
 problems = UIStyle.label(body, "")
 problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 cards_tab = null
 deck_tab = null
 if UIStyle.compact():
  var tabs = HBoxContainer.new()
  body.add_child(tabs)
  cards_tab = UIStyle.button(tabs, "Cards", func(): select_editor_tab(false))
  deck_tab = UIStyle.button(tabs, "Deck (0)", func(): select_editor_tab(true))
  cards_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  deck_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var columns = HBoxContainer.new()
 columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
 body.add_child(columns)
 var catalog_box = scroll_box(columns)
 grid = GridContainer.new()
 cards_view = catalog_box.get_parent()
 grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 cards_view.resized.connect(resize_grid)
 cards_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
 catalog_box.add_child(grid)
 chosen = scroll_box(columns)
 deck_view = chosen.get_parent()
 chosen.custom_minimum_size.x = 440 if not UIStyle.compact() else 0
 if not UIStyle.compact():
  cards_view.size_flags_stretch_ratio = 3.0
 select_editor_tab(false)
 printing_buttons.clear()
 for p in printings:
  var cell = VBoxContainer.new()
  cell.custom_minimum_size.x = TILE_WIDTH
  cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  grid.add_child(cell)
  var button = UIStyle.button(cell, "", func(): change_card(p.id, 1))
  button.custom_minimum_size = Vector2(155, 225)
  button.expand_icon = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  button.add_theme_constant_override("icon_max_width", 145)
  button.clip_text = true
  button.icon = load(p.image)
  button.add_theme_font_size_override("font_size", 16)
  TouchInput.register_card(button, func(): preview(p))
  button.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
    preview(p)
    button.accept_event())
  var title = UIStyle.label(cell, p.name, 18)
  title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  title.clip_text = true
  var controls = HBoxContainer.new()
  cell.add_child(controls)
  var minus = UIStyle.button(controls, "−", func(): change_card(p.id, -1))
  var count = UIStyle.label(controls, "×0", 22)
  count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var add = UIStyle.button(controls, "+", func(): change_card(p.id, 1))
  var detail = UIStyle.label(cell, "", 16)
  detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  detail.clip_text = true
  printing_buttons[p.id] = {"cell": cell, "plus": button, "add": add, "minus": minus, "count": count, "detail": detail, "printing": p}
 refresh_counts()
 resize_grid.call_deferred()
func select_editor_tab(show_deck: bool):
 cards_view.visible = not UIStyle.compact() or not show_deck
 deck_view.visible = not UIStyle.compact() or show_deck
 if is_instance_valid(cards_tab):
  cards_tab.disabled = not show_deck
  deck_tab.disabled = show_deck
func resize_grid():
 if not is_instance_valid(grid): return
 var width = cards_view.size.x - cards_view.get_v_scroll_bar().size.x
 var gap = grid.get_theme_constant("h_separation")
 grid.columns = maxi(1, int((width + gap) / (TILE_WIDTH + gap)))
func option(parent: Node, titles: Array) -> OptionButton:
 var result = OptionButton.new()
 for title in titles: result.add_item(title)
 parent.add_child(result)
 result.item_selected.connect(func(_i): filter_cards())
 return result
func filter_cards():
 for entry in printing_buttons.values():
  var p = entry.printing
  entry.cell.visible = (search.text.is_empty() or search.text.to_lower() in p.name.to_lower()) and (type_filter.selected == 0 or type_filter.get_item_text(type_filter.selected).to_lower() in p.type_line.to_lower()) and (cost_filter.selected == 0 or int(cost_filter.get_item_text(cost_filter.selected)) == int(p.cost)) and (set_filter.selected == 0 or p.set == ["", "2025", "2026", "2026mog"][set_filter.selected])
func limit_reason(id: String) -> String:
 if CustomDeck.total(deck) >= 200: return "Maximum 200 cards"
 var base = CustomDeck.base_id(id)
 var count = 0
 for key in deck.cards:
  if CustomDeck.base_id(key) == base: count += int(deck.cards[key])
 var legendary = CustomDeck.database().has_subtype(CustomDeck.rules_id(id), "Legendary")
 var limit = 2 if legendary else 4
 return "Maximum %d copies across all printings%s" % [limit, " (Legendary)" if legendary else ""] if count >= limit else ""
func change_card(id: String, delta: int) -> bool:
 if delta > 0 and not limit_reason(id).is_empty(): status.text = limit_reason(id); return false
 var n = maxi(0, int(deck.cards.get(id, 0)) + delta)
 if n == 0: deck.cards.erase(id)
 else: deck.cards[id] = n
 refresh_counts()
 return true
func refresh_counts():
 if not is_instance_valid(problems): return
 var errors = CustomDeck.validate(deck)
 problems.text = "%d / 60–200 · %s" % [CustomDeck.total(deck), "Ready to play" if errors.is_empty() else "; ".join(errors)]
 save_button.disabled = not errors.is_empty()
 for entry in printing_buttons.values():
  var p = entry.printing
  var reason = limit_reason(p.id)
  var count = int(deck.cards.get(p.id, 0))
  entry.count.text = "×%d" % count
  entry.detail.text = "Cost %d" % p.cost
  if not reason.is_empty():
   entry.detail.text += " · " + ("Max 200 cards" if CustomDeck.total(deck) >= 200 else ("Max 2 Legendary" if p.legendary else "Max 4 shared"))
  var accent = UIStyle.CYAN if count > 0 else UIStyle.MUTED
  entry.plus.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.CYAN.darkened(0.85) if count > 0 else UIStyle.PANEL, accent, 0))
  entry.plus.add_theme_stylebox_override("disabled", UIStyle.box(UIStyle.CYAN.darkened(0.85) if count > 0 else UIStyle.PANEL, accent, 0))
  entry.count.modulate = UIStyle.CYAN if count > 0 else UIStyle.MUTED
  entry.add.disabled = not reason.is_empty()
  entry.plus.disabled = not reason.is_empty()
  entry.plus.tooltip_text = reason
  entry.minus.disabled = not deck.cards.has(p.id)
 for child in chosen.get_children(): chosen.remove_child(child); child.queue_free()
 var groups = {}
 for id in deck.cards:
  var card_name = CustomDeck.database().get_card(id).get("name", id)
  if not groups.has(card_name): groups[card_name] = []
  groups[card_name].append(id)
 if is_instance_valid(deck_tab): deck_tab.text = "Deck (%d)" % CustomDeck.total(deck)
 var keys = deck.cards.keys()
 keys.sort_custom(func(a, b):
  var an = str(CustomDeck.database().get_card(a).get("name", a))
  var bn = str(CustomDeck.database().get_card(b).get("name", b))
  return an.naturalnocasecmp_to(bn) < 0 if an != bn else a < b)
 for id in keys:
  var card_name = str(CustomDeck.database().get_card(id).get("name", id))
  var title = card_name
  var mog = id.ends_with("@mog") or CustomDeck.database().get_card(id).get("set", "") == "2026mog"
  if groups[card_name].size() > 1 or mog: title += " · " + ("Mog Variant" if mog else "Original")
  var row = HBoxContainer.new()
  chosen.add_child(row)
  var label = UIStyle.label(row, title, 18)
  label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  UIStyle.button(row, "−", func(): change_card(id, -1))
  var count = UIStyle.label(row, str(deck.cards[id]), 22)
  count.custom_minimum_size.x = 32
  count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  UIStyle.button(row, "+", func(): change_card(id, 1)).disabled = not limit_reason(id).is_empty()
func preview(p: Dictionary):
 var box = popup(p.name)
 box.add_child(UIStyle.picture(p.image, Vector2(330, 450)))
 UIStyle.button(box, "Close", func(): modal.queue_free())
func back():
 if inspector.close_top(): return
 if is_instance_valid(modal) and not modal.is_queued_for_deletion(): modal.queue_free(); return
 if not deck.is_empty(): show_list(); return
 closed.emit()
 queue_free()
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"): back(); get_viewport().set_input_as_handled()
func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST and not get_parent().has_method("go_back"): back()
