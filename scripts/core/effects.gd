class_name CardEffects
extends RefCounted
## Each stable data id maps to its own handler. Shared mechanics live below.
const RICK_ART = ["Rick Astley", "Rickroll", "Never Gonna Give You Up", "Never Gonna Let You Down"]
var e
var handlers: Dictionary = {}
func _init(engine):
	e = engine
	handlers["5ud0"] = _effect_5ud0
	handlers["[Restaurant Name] Restaurant"] = _effect_restaurant_name_restaurant
	handlers["_NASKEY"] = _effect_naskey
	handlers["_NSAKey, Juiced"] = _effect_nsakey_juiced
	handlers["AI Bens AI Camry"] = _effect_ai_bens_ai_camry
	handlers["AI Slop"] = _effect_ai_slop
	handlers["Altk3y"] = _effect_altk3y
	handlers["Bedtime Story"] = _effect_bedtime_story
	handlers["Ben The Meek"] = _effect_ben_the_meek
	handlers["Ben the Phreak"] = _effect_ben_the_phreak
	handlers["Bitwize"] = _effect_bitwize
	handlers["Bony"] = _effect_bony
	handlers["Botnet"] = _effect_botnet
	handlers["Botnet Takeover"] = _effect_botnet_takeover
	handlers["Botnet1"] = _effect_botnet1
	handlers["Botnet2"] = _effect_botnet2
	handlers["Botnet3"] = _effect_botnet3
	handlers["Botnet4"] = _effect_botnet4
	handlers["Bribery"] = _effect_bribery
	handlers["Brimstone"] = _effect_brimstone
	handlers["Brimstone, Fabulous"] = _effect_brimstone_fabulous
	handlers["c14ud3"] = _effect_c14ud3
	handlers["Candy Factory"] = _effect_candy_factory
	handlers["Capture the Flag"] = _effect_capture_the_flag
	handlers["Carpeted Pool"] = _effect_carpeted_pool
	handlers["Clarion Inn Air Conditioning"] = _effect_clarion_inn_air_conditioning
	handlers["Clarion Inn Breakfast"] = _effect_clarion_inn_breakfast
	handlers["Clarion Inn Chandeliers"] = _effect_clarion_inn_chandeliers
	handlers["Clarion Inn Closet"] = _effect_clarion_inn_closet
	handlers["Clarion Inn Morning Coffee"] = _effect_clarion_inn_morning_coffee
	handlers["Clarion Inn Staff"] = _effect_clarion_inn_staff
	handlers["Corperate Retreat"] = _effect_corperate_retreat
	handlers["Corporate SWAG Table"] = _effect_corporate_swag_table
	handlers["crook3dfingers"] = _effect_crook3dfingers
	handlers["CTF Bangers"] = _effect_ctf_bangers
	handlers["cybermonkey"] = _effect_cybermonkey
	handlers["Damage"] = _effect_damage
	handlers["DeMartian"] = _effect_demartian
	handlers["Dick Van Dyke Stamp"] = _effect_dick_van_dyke_stamp
	handlers["Disassembled Sink"] = _effect_disassembled_sink
	handlers["Doom on a Trading Card"] = _effect_doom_on_a_trading_card
	handlers["Drunk Riddler"] = _effect_drunk_riddler
	handlers["Egg in Your Soup"] = _effect_egg_in_your_soup
	handlers["Elevator Noises"] = _effect_elevator_noises
	handlers["Elonka"] = _effect_elonka
	handlers["Employee Review"] = _effect_employee_review
	handlers["Empty Lockpicking Table"] = _effect_empty_lockpicking_table
	handlers["errorgone"] = _effect_errorgone
	handlers["Etch-a-Sketch Skillz"] = _effect_etch_a_sketch_skillz
	handlers["Even More Logo"] = _effect_even_more_logo
	handlers["evildagmar"] = _effect_evildagmar
	handlers["Filler"] = _effect_filler
	handlers["Fivrr Friendship"] = _effect_fivrr_friendship
	handlers["Flesh Oprah"] = _effect_flesh_oprah
	handlers["Fore04"] = _effect_fore04
	handlers["FOTTR Greatest Hits"] = _effect_fottr_greatest_hits
	handlers["FOTTR Greatest Hits Vol 2"] = _effect_fottr_greatest_hits_vol_2
	handlers["Foundation of Time Temporal Reconstruction"] = _effect_foundation_of_time_temporal_reconstruction
	handlers["Fred Rogers"] = _effect_fred_rogers
	handlers["G4nd4lf"] = _effect_g4nd4lf
	handlers["Hacking"] = _effect_hacking
	handlers["Hardware Hacking Village"] = _effect_hardware_hacking_village
	handlers["hardwarez"] = _effect_hardwarez
	handlers["heartsh8ped"] = _effect_heartsh8ped
	handlers["hfuller"] = _effect_hfuller
	handlers["Hotel Roof Chair Toss"] = _effect_hotel_roof_chair_toss
	handlers["I've got the Logs"] = _effect_i_ve_got_the_logs
	handlers["itsamenathan"] = _effect_itsamenathan
	handlers["Jenny"] = _effect_jenny
	handlers["John Titor"] = _effect_john_titor
	handlers["JousterL"] = _effect_jousterl
	handlers["Kevin Mitnick Cardboard Cutout"] = _effect_kevin_mitnick_cardboard_cutout
	handlers["Kevin's Desk"] = _effect_kevin_s_desk
	handlers["LAN Party"] = _effect_lan_party
	handlers["Lightning Talks"] = _effect_lightning_talks
	handlers["Lowes Shopping Cart"] = _effect_lowes_shopping_cart
	handlers["m8trix310"] = _effect_m8trix310
	handlers["Makeshift Lectern"] = _effect_makeshift_lectern
	handlers["Merry Christmas"] = _effect_merry_christmas
	handlers["Military-Grade Card Encapsulation"] = _effect_military_grade_card_encapsulation
	handlers["mog"] = _effect_mog
	handlers["Mog's Ice Cream"] = _effect_mog_s_ice_cream
	handlers["Mogs Pancake Breakfast"] = _effect_mogs_pancake_breakfast
	handlers["Nashville 2600"] = _effect_nashville_2600
	handlers["Never Gonna Give You Up"] = _effect_never_gonna_give_you_up
	handlers["Never Gonna Let You Down"] = _effect_never_gonna_let_you_down
	handlers["nirtom"] = _effect_nirtom
	handlers["Nirtom Unleashed"] = _effect_nirtom_unleashed
	handlers["Non-Infringing Game Show"] = _effect_non_infringing_game_show
	handlers["notlarry"] = _effect_notlarry
	handlers["NotLarry Cardboard Cutout"] = _effect_notlarry_cardboard_cutout
	handlers["Number One PhreakNIC Rule"] = _effect_number_one_phreaknic_rule
	handlers["Nuvious"] = _effect_nuvious
	handlers["O.P.R.A.H."] = _effect_o_p_r_a_h
	handlers["Oprah Wonka"] = _effect_oprah_wonka
	handlers["OSINT for Dummies"] = _effect_osint_for_dummies
	handlers["Payphone"] = _effect_payphone
	handlers["Payphone Dave"] = _effect_payphone_dave
	handlers["Payphone Karaoke"] = _effect_payphone_karaoke
	handlers["PhreakMyst"] = _effect_phreakmyst
	handlers["PhreakNIC"] = _effect_phreaknic
	handlers["Phreaknic Website Refresh"] = _effect_phreaknic_website_refresh
	handlers["Pooping in the Dark"] = _effect_pooping_in_the_dark
	handlers["pouipoui"] = _effect_pouipoui
	handlers["pouipoui, AV Guy"] = _effect_pouipoui_av_guy
	handlers["Powered On Taser Maintenance"] = _effect_powered_on_taser_maintenance
	handlers["proudF00F"] = _effect_proudf00f
	handlers["pTFS"] = _effect_ptfs
	handlers["r0nk"] = _effect_r0nk
	handlers["randy"] = _effect_randy
	handlers["Registration"] = _effect_registration
	handlers["Reps4Thor"] = _effect_reps4thor
	handlers["Reverse Shell"] = _effect_reverse_shell
	handlers["Rick Astley"] = _effect_rick_astley
	handlers["Rickroll"] = _effect_rickroll
	handlers["Rookie Numbers"] = _effect_rookie_numbers
	handlers["Share a Link"] = _effect_share_a_link
	handlers["Shell Speech"] = _effect_shell_speech
	handlers["Should have Preregistered"] = _effect_should_have_preregistered
	handlers["Speakers Needed"] = _effect_speakers_needed
	handlers["Sticky Fingers"] = _effect_sticky_fingers
	handlers["Still Not Spock"] = _effect_still_not_spock
	handlers["Super r0nk"] = _effect_super_r0nk
	handlers["Tableskirts"] = _effect_tableskirts
	handlers["Talks Fun Police"] = _effect_talks_fun_police
	handlers["Tennessee Department of Health"] = _effect_tennessee_department_of_health
	handlers["The Big Dipper"] = _effect_the_big_dipper
	handlers["The Book"] = _effect_the_book
	handlers["The Clarion Inn"] = _effect_the_clarion_inn
	handlers["The Fellowship of the Token Ring"] = _effect_the_fellowship_of_the_token_ring
	handlers["The Juice"] = _effect_the_juice
	handlers["The Phreaknic Network"] = _effect_the_phreaknic_network
	handlers["The Reason"] = _effect_the_reason
	handlers["The Sandwich Factory"] = _effect_the_sandwich_factory
	handlers["The Tone Whisperer"] = _effect_the_tone_whisperer
	handlers["Time Travel"] = _effect_time_travel
	handlers["Tips and tricks for Windows OS and Office365"] = _effect_tips_and_tricks_for_windows_os_and_office365
	handlers["tipsybacchus"] = _effect_tipsybacchus
	handlers["TOCTOU"] = _effect_toctou
	handlers["Touch Grass"] = _effect_touch_grass
	handlers["Treasure Hunters"] = _effect_treasure_hunters
	handlers["Two Hump Camel"] = _effect_two_hump_camel
	handlers["Tyler Crumpton"] = _effect_tyler_crumpton
	handlers["Unattended Phone"] = _effect_unattended_phone
	handlers["Under New Management"] = _effect_under_new_management
	handlers["Venaul"] = _effect_venaul
	handlers["Walmart Parking Lot"] = _effect_walmart_parking_lot
	handlers["What is Truth"] = _effect_what_is_truth
	handlers["Wheres Apache"] = _effect_wheres_apache
	handlers["White Python Boots"] = _effect_white_python_boots
	handlers["zalphaWolf"] = _effect_zalphawolf
	handlers["Zenthere, Mind Goblin"] = _effect_zenthere_mind_goblin
	for id in ["Mognet", "Mognet1", "Mognet2", "Mognet3", "Mognet4"]: handlers[id] = _effect_mognet
