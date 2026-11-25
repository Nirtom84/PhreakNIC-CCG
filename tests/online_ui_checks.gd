extends SceneTree
var checks = 0
var failures = 0
var user_backups = {}
var answer_dialogs = true
class FakeAPI extends Node:
 var calls = []
 var mismatch = false
 var rooms = []
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body})
  if mismatch: return {"status": 409, "data": {"error": "version", "need": "9.99"}}
  if method == HTTPClient.METHOD_GET: return {"status": 200, "data": {"rooms": rooms}}
  return {"status": 201, "data": {"code": "ABCD", "seat": 0, "token": "a".repeat(32)}}
class FakeRoom extends Node:
 var server: GameServer
 var socket
 var bridge
 var index = 0
 var started = false
 var sent = []
 var pool = "2026"
 var deck: Dictionary = {}
 func _ready():
  server = GameServer.new()
  add_child(server)
  server.setup([{"name": "Host", "bot": false}, {"name": "Guest", "bot": false}, {"name": "Bot", "bot": true}], pool, 20, 42, [], 0.0, deck)
  # Keep UI turn-driving scenarios reproducible, as in net_checks.
  server.engine.secure_random = false
  server.engine.setup([-1, -1, 1], 42, server.engine.deciders, pool, 20, [], deck)
 func connect_seat():
  # A new connection replaces the previous one: its game-server link must not forward (late, throttled) views here.
  if bridge != null:
   bridge.close()
   bridge = null
  var pair = LoopbackTransport.pair()
  socket = pair[1]
  socket.received.connect(receive)
  send_room.call_deferred()
  if started: authenticate.call_deferred()
  return pair[0]
 func send_room():
  socket.send({"t": "room", "code": "ABCD", "seats": [{"name": "Host", "hero": "", "bot": false, "difficulty": 0, "connected": true}, {"name": "Guest", "hero": "", "bot": false, "difficulty": 1, "connected": true}], "host_seat": 0, "started": started, "public": true, "card_pool": pool, "starting_life": 20})
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
 func drain():
  # Bot traces can leave an offline guest's decision pending at teardown.
  server.running = false
  server.engine.finish(null)
  for i in 200:
   for id in server.pending.keys(): await server._fallback(id)
   if server.pending.is_empty() and server.driving.is_empty() and server.locks.is_empty(): return
   await get_tree().process_frame
 func _exit_tree():
  if bridge != null: bridge.close()
  if socket != null: socket.close()
