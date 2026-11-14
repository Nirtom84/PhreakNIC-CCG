class_name CustomBotDecks
extends RefCounted
static func load_decks(plan_path = "") -> Array:
	var result: Array = []
	if not plan_path.is_empty():
		var plan = JSON.parse_string(FileAccess.get_file_as_string(plan_path))
		for code in plan.decks:
			var deck = CustomDeck.from_file_text(code)
			if deck.is_empty(): return []
			result.append(deck)
		return result
	var directory = DirAccess.open("res://decks/custom")
	if directory != null:
		var files = directory.get_files()
		files.sort()
		for file in files:
			if file.ends_with(".phreakdeck.json"):
				var deck = CustomDeck.from_file_text(FileAccess.get_file_as_string("res://decks/custom/" + file))
				if not deck.is_empty(): result.append(deck)
	if result.is_empty(): result = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))
	return result