func _effect_mognet(_p, _c):
	pass
func resolve(p, c):
	var data = e.db().get_card(c.effect_id())
	p.hacking += int(data.hack)
	if e.db().named(c.id, "DeMartian"): p.hacking += 2 * p.turn_flags.get("matrix", 0)
	var damage = int(data.damage)
	if e.db().named(c.id, "m8trix"): damage += 2 * p.turn_flags.get("demartian", 0)
	if damage > 0: await e.deal(p, damage, c)
	if not p.alive or e.state.finished: return
	if data.kind == "Permanent": c.counters = initial_ice(c.effect_id())
	await handlers[c.effect_id()].call(p, c)
var ice_regex: RegEx
var ice_counts: Dictionary = {}
func initial_ice(id: String) -> int:
	if ice_counts.has(id): return ice_counts[id]
	if ice_regex == null:
		ice_regex = RegEx.new()
		ice_regex.compile("comes into play with ([0-9]+) ICE")
	var found = ice_regex.search(e.db().get_card(id).get("text", ""))
	ice_counts[id] = int(found.get_string(1)) if found else 0
	return ice_counts[id]
func row() -> Array: return e.state.center_row.filter(func(c): return c != null)
func reduce(p, subtype: String, n: int):
	var mods = p.turn_flags.get("reductions", {})
	mods[subtype] = mods.get(subtype, 0) + n
	p.turn_flags.reductions = mods
func free_name(p, name: String):
	var names = p.turn_flags.get("free_names", [])
	names.append(name)
	p.turn_flags.free_names = names
func spend_number(p, maximum: int, prompt: String) -> int:
	var allowed: Array[int] = []
	for n in range(mini(maximum, p.hacking) + 1): allowed.append(n)
	var n = await e.dec(p).choose_number(p, prompt, allowed)
	if n not in allowed: n = 0
	p.hacking -= n
	return n
func choice_power(p, c, n: int):
	var option = await e.option(p, "Choose one", ["+%d hacking" % n, "Deal %d damage" % n])
	if option == 0: p.hacking += n
	else: await e.deal(p, n, c)
func copied(p, original, host):
	# Copy text only; name/type/cost checks continue to see the copying Action.
	var virtual = CardInstance.new(-original.uid, host.id, p.seat)
	virtual.flags.copy_id = original.effect_id()
	virtual.flags.virtual = true
	virtual.flags.host = host.flags.get("host", host)
	var texts = p.turn_flags.get("copied_text", {})
	texts[p.played.size() - 1] = original.effect_id()
	p.turn_flags.copied_text = texts
	await resolve(p, virtual)

