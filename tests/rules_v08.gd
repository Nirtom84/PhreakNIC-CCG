class_name RulesV08
extends RulesChecks
## Official research regression scenarios; fixtures always use physical cards.
class OrderedDecider extends FixedDecider:
	var order: Array = []
	var seen: Array = []
	var split: Array = []
	var allocations: int = 0
	var card_prompts: Array = []
	var empty_split: bool = false
	func choose_cards(p, prompt: String, cards: Array, min_n: int, max_n: int) -> Array:
		card_prompts.append(prompt)
		if empty_split and "Split" in prompt: return []
		return super.choose_cards(p, prompt, cards, min_n, max_n)
	var engine
	var suite
	func choose_option(_p, prompt: String, choices: Array[String]) -> int:
		if "simultaneous" in prompt or "attached Action" in prompt:
			if suite != null:
				suite.verify(engine.busy and not SaveGame.safe(engine), "Pending order refuses saving")
				await engine.get_tree().process_frame
			for name in order:
				if name in choices:
					seen.append(name)
					return choices.find(name)
		return 0
	func allocate_prevention(_p, _amount: int, _sources: Array) -> Array:
		allocations += 1
		if suite != null:
			suite.verify(engine.busy and not SaveGame.safe(engine), "Pending prevention refuses saving")
			await engine.get_tree().process_frame
		return split
func ordered(seat: int = 0):
	var d = OrderedDecider.new()
	d.engine = e
	d.suite = test
	e.deciders[seat] = d
	return d
func normalized(text: String) -> String:
	for quote in ["“", "”"]: text = text.replace(quote, '"')
	for quote in ["‘", "’"]: text = text.replace(quote, "'")
	var regex = RegEx.new()
	regex.compile("\\s+")
	return regex.sub(text, " ", true).strip_edges()
func data_checks():
	var records = JSON.parse_string(FileAccess.get_file_as_string("res://reference/cards_transcribed.json"))
	var by_stem = {}
	for record in records: by_stem[record.file.get_file().get_basename()] = record
	check(by_stem.size() == e.db().cards.size(), "Transcription and database have same image count")
	for data in e.db().cards.values():
		var record = by_stem.get(data.image.get_file().get_basename(), {})
		check(not record.is_empty(), "Transcription image: " + data.id)
		if record.is_empty(): continue
		for field in ["name", "cost", "type_line"]: check(data[field] == record[field], "Transcribed %s: %s" % [field, data.id])
		check(data.set == ("2025" if record.set == "base" else "2026"), "Transcribed set: " + data.id)
		var printed = normalized(record.rules_text)
		# Only these three intentionally preserved printed typos may differ.
		match data.id:
			"The Fellowship of the Token Ring": printed = printed.replace("Whenver", "Whenever")
			"pTFS": printed = printed.replace("Hereos", "Heros")
			"Flesh Oprah": printed = printed.replace("{H} .You", "{H}. You")
		check(normalized(data.text) == printed, "Transcribed text: " + data.id)
