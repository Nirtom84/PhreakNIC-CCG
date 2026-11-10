extends SceneTree
var checks = 0
var failures = 0
var fake_time = 0.0
var previous_hidden = {}
var views_seen = 0
var last_view_frame = {}
func _initialize(): run.call_deferred()
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func room(config: Array, seed_value: int = 12, life: int = 12):
 var server = GameServer.new()
 root.add_child(server)
 server.clock = func(): return fake_time
 server.setup(config, "2026", life, seed_value)
 return server
func link(server, seat: int, scripted: bool = true):
 var endpoints = LoopbackTransport.pair()
 server.attach(endpoints[0])
 var client = NetClient.new()
 client.scripted = scripted
 root.add_child(client)
 client.message_received.connect(func(m): inspect_message(server, seat, m))
 client.connect_to(endpoints[1], seat, server.tokens[seat])
 return client
func inspect_message(server, seat: int, message: Dictionary):
 if message.t == "view":
  views_seen += 1
  var frame_key = str(server.get_instance_id()) + ":" + str(seat)
  verify(last_view_frame.get(frame_key, -1) != Engine.get_process_frames(), "At most one view per frame per seat")
  last_view_frame[frame_key] = Engine.get_process_frames()
  var view = message.state
  var text = JSON.stringify(view)
  verify('"rng' not in text and '"seed' not in text and '"initial_ids"' not in text and '"coverage"' not in text, "No private state metadata")
  var mirror = NetView.apply(view)
  var hidden = mirror.center_deck.duplicate()
  var sizes_ok = mirror.center_deck.size() == view.counts.center_deck
  for p in mirror.players:
   hidden.append_array(p.deck)
   if p.seat != seat: hidden.append_array(p.hand)
   sizes_ok = sizes_ok and p.deck.size() == view.counts.players[p.seat].deck and p.hand.size() == view.counts.players[p.seat].hand
  verify(sizes_ok, "Hidden counts match authority")
  verify(hidden.all(func(c): return c.id == "hidden" and c.uid < 0 and c.attached.is_empty() and c.flags.is_empty()), "All hidden physical zones redacted")
  var key = str(server.get_instance_id()) + ":" + str(seat)
  var ids = hidden.map(func(c): return c.uid)
  verify(not previous_hidden.has(key) or ids.all(func(uid): return uid not in previous_hidden[key]), "Fresh placeholder UIDs on every view")
  previous_hidden[key] = ids
  # Every serialized real card must be visible under the documented policy.
  var public_ids = []
  for c in mirror.center_row + mirror.removed + mirror.resolving:
   if c != null: public_ids.append(c.uid)
  for p in mirror.players:
   for c in p.discard + p.play_area + p.reserve + p.played + (p.hand if p.seat == seat else []):
    public_ids.append(c.uid)
    for a in c.attached: public_ids.append(a.uid)
  verify(view.objects.all(func(r): return r.type != "card" or r.data.id == "hidden" or r.data.uid in public_ids), "Codec has no orphan private card definitions")
 elif message.t == "event" and message.kind == "draw":
  verify(message.seat == seat, "Draw identity sent only to owner")
 elif message.t == "log":
  verify(" draws " not in message.text, "No private draw names in logs")
func frames(count: int):
 for i in count: await process_frame
func finish_game(server, clients: Array):
 for frame in 25000:
  if server.engine.state.finished: break
  await process_frame
 verify(server.engine.state.finished, "Game completes")
 verify(server.engine.state.conservation_ok(), "Card conservation at finish")
 await frames(4)
 for client in clients:
  verify(client.engine.state.finished, "Final view received")
  client.transport.close()
  client.queue_free()
 server.queue_free()
 await frames(2)
func games():
 for config in [[{}, {}], [{}, {"bot": true}, {"bot": true, "difficulty": 2}], [{}, {}, {"bot": true}, {"bot": true, "difficulty": 2}]]:
  var server = room(config)
  var clients = []
  for i in config.size():
   if not config[i].get("bot", false): clients.append(link(server, i))
  await server.start()
  await finish_game(server, clients)
