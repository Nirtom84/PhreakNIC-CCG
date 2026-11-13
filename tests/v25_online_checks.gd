extends SceneTree
var checks = 0
var failures = 0
class FakeAPI extends Node:
 func request(_method, _path, _body = {}): return {"status": 200, "data": {"rooms": []}}
class Capture extends LinkServer:
 var messages = []
 func _send(message: Dictionary): messages.append(message)
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func buttons(node, title):
 var result = []
 if node is Button and node.text == title: result.append(node)
 for child in node.get_children(): result.append_array(buttons(child, title))
 return result
func has_label(node, text):
 if node is Label and text in node.text: return true
 for child in node.get_children():
  if has_label(child, text): return true
 return false
func run():
 var deck = load("res://scripts/ui/deck_builder.gd").playable()[0]
 var link = Capture.new()
 root.add_child(link)
 var config = {"t": "setup", "card_pool": "custom", "seats": [{"name": "Host", "bot": false}, {"name": "Guest", "bot": false}], "custom_deck_code": CustomDeck.encode(deck), "deck_roll": ["Deck roll (D20): Host 17, Guest 9."]}
 link._receive(config)
 verify(link.messages.any(func(m): return m.t == "setup_ok"), "valid setup acknowledged")
 verify(link.game.engine.state.card_pool == "custom", "custom game starts")
 verify(link.game.engine.state.custom_deck == CustomDeck.normalize(deck), "exact submitted deck")
 var actual_cards = {}
 for card in link.game.engine.state.center_deck + link.game.engine.state.center_row:
  if card != null: actual_cards[card.id] = actual_cards.get(card.id, 0) + 1
 verify(actual_cards == deck.cards, "Center Deck contains exact submitted copies")
 var clients = []
 for i in 2:
  var client = NetClient.new()
  root.add_child(client)
  var pair = LoopbackTransport.pair()
  link.game.attach(pair[1])
  client.connect_to(pair[0], i, link.game.tokens[i])
  for frame in 8: await process_frame
  verify(client.log_history.has(config.deck_roll[0]), "roll log reaches every client")
  verify(client.engine.state.custom_deck == CustomDeck.normalize(deck), "shared deck visible")
  clients.append(client)
 link.game._checkpoint()
 verify(link.game.last_snapshot.setup_log.has(config.deck_roll[0]), "roll log survives snapshots")
 var restored = GameServer.new()
 root.add_child(restored)
 verify(restored.restore(link.game.last_snapshot), "custom game snapshot restores")
 verify(restored.setup_log == link.game.setup_log and restored.engine.state.custom_deck == link.game.engine.state.custom_deck, "restored deck and roll metadata")
 restored.free()
 link.game.engine.state.log.clear()
 var replay = NetClient.new()
 root.add_child(replay)
 var replay_pair = LoopbackTransport.pair()
 link.game.attach(replay_pair[1])
 replay.connect_to(replay_pair[0], 0, link.game.tokens[0])
 for frame in 8: await process_frame
 verify(replay.log_history.has(config.deck_roll[0]), "reconnect retains roll after log trimming")
 clients.append(replay)
 config.custom_deck_code = "PNDK1.bad"
 link._receive(config)
 verify(link.messages.back().t == "setup_error" and not link.messages.back().reason.is_empty(), "invalid code has reason")
 var tampered = {"name": "Tampered", "cards": {"Unknown card": 60}}
 config.custom_deck_code = "PNDK1." + Marshalls.raw_to_base64(JSON.stringify(tampered).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)).replace("+", "-").replace("/", "_").replace("=", "")
 link._receive(config)
 verify(link.messages.back().t == "setup_error", "well-formed tampered deck rejected")
 var online = load("res://scripts/ui/online.gd").new()
 online.api = FakeAPI.new()
 online.add_child(online.api)
 root.add_child(online)
 online.in_lobby = true
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.credential = {"seat": 0}
 var room = {"code": "ABCD", "card_pool": "custom", "starting_life": 0, "public": true, "host_seat": 0, "started": false, "seats": [{"name": "Host", "bot": false, "difficulty": 0}, {"name": "Guest", "bot": false, "difficulty": 0}]}
 online.lobby(room)
 verify(buttons(online, "Submit deck").size() == 1 and buttons(online, "Withdraw").size() == 1, "submission controls")
 verify(buttons(online, "Start").back().disabled, "start needs submission")
 room.seats[0].deck = {"name": deck.name, "count": 60}
 online.lobby(room)
 verify(not buttons(online, "Start").back().disabled, "submission enables start")
 verify(has_label(online, str(deck.name) + " · 60 cards"), "submitted name and count visible")
 var lobby_pair = LoopbackTransport.pair()
 var sent = []
 lobby_pair[1].received.connect(func(m): sent.append(m))
 online.session.transport = lobby_pair[0]
 online.submit_deck()
 for child in online.get_children():
  if child is PopupMenu:
   child.id_pressed.emit(0)
   child.hide()
 for frame in 8: await process_frame
 verify(sent.any(func(m): return m.action == "submit_deck" and not CustomDeck.decode(m.code).is_empty()), "picker submits valid code")
 buttons(online, "Withdraw").back().pressed.emit()
 for frame in 8: await process_frame
 verify(sent.any(func(m): return m.action == "withdraw_deck"), "withdraw action")
 verify(buttons(online, "View banned cards").is_empty(), "custom bans hidden")
 load("res://scripts/ui/style.gd").compact_override = true
 root.content_scale_size = Vector2i(390, 844)
 root.size = Vector2i(390, 844)
 online.lobby(room)
 for frame in 8: await process_frame
 verify(online.content.size.x <= 390, "phone content fits")
 online.session.stopped = true
 online.free()
 for client in clients:
  client.transport.close()
  client.free()
 link.game.running = false
 link.game.engine.finish(null)
 for frame in 30:
  for id in link.game.pending.keys(): await link.game._fallback(id)
  await process_frame
 link.stop()
 link.free()
 print("v25 online checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
