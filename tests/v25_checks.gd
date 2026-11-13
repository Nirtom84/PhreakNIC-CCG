extends SceneTree
var checks = 0
var failures = 0
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func invalid(deck, fragment):
 verify(CustomDeck.validate(deck).any(func(s): return fragment in s), fragment)
func packed(payload):
 return CustomDeck.PREFIX + Marshalls.raw_to_base64(JSON.stringify(payload).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)).replace("+", "-").replace("/", "_").replace("=", "")
func game(deck, level, seed_value):
 var engine = GameEngine.new()
 root.add_child(engine)
 verify(engine.setup([level, 0], seed_value, [], "2026", 0, ["nirtom"], deck), "custom setup")
 verify(engine.state.card_pool == "custom" and engine.state.banned.is_empty(), "custom marker and ignores bans")
 verify(engine.state.initial_count == CustomDeck.total(deck) + 20, "exact deck copies")
 var driver = BotPlayer.new(engine)
 await engine.start_turn()
 for i in 300:
  if engine.state.finished: break
  await driver.take_turn(engine.active())
  verify(engine.state.conservation_ok(), "custom conservation")
 verify(engine.state.finished, "%s level %d finishes" % [deck.name, level])
 verify(engine.state.conservation_ok(), "final conservation")
 engine.free()