func run():
	await fixture()
	data_checks()
	check(e.db().get_card("LAN Party").cost == 4, "CRT LAN Party costs four")
	check(e.db().has_subtype("Rick Astley", "Legendary Hero") and e.db().get_card("Rick Astley").type_line == "Action - Hero Legend", "Rick is legendary without changing printed type")
	check(e.db().named("_NASKEY", "_nsakey") and e.db().name_contains("_NASKEY", "NSAKEY"), "NSAKEY errata aliases match")
	var p = e.active()
	var q = e.state.players[1]
	await e.play_card(p, card("Never Gonna Let You Down"))
	check(q.life == 98, "Let You Down deals two damage")
	await e.play_card(p, card("PhreakNIC"))
	check(e.effective_cost(p, card("Rick Astley")) == maxi(0, int(e.db().get_card("Rick Astley").cost) - 2), "Legendary discount includes Rick")
	await e.play_card(p, card("_NASKEY"))
	check(not e.can_play(p, card("Even More Logo")), "NSAKEY blocks Even More Logo")
	await fixture()
	p = e.active()
	await e.play_card(p, card("Even More Logo"))
	check(not e.can_play(p, card("_NASKEY")), "Even More Logo blocks alias in reverse order")
	await fixture(3)
	p = e.active()
	q = e.state.players[1]
	var stolen = card("Botnet", "play_area", 2)
	e.take_control(stolen, q)
	e.leave_play(stolen)
	check(stolen in q.discard and stolen.owner == 1, "Control change discards to controller")
	var permanent = card("The Book", "play_area", 1)
	var reserved = card("Brimstone", "reserve", 1)
	var bottom = card("Elevator Noises", "reserve", 1)
	await e.eliminate(q)
	check(permanent in e.state.removed and q.play_area.is_empty(), "Eliminated permanents removed")
	check(q.reserve.is_empty() and e.state.center_deck.slice(0, 2).has(reserved) and e.state.center_deck.slice(0, 2).has(bottom), "Eliminated reserves under Center Deck")
	await fixture(3)
	q = e.state.players[1]
	reserved = card("Brimstone", "reserve", 1)
	for c in e.state.center_deck.duplicate(): e.move(c, e.state.removed, "removed")
	e.move(e.state.center_row[0], e.state.removed, "removed")
	await e.eliminate(q)
	check(e.state.center_row[0] == reserved and e.state.center_deck.is_empty(), "Returned reserve immediately refills empty row")
	await fixture()
	p = e.active()
	var roll = card("Rickroll")
	var grass = card("Touch Grass", "play_area")
	e.move(roll, e.state.center_deck, "center_deck")
	# Use detach/move to preserve all original UIDs when installing a row card.
	e.detach(roll)
	var displaced = e.state.center_row[0]
	e.state.center_row[0] = roll
	if displaced != null: e.state.center_deck.append(displaced)
	await e.start_turn(0)
	check(roll in e.state.center_row and p.turn_flags.get("bought", 0) == 0, "Grass blocks forced Rickroll buy")
	e.remove(grass)
	await e.start_turn(0)
	check(roll in p.discard and p.turn_flags.bought == 1, "Forced Rickroll is a real buy")
	for reverse in [false, true]:
		await fixture()
		p = e.active()
		q = e.state.players[1]
		var a = card("DeMartian")
		var b = card("m8trix310")
		await e.play_card(p, b if reverse else a)
		await e.play_card(p, a if reverse else b)
		check(p.hacking == 4 and q.life == 96, "DeMartian/m8trix bonuses in order %s" % reverse)
	for reverse in [false, true]:
		await fixture()
		p = e.active()
		var mog = card("Mog's Ice Cream")
		var rookie = card("Rookie Numbers")
		var count = p.hand.size()
		await e.play_card(p, mog if reverse else rookie)
		await e.play_card(p, rookie if reverse else mog)
		check(p.hand.size() == count - 1 + (3 if not reverse else 0), "Mog requires earlier Rookie Numbers %s" % reverse)
	await fixture()
	p = e.active()
	var walmart = card("Walmart Parking Lot", "reserve")
	check(e.effective_cost(p, walmart) > 0, "Walmart needs earlier heartsh8ped")
	await e.play_card(p, card("heartsh8ped"))
	check(e.effective_cost(p, walmart) == 0, "Walmart free after heartsh8ped")
	await fixture()
	p = e.active()
	var hits = card("FOTTR Greatest Hits", "reserve")
	await e.play_card(p, card("Bony"))
	check(e.effective_cost(p, hits) == e.db().get_card(hits.id).cost, "BONY excludes reserves")
	e.detach(hits)
	var previous = e.state.center_row[0]
	e.state.center_row[0] = hits
	e.state.center_deck.append(previous)
	check(e.effective_cost(p, hits) == 0, "BONY permits Center Row")
	check(await e.buy_card(p, hits) and p.turn_flags.free_names.is_empty(), "BONY token consumed on row buy")
	await setup_checks()
	await trigger_checks()
	await prevention_checks()
	await copy_checks()
	await oprah_checks()
	await other_rulings()
	await more_timing_checks()
	await fixture()
	p = e.active()
	var book = card("The Book", "play_area")
	var rookie = card("Rookie Numbers")
	var mog = card("Mog's Ice Cream")
	e.move(rookie, book.attached, "attached")
	e.move(mog, book.attached, "attached")
	# No other Actions can be attached; the chosen order must determine the draw bonus.
	for c in p.hand.duplicate(): e.move(c, p.deck, "deck")
	var d = ordered()
	d.order = ["Mog's Lemon Custard Ice Cream", "Rookie Numbers"]
	await e.start_turn(0)
	check(p.played.slice(0, 2) == [mog, rookie] and mog in book.attached and rookie in book.attached, "The Book plays attached Actions in chosen order")
	check(e.state.conservation_ok(), "v08 fixture conservation")
	e.free()
	e = null
	print("v08 official rules scenarios complete")
