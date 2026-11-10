## Renders the table after N auto-played human turns and saves a PNG (needs a display, not --headless).
## Usage: godot4.7.1 --path . -s tools/screenshot.gd --resolution 1920x1080 -- <out.png> [turns] [hand]
## Pass "hand" to stop at the start of the last human turn with the hand still full.
extends SceneTree
var table
func _initialize(): run.call_deferred()
func answer():
	while is_instance_valid(table):
		await process_frame
		if not is_instance_valid(table) or not table.pending: continue
		var overlay = table.get_child(table.get_child_count() - 1)
		if not overlay is PanelContainer: continue
		var box = overlay.get_child(0)
		var grid = box.get_child(3).get_child(0)
		var done = box.get_child(4)
		if done.visible:
			var minimum = int(box.get_child(2).text.trim_prefix("Select ").split("–")[0])
			for i in minimum: grid.get_child(i).pressed.emit()
			done.pressed.emit()
		elif grid.get_child_count() > 0: grid.get_child(0).pressed.emit()
func run():
	var args = OS.get_cmdline_user_args()
	var out: String = args[0]
	var target: int = int(args[1]) if args.size() > 1 else 8
	var keep_hand: bool = args.size() > 2 and args[2] == "hand"
	# Auto-end would end the last turn during the wait below and catch the bot mid-turn; switch it off for this run only (not saved).
	root.get_node("Sfx").auto_end_turn = false
	table = load("res://scenes/table.tscn").instantiate()
	root.add_child(table)
	table.fast = true
	answer()
	for f in 30: await process_frame
	var turns := 0
	while turns < target and not table.engine.state.finished:
		await process_frame
		if table.engine.active().seat == 0 and table.available():
			if keep_hand and turns == target - 1: break
			await table.play_all()
			var p = table.engine.state.players[0]
			var buys = table.engine.state.center_row.filter(func(c): return c != null and table.engine.can_buy(p, c))
			buys.sort_custom(func(a, b): return table.engine.effective_cost(p, a) > table.engine.effective_cost(p, b))
			if not buys.is_empty(): await table.engine.buy_card(p, buys[0])
			turns += 1
			if turns < target: await table.end_human_turn()
	await create_timer(3.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