class SeatSocket extends Node:
 # The Worker's room socket on localhost. Each connection takes the next step of `plan` (the last one repeats):
 # "refuse" answers HTTP 401 like an unknown or revoked token (Godot logs each refused handshake as an error),
 # "limit" answers every request (sockets and the seat check) with 429 like the per-IP rate limit,
 # "remove" accepts and closes 1000 "removed" like the host's Remove seat, "drop" accepts and then loses the
 # connection, "keep" accepts and stays open.
 var tcp = TCPServer.new()
 var plan: Array = []
 var attempts = 0
 var refused: Array = []
 var peers: Array = []
 var bad_auth = false
 func _process(_delta):
  while tcp.is_connection_available():
   var stream = tcp.take_connection()
   var step = plan[mini(attempts, plan.size() - 1)]
   attempts += 1
   if step in ["refuse", "limit"]: refused.append({"stream": stream, "request": "", "step": step})
   else:
    var peer = WebSocketPeer.new()
    peer.supported_protocols = PackedStringArray(["phreaknic"])
    if peer.accept_stream(stream) == OK: peers.append({"peer": peer, "step": step, "opened": -1})
  for item in refused.duplicate():
   item.stream.poll()
   if item.stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
    refused.erase(item)
    continue
   if item.stream.get_available_bytes() > 0: item.request += item.stream.get_utf8_string(item.stream.get_available_bytes())
   if item.request.contains("\r\n\r\n"):
    if "upgrade: websocket" in item.request.to_lower():
     var protocol = ""
     for header in item.request.split("\r\n"):
      if header.to_lower().begins_with("sec-websocket-protocol:"): protocol = header.split(":", true, 1)[1].replace(" ", "").to_lower()
     if "?token=" in item.request or protocol != "phreaknic,t.0123456789abcdef0123456789abcdef": bad_auth = true
    else:
     if "authorization: bearer 0123456789abcdef0123456789abcdef" not in item.request.to_lower() or "sec-websocket-protocol:" in item.request.to_lower(): bad_auth = true
    var body = "{\"error\":\"token\"}" if item.step == "refuse" else "{\"error\":\"rate_limit\"}"
    var status = "401 Unauthorized" if item.step == "refuse" else "429 Too Many Requests"
    item.stream.put_data(("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.length(), body]).to_utf8_buffer())
    item.stream.disconnect_from_host()
    refused.erase(item)
  for item in peers:
   item.peer.poll()
   if item.peer.get_ready_state() != WebSocketPeer.STATE_OPEN: continue
   if item.opened < 0:
    item.opened = Engine.get_process_frames()
    item.peer.send_text(JSON.stringify({"t": "room", "code": "ABCD", "seats": [], "host_seat": 0, "started": false}))
    if item.step == "remove": item.peer.close(1000, "removed")
   elif item.step == "drop" and Engine.get_process_frames() - item.opened >= 5:
    item.peer.close(-1)
    item.step = "keep"
 func stop():
  for item in peers: item.peer.close(-1)
  for item in refused: item.stream.disconnect_from_host()
  tcp.stop()
func _initialize():
 for path in ["user://settings.json", "user://settings.cfg.migrated", "user://settings.cfg", "user://savegame.json", "user://stats.json"]:
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
    var grid = box.get_node("DecisionScroll").get_child(0)
    var offered = grid.get_meta("decision_buttons", grid.get_children())
    var done = box.get_node("DecisionDone")
    if offered.size() > 0: offered[0].pressed.emit()
    if done.visible: done.pressed.emit()
func has_label(node, text):
 if node is Label and node.text == text: return true
 for child in node.get_children():
  if has_label(child, text): return true
 return false
func has_portrait(node, hero):
 if node is TextureRect and node.texture is AtlasTexture and node.texture.atlas.resource_path == "res://assets/cards/" + hero + ".jpg": return true
 for child in node.get_children():
  if has_portrait(child, hero): return true
 return false
func fits(online, viewport):
 var rect = Rect2(Vector2.ZERO, Vector2(viewport))
 verify(rect.encloses(online.content.get_global_rect()), "Full online page fits " + str(viewport))
 for child in online.content.get_children():
  verify(rect.encloses(child.get_global_rect()), "Page section fits " + str(viewport))
# The table opens on the game's card set (here sets whose cards the default set lacks) and follows new views.
func card_set_table(api, pool: String):
 var room = FakeRoom.new()
 room.pool = pool
 if pool == "custom": room.deck = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))[0]
 root.add_child(room)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.transport_factory = room.connect_seat
 root.add_child(online)
 current_scene = online
 await frames()
 online.enter({"server": "http://127.0.0.1:9", "code": "ABCD", "seat": 0, "token": "a".repeat(32)})
 await frames()
 room.receive({"t": "lobby", "action": "start"})
 await frames(12)
 var table = current_scene
 verify(table != online and table.online_session != null, "%s: start enters the online table" % pool)
 if table == online or table.online_session == null:
  online.queue_free()
 else:
  var db = root.get_node("CardDB")
  verify(db.selected_pool == pool and table.card_names.size() == db.pool_ids(pool).size(), "%s: the online table knows every card of its set" % pool)
  var redrawn = [false]
  table.auto_view_received.connect(func(): redrawn[0] = true)
  room.server.dirty = true
  for i in 60:
   if redrawn[0]: break
   await process_frame
  verify(redrawn[0], "%s: the online table follows new views" % pool)
  table.queue_free()
 await frames()
 await room.drain()
 room.queue_free()
 await frames()
 OnlineAPI.remember({})