func illegal():
 var server = room([{}, {}])
 var a = link(server, 0, false)
 var b = link(server, 1, false)
 await server.start()
 await frames(5)
 var clients = [a, b]
 var errors = []
 for client in clients: client.error.connect(func(reason): errors.append(reason))
 var before = JSON.stringify(SaveGame.snapshot(server.engine.state))
 clients[1 - server.engine.active().seat].send_action("end_turn")
 clients[server.engine.active().seat].send_action("play", 999999)
 var pricey = server.engine.state.center_row.filter(func(c): return c != null and server.engine.effective_cost(server.engine.active(), c) > 0)[0]
 clients[server.engine.active().seat].send_action("buy", pricey.uid)
 a.answer("unknown", true)
 await frames(5)
 verify(errors.size() == 4, "Illegal actions and unknown prompt rejected")
 verify(before == JSON.stringify(SaveGame.snapshot(server.engine.state)), "Rejected inputs leave full authoritative state unchanged")
 var endpoint = LoopbackTransport.pair()
 server.attach(endpoint[0])
 var mismatch = []
 endpoint[1].received.connect(func(m): mismatch.append(m))
 endpoint[1].send({"t": "hello", "seat": 0, "token": server.tokens[0], "version": "wrong"})
 await frames(4)
 verify(mismatch.size() == 1 and mismatch[0].t == "error" and not endpoint[0] in server.authenticated, "Version mismatch refused")
 endpoint[1].close()
 for c in clients: c.transport.close(); c.queue_free()
 server.queue_free()
 await frames(2)
func prompt_cases():
 var server = room([{}, {}])
 var client = link(server, 0, false)
 link_cleanup = link(server, 1, false)
 await server.start()
 await frames(5)
 client.scripted = false
 var waiting_events = []
 var choosing_events = []
 link_cleanup.event.connect(func(data):
  if data.kind in ["waiting", "waiting_done"]: waiting_events.append(data))
 client.event.connect(func(data):
  if data.kind in ["waiting", "waiting_done"]: choosing_events.append(data))
 var p = server.engine.state.players[0]
 var remote = server.engine.dec(p)
 var results = []
 collect_option(remote, p, results)
 await frames(3)
 verify(waiting_events.size() == 1 and waiting_events[0].kind == "waiting" and waiting_events[0].seat == 0, "Other seat receives waiting event")
 var request = server.pending.values()[0]
 var error_count = []
 client.error.connect(func(r): error_count.append(r))
 client.answer(request.data.id, 99)
 await frames(3)
 verify(server.pending.size() == 1 and error_count.size() == 1, "Invalid prompt answer remains pending")
 client.answer(request.data.id, 1)
 await frames(4)
 verify(results == [1] and server.pending.is_empty(), "choose_option round trip")
 verify(waiting_events.size() == 2 and waiting_events[-1].kind == "waiting_done", "Answer clears waiting event")
 client.scripted = true
 collect_cards(remote, p, results)
 await frames(5)
 verify(results.size() == 2 and results[1].size() == 1 and results[1][0] in p.hand, "choose_cards resolves authoritative references")
 collect_confirm(remote, p, results)
 await frames(5)
 verify(results.size() == 3 and results[2] == true, "confirm round trip")
 collect_prevention(remote, p, results)
 await frames(5)
 verify(results.size() == 4 and results[3].reduce(func(a,b): return a+b, 0) == 2, "allocate_prevention round trip")
 collect_more(remote, p, results)
 await frames(16)
 verify(results.size() == 8 and results[4].size() == 2 and results[5] == p and results[6] in [1, 3] and results[7] == "Hacking", "Remaining decider methods round trip")
 client.scripted = false
 collect_confirm(remote, p, results)
 await frames(3)
 fake_time += 46
 await frames(4)
 verify(results.size() == 9 and results[8] == await BotDecider.new(server.engine, 1).confirm(p, "Use TOCTOU?"), "45 second timeout chooses Phreak bot answer")
 verify(waiting_events[-1].kind == "waiting_done", "Timeout clears waiting event")
 verify(choosing_events.is_empty(), "Choosing seat receives no waiting events")
 verify(waiting_events.all(func(data): return data.keys().all(func(key): return key in ["t", "kind", "seat", "text"])), "Waiting events contain only public seat and text, no prompt fields")
 for c in [client, link_cleanup]: c.transport.close(); c.queue_free()
 server.queue_free()
 await frames(2)
