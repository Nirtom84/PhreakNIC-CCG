extends SceneTree
var checks = 0
var failures = 0
var time = 0.0
var rooms = []
class Wire extends NetTransport:
 var messages = []
 func send(message: Dictionary): messages.append(message)
func _initialize(): run.call_deferred()
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func room():
 var s = GameServer.new()
 root.add_child(s)
 s.set_process(false)
 s.clock = func(): return time
 s.setup([{"name": "Alice"}, {"name": "Bob"}], "2026", 24, 1)
 s.running = true
 s.engine.state.turn = 1
 s.engine.state.active_seat = 1
 for seat in 2:
  var wire = Wire.new()
  s._receive(wire, {"t": "hello", "seat": seat, "version": s.version(), "token": s.tokens[seat]})
 s._idle_tick()
 rooms.append(s)
 return s
func action(s, kind, seat = 1, extra = {}):
 var message = {"t": "action", "kind": kind}
 message.merge(extra)
 s._receive(s.connections[seat], message)
func frames(count = 4):
 for i in count: await process_frame
func finish_idle(s, turn):
 for i in 500:
  s._process(0)
  if s.engine.state.turn > turn: break
  await process_frame
 verify(s.engine.state.turn > turn, "Idle takeover bot finishes stalled turn")
 s.running = false