# The server couldn't resume an unfinished game (LinkServer's restore_failed, see link_checks) and the room forwards
# that to the open table: close the game with the reason instead of showing a Stalemate and counting a lifetime draw.
func failed_restore_table(api):
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
 online.enter({"server": "http://127.0.0.1:9", "code": "ABCD", "seat": 0, "token": "a".repeat(32)})
 await frames()
 room.receive({"t": "lobby", "action": "start"})
 await frames(12)
 var table = current_scene
 verify(table != online and table.online_session != null and not table.match_stats.finished, "Failed restore: an unfinished online game is open")
 if table == online or table.online_session == null:
  online.queue_free()
 else:
  table.lifetime_test_enabled = true
  var games = load("res://scripts/ui/lifetime_stats.gd").new().data.games
  room.socket.send({"t": "over", "winner": -1, "reason": "restore_failed"})
  await frames()
  var after = load("res://scripts/ui/lifetime_stats.gd").new().data
  print("Failed restore evidence: online_over=%s, lifetime games %d -> %d, wins=%d, losses=%d" % [is_instance_valid(table) and table.online_over, games, after.games, after.wins, after.losses])
  verify(after.games == games, "Failed restore records no lifetime game (no draw)")
  verify(not is_instance_valid(table) or not table.online_over, "Failed restore shows no game result")
  var home = current_scene
  verify(home != table and home.get("message") != null and home.message.text.begins_with("The server was updated, so this game couldn't be resumed"), "Failed restore returns to online home with the reason")
  verify(OnlineAPI.remembered().is_empty(), "Failed restore forgets the seat")
  if is_instance_valid(table): table.queue_free()
  if is_instance_valid(home) and home != table: home.queue_free()
 await frames()
 await room.drain()
 room.queue_free()
 await frames()
 OnlineAPI.remember({})
