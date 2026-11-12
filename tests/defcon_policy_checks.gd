extends RefCounted
func run(suite):
 DefconValues.load_weights()
 var saved = DefconValues.weights.duplicate(true)
 var saved_bonus = DefconValues.bonus_weights.duplicate(true)
 var saved_settings = DefconValues.settings.duplicate(true)
 var game = GameEngine.new()
 suite.root.add_child(game)
 game.setup([3, 2], 631717)
 await game.start_turn(0)
 var p = game.active()
 var ai = game.dec(p)
 var elite = BotDecider.new(game, 2)
 for pool in ["2025", "2026"]:
  var ids = game.get_node("/root/CardDB").center_ids(pool)
  suite.verify(not ids.is_empty() and ids.all(func(id): return saved.get(pool, {}).has(id)), "Learned weights cover every non-starter in " + pool)
  suite.verify(not saved_bonus.has(pool) or ids.all(func(id): return saved_bonus[pool].has(id)), "Handicap weights cover every non-starter in " + pool)
 var mog = game.get_node("/root/CardDB").catalog("2026mog")
 for id in mog.center_ids("2026mog"):
  suite.verify(saved.get("2026", {}).has(DefconValues.original_id(mog, id)), "Mog weights resolve " + id)
 var card = CardInstance.new(0, "Payphone")
 if saved_bonus.has("2026"):
  suite.verify(is_equal_approx(ai.buy_value(card, p) - elite.value(card, p), float(saved_bonus["2026"][card.id][0])), "Own double-life context selects handicap coefficients")
 var old_life = p.starting_life
 p.starting_life = game.state.starting_life
 suite.verify(is_equal_approx(ai.buy_value(card, p) - elite.value(card, p), float(saved["2026"][card.id][0])), "Ordinary own life selects self-play coefficients")
 game.state.card_pool = "2026mog"
 suite.verify(is_equal_approx(DefconValues.adjustment(game, CardInstance.new(0, "Mognet1"), p), float(saved["2026"]["Botnet1"][0])), "Actual Mog lookup uses original card coefficients")
 game.state.card_pool = "2026"
 p.starting_life = old_life
 DefconValues.load_weights("user://missing-defcon.json")
 suite.verify(ai.buy_value(card, p) == elite.value(card, p), "Missing weights silently use Elite")
 FileAccess.open("user://broken-defcon.json", FileAccess.WRITE).store_string("{broken")
 DefconValues.load_weights("user://broken-defcon.json")
 suite.verify(ai.buy_value(card, p) == elite.value(card, p), "Corrupt weights silently use Elite")
 FileAccess.open("user://broken-defcon.json", FileAccess.WRITE).store_string('{"pools":{"2025":{},"2026":{"Payphone":["bad",0,0]}}}')
 DefconValues.load_weights("user://broken-defcon.json")
 suite.verify(ai.buy_value(card, p) == elite.value(card, p), "Invalid numeric weights silently use Elite")
 DefconValues.weights = {"2025": {}, "2026": {}}
 var driver = BotPlayer.new(game)
 var payphone = CardInstance.new(90001, "Payphone")
 var damage = CardInstance.new(90002, "Damage")
 suite.verify(driver.buy_priority(payphone, p) > driver.buy_priority(damage, p), "Neutral weights match Elite purchase order")
 DefconValues.weights["2026"]["Damage"] = [30, 30, 30]
 suite.verify(driver.buy_priority(damage, p) > driver.buy_priority(payphone, p), "Learned disagreement changes DEFCON purchase order")
 suite.verify(elite.value(payphone, p) > elite.value(damage, p), "Learned disagreement leaves Elite unchanged")
 DefconValues.weights = {"2025": {}, "2026": {"Payphone": [-20, -20, -20], "The Book": [-30, -30, -30]}}
 var book = CardInstance.new(90003, "The Book")
 var removed = await ai.choose_cards(p, "Remove cards from game", [payphone, book], 0, 1)
 suite.verify(removed == [book], "Thinning removes lowest learned value")
 var basics = p.deck + p.hand + p.discard
 var hacks = basics.filter(func(c): return c.id == "Hacking")
 var attacks = basics.filter(func(c): return c.id == "Damage")
 var selected = await ai.choose_cards(p, "Remove cards from game", hacks, 0, hacks.size())
 suite.verify(selected.size() == 2, "DEFCON thinning keeps six Hacking")
 selected = await ai.choose_cards(p, "Remove cards from game", attacks, 0, attacks.size())
 suite.verify(selected.is_empty(), "DEFCON thinning keeps two damage")
 var gate = DefconSearch.new(game)
 DefconSearch.fixed_rollouts = 100000
 gate.begin()
 gate.exact_active = true
 gate.lethal_deadline = Time.get_ticks_msec() - 1
 var started = Time.get_ticks_msec()
 suite.verify((await gate.lethal_line(game, p.seat, p.hand.map(func(c): return c.uid))).is_empty() and gate.lethal_nodes == 0 and Time.get_ticks_msec() - started < 40, "Count mode lethal obeys expired wall cap")
 gate.lethal_deadline = Time.get_ticks_msec() + 40
 gate.lethal_nodes = DefconSearch.LETHAL_NODES
 suite.verify((await gate.lethal_line(game, p.seat, p.hand.map(func(c): return c.uid))).is_empty() and gate.lethal_nodes == DefconSearch.LETHAL_NODES, "Count mode lethal obeys node cap")
 suite.verify(await purchase_fixture(suite, false) == "Payphone", "Neutral learned weights buy exactly Elite's preferred card")
 suite.verify(await purchase_fixture(suite, true) == "Jenny", "Learned card disagreement changes actual first purchase")
 DefconValues.weights = saved
 DefconValues.bonus_weights = saved_bonus
 DefconValues.settings = saved_settings
 DefconSearch.fixed_rollouts = -1
 game.free()
 await recycling_fixture(suite)
 await deterministic_fixture(suite)
 await target_fixture(suite)
