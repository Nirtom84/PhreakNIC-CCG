extends SceneTree
var checks = 0
var failures = 0
var style
var ui_resources = []
class FakeAPI extends Node:
 var calls = []
 var rooms = []
 func request(method, path, body = {}):
  calls.append({"method": method, "path": path, "body": body})
  return {"status": 200, "data": {"rooms": rooms}} if method == HTTPClient.METHOD_GET else {"status": 400, "data": {"error": "test"}}
func texture_count(node, path: String) -> int:
 var count = int(node is TextureRect and node.texture != null and node.texture.resource_path == path)
 for child in node.get_children(): count += texture_count(child, path)
 return count
func labels(node) -> String:
 var text = node.text if node is Label else ""
 for child in node.get_children(): text += "\n" + labels(child)
 return text
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func make_game(levels = [-1, 3], life = 0):
 var game = GameEngine.new()
 root.add_child(game)
 game.setup(levels, 21121, [], "2026", life)
 return game
func state_hash(game): return JSON.stringify(SaveGame.snapshot(game.state)).sha256_text()
func buttons(node) -> Array:
 var result = []
 if node is Button: result.append(node)
 for child in node.get_children(): result.append_array(buttons(child))
 return result
func disk_roundtrip(table):
 var expected_life = table.engine.state.players[1].starting_life
 await table.engine.start_turn(0)
 verify(table.save_game(), "Write DEFCON game to disk")
 var saved = SaveGame.read()
 verify(not saved.is_empty() and SaveGame.restore(saved.game).players[1].starting_life == expected_life, "Disk roundtrip validates DEFCON seat")
 for record in saved.game.objects:
  if record.type == "player": record.data.erase("starting_life")
 for seat in saved.table.match_stats.seats: seat.erase("starting_life")
 var file = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
 file.store_string(JSON.stringify(saved))
 file.close()
 verify(not SaveGame.read().is_empty(), "Read legacy disk save without seat baselines")
 SaveGame.remove()

func table_checks(compact: bool, count: int):
 style.compact_override = compact
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = count
 table.difficulty = 3
 table.seed_value = 2121
 table.auto_drive = false
 table.scripted_decider = Decider.new()
 root.add_child(table)
 await process_frame
 verify(table.avatar_hero(1) == "@defcon" and table.avatar_hero(0) != "@defcon", "Table seat avatar routing")
 verify("DEFCON" in table.player_name(table.engine.state.players[1]), "Turn label difficulty")
 await table.engine.start_turn(1)
 verify("DEFCON is hacking" in table.banner.text and table.turn_avatar.get_child(0).texture.resource_path == style.DEFCON_IMAGE, "Turn banner text and avatar")
 verify(table.share_details(table.engine.state.players[1]).difficulty == "DEFCON", "Share difficulty text")
 for size in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
  root.size = size
  for frame in 3: await process_frame
  verify(table.body.get_global_rect().end.x <= size.x + 1 and table.body.get_global_rect().end.y <= size.y + 1, "Table fits desktop")
 var share = load("res://scripts/ui/result_share.gd")
 verify("on DEFCON" in share.copy_text(table.share_details(table.engine.state.players[0])), "Result copy text uses DEFCON")
 var card_view = share.build_card(table.share_details(table.engine.state.players[0]))
 verify(texture_count(card_view, style.DEFCON_IMAGE) == 0, "Share image keeps human avatar")
 card_view.free()
 if compact:
  var rows = buttons(table).filter(func(button): return "♥" in button.text and "Hand" in button.text and "Deck" in button.text)
  verify(rows.size() == count - 1 and rows.all(func(button): return "DEFCON" in button.text and button.icon != null and button.icon.resource_path == style.DEFCON_IMAGE), "Every compact opponent row uses avatar and difficulty")
 else:
  verify(texture_count(table.body, style.DEFCON_IMAGE) == count - 1, "Every desktop opponent uses DEFCON avatar")
  await disk_roundtrip(table)
 table.show_result(table.engine.state.players[1])
 for frame in 3: await process_frame
 var summary = table.get_node("MatchSummary")
 verify("DEFCON" in labels(summary) and texture_count(summary, style.DEFCON_IMAGE) == 1, "Summary winner name and avatar")
 table.free()
 for frame in 3: await process_frame

