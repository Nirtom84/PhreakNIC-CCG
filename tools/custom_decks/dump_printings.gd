extends SceneTree
func _initialize():
	run.call_deferred()
func run():
	var out = []
	for p in CustomDeck.printings(): out.append(p)
	var f = FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	quit()