## 5ud0
func _effect_5ud0(p, c):
	pass

## [Restaurant Name] Restaurant
func _effect_restaurant_name_restaurant(p, c):
	var choices = e.permanents().filter(func(x): return x != c and e.db().has_subtype(x.effect_id(), "Location"))
	for x in await e.choose(p, "Copy location", choices, 0, 1):
		c.flags.copy_id = x.effect_id()
		c.counters = initial_ice(c.effect_id())
		break

## _NASKEY
func _effect_naskey(p, c):
	e.draw(p, 1)
	if e.in_play("The Juice"):
		await e.deal(p, 1, c)
		e.draw(p, 1)

## _NSAKey, Juiced
func _effect_nsakey_juiced(p, c):
	e.draw(p, 1)

## AI Bens AI Camry
func _effect_ai_bens_ai_camry(p, c):
	pass

## AI Slop
func _effect_ai_slop(p, c):
	for q in e.opponents(p): await e.discard_choices(q, q.play_area)
	e.draw(p, 1)

## Altk3y
func _effect_altk3y(p, c):
	var choices = e.permanents().filter(func(x): return e.db().name_contains(x.effect_id(), "phone"))
	for x in await e.choose(p, "Take phone into discard", choices, 0, 1):
		e.transfer_to_discard(p, x)

## Bedtime Story
func _effect_bedtime_story(p, c):
	e.draw(p, 2)
	await e.discard_choices(p, p.hand, 1)

## Ben The Meek
func _effect_ben_the_meek(p, c):
	var option = await e.option(p, "Choose one", ["+3 hacking", "Gain 3 life", "Deal 3 damage"])
	if option == 0: p.hacking += 3
	elif option == 1: add_life(p, 3)
	else: await e.deal(p, 3, c)

## Ben the Phreak
func _effect_ben_the_phreak(p, c):
	var choices = row()
	for x in await e.choose(p, "Acquire center card", choices): await e.acquire(p, x)

## Bitwize
func _effect_bitwize(p, c):
	pass

## Bony
func _effect_bony(p, c):
	add_life(p, 2)
	free_name(p, "@bony")

## Botnet
func _effect_botnet(p, c):
	pass

## Botnet Takeover
func _effect_botnet_takeover(p, c):
	var choices = e.permanents().filter(func(x): return e.db().named(x.effect_id(), "Botnet"))
	if choices.is_empty(): await e.deal(p, 2, c)
	for x in choices:
		e.transfer_to_discard(p, x)

## Botnet1
func _effect_botnet1(p, c):
	pass

## Botnet2
func _effect_botnet2(p, c):
	pass

## Botnet3
func _effect_botnet3(p, c):
	pass

## Botnet4
func _effect_botnet4(p, c):
	pass

## Bribery
func _effect_bribery(p, c):
	pass

## Brimstone
func _effect_brimstone(p, c):
	e.draw(p, 1)

## Brimstone, Fabulous
func _effect_brimstone_fabulous(p, c):
	e.draw(p, 3)

## c14ud3
func _effect_c14ud3(p, c):
	pass

## Candy Factory
func _effect_candy_factory(p, c):
	pass

## Capture the Flag
func _effect_capture_the_flag(p, c):
	pass

## Carpeted Pool
func _effect_carpeted_pool(p, c):
	pass

## Clarion Inn Air Conditioning
func _effect_clarion_inn_air_conditioning(p, c):
	e.draw(p, 1)

## Clarion Inn Breakfast
func _effect_clarion_inn_breakfast(p, c):
	add_life(p, 1)
	e.draw(p, 1)

## Clarion Inn Chandeliers
func _effect_clarion_inn_chandeliers(p, c):
	pass

## Clarion Inn Closet
func _effect_clarion_inn_closet(p, c):
	pass

## Clarion Inn Morning Coffee
func _effect_clarion_inn_morning_coffee(p, c):
	for x in e.permanents(): e.leave_play(x)
	e.draw(p, 1)

## Clarion Inn Staff
func _effect_clarion_inn_staff(p, c):
	free_name(p, "Clarion")

## Corperate Retreat
func _effect_corperate_retreat(p, c):
	if e.opponents(p).any(func(q): return p.life > q.life): await e.deal(p, 2, c)
	else: add_life(p, 3)

## Corporate SWAG Table
func _effect_corporate_swag_table(p, c):
	pass

## crook3dfingers
func _effect_crook3dfingers(p, c):
	pass

## CTF Bangers
func _effect_ctf_bangers(p, c):
	e.draw(p, 1)

## cybermonkey
func _effect_cybermonkey(p, c):
	reduce(p, "Exploit", 1)

## Damage
func _effect_damage(p, c):
	pass

## DeMartian
func _effect_demartian(p, c):
	p.turn_flags.demartian = p.turn_flags.get("demartian", 0) + 1
	await e.deal(p, 2 * p.played.filter(func(x): return e.db().named(x.id, "m8trix")).size(), c)

## Dick Van Dyke Stamp
func _effect_dick_van_dyke_stamp(p, c):
	pass

## Disassembled Sink
func _effect_disassembled_sink(p, c):
	pass

## Doom on a Trading Card
func _effect_doom_on_a_trading_card(p, c):
	for q in e.opponents(p): await e.discard_choices(q, q.hand, q.play_area.filter(func(x): return e.db().has_subtype(x.effect_id(), "Technology")).size())

## Drunk Riddler
func _effect_drunk_riddler(p, c):
	if await e.dec(p).confirm(p, "Remove this to deal 3 damage?"):
		e.remove(c)
		await e.deal(p, 3, c)

## Egg in Your Soup
func _effect_egg_in_your_soup(p, c):
	add_life(p, 1)
	e.draw(p, 1)
	for x in e.controlled(p, "The Sandwich Factory"): x.counters += 2

## Elevator Noises
func _effect_elevator_noises(p, c):
	e.draw(p, 1)

## Elonka
func _effect_elonka(p, c):
	await e.remove_choices(p, p.hand + p.discard)

## Employee Review
func _effect_employee_review(p, c):
	e.draw(p, 2)
	await e.remove_choices(p, p.hand, 1, 1)

## Empty Lockpicking Table
func _effect_empty_lockpicking_table(p, c):
	e.draw(p, 2)
	await e.discard_choices(p, p.hand, 2)
	if await e.dec(p).confirm(p, "Remove this to deal 1 damage?"):
		e.remove(c)
		await e.deal(p, 1, c)