func setup_checks():
	var starts = {}
	for count in [2, 3, 4]:
		for seed_value in range(6):
			var game = GameEngine.new()
			test.root.add_child(game)
			var levels = []
			for seat in count: levels.append(2)
			game.setup(levels, seed_value)
			check(game.state.starting_life == (24 if count == 2 else count * 10), "Default starting life")
			check(game.state.players.all(func(x): return x.life == game.state.starting_life), "All seats get starting life")
			if count == 2: starts[game.state.active_seat] = true
			var copy = GameEngine.new()
			test.root.add_child(copy)
			copy.setup(levels, seed_value)
			check(copy.state.active_seat == game.state.active_seat, "Seeded first player reproducible")
			await game.start_turn()
			var restored = SaveGame.restore(SaveGame.snapshot(game.state))
			check(restored != null and restored.active_seat == game.state.active_seat and restored.starting_life == game.state.starting_life, "Save starting life and active seat")
			var snapshot = SaveGame.snapshot(game.state)
			snapshot.state.erase("starting_life")
			check(SaveGame.restore(snapshot).starting_life == game.state.starting_life, "Old saves default starting life")
			copy.free()
			game.free()
	check(starts.size() == 2, "Either seat can go first")
	var game = GameEngine.new()
	test.root.add_child(game)
	game.setup([2, 2], 12, [], "2026", 37)
	await game.start_turn()
	check(game.active().life == 37 and SaveGame.restore(SaveGame.snapshot(game.state)).starting_life == 37, "Custom starting life saves")
	var seat = game.active().seat
	await game.end_turn(game.active())
	check(game.active().seat == (seat + 1) % 2, "Seat order follows random starter")
	game.free()
func trigger_checks():
	await fixture()
	var p = e.active()
	var protection = card("Military-Grade Card Encapsulation", "play_area")
	var air = card("Clarion Inn Air Conditioning", "play_area", 1)
	var d = ordered()
	d.order = ["Clarion Inn Air Conditioning", "Military-Grade Card Encapsulation"]
	await e.start_turn(0)
	check(p.life == 100 and protection in p.discard, "Active player orders air damage before protection expires")
	await fixture()
	p = e.active()
	var network = card("The Phreaknic Network", "play_area")
	air = card("Clarion Inn Air Conditioning", "play_area", 1)
	d = ordered()
	d.order = ["Clarion Inn Air Conditioning", "The Phreaknic Network"]
	await e.start_turn(0)
	check(network in p.discard and e.state.players[1].life == 100, "Pending trigger drops after its source leaves play")
	await fixture()
	p = e.active()
	var book = card("The Book", "play_area")
	var phreak = card("PhreakMyst")
	for c in p.hand.duplicate():
		if c != phreak: e.move(c, p.deck, "deck")
	var roll = card("Rickroll")
	e.detach(roll)
	var displaced = e.state.center_row[0]
	e.state.center_row[0] = roll
	e.state.center_deck.append(displaced)
	d = ordered()
	d.order = ["The Book", "Rickroll"]
	await e.start_turn(0)
	check(phreak in book.attached and roll in e.state.center_row and p.turn_flags.get("bought", 0) == 0, "Book can forbid buying before simultaneous Rickroll resolves")
