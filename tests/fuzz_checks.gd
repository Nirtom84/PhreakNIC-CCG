extends SceneTree
var checks = 0
var failures = 0
var rng = RandomNumberGenerator.new()
func _initialize(): run.call_deferred()
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func frames(n = 3):
 for i in n: await process_frame
func collect(server, results):
 results.append(await server.engine.deciders[0].confirm(server.engine.state.players[0], "Fuzz prompt"))
func run():
 rng.seed = 110011
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{}, {}], "2026", 10, 42)
 var twin = GameServer.new()
 root.add_child(twin)
 twin.setup([{}, {}], "2026", 10, 42)
 verify(server.engine.state.center_deck.map(func(c): return c.id) != twin.engine.state.center_deck.map(func(c): return c.id), "Secure same-seed servers have independent shuffles")
 twin.queue_free()
 var clients = []
 var endpoints = []
 for seat in 2:
  var pair = LoopbackTransport.pair()
  server.attach(pair[0])
  endpoints.append(pair[0])
  var client = NetClient.new()
  root.add_child(client)
  client.connect_to(pair[1], seat, server.tokens[seat])
  clients.append(client)
 await frames()
 server.running = true
 server.engine.state.turn = 1
 var link = LinkServer.new()
 root.add_child(link)
 # The handler is tested without requiring sandbox socket access.
 link.game = server
 for seat in 2: link.endpoints[seat] = endpoints[seat]
 var deep = "leaf"
 for i in 1000: deep = [deep]
 var values = [null, true, false, "", "x".repeat(100000), -999999999999, 999999999999, NAN, INF, -INF, [], {}, deep, 0.5]
 var before = JSON.stringify(SaveGame.snapshot(server.engine.state))
 for i in 4000:
  var value = values[rng.randi_range(0, values.size()-1)]
  var message
  match i % 8:
   0: message = {"t": value, "kind": value}
   1: message = {"t": "action", "kind": value, "uid": value, "index": value}
   2: message = {"t": "answer", "id": value, "value": value}
   3: message = {"t": "action", "kind": "play", "uid": value}
   4: message = {"t": "hello", "seat": value, "token": value, "version": server.version()}
   5: message = {"t": "action", "kind": "end_turn", "seat": server.engine.active().seat}
   6: message = {"t": "unknown", "nested": value}
   _: message = {}
  # Only the inactive seat sends valid-looking actions.
  var seat = 1 - server.engine.active().seat if i % 8 == 5 else i % 2
  if i % 2 == 0:
   endpoints[seat].received.emit(message)
  else:
   clients[seat].transport.send(message)
  link._receive({"t": "from", "seat": seat, "msg": message})
  link._receive({"t": value})
  link._receive({"t": "connect", "seat": value})
  link._receive({"t": "setup", "seats": value, "starting_life": value})
  if i % 100 == 0:
   await frames(1)
   verify(server.engine.state.conservation_ok(), "Conservation under malformed traffic")
 verify(before == JSON.stringify(SaveGame.snapshot(server.engine.state)), "Fuzz never applies illegal actions")
 var results = []
 collect(server, results)
 await frames()
 var id = server.pending.keys()[0]
 for i in 1000:
  clients[1].answer(id, true)
  var wrong = values[i % values.size()]
  if wrong is bool: wrong = "wrong"
  clients[0].answer(id, wrong)
 await frames(4)
 verify(results.is_empty() and server.pending.has(id), "Foreign/malformed answers cannot resolve prompt")
 clients[0].answer(id, true)
 clients[0].answer(id, false)
 await frames(4)
 verify(results == [true] and server.pending.is_empty(), "Duplicate answer resolves exactly once")
 verify(server.engine.state.conservation_ok(), "Conservation after prompt fuzz")
 for client in clients: client.scripted = true
 server.dirty = true
 for frame in 5000:
  if server.engine.state.finished: break
  await process_frame
 if not server.engine.state.finished: print("FUZZ DEBUG turn=", server.engine.state.turn, " active=", server.engine.active().seat, " pending=", server.pending.size(), " locks=", server.locks, " ready=", clients.map(func(c): return c.can_act), " prompts=", clients.map(func(c): return c.prompts.keys()))
 verify(server.engine.state.finished and server.engine.state.conservation_ok(), "Game finishes after fuzz")
 link.game = null
 link.endpoints.clear()
 for client in clients: client.transport.close(); client.queue_free()
 server.queue_free()
 link.queue_free()
 await frames()
 print("Fuzz checks: %d checks, %d failures (6000 malformed/foreign messages plus link-handler probes, seed 110011)" % [checks, failures])
 quit(1 if failures else 0)