func run():
 await seat_socket_checks()
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
 for populated in [false, true]:
  api.rooms = [{"code": "ABCD", "host": "Host", "seats": [{"name": "Host", "bot": false, "difficulty": 0}, {"name": "", "bot": false, "difficulty": 0}, {"name": "Bot", "bot": true, "difficulty": 2}], "card_pool": "2026", "starting_life": 20, "open_seats": 1, "banned_count": 3}] if populated else []
  if populated:
   for i in 7: api.rooms.append(api.rooms[0].duplicate(true))
  online.seat_count.select(2)
  online.seat_count.item_selected.emit(2)
  await online.refresh_rooms()
  if populated: verify(has_label(online.rooms_box, "3 cards banned"), "Open games show ban count")
  for viewport in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
   root.content_scale_size = viewport
   root.size = viewport
   await frames()
   fits(online, viewport)
 online.seat_count.select(0)
 online.seat_count.item_selected.emit(0)
 await online.create_game()
 await frames()
 verify(button(online, "Start") != null, "create enters host lobby")
 verify(button(online, "Remove") != null, "Host sees joined-human Remove button")
 button(online, "Remove").pressed.emit()
 await frames(1)
 verify(not room.sent.any(func(m): return m.get("action") == "kick"), "Kick waits for confirmation")
 online.kick_confirmed.emit(true)
 await frames()
 verify(room.sent.any(func(m): return m.get("action") == "kick" and m.seat == 1), "Confirmed kick sends lobby action for target")
 verify(api.calls[-1].body.seats.size() == 2, "create includes seat configuration")
 button(online, "Copy invite link").pressed.emit()
 verify(online.toast.visible and online.toast.text == "Copied!", "Copy shows toast")
 var lobby_room = online.session.room.duplicate(true)
 lobby_room.seats[1].name = ""
 online.lobby(lobby_room)
 verify(button(online, "Start").disabled, "Start disabled while a human seat is open")
 verify(has_label(online, "Fill every open human seat before starting."), "Disabled Start explains open seats")
 for viewport in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.content_scale_size = viewport
  root.size = viewport
  await frames()
  fits(online, viewport)
 lobby_room = online.session.room.duplicate(true)
 lobby_room.started = true
 online.lobby(lobby_room)
 await frames()
 verify(online.starting_indicator.text.contains("Starting the game server… (this can take ~10 s)"), "Startup progress indicator")
 online.session.credential.seat = 1
 lobby_room.started = false
 online.lobby(lobby_room)
 verify(has_label(online, "Waiting for Host to start…"), "Guest sees host waiting message")
 online.session.credential.seat = 0
 online.lobby(online.session.room)
 button(online, "Start").pressed.emit()
 await frames(12)
 var table = current_scene
 verify(table != online and table.online_session != null, "start enters existing online table")
 respond(table)
 verify(table.seat_names[2] == room.server.seats[2].name and table.seat_names[2] != "Bot", "Online bot Hero name reaches table")
 verify(has_label(table.body, table.seat_names[2]), "Online bot Hero name is rendered")
 verify(has_portrait(table.body, room.server.seats[2].hero), "Online bot Hero portrait is rendered")
 room.server.ask(1, {"kind": "choose_option", "text": "Private choice", "options": ["Secret"]}, [])
 await frames()
 verify(is_instance_valid(table.waiting_banner) and has_label(table.waiting_banner, "Waiting for Guest to choose…"), "Waiting banner appears for other seat")
 room.server._complete(room.server.pending.keys().filter(func(id): return room.server.pending[id].data.text == "Private choice")[0], 0)
 await frames()
 verify(not is_instance_valid(table.waiting_banner), "Waiting banner disappears")
 verify(not room.sent.any(func(m): return m.t == "hello"), "room socket never sends hello")
 var session = table.online_session
 var seat = session.client.seat
 var mirror_before_timers = session.client.engine.state
 session.client._receive({"t": "timers", "timers": [{"seat": 1, "kind": "turn", "remaining_seconds": 37, "limit": 180, "handable": true, "host_seat": seat}]})
 verify(table.handable_seat == 1 and table.countdowns[1].remaining == 37 and session.client.engine.state == mirror_before_timers, "Timer-only update refreshes countdown and host handover")
 session.client._receive({"t": "timers", "timers": [{"seat": 1}]})
 verify(table.handable_seat == 1 and table.countdowns[1].remaining == 37, "Invalid timer-only update ignored")
 session.client._receive({"t": "timers", "timers": []})
 verify(table.handable_seat == -1 and not table.countdowns[1].active, "Empty timers clear countdown and handover")
 # An active player who drops has two deadlines (disconnect takeover and turn idle). Others see the one that ends first.
 session.client._receive({"t": "timers", "timers": [{"seat": 1, "kind": "disconnected", "remaining_seconds": 90, "limit": 120}, {"seat": 1, "kind": "turn", "remaining_seconds": 150, "limit": 180, "handable": false, "host_seat": seat}]})
 verify(table.countdowns[1].kind == "disconnected" and table.countdowns[1].remaining == 90, "Disconnected active seat shows the disconnect countdown when it ends first")
 session.client._receive({"t": "timers", "timers": [{"seat": 1, "kind": "disconnected", "remaining_seconds": 100, "limit": 120}, {"seat": 1, "kind": "turn", "remaining_seconds": 20, "limit": 180, "handable": true, "host_seat": seat}]})
 verify(table.countdowns[1].kind == "turn" and table.countdowns[1].remaining == 20 and table.handable_seat == 1, "Disconnected active seat shows the idle countdown when it ends first, and handover stays available")
 session.client._receive({"t": "timers", "timers": []})
 # Drive several authoritative human turns using the real table controls.
 for turn in 4:
  if room.server.engine.active().seat != seat:
   await room.server.engine.end_turn(room.server.engine.active())
   room.server.dirty = true
   await frames()
  table.play_all()
  # The server throttles views to 5 Hz; wait for its acknowledgement before End Turn.
  await create_timer(0.25).timeout
  table.end_human_turn(true)
  await create_timer(0.25).timeout
 verify(room.server.engine.state.turn >= 4, "online table plays turns")
 # Exercise server requests through the actual table dialogs and wire validators.
 var p = room.server.engine.state.players[seat]
 # The preceding play-all can leave an empty hand; this dialog requires an offered card.
 if p.hand.is_empty(): p.hand.append(p.deck.pop_back())
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
 var timeout_id = room.server.pending.keys().filter(func(id): return room.server.pending[id].data.text == "Timeout")[0]
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
 room.socket.send({"t": "room_closed", "reason": "host_left"})
 await frames()
 verify(not join_ui.in_lobby and join_ui.message.text == "The host closed the room.", "Host closure returns to online home")
 verify(join_ui.session == null and OnlineAPI.remembered().is_empty(), "Host closure forgets seat and stops reconnect")
 join_ui.queue_free()
 await frames()
 # Resuming a seat whose game ended while it was away: `over` arrives before any view, so no table opens.
 var ended_room = LoopbackTransport.pair()
 var ended_ui = load("res://scripts/ui/online.gd").new()
 ended_ui.api = api
 ended_ui.session = OnlineSession.new()
 ended_ui.add_child(ended_ui.session)
 ended_ui.session.transport_factory = func(): return ended_room[0]
 root.add_child(ended_ui)
 current_scene = ended_ui
 await frames()
 ended_ui.enter({"server": "http://127.0.0.1:9", "code": "ABCD", "seat": 1, "token": "a".repeat(32)})
 ended_room[1].send({"t": "room", "code": "ABCD", "seats": [{"name": "Host", "hero": "", "bot": false, "difficulty": 0, "connected": true}, {"name": "Guest", "hero": "", "bot": false, "difficulty": 1, "connected": true}], "host_seat": 0, "started": true, "public": true, "card_pool": "2026", "starting_life": 20})
 ended_room[1].send({"t": "over", "winner": 0})
 await frames()
 verify(not ended_ui.in_lobby and ended_ui.message.text == "This game has already ended.", "Resuming a finished game returns to online home and says so")
 verify(ended_ui.session == null and OnlineAPI.remembered().is_empty() and not ended_room[1].open, "Resuming a finished game forgets the seat and closes the socket")
 ended_ui.queue_free()
 await frames()
 # A game that can't start (too many bans) ends with a reason before any view: return home with that reason.
 var banned_room = LoopbackTransport.pair()
 var banned_ui = load("res://scripts/ui/online.gd").new()
 banned_ui.api = api
 banned_ui.session = OnlineSession.new()
 banned_ui.add_child(banned_ui.session)
 banned_ui.session.transport_factory = func(): return banned_room[0]
 root.add_child(banned_ui)
 current_scene = banned_ui
 await frames()
 banned_ui.enter({"server": "http://127.0.0.1:9", "code": "ABCD", "seat": 1, "token": "a".repeat(32)})
 banned_room[1].send({"t": "over", "winner": -1, "reason": "banned_minimum"})
 await frames()
 verify(not banned_ui.in_lobby and banned_ui.message.text.begins_with("At least 40 center-deck cards"), "A game that can't start returns to online home with the reason")
 banned_ui.queue_free()
 await frames()
 await seat_renumber_checks(api)
 var mismatch_ui = load("res://scripts/ui/online.gd").new()
 mismatch_ui.api = api
 root.add_child(mismatch_ui)
 api.mismatch = true
 await mismatch_ui.join("ABCD")
 verify(mismatch_ui.message.text == "This game runs version 9.99. Please update", "Join version mismatch message")
 await mismatch_ui.create_game()
 verify(mismatch_ui.message.text == "This game runs version 9.99. Please update", "version mismatch plain message")
 verify(button(mismatch_ui, "Get the latest release") != null, "version release link")
 mismatch_ui.queue_free()
 await room.drain()
 verify(room.server.pending.is_empty() and room.server.driving.is_empty() and room.server.locks.is_empty(), "Fake room drains in-flight decisions before deletion")
 room.queue_free()
 await frames()
 api.mismatch = false
 for pool in ["2026mog", "custom"]: await card_set_table(api, pool)
 await failed_restore_table(api)
 api.queue_free()
 await frames()
 print("Online UI checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func seat_session(port: int, removed: Array = []) -> OnlineSession:
 var session = OnlineSession.new()
 root.add_child(session)
 session.removed.connect(func(text): removed.append(text))
 session.start({"server": "http://127.0.0.1:%d" % port, "code": "ABCD", "seat": 1, "token": "0123456789abcdef0123456789abcdef"})
 return session
func run_clock(session: OnlineSession, done: Callable):
 # Reconnect backoff passes at once on the session's own clock.
 for i in 3000:
  if done.call(): return
  await process_frame
  if session.retry > 0: session._process(16.0)
func seat_socket_checks():
 var server = SeatSocket.new()
 server.tree_exiting.connect(func(): verify(not server.bad_auth, "Seat authentication uses subprotocol header without URL token"))
 root.add_child(server)
 if server.tcp.listen(0, "127.0.0.1") != OK:
  print("Seat socket checks: SKIPPED (cannot bind localhost)")
  server.queue_free()
  return
 var port = server.tcp.get_local_port()
 # Remove seat closes 1000 "removed" and revokes the token: stop at once.
 server.plan = ["remove", "refuse"]
 var removed = []
 var session = seat_session(port, removed)
 await run_clock(session, func(): return session.stopped or server.attempts > 30)
 verify(session.stopped and removed == ["The host removed you from the room."] and OnlineAPI.remembered().is_empty(), "The host's Remove seat returns home and forgets the seat")
 verify(server.attempts == 1, "Remove seat doesn't reconnect (%d connections)" % server.attempts)
 session.queue_free()
 await frames(3)
 # A refused upgrade looks like a network error: 8 refused sockets, then one seat check that says the seat is gone.
 server.attempts = 0
 server.plan = ["refuse"]
 removed = []
 session = seat_session(port, removed)
 await run_clock(session, func(): return session.stopped or server.attempts > 30)
 verify(session.stopped and removed == ["This room has closed or your seat was removed."] and OnlineAPI.remembered().is_empty(), "A seat the server keeps refusing returns home and is forgotten")
 verify(server.attempts == 9, "A refused seat stops after 8 sockets and one HTTP check (%d connections)" % server.attempts)
 session.queue_free()
 await frames(3)
 # A rate limit (or a proxy) refuses the sockets while the server is up: the seat check doesn't say "gone", so keep it.
 server.attempts = 0
 server.plan = ["limit"]
 var limited = seat_session(port)
 await run_clock(limited, func(): return server.attempts > 12 or limited.stopped)
 verify(server.attempts > 12 and not limited.stopped and not OnlineAPI.remembered().is_empty(), "A rate-limited seat is kept and keeps retrying (%d connections)" % server.attempts)
 limited.disconnect_game()
 limited.queue_free()
 await frames(3)
 server.attempts = 0
 server.plan = ["drop", "keep"]
 var dropped = seat_session(port)
 await run_clock(dropped, func(): return server.attempts >= 2 and dropped.status == "Connected" and dropped.transport.active)
 verify(server.attempts == 2 and dropped.status == "Connected" and not dropped.stopped and not OnlineAPI.remembered().is_empty(), "A dropped connection reconnects")
 dropped.disconnect_game()
 dropped.queue_free()
 server.stop()
 server.queue_free()
 await frames(3)
 # Nothing listens on the port any more: an unreachable server is a network problem, so keep the seat and retry.
 var offline = seat_session(port)
 await run_clock(offline, func(): return offline.attempts > 10)
 verify(offline.attempts > 10 and not offline.stopped and offline.status == "Reconnecting…" and not OnlineAPI.remembered().is_empty(), "An unreachable server keeps the seat and keeps retrying")
 offline.disconnect_game()
 offline.queue_free()
 await frames(3)
 OnlineAPI.remember({})
func you_row_has(node, name) -> bool:
 if node is Label and node.text == "[you]": return has_label(node.get_parent(), name)
 for child in node.get_children():
  if you_row_has(child, name): return true
 return false
# The host's Remove seat on a lower seat shifts the seats after it down. Room updates say which seat the socket
# now holds; the credential (live and remembered) and the custom-deck lobby must follow it.
func seat_renumber_checks(api):
 var seat = func(name, bot = false, deck = null): return {"name": name, "hero": "", "bot": bot, "difficulty": 1, "connected": true, "deck": deck}
 var bot_title = "Bot · " + BotDifficulty.DISPLAY_NAMES[1]
 # Guest's old seat 2 becomes Friend's seat; Friend's old seat 3 is past the end of the shorter list.
 for me in [{"name": "Guest", "before": 2, "after": 1, "deck": false}, {"name": "Friend", "before": 3, "after": 2, "deck": true}]:
  var pair = LoopbackTransport.pair()
  var ui = load("res://scripts/ui/online.gd").new()
  ui.api = api
  ui.session = OnlineSession.new()
  ui.add_child(ui.session)
  ui.session.transport_factory = func(): return pair[0]
  root.add_child(ui)
  current_scene = ui
  await frames()
  ui.enter({"server": "http://127.0.0.1:9", "code": "ABCD", "seat": me.before, "token": "b".repeat(32)})
  var state = {"t": "room", "code": "ABCD", "host_seat": 0, "started": false, "public": false, "card_pool": "custom", "starting_life": 20, "bot_pace": 0.5, "seat": me.before, "seats": [seat.call("Host"), seat.call("Bot", true), seat.call("Guest"), seat.call("Friend", false, {"name": "Mine", "count": 40})]}
  pair[1].send(state)
  await frames()
  verify(you_row_has(ui, me.name) and button(ui, "Submit deck") != null and has_label(ui, bot_title), "Lobby marks %s as [you] with deck controls before a seat is removed" % me.name)
  state = state.duplicate(true)
  state.seats.remove_at(1)
  state.seat = me.after
  pair[1].send(state)
  await frames()
  verify(ui.session.credential.seat == me.after and OnlineAPI.remembered().get("seat", -1) == me.after, "%s's live and remembered seat follow the renumbering (%s)" % [me.name, ui.session.credential.seat])
  verify(not has_label(ui, bot_title) and you_row_has(ui, me.name), "Lobby rebuilds and still marks %s as [you] after a lower seat is removed" % me.name)
  var withdraw = button(ui, "Withdraw")
  verify(button(ui, "Submit deck") != null and withdraw != null and withdraw.disabled != me.deck, "%s's deck controls show their own deck after a lower seat is removed" % me.name)
  ui.queue_free()
  await frames()
 OnlineAPI.remember({})