## errorgone
func _effect_errorgone(p, c):
	e.draw(p, 1)
	await e.discard_choices(p, p.hand, 1)

## Etch-a-Sketch Skillz
func _effect_etch_a_sketch_skillz(p, c):
	var choices: Array = []
	for q in e.opponents(p): choices += q.discard.filter(func(x): return e.db().get_card(x.id).kind == "Action")
	for x in await e.choose(p, "Copy action", choices):
		await copied(p, x, c)

## Even More Logo
func _effect_even_more_logo(p, c):
	e.draw(p, 1)

## evildagmar
func _effect_evildagmar(p, c):
	await e.remove_choices(p, p.hand + p.discard)

## Filler
func _effect_filler(p, c):
	e.draw(p, 1)

## Fivrr Friendship
func _effect_fivrr_friendship(p, c):
	pass

## Flesh Oprah
func _effect_flesh_oprah(p, c):
	if await e.dec(p).confirm(p, "Remove this for a free O.P.R.A.H.?"):
		e.remove(c)
		free_name(p, "O.P.R.A.H.")

## Fore04
func _effect_fore04(p, c):
	pass

## FOTTR Greatest Hits
func _effect_fottr_greatest_hits(p, c):
	pass

## FOTTR Greatest Hits Vol 2
func _effect_fottr_greatest_hits_vol_2(p, c):
	pass

## Foundation of Time Temporal Reconstruction
func _effect_foundation_of_time_temporal_reconstruction(p, c):
	pass

## Fred Rogers
func _effect_fred_rogers(p, c):
	await e.remove_choices(p, p.hand + p.discard)

## G4nd4lf
func _effect_g4nd4lf(p, c):
	pass

## Hacking
func _effect_hacking(p, c):
	pass

## Hardware Hacking Village
func _effect_hardware_hacking_village(p, c):
	pass

## hardwarez
func _effect_hardwarez(p, c):
	var selected = await e.choose(p, "Discard for hacking", p.hand, 0, p.hand.size())
	for x in selected: e.discard(x)
	p.hacking += selected.size()

## heartsh8ped
func _effect_heartsh8ped(p, c):
	await choice_power(p, c, 1)

## hfuller
func _effect_hfuller(p, c):
	pass

## Hotel Roof Chair Toss
func _effect_hotel_roof_chair_toss(p, c):
	await e.deal(p, p.play_area.filter(func(x): return e.db().has_subtype(x.effect_id(), "Location")).size(), c)

## I've got the Logs
func _effect_i_ve_got_the_logs(p, c):
	var id = await e.dec(p).name_a_card(p, "Name a card")
	var revealers = []
	for q in e.opponents(p):
		e.reveal(q, q.hand)
		if q.hand.any(func(x): return e.db().named(x.id, e.db().get_card(id).get("name", id))): revealers.append(q)
	if not revealers.is_empty():
		# Designer ruling 2026-11-10 (#7, #14): only opponents who revealed the named card take {D}, one hit each.
		var cost = e.db().get_card(id).get("cost", 0)
		for q in revealers:
			if p.alive and q.alive and cost > 0: await e.damage(p, q, cost, c, true)
		e.remove(c)
	else: e.draw(p, 1)

## itsamenathan
func _effect_itsamenathan(p, c):
	var choices = row().filter(func(x): return e.db().get_card(x.id).cost <= 4)
	for x in await e.choose(p, "Acquire center card", choices): await e.acquire(p, x)

## Jenny
func _effect_jenny(p, c):
	var allowed: Array[int] = []
	for n in [8, 6, 7, 5, 3, 0, 9]:
		if n <= p.hacking: allowed.append(n)
	var n = await e.dec(p).choose_number(p, "Pay hacking for damage", allowed)
	if n in allowed:
		p.hacking -= n
		await e.deal(p, n, c)
	e.remove(c)

## John Titor
func _effect_john_titor(p, c):
	if await e.dec(p).confirm(p, "Shuffle John Titor into deck?"):
		e.move(c, p.deck, "deck")
		e.shuffle(p.deck)

## JousterL
func _effect_jousterl(p, c):
	pass

## Kevin Mitnick Cardboard Cutout
func _effect_kevin_mitnick_cardboard_cutout(p, c):
	e.draw(p, 1)

## Kevin's Desk
func _effect_kevin_s_desk(p, c):
	pass

## LAN Party
func _effect_lan_party(p, c):
	var revealed: Array = []
	var lowest = 999
	for q in e.opponents(p):
		if q.deck.is_empty():
			q.deck.append_array(q.discard)
			q.discard.clear()
			e.shuffle(q.deck)
		if not q.deck.is_empty():
			var x = q.deck.back()
			e.reveal(q, [x])
			e.discard(x)
			var cost_value = e.db().get_card(x.id).cost
			lowest = mini(lowest, cost_value)
			revealed.append([q, cost_value])
	for item in revealed:
		if item[1] == lowest: await e.damage(p, item[0], 3, c, true)

## Lightning Talks
func _effect_lightning_talks(p, c):
	e.draw(p, 2)

## Lowes Shopping Cart
func _effect_lowes_shopping_cart(p, c):
	pass

## m8trix310
func _effect_m8trix310(p, c):
	p.turn_flags.matrix = p.turn_flags.get("matrix", 0) + 1
	p.hacking += 2 * p.played.filter(func(x): return e.db().named(x.id, "DeMartian")).size()

## Makeshift Lectern
func _effect_makeshift_lectern(p, c):
	pass

## Merry Christmas
func _effect_merry_christmas(p, c):
	if await e.dec(p).confirm(p, "Give Merry Christmas for both effects?"):
		var q = await e.dec(p).choose_player(p, "Give card to opponent", e.opponents(p))
		if q != null:
			e.gain_owner(c, q)
			e.move(c, q.discard, "discard")
		p.hacking += 2
		await e.deal(p, 2, c)
	else: await choice_power(p, c, 2)

## Military-Grade Card Encapsulation
func _effect_military_grade_card_encapsulation(p, c):
	pass

## mog
func _effect_mog(p, c):
	pass

## Mog's Ice Cream
func _effect_mog_s_ice_cream(p, c):
	if e.played_name(p, "Rookie Numbers"): e.draw(p, 3)

## Mogs Pancake Breakfast
func _effect_mogs_pancake_breakfast(p, c):
	var n = await spend_number(p, 3, "Pay hacking to gain life")
	add_life(p, n)

## Nashville 2600
func _effect_nashville_2600(p, c):
	for x in e.permanents():
		if x != c: e.leave_play(x)

## Never Gonna Give You Up
func _effect_never_gonna_give_you_up(p, c):
	pass

