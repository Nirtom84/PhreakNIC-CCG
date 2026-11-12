extends SceneTree
class TrackingEngine extends GameEngine:
 var after_reserve_attempts = 0
 func buy_card(p, card, mandatory: bool = false) -> bool:
  if p.turn_flags.get("reserved", false): after_reserve_attempts += 1
  return await super.buy_card(p, card, mandatory)
 func acquire(p, card, destination = null) -> bool:
  if p.turn_flags.get("reserved", false): after_reserve_attempts += 1
  return super.acquire(p, card, destination)
var failures = 0
var checks = 0
func _initialize(): call_deferred("run")
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  print("FAIL: ", message)
func spend_fixture(old: bool) -> int:
 var e = GameEngine.new()
 root.add_child(e)
 e.setup([2, 2], 8765)
 await e.start_turn(0)
 var p = e.active()
 for c in p.hand.duplicate(): e.discard(c)
 for c in p.deck.duplicate(): e.discard(c)
 var show = e.state.center_deck.filter(func(c): return c.id == "Non-Infringing Game Show")[0]
 e.gain_owner(show, p)
 e.move(show, p.hand, "hand")
 for c in p.discard.duplicate():
  if c.id == "Hacking": e.move(c, p.hand, "hand")
 var q = e.state.players[1]
 q.life = 20
 if old:
  e.deciders[0] = preload("res://scripts/ai/baseline/bot_decider.gd").new(e, 2)
  await preload("res://scripts/ai/baseline/bot_player.gd").new(e).take_turn(p)
 else:
  await BotPlayer.new(e).take_turn(p)
 var dealt = 20 - q.life
 e.free()
 return dealt
func run():
 await preload("res://tests/defcon_policy_checks.gd").new().run(self)
 await preload("res://tests/defcon_policy_checks.gd").new().legacy_traces(self)
 await defcon_checks()
 await reserve_checks()
 var old_damage = await spend_fixture(true)
 var new_damage = await spend_fixture(false)
 print("Game Show fixture damage: baseline=%d new=%d" % [old_damage, new_damage])
 verify(new_damage == 3 and new_damage > old_damage, "Generate resources before Game Show spends them")
 var e = GameEngine.new()
 root.add_child(e)
 e.setup([2, 2], 8765)
 await e.start_turn(0)
 var p = e.active()
 var q = e.state.players[1]
 for c in p.hand.duplicate(): e.discard(c)
 for c in p.deck.duplicate(): e.discard(c)
 for c in p.discard.duplicate():
  if c.id == "Hacking": e.move(c, p.hand, "hand")
 var jenny = e.state.center_deck.filter(func(c): return c.id == "Jenny")[0]
 e.gain_owner(jenny, p)
 e.move(jenny, p.hand, "hand")
 q.life = 20
 await BotPlayer.new(e).take_turn(p)
 verify(q.life == 12, "Jenny spends eight Hacking generated before her play")
 verify(e.state.conservation_ok(), "Ordered turn conserves cards")
 var own = e.state.center_deck.filter(func(c): return c.id == "The Book")[0]
 var enemy = e.state.center_deck.filter(func(c): return c.id == "Botnet")[0]
 e.gain_owner(own, p)
 e.move(own, p.play_area, "play_area")
 e.gain_owner(enemy, q)
 e.move(enemy, q.play_area, "play_area")
 var selected = await e.dec(p).choose_cards(p, "Take control of permanent", [own, enemy], 1, 1)
 verify(selected == [enemy], "Steal an enemy permanent instead of selecting our more valuable Book")
 var baseline = preload("res://scripts/ai/baseline/bot_decider.gd").new(e, 2)
 var old_selection = await baseline.choose_cards(p, "Take control of permanent", [own, enemy], 1, 1)
 verify(old_selection == [own], "Frozen policy reproduces wasted theft on its own Book")
 var basics = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Hacking")
 selected = await e.dec(p).choose_cards(p, "Remove cards from game", basics, 0, basics.size())
 verify(selected.size() == 2, "Optional thinning keeps six total Hacking before replacement economy exists")
 var attacks = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Damage")
 selected = await e.dec(p).choose_cards(p, "Remove cards from game", attacks, 0, attacks.size())
 verify(selected.is_empty(), "Keep starter attacks until replacement offense exists")
 var stamp = e.state.center_deck.filter(func(c): return c.id == "Dick Van Dyke Stamp")[0]
 e.gain_owner(stamp, p)
 e.move(stamp, p.play_area, "play_area")
 var hacker = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Hacking")[0]
 selected = await e.dec(p).choose_cards(p, "Remove cards from game", [hacker], 0, 1)
 verify(selected.is_empty(), "Keep Hackers that power Dick Van Dyke Stamp")
 e.free()
 print("Bot checks: %d; failures: %d" % [checks, failures])
 quit(1 if failures else 0)