func prevention_checks():
	await fixture()
	var p = e.active()
	var q = e.state.players[1]
	var a = card("Carpeted Pool", "play_area")
	var b = card("Walmart Parking Lot", "play_area")
	a.counters = 3
	b.counters = 4
	var d = ordered()
	d.split = [1, 1]
	e.busy = true
	await e.damage(q, p, 2)
	e.busy = false
	check(a.counters == 2 and b.counters == 3 and p.life == 100 and d.allocations == 1, "Defender splits individual prevention points")
	await e.damage(q, p, 8)
	check(a in p.discard and b in p.play_area and b.counters == 0 and p.life == 97 and q.life == 99, "Mandatory ICE, overflow, last-counter text and Walmart zero")
	check(d.allocations == 1, "No allocation dialog when all ICE must be spent")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	a = card("Carpeted Pool", "play_area")
	a.counters = 3
	var guard = card("Military-Grade Card Encapsulation", "play_area")
	d = ordered()
	d.split = [0, 2]
	e.busy = true
	await e.damage(q, p, 2)
	e.busy = false
	check(a.counters == 1 and guard in p.play_area and p.life == 100, "May allocate ICE before prevent-all source")
	d.split = [0, 0]
	e.busy = true
	await e.damage(q, p, 2)
	e.busy = false
	check(p.life == 100, "Invalid allocation cannot bypass mandatory prevention")
func copy_checks():
	await fixture()
	var p = e.active()
	var q = e.state.players[1]
	var etch = card("Etch-a-Sketch Skillz")
	var source = card("PhreakMyst", "discard", 1)
	p.turn_flags.bought = 1
	e.dec(p).requested_id = source.id
	await e.play_card(p, etch)
	check(p.hacking == 6 and p.turn_flags.no_buy and p.played == [etch] and source in q.discard, "Etch ignores restrictions and keeps played identity")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	var stamp = card("Dick Van Dyke Stamp", "play_area")
	etch = card("Etch-a-Sketch Skillz")
	source = card("Hacking", "discard", 1)
	e.dec(p).requested_id = source.id
	await e.play_card(p, etch)
	check(q.life == 100 and p.hacking == 1 and not e.played_name(p, "Hacker"), "Copied Hacker text does not trigger Hacker identity")
func oprah_checks():
	await fixture(3)
	var p = e.active()
	var wonka = card("Oprah Wonka")
	for c in (p.deck + p.discard).duplicate(): e.move(c, e.state.removed, "removed")
	var small = [card("Hacking", "deck"), card("Damage", "discard")]
	await e.play_card(p, wonka)
	check(small.all(func(x): return x in p.hand), "Oprah takes all when fewer than five")
	await fixture(3)
	p = e.active()
	e.state.players[1].alive = false
	var next = ordered(2)
	next.requested_id = "Hacking"
	var skipped = ordered(1)
	skipped.requested_id = "Damage"
	wonka = card("Oprah Wonka")
	await e.play_card(p, wonka)
	check("Split cards into first pile" in next.card_prompts and skipped.card_prompts.is_empty(), "Oprah next living splitter")
	await fixture()
	p = e.active()
	var splitter = ordered(1)
	splitter.empty_split = true
	var chooser = ordered()
	chooser.selected_option = 0
	wonka = card("Oprah Wonka")
	var before = p.hand.size()
	await e.play_card(p, wonka)
	check(p.hand.size() == before - 1, "Oprah permits choosing an empty pile")