## Never Gonna Let You Down
func _effect_never_gonna_let_you_down(p, c):
	pass

## nirtom
func _effect_nirtom(p, c):
	for q in e.state.players:
		if q.alive: add_life(q, 1)

## Nirtom Unleashed
func _effect_nirtom_unleashed(p, c):
	pass

## Non-Infringing Game Show
func _effect_non_infringing_game_show(p, c):
	var n = await spend_number(p, 3, "Pay hacking for damage")
	await e.deal(p, n, c)

## notlarry
func _effect_notlarry(p, c):
	if await e.dec(p).confirm(p, "Remove this for 1 hacking?"):
		e.remove(c)
		p.hacking += 1

## NotLarry Cardboard Cutout
func _effect_notlarry_cardboard_cutout(p, c):
	for x in await e.choose(p, "Remove center card", row()): e.remove(x)

## Number One PhreakNIC Rule
func _effect_number_one_phreaknic_rule(p, c):
	e.draw(p, 2)
	for q in e.state.players:
		if q.alive: add_life(q, 2)

## Nuvious
func _effect_nuvious(p, c):
	pass

## O.P.R.A.H.
func _effect_o_p_r_a_h(p, c):
	var selected = await e.remove_choices(p, p.hand, 0, p.hand.size())
	for i in selected.size():
		if not e.state.center_deck.is_empty(): await e.acquire(p, e.state.center_deck.back(), p.hand)

## Oprah Wonka
func _effect_oprah_wonka(p, c):
	var options = p.deck + p.discard
	options.sort_custom(func(a, b): return a.id < b.id or (a.id == b.id and a.uid < b.uid))
	var selected = await e.choose(p, "Search for five cards", options, 5, 5)
	if selected.size() < 5:
		for x in selected: e.move(x, p.hand, "hand")
		e.shuffle(p.deck)
		return
	var left = p
	for step in range(1, e.state.players.size()):
		var candidate = e.state.players[(p.seat + step) % e.state.players.size()]
		if candidate.alive:
			left = candidate
			break
	var pile = await e.choose(left, "Split cards into first pile", selected, 0, selected.size())
	var other = selected.filter(func(x): return x not in pile)
	var option = await e.option(p, "Choose pile: %s / %s" % [pile.map(func(x): return x.id), other.map(func(x): return x.id)], ["First pile", "Second pile"])
	for x in (pile if option == 0 else other): e.move(x, p.hand, "hand")
	for x in (other if option == 0 else pile): e.remove(x)
	e.shuffle(p.deck)

## OSINT for Dummies
func _effect_osint_for_dummies(p, c):
	e.draw(p, 2)

## Payphone
func _effect_payphone(p, c):
	pass

## Payphone Dave
func _effect_payphone_dave(p, c):
	free_name(p, "@payphone_dave")

## Payphone Karaoke
func _effect_payphone_karaoke(p, c):
	var options = await e.options(p, "Choose two", ["Gain 1 life", "Draw a card", "+1 hacking"], 2)
	var seen = {}
	for option in options:
		if seen.has(option): continue
		seen[option] = true
		if option == 0: add_life(p, 1)
		elif option == 1: e.draw(p, 1)
		elif option == 2: p.hacking += 1

## PhreakMyst
func _effect_phreakmyst(p, c):
	p.turn_flags.no_buy = true

## PhreakNIC
func _effect_phreaknic(p, c):
	add_life(p, 1)
	e.draw(p, 1)
	reduce(p, "Legendary", 2)

## Phreaknic Website Refresh
func _effect_phreaknic_website_refresh(p, c):
	var old = row()
	for x in old:
		var slot = e.state.center_row.find(x)
		e.state.center_row[slot] = null
		e.state.center_deck.push_front(x)
	for i in 5: e.refill(i)
	e.draw(p, 1)

## Pooping in the Dark
func _effect_pooping_in_the_dark(p, c):
	var selected = p.hand.duplicate()
	for x in selected: e.discard(x)
	e.draw(p, selected.size())

## pouipoui
func _effect_pouipoui(p, c):
	reduce(p, "Permanent", 1)

## pouipoui, AV Guy
func _effect_pouipoui_av_guy(p, c):
	await e.deal(p, e.permanents().size(), c)

## Powered On Taser Maintenance
func _effect_powered_on_taser_maintenance(p, c):
	pass

## proudF00F
func _effect_proudf00f(p, c):
	pass

## pTFS
func _effect_ptfs(p, c):
	pass

## r0nk
func _effect_r0nk(p, c):
	var targets = e.state.players.filter(func(q): return q.alive)
	await e.simultaneous_loss(p, targets, targets.map(func(_q): return 1), c)

## randy
func _effect_randy(p, c):
	reduce(p, "Location", 1)

## Registration
func _effect_registration(p, c):
	for x in await e.choose(p, "Return hero", p.discard.filter(func(x): return e.db().has_subtype(x.id, "Hero")), 0, 1): e.move(x, p.hand, "hand")
	e.draw(p, 1)

## Reps4Thor
func _effect_reps4thor(p, c):
	pass

## Reverse Shell
func _effect_reverse_shell(p, c):
	pass

## Rick Astley
func _effect_rick_astley(p, c):
	var choices = p.discard.filter(func(x): return e.db().named(x.id, "Rickroll"))
	for x in await e.choose(p, "Give Rickroll to opponent", choices, 0, 1):
		var q = await e.dec(p).choose_player(p, "Give Rickroll", e.opponents(p))
		if q != null:
			e.gain_owner(x, q)
			e.move(x, q.discard, "discard")

## Rickroll
func _effect_rickroll(p, c):
	p.turn_flags.rickroll = c.flags.get("host", c)

## Rookie Numbers
func _effect_rookie_numbers(p, c):
	e.draw(p, 1)
	for q in e.state.players:
		if q.discard.any(func(x): return e.db().name_contains(x.id, "Mog")): await e.damage(p, q, 2, c)

## Share a Link
func _effect_share_a_link(p, c):
	if await e.dec(p).confirm(p, "Remove this for 2 hacking?"):
		e.remove(c)
		p.hacking += 2

## Shell Speech
func _effect_shell_speech(p, c):
	pass

## Should have Preregistered
func _effect_should_have_preregistered(p, c):
	var selected = await e.remove_choices(p, p.hand, 0, p.hand.size())
	await e.deal(p, selected.size(), c)

## Speakers Needed
func _effect_speakers_needed(p, c):
	p.deck.append_array(p.discard)
	p.discard.clear()
	e.shuffle(p.deck)
	while not p.deck.is_empty():
		var x = p.deck.back()
		e.reveal(p, [x])
		if e.db().has_subtype(x.id, "Hero"):
			e.move(x, p.hand, "hand")
			break
		e.discard(x)

