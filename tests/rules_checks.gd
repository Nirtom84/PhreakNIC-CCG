class_name RulesChecks
extends RefCounted
## Focused scenarios use existing instances, so conservation includes the fixtures.
var test
var e
class FixedDecider extends Decider:
	var requested_id: String = ""
	var choose_none: bool = false
	var yes: bool = true
	var selected_option: int = 0
	var named_id: String = "Hacking"
	var confirmations: Array[String] = []
	func name_a_card(_p, _prompt: String) -> String: return named_id
	func confirm(_p, prompt: String) -> bool:
		confirmations.append(prompt)
		return yes
	func choose_option(_p, _prompt: String, _choices: Array[String]) -> int: return selected_option
	func choose_cards(_p, _prompt: String, cards: Array, min_n: int, max_n: int) -> Array:
		if choose_none and min_n == 0: return []
		for c in cards:
			if c.id == requested_id: return [c]
		return cards.slice(0, min_n if min_n > 0 else mini(1, max_n))
class AsyncDecider extends FixedDecider:
	var tree
	var engine
	var suite
	func choose_option(player, _prompt: String, _choices: Array[String]) -> int:
		suite.verify(engine.busy, "Engine locks actions while human dialog awaits")
		var other = player.hand[0] if not player.hand.is_empty() else null
		if other != null: suite.verify(not await engine.play_card(player, other), "Human dialog blocks reentrant play")
		await tree.process_frame
		return 1
func _init(suite): test = suite
func fixture(count: int = 2):
	if e != null:
		test.verify(e.state.conservation_ok(), "Focused fixture conservation")
		e.free()
	e = GameEngine.new()
	test.root.add_child(e)
	var levels: Array = []
	var deciders: Array = []
	for i in count:
		levels.append(2)
		deciders.append(FixedDecider.new())
	e.setup(levels, 991, deciders)
	# Clear random Rickroll and provide ample life without changing card identities.
	for c in e.state.center_row.duplicate():
		if c != null and c.id == "Rickroll": e.move(c, e.state.center_deck, "center_deck")
	for p in e.state.players: p.life = 100
	await e.start_turn(0)
func card(id: String, zone: String = "hand", seat: int = 0):
	for c in e.state.all_cards():
		if c.id == id:
			var p = e.state.players[seat]
			e.gain_owner(c, p)
			e.move(c, p.get(zone), zone)
			return c
	return null
