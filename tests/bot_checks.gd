extends SceneTree
var failures = 0
var checks = 0
func _initialize(): call_deferred("run")
func verify(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)
func spend_fixture(old: bool) -> int:
	var e = GameEngine.new()
	root.add_child(e)
	e.setup([2, 2], 8765)
	await e.start_turn(0)
	var p = e.active()
	for c in p.hand.duplicate(): e.discard(c)
	for c in p.deck.duplicate(): e.discard(c)
	var show = e.state.center_deck.filter(func(c): return c.id == "Non-Infringing Game Show")[0]
	e.gain_owner(show, p)
	e.move(show, p.hand, "hand")
	for c in p.discard.duplicate():
		if c.id == "Hacking": e.move(c, p.hand, "hand")
	var q = e.state.players[1]
	q.life = 20
	if old:
		e.deciders[0] = preload("res://scripts/ai/baseline/bot_decider.gd").new(e, 2)
		await preload("res://scripts/ai/baseline/bot_player.gd").new(e).take_turn(p)
	else:
		await BotPlayer.new(e).take_turn(p)
	var dealt = 20 - q.life
	e.free()
	return dealt
func run():
	var old_damage = await spend_fixture(true)
	var new_damage = await spend_fixture(false)
	print("Game Show fixture damage: baseline=%d new=%d" % [old_damage, new_damage])
	verify(new_damage == 3 and new_damage > old_damage, "Generate resources before Game Show spends them")
	var e = GameEngine.new()
	root.add_child(e)
	e.setup([2, 2], 8765)
	await e.start_turn(0)
	var p = e.active()
	var q = e.state.players[1]
	for c in p.hand.duplicate(): e.discard(c)
	for c in p.deck.duplicate(): e.discard(c)
	for c in p.discard.duplicate():
		if c.id == "Hacking": e.move(c, p.hand, "hand")
	var jenny = e.state.center_deck.filter(func(c): return c.id == "Jenny")[0]
	e.gain_owner(jenny, p)
	e.move(jenny, p.hand, "hand")
	q.life = 20
	await BotPlayer.new(e).take_turn(p)
	verify(q.life == 12, "Jenny spends eight Hacking generated before her play")
	verify(e.state.conservation_ok(), "Ordered turn conserves cards")
	var own = e.state.center_deck.filter(func(c): return c.id == "The Book")[0]
	var enemy = e.state.center_deck.filter(func(c): return c.id == "Botnet")[0]
	e.gain_owner(own, p)
	e.move(own, p.play_area, "play_area")
	e.gain_owner(enemy, q)
	e.move(enemy, q.play_area, "play_area")
	var selected = await e.dec(p).choose_cards(p, "Take control of permanent", [own, enemy], 1, 1)
	verify(selected == [enemy], "Steal an enemy permanent instead of selecting our more valuable Book")
	var baseline = preload("res://scripts/ai/baseline/bot_decider.gd").new(e, 2)
	var old_selection = await baseline.choose_cards(p, "Take control of permanent", [own, enemy], 1, 1)
	verify(old_selection == [own], "Frozen policy reproduces wasted theft on its own Book")
	var basics = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Hacking")
	selected = await e.dec(p).choose_cards(p, "Remove cards from game", basics, 0, basics.size())
	verify(selected.size() == 2, "Optional thinning keeps six total Hacking before replacement economy exists")
	var attacks = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Damage")
	selected = await e.dec(p).choose_cards(p, "Remove cards from game", attacks, 0, attacks.size())
	verify(selected.is_empty(), "Keep starter attacks until replacement offense exists")
	var stamp = e.state.center_deck.filter(func(c): return c.id == "Dick Van Dyke Stamp")[0]
	e.gain_owner(stamp, p)
	e.move(stamp, p.play_area, "play_area")
	var hacker = (p.hand + p.deck + p.discard).filter(func(c): return c.id == "Hacking")[0]
	selected = await e.dec(p).choose_cards(p, "Remove cards from game", [hacker], 0, 1)
	verify(selected.is_empty(), "Keep Hackers that power Dick Van Dyke Stamp")
	e.free()
	print("Bot checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
