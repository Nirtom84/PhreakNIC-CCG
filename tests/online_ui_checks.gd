extends SceneTree
var checks = 0
var failures = 0
var user_backups = {}
var answer_dialogs = true
class FakeAPI extends Node:
 var calls = []
 var mismatch = false
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body})
  if mismatch: return {"status": 409, "data": {"error": "version", "need": "9.99"}}
  if method == HTTPClient.METHOD_GET: return {"status": 200, "data": {"rooms": []}}
  return {"status": 201, "data": {"code": "ABCD", "seat": 0, "token": "fake"}}
class FakeRoom extends Node:
 var server: GameServer
 var socket
 var bridge
 var index = 0
 var started = false
 var sent = []
 func _ready():
  server = GameServer.new()
  add_child(server)
  server.setup([{"name": "Host", "bot": false}, {"name": "Guest", "bot": false}], "2026", 20, 42)
 func connect_seat():
  var pair = LoopbackTransport.pair()
  socket = pair[1]
  socket.received.connect(receive)
  send_room.call_deferred()
  if started: authenticate.call_deferred()
  return pair[0]
 func send_room():
  socket.send({"t": "room", "code": "ABCD", "seats": [{"name": "Host", "hero": "", "bot": false, "difficulty": 0, "connected": true}, {"name": "Guest", "hero": "", "bot": false, "difficulty": 1, "connected": true}], "host_seat": 0, "started": started, "public": true, "card_pool": "2026", "starting_life": 20})
 func receive(data):
  sent.append(data)
  if data.t == "lobby" and data.action == "start":
   started = true
   send_room()
   socket.send({"t": "server", "status": "restarting"})
   server.start()
   authenticate()
  elif data.t in ["action", "answer"]: bridge.send(data)
 func authenticate():
  if bridge != null: bridge.close()
  var pair = LoopbackTransport.pair()
  bridge = pair[0]
  server.attach(pair[1])
  bridge.received.connect(func(data): socket.send(data))
  # The trusted room authenticates internally. The client socket never sends hello.
  bridge.send({"t": "hello", "seat": index, "token": server.tokens[index], "version": server.version()})
  socket.send({"t": "server", "status": "ok"})
 func _exit_tree():
  if bridge != null: bridge.close()
  if socket != null: socket.close()
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]:
  user_backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 run.call_deferred()
func _finalize():
 for path in user_backups:
  if user_backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(user_backups[path])
func verify(ok, text):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func frames(n = 5):
 for i in n: await process_frame
func button(node, text):
 for child in node.get_children():
  if child is Button and child.text == text: return child
  var found = button(child, text)
  if found != null: return found
 return null
func respond(table):
 while is_instance_valid(table) and table.is_inside_tree():
  await process_frame
  if not is_instance_valid(table): return
  if not table.pending or not answer_dialogs: continue
  for overlay in table.get_children():
   if not overlay is PanelContainer or not overlay.is_in_group("touch_modal"): continue
   var box = overlay.get_child(0)
   if box.get_child(0).text.contains("damage incoming"):
    box.get_child(box.get_child_count() - 1).pressed.emit()
   elif box.get_child_count() >= 5:
    var grid = box.get_child(3).get_child(0)
    var done = box.get_child(4)
    if grid.get_child_count() > 0: grid.get_child(0).pressed.emit()
    if done.visible: done.pressed.emit()
