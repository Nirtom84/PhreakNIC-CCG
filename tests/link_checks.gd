extends SceneTree
var checks = 0
var failures = 0
var server
var wire: WebSocketTransport
var clients: Array = []
var routes: Array = []
var messages: Array = []
var saved: Dictionary = {}
var snapshots = 0
var over = false
var version = str(ProjectSettings.get_setting("application/config/version", ""))
class Route extends NetTransport:
 var wire
 var seat: int
 func send(message: Dictionary):
  if message.t == "hello": wire.send({"t": "connect", "seat": seat, "version": message.version})
  else: wire.send({"t": "from", "seat": seat, "msg": message})
 func close():
  wire.send({"t": "disconnect", "seat": seat})
  closed.emit()
func _initialize(): run.call_deferred()
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func _process(_delta):
 if wire != null: wire.poll()
 return false
func frames(count: int):
 for i in count: await process_frame
func until(predicate: Callable, limit: int = 1200) -> bool:
 for i in limit:
  if predicate.call(): return true
  await process_frame
 return predicate.call()
func health(port: int) -> bool:
 var tcp = StreamPeerTCP.new()
 tcp.connect_to_host("127.0.0.1", port)
 for i in 600:
  tcp.poll()
  if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTING: break
  await process_frame
 if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED: return false
 tcp.put_data("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n".to_utf8_buffer())
 var response = ""
 for i in 600:
  tcp.poll()
  if tcp.get_available_bytes(): response += tcp.get_utf8_string(tcp.get_available_bytes())
  if response.ends_with("\r\n\r\nok"): break
  await process_frame
 tcp.disconnect_from_host()
 return response.begins_with("HTTP/1.1 200 OK\r\n") and response.ends_with("\r\n\r\nok")
func open_wire():
 messages.clear()
 wire = WebSocketTransport.new()
 wire.received.connect(receive)
 verify(wire.connect_to("ws://127.0.0.1:%d/link" % server.port) == OK, "WebSocket starts connecting")
 verify(await until(func(): return messages.any(func(m): return m.t == "ready")), "Link ready")
 verify(messages.any(func(m): return m.t == "ready" and m.version == version), "Ready reports server version")
func receive(message: Dictionary):
 messages.append(message)
 match message.t:
  "snapshot":
   saved = message.data
   snapshots += 1
  "over": over = true
  "to":
   verify(message.seat in [0, 1], "Output only addressed to human seats")
   inspect_private(message.seat, message.msg)
   if message.seat < routes.size(): routes[message.seat].received.emit(message.msg)
func inspect_private(seat: int, message: Dictionary):
 verify(not '"tokens"' in JSON.stringify(message), "Seat messages omit credentials")
 if message.t == "view":
  var text = JSON.stringify(message.state)
  verify(not '"rng' in text and not '"seed' in text and not '"initial_ids"' in text, "View omits authoritative metadata")
  verify(message.state.seat == seat, "View matches addressed seat")
  var state = NetView.apply(message.state)
  var hidden = state.center_deck.duplicate()
  var visible = []
  for c in state.center_row + state.removed + state.resolving:
   if c != null: visible.append(c.uid)
  for p in state.players:
   hidden.append_array(p.deck)
   if p.seat != seat: hidden.append_array(p.hand)
   for c in p.discard + p.play_area + p.reserve + p.played + (p.hand if p.seat == seat else []):
    visible.append(c.uid)
    for a in c.attached: visible.append(a.uid)
  verify(hidden.all(func(c): return c.id == "hidden" and c.uid < 0 and c.flags.is_empty() and c.attached.is_empty()), "Other hands and all decks stay private")
  verify(message.state.objects.all(func(r): return r.type != "card" or r.data.id == "hidden" or r.data.uid in visible), "No private orphan definitions")
 elif message.t == "event" and message.kind == "draw": verify(message.seat == seat, "Private draw goes only to its seat")
 elif message.t == "log": verify(" draws " not in message.text, "Logs omit private draws")
func connect_clients(scripted: bool = true):
 for seat in 2:
  var route = Route.new()
  route.wire = wire
  route.seat = seat
  routes.append(route)
  var client = NetClient.new()
  client.scripted = scripted
  root.add_child(client)
  clients.append(client)
  client.connect_to(route, seat, "room authenticates")
func clear_clients():
 for client in clients: client.queue_free()
 clients.clear()
 routes.clear()
 await frames(2)
