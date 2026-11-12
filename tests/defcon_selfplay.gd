extends SceneTree
# Offline all-DEFCON randomized purchase trials; no game RNG consumption.
# Pure measurement wrappers delegate every decision/action to the shipped code.
class MeasuredEngine extends GameEngine:
 var people: Array = []
 func activate(p, permanent, ability_index: int = 0) -> bool:
  var cost = 0
  for ability in activatable_abilities(p, permanent):
   if ability.index == ability_index and ability.enabled: cost = ability.cost
  var succeeded = await super.activate(p, permanent, ability_index)
  if succeeded: people[p.seat].hacking_spent += cost
  return succeeded
class MeasuredDecider extends BotDecider:
 var counters: Dictionary = {}
 func choose_number(player, prompt: String, allowed: Array[int]) -> int:
  var result = super.choose_number(player, prompt, allowed)
  if prompt.begins_with("Pay hacking") and result in allowed: counters.hacking_spent += result
  return result
class ErrorCounter extends Logger:
 var count = 0
 func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
  count += 1
var error_counter = ErrorCounter.new()
const NAMES = ["Nirtom", "Reps4Thor", "Bitwize", "5ud0"]
var game
var drivers: Array = []
var rng = RandomNumberGenerator.new()
var decisions: Array = []
var epsilon = 0.25
var seats = 2
var seed_value = 0
var output = {}
var local = {}
var ids: Array = []
var index = {}
var fit: Array = []
func _initialize(): run.call_deferred()
func env_int(key, fallback): return int(OS.get_environment(key)) if OS.has_environment(key) else fallback
func person(seat): return output.people[NAMES[seat]]
func card(id):
 if not output.cards.has(id): output.cards[id] = {"bought": 0, "winner_bought": 0, "winner_games_bought": 0, "played": 0, "star": 0, "reserved": 0}
 return output.cards[id]
func record(key, value, seat = -1, minimum = false):
 if not output.records.has(key) or (value < output.records[key].value if minimum else value > output.records[key].value):
  output.records[key] = {"value": value, "seed": seed_value, "name": NAMES[seat] if seat >= 0 else "", "seats": seats, "pool": output.pool}
func policy(p, buys, fallback):
 var options = buys.map(func(c): return {"kind": "buy", "uid": c.uid})
 options.append({"kind": "stop", "uid": -1})
 var choice = fallback
 var explored = rng.randf() < epsilon
 if explored: choice = options[rng.randi_range(0, options.size() - 1)]
 if choice.kind == "reserve": return choice
 var id = "__stop__"
 for c in buys:
  if choice.kind == "buy" and c.uid == choice.uid: id = c.id
 decisions.append({"seat": p.seat, "id": id, "phase": DefconValues.phase(p), "turn": p.turns, "options": buys.map(func(c): return c.id), "random": explored})
 return choice
func observe():
 for p in game.state.players:
  local.low[p.seat] = minf(local.low[p.seat], maxf(0, p.life))
  record("highest_life", p.life, p.seat)
  if p.alive and p.life > 0: local.last_source.erase(p.seat)
  if not p.alive and not local.dead.has(p.seat):
   if local.dead.is_empty(): person(p.seat).first_eliminated += 1
   local.dead.append(p.seat)
   var source = local.last_source.get(p.seat, -1)
   if source >= 0 and source != p.seat:
    output.eliminations[source][p.seat] += 1
    person(source).eliminations += 1
func damage(p, q, amount, _dealing):
 person(p.seat).damage_dealt += amount
 person(q.seat).damage_taken += amount
 local.damage[p.seat] += amount
 if q.life <= 0: local.last_source[q.seat] = p.seat
 else: local.last_source.erase(q.seat)
 record("biggest_hit", amount, p.seat)
 local.low[q.seat] = minf(local.low[q.seat], maxf(0, q.life))
func played(p, c):
 person(p.seat).cards_played += 1
 card(c.id).played += 1
 local.plays[p.seat][c.id] = local.plays[p.seat].get(c.id, 0) + 1