func other_rulings():
	# Buying and acquiring use separate paths even with buying prohibited.
	await fixture()
	var p = e.active()
	var q = e.state.players[1]
	var taser = card("Powered On Taser Maintenance", "play_area", 1)
	var nathan = card("itsamenathan")
	var target = card("G4nd4lf")
	e.detach(target)
	var displaced = e.state.center_row[0]
	e.state.center_row[0] = target
	e.state.center_deck.append(displaced)
	await e.play_card(p, card("PhreakMyst"))
	e.dec(p).requested_id = target.id
	await e.play_card(p, nathan)
	check(target in p.discard and p.life == 100 and p.turn_flags.get("bought", 0) == 0, "Acquire under buying prohibition does not trigger buy effects")
	check(not e.can_reserve(p, e.state.center_row[0]), "Acquisition prevents reservation")
	await fixture()
	p = e.active()
	check(e.reserve_card(p, e.state.center_row[0]), "Reserve fixture")
	var before = p.turn_flags.get("acquired", 0)
	await e.play_card(p, card("Ben the Phreak"))
	check(p.turn_flags.get("acquired", 0) == before, "Reservation blocks acquisition")
	# Costs in text remain printed despite a discount; copy retains the limit too.
	await fixture()
	p = e.active()
	var etch = card("Etch-a-Sketch Skillz")
	card("itsamenathan", "discard", 1)
	target = card("The Book")
	e.detach(target)
	displaced = e.state.center_row[0]
	e.state.center_row[0] = target
	e.state.center_deck.append(displaced)
	p.turn_flags.reductions = {"Permanent": 20}
	var d = ordered()
	d.requested_id = "itsamenathan"
	await e.play_card(p, etch)
	check(target in e.state.center_row, "Copied itsamenathan still uses printed cost four limit")
	await fixture()
	p = e.active()
	etch = card("Etch-a-Sketch Skillz")
	card("Pooping in the Dark", "discard", 1)
	d = ordered()
	d.requested_id = "Pooping in the Dark"
	var old_hand = p.hand.filter(func(x): return x != etch)
	await e.play_card(p, etch)
	check(old_hand.all(func(x): return x not in p.hand) and not "Discard to redraw" in d.card_prompts, "Copied Pooping in the Dark discards entire hand")
	# A copied combo is text, but cannot supply its partner's name to the original.
	await fixture()
	p = e.active()
	q = e.state.players[1]
	etch = card("Etch-a-Sketch Skillz")
	card("Reps4Thor", "discard", 1)
	e.dec(p).requested_id = "Reps4Thor"
	await e.play_card(p, etch)
	var life = q.life
	await e.play_card(p, card("nirtom"))
	check(q.life == life + 1 - 3 and not e.played_name(p, "Reps4Thor"), "Copied conditional text waits for partner without copied identity")
	# Hardware Hacking Village discounts only the controller's Technology buys.
	await fixture()
	p = e.active()
	q = e.state.players[1]
	card("Hardware Hacking Village", "play_area", 1)
	target = card("Dick Van Dyke Stamp")
	check(e.effective_cost(p, target) == e.db().get_card(target.id).cost and e.effective_cost(q, target) == maxi(0, int(e.db().get_card(target.id).cost) - 1), "Village controller-only discount")
	# CTF Bangers modifies each permanent damage instruction once, not life loss.
	await fixture()
	p = e.active()
	q = e.state.players[1]
	card("CTF Bangers", "play_area")
	var juice = card("The Juice", "play_area")
	juice.counters = 2
	await e.start_turn(0)
	check(q.life == 96, "CTF Bangers adds one to Juice instruction")
	await e.damage(p, q, 2, juice)
	check(q.life == 94, "Life loss receives no CTF bonus")
	# TOCTOU also replaces a fifth Juice counter loss.
	var reaction = card("TOCTOU")
	juice.counters = 4
	e.turn_driver = func(who): await e.end_turn(who)
	await e.start_turn(0)
	check(p.alive and reaction in e.state.removed, "TOCTOU replaces Juice loss")
	# CRT LAN Party skips an empty opponent and damages every tied lowest card.
	await fixture(4)
	p = e.active()
	for seat in range(1, 4):
		var opponent = e.state.players[seat]
		for c in (opponent.deck + opponent.discard).duplicate(): e.move(c, e.state.removed, "removed")
	card("Hacking", "discard", 1)
	card("Damage", "deck", 2)
	await e.play_card(p, card("LAN Party"))
	check(e.state.players[1].life == 97 and e.state.players[2].life == 97 and e.state.players[3].life == 100, "CRT reshuffles, handles ties, skips empty opponent")
	# Ruling 15 compares against any living opponent.
	await fixture(3)
	p = e.active()
	p.life = 50
	e.state.players[1].life = 40
	e.state.players[2].life = 60
	await e.play_card(p, card("Corperate Retreat"))
	check(e.state.players[1].life == 38 and e.state.players[2].life == 58, "Corporate Retreat compares with at least one living opponent")
	# Mandatory Book attachment and public in-play name checks are already shared engine paths.
	await fixture()
	p = e.active()
	card("The Juice", "play_area", 1)
	var nsakey = card("_NASKEY")
	var count = p.hand.size()
	await e.play_card(p, nsakey)
	check(p.hand.size() == count + 1 and e.state.players[1].life == 98, "NSAKEY checks Juice on either side")