## Sticky Fingers
func _effect_sticky_fingers(p, c):
	for x in await e.choose(p, "Take control of permanent", e.permanents()): e.take_control(x, p)
	e.remove(c)

## Still Not Spock
func _effect_still_not_spock(p, c):
	if await e.dec(p).confirm(p, "Remove this to discard a permanent?"):
		e.remove(c)
		await e.discard_choices(p, e.permanents())

## Super r0nk
func _effect_super_r0nk(p, c):
	p.turn_flags.super_ronk = p.turn_flags.get("super_ronk", 0) + 1

## Tableskirts
func _effect_tableskirts(p, c):
	pass

## Talks Fun Police
func _effect_talks_fun_police(p, c):
	for q in e.state.players:
		if q.alive: await e.discard_choices(q, q.play_area.filter(func(x): return e.db().get_card(x.id).cost <= 4))

## Tennessee Department of Health
func _effect_tennessee_department_of_health(p, c):
	pass

## The Big Dipper
func _effect_the_big_dipper(p, c):
	pass

## The Book
func _effect_the_book(p, c):
	pass

## The Clarion Inn
func _effect_the_clarion_inn(p, c):
	pass

## The Fellowship of the Token Ring
func _effect_the_fellowship_of_the_token_ring(p, c):
	pass

## The Juice
func _effect_the_juice(p, c):
	pass

## The Phreaknic Network
func _effect_the_phreaknic_network(p, c):
	pass

## The Reason
func _effect_the_reason(p, c):
	for q in e.opponents(p): await e.discard_choices(q, q.hand)

## The Sandwich Factory
func _effect_the_sandwich_factory(p, c):
	pass

## The Tone Whisperer
func _effect_the_tone_whisperer(p, c):
	if e.in_play("Payphone"): await e.deal(p, 3, c)

## Time Travel
func _effect_time_travel(p, c):
	pass

## Tips and tricks for Windows OS and Office365
func _effect_tips_and_tricks_for_windows_os_and_office365(p, c):
	p.turn_flags.tips = true

## tipsybacchus
func _effect_tipsybacchus(p, c):
	var selected = await e.choose(p, "Discard to redraw", p.hand, 0, p.hand.size())
	for x in selected: e.discard(x)
	e.draw(p, selected.size())

## TOCTOU
func _effect_toctou(p, c):
	e.draw(p, 1)

## Touch Grass
func _effect_touch_grass(p, c):
	c.flags.expires = p.turns + 1

## Treasure Hunters
func _effect_treasure_hunters(p, c):
	var n = await spend_number(p, p.hacking, "Pay hacking to acquire matching cost")
	if e.can_acquire(p):
		var revealed = e.state.center_deck.duplicate()
		revealed.reverse()
		for x in revealed:
			e.reveal(p, [x])
			if e.db().get_card(x.id).cost == n:
				await e.acquire(p, x)
				break
	e.shuffle(e.state.center_deck)

## Two Hump Camel
func _effect_two_hump_camel(p, c):
	await e.deal(p, 1, c)

## Tyler Crumpton
func _effect_tyler_crumpton(p, c):
	reduce(p, "Technology", 1)

## Unattended Phone
func _effect_unattended_phone(p, c):
	pass

## Under New Management
func _effect_under_new_management(p, c):
	var choices: Array = []
	for q in e.state.players: choices += q.discard.filter(func(x): return e.db().name_contains(x.id, "Clarion"))
	for x in await e.choose(p, "Take Clarion card", choices, 0, 1):
		e.transfer_to_discard(p, x)

## Venaul
func _effect_venaul(p, c):
	pass

## Walmart Parking Lot
func _effect_walmart_parking_lot(p, c):
	pass

## What is Truth
func _effect_what_is_truth(p, c):
	pass

## Wheres Apache
func _effect_wheres_apache(p, c):
	e.draw(p, 3)
	await e.discard_choices(p, p.hand, 2)

## White Python Boots
func _effect_white_python_boots(p, c):
	pass

## zalphaWolf
func _effect_zalphawolf(p, c):
	if await e.dec(p).confirm(p, "Remove this to draw a card?"):
		e.remove(c)
		e.draw(p, 1)

## Zenthere, Mind Goblin
func _effect_zenthere_mind_goblin(p, c):
	p.turn_flags.zenthere = p.turn_flags.get("zenthere", 0) + 1

func cost(p, c) -> int:
	var data = e.db().get_card(c.id)
	var value = int(data.cost)
	for name in p.turn_flags.get("free_names", []):
		if free_matches(c, name): return 0
	if e.db().named(c.id, "Walmart Parking Lot") and e.played_name(p, "heartsh8ped"): return 0
	if e.db().has_subtype(c.id, "FOTTR Hero") and not e.controlled(p, "The Fellowship of the Token Ring").is_empty(): return 0
	if e.db().has_subtype(c.id, "pTFS Hero") and not e.controlled(p, "pTFS").is_empty(): return 0
	for subtype in p.turn_flags.get("reductions", {}):
		if data.kind == subtype or e.db().has_subtype(c.id, subtype): value -= p.turn_flags.reductions[subtype]
	if e.db().has_subtype(c.id, "Hero"): value -= e.controlled(p, "Makeshift Lectern").size()
	if e.db().has_subtype(c.id, "Technology"): value -= e.controlled(p, "Hardware Hacking Village").size()
	return maxi(0, value)
func on_play(p, c):
	var pending: Array = []
	for permanent in p.play_area:
		if permanent.effect_id() == "Dick Van Dyke Stamp":
			if e.db().named(c.id, "Hacker"): pending.append({"card": permanent, "resolve": e.deal.bind(p, 1, permanent)})
			if e.db().named(c.id, "Attack"): pending.append({"card": permanent, "commutes": true, "resolve": add_hacking.bind(p, 1)})
		if permanent.effect_id() == "Foundation of Time Temporal Reconstruction":
			if e.db().has_subtype(c.id, "Hero"): pending.append({"card": permanent, "commutes": true, "resolve": add_hacking.bind(p, 1)})
			if e.db().has_subtype(c.id, "Exploit"): pending.append({"card": permanent, "resolve": e.deal.bind(p, 1, permanent)})
			if e.db().has_subtype(c.id, "Event"): pending.append({"card": permanent, "commutes": true, "resolve": add_life.bind(p, 1)})
	if e.db().has_subtype(c.id, "Hero") and p.turn_flags.get("super_ronk", 0) > 0:
		pending.append({"name": "Super r0nk", "commutes": true, "resolve": add_hacking.bind(p, p.turn_flags.super_ronk)})
	await e.resolve_triggers(pending)
