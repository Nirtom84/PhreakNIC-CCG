extends SceneTree
var checks = 0
var failures = 0
var backups = {}
class FakeAPI extends Node:
 var bodies = []
 func request(method, _path, body = {}):
  if method == HTTPClient.METHOD_GET: return {"status": 200, "data": {"rooms": []}}
  bodies.append(body.duplicate(true))
  return {"status": 201, "data": {"code": "ABCD", "seat": 0, "token": "fake"}}
class Room extends Node:
 var endpoint
 var messages = []
 var server: GameServer
 var config = {"t": "room", "code": "ABCD", "host_seat": 0, "started": false, "public": true, "card_pool": "2026", "starting_life": 0, "banned": [], "seats": [{"name": "Host", "hero": "", "bot": false, "difficulty": 0}, {"name": "Guest", "hero": "", "bot": false, "difficulty": 0}]}
 func connect_socket():
  var pair = LoopbackTransport.pair()
  endpoint = pair[1]
  endpoint.received.connect(receive)
  endpoint.send.call_deferred(config)
  return pair[0]
 func receive(data):
  messages.append(data)
  if data.get("action") == "settings":
   for key in ["banned", "card_pool"]:
    if data.has(key): config[key] = data[key]
   endpoint.send(config)
  if data.get("action") == "start":
   server = GameServer.new()
   add_child(server)
   server.setup(config.seats, config.card_pool, 0, 42, config.banned)
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]: backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 run.call_deferred()
func _finalize():
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
func verify(ok, text):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func frames(n = 4):
 for i in n: await process_frame
func button(node, text):
 if node is Button and node.text == text: return node
 for child in node.get_children():
  var result = button(child, text)
  if result != null: return result
 return null
