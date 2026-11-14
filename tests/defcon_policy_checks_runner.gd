extends SceneTree
var checks = 0
var failures = 0
func _initialize(): run.call_deferred()
func verify(ok, message):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", message)
func run():
 await load("res://tests/defcon_policy_checks.gd").new().run(self)
 print("DEFCON policy checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