func add_hacking(p, n: int): p.hacking += n
func add_life(p, n: int):
	p.life += n
	e.life_gained.emit(p, n)
func combos(p):
	# Conditional "this turn" abilities wait for their partner, in either play order.
	var fired = p.turn_flags.get("combos", {})
	var pending: Array = []
	for i in p.played.size():
		var c = p.played[i]
		var key = "%d" % i
		if fired.has(key): continue
		var id = p.turn_flags.get("copied_text", {}).get(i, c.id)
		var ready = false
		var damage = 0
		if id in ["5ud0", "Bitwize", "crook3dfingers"]:
			for name in ["5ud0", "bitwize", "crook3dfingers"]:
				if not e.db().named(id, name) and e.played_name(p, name): ready = true
			damage = 1
		elif id == "Reps4Thor":
			ready = e.played_name(p, "Nirtom", true)
			damage = 3
		elif id == "Never Gonna Give You Up": ready = e.played_name(p, "Never Gonna Let You Down")
		elif id == "Never Gonna Let You Down": ready = e.played_name(p, "Never Gonna Give You Up")
		if not ready: continue
		fired[key] = true
		p.turn_flags.combos = fired
		pending.append({"name": e.db().get_card(c.id).name, "resolve": combo_effect.bind(p, c, id, damage)})
	await e.resolve_triggers(pending)
func combo_effect(p, c, id: String, damage: int):
	if damage > 0: await e.deal(p, damage, c)
	else:
		for q in e.opponents(p): await e.discard_choices(q, q.play_area if id == "Never Gonna Give You Up" else q.hand)
func bought(p, c, from_row: bool):
	var pending: Array = []
	# Destination choices are local to this purchase, including nested reactions.
	var destination = {"chosen": false}
	if c.id in ["Fore04", "G4nd4lf", "JousterL", "hfuller", "mog", "Nuvious", "proudF00F", "Venaul"]:
		pending.append({"name": e.db().get_card(c.id).name, "resolve": bought_self.bind(p, c, destination)})
	if e.db().has_subtype(c.id, "Hero"):
		for permanent in p.play_area:
			if permanent.effect_id() in ["The Fellowship of the Token Ring", "pTFS"]:
				pending.append({"card": permanent, "resolve": bought_destination.bind(p, c, permanent, destination)})
	if from_row:
		for permanent in e.permanents():
			if permanent.effect_id() == "Powered On Taser Maintenance" and permanent.controller != p.seat:
				pending.append({"card": permanent, "resolve": e.damage.bind(e.state.players[permanent.controller], p, 1, permanent)})
	await e.resolve_triggers(pending)
func bought_self(p, c, destination: Dictionary = {}):
	if c.id in ["hfuller", "proudF00F"]:
		for q in e.state.players:
			if q.alive: e.reveal(q, q.hand)
	match c.id:
		"Fore04":
			# Designer ruling 2026-11-10 (#10): with Fellowship/pTFS too, exactly one destination applies.
			if destination.get("chosen", false): return
			if await e.dec(p).confirm(p, "Put bought card on deck?"):
				e.move(c, p.deck, "deck")
				destination.chosen = true
		"G4nd4lf", "JousterL":
			var choices = p.discard.filter(func(x): return x != c)
			for x in await e.choose(p, "Put discard on deck", choices, 0, 1): e.move(x, p.deck, "deck")
		"hfuller":
			for q in e.state.players:
				if q.alive: add_life(p, q.hand.filter(func(x): return e.db().named(x.id, "Attack")).size())
		"mog": await e.remove_choices(p, p.hand + p.discard, 0, 1)
		"Nuvious":
			if await e.dec(p).confirm(p, "Discard permanent on buy?"): await e.discard_choices(p, e.permanents())
		"proudF00F":
			var targets = e.state.players.filter(func(q): return q.alive)
			await e.simultaneous_loss(p, targets, targets.map(func(q): return q.hand.filter(func(x): return e.db().named(x.id, "Hacker")).size()), c)
		"Venaul":
			for q in e.state.players:
				if q.alive: add_life(q, 5)
func bought_destination(p, c, permanent, destination: Dictionary):
	if destination.get("chosen", false): return
	if permanent.effect_id() == "The Fellowship of the Token Ring" and await e.dec(p).confirm(p, "Put bought hero in hand?"):
		e.move(c, p.hand, "hand")
		destination.chosen = true
	if permanent.effect_id() == "pTFS" and await e.dec(p).confirm(p, "Store bought hero on pTFS?"):
		e.move(c, permanent.attached, "attached")
		destination.chosen = true
const START_TRIGGERS = ["Clarion Inn Closet", "Kevin's Desk", "Military-Grade Card Encapsulation", "Tableskirts", "Unattended Phone", "The Juice", "The Phreaknic Network", "pTFS", "The Book"]
func start_turn(p):
	var pending: Array = []
	for c in e.permanents():
		if c.effect_id() == "Clarion Inn Air Conditioning" or (c.controller == p.seat and c.effect_id() in START_TRIGGERS):
			pending.append({"card": c, "commutes": c.effect_id() in ["Clarion Inn Closet", "pTFS"], "resolve": start_trigger.bind(p, c)})
	for c in row():
		if c.id == "Rickroll": pending.append({"card": c, "row": true, "resolve": e.buy_card.bind(p, c, true)})
	await e.resolve_triggers(pending)
func start_trigger(p, c):
	if c.effect_id() == "Clarion Inn Air Conditioning": await e.damage(e.state.players[c.controller], p, 1, c)
	if c.controller != p.seat: return
	match c.effect_id():
		"Clarion Inn Closet": c.counters += 2
		"Kevin's Desk":
			for x in await e.choose(p, "Take control of permanent", e.permanents()): e.take_control(x, p)
		"Military-Grade Card Encapsulation": e.leave_play(c)
		"Tableskirts":
			if p.play_area.size() > 1: e.leave_play(c)
		"Unattended Phone":
			if e.rand_range(1, 6) == 1:
				e.leave_play(c)
				await e.damage(p, p, 1, c)
		"The Juice":
			c.counters += 1
			if c.counters == 5: await e.eliminate(p, true)
			else: await e.deal(p, c.counters, c)
		"The Phreaknic Network":
			e.remove(c)
			await e.deal(p, 5, c)
		"pTFS":
			for x in c.attached.duplicate(): e.move(x, p.hand, "hand")
		"The Book":
			for x in await e.choose(p, "Attach action to The Book", p.hand.filter(func(x): return e.db().get_card(x.id).kind == "Action")):
				e.move(x, c.attached, "attached")
			var pending = c.attached.duplicate()
			while not pending.is_empty() and c in e.permanents():
				var names = pending.map(func(x): return e.db().get_card(x.id).name)
				var index = await e.option(p, "Choose next attached Action", names) if pending.size() > 1 else 0
				var x = pending.pop_at(index)
				if x in c.attached and e.legal_effect(p, x):
					await e.resolve_play(p, x)
					# Normal resolution does not discard attachments; self-moving effects do.