func reserve_fixture(level: int = 2, seed_value: int = 123):
 var e = TrackingEngine.new()
 root.add_child(e)
 e.setup([level, 2], seed_value)
 await e.start_turn(0)
 var p = e.active()
 for c in p.hand.duplicate(): e.discard(c)
 for c in e.state.center_row.duplicate():
  if c != null: e.state.center_deck.append(c)
 e.state.center_row.clear()
 p.hacking = 2
 return e
func row_card(e, id: String):
 var c = e.state.all_cards().filter(func(x): return x.id == id)[0]
 e.move(c, e.state.center_row, "center_row")
 return c
func reserve_checks():
 var e = await reserve_fixture()
 var p = e.active()
 var bot = BotPlayer.new(e)
 var target = row_card(e, "Payphone")
 # Payphone is reachable with the starter economy; Camel is a mediocre buy.
 var budget = bot.estimate_hacking(p) + 2
 verify(e.effective_cost(p, target) <= budget, "Save-up fixture target is reachable")
 var mediocre = row_card(e, "Two Hump Camel")
 p.hacking = e.effective_cost(p, mediocre)
 verify(bot.reserve_target(p, [mediocre]) == target, "Elite saves for high value instead of mediocre buy")
 p.hacking = e.effective_cost(p, target)
 verify(bot.reserve_target(p, [target]) == null, "Elite keeps a good affordable buy")
 p.hacking = e.effective_cost(p, mediocre)
 var damage = (p.deck + p.discard).filter(func(c): return c.id == "Damage")[0]
 e.move(damage, p.hand, "hand")
 e.state.players[1].life = 1
 verify(bot.reserve_target(p, []) == null, "Elite never reserves with lethal in hand")
 e.discard(damage)
 e.state.players[1].life = 3
 verify(bot.reserve_target(p, [mediocre]) == null, "Elite keeps near-lethal tempo")
 e.state.players[1].life = 20
 p.life = 8
 verify(bot.reserve_target(p, [mediocre]) == null, "Elite keeps tempo when behind on life")
 p.life = 20
 var events = {"reserved": 0, "bought_after": 0}
 e.card_reserved.connect(func(_p, _c): events.reserved += 1)
 e.card_bought.connect(func(_p, _c):
  if events.reserved > 0: events.bought_after += 1)
 verify(bot.buy_priority(target, p) == e.dec(p).value(target, p), "Row cards receive no reserved buying bonus")
 var turn = e.state.turn
 await bot.take_turn(p)
 verify(events.reserved == 1 and events.bought_after == 0 and e.after_reserve_attempts == 0 and e.state.turn > turn, "Reserve ends promptly without further acquisitions")
 verify(e.state.log.any(func(line): return " reserves " in line), "Reserve emits normal log")
 verify(bot.buy_priority(target, p) == e.dec(p).value(target, p) + 2.0, "Wanted reserve receives follow-through buying preference")
 await e.start_turn(0)
 for c in p.hand.duplicate(): e.discard(c)
 p.hacking = 100
 await bot.take_turn(p)
 verify(target not in p.reserve and target.owner == p.seat, "Reserved card bought on a later affordable turn")
 e.free()
 e = await reserve_fixture()
 p = e.active()
 bot = BotPlayer.new(e)
 target = row_card(e, "Botnet")
 for c in (p.deck + p.discard).duplicate():
  if c.id == "Hacking": e.remove(c)
 var q = e.state.players[1]
 var other = row_card(e, "Botnet1")
 e.gain_owner(other, q)
 e.move(other, q.hand, "hand")
 p.hacking = 0
 verify(bot.reserve_priority(target, p) == e.dec(p).value(target, p), "Hidden opponent combo gives no denial bonus")
 e.move(other, q.play_area, "play_area")
 verify(bot.reserve_target(p, []) == target, "Elite denial uses public Botnet combo")
 for id in ["The Book", "Bribery"]:
  var held = row_card(e, id)
  e.gain_owner(held, p)
  e.move(held, p.reserve, "reserve")
 verify(bot.reserve_target(p, []) == target, "Denial may exceed Elite inventory cap")
 e.move(other, q.hand, "hand")
 verify(bot.reserve_target(p, []) == null, "Elite holds at most two wanted reserves without denial")
 e.free()
 e = await reserve_fixture(1)
 p = e.active()
 bot = BotPlayer.new(e)
 target = row_card(e, "Payphone")
 verify(bot.reserve_target(p, []) == target, "Phreak reserves reachable value when no worthwhile buy")
 p.turn_flags.acquired = 1
 p.turn_flags.tips = true
 verify(bot.reserve_target(p, []) == null, "Phreak only reserves before any acquisitions")
 p.turn_flags.clear()
 var good = row_card(e, "Two Hump Camel")
 verify(bot.reserve_target(p, [good]) == null, "Phreak keeps any worthwhile buy")
 e.gain_owner(good, p)
 e.move(good, p.reserve, "reserve")
 verify(bot.reserve_target(p, []) == null, "Phreak holds at most one unbought reserve")
 e.free()
 # Tips permits the fallback after buying, but ordinary acquisition does not.
 e = await reserve_fixture()
 p = e.active()
 target = row_card(e, "Payphone")
 p.turn_flags.acquired = 1
 verify(BotPlayer.new(e).reserve_target(p, []) == null, "No ordinary reservation after acquisition")
 p.turn_flags.tips = true
 verify(BotPlayer.new(e).reserve_target(p, []) == target, "Tips permits reservation after acquisition")
 var seen = {"buy": 0, "reserve": 0}
 e.card_bought.connect(func(_p, _c): seen.buy += 1)
 e.card_reserved.connect(func(_p, _c): seen.reserve += 1)
 p.turn_flags.acquired = 0
 var buy = row_card(e, "Jenny")
 p.hacking = e.effective_cost(p, buy)
 # A good buy prevents saving; Tips enables the later fallback for Payphone.
 await BotPlayer.new(e).take_turn(p)
 verify(seen.buy > 0 and seen.reserve == 1 and e.after_reserve_attempts == 0, "Tips buys then reserves in the same turn")
 e.free()
 e = await reserve_fixture()
 p = e.active()
 target = row_card(e, "Payphone")
 p.hacking = e.effective_cost(p, target)
 var paid = {"target": false, "reserve": false}
 e.card_bought.connect(func(_p, c):
  if c == target: paid.target = true)
 e.card_reserved.connect(func(_p, _c): paid.reserve = true)
 await BotPlayer.new(e).take_turn(p)
 verify(paid.target and not paid.reserve, "Elite buys normally when a good affordable buy exists")
 e.free()
 e = await reserve_fixture()
 p = e.active()
 target = row_card(e, "Payphone")
 e.state.turn = 100
 verify(BotPlayer.new(e).reserve_target(p, []) == null, "Elite avoids late save-up reservations")
 e.free()
 var first = await random_reserves()
 var second = await random_reserves()
 print("Kiddie random reserve sample: %d/200" % first.count(true))
 var acquired = await random_reserves(true)
 verify(acquired.count(true) == 0, "Kiddie only reserves before any acquisitions, even with Tips")
 verify(first == second, "Kiddie reservation sequence repeats for fixed seeds")
 verify(first.count(true) >= 10 and first.count(true) <= 40, "Kiddie random reservations have plausible frequency")
 await server_reserve_check(false)
 await server_reserve_check(true)