func more_timing_checks():
	await fixture()
	var p = e.active()
	var q = e.state.players[1]
	var guard = card("Military-Grade Card Encapsulation", "play_area")
	var d = ordered()
	# A source that leaves and returns during a reaction still loses the old trigger.
	var pending = [
		{"name": "Departure", "resolve": func():
			e.leave_play(guard)
			e.move(guard, p.play_area, "play_area")},
		{"card": guard, "resolve": e.effects.add_hacking.bind(p, 20)}]
	d.order = ["Departure"]
	await e.resolve_triggers(pending)
	check(p.hacking == 0 and guard in p.play_area, "Departure invalidates pending trigger even after re-entry")
	await fixture()
	p = e.active()
	q = e.state.players[1]
	p.life = 2
	q.life = 2
	p.turn_flags.zenthere = 1
	card("FOTTR Greatest Hits Vol 2", "play_area", 1)
	d = ordered()
	d.order = ["Zenthere, Mind Goblin", "F.O.T.T.R. Greatest Hits Volume 2"]
	await e.end_turn(p)
	check(e.state.finished and e.state.winner == p, "Active player orders lethal end-of-turn triggers")
	# The active buyer can resolve a life-gaining buy effect before opposing Taser.
	await fixture()
	p = e.active()
	p.life = 1
	card("Powered On Taser Maintenance", "play_area", 1)
	var hero = card("Venaul")
	e.detach(hero)
	var displaced = e.state.center_row[0]
	e.state.center_row[0] = hero
	e.state.center_deck.append(displaced)
	p.hacking = 20
	d = ordered()
	d.order = [e.db().get_card(hero.id).name]
	await e.buy_card(p, hero)
	check(p.alive and p.life == 5 and not e.state.finished, "Active player orders buy effect before Taser")
	# Multi-target prevention assigns the split to the correct defender.
	await fixture(3)
	p = e.active()
	q = e.state.players[2]
	var a = card("Carpeted Pool", "play_area", 2)
	var b = card("Walmart Parking Lot", "play_area", 2)
	a.counters = 3
	b.counters = 4
	d = ordered(2)
	d.split = [0, 1]
	await e.deal(p, 1)
	check(e.state.players[1].life == 99 and q.life == 100 and a.counters == 3 and b.counters == 3, "Prevention split belongs to the correct damage target")

	# A start trigger stays pending even when it has no useful work until another resolves.
	await fixture()
	p = e.active()
	var book = card("The Book", "play_area")
	var ptfs = card("pTFS", "play_area")
	var action = card("5ud0")
	for c in p.hand.duplicate():
		if c != action: e.move(c, p.deck, "deck")
	e.move(action, ptfs.attached, "attached")
	d = ordered()
	d.order = ["pTFS", "The Book"]
	await e.start_turn(0)
	check(action in book.attached and action in p.played, "pTFS can supply an Action to a later Book trigger")

	await fixture()
	p = e.active()
	q = e.state.players[1]
	var ice = card("Carpeted Pool", "play_area")
	ice.counters = 3
	p.turn_flags.prevent_all = true
	d = ordered()
	d.split = [0, 2]
	await e.damage(q, p, 2)
	check(ice.counters == 1 and p.life == 100, "May allocate ICE even with rest-of-turn prevention active")