func end_turn(p):
	var pending: Array = []
	if p.turn_flags.get("acquired", 0) == 0:
		for i in p.turn_flags.get("zenthere", 0): pending.append({"name": "Zenthere, Mind Goblin", "resolve": e.deal.bind(p, 2)})
	for c in e.permanents():
		if c.effect_id() == "Touch Grass" and c.controller == p.seat and p.turns >= c.flags.get("expires", 999999):
			pending.append({"card": c, "resolve": e.remove.bind(c)})
		elif c.effect_id() == "FOTTR Greatest Hits Vol 2" and c.controller != p.seat and not p.played.any(func(x): return x.id in RICK_ART):
			pending.append({"card": c, "resolve": e.damage.bind(e.state.players[c.controller], p, 2, c)})
	await e.resolve_triggers(pending)
const FREE_ONCE = ["Mognet", "Mognet1", "Mognet2", "Mognet3", "Mognet4", "Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4", "Tableskirts", "Unattended Phone", "The Big Dipper", "Payphone", "Shell Speech", "Disassembled Sink", "FOTTR Greatest Hits"]
const PAID = {"Bribery": 2, "AI Bens AI Camry": 2, "Fivrr Friendship": 2, "White Python Boots": 2, "The Sandwich Factory": 2, "Lowes Shopping Cart": 1}
func abilities(p, c) -> Array:
	var result: Array = []
	if c not in e.permanents(): return result
	if c.effect_id() == "Nashville 2600":
		return [{"index": 0, "label": "Pay 6 Hacking: remove Nashville 2600", "enabled": e.is_turn(p) and p.hacking >= 6, "cost": 6}]
	if c.controller != p.seat: return result
	var id = c.effect_id()
	if id in FREE_ONCE:
		var enabled = not c.flags.get("used", false)
		if id in ["Disassembled Sink", "FOTTR Greatest Hits"]: enabled = enabled and not p.hand.is_empty()
		result.append({"index": 0, "label": e.db().get_card(id).text.split("\n")[0], "enabled": e.is_turn(p) and enabled, "cost": 0})
	if PAID.has(id): result.append({"index": 0, "label": e.db().get_card(id).text, "enabled": e.is_turn(p) and p.hacking >= PAID[id], "cost": PAID[id]})
	if id in ["Time Travel", "Shell Speech", "Clarion Inn Chandeliers", "Candy Factory", "Tennessee Department of Health"]:
		var enabled = true
		if id == "Clarion Inn Chandeliers": enabled = not e.state.removed.is_empty()
		if id == "Candy Factory": enabled = p.hand.any(func(x): return e.db().has_subtype(x.id, "Hero"))
		if id == "Tennessee Department of Health": enabled = e.permanents().any(func(x): return e.db().has_subtype(x.effect_id(), "Location") and x.counters > 0)
		result.append({"index": 1 if id == "Shell Speech" else 0, "label": "Remove this: deal 2 damage" if id == "Shell Speech" else e.db().get_card(id).text, "enabled": enabled and e.is_turn(p), "cost": 0})
	return result
func activate(p, c, index: int):
	var id = c.effect_id()
	if id in FREE_ONCE and index == 0:
		c.flags.used = true
		match id:
			"Mognet", "Mognet1", "Mognet2", "Mognet3", "Mognet4": p.hacking += e.controlled(p, "Mognet").size()
			"Botnet", "Botnet1", "Botnet2", "Botnet3", "Botnet4": p.hacking += e.controlled(p, "Botnet").size()
			"Tableskirts", "Unattended Phone": p.hacking += 1
			"The Big Dipper": add_life(p, 1)
			"Payphone": await choice_power(p, c, 2)
			"Shell Speech": e.draw(p, 1)
			"Disassembled Sink", "FOTTR Greatest Hits":
				var removed = await e.remove_choices(p, p.hand, 0, 1)
				if not removed.is_empty():
					if id == "Disassembled Sink": e.draw(p, 1)
					else: await e.deal(p, 2, c)
	elif PAID.has(id):
		p.hacking -= PAID[id]
		match id:
			"Bribery": await e.deal(p, 1, c)
			"AI Bens AI Camry":
				for q in e.opponents(p): await e.discard_choices(q, q.hand)
			"Fivrr Friendship": add_life(p, 1)
			"White Python Boots": e.draw(p, 1)
			"The Sandwich Factory": c.counters += 1
			"Lowes Shopping Cart":
				c.counters += 1
				if c.counters >= 25: e.finish(p)
	else:
		match id:
			"Nashville 2600":
				p.hacking -= 6
				e.remove(c)
			"Time Travel":
				e.remove(c)
				e.state.extra_turns.append(p.seat)
			"Shell Speech":
				e.remove(c)
				await e.deal(p, 2, c)
			"Clarion Inn Chandeliers":
				var selected = await e.choose(p, "Recover removed card", e.state.removed)
				if not selected.is_empty():
					if selected[0].owner == p.seat or e.can_acquire(p):
						e.remove(c)
						if selected[0].owner == p.seat: e.move(selected[0], p.hand, "hand")
						else: await e.acquire(p, selected[0], p.hand)
			"Candy Factory":
				var selected = await e.choose(p, "Discard hero to add ICE", p.hand.filter(func(x): return e.db().has_subtype(x.id, "Hero")), 0, 1)
				for x in selected:
					e.discard(x)
					c.counters += 1
			"Tennessee Department of Health":
				var choices = e.permanents().filter(func(x): return e.db().has_subtype(x.effect_id(), "Location") and x.counters > 0)
				for x in await e.choose(p, "Remove location counter", choices):
					x.counters -= 1
					await e.counter_removed(x)

func consume_free_buy(p, c, price: int):
	if price != 0: return
	var names = p.turn_flags.get("free_names", [])
	for i in names.size():
		if free_matches(c, names[i]):
			names.remove_at(i)
			break

func free_matches(c, name: String) -> bool:
	if name == "@bony": return c in e.state.center_row and e.db().name_contains(c.id, "F.O.T.T.R. Greatest Hits")
	if name == "@payphone_dave":
		return ["Payphone", "You've Got Mail", "Shell Speech"].any(func(n): return e.db().named(c.id, n))
	return e.db().name_contains(c.id, name)
