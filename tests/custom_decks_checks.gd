extends SceneTree
var checks = 0
var failures = 0
func _initialize(): run.call_deferred()
func verify(ok, message):
 checks += 1
 if not ok:
  failures += 1
  print("FAIL: ", message)
func run():
 var specs = JSON.parse_string(FileAccess.get_file_as_string("res://tools/custom_deck_specs.json"))
 verify(specs is Array and specs.size() == 100, "100 specs")
 var files = []
 for filename in DirAccess.get_files_at("res://decks/custom"):
  if filename.ends_with(".phreakdeck.json"): files.append(filename)
 files.sort()
 verify(files.size() == 100, "exactly 100 files")
 var names = {}
 var codes = {}
 var histogram = [0, 0, 0, 0]
 var covered = {}
 var lists = []
 var sizes = []
 var mog_decks = 0
 var mognet_decks = 0
 var mostly_single = 0
 var exact60 = 0
 var exact200 = 0
 var all_names = {}
 for printing in CustomDeck.printings():
  all_names[printing.name.to_lower()] = printing.base_id
 var quote = RegEx.new()
 quote.compile("`([^`]+)`")
 for i in files.size():
  var text = FileAccess.get_file_as_string("res://decks/custom/" + files[i])
  var document = JSON.parse_string(text)
  verify(document is Dictionary, files[i] + " parses")
  if not document is Dictionary: continue
  var deck = CustomDeck.from_file_text(text)
  verify(not deck.is_empty(), files[i] + " imports")
  if deck.is_empty(): continue
  var expected = {"name": specs[i].name, "cards": {}}
  for pair in specs[i].cards: expected.cards[pair[0]] = int(pair[1])
  verify(deck == CustomDeck.normalize(expected), deck.name + " matches source")
  verify(CustomDeck.from_file_text(CustomDeck.to_file_text(deck)) == deck, deck.name + " file round trip")
  verify(CustomDeck.decode(CustomDeck.encode(deck)) == deck, deck.name + " code round trip")
  verify(document.cards == JSON.parse_string(CustomDeck.to_file_text(deck)).cards, deck.name + " readable card list")
  verify(CustomDeck.validate(deck).is_empty(), deck.name + " legal")
  verify(not names.has(deck.name), deck.name + " unique name")
  verify(not codes.has(document.code), deck.name + " unique code")
  names[deck.name] = true
  codes[document.code] = true
  var count = CustomDeck.total(deck)
  verify(count == int(document.count), deck.name + " count")
  verify(text.to_utf8_buffer().size() <= 32768, deck.name + " import cap")
  for key in ["description", "play_style", "combos", "tags"]:
   verify(document.get(key) == specs[i].get(key), deck.name + " metadata " + key)
  histogram[0 if count < 80 else (1 if count < 120 else (2 if count < 160 else 3))] += 1
  if count == 60: exact60 += 1
  if count == 200: exact200 += 1
  var base_counts = {}
  var has_mog = false
  for id in deck.cards:
   var base = CustomDeck.base_id(id)
   covered[base] = true
   base_counts[base] = base_counts.get(base, 0) + deck.cards[id]
   if id.ends_with("@mog") or id == "Mognet": has_mog = true
  if has_mog: mog_decks += 1
  if deck.cards.has("Mognet"): mognet_decks += 1
  var singles = 0
  for n in base_counts.values():
   if n == 1: singles += 1
  if singles > base_counts.size() / 2.0: mostly_single += 1
  lists.append(base_counts)
  sizes.append(count)
  verify(document.combos.size() >= 2 and document.combos.size() <= 5, deck.name + " combo count")
  var paired = false
  for combo in document.combos:
   var matches = quote.search_all(combo)
   verify(matches.size() >= 1, deck.name + " explicit combo names")
   if matches.size() >= 2: paired = true
   for matched in matches:
    var named = matched.get_string(1).to_lower()
    verify(all_names.has(named) and base_counts.has(all_names.get(named, "")), deck.name + " present combo card " + named)
   # All named cards use backticks. Scan remaining prose for unmarked card names,
   # using whole words to avoid matching e.g. 'mog' inside 'Mognet'.
   var prose = quote.sub(combo, "", true).to_lower()
   for named in all_names:
    if named.length() < 4: continue
    var start = prose.find(named)
    if start < 0: continue
    var before = prose.substr(start - 1, 1) if start > 0 else " "
    var after = prose.substr(start + named.length(), 1)
    if (before.is_empty() or not before.is_valid_identifier()) and (after.is_empty() or not after.is_valid_identifier()):
     verify(base_counts.has(all_names[named]), deck.name + " prose card " + named)
  verify(paired, deck.name + " has a two-card combo")
 verify(histogram == [35, 25, 20, 20], "size histogram 35/25/20/20")
 verify(exact60 >= 3 and exact200 >= 3, "several minimum and maximum decks")
 verify(mog_decks >= 15, "Mog variety")
 verify(mognet_decks >= 5, "Mognet variety")
 verify(mostly_single >= 5, "mostly singleton variety")
 for printing in CustomDeck.printings():
  verify(covered.has(printing.base_id), "coverage " + printing.base_id)
 for a in lists.size():
  for b in range(a):
   var overlap = 0
   for id in lists[a]: overlap += mini(lists[a][id], lists[b].get(id, 0))
   verify(overlap <= 0.8 * maxi(sizes[a], sizes[b]), "base-card overlap %d/%d" % [a + 1, b + 1])
 print("custom decks checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
