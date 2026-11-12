extends SceneTree
## Counts all turn_started signals, including reactions; delay uses actual owner turns.
## RESERVE_GAMES (default 40), BENCH_POOL / BENCH_SEATS / BENCH_LEVEL filters.
func _initialize(): call_deferred("run")
func run():
 DefconSearch.fixed_rollouts = 1
 var n = int(OS.get_environment("RESERVE_GAMES")) if OS.has_environment("RESERVE_GAMES") else 40
 if n < 1: quit(1); return
 for pool in ["2025", "2026"]:
  if OS.has_environment("BENCH_POOL") and OS.get_environment("BENCH_POOL") != pool: continue
  for seats in [2, 4]:
   if OS.has_environment("BENCH_SEATS") and int(OS.get_environment("BENCH_SEATS")) != seats: continue
   for level in [3, 2, 1, 0]:
    if OS.has_environment("BENCH_LEVEL") and int(OS.get_environment("BENCH_LEVEL")) != level: continue
    var stats = {"turns": 0, "reserves": 0, "bought": 0, "delay": 0, "games": 0, "unbought": {}, "capped": 0}
    for i in n:
     var e = GameEngine.new()
     root.add_child(e)
     var levels: Array = []
     for seat in seats: levels.append(level)
     e.setup(levels, 820000 + i, [], pool)
     var pending: Dictionary = {}
     var player_turns: Dictionary = {}
     e.turn_started.connect(func(p):
      stats.turns += 1
      player_turns[p.seat] = player_turns.get(p.seat, 0) + 1)
     var seen = {"reserve": false}
     e.card_reserved.connect(func(p, c):
      stats.reserves += 1
      seen.reserve = true
      pending[c.uid] = {"seat": p.seat, "turn": player_turns.get(p.seat, 0)})
     e.card_bought.connect(func(p, c):
      if pending.has(c.uid) and pending[c.uid].seat == p.seat:
       stats.bought += 1
       stats.delay += player_turns.get(p.seat, 0) - pending[c.uid].turn
       pending.erase(c.uid))
     var driver = BotPlayer.new(e)
     await e.start_turn(i % seats)
     while not e.state.finished and e.state.turn <= 200:
      await driver.take_turn(e.active())
     if seen.reserve: stats.games += 1
     if not e.state.finished: stats.capped += 1
     if not e.state.conservation_ok():
      push_error("Reserve statistics conservation failure")
      quit(1)
      return
     for uid in pending:
      var card = e.state.all_cards().filter(func(c): return c.uid == uid)
      if not card.is_empty(): stats.unbought[card[0].id] = stats.unbought.get(card[0].id, 0) + 1
     e.free()
    print("RESERVE pool=%s seats=%d level=%d games=%d turns=%d reserves=%d/game=%.2f games_with=%.1f%% bought=%d never=%d bought_rate=%.1f%% delay=%.2f owner_turns capped=%d" % [pool, seats, level, n, stats.turns, stats.reserves, float(stats.reserves) / n, 100.0 * stats.games / n, stats.bought, stats.reserves - stats.bought, 100.0 * stats.bought / maxf(1, stats.reserves), stats.delay / maxf(1, stats.bought), stats.capped])
    if OS.get_environment("RESERVE_TRACE") == "1": print("UNBOUGHT ", stats.unbought)
 quit()
