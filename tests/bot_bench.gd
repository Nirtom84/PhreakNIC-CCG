extends SceneTree
## BENCH_GAMES games per matchup; BENCH_BASELINE=1 runs the frozen control.
const OldDriver = preload("res://scripts/ai/baseline/bot_player.gd")
const OldDecider = preload("res://scripts/ai/baseline/bot_decider.gd")
var failures = 0
var diagnostics: Dictionary = {}
var drivers: Array = []
var groups: Array = []
var elapsed = [0, 0]
var turns = [0, 0]
func _initialize(): call_deferred("run")
func drive(p):
	var group = groups[p.seat]
	var nested_before = elapsed[0] + elapsed[1]
	var start = Time.get_ticks_usec()
	await drivers[p.seat].take_turn(p)
	elapsed[group] += Time.get_ticks_usec() - start - (elapsed[0] + elapsed[1] - nested_before)
	turns[group] += 1
func interval(wins: int, n: int) -> String:
	var rate = float(wins) / n
	var center = (rate + 3.8416 / (2 * n)) / (1 + 3.8416 / n)
	var half = 1.96 * sqrt(rate * (1 - rate) / n + 3.8416 / (4 * n * n)) / (1 + 3.8416 / n)
	return "%.1f%% [%.1f, %.1f]" % [100 * rate, 100 * (center - half), 100 * (center + half)]
func run():
	var n = int(OS.get_environment("BENCH_GAMES")) if OS.has_environment("BENCH_GAMES") else 200
	if n < 1: quit(1); return
	for pool in ["2025", "2026"]:
		if OS.has_environment("BENCH_POOL") and OS.get_environment("BENCH_POOL") != pool: continue
		for seats in [2, 4]:
			if OS.has_environment("BENCH_SEATS") and int(OS.get_environment("BENCH_SEATS")) != seats: continue
			for level in [2, 1, 0]:
				if OS.has_environment("BENCH_LEVEL") and int(OS.get_environment("BENCH_LEVEL")) != level: continue
				elapsed = [0, 0]
				diagnostics = {}
				turns = [0, 0]
				var wins = 0
				var draws = 0
				var total_turns = 0
				for i in n:
					var e = GameEngine.new()
					root.add_child(e)
					var levels: Array = []
					for seat in seats: levels.append(level)
					e.setup(levels, 720000 + i, [], pool)
					drivers = []
					groups = []
					for seat in seats:
						var group = (seat % 2) if seats == 2 else int(((seat + i % 4) % 4) >= 2)
						groups.append(group)
						var old = group == 1 or OS.get_environment("BENCH_BASELINE") == "1"
						e.deciders[seat] = OldDecider.new(e, level) if old else BotDecider.new(e, level)
						drivers.append(OldDriver.new(e) if old else BotPlayer.new(e))
					if OS.get_environment("BENCH_TRACE") == "1":
						e.card_played.connect(func(p, c):
							if c.id == "Jenny":
								var key = "group%d Jenny plays" % groups[p.seat]
								diagnostics[key] = diagnostics.get(key, 0) + 1
								if p.hacking < 3:
									key = "group%d Jenny without 3H" % groups[p.seat]
									diagnostics[key] = diagnostics.get(key, 0) + 1)
						e.card_bought.connect(func(p, c):
							if c.id in ["Ben The Meek", "The Juice", "FOTTR Greatest Hits Vol 2", "Shell Speech", "Payphone"]:
								var key = "group%d bought %s" % [groups[p.seat], c.id]
								diagnostics[key] = diagnostics.get(key, 0) + 1)
					e.turn_driver = drive
					await e.start_turn(i % 2 if seats == 2 else (i / 4) % seats)
					while not e.state.finished and e.state.turn <= 200:
						await drive(e.active())
						if not e.state.conservation_ok():
							failures += 1
							print("FAIL: conservation pool=%s seats=%d level=%d seed=%d turn=%d" % [pool, seats, level, 720000 + i, e.state.turn])
							break
					if e.state.winner == null: draws += 1
					elif groups[e.state.winner.seat] == 0: wins += 1
					total_turns += e.state.turn
					e.free()
				print("BENCH pool=%s seats=%d level=%d n=%d new=%s draws=%d turns=%.2f ms/new=%.3f ms/old=%.3f" % [pool, seats, level, n, interval(wins, n), draws, float(total_turns) / n, elapsed[0] / maxf(1, turns[0]) / 1000, elapsed[1] / maxf(1, turns[1]) / 1000])
				if not diagnostics.is_empty(): print("DIAG ", JSON.stringify(diagnostics))
	print("Bot benchmark failures: %d" % failures)
	quit(1 if failures else 0)
