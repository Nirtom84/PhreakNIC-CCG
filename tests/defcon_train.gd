extends SceneTree
# Randomized purchase trials. Separate experiment RNG never consumes game RNG.
var game
var rng = RandomNumberGenerator.new()
var decisions: Array = []
var stats = {}
var samples: Array = []
var drivers: Array = []
var epsilon = 0.35
func _initialize(): run.call_deferred()
func policy(p, buys, fallback):
 var options = buys.map(func(c): return {"kind": "buy", "uid": c.uid})
 options.append({"kind": "stop", "uid": -1})
 var choice = fallback
 var explored = rng.randf() < epsilon
 if explored: choice = options[rng.randi_range(0, options.size() - 1)]
 var ids = buys.map(func(c): return c.id)
 var id = "__stop__"
 if choice.kind == "buy":
  for c in buys:
   if c.uid == choice.uid: id = c.id
 elif choice.kind == "reserve": return choice
 var phase = DefconValues.phase(p)
 decisions.append({"seat": p.seat, "id": id, "phase": phase, "turn": p.turns, "options": ids, "random": explored})
 return choice
func drive(p): await drivers[p.seat].take_turn(p)
func run():
 var count = int(OS.get_environment("TRAIN_GAMES")) if OS.has_environment("TRAIN_GAMES") else 1000
 var start_seed = int(OS.get_environment("TRAIN_SEED"))
 var pool = OS.get_environment("TRAIN_POOL")
 var iteration = int(OS.get_environment("TRAIN_ITERATION"))
 var bonus = OS.get_environment("TRAIN_BONUS") == "1"
 epsilon = float(OS.get_environment("TRAIN_EPSILON")) if OS.has_environment("TRAIN_EPSILON") else 0.35
 if OS.has_environment("TRAIN_WEIGHTS"): DefconValues.load_weights(OS.get_environment("TRAIN_WEIGHTS"))
 DefconSearch.fixed_rollouts = 0
 var started = Time.get_ticks_msec()
 for i in count:
  game = GameEngine.new()
  root.add_child(game)
  var seed_value = start_seed + i
  rng.seed = seed_value * 100003 + 79
  game.setup([2, 2], seed_value, [], pool)
  if iteration > 0:
   for j in 2:
    if not bonus or j == seed_value % 2: game.deciders[j] = BotDecider.new(game, 3)
  if bonus:
   game.state.players[seed_value % 2].life *= 2
   game.state.players[seed_value % 2].starting_life *= 2
  drivers = [BotPlayer.new(game), BotPlayer.new(game)]
  for j in 2:
   if not bonus or j == seed_value % 2: drivers[j].purchase_policy = policy
  decisions = []
  game.turn_driver = drive
  await game.start_turn()
  for turn in 200:
   if game.state.finished or game.state.turn > 200: break
   await drive(game.active())
  var winner = game.state.winner.seat if game.state.winner != null else -1
  var seen = {}
  for d in decisions:
   var key = "%s/%s" % [d.id, d.phase]
   var buyer_key = "%d/%s" % [d.seat, key]
   var win = 1.0 if winner == d.seat else (0.5 if winner < 0 else 0.0)
   var tempo = (2.0 * win - 1.0) / sqrt(maxf(1, game.state.players[d.seat].turns - d.turn + 1))
   if not stats.has(key): stats[key] = {"games": 0, "wins": 0.0, "tempo": 0.0}
   if not seen.has(buyer_key):
    stats[key].games += 1
    stats[key].wins += win
    stats[key].tempo += tempo
    seen[buyer_key] = true
   if d.random: samples.append([d.id, d.phase, d.options, win, tempo])
  if not game.state.conservation_ok(): push_error("Training conservation"); quit(1); return
  game.turn_driver = Callable()
  game.free()
  if (i + 1) % 100 == 0: print("Training %s iteration=%d %d/%d" % [pool, iteration, i + 1, count])
 var output = {"pool": pool, "iteration": iteration, "seed": start_seed, "games": count, "epsilon": epsilon, "bonus": bonus, "stats": stats, "samples": samples}
 FileAccess.open(OS.get_environment("TRAIN_OUT"), FileAccess.WRITE).store_string(JSON.stringify(output))
 print("DEFCON training pool=%s iteration=%d games=%d samples=%d seconds=%.2f" % [pool, iteration, count, samples.size(), (Time.get_ticks_msec() - started) / 1000.0])
 quit()
