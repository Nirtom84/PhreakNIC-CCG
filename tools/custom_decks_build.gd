extends SceneTree
## Rebuild the checked-in experimental shared-market collection from its specs.
func _initialize():
	run.call_deferred()
func fail(message: String):
	push_error(message)
	quit(1)
func run():
	var specs = JSON.parse_string(FileAccess.get_file_as_string("res://tools/custom_deck_specs.json"))
	if not specs is Array or specs.size() != 100:
		fail("Expected 100 custom deck specs")
		return
	var printing_ids = {}
	for printing in CustomDeck.printings(): printing_ids[printing.id] = true
	DirAccess.make_dir_recursive_absolute("res://decks/custom")
	var readme = "# Experimental custom Center Decks\n\nThese 100 shared-market environments are experimental designs, not a balance-tested ranking. Every player still starts with 8 Hacker and 2 Attack.\n\nTo import, copy a file's `code` into **Decks → Import**, or open the `.phreakdeck.json` file in the deck importer. Descriptions, play guidance, and combos are included in each file. Card names in combo notes are enclosed in backticks; either printing's display name identifies the same base card, except Mognet has its own rules.\n\nRebuild with `godot4.7.1 --headless -s tools/custom_decks_build.gd`. Source: `tools/custom_deck_specs.json`, generated from the hand-written designs in `tools/custom_decks/deck_defs.py` by `tools/custom_decks/design.py` (see its header).\n\n| # | Name | Cards | Tags | Description |\n|---|---|---:|---|---|\n"
	for index in specs.size():
		var spec = specs[index]
		var deck = {"name": spec.name, "cards": {}}
		for pair in spec.cards:
			if not printing_ids.has(pair[0]) or deck.cards.has(pair[0]):
				fail(spec.name + ": unknown or duplicate printing " + str(pair[0]))
				return
			deck.cards[pair[0]] = pair[1]
		var problems = CustomDeck.validate(deck)
		if not problems.is_empty():
			fail(spec.name + ": " + "; ".join(problems))
			return
		var document = JSON.parse_string(CustomDeck.to_file_text(deck))
		for key in ["description", "play_style", "combos", "tags"]: document[key] = spec[key]
		document.count = CustomDeck.total(deck)
		var text = JSON.stringify(document, "  ", true) + "\n"
		if text.to_utf8_buffer().size() > 32768 or CustomDeck.from_file_text(text) != CustomDeck.normalize(deck):
			fail(spec.name + ": file import round trip failed")
			return
		var filename = "%03d-%s.phreakdeck.json" % [index + 1, spec.slug]
		var file = FileAccess.open("res://decks/custom/" + filename, FileAccess.WRITE)
		if file == null:
			fail(spec.name + ": cannot write output")
			return
		file.store_string(text)
		file.close()
		readme += "| %03d | [%s](%s) | %d | %s | %s |\n" % [index + 1, spec.name, filename, document.count, ", ".join(spec.tags), spec.description.replace("|", "\\|")]
	var file = FileAccess.open("res://decks/custom/README.md", FileAccess.WRITE)
	if file == null:
		fail("Cannot write collection README")
		return
	file.store_string(readme)
	file.close()
	print("custom decks build: 100 decks written and import-checked")
	quit(0)
