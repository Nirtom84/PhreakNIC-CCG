extends SceneTree
var checks = 0
var failures = 0
var table
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func frames(n = 4):
 for i in n: await process_frame
func named(node, title):
 if node.name == title: return node
 for child in node.get_children():
  var found = named(child, title)
  if found != null: return found
 return null
func dialog():
 for child in table.get_children():
  if child is PanelContainer and named(child, "DecisionDone") != null: return child
 return null
func buttons(node, out = []) -> Array:
 if node is Button: out.append(node)
 for child in node.get_children(): buttons(child, out)
 return out
func find_text(node, text):
 for b in buttons(node, []):
  if b.text.begins_with(text): return b
 return null
func prompt(text):
 for child in table.get_children():
  if child is PanelContainer and named(child, "DecisionDone") != null and not child.is_queued_for_deletion() and text in child.get_child(0).get_child(0).get_parsed_text(): return child
 return null
func until(condition: Callable, limit = 600) -> bool:
 for i in limit:
  if condition.call(): return true
  await process_frame
 return condition.call()
func run():
 # A phone held sideways: wide and short.
 root.size = Vector2i(1900, 860)
 var style = load("res://scripts/ui/style.gd")
 style.compact_override = true
 root.get_node("Sfx").auto_end_turn = false
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 # A fixed board: the card reserved below (the first Center Row card, Share a Link) asks nothing when bought.
 table.seed_value = 22
 root.add_child(table)
 await frames()
 var engine = table.engine
 var p = engine.state.players[0]
 engine.state.active_seat = 0
 var reserved = engine.state.center_row[0]
 engine.state.center_row.erase(reserved)
 p.reserve.append(reserved)
 p.hacking = 99
 table.redraw()
 await frames()
 var open = find_text(table, "Rig: 0 · Reserved: 1")
 verify(open != null, "Phone layout shows the Open board button")
 if open != null: open.pressed.emit()
 await frames()
 var panel = dialog()
 verify(panel != null and table.pending, "Open board opens the viewer")
 if panel != null:
  var card = null
  for b in buttons(panel, []):
   if b.has_meta("uid") and b.get_meta("uid") == reserved.uid: card = b
  verify(card != null, "Reserved card is listed")
  var scroll = named(panel, "DecisionScroll")
  verify(scroll.size.y >= 233, "One-card viewer shows the whole card (%d px)" % scroll.size.y)
  verify(named(panel, "DecisionDone").get_global_rect().end.y <= root.size.y, "Close button stays on screen")
  if card != null: card.pressed.emit()
  await frames()
  verify(not table.pending, "Tapping a board card closes the viewer")
  var sheet = table.inspect_overlay
  verify(is_instance_valid(sheet), "Tapping a board card opens its action sheet")
  if is_instance_valid(sheet):
   var buy = find_text(sheet, "Buy")
   verify(buy != null and not buy.disabled, "Reserved card can be bought from the phone board")
   if buy != null: buy.pressed.emit()
   await frames(8)
   verify(reserved not in p.reserve and reserved in p.discard, "Buying from the sheet moves the card to the discard pile")
 # An ordinary viewer still only inspects.
 table.view_cards("Removed from game", [reserved])
 await frames()
 panel = dialog()
 verify(panel != null, "Plain viewer opens")
 if panel != null:
  for b in buttons(panel, []):
   if b.has_meta("uid"): b.pressed.emit()
  await frames()
  verify(table.pending, "Plain viewer stays open on tap")
  verify(is_instance_valid(table.inspect_overlay) and find_text(table.inspect_overlay, "Buy") == null, "Plain viewer inspect has no Buy")
  table.close_inspect()
  table.answered.emit([])
  await frames()
 await reaction_viewers()
 style.compact_override = null
 print("v22 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
# TOCTOU's extra turn runs inside the bot's turn, where the table counts as driving a bot. It's still your turn:
# Open board and the Deck / Discard button must open.
func reaction_viewers():
 table.queue_free()
 var settings = root.get_node("Sfx")
 var confirm = settings.confirm_end_turn
 settings.confirm_end_turn = false
 var saved_game = FileAccess.get_file_as_bytes(SaveGame.PATH) if FileAccess.file_exists(SaveGame.PATH) else null
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.bot_pace = 0
 table.seed_value = 7
 root.add_child(table)
 await frames(6)
 while table.engine.active().is_bot: await table.drive_reaction(table.engine.active())
 # You're at 1 life with TOCTOU in your next hand and a permanent in your rig; the bot holds an Attack.
 var p = table.engine.state.players[0]
 p.life = 1
 p.deck.assign([CardInstance.new(99600, "TOCTOU", 0)] + range(1, 5).map(func(i): return CardInstance.new(99600 + i, "Hacking", 0)))
 p.play_area.append(CardInstance.new(99610, "Bribery", 0))
 table.engine.state.players[1].hand.assign([CardInstance.new(99609, "Damage", 1)])
 table.redraw()
 await frames()
 table.auto_drive = true
 table.end_button.pressed.emit()
 var asked = await until(func(): return prompt("Use TOCTOU") != null)
 if asked: find_text(prompt("Use TOCTOU"), "Yes").pressed.emit()
 var saved = await until(func(): return table.banner.text.begins_with("Your turn") and not table.end_button.disabled)
 verify(asked and saved and table.driving and table.engine.reaction_depth == 1, "TOCTOU gives you a reaction turn inside the bot's turn")
 for entry in [["Rig: 1", "Open board", "Your rig & reserved"], ["Deck ", "Deck / Discard", "Your discard"]]:
  var viewer = find_text(table, entry[0])
  if viewer != null: viewer.pressed.emit()
  await frames()
  verify(prompt(entry[2]) != null, "%s opens during a TOCTOU reaction turn" % entry[1])
  if table.pending: table.go_back()
  await frames()
 table.end_button.pressed.emit()
 await until(func(): return not table.driving and not table.engine.busy)
 table.queue_free()
 await frames()
 settings.confirm_end_turn = confirm
 if saved_game == null: SaveGame.remove()
 else:
  var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
  file.store_buffer(saved_game)
  file.close()