func run():
 if FileAccess.file_exists("user://savegame.json"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
 root.get_node("Sfx").visual_effects = false
 root.get_node("Sfx").auto_end_turn = false
 verify(OnlineAPI.invite_code("https://phreaknic-ccg.net/join/ABCD") == "ABCD", "path invite")
 verify(OnlineAPI.invite_code("https://phreaknic-ccg.net/?join=abcd") == "ABCD", "query invite")
 verify(OnlineAPI.invite_code("https://phreaknic-ccg.net/?join=0000") == "", "invalid invite")
 var api = FakeAPI.new()
 root.add_child(api)
 var room = FakeRoom.new()
 root.add_child(room)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.transport_factory = room.connect_seat
 root.add_child(online)
 current_scene = online
 await frames()
 for viewport in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.content_scale_size = viewport
  root.size = viewport
  await frames()
  verify(online.content.get_combined_minimum_size().x <= viewport.x - 60, "online browser fits " + str(viewport))
 await online.create_game()
 await frames()
 verify(button(online, "Start") != null, "create enters host lobby")
 verify(api.calls[-1].body.seats.size() == 2, "create includes seat configuration")
 button(online, "Start").pressed.emit()
 await frames(12)
 var table = current_scene
 verify(table != online and table.online_session != null, "start enters existing online table")
 respond(table)
 verify(not room.sent.any(func(m): return m.t == "hello"), "room socket never sends hello")
 var session = table.online_session
 var seat = session.client.seat
 # Drive several authoritative human turns using the real table controls.
 for turn in 4:
  if room.server.engine.active().seat != seat:
   await room.server.engine.end_turn(room.server.engine.active())
   room.server.dirty = true
   await frames()
  table.play_all()
  await frames(10)
  table.end_human_turn(true)
  await frames(10)
 verify(room.server.engine.state.turn >= 4, "online table plays turns")
 # Exercise server requests through the actual table dialogs and wire validators.
 var p = room.server.engine.state.players[seat]
 var value = await room.server.ask(seat, {"kind": "choose_cards", "text": "Select a card", "cards": p.hand.map(RemoteDecider.card_data), "min": 1, "max": 1}, [])
 verify(value.size() == 1 and value[0] == p.hand[0].uid, "choose_cards dialog returns UID")
 value = await room.server.ask(seat, {"kind": "choose_option", "text": "Order triggers", "options": ["First", "Second"]}, [])
 verify(value == 0, "choose_option dialog returns index")
 value = await room.server.ask(seat, {"kind": "allocate_prevention", "text": "Allocate", "amount": 2, "sources": [{"card": null, "capacity": 3, "full": false, "name": "Shield"}]}, [])
 verify(value == [2], "prevention dialog returns allocation")
 answer_dialogs = false
 room.server.ask(seat, {"kind": "choose_option", "text": "Timeout", "options": ["First", "Second"]}, [])
 await frames()
 verify(table.pending, "timeout prompt opened")
 var timeout_id = room.server.pending.keys()[0]
 room.server._complete(timeout_id, 0)
 await frames()
 verify(not table.pending and not session.client.prompts.has(timeout_id), "prompt_done closes timed out dialog")
 answer_dialogs = true
 table.menu()
 verify(button(table.game_menu, "Save game") == null and button(table.game_menu, "Leave game") != null, "online menu offers Leave without Save")
 table.close_menu()
 verify(not table.save_game(), "online saving disabled")
 verify(not FileAccess.file_exists("user://savegame.json"), "online does not write savegame")
 session.transport.close()
 await frames()
 verify(session.status == "Reconnecting…" and table.notice_text == "Reconnecting…", "reconnect banner")
 session.retry = 0.001
 await frames(12)
 verify(session.status == "Connected" and session.client.engine.state != null, "token rejoin restores view")
 table.leave_game(false)
 await frames()
 verify(not OnlineAPI.remembered().is_empty(), "Leave game preserves resumable seat")
 var menu = current_scene
 verify(button(menu, "Resume online game") != null, "menu offers resume")
 # Resume at seat 1 to prove the bottom hand belongs to the authenticated seat.
 room.index = 1
 var resumed = OnlineSession.new()
 resumed.transport_factory = room.connect_seat
 root.add_child(resumed)
 var data = OnlineAPI.remembered()
 data.seat = 1
 resumed.start(data)
 await frames(10)
 var second = load("res://scenes/table.tscn").instantiate()
 second.online_session = resumed
 resumed.reparent(second)
 root.add_child(second)
 current_scene = second
 menu.queue_free()
 await frames()
 verify(second.human_seat == 1, "seat 1 bottom player")
 var hand = second.body.find_child("Hand", true, false)
 verify(hand.get_children().map(func(c): return c.get_meta("card_uid")) == second.engine.state.players[1].hand.map(func(c): return c.uid), "bottom hand is seat 1")
 verify(second.engine.state.players[0].hand.all(func(c): return c.id == "hidden"), "opponent hand redacted")
 verify(second.texture_for("hidden") == second.texture_for("phreaknic_fottr_tcg_card_back"), "hidden cards use card back")
 room.socket.send({"t": "over", "winner": 1})
 await frames()
 verify(second.online_over and OnlineAPI.remembered().is_empty(), "game over clears resume")
 second.queue_free()
 await frames()
 # Separate join and version mismatch flow with the same injectable REST API.
 var join_ui = load("res://scripts/ui/online.gd").new()
 join_ui.api = api
 join_ui.session = OnlineSession.new()
 join_ui.add_child(join_ui.session)
 room.started = false
 join_ui.session.transport_factory = room.connect_seat
 root.add_child(join_ui)
 current_scene = join_ui
 await join_ui.join("ABCD")
 await frames()
 verify(api.calls[-1].path == "/rooms/ABCD/join" and join_ui.in_lobby, "join flow")
 join_ui.queue_free()
 await frames()
 var mismatch_ui = load("res://scripts/ui/online.gd").new()
 mismatch_ui.api = api
 root.add_child(mismatch_ui)
 api.mismatch = true
 await mismatch_ui.join("ABCD")
 verify(mismatch_ui.message.text == "This game runs version 9.99. Please update", "version mismatch plain message")
 verify(button(mismatch_ui, "Get the latest release") != null, "version release link")
 mismatch_ui.queue_free()
 room.queue_free()
 api.queue_free()
 await frames()
 print("Online UI checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
