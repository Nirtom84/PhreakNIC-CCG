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
func run():
 # A phone held sideways: wide and short.
 root.size = Vector2i(1900, 860)
 var style = load("res://scripts/ui/style.gd")
 style.compact_override = true
 root.get_node("Sfx").auto_end_turn = false
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
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
 style.compact_override = null
 print("v22 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
