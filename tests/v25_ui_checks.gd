extends SceneTree
var checks = 0
var failures = 0
var BUILDER
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func frames(n = 5):
 for i in n: await process_frame
func buttons(node, out = []) -> Array:
 if node is Button: out.append(node)
 for child in node.get_children(): buttons(child, out)
 return out
func find_button(node, text):
 for button in buttons(node, []):
  if button.text.begins_with(text): return button
 return null
func labels(node, text) -> bool:
 if node is Label and text in node.text: return true
 for child in node.get_children():
  if labels(child, text): return true
 return false
func visible_buttons_fit(node):
 var viewport = root.get_visible_rect()
 for button in buttons(node, []):
  if not button.is_visible_in_tree(): continue
  var visible_rect = button.get_global_rect()
  var parent = button.get_parent()
  while parent != null:
   if parent is ScrollContainer: visible_rect = visible_rect.intersection(parent.get_global_rect())
   parent = parent.get_parent()
  if visible_rect.has_area(): verify(viewport.encloses(visible_rect), "Visible button fits: " + button.text + " " + str(visible_rect))
func run():
 var backups = {}
 for path in ["user://decks.json", "user://decks.json.tmp"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 await compact_menu_layout_checks()
 BUILDER = load("res://scripts/ui/deck_builder.gd")
 root.size = Vector2i(1920, 1080)
 var style = load("res://scripts/ui/style.gd")
 var sfx = root.get_node("Sfx")
 sfx.visual_effects = false
 sfx.auto_end_turn = false
 sfx.bot_pace = 0.0
 SaveGame.remove()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(BUILDER.PATH))
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await frames()
 verify(find_button(menu, "Decks (experimental)") != null, "Decks menu button")
 verify(find_button(menu, "Custom deck (experimental)") != null, "Custom card set option")
 find_button(menu, "Decks (experimental)").pressed.emit()
 await frames()
 var builder
 for child in menu.get_children():
  if child.get_script() == BUILDER: builder = child
 verify(builder != null, "Builder opens from menu")
 verify(labels(builder, "Tag Team") and labels(builder, "Greatest Hits"), "Both starters listed")
 verify(find_button(builder, "Duplicate") != null and find_button(builder, "Edit") == null, "Starters read-only")
 var starter = BUILDER.builtins()[0]
 builder.edit({"name": "Limits", "cards": {}}, -1)
 await frames(10)
 verify(builder.grid.columns >= 5, "Desktop grid has at least five columns")
 verify(absf(builder.grid.size.x - builder.grid.get_parent().size.x) < 8, "Grid fills catalog width")
 var old_columns = builder.grid.columns
 root.size = Vector2i(2400, 1080)
 await frames(10)
 verify(builder.grid.columns > old_columns, "Grid recomputes columns on resize")
 root.size = Vector2i(1920, 1080)
 await frames(10)
 for i in 4: verify(builder.change_card("nirtom", 1), "Add normal copy")
 verify(builder.printing_buttons.nirtom.count.text == "×4", "Tile badge reflects added copies")
 verify("Max 4 shared" in builder.printing_buttons.nirtom.detail.text, "Disabled tile shows shared limit")
 verify(not builder.change_card("nirtom", 1) and builder.deck.cards.nirtom == 4, "Fifth copy blocked")
 for i in 2: verify(builder.change_card("PhreakNIC", 1), "Add Legendary")
 verify(not builder.change_card("PhreakNIC@mog", 1), "Third Legendary across printings blocked")
 for i in 3: builder.change_card("Botnet", 1)
 builder.change_card("Mognet", 1)
 verify(not builder.change_card("Mognet", 1), "Botnet and Mognet share limit")
 verify(builder.chosen.get_child_count() == builder.deck.cards.size(), "Deck has one row per printing")
 var previous_name = ""
 for row in builder.chosen.get_children():
  var title = row.get_child(0).text
  verify(previous_name.naturalnocasecmp_to(title) <= 0, "Deck rows sorted by name")
  previous_name = title
 verify(labels(builder.chosen, "Mognet · Mog Variant"), "Mog printing identified")
 builder.change_card("PhreakNIC", -1)
 builder.change_card("PhreakNIC@mog", 1)
 verify(labels(builder.chosen, CustomDeck.database().get_card("PhreakNIC@mog").name + " · Mog Variant"), "Alternate name retains Mog printing label")
 var click = InputEventMouseButton.new()
 click.button_index = MOUSE_BUTTON_RIGHT
 click.pressed = true
 builder.printing_buttons.PhreakNIC.plus.gui_input.emit(click)
 await frames()
 verify(is_instance_valid(builder.modal) and labels(builder.modal, "PhreakNIC"), "Right-click previews even at copy limit")
 builder.back()
 await frames()
 builder.type_filter.select(1)
 builder.search.text = "nirtom"
 builder.filter_cards()
 verify(builder.printing_buttons.nirtom.cell.visible and not builder.printing_buttons.Botnet.cell.visible, "Search and type filters")
 builder.search.text = ""
 builder.type_filter.select(0)
 builder.set_filter.select(3)
 builder.filter_cards()
 verify(builder.printing_buttons.values().all(func(e): return e.cell.visible == (e.printing.set == "2026mog")), "Mog set filter")
 builder.set_filter.select(0)
 builder.cost_filter.select(1)
 builder.filter_cards()
 var cost = int(builder.cost_filter.get_item_text(1))
 verify(builder.printing_buttons.values().all(func(e): return e.cell.visible == (int(e.printing.cost) == cost)), "Exact cost filter")
 builder.deck.cards = {}
 for printing in builder.printings:
  if CustomDeck.total(builder.deck) == 200: break
  if builder.deck.cards.has(printing.base_id): continue
  builder.deck.cards[printing.id] = 2
 builder.refresh_counts()
 verify(CustomDeck.total(builder.deck) == 200 and not builder.change_card("nirtom", 1), "Card 201 blocked")
 builder.edit(starter, -1)
 builder.deck.name = "UI saved"
 verify(builder.save_deck(), "Save valid 60-card deck")
 verify(BUILDER.saved().size() == 1 and BUILDER.saved()[0].name == "UI saved", "Reload saved deck")
 builder.share(BUILDER.saved()[0])
 var code = builder.copy_code(BUILDER.saved()[0])
 verify(code.begins_with("PNDK1.") and builder.status.text == "Copied", "UI copy code with feedback")
 builder.modal.queue_free()
 await frames()
 builder.show_import()
 var input
 for child in builder.modal.get_child(0).get_children():
  if child is TextEdit: input = child
 input.text = "bad code"
 find_button(builder.modal, "Import").pressed.emit()
 verify(labels(builder.modal, "Invalid deck code"), "Invalid UI import shows error")
 input.text = code
 find_button(builder.modal, "Import").pressed.emit()
 await frames()
 verify(builder.deck.name == "UI saved (2)" and builder.deck.cards == CustomDeck.normalize(starter).cards, "UI import round trip and unique name")
 verify(builder.save_deck(), "Save imported deck")
 builder.edit({"name": "Draft", "cards": {"nirtom": 1}}, -1)
 verify(builder.save_button.disabled and builder.save_deck(true), "Keep unfinished draft")
 verify(labels(builder, "Incomplete"), "Draft badge")
 verify(BUILDER.playable().size() == 4, "Draft excluded from playable decks")
 builder.confirm_delete(0)
 find_button(builder.modal, "Cancel").pressed.emit()
 await frames()
 verify(BUILDER.saved().size() == 3, "Delete requires confirmation")
 builder.confirm_delete(0)
 find_button(builder.modal, "Delete").pressed.emit()
 await frames()
 verify(BUILDER.saved().size() == 2 and BUILDER.saved()[0].name == "UI saved (2)", "Confirmed deletion persists")
 var file = FileAccess.open(BUILDER.PATH, FileAccess.WRITE)
 file.store_string("{broken")
 file.close()
 verify(BUILDER.saved().is_empty(), "Corrupt storage safely ignored")
 file = FileAccess.open(BUILDER.PATH, FileAccess.WRITE)
 file.store_string('[null, {"name":"Bad", "cards":{"nirtom":"oops"}}]')
 file.close()
 verify(BUILDER.saved().is_empty(), "Malformed deck entries safely ignored")
 builder.queue_free()
 await frames()
 sfx.custom_deck_name = "Deleted deck"
 menu.resolve_custom_deck()
 verify(menu.custom_deck.name == "Tag Team", "Deleted selection falls back to starter")
 root.size = Vector2i(1900, 860)
 style.compact_override = true
 builder = BUILDER.new()
 root.add_child(builder)
 await frames()
 visible_buttons_fit(builder)
 builder.edit(starter, -1)
 await frames(10)
 visible_buttons_fit(builder)
 verify(builder.grid.get_parent().get_parent().size.y > 200, "Phone editor has scrollable card space")
 verify(builder.cards_view.visible and not builder.deck_view.visible, "Cards tab starts with catalog only")
 verify(builder.deck_tab.text == "Deck (60)", "Deck tab shows total")
 builder.deck_tab.pressed.emit()
 await frames()
 verify(builder.deck_view.visible and not builder.cards_view.visible and builder.problems.is_visible_in_tree(), "Deck tab switches view and retains validation")
 visible_buttons_fit(builder)
 builder.cards_tab.pressed.emit()
 await frames()
 verify(builder.cards_view.visible and not builder.deck_view.visible, "Cards tab restores catalog")
 for button in buttons(builder, []):
  if button.is_visible_in_tree(): verify(button.size.y >= 72, "Compact touch target height")
 builder.share(starter)
 await frames()
 visible_buttons_fit(builder.modal)
 builder.back()
 await frames()
 verify(not is_instance_valid(builder.modal), "Back closes overlay")
 # The starter copy isn't saved yet, so Back asks before throwing it away.
 builder.back()
 await frames()
 var asked = not builder.deck.is_empty() and is_instance_valid(builder.modal) and find_button(builder.modal, "Discard") != null
 verify(asked, "Back on an unsaved deck asks first")
 if asked:
  visible_buttons_fit(builder.modal)
  find_button(builder.modal, "Discard").pressed.emit()
  await frames()
 verify(builder.deck.is_empty(), "Discard returns to list")
 builder.queue_free()
 style.compact_override = null
 await frames()
 menu.choose_custom_deck()
 await frames()
 for child in menu.get_children():
  if child.get_script() == BUILDER: builder = child
 verify(find_button(builder, "Use deck") != null, "Custom selection offers valid starters")
 find_button(builder, "Use deck").pressed.emit()
 await frames()
 verify(not menu.bans_button.visible and sfx.card_pool == "custom", "Custom selection hides bans")
 verify("Tag Team" in menu.custom_tile.text and "60 cards" in menu.custom_tile.text, "Custom tile names selected deck")
 sfx.save()
 var config = OnlineAPI.settings()
 verify(config.get_value("game", "custom_deck_name") == "Tag Team" and config.get_value("game", "card_pool") == "custom", "Selection remembered")
 menu.launch()
 current_scene.auto_drive = false
 await frames()
 var table = current_scene
 table.auto_drive = false
 verify(table.engine.state.card_pool == "custom", "Menu starts custom game")
 var counts = {}
 for card in table.engine.state.center_deck + table.engine.state.center_row: counts[card.id] = counts.get(card.id, 0) + 1
 verify(counts == CustomDeck.normalize(starter).cards, "Center Deck plus Row exactly matches chosen deck")
 verify(labels(table, "Custom deck: Tag Team"), "Table custom label")
 verify(table.share_details(null).custom_deck.name == "Tag Team", "Share gets custom name")
 await table.engine.start_turn(0)
 await frames()
 verify(table.save_game(), "Custom game saved")
 var resume = SaveGame.read()
 verify(not resume.is_empty(), "Custom save readable")
 table.queue_free()
 await frames()
 menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 await frames()
 verify(labels(menu, "Custom deck: Tag Team"), "Resume label names custom deck")
 menu.launch(resume)
 await frames()
 table = current_scene
 table.auto_drive = false
 verify(table.engine.state.card_pool == "custom" and table.engine.state.custom_deck.name == "Tag Team", "Menu resumes custom game")
 var stats = table.match_stats
 stats.finish(0, table.engine.state.players)
 var store = load("res://scripts/ui/lifetime_stats.gd").new()
 store.reset()
 verify(store.record(stats, 0, "", "local", "v25-ui"), "Experimental game recorded")
 var screen = load("res://scripts/ui/stats_screen.gd").open(table)
 await frames()
 verify(labels(screen.content, "No finished games yet"), "Lifetime excludes custom game")
 find_button(screen, "Experimental decks").pressed.emit()
 await frames()
 verify(labels(screen.content, "1 games") and labels(screen.content, "Tag Team") and labels(screen.content, "By difficulty".to_upper()), "Experimental tab shows totals, difficulty and deck")
 find_button(screen, "Lifetime").pressed.emit()
 verify(labels(screen.content, "No finished games yet"), "Lifetime toggle preserves isolation")
 table.queue_free()
 SaveGame.remove()
 for path in ["res://scripts/ui/deck_builder.gd", "res://scripts/ui/menu.gd", "res://scripts/ui/result_share.gd"]:
  verify(not FileAccess.get_file_as_string(path).contains("JavaScriptBridge" + ".eval"), "No eval: " + path)
 await unsaved_deck_checks()
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var restored_file = FileAccess.open(path, FileAccess.WRITE)
   restored_file.store_buffer(backups[path])
   restored_file.close()
 print("v25 UI checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)

func copies(builder, id: String) -> int:
 return int(builder.deck.get("cards", {}).get(id, 0))
## The three ways out of the deck editor.
func leave_editor(builder, path: String):
 match path:
  "Back button": find_button(builder, "Back").pressed.emit()
  "Escape":
   var escape = InputEventKey.new()
   escape.keycode = KEY_ESCAPE
   escape.physical_keycode = KEY_ESCAPE
   escape.pressed = true
   builder._unhandled_key_input(escape)
  "Android Back": builder.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
## Leaving the deck editor with unsaved work asks first: Keep draft, Discard or Cancel. Back on the question cancels it.
func unsaved_deck_checks():
 DirAccess.remove_absolute(ProjectSettings.globalize_path(BUILDER.PATH))
 var builder = BUILDER.new()
 root.add_child(builder)
 await frames()
 builder.edit({"name": "Unsaved", "cards": {}}, -1)
 builder.back()
 await frames()
 verify(builder.deck.is_empty() and not is_instance_valid(builder.modal), "Back from an empty new deck returns to the list")
 for path in ["Back button", "Escape", "Android Back"]:
  builder.edit({"name": "Unsaved", "cards": {}}, -1)
  for i in 4: builder.change_card("nirtom", 1)
  leave_editor(builder, path)
  await frames()
  var asked = is_instance_valid(builder.modal) and find_button(builder.modal, "Keep draft") != null and find_button(builder.modal, "Discard") != null and find_button(builder.modal, "Cancel") != null
  verify(asked and copies(builder, "nirtom") == 4, path + " with unsaved cards asks first")
  if asked:
   if path == "Back button": find_button(builder.modal, "Cancel").pressed.emit()
   else: leave_editor(builder, path)
   await frames()
  verify(not is_instance_valid(builder.modal) and copies(builder, "nirtom") == 4, path + ": Cancel keeps editing")
 builder.edit({"name": "Unsaved", "cards": {}}, -1)
 for i in 4: builder.change_card("nirtom", 1)
 builder.back()
 await frames()
 if is_instance_valid(builder.modal): find_button(builder.modal, "Keep draft").pressed.emit()
 await frames()
 verify(builder.deck.is_empty() and BUILDER.saved().any(func(d): return d.name == "Unsaved" and CustomDeck.total(d) == 4), "Keep draft saves the deck and returns to the list")
 builder.edit({"name": "Saved", "cards": {"nirtom": 4}}, -1)
 builder.save_deck(true)
 var index = builder.decks.size() - 1
 builder.edit(builder.decks[index], index)
 builder.back()
 await frames()
 verify(builder.deck.is_empty() and not is_instance_valid(builder.modal), "Back from an unchanged saved deck returns to the list")
 builder.edit(builder.decks[index], index)
 builder.change_card("nirtom", -1)
 builder.back()
 await frames()
 var changed_asked = is_instance_valid(builder.modal) and find_button(builder.modal, "Discard") != null
 verify(changed_asked, "Back from a changed saved deck asks first")
 if changed_asked: find_button(builder.modal, "Discard").pressed.emit()
 await frames()
 verify(builder.deck.is_empty() and BUILDER.saved()[index].cards.get("nirtom", 0) == 4, "Discard keeps the saved deck as it was")
 builder.queue_free()
 await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(BUILDER.PATH))

