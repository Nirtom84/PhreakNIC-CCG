extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var hashes = {}
 for level in 3:
  for pool in ["2025", "2026", "2026mog"]:
   for seed_value in [77101, 77102, 77103]:
    var game = GameEngine.new()
    root.add_child(game)
    game.setup([level, level], seed_value, [], pool)
    var driver = BotPlayer.new(game)
    game.turn_driver = func(p): await driver.take_turn(p)
    await game.start_turn()
    for turn in 200:
     if game.state.finished or game.state.turn > 200: break
     await driver.take_turn(game.active())
    hashes["%d/%s/%d" % [level, pool, seed_value]] = JSON.stringify(SaveGame.snapshot(game.state)).sha256_text()
    game.turn_driver = Callable()
    game.free()
 var path = "res://tests/defcon_trace_hashes.json"
 if "--record" in OS.get_cmdline_user_args():
  FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(hashes, " "))
  print("Recorded %d pre-change trace hashes" % hashes.size())
 else:
  var expected = JSON.parse_string(FileAccess.get_file_as_string(path))
  var failures = 0
  for key in hashes:
   if hashes[key] != expected.get(key): failures += 1; print("FAIL trace ", key)
  print("DEFCON legacy traces: %d checks, %d failures" % [hashes.size(), failures])
  quit(1 if failures else 0)
  return
 quit()
