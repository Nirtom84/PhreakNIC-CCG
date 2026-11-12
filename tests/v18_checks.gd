extends SceneTree
var checks = 0
var failures = 0
class RoomAPI extends Node:
 var rooms = []
 func request(_method, _path, _body = {}): return {"status": 200, "data": {"rooms": rooms}}
class ClientSpy extends NetClient:
 var sent = []
 func send_action(kind: String, uid = null, index = null):
  can_act = false
  sent.append({"kind": kind, "uid": uid, "index": index})
var settings
var table
func _initialize(): run.call_deferred()
func verify(value, text):
 checks += 1
 if not value: failures += 1; print("FAIL: ", text)
func frames(n = 4):
 for i in n: await process_frame
func autos(node) -> Array:
 var found = []
 if node is Button and node.name == "AutoActivate": found.append(node)
 for child in node.get_children(): found.append_array(autos(child))
 return found
func has_picture(node, path: String) -> bool:
 if node is TextureRect and node.texture != null:
  var texture = node.texture.atlas if node.texture is AtlasTexture else node.texture
  if texture.resource_path == path: return true
 for child in node.get_children():
  if has_picture(child, path): return true
 return false
func card(id, uid, owner = 0): return CardInstance.new(uid, id, owner)
func run():
 settings = root.get_node("Sfx")
 var cfg = ConfigFile.new()
 settings.load_auto(cfg)
 verify(settings.auto_activate.values().all(func(v): return v == false), "Defaults off")
 cfg.set_value("game", "auto_botnet", true)
 settings.load_auto(cfg)
 verify(settings.auto_activate.values().all(func(v): return v == true), "Legacy migrates all groups")
 cfg.set_value("auto_activate", "Botnet", "bad")
 settings.load_auto(cfg)
 verify(not settings.auto_enabled("Botnet"), "Validate bool")
 settings.auto_activate.clear()
 settings.auto_end_turn = false
 table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 root.add_child(table)
 await frames()
 var p = table.engine.state.players[0]
 table.engine.state.active_seat = 0
 p.hand.clear()
 p.play_area.clear()
 var b = card("Botnet", 91001)
 var b2 = card("Botnet1", 91002)
 p.play_area.append_array([b, b2])
 var widget = table.card_widget(b, "permanent", 100)
 verify(autos(widget).size() == 1, "Own eligible toggle")
 autos(widget)[0].pressed.emit()
 verify(settings.auto_enabled("Botnet") and not settings.auto_enabled("Mognet") and not settings.auto_enabled("Tableskirts"), "Group isolated")
 widget.free()
 widget = table.card_widget(b2, "permanent", 100)
 verify(autos(widget)[0].button_pressed, "Copies share group")
 widget.free()
 for zone in ["hand", "opponent", "market"]:
  widget = table.card_widget(b, zone, 100)
  verify(autos(widget).is_empty(), "No toggle " + zone)
  widget.free()
 var other = card("Botnet", 91003, 1)
 widget = table.card_widget(other, "permanent", 100)
 verify(autos(widget).is_empty(), "Opponent excluded")
 widget.free()
 var saved = ConfigFile.new()
 saved.load("user://settings.cfg")
 settings.load_auto(saved)
 verify(settings.auto_enabled("Botnet") and not saved.has_section_key("game", "auto_botnet"), "Settings round trip removes legacy")
 var third = card("Botnet2", 91004)
 p.hand.append(third)
 p.hacking = 100
 verify(table.engine.can_play(p, third), "Third playable")
 verify(not await table.auto_step(), "Hold while playable copy in hand")
 p.hacking = 0
 await table.engine.play_card(p, third)
 while await table.auto_step(): pass
 verify(p.hacking == 9, "Three Botnets yield exactly nine")
 verify(not await table.auto_step(), "Once per turn")
 settings.auto_activate.clear()
 settings.auto_activate.Tableskirts = true
 var skirt = card("Tableskirts", 91005)
 p.play_area.append(skirt)
 var before = p.hacking
 await table.auto_step()
 verify(p.hacking == before + 1, "Tableskirts gains hacking")
 await table.auto_step()
 verify(p.hacking == before + 1, "Tableskirts once")
 table.engine.state.turn += 1
 skirt.flags.used = false
 table.pending = true
 verify(not await table.auto_step(), "Pending blocks")
 table.pending = false
 table.tutorial_mode = true
 verify(not await table.auto_step(), "Tutorial blocks")
 table.tutorial_mode = false
 table.engine.state.finished = true
 verify(not await table.auto_step(), "Finished blocks")
 table.engine.state.finished = false
 settings.auto_activate.clear()
 table.auto_tip_shown = false
 table.auto_notice()
 verify(table.notice_text.begins_with("Tip: tap Auto on Botnet"), "Discoverable tip")
 table.notice_text = "sentinel"
 table.auto_notice()
 verify(table.notice_text == "sentinel", "Tip once")
 var style = load("res://scripts/ui/style.gd")
 style.compact_override = true
 widget = table.card_widget(b, "permanent", 100)
 verify(autos(widget)[0].custom_minimum_size.y >= 72, "Compact target")
 widget.free()
 style.compact_override = null
 verify(style.avatar_id("Botnet", "Elonka") == root.get_node("CardDB").card_id_for_name("Botnet"), "Handle wins avatar")
 verify(style.avatar_id("unknown handle", "Elonka") == "Elonka", "Hero fallback")
 var mog_book = root.get_node("CardDB").catalog("2026mog")
 verify(style.avatar_id("Mognet", "Elonka", mog_book) == mog_book.card_id_for_name("Mognet"), "Pool catalog respected")
 # Primary Shell Speech is safe; its remove ability must remain untouched.
 settings.auto_activate = {"Shell Speech": true}
 var shell = card("Shell Speech", 91006)
 p.play_area.append(shell)
 var hand_count = p.hand.size()
 await table.auto_step()
 verify(p.hand.size() == hand_count + 1 and shell in p.play_area, "Shell primary draws without removing")
 await table.auto_step()
 verify(shell in p.play_area, "Shell secondary never automatic")
 settings.auto_activate = {"Tableskirts": true}
 skirt.flags.used = false
 table.engine.state.turn += 1
 table.engine.state.active_seat = 1
 verify(not await table.auto_step(), "Opponent turn blocked")
 widget = table.card_widget(skirt, "permanent", 100)
 verify(not autos(widget)[0].disabled, "Toggle usable on opponent turn")
 widget.free()
 table.engine.state.active_seat = 0
 p.play_area.assign([skirt])
 table.redraw()
 await frames()
 verify(skirt.flags.get("used", false), "Redraw hook activates automatically")
 table.engine.state.turn += 1
 skirt.flags.used = false
 var next_before = p.hacking
 table.redraw()
 await frames()
 verify(p.hacking == next_before + 1, "Next turn hook runs once")
 settings.auto_activate.clear()
 widget = table.card_widget(card("Hacking", 91007), "permanent", 100)
 verify(autos(widget).is_empty(), "Ineligible permanent excluded")
 widget.free()
 var db = root.get_node("CardDB")
 var hero = style.heroes()[0]
 var original_name = db.cards.Botnet.name
 db.cards.Botnet.name = db.cards[hero].name
 verify(db.card_id_for_name(db.cards[hero].name) == hero, "Hero subtype wins name tie")
 db.cards.Botnet.name = original_name
 var share = load("res://scripts/ui/result_share.gd")
 var details = table.share_details(p)
 details.handle = "Botnet"
 details.hero = hero
 var result = share.build_card(details)
 verify(has_picture(result, db.image_path(db.card_id_for_name("Botnet"))), "Result tree uses named card")
 result.free()
 var stats = load("res://scripts/ui/lifetime_stats.gd").new().share_details("Botnet")
 stats.hero = hero
 result = share.build_card(stats)
 verify(has_picture(result, db.image_path(db.card_id_for_name("Botnet"))), "Stats tree uses named card")
 result.free()
 # A scripted online client acknowledges each send with the next view.
 var session = OnlineSession.new()
 session.client.free()
 session.client = ClientSpy.new()
 session.add_child(session.client)
 table.add_child(session)
 table.online_session = session
 session.client.seats.assign([{"bot": false}, {"bot": true}])
 session.client.can_act = true
 settings.auto_activate = {"Botnet": true, "Tableskirts": true}
 p.hand.clear()
 p.play_area.assign([b, b2, skirt])
 for c in p.play_area: c.flags.used = false
 table.engine.state.turn += 1
 table.auto_step()
 verify(session.client.sent.size() == 1 and table.auto_inflight, "Online first send only")
 session.client.can_act = true
 table.auto_step()
 verify(session.client.sent.size() == 1, "No send before confirming view")
 for expected in [2, 3]:
  table.auto_view_received.emit()
  await frames()
  verify(session.client.sent.size() == expected, "Next view sends one " + str(expected))
  session.client.can_act = true
 table.auto_view_received.emit()
 await frames()
 verify(session.client.sent.size() == 3 and not table.auto_inflight, "All acknowledged")
 for i in 3:
  table.auto_view_received.emit()
  table.redraw()
  await frames()
 verify(session.client.sent.size() == 3, "Repeated views never resend same turn")
 verify(session.client.sent.all(func(a): return a.kind == "activate" and a.index == 0), "Only primary ability sent")
 table.engine.state.turn += 1
 table.auto_step()
 verify(session.client.sent.size() == 4, "New turn clears guard")
 table.auto_view_received.emit()
 table.online_session = null
 settings.auto_activate.clear()
 await frames()
 # End Turn must flush a held Botnet before asking about remaining Hacking.
 table.engine.state.turn += 1
 table.auto_sent.clear()
 for c in p.play_area: c.flags.used = false
 p.play_area.assign([b])
 p.hand.assign([third])
 p.hacking = 0
 settings.auto_activate.Botnet = true
 settings.confirm_end_turn = true
 table.end_human_turn()
 await frames()
 verify(table.pending and p.hacking == 1, "Held activation precedes confirm")
 verify(not table.nothing_left(), "Unfired or pending ability blocks auto end")
 table.answered.emit(1)
 await frames()
 settings.auto_activate.clear()
 table.free()
 settings.auto_activate.clear()
 await online_views()
 await lobby_avatars()
 settings.auto_activate.clear()
 settings.save()
 print("v18 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)

func online_views():
 var authority = GameEngine.new()
 root.add_child(authority)
 authority.setup([0, 0], 41)
 await authority.start_turn()
 authority.state.active_seat = 0
 var p = authority.state.players[0]
 p.hand.clear()
 p.play_area.assign([card("Botnet", 92001), card("Botnet1", 92002), card("Tableskirts", 92003)])
 var session = OnlineSession.new()
 root.add_child(session)
 var pair = LoopbackTransport.pair(false)
 session.client.bind_transport(pair[0])
 pair[1].send({"t": "welcome", "seat": 0, "seats": [{"name": "Botnet", "hero": "", "bot": false}, {"name": "Guest", "hero": "", "bot": false}]})
 pair[1].send({"t": "view", "state": NetView.build(authority, 0)})
 pair[0].pump()
 settings.auto_activate = {"Botnet": true, "Tableskirts": true}
 var screen = load("res://scenes/table.tscn").instantiate()
 screen.auto_drive = false
 screen.online_session = session
 root.add_child(screen)
 var sent_uids = []
 for turn in 2:
  if turn == 1:
   authority.state.turn += 1
   for c in p.play_area: c.flags.used = false
   pair[1].send({"t": "view", "state": NetView.build(authority, 0)})
   pair[0].pump()
  for expected in 3:
   await frames()
   verify(pair[1].queue.size() == 1, "Real session one queued activate")
   var action = pair[1].queue.pop_front()
   verify(action.kind == "activate" and action.index == 0 and action.uid not in sent_uids, "Real session unique primary ability")
   sent_uids.append(action.uid)
   screen.redraw()
   await frames()
   verify(pair[1].queue.is_empty(), "Real session waits for view")
   var c = p.play_area.filter(func(c): return c.uid == action.uid)[0]
   await authority.activate(p, c, 0)
   pair[1].send({"t": "view", "state": NetView.build(authority, 0)})
   pair[0].pump()
  for repeat in 3:
   pair[1].send({"t": "view", "state": NetView.build(authority, 0)})
   pair[0].pump()
   await frames()
  verify(pair[1].queue.is_empty(), "Real repeated views send no duplicates")
  sent_uids.clear()
 screen.free()
 session.free()
 pair[0].close()
 authority.free()

func lobby_avatars():
 var api = RoomAPI.new()
 root.add_child(api)
 var seat = {"name": "Botnet", "hero": "Elonka", "bot": false, "difficulty": 0, "connected": true}
 api.rooms = [{"code": "TEST", "host": "Botnet", "seats": [seat], "card_pool": "2026", "starting_life": 20, "open_seats": 0}]
 var screen = load("res://scripts/ui/online.gd").new()
 screen.api = api
 root.add_child(screen)
 await screen.refresh_rooms()
 await frames()
 var path = root.get_node("CardDB").image_path(root.get_node("CardDB").card_id_for_name("Botnet"))
 verify(has_picture(screen.rooms_box, path), "Room browser tree uses handle avatar")
 var session = OnlineSession.new()
 screen.add_child(session)
 screen.session = session
 session.credential = {"seat": 1}
 screen.lobby({"code": "TEST", "host_seat": 0, "seats": [seat, {"name": "Guest", "hero": "", "bot": false, "difficulty": 0}], "card_pool": "2026", "starting_life": 20, "public": true, "started": false})
 await frames()
 verify(has_picture(screen.content, path), "Lobby list tree uses handle avatar")
 screen.free()
 api.free()