func random_reserves(acquired: bool = false) -> Array:
 var results: Array = []
 for seed_value in (40 if acquired else 200):
  var e = await reserve_fixture(0, 99000 + seed_value)
  row_card(e, "Payphone")
  if acquired:
   e.active().turn_flags.acquired = 1
   e.active().turn_flags.tips = true
  var seen = {"reserved": false}
  e.card_reserved.connect(func(_p, _c): seen.reserved = true)
  await BotPlayer.new(e).take_turn(e.active())
  results.append(seen.reserved)
  e.free()
 return results
func server_reserve_check(idle: bool):
 var server = GameServer.new()
 root.add_child(server)
 server.setup([{"bot": not idle, "name": "Fixture", "difficulty": 1}, {"bot": false, "name": "Human", "difficulty": 1}], "2026", 24, 123)
 var e = server.engine
 e.secure_random = false
 e.setup([1, 2], 123)
 await e.start_turn(0)
 for c in e.active().hand.duplicate(): e.discard(c)
 for c in e.state.center_row:
  if c != null: e.state.center_deck.append(c)
 e.state.center_row.clear()
 e.active().hacking = 2
 var pair = LoopbackTransport.pair()
 server.connections[1] = pair[0]
 var wire = {"event": false, "log": false}
 pair[1].received.connect(func(m):
  if m.get("kind") == "reserved": wire.event = true
  if m.get("t") == "log" and " reserves " in m.get("text", ""): wire.log = true)
 if idle: server.idle_bot[0] = true
 row_card(e, "Payphone")
 var seen = {"reserved": 0}
 e.card_reserved.connect(func(_p, _c): seen.reserved += 1)
 await server._drive()
 verify(seen.reserved == 1 and e.state.log.any(func(line): return " reserves " in line), "Server bot / idle takeover reserves and emits event and log")
 await process_frame
 verify(wire.event and wire.log, "Client receives server reserve event and reserves log")
 pair[0].close()
 server.free()

