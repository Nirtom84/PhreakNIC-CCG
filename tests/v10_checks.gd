extends SceneTree
var checks = 0
var failures = 0
var backups = {}
const RULE_CARDS = ["Nashville 2600", "Touch Grass", "Clarion Inn Air Conditioning", "FOTTR Greatest Hits Vol 2", "Powered On Taser Maintenance"]
class FakeAPI extends Node:
 var calls = []
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body.duplicate(true)})
  return {"status": 400, "data": {"error": "test"}}
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 run.call_deferred()
func _finalize():
 for path in backups:
  if backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
func verify(ok: bool, text: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(text)
func frames(n = 4):
 for i in n: await process_frame
func button(node, prefix):
 if node is Button and node.text.begins_with(prefix): return node
 for child in node.get_children():
  var found = button(child, prefix)
  if found != null: return found
 return null
func has_text(node, text):
 if node is Label and node.text == text: return true
 for child in node.get_children():
  if has_text(child, text): return true
 return false
func place(e, id, seat, zone):
 var c = e.state.all_cards().filter(func(x): return x.id == id)[0]
 e.gain_owner(c, e.state.players[seat])
 e.move(c, zone, "test")
 return c
func has_portrait(node, hero):
 if node is TextureRect and node.texture is AtlasTexture and node.texture.atlas.resource_path == "res://assets/cards/" + hero + ".jpg": return true
 for child in node.get_children():
  if has_portrait(child, hero): return true
 return false
func strip(table): return table.body.find_child("InEffect", true, false)
func rule_checks(table, authority, server = null):
 var p = authority.state.players[0]
 authority.state.active_seat = 0
 authority.busy = false
 p.hacking = 6
 var permanent = place(authority, "Filler", 0, p.hand)
 var cards = []
 for id in RULE_CARDS: cards.append(place(authority, id, 1, authority.state.players[1].play_area))
 if server != null: server.dirty = true
 else: table.redraw()
 await frames()
 verify(is_instance_valid(strip(table)), "IN EFFECT strip appears, mirror=" + str(server != null))
 for id in RULE_CARDS:
  var chip = button(strip(table), authority.db().get_card(id).name)
  verify(chip != null and chip.text.contains(authority.db().get_card(id).table_rule) and chip.text.contains(table.seat_name(1)), "Chip rule and controller: " + id)
  chip.pressed.emit()
  await frames()
  verify(is_instance_valid(table.inspect_overlay) and has_text(table.inspect_overlay, authority.db().get_card(id).name), "Chip opens card sheet: " + id)
  table.close_inspect()
 var saved_flags = p.turn_flags.duplicate()
 p.turn_flags.reserved = true
 var saved_hand = p.hand.duplicate()
 for c in p.hand.duplicate():
  if authority.db().get_card(c.id).kind != "Permanent": authority.move(c, p.discard, "discard")
 if server != null: server.dirty = true
 else: table.redraw()
 await frames()
 verify(not table.nothing_left(), "Opponent Nashville payment prevents auto-end")
 p.turn_flags = saved_flags
 for c in saved_hand:
  if c not in p.hand: authority.move(c, p.hand, "hand")
 if server != null: server.dirty = true
 else: table.redraw()
 await frames()
 var mirrored = table.engine.state.players[0].hand.filter(func(c): return c.uid == permanent.uid)[0]
 table.inspect_card(mirrored, true)
 verify(has_text(table.inspect_overlay, "Nashville 2600 is in play: no one can play permanents.") and button(table.inspect_overlay, "Play") == null, "Blocked hand permanent explains Nashville")
 verify(not table.engine.can_play(table.engine.state.players[0], mirrored), "Blocked hand permanent is unplayable")
 table.close_inspect()
 for dimensions in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.content_scale_size = dimensions
  root.size = dimensions
  await frames()
  var rect = Rect2(Vector2.ZERO, Vector2(dimensions))
  verify(rect.encloses(strip(table).get_global_rect()), "Warning strip fits " + str(dimensions))
  var hand = table.body.find_child("Hand", true, false)
  verify(rect.encloses(hand.get_global_rect()), "Hand fits with warning strip " + str(dimensions))
  var canvas = table.body.get_child(0)
  var market_frame = canvas.get_child(2)
  var opponents_frame = canvas.get_child(0)
  var rig_frame = canvas.get_child(3)
  verify(opponents_frame.get_global_rect().end.y <= strip(table).get_global_rect().position.y and strip(table).get_global_rect().end.y <= market_frame.get_global_rect().position.y - 10 and market_frame.get_global_rect().end.y <= rig_frame.get_global_rect().position.y - 10, "Warnings and card regions do not overlap " + str(dimensions))
  var market = button(table.body, "Removed:")
  verify(rect.encloses(market.get_global_rect()), "Center Row fits with warning strip " + str(dimensions))
 var chip = button(strip(table), "Nashville 2600")
 chip.pressed.emit()
 await frames()
 var pay = button(table.inspect_overlay, "Pay 6 Hacking: remove Nashville 2600")
 verify(pay != null, "Opponent Nashville payment available through sheet")
 pay.pressed.emit()
 await frames(8)
 verify(cards[0] in authority.state.removed and p.hacking == 0, "Sheet payment removes opponent Nashville, mirror=" + str(server != null))
 verify(table.engine.permanents().all(func(c): return c.effect_id() != "Nashville 2600"), "Mirror follows removal")
 for c in cards.slice(1): authority.move(c, authority.state.removed, "removed")
 if server != null: server.dirty = true
 else: table.redraw()
 await frames()
 verify(not is_instance_valid(strip(table)), "Warning strip disappears, mirror=" + str(server != null))
func run():
 var settings = root.get_node("Sfx")
 settings.visual_effects = false
 settings.auto_end_turn = false
 root.size = Vector2i(1920,1080)
 var table = load("res://scenes/table.tscn").instantiate()
 table.auto_drive = false
 table.player_count = 4
 table.seed_value = 42
 root.add_child(table)
 await frames()
 await rule_checks(table, table.engine)
 table.queue_free()
 await frames()
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{"name": "Local", "bot": false}, {"name": "Remote", "bot": false}, {"name": "Third", "bot": false}, {"name": "Fourth", "bot": false}], "2026", 40, 42)
 await server.start()
 server.engine.state.active_seat = 0
 var session = OnlineSession.new()
 root.add_child(session)
 var pair = LoopbackTransport.pair()
 server.attach(pair[0])
 session.client.connect_to(pair[1], 0, server.tokens[0])
 await frames()
 table = load("res://scenes/table.tscn").instantiate()
 table.online_session = session
 session.reparent(table)
 root.add_child(table)
 await frames()
 await rule_checks(table, server.engine, server)
 pair[1].close()
 table.queue_free()
 server.queue_free()
 await frames()
 # Stop the driver immediately after removal, before it can play the freed permanent.
 DefconSearch.fixed_rollouts = 1
 for difficulty in [0, 1, 2, 3]:
  var e = GameEngine.new()
  root.add_child(e)
  e.setup([difficulty, difficulty], 42)
  var p = e.state.players[0]
  e.state.active_seat = 0
  p.difficulty = difficulty
  p.hacking = 6
  p.turn_flags.no_buy = true
  p.hand.clear()
  place(e, "Filler", 0, p.hand)
  var nashville = place(e, "Nashville 2600", 1, e.state.players[1].play_area)
  for c in e.state.center_row.duplicate():
   if c != null: e.move(c, e.state.removed, "removed")
  var driver = BotPlayer.new(e)
  driver.continue_turn = func(): return nashville in e.permanents()
  await driver.take_turn(p)
  verify((nashville in e.state.removed) == (difficulty > 0), "Nashville bot policy level " + str(difficulty))
  e.queue_free()
 var api = FakeAPI.new()
 root.add_child(api)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 root.add_child(online)
 await frames()
 verify(online.handle_input.max_length == 16, "Online handle limited to 16 characters")
 online.handle_input.text = "[New Handle]"
 online.handle_input.text_changed.emit(online.handle_input.text)
 verify(settings.handle == "New Handle" and settings.hero_id == "", "Online handle uses menu validation")
 var config = ConfigFile.new()
 config.load("user://settings.cfg")
 verify(config.get_value("player", "handle") == "New Handle", "Online handle saved")
 await online.create_game()
 verify(api.calls[-1].body.name == "New Handle" and api.calls[-1].body.hero == "", "Create uses edited handle")
 online.pick_hero()
 await frames()
 var hero = "Ben the Phreak"
 var hero_button = button(online.hero_overlay, str(root.get_node("CardDB").cards[hero].name))
 verify(hero_button != null and hero_button.has_meta("inspect"), "Shared Hero picker supports long press")
 hero_button.pressed.emit()
 await frames()
 verify(settings.hero_id == hero and online.avatar_preview.get_child(0).texture != null, "Hero choice updates settings and avatar")
 config.load("user://settings.cfg")
 verify(config.get_value("player", "hero_id") == hero, "Online Hero saved")
 await online.join("ABCD")
 verify(api.calls[-1].path == "/rooms/ABCD/join" and api.calls[-1].body.hero == hero and api.calls[-1].body.name == str(root.get_node("CardDB").cards[hero].name).left(16), "Join uses selected Hero and handle")
 for dimensions in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.content_scale_size = dimensions
  root.size = dimensions
  await frames()
  var rect = Rect2(Vector2.ZERO, Vector2(dimensions))
  verify(rect.encloses(online.content.get_global_rect()) and rect.encloses(online.handle_input.get_global_rect()), "Online identity layout fits " + str(dimensions))
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.credential = {"seat": 0}
 online.in_lobby = true
 online.lobby({"code": "ABCD", "host_seat": 0, "started": false, "public": false, "card_pool": "2026", "starting_life": 40, "seats": [{"name": settings.handle.left(16), "hero": hero, "bot": false}, {"name": "Guest", "hero": "", "bot": false}]})
 await frames()
 verify(has_text(online.content, settings.handle.left(16)) and has_portrait(online.content, hero) and button(online.content, "Pick a Hero") == null, "Lobby shows joined name and locks identity controls")
 while not online.hero_picker.loading_icons.is_empty(): await process_frame
 online.queue_free()
 api.queue_free()
 await frames()
 print("v10 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
