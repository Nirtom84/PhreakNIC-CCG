extends SceneTree
# Reaction turns can start further turns before the outer shard loop resumes.
# Enforce the cap at that entry point too, including automatic Book/extra-turn chains.
class CappedEngine extends GameEngine:
 var turn_capped = false
 func start_turn(seat: int = -1):
  if state.finished: return
  if state.turn >= 200:
   turn_capped = true
   state.finished = true
   state.winner = null
   return
  await super.start_turn(seat)
class ErrorCounter extends Logger:
 var count = 0
 func _log_error(_f: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _type: int, _traces: Array[ScriptBacktrace]) -> void: count += 1
var errors = ErrorCounter.new()
var game
var drivers = []
var decisions = []
var fit = [{"xx": {}, "xy": {}, "count": 0}, {"xx": {}, "xy": {}, "count": 0}, {"xx": {}, "xy": {}, "count": 0}]
var exploration = RandomNumberGenerator.new()
var learner = 0
var bench = false
var candidate = {}
var prior = {}
var ordering = false
func _initialize(): run.call_deferred()
func env_int(key, fallback): return int(OS.get_environment(key)) if OS.has_environment(key) else fallback
func policy(p, buys, fallback):
 if p.seat != learner: return fallback
 if exploration.randf() >= 0.25: return fallback
 var options = buys.map(func(c): return CustomDeck.base_id(c.id))
 options.append("__stop__")
 var index = exploration.randi_range(0, options.size() - 1)
 var x = {}
 for id in options: x[id] = x.get(id, 0.0) - 1.0 / options.size()
 x[options[index]] = x.get(options[index], 0.0) + 1.0
 decisions.append({"x": x, "phase": 2 if float(game.state.center_deck.size()) / maxf(1, CustomDeck.total(game.state.custom_deck)) < 0.2 else DefconValues.phase(p)})
 return {"kind": "stop", "uid": -1} if index == buys.size() else {"kind": "buy", "uid": buys[index].uid}
func drive(p):
 if game.state.turn >= 200: return
 var saved = CustomDeckPlanner.weights
 if bench and not ordering: CustomDeckPlanner.weights = candidate if p.seat == learner else prior
 await drivers[p.seat].take_turn(p)
 if bench and not ordering: CustomDeckPlanner.weights = saved
