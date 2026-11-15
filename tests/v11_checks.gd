extends SceneTree
var checks = 0
var failures = 0
var time = 0.0
class SearchSpy extends Decider:
 var seen = []
 func choose_cards(_p, text: String, cards: Array, minimum: int, _maximum: int) -> Array:
  if text == "Search for five cards": seen = cards.duplicate()
  return cards.slice(0, minimum)
class Yes extends Decider:
 func confirm(_p, _prompt: String) -> bool: return true
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
 await toctou_turns()
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
 await stall_checks()
 print("V11 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func seated_room() -> Array:
 var server = make_room()
 server.running = true
 server.engine.state.turn = 1
 var clients = []
 for seat in 2:
  var pair = LoopbackTransport.pair()
  server.attach(pair[0])
  var client = NetClient.new()
  root.add_child(client)
  client.connect_to(pair[1], seat, server.tokens[seat])
  clients.append(client)
 await frames()
 return [server, clients]
## One player must not be able to hold a game forever (security scan, v0.30).
func stall_checks():
 # Pointless actions reset the idle timer, but not the hard per-turn limit.
 var made = await seated_room()
 var server = made[0]
 var clients = made[1]
 var active = server.engine.active().seat
 var turn = server.engine.state.turn
 for i in 5:
  time += 100
  clients[active].send_action("play_basics")
  await frames()
 verify(server.engine.state.turn == turn, "Actions keep the turn alive before the hard limit")
 time += 101
 for i in 300:
  if server.engine.state.turn > turn: break
  await process_frame
 verify(server.engine.state.turn > turn, "A turn kept alive with pointless actions ends at the hard limit")
 server.running = false
 # A human reaction turn (TOCTOU) that never ends is finished by a bot after 180 idle seconds.
 made = await seated_room()
 server = made[0]
 var results = []
 var reacting = server.engine.state.players[0]
 if server.engine.state.active_seat == 0: server.engine.state.active_seat = 1
 collect_reaction(server.engine, results)
 await frames()
 verify(server.engine.reaction_depth > 0 and server.engine.active() == reacting, "Human reaction turn is waiting")
 time += 179
 await frames()
 verify(results.is_empty(), "No takeover of a reaction turn before 180 seconds")
 time += 2
 for i in 300:
  if not results.is_empty(): break
  await process_frame
 verify(not results.is_empty() and server.engine.reaction_depth == 0, "An idle reaction turn is finished by a bot")
 server.running = false
## TOCTOU: "pause the current player's turn, and take an extra turn immediately. After the extra turn,
## return play to the paused turn." Shipped deck 082 has three TOCTOU; every seat uses them.
func toctou_game(levels: Array, active: int):
 var engine = GameEngine.new()
 root.add_child(engine)
 var deck = CustomDeck.decode(JSON.parse_string(FileAccess.get_file_as_string("res://decks/custom/082-max-chaos.phreakdeck.json")).code)
 var deciders = []
 for seat in levels.size(): deciders.append(Yes.new())
 engine.setup(levels, 991, deciders, "custom", 50, [], deck)
 # Keep Rickroll's forced buy out of the turns started here.
 for slot in 5:
  while engine.state.center_row[slot] != null and engine.state.center_row[slot].id == "Rickroll":
   var roll = engine.state.center_row[slot]
   engine.detach(roll)
   engine.state.center_deck.push_front(roll)
 engine.turn_driver = func(p): await engine.end_turn(p)   # bots end their TOCTOU turn at once
 await engine.start_turn(active)
 return engine
## A card moved into a seat's hand, as if bought and drawn earlier.
func toctou_hand(engine, id: String, seat: int):
 var p = engine.state.players[seat]
 for c in p.hand + p.deck + engine.state.center_deck:
  if c.id == id:
   engine.gain_owner(c, p)
   engine.move(c, p.hand, "hand")
   return c
 return null
func toctou_turns():
 # A TOCTOU turn nested in a human's TOCTOU turn, by a bot or by a second human.
 for inner_human in [false, true]:
  var engine = await toctou_game([-1, -1 if inner_human else 2, 2], 2)
  var outer = engine.state.players[0]
  var inner = engine.state.players[1]
  var bot = engine.state.players[2]
  outer.life = 1
  inner.life = 1
  toctou_hand(engine, "TOCTOU", 0)
  var inner_toctou = toctou_hand(engine, "TOCTOU", 1)
  engine.play_card(bot, toctou_hand(engine, "Damage", 2))   # seat 0 takes a TOCTOU turn
  await frames()
  engine.play_card(outer, toctou_hand(engine, "Damage", 0))   # seat 1 takes one inside it
  await frames()
  if inner_human: engine.end_turn(inner)
  await frames()
  var label = "human" if inner_human else "bot"
  verify(inner_toctou in engine.state.removed and engine.reaction_depth == 1 and engine.is_turn(outer), "Human TOCTOU turn continues after a nested %s TOCTOU turn ends" % label)
  engine.end_turn(outer)
  await frames()
  verify(engine.reaction_depth == 0 and engine.active() == bot and outer.alive, "Ending it returns play to the paused turn (nested %s)" % label)
  engine.queue_free()
 # Seat 1's TOCTOU turn interrupts r0nk's simultaneous loss. Seat 0 dies alone during that turn.
 var engine = await toctou_game([2, 2], 0)
 var caster = engine.state.players[0]
 var survivor = engine.state.players[1]
 caster.life = 2
 survivor.life = 1
 toctou_hand(engine, "TOCTOU", 1)
 var kill = toctou_hand(engine, "Damage", 1)
 var second = toctou_hand(engine, "r0nk", 1)
 var during = {}
 engine.turn_driver = func(p):
  await engine.play_card(p, kill)
  during.over = engine.state.finished
  await engine.play_card(p, second)   # refused once the game is over
  if not engine.state.finished: await engine.end_turn(p)
 await engine.play_card(caster, toctou_hand(engine, "r0nk", 0))
 verify(during.get("over", false) and engine.state.winner == survivor, "Last player alive wins during a TOCTOU turn that interrupted r0nk")
 engine.queue_free()