func run():
 await preload("res://tests/defcon_policy_checks.gd").new().run(self)
 root.get_node("Sfx").visual_effects = false
 # Keep shared UI resources alive across repeated headless scene construction.
 for path in ["toggle_on.svg", "toggle_off.svg", "slider_grip.svg"]: ui_resources.append(load("res://assets/ui/" + path))
 style = load("res://scripts/ui/style.gd")
 for path in [style.BACK, style.DEFCON_IMAGE, "res://assets/icon/icon.png", "res://assets/shaders/network.gdshader", "res://assets/fonts/JetBrainsMonoNerdFontMono-Regular.ttf", "res://assets/fonts/NotoSansMono-CondensedBlack.ttf"]: ui_resources.append(load(path))
 for id in style.heroes(): ui_resources.append(load(root.get_node("CardDB").image_path(id)))
 DefconSearch.fixed_rollouts = 1
 for levels in [[-1, 3], [-1, 3, 2], [-1, 3, 2, 3]]:
  for life in [0, 20, 30, 40]:
   var game = make_game(levels, life)
   var base = life if life else (24 if levels.size() == 2 else 10 * levels.size())
   verify(game.state.starting_life == base, "Global base life")
   for p in game.state.players:
    verify(p.life == base * (2 if p.difficulty == 3 else 1) and p.starting_life == p.life, "Per-seat life")
   await game.start_turn(0)
   var restored = SaveGame.restore(SaveGame.snapshot(game.state))
   verify(restored != null and restored.players.map(func(p): return p.starting_life) == game.state.players.map(func(p): return p.starting_life), "Save roundtrip")
   var view = NetView.apply(NetView.build(game, 0))
   verify(view.players[1].starting_life == base * 2, "Network per-seat life")
   var old = SaveGame.snapshot(game.state)
   for record in old.objects:
    if record.type == "player": record.data.erase("starting_life")
   verify(SaveGame.restore(old).players.all(func(p): return p.starting_life == base), "Legacy save base life")
   var invalid = SaveGame.snapshot(game.state)
   for record in invalid.objects:
    if record.type == "player": record.data.starting_life = -1
   verify(SaveGame.restore(invalid) == null, "Reject malformed seat life")
   game.free()
 var game = make_game()
 await game.start_turn(1)
 var p = game.active()
 var stats = load("res://scripts/ui/match_stats.gd").new()
 stats.setup(2, "2026", [-1, 3])
 stats.capture_start(game.state.players)
 verify(stats.seats[1].starting_life == p.starting_life, "Match stats remember seat baseline")
 var invalid_stats = stats.to_dict()
 invalid_stats.seats[1].starting_life = 20001
 verify(stats.from_dict(invalid_stats) == null, "Reject impossible stats baseline")
 game.damage_resolved.connect(func(_source, target, amount, _dealing): stats.damage(-1, target.seat, amount))
 game.life_gained.connect(func(target, amount): stats.gain(target.seat, amount))
 await game.deal(game.state.players[0], 3)
 for q in game.state.players:
  verify(stats.seats[q.seat].damage_taken == q.starting_life + stats.seats[q.seat].life_gained - q.life, "Stats reconcile per seat")
 verify(JSON.stringify(SaveGame.snapshot(SaveGame.clone_memory(game.state))) == JSON.stringify(SaveGame.snapshot(game.state)), "Memory clone matches save snapshot")
 var before = state_hash(game)
 var rng_state = game.state.rng.state
 var nodes = root.get_child_count()
 for i in 20:
  var sandbox = DefconSearch.sandbox(game, p.seat, 123)
  verify(sandbox.state.conservation_ok(), "Sandbox conservation")
  DefconSearch.dispose(sandbox)
 verify(root.get_child_count() == nodes, "No sandbox nodes leaked")
 var card = p.hand[0]
 card.flags.self_reference = card
 var warm = DefconSearch.sandbox(game, p.seat, 124)
 DefconSearch.dispose(warm)
 var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
 for i in 20:
  var sandbox = DefconSearch.sandbox(game, p.seat, 125)
  DefconSearch.dispose(sandbox)
 verify(Performance.get_monitor(Performance.OBJECT_COUNT) == object_count, "Sandbox loop frees object-valued flag cycles")
 card.flags.erase("self_reference")
 verify(before == state_hash(game) and rng_state == game.state.rng.state, "Sandbox leaves state and RNG untouched")
 p.hacking = 5
 var buys = (game.state.center_row + p.reserve).filter(func(c): return c != null and game.can_buy(p, c))
 buys.sort_custom(func(a, b): return game.dec(p).value(a, p) > game.dec(p).value(b, p))
 var fallback = {"kind": "stop", "uid": -1}
 before = state_hash(game)
 var first = await DefconSearch.new(game).choose_purchase(p, buys, fallback)
 var second = await DefconSearch.new(game).choose_purchase(p, buys, fallback)
 verify(first == second, "Count mode repeatability")
 verify(before == state_hash(game), "Search leaves real state and RNG untouched")
 var control_rng = RandomNumberGenerator.new()
 control_rng.seed = game.state.rng.seed
 control_rng.state = game.state.rng.state
 var saved_rng = game.state.rng.state
 for i in 8: verify(game.state.rng.randi() == control_rng.randi(), "Real RNG sequence remains identical")
 game.state.rng.state = saved_rng
 # Move identities between hidden hand/deck without changing sizes or ownership.
 var opponent = game.state.players[0]
 var unknown = opponent.hand + opponent.deck
 unknown.reverse()
 opponent.hand = unknown.slice(0, opponent.hand.size())
 opponent.deck = unknown.slice(opponent.hand.size())
 game.state.center_deck.reverse()
 p.deck.reverse()
 var third = await DefconSearch.new(game).choose_purchase(p, buys, fallback)
 verify(first == third, "Hidden arrangements do not change count-mode decisions")
 var a = DefconSearch.sandbox(game, p.seat, 123)
 opponent.hand.reverse()
 opponent.deck.reverse()
 game.state.center_deck.reverse()
 var b = DefconSearch.sandbox(game, p.seat, 123)
 verify(a.state.players[0].hand.map(func(c): return c.uid) == b.state.players[0].hand.map(func(c): return c.uid) and a.state.center_deck.map(func(c): return c.uid) == b.state.center_deck.map(func(c): return c.uid), "Canonical determinization")
 DefconSearch.dispose(a); DefconSearch.dispose(b)
 DefconSearch.force_error = true
 verify(await DefconSearch.new(game).choose_purchase(p, buys, fallback) == fallback, "Forced failure uses Elite fallback")
 DefconSearch.force_error = false
 DefconSearch.fixed_rollouts = -1
 var search = DefconSearch.new(game)
 search.budget_ms = 50
 var started = Time.get_ticks_msec()
 await search.choose_purchase(p, buys, fallback)
 verify(Time.get_ticks_msec() - started < 1200, "Time budget bounded with generous scheduling allowance")
 verify(search.rollouts == 0, "Live rollout search disabled; bounded lethal remains")
 # A candidate or exact-lethal branch may trigger TOCTOU before rollout starts.
 # Its reaction driver must obey the same expired deadline.
 var reaction = DefconSearch.sandbox(game, p.seat, 7121)
 var gate = DefconSearch.new(game)
 gate.deadline = Time.get_ticks_msec() - 1
 gate.install_policy(reaction)
 var victim = reaction.state.players[0]
 var rescue = reaction.state.all_cards().filter(func(c): return c.id == "TOCTOU")[0]
 reaction.gain_owner(rescue, victim)
 reaction.move(rescue, victim.hand, "hand")
 victim.life = 1
 var actor = reaction.active()
 var attack = (actor.hand + actor.deck + actor.discard).filter(func(c): return c.id == "Damage")[0]
 reaction.move(attack, actor.hand, "hand")
 await reaction.play_card(actor, attack)
 verify(rescue in reaction.state.removed and victim.played.is_empty(), "Candidate reaction policy obeys expired deadline")
 verify(reaction.state.conservation_ok(), "Interrupted reaction conserves cards")
 DefconSearch.dispose(reaction)
 DefconSearch.fixed_rollouts = 1
 game.free()
 for bot in [false, true]:
  for level in [-1, 0, 1, 2, 3]:
   var id = style.seat_avatar("nirtom", "Bitwize", bot, level)
   verify((id == "@defcon") == (bot and level == 3), "DEFCON override before handle matching; humans excluded")
 var avatar = style.avatar("@defcon", 72)
 verify(avatar.get_child(0).texture.resource_path == style.DEFCON_IMAGE, "DEFCON texture")
 avatar.free()
 var sfx = root.get_node("Sfx")
 sfx.difficulty = 3
 sfx.save()
 sfx.difficulty = 0
 sfx._ready()
 verify(sfx.difficulty == 3, "Persist DEFCON setting")
 for compact in [false, true]:
  style.compact_override = compact
  for size in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1920, 1440)]:
   root.size = size
   var menu = load("res://scenes/menu.tscn").instantiate()
   root.add_child(menu)
   for frame in 4: await process_frame
   var tiles = buttons(menu).filter(func(c): return "●" in c.text)
   verify(tiles.size() == 4 and menu.difficulty.selected == 3, "Menu four cards and selected DEFCON")
   for tile in tiles:
    verify(Rect2(Vector2.ZERO, Vector2(size)).encloses(tile.get_global_rect()), "Difficulty tile fits viewport")
    if compact: verify(tile.size.y >= 72 and tile.get_theme_font_size("font_size") >= 22, "Compact tile target/text")
   menu.free()
 for compact in [false, true]:
  for count in [2, 3, 4]: await table_checks(compact, count)
 style.compact_override = false
 var api = FakeAPI.new()
 root.add_child(api)
 var online = load("res://scripts/ui/online.gd").new()
 online.api = api
 online.default_difficulty = 3
 root.add_child(online)
 for frame in 3: await process_frame
 verify(online.seat_types[0].item_count == 5 and online.seat_types[0].selected == 4, "Online creation lists DEFCON")
 await online.create_game()
 verify(api.calls[-1].body.seats[1] == {"bot": true, "difficulty": 3}, "Online create sends DEFCON seat")
 api.rooms = [{"code": "ABCD", "host": "Host", "card_pool": "2026", "starting_life": 30, "open_seats": 1, "banned_count": 0, "seats": [{"name": "nirtom", "hero": "nirtom", "bot": false, "difficulty": 3}, {"name": "Bot", "hero": "nirtom", "bot": true, "difficulty": 3}]}]
 await online.refresh_rooms()
 for frame in 3: await process_frame
 verify("DEFCON" in labels(online) and texture_count(online, style.DEFCON_IMAGE) == 0, "Browser lists DEFCON and keeps human host avatar")
 online.session = OnlineSession.new()
 online.add_child(online.session)
 online.session.credential = {"seat": 0}
 var room = {"code": "ABCD", "host_seat": 0, "card_pool": "2026", "starting_life": 30, "started": false, "public": true, "seats": [{"name": "nirtom", "hero": "nirtom", "bot": false, "difficulty": 3}, {"name": "nirtom", "hero": "nirtom", "bot": true, "difficulty": 3}]}
 online.lobby(room)
 for frame in 3: await process_frame
 verify("Bot · DEFCON" in labels(online), "Lobby DEFCON label")
 verify(texture_count(online, style.DEFCON_IMAGE) == 1, "Lobby bot avatar overrides handle, human keeps Hero")
 online.free()
 api.free()
 var server = GameServer.new()
 root.add_child(server)
 verify(server.setup([{"bot": false}, {"bot": true, "difficulty": 3}], "2026", 30, 2121), "Create server DEFCON room")
 verify(server.engine.state.players[1].life == 60 and server.engine.state.players[0].life == 30, "Server handicap")
 verify(server.seats[1].difficulty == 3, "Server keeps difficulty")
 verify(server.seats[1].name != "Bot" and not server.seats[1].hero.is_empty(), "Server keeps random Hero identity")
 await server.engine.start_turn(1)
 await server._drive()
 verify(server.engine.state.turn >= 2 and server.driving.is_empty() and server.engine.state.conservation_ok(), "Server drives DEFCON turn and releases room")
 var human_life = server.engine.state.players[0].life
 # Drive the real takeover branch with game driving suppressed at game over.
 server.engine.state.finished = true
 server.running = true
 server.permanent_idle[0] = true
 server._process(0)
 verify(server.engine.state.players[0].difficulty == 1 and server.engine.deciders[0].difficulty == 1, "Human takeover remains Phreak")
 verify(server.engine.state.players[0].starting_life == 30 and server.engine.state.players[0].life == human_life, "Human takeover receives no life bonus")
 server.free()
 var lifetime = load("res://scripts/ui/lifetime_stats.gd").new()
 stats.finish(0, [PlayerState.new(0), PlayerState.new(1)])
 verify(lifetime.record(stats, 0, "", "local", "v21"), "Record DEFCON lifetime")
 verify(lifetime.data.difficulties.has("3"), "Lifetime DEFCON bucket")
 lifetime.save()
 verify(load("res://scripts/ui/lifetime_stats.gd").new().data.difficulties.has("3"), "Lifetime accepts persisted level 3")
 for frame in 10: await process_frame
 print("v21 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
