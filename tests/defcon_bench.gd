extends SceneTree
var drivers: Array = []
var game
var turn_ms: Array = []
var failures = 0
func _initialize(): run.call_deferred()
func drive(p):
 var started = Time.get_ticks_usec()
 var own_turn = p.turns
 await drivers[p.seat].take_turn(p)
 if p.difficulty == 3:
  var elapsed = (Time.get_ticks_usec() - started) / 1000.0
  turn_ms.append(elapsed)
  if elapsed > 500 and OS.has_environment("DEFCON_SLOW"):
   print("SLOW seed=%d turn=%d seat=%d ms=%.1f log=%s" % [game.state.rng.seed, own_turn, p.seat, elapsed, str(game.state.log.slice(-10))])
func interval(wins: int, n: int) -> String:
 var rate = float(wins) / n
 var center = (rate + 3.8416 / (2 * n)) / (1 + 3.8416 / n)
 var half = 1.96 * sqrt(rate * (1 - rate) / n + 3.8416 / (4 * n * n)) / (1 + 3.8416 / n)
 return "%.1f%% [%.1f, %.1f]" % [100 * rate, 100 * (center - half), 100 * (center + half)]
func run():
 DefconSearch.collect_measurements = true
 var count = int(OS.get_environment("DEFCON_GAMES")) if OS.has_environment("DEFCON_GAMES") else 200
 DefconSearch.fixed_rollouts = int(OS.get_environment("DEFCON_COUNT")) if OS.has_environment("DEFCON_COUNT") else -1
 if OS.has_environment("DEFCON_WEIGHTS"): DefconValues.load_weights(OS.get_environment("DEFCON_WEIGHTS"))
 if OS.has_environment("DEFCON_SCALE"): DefconValues.scale = float(OS.get_environment("DEFCON_SCALE"))
 if OS.has_environment("DEFCON_THRESHOLD"): DefconValues.settings.threshold = JSON.parse_string(OS.get_environment("DEFCON_THRESHOLD"))
 if OS.has_environment("DEFCON_MARGIN"): DefconValues.settings.reserve_margin = float(OS.get_environment("DEFCON_MARGIN"))
 if OS.has_environment("DEFCON_FILLER"): DefconValues.settings.late_filler = float(OS.get_environment("DEFCON_FILLER"))
 var seed_start = int(OS.get_environment("DEFCON_SEED")) if OS.has_environment("DEFCON_SEED") else 930000
 var seats = int(OS.get_environment("DEFCON_SEATS")) if OS.has_environment("DEFCON_SEATS") else 2
 for pool in ["2025", "2026"]:
  if OS.has_environment("DEFCON_POOL") and OS.get_environment("DEFCON_POOL") != pool: continue
  for bonus in [false, true]:
   if OS.has_environment("DEFCON_BONUS") and bool(int(OS.get_environment("DEFCON_BONUS"))) != bonus: continue
   var wins = 0
   var draws = 0
   turn_ms = []
   DefconSearch.measurements = []
   var start = Time.get_ticks_msec()
   for i in count:
    game = GameEngine.new()
    root.add_child(game)
    var seat = i % seats
    var levels = []
    # DEFCON_OPPONENT picks the other seats' level (0 Script Kiddie, 1 Phreak, 2 Elite; default Elite).
    for j in seats: levels.append(3 if j == seat else (int(OS.get_environment("DEFCON_OPPONENT")) if OS.has_environment("DEFCON_OPPONENT") else 2))
    game.setup(levels, seed_start + i, [], pool)
    if not bonus:
     game.state.players[seat].life = game.state.starting_life
     game.state.players[seat].starting_life = game.state.starting_life
    drivers = []
    for j in seats: drivers.append(BotPlayer.new(game))
    game.turn_driver = drive
    await game.start_turn()
    for turn in 200:
     if game.state.finished or game.state.turn > 200: break
     await drive(game.active())
    if game.state.winner != null and game.state.winner.seat == seat: wins += 1
    if game.state.winner == null: draws += 1
    if not game.state.conservation_ok(): failures += 1
    game.turn_driver = Callable()
    game.free()
    if (i + 1) % 20 == 0: print("Progress %s bonus=%s %d/%d wins=%d elapsed=%.1fs" % [pool, bonus, i + 1, count, wins, (Time.get_ticks_msec() - start) / 1000.0])
   var decision_ms = 0.0
   var rollouts = 0
   for m in DefconSearch.measurements:
    decision_ms += m.ms
    rollouts += m.rollouts
   var total = 0.0
   var worst = 0.0
   for t in turn_ms:
    total += t
    worst = maxf(worst, t)
   var n = maxi(1, DefconSearch.measurements.size())
   if OS.has_environment("DEFCON_OUT"):
    FileAccess.open(OS.get_environment("DEFCON_OUT"), FileAccess.WRITE).store_string(JSON.stringify({"pool": pool, "bonus": bonus, "seats": seats, "seed": seed_start, "count_mode": DefconSearch.fixed_rollouts, "games": count, "wins": wins, "draws": draws, "turns": turn_ms.size(), "total_ms": total, "worst_ms": worst, "failures": failures}))
   print("DEFCON pool=%s bonus=%s games=%d wins=%d draws=%d Wilson=%s decision_ms=%.3f turn_mean_ms=%.3f turn_worst_ms=%.3f rollouts_per_decision=%.2f seconds=%.2f" % [pool, bonus, count, wins, draws, interval(wins, count), decision_ms / n, total / maxf(1, turn_ms.size()), worst, float(rollouts) / n, (Time.get_ticks_msec() - start) / 1000.0])
 print("DEFCON benchmark failures: %d" % failures)
 quit(1 if failures else 0)
