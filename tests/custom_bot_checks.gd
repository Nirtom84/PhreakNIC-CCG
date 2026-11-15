extends SceneTree
class ErrorCounter extends Logger:
 var count = 0
 func _log_error(_f: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _type: int, _traces: Array[ScriptBacktrace]) -> void: count += 1
## A human who plays O.P.R.A.H. and removes one card from their hand.
class OprahHuman extends Decider:
 func choose_cards(_p, prompt: String, cards: Array, min_n: int, _max_n: int) -> Array:
  return cards.slice(0, 1) if prompt.begins_with("Remove cards") else cards.slice(0, min_n)
var errors = ErrorCounter.new()
var checks = 0
var failures = 0
func _initialize(): run.call_deferred()
func verify(ok, message):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", message)
func run():
 OS.add_logger(errors)
 DefconSearch.fixed_rollouts = 0
 var decks = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))
 var large = {"name": "200 mixed printings", "cards": {"Mognet": 2, "Botnet": 2, "NotLarry Cardboard Cutout@mog": 2}}
 for printing in CustomDeck.printings():
  if CustomDeck.total(large) >= 200: break
  if printing.base_id in ["Botnet", "NotLarry Cardboard Cutout"] or large.cards.has(printing.base_id): continue
  large.cards[printing.id] = 2
 verify(CustomDeck.total(large) == 200 and CustomDeck.validate(large).is_empty(), "200 card fixture valid")
 decks.append(large)
 for deck in decks:
  for level in 4:
   for seats in [2, 3, 4]:
    var game = GameEngine.new(); root.add_child(game)
    var levels = []; levels.resize(seats); levels.fill(level)
    verify(game.setup(levels, 85000000 + decks.find(deck) * 1000 + level * 100 + seats, [], "2026", 0, [], deck), "setup")
    var bot = BotPlayer.new(game)
    verify(BotPlayer.new(game).custom_planner == bot.custom_planner, "planner persists across recreated drivers")
    var census = bot.custom_planner.census()
    var expected = {}
    for c in game.state.center_deck: expected[CustomDeck.base_id(c.id)] = expected.get(CustomDeck.base_id(c.id), 0) + 1
    verify(census.values().reduce(func(a,b): return a+b, 0) == game.state.center_deck.size(), "initial census count")
    for id in census: verify(census[id] == expected.get(id,0), "initial census copies")
    await game.start_turn(0)
    for turn in 200:
     if game.state.finished or game.state.turn >= 200: break
     await bot.take_turn(game.active())
     verify(game.state.conservation_ok(), "conservation")
     census = bot.custom_planner.census()
     expected = {}
     for c in game.state.center_deck: expected[CustomDeck.base_id(c.id)] = expected.get(CustomDeck.base_id(c.id),0)+1
     for id in census: verify(census[id] == expected.get(id,0), "census after buys/refills/returns")
    verify(game.state.finished or game.state.turn >= 200, "full game resolves naturally or as 200-turn draw %s/%d/%d" % [deck.name,level,seats])
    DefconSearch.dispose(game)
 var world = await oprah_draw(decks[0], false)
 var swapped = await oprah_draw(decks[0], true)
 verify(world.in_hand and swapped.in_hand and world.drawn != swapped.drawn, "O.P.R.A.H. fixture draws a different hidden card in each world")
 verify(world.hidden == swapped.hidden, "census learns nothing from O.P.R.A.H.'s hidden draw")
 var counted = world.hidden.duplicate()
 counted[world.drawn] -= 1
 verify(world.revealed == counted, "census counts O.P.R.A.H.'s draw once it's discarded")
 var normal = GameEngine.new(); root.add_child(normal); normal.setup([2,2], 85100000)
 var bot = BotPlayer.new(normal)
 var before = CustomDeckPlanner.calls
 bot.purchase_value(normal.dec(normal.active()), normal.state.center_row[0], normal.active())
 verify(bot.custom_planner == null and CustomDeckPlanner.calls == before, "normal planner isolation")
 normal.free()
 for text in ["oops", "[]", '{"format":"custom-weights-v1","adjustments":{"Botnet":[1,"x",2]}}']:
  var file = FileAccess.open("user://bad-custom.json",FileAccess.WRITE); file.store_string(text); file.close()
  CustomDeckPlanner.load_weights("user://bad-custom.json")
  verify(CustomDeckPlanner.weights.is_empty(), "corrupt weights fallback")
 CustomDeckPlanner.load_weights("user://missing-custom.json")
 verify(CustomDeckPlanner.weights.is_empty(), "missing weights fallback")
 CustomDeckPlanner.load_weights()
 var capped = preload("res://tests/custom_selfplay.gd").CappedEngine.new()
 root.add_child(capped); capped.setup([2,2], 85120000, [], "2026", 0, [], decks[0])
 capped.state.turn = 200
 await capped.start_turn(0)
 verify(capped.turn_capped and capped.state.finished and capped.state.winner == null and capped.state.turn == 200, "nested turn entry enforces the draw cap")
 DefconSearch.dispose(capped)
 var path = "/tmp/custom-bot-check-" + str(OS.get_process_id())
 var output = []
 var old_scale = OS.get_environment("SP_PLAN_SCALE")
 OS.set_environment("SP_PLAN_SCALE", "0.00001")
 # CI has no ~/.local/bin/godot4.7.1: run the shard with this same Godot binary.
 if not OS.has_environment("GODOT"): OS.set_environment("GODOT", OS.get_executable_path())
 var code = OS.execute("bash", ["tools/custom_selfplay.sh", path, "2"],output,true)
 if old_scale.is_empty(): OS.unset_environment("SP_PLAN_SCALE")
 else: OS.set_environment("SP_PLAN_SCALE", old_scale)
 verify(code == 0 and FileAccess.file_exists(path+"/plan.json"), "tiny selfplay " + str(output))
 output = []
 code = OS.execute("python3",["tools/custom_fit.py",path,"--output",path+"/candidate.json"],output,true)
 verify(code == 0,"tiny fit " + str(output))
 CustomDeckPlanner.load_weights(path+"/candidate.json")
 verify(not CustomDeckPlanner.weights.is_empty(),"fitted weights load")
 CustomDeckPlanner.load_weights()
 verify(errors.count == 0, "no script errors during full games")
 print("custom bot checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)

## Plays O.P.R.A.H. for a human seat, optionally with a different card hidden on top of the Center Deck.
func oprah_draw(base: Dictionary, swap_top: bool) -> Dictionary:
 var deck = {"name": "O.P.R.A.H. fixture", "cards": base.cards.duplicate()}
 deck.cards["O.P.R.A.H."] = 2
 var game = GameEngine.new(); root.add_child(game)
 game.setup([-1, 2], 85130000, [OprahHuman.new()], "2026", 0, [], deck)
 var planner = game.get_meta("custom_planner")
 await game.start_turn(0)
 var human = game.state.players[0]
 var oprah = (game.state.center_deck + game.state.center_row).filter(func(c): return c != null and c.id == "O.P.R.A.H.")[0]
 game.gain_owner(oprah, human)
 game.move(oprah, human.hand, "hand")
 var pile = game.state.center_deck
 if swap_top:
  var other = pile.filter(func(c): return CustomDeck.base_id(c.id) != CustomDeck.base_id(pile.back().id))[0]
  var i = pile.find(other)
  pile[i] = pile.back()
  pile[pile.size() - 1] = other
 var drawn = pile.back()
 await game.play_card(human, oprah)
 var result = {"drawn": CustomDeck.base_id(drawn.id), "in_hand": drawn in human.hand, "hidden": planner.census().duplicate()}
 game.discard(drawn)
 result.revealed = planner.census().duplicate()
 DefconSearch.dispose(game)
 return result
