extends SceneTree
var checks = 0
var failures = 0
var table
var result = null
var wire_result = null
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func frames(n = 4):
 for i in n: await process_frame
func capture(cards, minimum, maximum):
 result = await table.decision("Choose cards", [], cards, minimum, maximum, true, true)
func dialog():
 for child in table.get_children():
  if child is PanelContainer and named(child, "DecisionDone") != null: return child
 return null
func named(node, title):
 if node.name == title: return node
 for child in node.get_children():
  var found = named(child, title)
  if found != null: return found
 return null
func sections(node) -> Array:
 var found = []
 if node.has_meta("decision_section"): found.append(node)
 for child in node.get_children(): found.append_array(sections(child))
 return found
func mouse(panel, point, pressed):
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = point
 event.pressed = pressed
 panel.gui_input.emit(event)
func escape():
 var event = InputEventKey.new()
 event.keycode = KEY_ESCAPE
 event.pressed = true
 table._unhandled_key_input(event)
func outside(panel):
 mouse(panel, Vector2(2, 2), true)
 mouse(panel, Vector2(2, 2), false)
func ask_remote(server, kind, data, args):
 wire_result = await server.ask(0, data.merged({"kind": kind, "text": "Choose one"}), args)
func online_checks():
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{}, {}], "2026", 100, 72)
 server.set_process(false)
 var session = OnlineSession.new()
 root.add_child(session)
 session.set_process(false)
 session.client.seats = server.seats.duplicate(true)
 var pair = LoopbackTransport.pair()
 server.attach(pair[0])
 server.authenticated[pair[0]] = 0
 server.connections[0] = pair[0]
 session.client.transport = pair[1]
 pair[1].received.connect(session.client._receive)
 session.client.prompt.connect(table.online_prompt)
 table.online_session = session
 var saved_state = table.engine.state
 table.engine.state = NetView.apply(NetView.build(server.engine, 0))
 var p = server.engine.state.players[0]
 var options: Array[String] = ["+2 hacking", "Deal 2 damage", "Cancel"]
 for kind in ["choose_cards", "choose_option"]:
  wire_result = null
  var data = {"cards": p.hand.map(RemoteDecider.card_data), "min": 0, "max": 1} if kind == "choose_cards" else {"options": options}
  ask_remote(server, kind, data, [])
  await frames()
  outside(dialog())
  for i in 30:
   if server.pending.is_empty(): break
   await process_frame
  verify(wire_result == ([] if kind == "choose_cards" else 2) and server.pending.is_empty(), "Online UI cancellation accepted by server: " + kind)
 # Same timeout handler invoked by _process after 45 seconds.
 for i in 20:
  wire_result = null
  ask_remote(server, "choose_option", {"options": options}, [p, "Choose one", options])
  var id = server.pending.keys()[0]
  server._fallback(id)
  await frames()
  verify(wire_result in [0, 1] and server.pending.is_empty(), "Server timeout fallback resolves Payphone")
  if table.pending:
   table.online_prompt_id = ""
   table.answered.emit(null)
   await frames()
 table.online_session = null
 table.engine.state = saved_state
 pair[0].close()
 session.queue_free()
 server.queue_free()
 await frames()