func run():
 OS.add_logger(errors)
 bench = OS.get_environment("CB_BENCH") == "1"
 ordering = OS.get_environment("CB_ORDERING") == "1"
 var count = env_int("SP_GAMES", 10)
 var seats = env_int("SP_SEATS", 2)
 var first = env_int("SP_SEED", 81000000)
 var offset = env_int("SP_OFFSET", 0)
 var decks = CustomBotDecks.load_decks(OS.get_environment("SP_PLAN"))
 if decks.is_empty() or seats not in [2, 3, 4]: quit(2); return
 CustomDeckPlanner.load_weights(OS.get_environment("SP_WEIGHTS") if OS.has_environment("SP_WEIGHTS") else "res://data/custom_deck_weights.json")
 candidate = CustomDeckPlanner.weights.duplicate(true)
 CustomDeckPlanner.load_weights()
 prior = CustomDeckPlanner.weights.duplicate(true)
 CustomDeckPlanner.weights = candidate
 # Training deliberately disables exact lethal, matching the previous offline pipeline.
 DefconSearch.fixed_rollouts = -1 if bench else 0
 var output = {"format": "custom-selfplay-v1", "seed": first, "games": count, "seats": seats, "totals": {"games": 0, "turns": 0, "draws": 0, "turn_caps": 0, "errors": 0, "conservation_failures": 0, "first_wins": 0, "candidate_wins": 0}, "decks": {}, "error_seeds": [], "levels": {}, "matchups": {}, "weights": OS.get_environment("SP_WEIGHTS") if OS.has_environment("SP_WEIGHTS") else "res://data/custom_deck_weights.json", "fit": fit}
 var started = Time.get_ticks_msec()
 for i in count:
  var seed_value = first + i
  var sequence = offset + i
  var deck = decks[sequence % decks.size()]
  var levels = []
  # Enumerate base-four difficulty tuples independently of deck round-robin.
  var mix = sequence / decks.size()
  for j in seats:
   levels.append(int(mix) % 4)
   mix = int(mix) / 4
  if bench:
   levels.fill(2)
   if ordering:
    for j in seats: levels[j] = (j + sequence) % 4 if seats == 4 else (sequence / 2 % 3 + (j + sequence) % 2)
  learner = sequence % seats
  exploration.seed = seed_value * 100003 + 79
  errors.count = 0
  decisions = []; drivers = []
  game = CappedEngine.new(); root.add_child(game)
  if not game.setup(levels, seed_value, [], "2026", 0, [], deck): quit(2); return
  for j in seats:
   var bot = BotPlayer.new(game)
   bot.continue_turn = func(): return game.state.turn < 200 and errors.count == 0
   if not bench: bot.purchase_policy = policy
   drivers.append(bot)
  game.turn_driver = drive
  if OS.get_environment("SP_TRACE_TURNS") == "1": game.turn_started.connect(func(_p): print("TRACE seed=%d turn=%d" % [seed_value,game.state.turn]))
  await game.start_turn(int(sequence / seats) % seats)
  var steps = 0
  while not game.state.finished and game.state.turn < 200 and errors.count == 0 and steps < 400:
   await drive(game.active())
   steps += 1
  var failed = errors.count > 0 or steps >= 400
  var capped = (game.turn_capped or not game.state.finished) and not failed
  var winner = game.state.winner.seat if game.state.finished and game.state.winner != null and not failed else -1
  var totals = output.totals
  totals.games += 1; totals.turns += game.state.turn
  if winner < 0: totals.draws += 1
  if capped: totals.turn_caps += 1
  if failed: totals.errors += 1; output.error_seeds.append(seed_value)
  if not game.state.conservation_ok(): totals.conservation_failures += 1; output.error_seeds.append(seed_value)
  if winner == learner: totals.candidate_wins += 1
  if winner == int(sequence / seats) % seats: totals.first_wins += 1
  if not output.decks.has(deck.name): output.decks[deck.name] = {"games": 0, "turns": 0, "draws": 0, "errors": 0, "levels": {}}
  var dest = output.decks[deck.name]
  dest.games += 1; dest.turns += game.state.turn
  if winner < 0: dest.draws += 1
  if failed: dest.errors += 1
  for j in seats:
   var key = "%dP/%d" % [seats, levels[j]]
   for target in [dest.levels, output.levels]:
    if not target.has(key): target[key] = {"seats": 0, "wins": 0}
    target[key].seats += 1
    if winner == j: target[key].wins += 1
  if ordering and seats == 2:
   var low = mini(levels[0], levels[1])
   var key = "%d<%d" % [low,low+1]
   if not output.matchups.has(key): output.matchups[key] = {"games": 0, "higher_wins": 0, "lower_wins": 0, "draws": 0}
   var pair = output.matchups[key]; pair.games += 1
   if winner < 0: pair.draws += 1
   elif levels[winner] == low: pair.lower_wins += 1
   else: pair.higher_wins += 1
  if not failed:
   var reward = (1.0 if winner == learner else (1.0 / seats if winner < 0 else 0.0)) - 1.0 / seats
   for d in decisions:
    var f = fit[d.phase]; f.count += 1
    for a in d.x:
     f.xy[a] = f.xy.get(a, 0.0) + d.x[a] * reward
     if not f.xx.has(a): f.xx[a] = {}
     for b in d.x: f.xx[a][b] = f.xx[a].get(b, 0.0) + d.x[a] * d.x[b]
  game.turn_driver = Callable()
  drivers.clear()
  DefconSearch.dispose(game); game = null
  if (i+1) % 10 == 0: print("custom progress: %d/%d seed=%d" % [i+1,count,seed_value])
  await process_frame
 output.wall_seconds = (Time.get_ticks_msec() - started) / 1000.0
 var path = OS.get_environment("SP_OUT")
 var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
 if file == null: quit(2); return
 file.store_string(JSON.stringify(output)); file.close()
 var err = DirAccess.rename_absolute(path + ".tmp", path)
 print("custom selfplay: %d games, %d errors, %.3f seconds" % [count, output.totals.errors, output.wall_seconds])
 quit(0 if err == OK and output.totals.errors == 0 else 1)