var link_cleanup
func collect_option(remote, p, results):
 var options: Array[String] = ["One", "Two"]
 results.append(await remote.choose_option(p, "Choose", options))
func collect_cards(remote, p, results): results.append(await remote.choose_cards(p, "Choose", p.hand, 1, 1))
func collect_confirm(remote, p, results): results.append(await remote.confirm(p, "Use TOCTOU?"))
func collect_prevention(remote, p, results):
 var c = p.hand[0]
 results.append(await remote.allocate_prevention(p, 2, [{"card": c, "capacity": 3, "full": false}, {"card": null, "capacity": 2, "full": true}]))
func collect_more(remote, p, results):
 var options: Array[String] = ["Draw", "Damage", "Life"]
 results.append(await remote.choose_options(p, "Choose", options, 2))
 results.append(await remote.choose_player(p, "Choose", [p]))
 var allowed: Array[int] = [1, 3]
 results.append(await remote.choose_number(p, "Choose", allowed))
 results.append(await remote.name_a_card(p, "Name"))
func reconnect_and_restore():
 var server = room([{}, {}], 45, 24)
 var a = link(server, 0, false)
 var b = link(server, 1, false)
 await server.start()
 await frames(5)
 var active = server.engine.active().seat
 var clients = [a, b]
 clients[active].transport.close()
 var old_turn = server.engine.state.turn
 fake_time += 119
 await frames(3)
 verify(server.engine.state.turn == old_turn, "No takeover before 120 seconds")
 fake_time += 2
 await frames(6)
 verify(server.engine.state.turn > old_turn and server.engine.state.players[active].difficulty == 1, "Disconnected human played by Phreak bot after 120 seconds")
 var rejoined = link(server, active, false)
 await frames(5)
 verify(rejoined.seat == active and rejoined.engine.state != null and server.engine.deciders[active] is RemoteDecider and server.engine.state.players[active].difficulty == -1, "Reconnect receives welcome/view and restores remote control")
 var answers = []
 collect_confirm(server.engine.deciders[active], server.engine.state.players[active], answers)
 await frames(3)
 var id = server.pending.keys()[0]
 rejoined.transport.close()
 var again = link(server, active, false)
 await frames(5)
 verify(again.prompts.has(id), "Pending prompt replayed on reconnect")
 again.answer(id, true)
 await frames(4)
 verify(answers == [true], "Reconnected human answers suspended prompt")
 server._checkpoint()
 var saved = NetTransport.normalize(JSON.parse_string(JSON.stringify(server.last_snapshot)))
 verify(not saved.is_empty() and SaveGame.restore(saved.game) != null, "Safe authoritative snapshot restores")
 for c in [a, b, rejoined, again]: c.transport.close(); c.queue_free()
 server.queue_free()
 await frames(2)
 var restored = GameServer.new()
 root.add_child(restored)
 restored.clock = func(): return fake_time
 verify(restored.restore(saved), "New server restores room and tokens")
 verify(restored.engine.state.conservation_ok(), "Restored room conserves cards")
 var x = link(restored, 0)
 var y = link(restored, 1)
 await finish_game(restored, [x, y])
