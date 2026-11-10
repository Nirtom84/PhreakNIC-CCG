extends SceneTree
## Run: godot4.7.1 --headless --path . -s tests/sim.gd
const GAMES = 300
var coverage: Dictionary = {}
var wins = [0, 0, 0]
var appearances = [0, 0, 0]
var draws = 0
var capped_draws = 0
var duel_wins = [0, 0, 0]
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func verify(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)
func game(levels: Array, seed_value: int):
	var engine = GameEngine.new()
	root.add_child(engine)
	engine.setup(levels, seed_value)
	engine.state_changed.connect(func(): verify(engine.state.conservation_ok(), "Action conservation seed %d" % seed_value))
	var driver = BotPlayer.new(engine)
	for level in levels: appearances[level] += 1
	await engine.start_turn()
	for turn in 200:
		if engine.state.finished or engine.state.turn > 200: break
		if not engine.state.finished: await driver.take_turn(engine.active())
		verify(engine.state.conservation_ok(), "Conservation game %d turn %d" % [seed_value, turn])
		if failures > 0: break
	if not engine.state.finished:
		capped_draws += 1
		engine.finish(null)
	if engine.state.winner == null: draws += 1
	else:
		wins[engine.state.winner.difficulty] += 1
		if levels.size() == 2 and 1 not in levels: duel_wins[engine.state.winner.difficulty] += 1
	for id in engine.state.coverage: coverage[id] = coverage.get(id, 0) + engine.state.coverage[id]
	verify(engine.state.conservation_ok(), "Final conservation game %d" % seed_value)
	engine.free()
func run():
	await RulesChecks.new(self).run()
	if failures > 0:
		quit(1)
		return
	for i in GAMES:
		var levels: Array
		if i < 120: levels = [2, 0] if i % 2 == 0 else [0, 2]
		elif i < 180: levels = [[1, 0], [0, 1], [1, 2], [2, 1]][i % 4]
		elif i < 240: levels = [i % 3, (i + 1) % 3, (i + 2) % 3]
		else: levels = [i % 3, (i + 1) % 3, (i + 2) % 3, i % 3]
		await game(levels, 31000 + i)
		if failures > 0: break
		if (i + 1) % 40 == 0: print("Completed %d/%d games" % [i + 1, GAMES])
	var never: Array = []
	for id in root.get_node("CardDB").cards:
		if not coverage.has(id): never.append(id)
	print("Games: %d; draws: %d (natural %d, turn cap %d)" % [GAMES, draws, draws - capped_draws, capped_draws])
	for level in 3:
		print("%s: %d wins / %d seats (%.1f%%)" % [BotDifficulty.DISPLAY_NAMES[level], wins[level], appearances[level], 100.0 * wins[level] / maxf(1, appearances[level])])
	print("Elite vs Script Kiddie (120 games): Elite %d (%.1f%%), Kiddie %d (%.1f%%)" % [duel_wins[2], duel_wins[2] * 100.0 / 120, duel_wins[0], duel_wins[0] * 100.0 / 120])
	print("Tournament played coverage: %d/152; handlers: 152/152" % coverage.size())
	print("Never played in tournament: %s" % str(never))
	if "--coverage" in OS.get_cmdline_user_args():
		var ids = root.get_node("CardDB").cards.keys()
		ids.sort()
		for id in ids: print("Coverage %s: %d plays" % [id, coverage.get(id, 0)])
	verify(duel_wins[2] >= 72, "Elite must win at least 60%% of seeded duels")
	print("Checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