func finish():
 verify(await until(func(): return over, 40000), "Game finishes through the room link")
 await frames(20)
 verify(clients.all(func(c): return c.engine.state != null and c.engine.state.finished), "Every client receives final view")
 verify(server.game.engine.state.conservation_ok(), "Authoritative cards conserved")
 verify(messages.any(func(m): return m.t == "over" and m.winner == (server.game.engine.state.winner.seat if server.game.engine.state.winner != null else -1)), "Over reports winner")
func setup():
 over = false
 wire.send({"t": "setup", "room": "TEST", "seats": [{"name": "A", "hero": "nirtom", "bot": false, "difficulty": 0, "token": "a"}, {"name": "B", "hero": "r0nk", "bot": false, "difficulty": 0, "token": "b"}, {"name": "C", "bot": true, "difficulty": 2, "token": ""}], "card_pool": "2026", "starting_life": 12, "seed": 12})
 verify(await until(func(): return not saved.is_empty()), "Initial safe snapshot received")
func run():
 server = LinkServer.new()
 root.add_child(server)
 if server.listen(0) != OK:
  print("Link checks: 0 checks, 0 failures (SKIPPED: sandbox cannot bind localhost TCP)")
  server.queue_free()
  quit(0)
  return
 verify(await health(server.port), "Raw TCP GET /health returns 200 ok")
 await open_wire()
 wire.send({"t": "ping"})
 verify(await until(func(): return messages.any(func(m): return m.t == "pong")), "Application ping/pong")
 await setup()
 wire.send({"t": "connect", "seat": 0, "version": "wrong"})
 verify(await until(func(): return messages.any(func(m): return m.t == "to" and m.seat == 0 and m.msg.t == "error" and m.msg.reason == "version" and m.msg.need == version)), "Version mismatch gives exact error and required version")
 connect_clients()
 var baseline = snapshots
 verify(await until(func(): return snapshots > baseline + 5), "Snapshots arrive after completed actions")
 await finish()
 await clear_clients()
 # Replace a live link without resetting the authoritative game.
 var previous = wire
 var before = server.game
 await open_wire()
 verify(await until(func(): previous.poll(); return not previous.active), "Second link closes first")
 verify(server.game == before, "Replacement preserves game")
 saved = {}
 await setup()
 connect_clients()
 var old_count = snapshots
 verify(await until(func(): return snapshots > old_count + 4), "Midgame checkpoint received")
 for client in clients: client.scripted = false
 # Restore only the last message received by the simulated Room, never server state.
 var checkpoint = saved.duplicate(true)
 verify(not server.game.engine.state.finished, "Restart happens mid-game")
 server.stop()
 server.queue_free()
 await clear_clients()
 server = LinkServer.new()
 root.add_child(server)
 verify(server.listen(0) == OK, "Replacement container listens")
 await open_wire()
 over = false
 wire.send({"t": "restore", "room": "TEST", "snapshot": checkpoint})
 connect_clients()
 await finish()
 await clear_clients()
 # With no humans connected, takeover still runs on the server.
 saved = {}
 await setup()
 await until(func(): return server.game != null and not saved.is_empty())
 var now = server.game.now()
 server.game.clock = func(): return now + 121.0
 verify(await until(func(): return over, 40000), "Bots and takeover run with no connected humans")
 await subprocess_smoke()
 server.stop()
 server.queue_free()
 await frames(2)
 print("Link checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func subprocess_smoke():
 var binary = ProjectSettings.globalize_path("res://build/server/phreaknic-server.x86_64")
 if not FileAccess.file_exists(binary):
  print("Server subprocess smoke: SKIPPED (export binary missing)")
  return
 var probe = TCPServer.new()
 if probe.listen(0, "127.0.0.1") != OK:
  print("Server subprocess smoke: SKIPPED (cannot bind localhost)")
  return
 var port = probe.get_local_port()
 probe.stop()
 var pid = OS.create_process(binary, ["--headless", "--", "--server", "--port", str(port)])
 verify(pid > 0, "Exported server subprocess starts")
 if pid <= 0: return
 var healthy = false
 for attempt in 100:
  if await health(port):
   healthy = true
   break
  await create_timer(0.05).timeout
 verify(healthy, "Exported server /health")
 OS.kill(pid)
 print("Server subprocess smoke: %s" % ("PASS" if healthy else "FAIL"))