func privacy_and_reactions():
 var server = room([{}, {}], 91, 24)
 var a = link(server, 0, false)
 var b = link(server, 1, false)
 await server.start()
 await frames(4)
 await server.engine.start_turn(0)
 var p = server.engine.state.players[0]
 var q = server.engine.state.players[1]
 var secret = server.engine.state.center_deck.back()
 var private_messages = []
 var owner_messages = []
 a.message_received.connect(func(m):
  if m.t in ["event", "log"]: private_messages.append(m))
 b.message_received.connect(func(m):
  if m.t in ["event", "log"]: owner_messages.append(m))
 server.engine.gain_owner(secret, q)
 server.engine.move(secret, q.deck, "deck")
 # As with attachments on a stolen pTFS, ownership metadata may differ
 # from the receiving hand; privacy must follow zone membership.
 secret.owner = p.seat
 server.engine.draw(q, 1)
 server.dirty = true
 await frames(5)
 var public_text = JSON.stringify(private_messages)
 verify(secret.id not in public_text and server.engine.db().get_card(secret.id).name not in public_text, "Secret draw identity absent from other seat's events and logs")
 verify(owner_messages.any(func(m): return m.t == "event" and m.kind == "draw" and m.id == secret.id), "Owner receives private draw identity")
 server.engine.gain_owner(secret, q)
 var cover = server.engine.state.all_cards().filter(func(c): return c.id == "TOCTOU")[0]
 server.engine.gain_owner(cover, q)
 server.engine.move(cover, q.hand, "hand")
 var attack = server.engine.state.all_cards().filter(func(c): return c.id == "Damage" and c.owner == 0)[0]
 server.engine.move(attack, p.hand, "hand")
 q.life = 1
 b.scripted = true
 var reactions = []
 var unsafe_saves = []
 server.engine.turn_started.connect(func(player):
  if player == q and server.engine.reaction_depth > 0: reactions.append(true))
 server.snapshot.connect(func(_data):
  if server.engine.reaction_depth > 0 or server.engine.busy: unsafe_saves.append(true))
 a.send_action("play", attack.uid)
 for frame in 600:
  await process_frame
  if not reactions.is_empty() and server.engine.reaction_depth == 0 and not server.engine.busy: break
 verify(not reactions.is_empty() and server.engine.reaction_depth == 0 and server.engine.active() == p, "Remote human reaction turn completes while outer action is suspended")
 verify(unsafe_saves.is_empty(), "No snapshots inside suspended reactions")
 verify(server.engine.state.conservation_ok(), "Reaction and hidden draw conserve cards")
 for c in [a,b]: c.transport.close(); c.queue_free()
 server.queue_free()
 await frames(3)
func transport_checks():
 var pair = LoopbackTransport.pair(false)
 var messages = []
 var closures = []
 pair[1].received.connect(func(m): messages.append(m))
 pair[1].closed.connect(func(): closures.append(true))
 pair[0].send({"t": "test", "nested": {"integers": [7, 8]}, "fraction": 1.5})
 verify(messages.is_empty(), "Loopback never delivers synchronously")
 pair[1].pump()
 verify(messages.size() == 1 and messages[0].nested.integers[0] is int and messages[0].fraction == 1.5, "Explicit pump JSON round trip normalizes integral numbers")
 pair[0].close()
 pair[0].send({"t": "ignored"})
 pair[1].pump()
 verify(closures.size() == 1 and messages.size() == 1, "Close disconnects pair and drops further sends")
func bot_names():
 var db = root.get_node("CardDB")
 var hero = db.pool_ids("2025").filter(func(id): return db.has_subtype(id, "Hero"))[0]
 var config = [{"name": db.cards[hero].name, "hero": hero}, {"name": "Bot", "bot": true}, {"name": "", "bot": true}, {"bot": true}]
 var a = room(config, 42)
 var b = room(config, 42)
 verify(a.seats == b.seats, "Bot identities use game seed")
 var names = []
 var ids = []
 for seat in a.seats:
  verify(seat.name.to_lower() not in names and seat.hero not in ids, "Unique names and avatars exclude human identity")
  names.append(seat.name.to_lower())
  ids.append(seat.hero)
  if seat.bot: verify(db.has_subtype(seat.hero, "Hero") and not db.cards[seat.hero].get("starter", false), "Bot has nonstarter Hero identity")
 await a.start()
 a._checkpoint()
 var restored = GameServer.new()
 root.add_child(restored)
 verify(restored.restore(a.last_snapshot) and restored.seats == a.seats, "Restore retains Hero identities")
 a.queue_free()
 b.queue_free()
 restored.queue_free()
func run():
 await bot_names()
 transport_checks()
 await games()
 await illegal()
 await prompt_cases()
 await reconnect_and_restore()
 await privacy_and_reactions()
 verify(views_seen > 100, "Views inspected throughout games")
 print("Net checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
