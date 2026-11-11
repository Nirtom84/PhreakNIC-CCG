extends SceneTree
var checks = 0
var failures = 0
var optional_one = false
var reaction_driving = false
# Back up the player's settings and saved game, and put them back on exit (tables autosave during these tests).
var user_backups = {}
func _initialize():
 for path in ["user://settings.cfg", "user://savegame.json"]:
  user_backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
 run.call_deferred()
func _finalize():
 for path in user_backups:
  if user_backups[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(user_backups[path])
   file.close()
func verify(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func drive_human_reaction(table):
 reaction_driving = true
 await table.play_all()
 if is_instance_valid(table) and table.engine.reaction_depth > 0 and table.available(): await table.end_human_turn(true)
 reaction_driving = false
func respond(table):
 # Answer the same signal emitted by the modal buttons, on a later frame.
 while is_instance_valid(table) and table.is_inside_tree():
  await process_frame
  if not is_instance_valid(table): return
  # The outer bot action may await a human TOCTOU turn. Keep the prompt
  # responder alive while a separate coroutine drives that reaction.
  if table.engine != null and table.engine.reaction_depth > 0 and table.available() and not reaction_driving:
   drive_human_reaction(table)
  if table.pending:
   var prompts = table.get_children().filter(func(node): return node is PanelContainer and node.is_in_group("touch_modal") and node.z_index == 20)
   if prompts.is_empty(): continue
   var overlay = prompts.back()
   var box = overlay.get_child(0)
   if box.get_child(0).text.contains("damage incoming"):
    box.get_child(box.get_child_count() - 1).pressed.emit()
    continue
   var grid = box.get_child(3).get_child(0)
   var done = box.get_child(4)
   if done.visible:
    var text: String = box.get_child(2).text
    var minimum = int(text.trim_prefix("Select ").split("–")[0])
    if optional_one and minimum == 0 and grid.get_child_count() > 0: minimum = 1
    for i in minimum: grid.get_child(i).pressed.emit()
    assert(not done.disabled)
    done.pressed.emit()
   elif grid.get_child_count() > 0: grid.get_child(0).pressed.emit()
func sync(table):
 var e = table.engine
 var p = e.state.players[0]
 var hand = table.body.find_child("Hand", true, false)
 verify(hand != null, "Hand rendered")
 if hand != null:
  verify(hand.get_children().map(func(c): return c.get_meta("card_uid")) == p.hand.map(func(c): return c.uid), "Hand UIDs match turn %d" % e.state.turn)
 var piles = table.body.find_child("PlayerPiles", true, false)
 verify(piles != null and piles.text == "Deck %d   /   Discard %d" % [p.deck.size(), p.discard.size()], "Pile counts match turn %d" % e.state.turn)
 for q in e.state.players:
  verify(table.life_labels.has(q.seat) and table.life_labels[q.seat].text == str(q.life), "Life matches")
 verify(e.state.conservation_ok(), "Card conservation")
 verify(e.state.resolving.is_empty(), "Completed actions leave no resolving cards")
 for q in e.state.players:
  for c in q.played:
   if e.db().get_card(c.id).kind == "Action":
    verify(c in q.discard + q.deck + q.hand + e.state.removed or (c.id == "Rickroll" and c in e.state.center_row) or e.state.all_cards().any(func(host): return c in host.attached), "Played action has a final zone: " + c.id)
func prepare_draw_hand(table):
 var e = table.engine
 var p = e.state.players[0]
 e.state.rng.seed = 1
 # Empty deck forces the draw action to recycle actions just played by Play All.
 for c in (p.hand + p.deck + p.discard).duplicate(): e.move(c, e.state.removed, "removed")
 for id in ["cybermonkey", "Damage", "Hacking", "Hacking", "OSINT for Dummies"]:
  var card = e.state.all_cards().filter(func(c): return c.id == id and c not in p.hand)[0]
  e.gain_owner(card, p)
  e.move(card, p.hand, "hand")
 e.state_changed.emit()
func draw_regression(table):
 var e = table.engine
 var p = e.state.players[0]
 prepare_draw_hand(table)
 # Reproduce the former snapshot loop before exercising the fix.
 for c in p.hand.duplicate():
  if e.can_play(p, c): await e.play_card(p, c)
 verify(not p.hand.is_empty(), "Draw effect refills hand after snapshot plays")
 verify(p.hand.any(func(c): return c in p.played), "Already played action can legitimately return to hand")
 sync(table)
 prepare_draw_hand(table)
 await table.play_all()
 sync(table)
 verify(p.hand.filter(func(c): return e.can_play(p, c)).is_empty(), "Play All includes cards drawn from recycled discard")
func buy_and_sink_regression(table):
 var e = table.engine
 var p = e.state.players[0]
 var jouster = e.state.all_cards().filter(func(c): return c.id == "JousterL")[0]
 e.gain_owner(jouster, p)
 e.move(jouster, p.reserve, "reserve")
 p.hacking = 100
 var discard_before = p.discard.duplicate()
 var deck_before = p.deck.size()
 optional_one = true
 await e.buy_card(p, jouster)
 optional_one = false
 verify(p.deck.size() == deck_before + 1, "JousterL returns exactly one discard to deck")
 verify(p.discard.size() == discard_before.size(), "JousterL buy adds itself and removes one discard")
 verify(jouster in p.discard, "JousterL stays in discard")
 sync(table)
 var sink = e.state.all_cards().filter(func(c): return c.id == "Disassembled Sink")[0]
 e.gain_owner(sink, p)
 e.move(sink, p.play_area, "play_area")
 e.draw(p, 1)
 e.state_changed.emit()
 var removed_before = e.state.removed.size()
 var hand_before = p.hand.size()
 optional_one = true
 await table.activate_card(sink, 0)
 optional_one = false
 verify(e.state.removed.size() == removed_before + 1, "Sink removes one hand card")
 verify(p.hand.size() == hand_before, "Sink draws one replacement")
 sync(table)
 var prior_floats = table.get_children().filter(func(c): return c.has_meta("life_float"))
 await e.damage(p, e.state.players[1], 1)
 await process_frame
 await process_frame
 var floats = table.get_children().filter(func(c): return c.has_meta("life_float") and c not in prior_floats)
 verify(not floats.is_empty(), "Damage creates a floating number")
 for number in floats:
  verify(absf(number.global_position.x - table.life_labels[1].global_position.x) < 1, "Damage number tracks target life readout")
 await create_timer(1.1).timeout
 verify(table.get_children().filter(func(c): return c.has_meta("life_float")).is_empty(), "Floating numbers are freed")
func run():
 create_timer(180).timeout.connect(func():
  push_error("UI state sync timed out")
  quit(1))
 for seed_id in [1, 17, 42, 137, 2026]:
  var table = load("res://scenes/table.tscn").instantiate()
  table.fast = true
  table.auto_drive = seed_id == 17
  table.seed_value = seed_id
  root.add_child(table)
  respond(table)
  await process_frame
  var e = table.engine
  var p = e.state.players[0]
  if seed_id == 1:
   while e.active().is_bot and not e.state.finished: await table.drive_reaction(e.active())
   await draw_regression(table)
   await buy_and_sink_regression(table)
  e.state_changed.connect(func():
   if not e.busy: sync(table))
  var human_turns = 0
  while human_turns < 15 and not e.state.finished:
   if e.active() == p:
    human_turns += 1
    await table.play_all()
    sync(table)
    var buys = e.state.center_row.filter(func(c): return c != null and e.can_buy(p, c))
    buys.sort_custom(func(a, b): return e.effective_cost(p, a) > e.effective_cost(p, b))
    if not buys.is_empty():
     await e.buy_card(p, buys[0])
     sync(table)
    await table.end_human_turn()
    sync(table)
   else:
    if table.auto_drive:
     while (e.active().is_bot or table.driving or e.busy) and not e.state.finished:
      await process_frame
    else: await table.drive_reaction(e.active())
    sync(table)
   await process_frame
  print("Seed %d: %d human turns" % [seed_id, human_turns])
  while table.driving: await process_frame
  table.queue_free()
  await process_frame
 print("UI state sync: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
