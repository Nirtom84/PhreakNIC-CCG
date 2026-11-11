extends SceneTree
var checks = 0
var failures = 0
class FakeAPI extends Node:
 var calls = []
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body})
  return {"status": 200, "data": {"rooms": []}} if method == HTTPClient.METHOD_GET else {"status": 400, "data": {"error": "test"}}
class CaptureLink extends LinkServer:
 var sent = []
 func _send(message: Dictionary): sent.append(message)
func _initialize(): call_deferred("run")
func verify(value, text):
 checks += 1
 if not value: failures += 1; print("FAIL: ", text)
func run():
 var db = root.get_node("CardDB")
 var mog = db.catalog("2026mog")
 verify(mog.center_ids("2026mog").size() == 150, "Mog center copy count")
 verify(mog.pool_ids("2026mog").size() == 152, "Mog definition count")
 var records = JSON.parse_string(FileAccess.get_file_as_string("res://reference/mog_cards_2026.json"))
 verify(records.size() == 48, "All 48 images transcribed")
 verify(records == JSON.parse_string(FileAccess.get_file_as_string("res://data/mog_variants.json")), "Exported variant data matches audit")
 for record in records:
  var id = "Mognet" if record.original_id == "Botnet" else record.original_id
  verify(mog.get_card(id).name == record.name and FileAccess.file_exists(mog.image_path(id)), "Mog presentation: " + record.name)
  verify(mog.named(id, record.name), "Mog name lookup: " + record.name)
 verify(db.catalog("2026").get_card("Touch Grass").name == "Grass", "Printed Grass unchanged")
 verify(db.catalog("2026").get_card("Tyler Crumpton").name == "Tyler Crumpton", "Catalog isolation")
 var engine = GameEngine.new()
 root.add_child(engine)
 verify(engine.setup([1, 1], 13, [], "2026mog"), "Mog setup")
 await engine.start_turn()
 var player = engine.active()
 # Put physical copies into play through normal rules, preserving conservation.
 for id in ["Mognet", "Mognet1"]:
  var card = engine.state.all_cards().filter(func(c): return c.id == id)[0]
  engine.detach(card)
  player.hand.append(card)
  card.owner = player.seat
  card.controller = player.seat
  await engine.play_card(player, card)
 var before = player.hacking
 var net = player.play_area.filter(func(c): return c.id == "Mognet")[0]
 await engine.activate(player, net, 0)
 verify(player.hacking == before + 2, "Mognet counts Mognet copies")
 verify(not engine.activatable_abilities(player, net)[0].enabled, "Mognet once per turn")
 verify(not mog.named("Mognet", "Botnet"), "Mognet does not become Botnet")
 verify(mog.named("What is Truth", "Mognet"), "All-name card still matches")
 var restored = SaveGame.restore(SaveGame.snapshot(engine.state))
 verify(restored != null and restored.card_pool == "2026mog", "Mog save round trip")
 engine.free()
 var bot_server = GameServer.new()
 root.add_child(bot_server)
 verify(bot_server.setup([{"name": "Host", "bot": false}, {"bot": true}], "2026mog"), "Online Mog setup")
 verify(mog.get_card(bot_server.seats[1].hero).name == bot_server.seats[1].name, "Online bot identity belongs to Mog catalog")
 bot_server.free()
 var settings = root.get_node("Sfx")
 settings.visual_effects = false
 for viewport_size in [Vector2i(1920,1080), Vector2i(2400,1080), Vector2i(1920,1440)]:
  root.size = viewport_size
  var menu = load("res://scenes/menu.tscn").instantiate()
  root.add_child(menu)
  for i in 4: await process_frame
  verify(buttons_fit(menu, Rect2(Vector2.ZERO, Vector2(viewport_size))), "Menu buttons fit " + str(viewport_size))
  menu.free()
 root.size = Vector2i(1920,1080)
 settings.handle = ""
 settings.hero_id = ""
 var ui = load("res://scripts/ui/online.gd").new()
 var api = FakeAPI.new()
 ui.api = api
 ui.add_child(api)
 ui.initial_code = "ABCD"
 root.add_child(ui)
 await process_frame
 verify(ui.pending_join == "ABCD", "Invite opens join panel")
 verify(api.calls.all(func(c): return c.method == HTTPClient.METHOD_GET), "Invite does not join automatically")
 verify(ui.handle_input.is_visible_in_tree() and ui.avatar_preview.is_visible_in_tree(), "YOU panel visible")
 verify(not ui.join_button.visible and ui.join_anyway.visible, "Default identity offers only Join anyway")
 ui.select_hero("Tyler Crumpton")
 verify(ui.join_button.visible and not ui.join_anyway.visible and ui.join_button.text.begins_with("Join as "), "Hero shows the Join as button instead of Join anyway")
 ui.join_button.pressed.emit()
 await process_frame
 var posted = api.calls.filter(func(c): return c.method == HTTPClient.METHOD_POST)
 verify(posted.size() == 1 and posted[0].body.hero == "Tyler Crumpton", "Explicit Join sends chosen identity")
 ui.browser()
 settings.handle = "You"
 settings.hero_id = ""
 ui.identity_prompted = false
 ui.request_join("ABCD")
 verify(ui.pending_join == "ABCD", "Typed code prompts default identity")
 ui.queue_free()
 var link = CaptureLink.new()
 root.add_child(link)
 var server = GameServer.new()
 root.add_child(server)
 server.diagnostic.connect(link.forward_diag)
 server.diag("test forwarding")
 verify(link.sent.size() == 1 and link.sent[0].t == "diag" and "test forwarding" in link.sent[0].text, "Game diagnostic reaches link")
 for i in 130: link.forward_diag("line " + str(i))
 verify(link.sent.size() == 120 and "muted" in link.sent.back().text, "120 lines per minute with muted note")
 server.free()
 link.free()
 await process_frame
 print("V13 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
func buttons_fit(node: Node, bounds: Rect2) -> bool:
 if node is Button and node.is_visible_in_tree() and not bounds.encloses(node.get_global_rect()): return false
 for child in node.get_children():
  if not buttons_fit(child, bounds): return false
 return true