func compact_menu_layout_checks():
 var style = load("res://scripts/ui/style.gd")
 var previous = style.compact_override
 style.compact_override = true
 var menu = load("res://scenes/menu.tscn").instantiate()
 root.add_child(menu)
 # Resize the same live menu to cover rotation and browser chrome changes.
 for dimensions in [Vector2i(2770, 1080), Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(1920, 1440), Vector2i(1920, 2400), Vector2i(2400, 1080), Vector2i(2770, 1080)]:
  root.size = dimensions
  await frames(10)
  var column = menu.find_child("CompactMenuColumn", true, false)
  var scroll = menu.find_child("CompactMenuScroll", true, false)
  var credits = menu.find_child("CompactMenuCredits", true, false)
  var version = menu.find_child("CompactMenuVersion", true, false)
  var rect = column.get_global_rect()
  var viewport = root.get_visible_rect()
  verify(absf(rect.position.x - (viewport.size.x - rect.end.x)) <= 3, "Compact menu centered at " + str(dimensions))
  verify(rect.size.x <= menu.COMPACT_WIDTH and rect.size.x <= viewport.size.x - 64, "Compact menu bounded at " + str(dimensions))
  verify(not credits.get_global_rect().intersects(scroll.get_global_rect()), "Compact menu clears credits at " + str(dimensions))
  verify(viewport.encloses(credits.get_global_rect()), "Compact credits visible at " + str(dimensions))
  verify(viewport.encloses(version.get_global_rect()), "Compact version visible at " + str(dimensions))
  verify(not version.get_global_rect().intersects(scroll.get_global_rect()) and not version.get_global_rect().intersects(credits.get_global_rect()), "Compact version clears content and credits")
  # Phone browsers (about 2340-2770 x 1080 virtual) see the whole menu without scrolling.
  if dimensions.y == 1080 and dimensions.x >= 2340: verify(scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1, "Compact menu fits without scrolling at " + str(dimensions))
  var left = menu.find_child("CompactMenuLeft", true, false)
  var right = menu.find_child("CompactMenuRight", true, false)
  verify(left.get_global_rect().end.x <= right.get_global_rect().position.x, "Compact menu has two columns at " + str(dimensions))
  scroll.scroll_vertical = 100000
  await frames()
  visible_buttons_fit(menu)
  scroll.scroll_vertical = 0
 # Settings live in a pop-up on phones; Back closes it and keeps the controls for next time.
 root.size = Vector2i(2340, 1080)
 await frames(5)
 verify(not menu.find_child("CompactMenuSettings", true, false).is_visible_in_tree(), "Compact settings start hidden")
 find_button(menu, "Settings").pressed.emit()
 await frames(5)
 verify(is_instance_valid(menu.settings_overlay) and find_button(menu, "Done").is_visible_in_tree(), "Compact settings pop-up opens")
 verify(root.get_visible_rect().encloses(find_button(menu, "Done").get_global_rect()), "Compact settings fit the screen")
 visible_buttons_fit(menu.settings_overlay)
 menu.go_back()
 await frames(5)
 verify(not is_instance_valid(menu.settings_overlay) and menu.settings_box.get_parent() == menu and not menu.settings_box.visible, "Back closes compact settings")
 find_button(menu, "Settings").pressed.emit()
 await frames(5)
 find_button(menu, "Done").pressed.emit()
 await frames(5)
 verify(not is_instance_valid(menu.settings_overlay), "Done closes compact settings")
 for path in menu.hero_picker.loading_icons: ResourceLoader.load_threaded_get(path)
 menu.free()
 style.compact_override = previous