func legacy_traces(suite):
 var expected = JSON.parse_string(FileAccess.get_file_as_string("res://tests/defcon_trace_hashes.json"))
 for level in 3:
  for pool in ["2025", "2026", "2026mog"]:
   for seed_value in [77101, 77102, 77103]:
    var game = GameEngine.new()
    suite.root.add_child(game)
    game.setup([level, level], seed_value, [], pool)
    var driver = BotPlayer.new(game)
    game.turn_driver = func(p): await driver.take_turn(p)
    await game.start_turn()
    for turn in 200:
     if game.state.finished or game.state.turn > 200: break
     await driver.take_turn(game.active())
    var key = "%d/%s/%d" % [level, pool, seed_value]
    suite.verify(JSON.stringify(SaveGame.snapshot(game.state)).sha256_text() == expected[key], "Pre-change trace " + key)
    game.turn_driver = Callable()
    game.free()

func purchase_fixture(suite, disagree: bool) -> String:
 var game = GameEngine.new()
 suite.root.add_child(game)
 game.setup([3, 2], 66317)
 await game.start_turn(0)
 var p = game.active()
 for c in p.hand.duplicate(): game.discard(c)
 for slot in 5:
  var c = game.state.center_row[slot]
  game.state.center_row[slot] = null
  if c != null: game.move(c, game.state.center_deck, "center_deck")
 for id in ["Payphone", "Jenny"]:
  var c = game.state.center_deck.filter(func(x): return x.id == id)[0]
  game.detach(c)
  game.state.center_row[game.state.center_row.find(null)] = c
 p.hacking = 10
 DefconValues.weights = {"2025": {}, "2026": {"Jenny": [30, 30, 30] if disagree else [0, 0, 0]}}
 var bought = []
 game.card_bought.connect(func(_buyer, c): bought.append(c.id))
 DefconSearch.fixed_rollouts = 0
 await BotPlayer.new(game).take_turn(p)
 suite.verify(game.state.conservation_ok(), "Learned purchase fixture conserves cards")
 var result = bought[0] if not bought.is_empty() else ""
 game.free()
 return result