func run():
 var decks = JSON.parse_string(FileAccess.get_file_as_string("res://data/starter_decks.json"))
 for deck in decks:
  verify(CustomDeck.validate(deck).is_empty(), "starter valid " + str(CustomDeck.validate(deck)))
  verify(CustomDeck.total(deck) == 60, "starter size")
  var code = CustomDeck.encode(deck)
  print("Deck code ", deck.name, " (", code.length(), "): ", code)
  verify(CustomDeck.decode(code) == CustomDeck.normalize(deck), "code round trip")
  verify(CustomDeck.from_file_text(CustomDeck.to_file_text(deck)) == CustomDeck.normalize(deck), "file round trip")
  verify(CustomDeck.from_file_text(code) == CustomDeck.normalize(deck), "bare code import")
  verify(code.length() < 1000, "Discord code length")
 var deck = decks[0].duplicate(true)
 deck.cards = {}
 invalid(deck, "at least 60")
 deck.cards = {"nirtom": 201}
 invalid(deck, "Invalid count")
 deck.cards = {"Botnet": 3, "Mognet": 2}
 invalid(deck, "Too many copies of Botnet: 5")
 deck.cards = {"NotLarry Cardboard Cutout": 3, "NotLarry Cardboard Cutout@mog": 2}
 invalid(deck, "Too many copies")
 deck.cards = {"PhreakNIC": 1, "PhreakNIC@mog": 2}
 invalid(deck, "Legendary card PhreakNIC")
 deck.cards = {"Nirtom Unleashed": 3, "Rick Astley": 3}
 invalid(deck, "Legendary card Nirtom Unleashed")
 invalid(deck, "Legendary card Rick Astley")
 deck.cards = {"Hacking": 1, "Damage": 1, "xyz": 1}
 invalid(deck, "Hacker can't")
 invalid(deck, "Attack can't")
 invalid(deck, "Unknown card: xyz")
 deck = decks[0].duplicate(true)
 deck.cards["Botnet"] = 2
 deck.cards["Mognet"] = 2
 verify(CustomDeck.validate(deck).is_empty(), "Botnet plus Mognet four legal " + str(CustomDeck.validate(deck)))
 deck.cards["NotLarry Cardboard Cutout@mog"] = 2
 deck.cards["NotLarry Cardboard Cutout"] = 2
 deck.cards["Filler@mog"] = 2
 var mixed = deck
 verify(CustomDeck.validate(mixed).is_empty(), "mixed valid")
 var large = {"name": "Large", "cards": {}}
 for printing in CustomDeck.printings():
  if large.cards.has(printing.base_id): continue
  large.cards[printing.id] = 2
 invalid(large, "at most 200")
 for bad in ["", "garbage", "PNDK1." + "x".repeat(9000), "PNDK1.!", "PNDK1.a", "PNDK1.AAAA", "PNDK1.eJwAAAAA"]:
  verify(CustomDeck.decode(bad).is_empty(), "reject bad code")
 for count in [-1, 0, 5, 1.5, "2"]:
  var bad = decks[0].duplicate(true)
  bad.cards["Botnet"] = count
  verify(CustomDeck.decode(packed(bad)).is_empty(), "reject bad count")
 verify(CustomDeck.decode(packed("x".repeat(100000))).is_empty(), "reject decompression bomb")
 var rng = RandomNumberGenerator.new()
 rng.seed = 251
 for length in [1, 10, 100, 500, 8000, 8193]:
  var bytes = PackedByteArray()
  for i in length: bytes.append(rng.randi_range(32, 126))
  var decoded = CustomDeck.BoundedInflater.new().inflate(bytes.compress(FileAccess.COMPRESSION_DEFLATE))
  verify(decoded == bytes if length <= 8192 else decoded.is_empty(), "bounded inflater native compatibility")
 for i in 100:
  var bytes = PackedByteArray()
  for j in rng.randi_range(1, 100): bytes.append(rng.randi_range(0, 255))
  verify(CustomDeck.BoundedInflater.new().inflate(bytes).is_empty(), "malformed compressed input")
 var long_name = decks[0].duplicate(true)
 long_name.name = "x".repeat(41)
 verify(CustomDeck.decode(packed(long_name)).is_empty(), "reject long name")
 verify(CustomDeck.decode(packed(large)).is_empty(), "reject oversized deck")
 verify(CustomDeck.from_file_text("x".repeat(40000)).is_empty(), "bounded file")
 var db = root.get_node("CardDB").catalog("custom")
 verify(db.get_card("NotLarry Cardboard Cutout@mog").name == "Mog Cardboard Cutout", "Mog printed name")
 verify(not db.name_contains("NotLarry Cardboard Cutout", "Mog"), "original name retained")
 verify(db.name_contains("NotLarry Cardboard Cutout@mog", "Mog"), "Mog name check")
 verify(db.has_subtype("Rick Astley", "Legendary"), "Rick ruling")
 var server = load("res://scripts/net/game_server.gd").new()
 root.add_child(server)
 verify(server.setup([{"bot": true}, {"bot": true}], "2026", 12, 251, root.get_node("CardDB").center_ids("2026"), 0.0, mixed), "server custom setup ignores bans")
 verify(server.engine.state.card_pool == "custom", "server custom state")
 server.free()
 var engine = GameEngine.new()
 root.add_child(engine)
 engine.setup([2, 2], 152, [], "2026", 24, [], mixed)
 await engine.start_turn(0)
 var p = engine.active()
 var mog = engine.state.all_cards().filter(func(c): return c.id == "Filler@mog")[0]
 engine.gain_owner(mog, p)
 engine.move(mog, p.hand, "hand")
 var hand_size = p.hand.size()
 await engine.play_card(p, mog)
 verify(mog in p.play_area and p.hand.size() == hand_size, "Mog effect handler resolves")
 var public_state = NetView.apply(NetView.build(engine, 0))
 verify(public_state.custom_deck == engine.state.custom_deck, "custom deck public state")
 var snapshot = SaveGame.snapshot(engine.state)
 var restored = SaveGame.restore(snapshot)
 verify(restored != null and restored.custom_deck == CustomDeck.normalize(mixed), "custom mid-game save load")
 if restored != null: verify(SaveGame.snapshot(restored) == snapshot, "save exact round trip")
 var changed = SaveGame.clone_memory(engine.state)
 changed.custom_deck.cards["Botnet"] = 1
 changed.custom_deck.cards["nirtom"] = 3
 verify(SaveGame.restore(SaveGame.snapshot(changed)) == null, "tampered valid deck rejected")
 var invalid_save = SaveGame.clone_memory(engine.state)
 invalid_save.custom_deck.cards["Hacking"] = 1
 verify(SaveGame.restore(SaveGame.snapshot(invalid_save)) == null, "invalid saved deck rejected")
 var stats = load("res://scripts/ui/match_stats.gd").new()
 stats.setup(2, "custom", [2, 2])
 stats.custom_deck = mixed.duplicate(true)
 stats.finish(0, engine.state.players)
 verify(load("res://scripts/ui/match_stats.gd").from_dict(stats.to_dict()) != null, "custom match stats round trip")
 var store = load("res://scripts/ui/lifetime_stats.gd").new()
 store.reset()
 verify(store.record(stats, 0, "", "local", "v25"), "record experimental")
 verify(store.data.games == 0 and store.experimental().games == 1 and store.experimental().decks[mixed.name].wins == 1, "separate stats")
 verify(not store.record(stats, 0, "", "local", "v25"), "experimental dedupe")
 var reread = load("res://scripts/ui/lifetime_stats.gd").new()
 verify(reread.experimental() == store.experimental(), "experimental stats persisted")
 engine.free()
 DefconSearch.fixed_rollouts = 1
 for fixture in [decks[0], decks[1], mixed]:
  for level in 4: await game(fixture, level, 25100 + level)
 print("v25 checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