func defcon_checks():
 DefconSearch.fixed_rollouts = 1
 var e = GameEngine.new()
 root.add_child(e)
 e.setup([3, 2], 212121)
 await e.start_turn(0)
 var p = e.active()
 for c in p.hand.duplicate(): e.discard(c)
 var nirtom = e.state.all_cards().filter(func(c): return c.id == "Nirtom Unleashed")[0]
 var ben = e.state.all_cards().filter(func(c): return c.id == "Ben The Meek")[0]
 for c in [nirtom, ben]:
  e.gain_owner(c, p)
  e.move(c, p.hand, "hand")
 e.state.players[1].life = 3
 var elite = BotPlayer.new(e)
 var order = p.hand.duplicate()
 order.sort_custom(func(a, b): return elite.play_priority(p, a) > elite.play_priority(p, b))
 verify(elite.lethal_reachable(p) and order[0] == nirtom, "Elite printed-damage heuristic chooses a blocking Nirtom line")
 var chosen = await DefconSearch.new(e).choose_play(p, order)
 verify(chosen == ben, "DEFCON exact lethal chooses Ben before Nirtom blocks him")
 await e.play_card(p, chosen)
 verify(e.state.finished and e.state.winner == p, "Exact lethal really wins")
 e.free()
 e = GameEngine.new()
 root.add_child(e)
 e.setup([3, 2], 212122)
 await e.start_turn(0)
 p = e.active()
 for c in p.hand.duplicate(): e.discard(c)
 var payphone = e.state.all_cards().filter(func(c): return c.id == "Payphone")[0]
 var proud = e.state.all_cards().filter(func(c): return c.id == "proudF00F")[0]
 var ice = e.state.all_cards().filter(func(c): return c.id == "Bribery")[0]
 var q = e.state.players[1]
 e.gain_owner(ice, q)
 e.move(ice, q.play_area, "play_area")
 p.life = 1
 for slot in 5:
  var previous = e.state.center_row[slot]
  e.state.center_row[slot] = null
  if previous != null: e.move(previous, e.state.center_deck, "center_deck")
 for c in [payphone, proud]:
  e.detach(c)
  e.state.center_row[e.state.center_row.find(null)] = c
 p.hacking = 5
 q.life = 1
 var fallback = {"kind": "buy", "uid": payphone.uid}
 verify(e.dec(p).value(payphone, p) > e.dec(p).value(proud, p), "Elite values Payphone above immediate-loss purchase")
 var choice = await DefconSearch.new(e).choose_purchase(p, [payphone, proud], fallback)
 verify(choice == {"kind": "buy", "uid": proud.uid}, "Rollouts find proudF00F lethal buy before Bribery")
 await e.buy_card(p, proud)
 verify(e.state.finished and e.state.winner == p, "Better buy really wins")
 e.free()
 e = GameEngine.new()
 root.add_child(e)
 e.setup([3, 2], 212123)
 await e.start_turn(0)
 p = e.active()
 var ai = e.dec(p)
 var options: Array[String] = ["+3 hacking", "Gain 3 life", "Deal 3 damage"]
 verify(await ai.choose_option(p, "Choose one", options) in [0, 1, 2], "DEFCON option fallback")
 verify((await ai.choose_cards(p, "Discard cards", p.hand, 1, 2)).size() >= 1, "DEFCON card prompt fallback")
 verify(await ai.choose_player(p, "Hit player", e.opponents(p)) == e.state.players[1], "DEFCON target prompt fallback")
 verify(await ai.confirm(p, "Optional effect?") is bool, "DEFCON optional prompt fallback")
 e.free()