func run():
 var db = root.get_node("CardDB")
 var sfx = root.get_node("Sfx")
 sfx.visual_effects = false
 var ids = db.center_ids("2026")
 verify(ids.size() == 150 and db.center_ids("2025").size() == 102, "Center pools exclude starters")
 var bans = db.filter_banned(["Botnet", "Hacking", "unknown"], "2026")
 verify(bans.size() == 5, "All five Botnet copies banned; starters and unknown ignored")
 var engine = GameEngine.new()
 root.add_child(engine)
 verify(engine.setup([-1, -1], 42, [], "2026", 0, bans), "Offline bans accepted")
 verify(not engine.state.all_cards().any(func(c): return c.id in bans) and engine.state.initial_count == 165, "Bans remove copies from setup")
 verify(engine.state.players[0].deck.size() + engine.state.players[0].hand.size() == 10, "Starters unaffected")
 var rejected = GameEngine.new()
 root.add_child(rejected)
 verify(not rejected.setup([0, 0], 42, [], "2026", 0, ids), "Offline rejects below minimum")
 engine.state.turn = 1
 var saved = SaveGame.snapshot(engine.state)
 var restored = SaveGame.restore(saved)
 verify(restored != null and restored.banned == bans and restored.conservation_ok(), "Save restores bans and conservation")
 var old = GameEngine.new()
 root.add_child(old)
 old.setup([-1, -1])
 old.state.turn = 1
 var legacy = SaveGame.snapshot(old.state)
 legacy.state.erase("banned")
 verify(SaveGame.restore(legacy) != null and SaveGame.restore(legacy).banned.is_empty(), "Old saves default to no bans")
 sfx.set_banned("2025", bans)
 var expansion = ids.filter(func(id): return not db.in_pool(id, "2025"))[0]
 sfx.set_banned("2026", [expansion])
 sfx.save()
 verify(sfx.banned_cards("2025") == db.filter_banned(bans, "2025") and sfx.banned_cards("2026") == [expansion], "Independent settings per pool")
 var settings = OnlineAPI.settings()
 verify(settings.get_value("game", "banned_2025") == db.filter_banned(bans, "2025") and settings.get_value("game", "banned_2026") == [expansion], "Both lists persisted")
 var settings_copy = load("res://scripts/ui/sfx.gd").new()
 root.add_child(settings_copy)
 verify(settings_copy.banned_cards("2025") == db.filter_banned(bans, "2025") and settings_copy.banned_cards("2026") == [expansion], "Settings restored per pool")
 settings_copy.queue_free()
 var exact_bans = []
 for id in db.center_choices("2026"):
  var copies = db.center_copies(id)
  if ids.size() - exact_bans.size() - copies.size() >= 40: exact_bans.append_array(copies)
 verify(ids.size() - exact_bans.size() == 40 and rejected.setup([-1, -1], 42, [], "2026", 0, exact_bans) and rejected.state.center_deck.size() == 35, "Exactly 40 cards accepted, 35 after initial row")
 var picker = load("res://scripts/ui/ban_picker.gd").new()
 root.add_child(picker)
 var overlay = picker.open_bans("2026", [])
 await frames()
 picker.toggle_card("Botnet")
 verify(picker.banned.size() == 5 and "BANNED" in picker.cards.Botnet.text and "Copies 5" in picker.cards.Botnet.text, "Picker toggles all copies with label")
 picker.search.text = "botnet"
 picker.search.text_changed.emit("botnet")
 verify(picker.cards.Botnet.visible and not picker.cards[expansion].visible, "Picker filters by printed name")
 for viewport in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.content_scale_size = viewport
  root.size = viewport
  await frames()
  verify(Rect2(Vector2.ZERO, Vector2(viewport)).encloses(overlay.get_child(0).get_global_rect()), "Picker content fits " + str(viewport))
 picker.search.text_changed.emit("")
 for id in picker.cards: picker.toggle_card(id)
 verify(db.bans_valid(picker.banned) and ids.size() - picker.banned.size() >= 40, "Picker blocks unsafe last toggle")
 button(overlay, "Clear all").pressed.emit()
 verify(picker.banned.is_empty(), "Clear all")
 picker.open_bans("2026", bans, Callable(), true)
 await frames()
 picker.toggle_card("Botnet")
 verify(picker.banned == bans and picker.cards.size() == 1, "Read-only list cannot toggle")
 picker.queue_free()
 var api = FakeAPI.new()
 root.add_child(api)
 var room = Room.new()
 root.add_child(room)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.transport_factory = room.connect_socket
 root.add_child(online)
 current_scene = online
 await frames()
 online.create_banned = bans
 await online.create_game()
 await frames()
 verify(api.bodies[0].banned == bans, "Create API includes bans")
 online.session.lobby("settings", {"banned": bans})
 await frames()
 verify(online.session.room.banned == bans and button(online, "Banned cards: 5") != null, "Lobby broadcasts and shows bans")
 verify(button(online, "Close room") != null, "Host Leave is labeled Close room")
 online.leave_lobby()
 await frames(1)
 verify(is_instance_valid(online.kick_overlay), "Host close waits for confirmation")
 online.kick_confirmed.emit(false)
 await frames()
 verify(online.in_lobby, "Cancel keeps room open")
 online.session.credential.seat = 1
 online.lobby(online.session.room)
 button(online, "View banned cards").pressed.emit()
 await frames()
 verify(online.ban_picker.readonly and online.ban_picker.banned == bans, "Guest views read-only banned list")
 while online.ban_picker.close_top(): pass
 online.session.credential.seat = 0
 online.lobby(online.session.room)
 online.session.lobby("start")
 await frames()
 verify(room.server.engine.state.banned == bans, "Loopback lobby setup applies bans")
 room.server.engine.state.turn = 1
 room.server._checkpoint()
 var server_copy = GameServer.new()
 root.add_child(server_copy)
 verify(server_copy.restore(room.server.last_snapshot) and server_copy.engine.state.banned == bans, "Server snapshot retains bans")
 server_copy.running = false
 var bad = GameServer.new()
 root.add_child(bad)
 verify(not bad.setup(room.config.seats, "2026", 0, 42, ids) and bad.engine == null and "40" in bad.setup_error, "Server refuses unsafe setup")
 verify(bad.setup(room.config.seats, "2026", 0, 42, bans + ["unknown", "Hacking"]) and bad.engine.state.banned == bans, "Server ignores unknown IDs and starters")
 var view = NetView.build(room.server.engine, 0)
 verify(NetView.apply(view).banned == bans, "Public view retains banned list")
 var current_session = online.session
 room.endpoint.send({"t": "room_closed", "reason": "host_left"})
 await frames()
 verify(not online.in_lobby and online.message.text == "The host closed the room." and OnlineAPI.remembered().is_empty(), "Room closed returns to online home and forgets seat")
 verify(not is_instance_valid(current_session), "Room closure removes session without reconnect")
 # Close-code fallback covers a lost room_closed message.
 var session = OnlineSession.new()
 root.add_child(session)
 var socket = WebSocketTransport.new()
 socket.close_code = 4002
 session.transport = socket
 session.credential = {"seat": 1}
 session._closed(socket)
 verify(session.stopped and session.retry == 0 and session.credential.is_empty() and session.status == "The host closed the room.", "4002 stops reconnect and clears seat")
 session.queue_free()
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.transport_factory = room.connect_socket
 online.enter({"code": "ABCD", "seat": 0, "token": "fake", "server": "http://localhost"})
 await frames()
 online.leave_lobby()
 await frames(1)
 online.kick_confirmed.emit(true)
 await frames()
 verify(not is_instance_valid(online) and OnlineAPI.remembered().is_empty() and room.messages.any(func(m): return m.get("action") == "leave"), "Confirmed host closure sends leave and exits")
 if is_instance_valid(online): online.queue_free()
 if is_instance_valid(current_scene): current_scene.queue_free()
 room.queue_free()
 api.queue_free()
 for node in [engine, rejected, old, server_copy, bad]: node.queue_free()
 await frames()
 print("v12 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