func bought(p, c):
 person(p.seat).cards_bought += 1
 card(c.id).bought += 1
 local.buys[p.seat][c.id] = local.buys[p.seat].get(c.id, 0) + 1
 if local.reserved.get(c.uid, -1) == p.seat: person(p.seat).reserved_bought += 1
func reserved(p, c):
 person(p.seat).reserves += 1
 card(c.id).reserved += 1
 local.reserved[c.uid] = p.seat
func drive(p):
 await drivers[p.seat].take_turn(p)
 observe()
func injected_error():
 var empty: Array = []
 return empty[0]
func run():
 OS.add_logger(error_counter)
 seats = env_int("SP_SEATS", 2)
 var pool = OS.get_environment("SP_POOL")
 var count = env_int("SP_GAMES", 2000)
 var first_seed = env_int("SP_SEED", 60000000)
 epsilon = float(OS.get_environment("SP_EPSILON")) if OS.has_environment("SP_EPSILON") else 0.25
 if seats not in [2, 3, 4] or pool not in ["2025", "2026"]: quit(2); return
 if OS.has_environment("SP_WEIGHTS"): DefconValues.load_weights(OS.get_environment("SP_WEIGHTS"))
 DefconSearch.fixed_rollouts = 0
 output = {"format": "selfplay-v1", "pool": pool, "seats": seats, "seed": first_seed, "games": count, "iteration": 1, "epsilon": epsilon, "stats": {}, "people": {}, "cards": {}, "records": {}, "eliminations": [], "totals": {"games": 0, "turns": 0, "draws": 0, "turn_caps": 0, "errors": 0, "conservation_failures": 0}, "failure_seeds": [], "cap_seeds": [], "error_seeds": []}
 for j in seats:
  output.people[NAMES[j]] = {"games": 0, "wins": 0, "draws": 0, "first_wins": 0, "own_turns": 0, "damage_dealt": 0, "damage_taken": 0, "life_gained": 0, "cards_played": 0, "cards_bought": 0, "hacking_spent": 0, "reserves": 0, "reserved_bought": 0, "eliminations": 0, "first_eliminated": 0}
  var row = []
  row.resize(seats); row.fill(0); output.eliminations.append(row)
 for c in root.get_node("/root/CardDB").catalog(pool).cards.values():
  if not c.starter and c.id in root.get_node("/root/CardDB").catalog(pool).pool_ids(pool): ids.append(c.id)
 ids.sort()
 ids.append("__stop__")
 for j in ids.size(): index[ids[j]] = j
 for phase in 3: fit.append({"xx": {}, "xy": {}, "count": 0})
 var started = Time.get_ticks_msec()
 for i in count:
  seed_value = first_seed + i
  rng.seed = seed_value * 100003 + 79
  error_counter.count = 0
  game = MeasuredEngine.new(); root.add_child(game)
  var levels = []; levels.resize(seats); levels.fill(3)
  game.setup(levels, seed_value, [], pool)
  local = {"low": [], "damage": [], "plays": [], "buys": [], "dead": [], "last_source": {}, "reserved": {}}
  drivers = []; decisions = []
  for j in seats:
   game.people.append(person(j))
   var measured = MeasuredDecider.new(game, 3)
   measured.counters = person(j)
   game.deciders[j] = measured
   local.low.append(game.state.players[j].life); local.damage.append(0); local.plays.append({}); local.buys.append({})
   var bot = BotPlayer.new(game); bot.purchase_policy = policy; drivers.append(bot)
  game.damage_resolved.connect(damage)
  game.card_played.connect(played); game.card_bought.connect(bought); game.card_reserved.connect(reserved)
  game.purchase_paid.connect(func(p, _c, cost): person(p.seat).hacking_spent += cost)
  game.life_gained.connect(func(p, amount): person(p.seat).life_gained += amount; record("highest_life", p.life, p.seat))
  game.state_changed.connect(observe)
  game.log_message.connect(func(message):
   if "eliminated" in message: observe())
  game.turn_driver = drive
  await game.start_turn(i % seats)
  # Optional offline fault injection verifies an errored game does not abort a shard.
  if seed_value == env_int("SP_TEST_ERROR_SEED", -1): injected_error()
  var steps = 0
  while not game.state.finished and game.state.turn < 200 and steps < 400 and error_counter.count == 0:
   await drive(game.active())
   steps += 1
  observe()
  var errored = error_counter.count > 0 or (steps >= 400 and not game.state.finished)
  var capped = not game.state.finished and not errored
  if errored:
   output.totals.errors += 1; output.error_seeds.append(seed_value)
   decisions.clear()
  var winner = game.state.winner.seat if not capped and not errored and game.state.winner != null else -1
  if capped:
   output.totals.turn_caps += 1; output.cap_seeds.append(seed_value)
  output.totals.games += 1; output.totals.turns += game.state.turn
  if winner < 0: output.totals.draws += 1
  record("longest_game", game.state.turn)
  for p in game.state.players:
   var dest = person(p.seat)
   dest.games += 1; dest.own_turns += p.turns
   record("most_damage", local.damage[p.seat], p.seat)
   if winner < 0: dest.draws += 1
   if winner == p.seat:
    dest.wins += 1
    if winner == i % seats: dest.first_wins += 1
    record("fastest_win", game.state.turn, winner, true)
    record("comeback", local.low[winner] / float(p.starting_life), winner, true)
    var best = ""; var best_count = 0
    for id in local.plays[winner]:
     if not game.db().get_card(id).starter and local.plays[winner][id] > best_count: best = id; best_count = local.plays[winner][id]
    if best != "": card(best).star += 1
    for id in local.buys[winner]:
     card(id).winner_bought += local.buys[winner][id]; card(id).winner_games_bought += 1
  var seen = {}
  for d in decisions:
   var win = 1.0 if winner == d.seat else (1.0 / seats if winner < 0 else 0.0)
   var tempo = (win - 1.0 / seats) * 2.0 / sqrt(maxf(1, game.state.players[d.seat].turns - d.turn + 1))
   var key = "%s/%s" % [d.id, d.phase]
   var buyer = "%s/%s" % [d.seat, key]
   if not output.stats.has(key): output.stats[key] = {"games": 0, "wins": 0.0, "tempo": 0.0}
   if not seen.has(buyer):
    output.stats[key].games += 1; output.stats[key].wins += win; output.stats[key].tempo += tempo; seen[buyer] = true
   if not d.random: continue
   var x = {}; var options = d.options.duplicate(); options.append("__stop__")
   for id in options: x[id] = x.get(id, 0.0) - 1.0 / options.size()
   x[d.id] = x.get(d.id, 0.0) + 1.0
   var f = fit[d.phase]; f.count += 1
   for a in x:
    f.xy[a] = f.xy.get(a, 0.0) + x[a] * ((win - 1.0 / seats) + 0.15 * tempo)
    for b in x:
     var pair = "%s,%s" % [index[a], index[b]]
     f.xx[pair] = f.xx.get(pair, 0.0) + x[a] * x[b]
  if not game.state.conservation_ok(): output.totals.conservation_failures += 1; output.failure_seeds.append(seed_value)
  game.turn_driver = Callable()
  drivers.clear()
  game.free(); game = null
  await process_frame
  if (i + 1) % 100 == 0: print("SELFPLAY %dP %s %d/%d seconds=%.2f" % [seats, pool, i + 1, count, (Time.get_ticks_msec() - started) / 1000.0])
 output["fit"] = {"ids": ids, "phases": fit}
 output["wall_seconds"] = (Time.get_ticks_msec() - started) / 1000.0
 var path = OS.get_environment("SP_OUT")
 var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
 file.store_string(JSON.stringify(output)); file.close()
 var err = DirAccess.rename_absolute(path + ".tmp", path)
 print("SELFPLAY complete seconds=%.3f conservation=%d" % [output.wall_seconds, output.totals.conservation_failures])
 quit(0 if err == OK else 1)