func run():
 root.size = Vector2i(1920, 1080)
 root.get_node("Sfx").auto_end_turn = false
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 root.add_child(table)
 await frames()
 var p = table.engine.state.players[0]
 table.engine.state.active_seat = 0
 var cards = []
 for i in 5: cards.append(CardInstance.new(97000 + i, "Hacking", 0))
 p.hand.assign(cards.slice(0, 2))
 p.discard.assign(cards.slice(2))
 for bounds in [[0, 0], [0, 1], [1, 1]]:
  result = null
  capture(cards, bounds[0], bounds[1])
  await frames()
  var panel = dialog()
  var center = panel.get_child(0).get_global_rect().get_center()
  mouse(panel, center, true)
  mouse(panel, center, false)
  verify(table.pending, "Inside click preserves decision")
  mouse(panel, Vector2(2, 2), true)
  mouse(panel, Vector2(80, 2), false)
  verify(table.pending, "Outside drag preserves decision")
  outside(panel)
  await frames()
  if bounds[0] == 0:
   verify(not table.pending and result == [], "Outside answers empty for viewer/optional picker")
  else:
   verify(table.pending and named(panel, "DecisionHint").visible, "Mandatory outside shows hint")
   escape()
   verify(table.pending, "Mandatory Back preserves decision")
   table.answered.emit([0])
   await frames()
 for bounds in [[0, 0], [0, 1]]:
  capture(cards, bounds[0], bounds[1])
  await frames()
  escape()
  await frames()
  verify(not table.pending and result == [], "Back answers empty")
 capture(cards, 0, 1)
 await frames()
 var held_panel = dialog()
 mouse(held_panel, Vector2(2, 2), true)
 await create_timer(0.5).timeout
 mouse(held_panel, Vector2(2, 2), false)
 verify(table.pending, "Outside long press does not dismiss")
 escape()
 await frames()
 table.decision("Mandatory option", ["Resolve"], [], 1, 1, false)
 await frames()
 held_panel = dialog()
 outside(held_panel)
 verify(table.pending and named(held_panel, "DecisionHint").visible, "Mandatory option outside gives feedback")
 table.answered.emit(0)
 await frames()
 var style = load("res://scripts/ui/style.gd")
 for compact in [false, true]:
  style.compact_override = compact
  for view in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
   root.size = view
   capture(cards, 0, 2)
   await frames()
   var panel = dialog()
   var groups = sections(panel)
   verify(groups.size() == 2, "Two zone sections")
   verify(groups[0].get_child(0).text == "// YOUR HAND · 2" and groups[1].get_child(0).text == "// YOUR DISCARD PILE · 3", "Zone headers and counts")
   verify(groups[0].get_child(1).get_children().map(func(b): return b.get_meta("uid")) == [97000, 97001], "Hand uids preserve order")
   verify(groups[1].get_child(1).get_children().map(func(b): return b.get_meta("uid")) == [97002, 97003, 97004], "Discard uids preserve order")
   var done = named(panel, "DecisionDone")
   verify(done.text == "Choose none", "Visible empty answer")
   groups[0].get_child(1).get_child(1).pressed.emit()
   groups[1].get_child(1).get_child(2).pressed.emit()
   verify(done.text == "Confirm selection", "Selection changes label")
   var box = panel.get_child(0)
   verify(Rect2(Vector2.ZERO, Vector2(view)).encloses(box.get_global_rect()), "Dialog fits viewport")
   if compact: verify(done.size.y >= 72 and done.get_theme_font_size("font_size") >= 22, "Compact primary target")
   box.get_child(1).text = "no matching card"
   box.get_child(1).text_changed.emit("no matching card")
   await frames()
   verify(groups.all(func(g): return not g.visible), "Search hides empty sections")
   done.pressed.emit()
   await frames()
   verify(result == [1, 4] and result.map(func(i): return cards[i].uid) == [97001, 97004], "Selection retains original indices and uids across sections")
 style.compact_override = null
 capture(cards.slice(0, 2), 0, 1)
 await frames()
 verify(sections(dialog()).is_empty() and named(dialog(), "DecisionZoneSubtitle").text == "From your hand", "Single zone subtitle without headers")
 table.go_back()
 await frames()
 var options: Array[String] = ["+2 hacking", "Deal 2 damage", "Cancel"]
 for difficulty in 3:
  var bot = BotDecider.new(table.engine, difficulty)
  for i in 100:
   verify(await bot.choose_option(p, "Choose one", options) in [0, 1], "Bot never cancels Payphone")
 verify(RemoteDecider.valid({"kind": "choose_option", "options": options}, 2, table.engine.db()), "Wire accepts Payphone Cancel index")
 verify(RemoteDecider.valid({"kind": "choose_cards", "cards": cards.map(RemoteDecider.card_data), "min": 0, "max": 1}, [], table.engine.db()), "Wire accepts empty optional selection")
 var phone = CardInstance.new(98000, "Payphone", 0)
 p.play_area.append(phone)
 table.engine.activate(p, phone)
 await frames()
 outside(dialog())
 await frames()
 verify(not phone.flags.used and table.engine.activatable_abilities(p, phone)[0].enabled, "Outside cancels Payphone and keeps ability enabled")
 for id in ["Disassembled Sink", "FOTTR Greatest Hits"]:
  var source = CardInstance.new(99000 if id == "Disassembled Sink" else 99001, id, 0)
  p.play_area.append(source)
  table.engine.activate(p, source)
  await frames()
  outside(dialog())
  await frames()
  verify(not source.flags.used and table.engine.activatable_abilities(p, source)[0].enabled, id + " UI back preserves ability")
  var before = p.hand.size()
  var life = table.engine.state.players[1].life
  table.engine.activate(p, source)
  await frames()
  var grid = dialog().get_child(0).get_node("DecisionScroll").get_child(0)
  grid.get_meta("decision_buttons")[0].pressed.emit()
  named(dialog(), "DecisionDone").pressed.emit()
  await frames()
  verify(source.flags.used and not table.engine.activatable_abilities(p, source)[0].enabled, id + " UI real selection consumes use")
  verify(p.hand.size() == before if id == "Disassembled Sink" else table.engine.state.players[1].life == life - 2, id + " UI reward applied")
 for difficulty in 3:
  table.engine.deciders[0] = BotDecider.new(table.engine, difficulty)
  for i in 30:
   phone.flags.used = false
   var hacking = p.hacking
   var life = table.engine.state.players[1].life
   table.engine.state.players[1].life = 10000
   await table.engine.activate(p, phone)
   verify(phone.flags.used and (p.hacking == hacking + 2 or table.engine.state.players[1].life == 9998), "Bot activation resolves Payphone")
 table.engine.deciders[0] = HumanDecider.new(table)
 await online_checks()
 table.queue_free()
 await frames()
 # A player knocked below zero must not make the saved match stats unreadable.
 var negative = load("res://scripts/ui/match_stats.gd").new()
 negative.setup(2, "2025", [-1, 0])
 negative.seats[1].final_life = -3
 var back = negative.from_dict(JSON.parse_string(JSON.stringify(negative.to_dict())))
 verify(back != null and back.seats[1].final_life == -3, "Match stats with a negative final life round trip")
 print("v20 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