func recycling_fixture(suite):
 var game = GameEngine.new()
 suite.root.add_child(game)
 game.setup([3, 2], 67171)
 await game.start_turn(0)
 var p = game.active()
 for c in (p.deck + p.hand + p.discard).duplicate(): game.remove(c)
 var draw = game.state.center_deck.filter(func(c): return c.id == "Brimstone, Fabulous")
 if draw.is_empty(): draw = game.state.center_row.filter(func(c): return c != null and c.id == "Brimstone, Fabulous")
 game.gain_owner(draw[0], p)
 game.move(draw[0], p.hand, "hand")
 var counter = {"plays": 0}
 game.card_played.connect(func(_p, _c): counter.plays += 1)
 var started = Time.get_ticks_msec()
 DefconSearch.fixed_rollouts = -1
 await BotPlayer.new(game).take_turn(p)
 suite.verify(counter.plays <= 3 and game.state.turn >= 2, "DEFCON leaves draw-only recycling and reaches acquisition/end")
 suite.verify(Time.get_ticks_msec() - started < 500 and game.state.conservation_ok(), "Draw-cycle turn bounded and conserves cards")
 game.free()
func deterministic_fixture(suite):
 var hashes = []
 DefconSearch.fixed_rollouts = 0
 for repeat in 2:
  var game = GameEngine.new()
  suite.root.add_child(game)
  game.setup([3, 2], 677171)
  game.state.players[0].life = game.state.starting_life
  game.state.players[0].starting_life = game.state.starting_life
  var driver = BotPlayer.new(game)
  game.turn_driver = func(p): await driver.take_turn(p)
  await game.start_turn()
  for turn in 200:
   if game.state.finished or game.state.turn > 200: break
   await driver.take_turn(game.active())
  hashes.append(JSON.stringify(SaveGame.snapshot(game.state)).sha256_text())
  game.turn_driver = Callable()
  game.free()
 suite.verify(hashes[0] == hashes[1], "Fixed seed produces identical learned-policy game trace")
 DefconSearch.fixed_rollouts = -1

func target_fixture(suite):
 var game = GameEngine.new()
 suite.root.add_child(game)
 game.setup([3, 2, 2, 2], 671718)
 await game.start_turn(0)
 var p = game.active()
 for c in p.hand.duplicate(): game.discard(c)
 var damage = (p.deck + p.discard).filter(func(c): return c.id == "Damage")[0]
 game.move(damage, p.hand, "hand")
 var targets = game.opponents(p)
 targets[0].life = 1
 targets[1].life = 50
 targets[2].life = 20
 suite.verify(await game.dec(p).choose_player(p, "Hit player", targets) == targets[0], "Multiplayer DEFCON finishes a killable opponent")
 targets[0].life = 20
 var chosen = await game.dec(p).choose_player(p, "Hit player", targets)
 suite.verify(chosen == targets[1], "Multiplayer DEFCON targets highest public strength")
 for q in targets:
  var unknown = q.hand + q.deck
  unknown.reverse()
  q.hand = unknown.slice(0, q.hand.size())
  q.deck = unknown.slice(q.hand.size())
 suite.verify(await game.dec(p).choose_player(p, "Hit player", targets) == chosen, "Multiplayer target ignores hidden hand/deck arrangements")
 suite.verify(await game.dec(p).choose_player(p, "Give Rickroll", targets) == targets[1], "Hostile gift targets public threat")
 suite.verify(await game.dec(p).choose_player(p, "Give card to opponent", targets) != targets[1], "Beneficial gift keeps Elite beneficiary choice")
 game.free()