func run():
 var s = room()
 var endpoint_timer = s.connections[1]
 s.dirty = false
 endpoint_timer.messages.clear()
 await frames(1)
 time += 1
 s._process(0)
 verify(endpoint_timer.messages.any(func(m): return m.t == "timers" and m.timers.any(func(t): return t.has("handable"))) and not endpoint_timer.messages.any(func(m): return m.t == "view") and not s.dirty, "Idle tick sends small timers only")
 endpoint_timer.messages.clear()
 s._process(0)
 verify(endpoint_timer.messages.is_empty(), "Timers limited to once per second")
 s.engine.busy = true
 time += 1
 s._process(0)
 verify(endpoint_timer.messages.is_empty(), "Unchanged displayed timers are suppressed")
 s.engine.busy = false
 var p = s.engine.active()
 # Empty basics is accepted but does not reset the clock, dirty a view, or snapshot.
 for c in p.hand.duplicate(): s.engine.move(c, p.deck, "deck")
 s.state_fingerprint = s._fingerprint()
 s.dirty = false
 var counts = [0]
 s.snapshot.connect(func(_data): counts[0] += 1)
 var began = s.idle_at
 var fingerprint_calls = s.fingerprint_calls
 action(s, "play_basics")
 verify(s.fingerprint_calls - fingerprint_calls <= 1, "At most one fingerprint per action")
 verify(not s.dirty and counts[0] == 0 and s.idle_at == began, "No-op skips view, checkpoint, and progress reset")
 var endpoint = s.connections[1]
 endpoint.messages.clear()
 for i in 5: action(s, "play_basics")
 verify(endpoint.messages.filter(func(m): return m.t == "error" and m.reason == "action rate limit").size() == 1, "Sixth action within a second is refused")
 time += 1
 action(s, "play_basics")
 verify(s.action_times[1].size() == 1, "Action budget recovers after one second")
 var cost_at = Time.get_ticks_usec()
 for i in 100: s._fingerprint()
 print("Fingerprint mean: %.0f us" % ((Time.get_ticks_usec() - cost_at) / 100.0))
 s._checkpoint()
 verify(counts[0] == 1, "Initial checkpoint emitted")
 p.hacking += 1
 s._checkpoint()
 verify(counts[0] == 1 and s.snapshot_due, "Snapshot coalesced within two seconds")
 time += 2
 s._process(0)
 verify(counts[0] == 2 and not s.snapshot_due and SaveGame.restore(s.last_snapshot.game).players[1].hacking == p.hacking, "Final pending snapshot flushes without another action")
 time += 0.01
 s.engine.state.turn += 1
 s._checkpoint()
 verify(counts[0] == 3, "Turn boundary snapshots immediately")
 var restored = GameServer.new()
 root.add_child(restored)
 s.host_seat = 1
 s._checkpoint(true)
 verify(restored.restore(s.last_snapshot) and restored.host_seat == 1, "Snapshot restores host seat")
 restored.running = false
 restored.queue_free()
 endpoint.messages.clear()
 s.view_at.clear()
 s.view_frames.clear()
 for i in 30:
  s._view(1)
  time += 0.01
  await process_frame
 verify(endpoint.messages.filter(func(m): return m.t == "view").size() <= 2, "Thirty changes coalesce to at most five views per second")
 # Turn boundaries must also flush while the clock is inside the view interval.
 await frames(1)
 s._view(1, true)
 endpoint.messages.clear()
 s.engine.turn_ended.emit(p)
 s.dirty = true
 await frames(1)
 s._process(0)
 verify(endpoint.messages.any(func(m): return m.t == "view"), "Turn-end view bypasses time coalescing")
 # Terminal views must not sit behind the ordinary coalescing interval.
 await frames(1)
 s._view(1, true)
 endpoint.messages.clear()
 var snap_before = counts[0]
 s.engine.finish(null)
 await frames(1)
 s._process(0)
 verify(endpoint.messages.any(func(m): return m.t == "view" and NetView.apply(m.state).finished), "Game-over view bypasses time coalescing")
 verify(counts[0] == snap_before + 1 and s.last_snapshot.game == SaveGame.snapshot(s.engine.state), "Game-over snapshot flushes immediately")
 s.running = false
 # Real cancellable activation: wait 44 seconds, cancel and reopen repeatedly.
 s = room()
 p = s.engine.active()
 var phone = s.engine.state.all_cards().filter(func(c): return c.id == "Payphone")[0]
 s.engine.gain_owner(phone, p)
 s.engine.move(phone, p.play_area, "play")
 s.state_fingerprint = s._fingerprint()
 var turn = s.engine.state.turn
 began = s.idle_at
 for i in 4:
  action(s, "activate", 1, {"uid": phone.uid})
  verify(s.pending.size() == 1, "Activation prompt opened")
  time += 44
  s._idle_tick()
  var id = s.pending.keys()[0]
  s._receive(s.connections[1], {"t": "answer", "id": id, "value": 2})
  verify(s.idle_at == began, "Cancelled Payphone activation leaves idle deadline unchanged")
 time += 5
 s._idle_tick()
 verify(s.idle_bot.has(1), "Repeated cancelled prompts charge all waiting time")
 await finish_idle(s, turn)
 # Reconnect before the 120-second disconnect takeover and repeat a no-op.
 s = room()
 p = s.engine.active()
 for c in p.hand.duplicate(): s.engine.move(c, p.deck, "deck")
 s.state_fingerprint = s._fingerprint()
 turn = s.engine.state.turn
 for i in 2:
  action(s, "play_basics")
  var wire = s.connections[1]
  s._closed(wire)
  time += 110
  s._idle_tick()
  s._receive(wire, {"t": "hello", "seat": 1, "token": s.tokens[1], "version": s.version()})
 verify(s.idle_bot.has(1) and s.turn_used >= 220, "Short disconnect loops count toward idle and hard turn clocks")
 await finish_idle(s, turn)
 # Hard limit is checked even while the active player's prompt is open.
 s = room()
 s.turn_used = s.TURN_LIMIT - 1
 var result = []
 collect_prompt(s, 1, result)
 time += 2
 s._idle_tick()
 verify(s.idle_bot.has(1), "Hard turn limit checked before prompt guard")
 s._complete(s.pending.keys()[0], true)
 s.running = false
 # Resolving rules and another seat's prompt pause both clocks.
 s = room()
 began = s.idle_at
 collect_prompt(s, 0, [])
 time += 90
 s._idle_tick()
 verify(s.turn_used == 0 and s.idle_at == began + 90 and not s.handable(1), "Other seat's decision pauses active idle and hard clocks")
 s._receive(s.connections[0], {"t": "answer", "id": s.pending.keys()[0], "value": true})
 verify(s.idle_at == began + 90, "Other seat's answer does not reset active idle clock")
 s.engine.busy = true
 time += 90
 s._idle_tick()
 verify(s.turn_used == 0 and not s.idle_bot.has(1), "Rules resolution pauses active clock")
 s.engine.busy = false
 s.running = false
 # A completed negative confirm is a meaningful decision, not an activation cancel.
 s = room()
 collect_prompt(s, 1, [])
 time += 30
 s._idle_tick()
 s._receive(s.connections[1], {"t": "answer", "id": s.pending.keys()[0], "value": false})
 verify(s.idle_at == time, "Completed negative confirm resets idle deadline")
 s.running = false
 # A reaction charges its own prompt/disconnection and enforces its hard limit.
 s = room()
 s.engine.reaction_depth = 1
 s._turn_started(s.engine.active())
 time += 120
 s._idle_tick()
 verify(s.handable(1), "Host can hand over idle reaction seat")
 collect_prompt(s, 1, [])
 s._closed(s.connections[1])
 s.reaction_used = s.REACTION_LIMIT - 1
 time += 2
 s._idle_tick()
 verify(s.idle_bot.has(1) and s.reaction_used >= s.REACTION_LIMIT, "Reaction hard limit precedes own prompt and offline guards")
 s._complete(s.pending.keys()[0], true)
 s.running = false
 # Returning from a reaction preserves the interrupted main turn's hard budget.
 s = room()
 s.turn_used = 500
 s.engine.reaction_depth = 1
 s._turn_started(s.engine.active())
 time += 20
 s._idle_tick()
 s.engine.reaction_depth = 0
 s.engine.state.turn += 1
 s._idle_tick()
 verify(s.turn_used == 500, "Reaction's global turn increment does not reset interrupted hard budget")
 s.running = false
 # Host authority, target, and grace period are enforced by the server.
 s = room()
 time += 119
 s._idle_tick()
 action(s, "hand_to_bot", 0, {"seat": 1})
 verify(not s.idle_bot.has(1) and not s.handable(1), "Host cannot hand over before 120 seconds")
 time += 1
 s._idle_tick()
 verify(s.timer_state().any(func(t): return t.kind == "turn" and t.handable and t.host_seat == 0), "Timer advertises host handover at 120 seconds")
 action(s, "hand_to_bot", 1, {"seat": 1})
 action(s, "hand_to_bot", 0, {"seat": 0})
 verify(s.idle_bot.is_empty(), "Non-host and host-self handovers refused")
 s.idle_streak[1] = 2
 turn = s.engine.state.turn
 action(s, "hand_to_bot", 0, {"seat": 1})
 verify(s.idle_bot.has(1) and s.idle_streak[1] == 2 and not s.permanent_idle.has(1), "Host handover does not count an idle strike")
 await finish_idle(s, turn)
 # Unknown client-controlled names never enter diagnostics.
 s = room()
 var logs = []
 s.diagnostic.connect(func(line): logs.append(line))
 action(s, "evil\nforged log", 0)
 verify(not "evil" in " ".join(logs) and "unknown" in " ".join(logs), "Unknown action names are sanitized in diagnostics")
 s.running = false
 var link = LinkServer.new()
 verify(link.bind_address == "127.0.0.1", "Link defaults to loopback")
 link.link_key = "secret"
 verify(not link.authorized_header("GET /link HTTP/1.1\r\n\r\n"), "Link rejects missing secret")
 verify(not link.authorized_header("X-Link-Key: secrex\r\n") and not link.authorized_header("X-Link-Key: secret-long\r\n"), "Link rejects wrong and wrong-length secret")
 verify(link.authorized_header("x-link-key: secret\r\n"), "Link accepts matching case-insensitive header")
 verify(not link.authorized_header("X-Link-Key: secret\r\nX-Link-Key: secret\r\n"), "Duplicate secret header rejected")
 verify(not link.large_control_packet(('{"t":"from","msg":"' + "x".repeat(5000) + '"}').to_utf8_buffer()), "Oversized game message rejected before parsing")
 verify(link.large_control_packet('{"t":"restore","snapshot":{}}'.to_utf8_buffer()), "Restore envelope retains separate larger bound")
 verify(link.large_control_packet('{"t":"setup","seats":[]}'.to_utf8_buffer()) and not link.large_control_packet(('{"t":"restore",' + "x".repeat(2 * 1024 * 1024)).to_utf8_buffer()), "Setup controls retain larger bound and oversized controls are rejected")
 verify(link.loopback_bind("127.0.0.2") and not link.loopback_bind("0.0.0.0"), "Non-loopback warning recognizes the loopback address range")
 link.free()
 var nested = []
 var cursor = nested
 for i in 34:
  var child = []
  cursor.append(child)
  cursor = child
 verify(NetTransport.normalize(nested) == null, "Combined normalizer bounds depth")
 verify(NetTransport.normalize([1, 2, 3], 2) == null and NetTransport.normalize("xxxxx", 10, 4) == null, "Combined normalizer bounds nodes and bytes")
 verify(NetTransport.normalize({"n": 2.0, "x": [1.5]}).n is int, "Combined pass normalizes integral protocol numbers")
 var budget = {"nodes": 20, "bytes": 20, "ok": true}
 var clean = NetTransport._bounded_normalize({"n": [2.0, "abc"]}, budget, 0)
 verify(budget.ok and budget.nodes == 15 and budget.bytes == 16 and clean.n[0] is int, "Normalization counts each node exactly once in a single bounded pass")
 var table = load("res://scripts/ui/table.gd")
 var advertised = [{"kind": "turn", "seat": 1, "host_seat": 0, "handable": true}]
 verify(table.handable_target(advertised, 0) == 1 and table.handable_target(advertised, 1) == -1 and table.handable_target([], 0) == -1, "Only host UI exposes server-advertised handover")
 var ui = table.new()
 var session = OnlineSession.new()
 session.client = NetClient.new()
 session.client.transport = Wire.new()
 ui.online_session = session
 ui.handable_seat = 1
 ui.hand_turn_to_bot()
 verify(session.client.transport.messages == [{"t": "action", "kind": "hand_to_bot", "seat": 1}], "Table sends host handover using existing transport")
 session.client.free()
 ui.online_session = null
 session.free()
 ui.free()
 verify(table.substitute_seats("Seat 0 plays; Seat 1 waits; Seat 10", func(i): return {0: "Seat 1", 1: "Bob"}.get(i, "Seat %d" % i)) == "Seat 1 plays; Bob waits; Seat 10", "Seat names substituted once using original indices")
 for node in rooms:
  node.running = false
  node.queue_free()
 await frames()
 print("V32 server checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func collect_prompt(s, seat, result):
 result.append(await s.ask(seat, {"kind": "confirm", "text": "Test"}, []))
