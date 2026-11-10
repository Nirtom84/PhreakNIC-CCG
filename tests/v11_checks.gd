extends SceneTree
var checks = 0
var failures = 0
var time = 0.0
class SearchSpy extends Decider:
 var seen = []
 func choose_cards(_p, text: String, cards: Array, minimum: int, _maximum: int) -> Array:
  if text == "Search for five cards": seen = cards.duplicate()
  return cards.slice(0, minimum)
func _initialize(): run.call_deferred()
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func frames(n = 3):
 for i in n: await process_frame
func make_room():
 var server = GameServer.new()
 root.add_child(server)
 server.clock = func(): return time
 server.setup([{"name": "Alice"}, {"name": "Bob"}], "2026", 24, 123)
 return server
func collect_reaction(engine, results):
 await engine.reaction_turn(engine.state.players[0])
 results.append(true)
func run():
 var a = make_room()
 var b = make_room()
 verify(a.engine.secure_random and b.engine.secure_random, "Servers enable CSPRNG")
 verify(a.engine.state.center_deck.map(func(c): return c.id) != b.engine.state.center_deck.map(func(c): return c.id), "Same seed does not repeat online shuffle")
 var local_a = GameEngine.new()
 var local_b = GameEngine.new()
 root.add_child(local_a)
 root.add_child(local_b)
 local_a.setup([0, 2], 456)
 local_b.setup([0, 2], 456)
 verify(JSON.stringify(SaveGame.snapshot(local_a.state)) == JSON.stringify(SaveGame.snapshot(local_b.state)), "Offline seeded setup stays deterministic")
 for n in [1, 2, 3, 7, 255, 1000000]:
  for i in 50:
   var value = GameEngine.crypto_int(n)
   verify(value >= 0 and value < n, "Secure bounded sampling range")
 # Avoid opening an unrelated initial-row start trigger in this timer test.
 a.running = true
 a.engine.state.turn = 1
 var clients = []
 var events = [[], []]
 for seat in 2:
  var pair = LoopbackTransport.pair()
  a.attach(pair[0])
  var client = NetClient.new()
  root.add_child(client)
  var index = seat
  client.event.connect(func(data): events[index].append(data))
  client.connect_to(pair[1], seat, a.tokens[seat])
  clients.append(client)
 await frames()
 var active = a.engine.active().seat
 time += 119
 await frames()
 verify(not events[active].any(func(e): return e.kind == "idle_warning"), "No warning before 120 seconds")
 time += 1
 await frames()
 verify(events[active].filter(func(e): return e.kind == "idle_warning").size() == 1, "Warning at 120 seconds")
 verify(not events[1-active].any(func(e): return e.kind == "idle_warning"), "Warning private to idle seat")
 clients[active].transport.send({"t": "noise"})
 await frames()
 verify(a.idle_at == 0, "Rejected traffic does not reset deadline")
 # Accepted action resets the timer.
 clients[active].send_action("play", a.engine.active().hand.filter(func(c): return c.id == "Hacking")[0].uid)
 await frames()
 verify(a.idle_at == time and not a.idle_warned, "Accepted action resets deadline")
 var turn = a.engine.state.turn
 time += 179
 await frames()
 verify(a.engine.state.turn == turn, "No idle takeover before 180 seconds")
 time += 1
 for i in 200:
  if a.engine.state.turn > turn: break
  await process_frame
 verify(a.engine.state.turn > turn, "Idle bot completes turn")
 await frames()
 verify(a.engine.deciders[active] is RemoteDecider, "Temporary bot returns human control")
 verify(a.engine.state.log.any(func(line): return "was idle; a bot finished their turn" in line), "Idle turn logged")
 # Three consecutive idle turns on that seat cause permanent takeover.
 a.idle_streak[active] = 2
 a.engine.state.active_seat = active
 a.engine.state.turn += 1
 await frames()
 time += 180
 await frames()
 verify(a.permanent_idle.has(active) and a._takeover(active), "Third consecutive idle becomes full takeover")
 a.running = false
 for i in 10000: a.engine.say("x".repeat(400))
 verify(a.engine.state.log.size() <= 200 and "\n".join(a.engine.state.log).to_utf8_buffer().size() <= 65536, "Server log bounded by count and bytes")
 a._checkpoint()
 verify(JSON.stringify(a.last_snapshot).to_utf8_buffer().size() < 256 * 1024, "Long-game snapshot stays below 256 KiB")
 var restored = GameServer.new()
 root.add_child(restored)
 verify(restored.restore(NetTransport.normalize(JSON.parse_string(JSON.stringify(a.last_snapshot)))) and restored.engine.secure_random, "Restore preserves deck orders and secure future randomness")
 verify(not "rng_seed" in JSON.stringify(NetView.build(a.engine, 0)), "Seed never in client view")
 for kind in ["room_version", "busy", "maintenance", "rate_limit"]:
  var text = OnlineAPI.error_text(409, {"error": kind, "room": "0.10"})
  verify(not "Could not" in text and not "Please update" in text, "Friendly error: " + kind)
 verify("0.10" in OnlineAPI.error_text(409, {"error": "room_version", "room": "0.10"}), "Old room error includes room version")
 var report = load("res://scripts/ui/bug_report.gd")
 verify(report.redact("Alice Bob Bot", ["Alice", "Bob", "Bot"], [false, false, true], 0) == "Alice Player 2 Bot", "Bug log keeps self and bots, removes opponents")
 verify("names removed" in report.build("log").uri_decode(), "Bug form describes redaction")
 var spy = SearchSpy.new()
 local_a.deciders = [spy, spy]
 var player = local_a.state.players[0]
 player.deck.reverse()
 await local_a.effects._effect_oprah_wonka(player, null)
 var ordered = spy.seen.duplicate()
 ordered.sort_custom(func(x, y): return x.id < y.id or (x.id == y.id and x.uid < y.uid))
 verify(not spy.seen.is_empty() and spy.seen == ordered, "Oprah search options conceal deck order")
 for code in [4000, 4001]:
  var session = OnlineSession.new()
  root.add_child(session)
  var endpoint = WebSocketTransport.new()
  endpoint.close_code = code
  session.transport = endpoint
  var removed = []
  session.removed.connect(func(text): removed.append(text))
  OnlineAPI.remember({"server": "https://example.test", "code": "ABCD", "seat": 0, "token": "x"})
  session._closed(endpoint)
  verify(session.stopped and session.retry == 0, "Terminal seat close stops reconnect")
  verify(session.status == ("The host removed you from the room." if code == 4001 else "This seat was opened somewhere else."), "Terminal seat close message")
  verify(OnlineAPI.remembered().is_empty() and (removed.size() == 1 if code == 4001 else removed.is_empty()), "Kicked seat forgotten and returns home")
  session.queue_free()
 var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
 file.store_string("x".repeat(65537))
 file.close()
 verify(OnlineAPI.remembered().is_empty(), "Oversized settings ignored")
 var config = ConfigFile.new()
 config.set_value("game", "online_seat", ["wrong"])
 config.save("user://settings.cfg")
 verify(OnlineAPI.remembered().is_empty(), "Wrong seat type ignored")
 config.set_value("game", "online_seat", {"server": "https://example.test", "code": "ABCD", "token": "x", "seat": 999})
 config.save("user://settings.cfg")
 verify(OnlineAPI.remembered().is_empty(), "Out of range seat ignored")
 file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
 file.store_string("x".repeat(2 * 1024 * 1024 + 1))
 file.close()
 verify(SaveGame.read().is_empty(), "Oversized save ignored")
 config.clear()
 for entry in [["sound", "volume"], ["game", "starting_life"], ["game", "auto_end_turn"], ["player", "hero_id"]]: config.set_value(entry[0], entry[1], {"bad": true})
 config.save("user://settings.cfg")
 var sound = load("res://scripts/ui/sfx.gd").new()
 root.add_child(sound)
 verify(sound.volume == 0.65 and sound.starting_life == 0 and sound.auto_end_turn and sound.hero_id == "", "Malformed settings retain defaults without conversion")
 sound.queue_free()
 var reaction = GameEngine.new()
 root.add_child(reaction)
 reaction.setup([-1, -1], 12, [Decider.new(), Decider.new()])
 reaction.state.active_seat = 1
 var completed = []
 collect_reaction(reaction, completed)
 await frames()
 verify(reaction.reaction_depth == 1 and completed.is_empty(), "Human reaction waits for input")
 reaction.finish(reaction.state.players[0])
 await frames()
 verify(reaction.reaction_depth == 0 and completed == [true], "Game over releases suspended human reaction")
 reaction.queue_free()
 var bad = SaveGame.snapshot(local_a.state)
 bad.state.starting_life = -100
 verify(SaveGame.restore(bad) == null, "Save range validation")
 for c in clients: c.transport.close(); c.queue_free()
 for node in [a, b, local_a, local_b, restored]: node.queue_free()
 await frames()
 # The website's CSP forbids JavaScript eval, so the game must never use JavaScriptBridge.eval.
 var eval_users = []
 for dir in ["res://scripts/ui", "res://scripts/net", "res://scripts/core", "res://scripts/ai"]:
  for script_name in DirAccess.get_files_at(dir):
   if script_name.ends_with(".gd") and FileAccess.get_file_as_string(dir + "/" + script_name).contains("JavaScriptBridge" + ".eval("): eval_users.append(script_name)
 verify(eval_users.is_empty(), "No script uses JavaScriptBridge.eval: %s" % [eval_users])
 print("V11 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