func check(condition: bool, message: String): test.verify(condition, message)
func run():
	for id in ["Disassembled Sink", "FOTTR Greatest Hits", "Payphone"]:
		await fixture()
		var player = e.active()
		var source = card(id, "play_area")
		var decider = e.deciders[0]
		decider.choose_none = true
		decider.selected_option = 2
		await e.activate(player, source)
		check(not source.flags.used and e.activatable_abilities(player, source)[0].enabled, id + " cancellation preserves use")
		decider.choose_none = false
		decider.selected_option = 0
		var hand_size = player.hand.size()
		var removed_size = e.state.removed.size()
		var hacking = player.hacking
		var life = e.state.players[1].life
		await e.activate(player, source)
		check(source.flags.used and not e.activatable_abilities(player, source)[0].enabled, id + " real action consumes use")
		check(not await e.activate(player, source), id + " rejects repeat activation this turn")
		if id == "Payphone":
			check(player.hacking == hacking + 2, "Payphone hacking option")
			source.flags.used = false
			decider.selected_option = 1
			await e.activate(player, source)
			check(e.state.players[1].life == life - 2 and source.flags.used, "Payphone damage option")
		else:
			check(e.state.removed.size() == removed_size + 1, id + " removes card")
			check(player.hand.size() == hand_size if id == "Disassembled Sink" else e.state.players[1].life == life - 2, id + " applies reward")
	await fixture()
	var p = e.active()
	var q = e.state.players[1]
	check(e.state.initial_count == 170, "2-player setup has 150 center + 20 starters")
	check(e.db().has_subtype("Rick Astley", "Hero"), "Hero word matching")
	check(e.db().named("What is Truth", "Anything") and e.db().name_contains("What is Truth", "nirtom"), "Truth has every name")
	var first = card("5ud0")
	var second = card("Bitwize")
	await e.play_card(p, first)
	check(q.life == 100, "Trio waits for partner")
	await e.play_card(p, second)
	check(q.life == 98, "Both trio abilities fire in either order")
	await e.effects.combos(p)
	check(q.life == 98, "Trio only fires once per played instance")
	var ice = card("Carpeted Pool")
	await e.play_card(p, ice)
	var attack = card("Damage", "hand", 1)
	await e.damage(q, p, 5, attack, true)
	check(p.life == 98 and q.life == 97 and ice in p.discard, "ICE overflow and final-counter retaliation")
	var protection = card("Military-Grade Card Encapsulation")
	await e.play_card(p, protection)
	await e.damage(q, p, 5, attack, true)
	check(p.life == 98, "Encapsulation prevents all damage")
	var alternative_guard = card("The Phreaknic Network")
	await e.play_card(p, alternative_guard)
	e.dec(p).requested_id = "The Phreaknic Network"
	await e.damage(q, p, 1, attack, true)
	check(alternative_guard in p.discard and protection in p.play_area, "Controller chooses between full prevention sources")
	e.dec(p).requested_id = ""
	await e.start_turn(0)
	check(protection in p.discard, "Encapsulation expires at start")
	var net = card("The Phreaknic Network")
	await e.play_card(p, net)
	await e.damage(q, p, 2, attack, true)
	await e.damage(q, p, 3, attack, false)
	check(p.life == 98 and net in p.discard, "Network prevents rest-of-turn life loss")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var stolen = card("Botnet", "play_area", 1)
	e.take_control(stolen, p)
	check(stolen.owner == 1 and stolen.controller == 0, "Control does not change ownership")
	e.discard(stolen)
	check(stolen in p.discard, "Stolen permanent goes to controller discard")
	var table = card("Tableskirts")
	await e.play_card(p, table)
	await e.activate(p, table, 0)
	var pool = p.hacking
	check(not await e.activate(p, table, 0) and p.hacking == pool, "Once per turn cannot activate twice")
	var reserved = e.state.center_row[0]
	check(e.reserve_card(p, reserved), "Reserve before acquisition")
	p.hacking = 50
	check(not e.can_buy(p, reserved), "Reserve blocks subsequent buys")
	await e.play_card(p, card("Tips and tricks for Windows OS and Office365"))
	check(e.can_buy(p, reserved), "Tips permits reserve and buy")
	await e.buy_card(p, reserved)
	check(reserved not in p.reserve, "Buy reserved card")
	await fixture()
	p = e.active()
	card("Makeshift Lectern", "play_area")
	e.effects.reduce(p, "Hero", 2)
	var discount = card("Brimstone", "reserve")
	check(e.effective_cost(p, discount) == 0, "Cost reductions stack and clamp at zero")
	await e.play_card(p, card("Even More Logo"))
	var nsa = card("_NSAKey, Juiced")
	check(not e.can_play(p, nsa), "Even More Logo mutually excludes NSAKEY")
	await fixture()
	p = e.active()
	var free_source = card("Clarion Inn Staff")
	await e.play_card(p, free_source)
	var clarion = card("The Clarion Inn", "reserve")
	check(e.effective_cost(p, clarion) == 0, "Staff free-buy token")
	await e.buy_card(p, clarion)
	var coffee = card("Clarion Inn Morning Coffee", "reserve")
	check(e.effective_cost(p, coffee) == 4, "Free-buy token consumed once")
	var grass = card("Touch Grass")
	await e.play_card(p, grass)
	p.hacking = 50
	check(not e.can_buy(p, coffee), "Grass blocks purchases")
	await e.end_turn(p)
	check(grass in p.play_area, "Grass remains through played turn")
	await e.start_turn(0)
	await e.end_turn(p)
	check(grass in e.state.removed, "Grass expires after next turn")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var roll = card("Rickroll")
	await e.play_card(p, roll)
	var bought = e.state.center_row[0]
	var deck_size = e.state.center_deck.size()
	p.hacking = 100
	await e.buy_card(p, bought)
	check(roll in e.state.center_row and bought not in e.state.center_row and e.state.center_deck.size() == deck_size, "Rickroll replaces purchase without extra refill")
	await e.start_turn(1)
	check(roll.owner == 1 and q.turn_flags.get("bought", 0) == 1, "Start-of-turn mandatory Rickroll buy")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var copy = card("Etch-a-Sketch Skillz")
	var original = card("Drunk Riddler", "discard", 1)
	e.dec(p).requested_id = "Drunk Riddler"
	await e.play_card(p, copy)
	check(original in q.discard and copy in e.state.removed and q.life == 97, "Copy leaves source intact and self-removal affects copying card")
	# Custom decks can put another Etch in the target discard. A human or bot
	# repeatedly selecting it used to recurse without changing the choice set.
	await fixture()
	e.free()
	e = GameEngine.new()
	test.root.add_child(e)
	var copy_deck = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))[0]
	copy_deck.cards["Etch-a-Sketch Skillz"] = 3
	check(e.setup([2, 2], 83011518, [FixedDecider.new(), FixedDecider.new()], "2026", 0, [], copy_deck), "Custom copy fixture setup")
	await e.start_turn(0)
	p = e.active()
	q = e.state.players[1]
	var etches: Array = []
	for c in e.state.all_cards():
		if c.id == "Etch-a-Sketch Skillz": etches.append(c)
	for c in etches:
		e.gain_owner(c, q)
		e.move(c, q.discard, "discard")
	copy = etches[0]
	e.gain_owner(copy, p)
	e.move(copy, p.hand, "hand")
	e.dec(p).requested_id = "Etch-a-Sketch Skillz"
	check(await e.play_card(p, copy) and copy in p.discard and q.discard.size() == 2, "All-Etch targets resolve without recursion")
	original = (q.hand + q.deck).filter(func(c): return c.id == "Hacking")[0]
	e.move(original, q.discard, "discard")
	e.move(copy, p.hand, "hand")
	var before_copy_hack = p.hacking
	await e.play_card(p, copy)
	check(p.hacking == before_copy_hack + 1 and original in q.discard, "Copy skips redundant Etch and resolves productive target once")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var book = card("The Book", "play_area")
	var action = card("Hacking")
	e.dec(p).requested_id = "Hacking"
	await e.start_turn(0)
	check(not book.attached.is_empty() and book.attached[0].id == "Hacking" and p.hacking >= 1, "Book attaches and plays action")
	action = book.attached[0]
	e.discard(book)
	check(action in p.discard and book.attached.is_empty(), "Book releases attachments")
	var org = card("pTFS", "play_area")
	var hero = card("Venaul", "reserve")
	p.hacking = 10
	await e.buy_card(p, hero)
	check(hero in org.attached, "pTFS stores purchased hero")
	await e.start_turn(0)
	check(hero in p.hand and org.attached.is_empty(), "pTFS releases heroes at start")
	# Logs: count targeted hits, including two physical copies of the same name.
	for holders in [1, 2, 0]:
		await fixture(3)
		p = e.active()
		q = e.state.players[1]
		e.dec(p).named_id = "Botnet"
		if holders >= 1: card("Botnet", "hand", 1)
		if holders == 2: card("Botnet1", "hand", 2)
		var logs = card("I've got the Logs")
		var hand_size = p.hand.size()
		var hits: Array = []
		e.damage_incoming.connect(func(_source, target, amount, source_card):
			if source_card == logs: hits.append([target.seat, amount]))
		check(await e.play_card(p, logs), "Logs plays with %d revealers" % holders)
		var cost = int(e.db().get_card("Botnet").cost)
		check(q.life == 100 - (cost if holders >= 1 else 0) and e.state.players[2].life == 100 - (cost if holders == 2 else 0), "Logs damages only its %d revealers once" % holders)
		check(hits == ([[1, cost], [2, cost]] if holders == 2 else ([[1, cost]] if holders == 1 else [])), "Logs emits one separate hit per revealer")
		check((logs in e.state.removed) == (holders > 0), "Logs removed exactly when someone reveals")
		check(p.hand.size() == hand_size - (1 if holders > 0 else 0) and (holders > 0 or logs in p.discard), "Logs whiff draws one and stays in game")
	await fixture(3)
	p = e.active()
	q = e.state.players[1]
	e.dec(p).named_id = "Jenny"
	card("What is Truth", "hand", 1)
	var truth_logs = card("I've got the Logs")
	await e.play_card(p, truth_logs)
	check(q.life == 100 - int(e.db().get_card("Jenny").cost) and e.state.players[2].life == 100 and truth_logs in e.state.removed, "Truth always reveals the named card to Logs")
	# Choose either simultaneous trigger first; saying yes must cause only one redirect.
	for order in [0, 1]:
		await fixture()
		p = e.active()
		card("The Fellowship of the Token Ring", "play_area")
		var fore = card("Fore04", "reserve")
		e.dec(p).selected_option = order
		e.dec(p).confirmations.clear()
		var moves: Array = []
		e.card_moved.connect(func(moved, origin, destination):
			if moved == fore: moves.append([origin, destination]))
		p.hacking = 100
		check(await e.buy_card(p, fore), "Fore04 buys with Fellowship")
		check((fore in p.hand) != (fore in p.deck), "Fore04 ends in exactly one destination")
		check((fore in p.deck) == (order == 0) and fore not in p.discard, "Controller selects Fore04 destination by trigger order")
		check(e.dec(p).confirmations == (["Put bought card on deck?"] if order == 0 else ["Put bought hero in hand?"]), "Second destination prompt suppressed")
		check(moves.size() == 2, "Fore04 moves once into discard and redirects only once")
	# JousterL: "you may put a card from your discard pile on top of your deck", itself included;
	# G4nd4lf says "another card". On the deck, JousterL has its one destination, even with pTFS.
	for id in ["JousterL", "G4nd4lf", "pTFS"]:
		await fixture()
		p = e.active()
		if id == "pTFS": card("pTFS", "play_area")
		var bought_hero = card("G4nd4lf" if id == "G4nd4lf" else "JousterL", "reserve")
		e.dec(p).requested_id = bought_hero.id
		e.dec(p).confirmations.clear()
		p.hacking = 10
		await e.buy_card(p, bought_hero)
		var on_top = not p.deck.is_empty() and p.deck.back() == bought_hero
		match id:
			"JousterL": check(on_top, "JousterL can put itself on top of the deck")
			"G4nd4lf": check(not on_top and bought_hero in p.discard, "G4nd4lf can't put itself on top of the deck")
			"pTFS": check(on_top and e.dec(p).confirmations.is_empty(), "JousterL put on top of the deck isn't also stored on pTFS")
	# Egg in Your Soup adds its 2 ICE counters to one Sandwich Factory, the player's pick.
	await fixture()
	p = e.active()
	var factory = card("The Sandwich Factory")
	await e.play_card(p, factory)
	var restaurant = card("[Restaurant Name] Restaurant")
	e.dec(p).requested_id = "The Sandwich Factory"
	await e.play_card(p, restaurant)   # comes into play as a copy of the Sandwich Factory
	e.dec(p).requested_id = restaurant.id
	await e.play_card(p, card("Egg in Your Soup"))
	check(restaurant.effect_id() == "The Sandwich Factory" and restaurant.counters == 4 and factory.counters == 2, "Egg in Your Soup adds 2 ICE counters to the one Sandwich Factory picked")
	# Every discard-into-deck shuffle reports each card, as draw() does (the table's shuffle sound).
	for id in ["Lightning Talks", "LAN Party", "Speakers Needed"]:
		await fixture()
		p = e.active()
		var shuffler = e.state.players[1] if id == "LAN Party" else p
		for c in shuffler.deck.duplicate(): e.move(c, shuffler.discard, "discard")
		var expected = shuffler.discard.size()
		var reported: Array = []
		e.card_moved.connect(func(moved, origin, destination):
			if origin == "discard" and destination == "deck" and moved.owner == shuffler.seat: reported.append(moved))
		await e.play_card(p, card(id))
		check(expected == 5 and reported.size() == expected, "%s reports each card it shuffles from the discard pile into the deck" % e.db().get_card(id).name)
	# Flesh Oprah: the free buy needs a buyable O.P.R.A.H.; with none, the prompt must say so.
	await fixture()
	p = e.active()
	for c in e.state.center_row.duplicate():
		if c != null and c.id == "O.P.R.A.H.": e.move(c, e.state.center_deck, "center_deck")
	var flesh = card("Flesh Oprah")
	e.dec(p).yes = false
	e.dec(p).confirmations.clear()
	await e.play_card(p, flesh)
	check(e.dec(p).confirmations.size() == 1 and "not in the Center Row" in e.dec(p).confirmations[0], "Flesh Oprah warns when no O.P.R.A.H. can be bought")
	check(flesh not in e.state.removed and not p.turn_flags.get("free_names", []).has("O.P.R.A.H."), "Declining keeps Flesh Oprah and grants nothing")
	await fixture()
	p = e.active()
	var oprah = card("O.P.R.A.H.", "reserve")
	flesh = card("Flesh Oprah")
	e.dec(p).yes = true
	e.dec(p).confirmations.clear()
	await e.play_card(p, flesh)
	check(e.dec(p).confirmations == ["Remove this for a free O.P.R.A.H.?"] and flesh in e.state.removed, "Flesh Oprah offers the plain prompt when O.P.R.A.H. is buyable")
	p.hacking = 0
	check(await e.buy_card(p, oprah) and oprah.owner == p.seat and oprah not in p.reserve, "The free O.P.R.A.H. buy works with no Hacking")
	await fixture(3)
	p = e.active()
	q = e.state.players[1]
	var third = e.state.players[2]
	var reaction = card("TOCTOU", "hand", 1)
	p.hacking = 7
	p.turn_flags.marker = 42
	var resumed: Array = []
	e.turn_driver = func(who):
		resumed.append(who.seat)
		await e.end_turn(who)
	await e.damage(p, q, 101)
	check(q.alive and q.life == 1 and reaction in e.state.removed, "TOCTOU prevents elimination")
	check(resumed == [1] and e.active() == p and p.hacking == 7 and p.turn_flags.marker == 42, "TOCTOU resumes paused turn resources")
	var time = card("Time Travel")
	await e.play_card(p, time)
	await e.activate(p, time)
	await e.end_turn(p)
	check(e.active() == p and time in e.state.removed, "Time Travel schedules extra turn")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	p.life = 1
	q.life = 1
	await e.play_card(p, card("r0nk"))
	check(e.state.finished and e.state.winner == null and not p.alive and not q.alive, "Simultaneous self-and-opponent death is draw")
	await fixture()
	p = e.active()
	var async_decider = AsyncDecider.new()
	async_decider.tree = test
	async_decider.engine = e
	async_decider.suite = test
	e.deciders[0] = async_decider
	p.is_bot = false
	var before_life = e.state.players[1].life
	await e.play_card(p, card("heartsh8ped"))
	check(e.state.players[1].life == before_life - 1 and not e.busy, "Async human choice resumes effect")
	await fixture()
	p = e.active()
	var juice = card("The Juice", "play_area")
	juice.counters = 4
	await e.start_turn(0)
	check(not p.alive and e.state.finished, "Fifth Juice counter loses")
	await fixture()
	p = e.active()
	var cart = card("Lowes Shopping Cart", "play_area")
	cart.counters = 24
	p.hacking = 1
	await e.activate(p, cart)
	check(e.state.finished and e.state.winner == p, "25th Cart counter wins")
	# Ruling 26 (issue #6): the overflow reaches life before Carpeted Pool's last-counter text resolves.
	await fixture()
	p = e.active()
	q = e.state.players[1]
	p.life = 1
	q.life = 3
	var last_pool = card("Carpeted Pool", "play_area", 1)
	last_pool.counters = 1
	await e.damage(p, q, 4, card("Damage"), true)
	check(not q.alive and e.state.finished and e.state.winner == p and p.life == 1, "Overflow lands before the last-counter text (Ruling 26)")
	# Ruling 27 (issue #7): a Rickroll that left the discard pile replaces nothing.
	await fixture()
	p = e.active()
	var gone_roll = card("Rickroll")
	await e.play_card(p, gone_roll)
	check(gone_roll in p.discard, "Played Rickroll waits in the discard pile")
	e.remove(gone_roll)
	var plain_buy = e.state.center_row[0]
	p.hacking = 100
	await e.buy_card(p, plain_buy)
	check(gone_roll in e.state.removed and gone_roll not in e.state.center_row and plain_buy in p.discard and not p.turn_flags.has("rickroll"), "Removed Rickroll replaces nothing and is used up (Ruling 27)")
	# Ruling 28 (issue #8): a Restaurant copying The Clarion Inn costs 6 for Talks Fun Police.
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var restaurant = card("[Restaurant Name] Restaurant", "play_area", 1)
	restaurant.flags.copy_id = "The Clarion Inn"
	var plain_restaurant = card("Clarion Inn Staff", "play_area", 0)
	await e.play_card(p, card("Talks Fun Police"))
	check(restaurant in q.play_area and plain_restaurant in p.discard, "A copy uses the copied card's cost for Talks Fun Police (Ruling 28)")
	check(e.state.conservation_ok(), "Final focused fixture conservation")
	e.free()
	e = null
	print("Focused rules scenarios complete")
