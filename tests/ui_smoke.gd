extends SceneTree
var failures: int = 0
var checks: int = 0
class ScriptedHuman extends Decider:
 var table
 func _init(ui): table = ui
 func choose_option(_p, prompt: String, options: Array[String]) -> int:
  return await table.decision(prompt, options, [], 1, 1, false)
 func choose_cards(_p, prompt: String, cards: Array, min_n: int, max_n: int) -> Array:
  var result: Array = []
  for i in await table.decision(prompt, [], cards, min_n, max_n, true): result.append(cards[i])
  return result
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
func respond(table):
 # Answer the same signal emitted by the modal buttons, on a later frame.
 while is_instance_valid(table) and table.is_inside_tree():
  await process_frame
  if not is_instance_valid(table): return
  if table.pending:
   var overlay = table.get_child(table.get_child_count() - 1)
   if not overlay is PanelContainer: continue
   var box = overlay.get_child(0)
   if box.get_child(0).text.contains("damage incoming"):
    box.get_child(box.get_child_count() - 1).pressed.emit()
    continue
   var grid = box.get_child(3).get_child(0)
   var done = box.get_child(4)
   if done.visible:
    var text: String = box.get_child(2).text
    var minimum = int(text.trim_prefix("Select ").split("–")[0])
    for i in minimum: grid.get_child(i).pressed.emit()
    verify(not done.disabled, "Selection enforces legal minimum")
    done.pressed.emit()
   elif grid.get_child_count() > 0: grid.get_child(0).pressed.emit()
func run():
 root.size = Vector2i(1920, 1080)
 var settings = root.get_node("Sfx")
 var previous_handle = settings.handle
 settings.handle = "bitwize"
 for count in [2, 3, 4]:
  var table = load("res://scenes/table.tscn").instantiate()
  table.player_count = count
  table.auto_drive = false
  table.scripted_decider = ScriptedHuman.new(table)
  root.add_child(table)
  respond(table)
  await process_frame
  verify(table.engine.state.players.size() == count, "Generic table seats")
  if count == 2:
   var regions = table.body.get_child(0).get_children()
   var remote = regions[0].get_global_rect()
   var center = regions[1].get_global_rect()
   var rig = regions[2].get_global_rect()
   var status = regions[3].get_global_rect()
   var hand = regions[4].get_global_rect()
   verify(remote.end.y <= center.position.y - 10, "Opponent strip clears center tab")
   verify(center.end.y <= rig.position.y - 10, "Center costs clear rig tab")
   verify(maxf(rig.end.y, status.end.y) <= hand.position.y - 10, "Rig and actions clear hand tab")
   verify(hand.end.y <= 1080, "Hand fits 1080p viewport")
  verify(table.seat_name(0) == "bitwize", "Human handle names the seat")
  for bot_name in table.seat_names.slice(1):
   verify(bot_name.to_lower() != "bitwize", "Bot names exclude the human handle")
  table.append_log("Seat 0 plays Hacker")
  verify("bitwize plays Hacker" in table.log_view.get_parsed_text(), "Handle uses third-person log verbs")
  table.append_log("Seat 0 plays [Restaurant Name] Restaurant")
  verify("bitwize plays [Restaurant Name] Restaurant" in table.log_view.get_parsed_text(), "Bracketed card names render literally")
  var before_reveal = table.log_view.text
  table.engine.reveal(table.engine.state.players[0], [])
  verify(table.log_view.text == before_reveal, "Empty reveals are silent")
  var restaurant_id = "[Restaurant Name] Restaurant"
  verify(table.link_cards(restaurant_id).count("[url=") == 1, "Bracketed card name is one link")
  verify(restaurant_id.uri_encode() in table.link_cards(restaurant_id), "Link metadata safely encodes brackets")
  var human = HumanDecider.new(table)
  var p = table.engine.state.players[0]
  var options: Array[String] = ["One", "Two"]
  verify(await human.choose_option(p, "Option", options) == 0, "Option modal")
  verify((await human.choose_options(p, "Multiple", options, 2)).size() == 2, "Multiple modal")
  verify((await human.choose_cards(p, "Cards", p.hand, 1, 2)).size() == 1, "Card modal")
  verify(await human.choose_player(p, "Player", table.engine.state.players) == p, "Player modal")
  var numbers: Array[int] = [3, 7]
  verify(await human.choose_number(p, "Number", numbers) == 3, "Number modal")
  verify(await human.confirm(p, "Confirm"), "Confirm modal")
  var sources = [{"card": p.hand[0], "capacity": 2, "full": false}, {"card": p.hand[1], "capacity": 3, "full": false}]
  verify(await human.allocate_prevention(p, 2, sources) == [2, 0], "Human prevention allocation modal")
  verify(table.engine.db().cards.has(await human.name_a_card(p, "Name")), "Searchable name modal")
  for turn in 12:
   if table.engine.state.finished: break
   if table.engine.active().seat == 0:
    await table.play_all()
    verify(not table.acting and not table.engine.busy, "Play All unlocks")
    var buys = table.engine.state.center_row.filter(func(c): return c != null and table.engine.can_buy(p, c))
    if not buys.is_empty():
     # Market modal auto-selects reserve if available, otherwise buy.
     table.card_clicked(buys[0], "market")
     await table.sheet_buy(buys[0])
    await table.end_human_turn(true)
   else: await BotPlayer.new(table.engine).take_turn(table.engine.active())
   verify(table.engine.state.conservation_ok(), "UI action conservation")
   await process_frame
  verify(table.engine.state.turn >= 10 or table.engine.state.finished, "Full turns advance")
  table.queue_free()
  await process_frame
 var opening = load("res://scenes/table.tscn").instantiate()
 var old_auto_end = settings.auto_end_turn
 settings.auto_end_turn = false
 opening.seed_value = 1
 opening.fast = true
 opening.starting_life = 31
 opening.scripted_decider = Decider.new()
 root.add_child(opening)
 verify(opening.engine.state.active_seat == 1, "Seeded bot can start before human")
 for frame in 300:
  await process_frame
  if opening.engine.state.turn >= 2 and not opening.driving and not opening.engine.busy: break
 verify(opening.engine.active().seat == 0 and opening.engine.state.players[1].turns == 1, "Opening bot turn automatically finishes")
 verify(opening.engine.state.starting_life == 31, "Table passes custom starting life")
 verify(opening.can_save(), "First human turn is a safe save point after bot starts")
 opening.queue_free()
 await process_frame
 settings.auto_end_turn = old_auto_end
 settings.handle = previous_handle
 print("UI smoke: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
