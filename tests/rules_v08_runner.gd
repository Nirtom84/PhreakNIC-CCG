extends SceneTree
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func verify(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
func run():
	await RulesV08.new(self).run()
	print("Rules v08 checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
