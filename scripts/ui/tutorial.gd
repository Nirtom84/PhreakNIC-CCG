extends Control
const SEED = 150041
const STEPS = [
 ["hand", "Your hand contains the cards you can play this turn. Cards you buy improve future hands.", ""],
 ["hand", "Play a Hacker: tap a Hacking card in your hand to generate Hacking.", "play"],
 ["hack", "Hacking pays for purchases. Unspent Hacking resets at the end of your turn.", ""],
 ["center", "The Center Row is the market. Each card shows its Hacking cost below it.", ""],
 ["center", "Buy an affordable card from the Center Row. Play more Hacking cards first if needed.", "buy"],
 ["discard", "Bought cards go to your discard. When your deck runs out, your discard shuffles into a new deck.", ""],
 ["life", "Attack cards deal damage. Keep your life above zero and eliminate your opponents.", ""],
 ["play_area", "Permanents stay in your rig. Their abilities can help each turn; some also block damage.", ""],
 ["hand", "Inspect a card: long-press on a phone, or right-click on desktop, to read its full rules.", "inspect"],
 ["log", "Open the log to review plays, purchases, damage, and card rules.", ""],
 ["end", "End Turn discards your played cards and hand, then draws your next hand. Tap End Turn now.", "end"],
 ["banner", "Watch the bot's turn. Its plays and purchases appear on the table and in the log.", "bot"],
 ["rules", "Ready to hack! Open Menu → Rules whenever you need a reference. Finish this practice game or return to the menu.", ""]]
var table
var step = 0
var stopped = false
var caption: Label
var next_button: Button
var coach: PanelContainer
var outline: Panel
var baseline_played = 0
var baseline_bought = 0
var baseline_turn = 0
func begin(owner_table):
 table = owner_table
 name = "TutorialCoach"
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 z_index = 40
 outline = Panel.new()
 outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var border = UIStyle.box(Color.TRANSPARENT, UIStyle.AMBER, 0)
 border.border_color = UIStyle.AMBER
 border.set_border_width_all(4)
 outline.add_theme_stylebox_override("panel", border)
 add_child(outline)
 UIStyle.pulse(outline, UIStyle.AMBER)
 coach = UIStyle.panel("// GUIDED FIRST GAME")
 add_child(coach)
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation", 12)
 coach.add_child(box)
 caption = UIStyle.label(box, "", 22)
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var row = HBoxContainer.new()
 box.add_child(row)
 next_button = UIStyle.button(row, "Next", advance)
 UIStyle.button(row, "Skip tutorial", skip)
 for button in row.get_children(): button.custom_minimum_size.y = 72
 enter_step()
func enter_step():
 if step >= STEPS.size(): skip(); return
 var stat = table.match_stats.seats[table.human_seat]
 baseline_played = int(stat.played.get("Hacking", 0))
 baseline_bought = stat.cards_bought
 baseline_turn = table.engine.state.turn
 caption.text = "%d / %d · %s" % [step + 1, STEPS.size(), STEPS[step][1]]
 next_button.text = "Finish" if step == STEPS.size() - 1 else "Next"
 next_button.disabled = STEPS[step][2] != ""
func advance():
 if stopped: return
 step += 1
 enter_step()
func skip():
 stopped = true
 hide()
 set_process(false)
func target():
 var key = STEPS[step][0]
 if key in ["hand", "discard", "play_area"]: key = "%d:%s" % [table.human_seat, key]
 return table.zone_anchors.get(key)
func _process(_delta):
 if stopped or table == null: return
 var view = get_viewport_rect().size
 var width = minf(620, view.x - 64)
 caption.custom_minimum_size.x = width - 40
 coach.size.x = width
 coach.reset_size()
 coach.position = Vector2(view.x - width - 32, view.y - coach.size.y - 32) if STEPS[step][0] in ["center", "log", "banner", "rules"] else Vector2(view.x - width - 32, 120)
 var control = target()
 outline.visible = is_instance_valid(control) and control.is_visible_in_tree()
 if outline.visible:
  outline.position = control.global_position - global_position - Vector2(4, 4)
  outline.size = control.size + Vector2(8, 8)
 var p = table.engine.state.players[table.human_seat]
 var stat = table.match_stats.seats[table.human_seat]
 var done = false
 match STEPS[step][2]:
  "play": done = int(stat.played.get("Hacking", 0)) > baseline_played or not table.engine.is_turn(p) or not p.hand.any(func(c): return c.id == "Hacking" and table.engine.can_play(p, c))
  "buy":
   var can_buy = table.engine.state.center_row.any(func(c): return c != null and table.engine.can_buy(p, c))
   var can_play = p.hand.any(func(c): return table.engine.can_play(p, c))
   done = stat.cards_bought > baseline_bought or not table.engine.is_turn(p) or (not can_buy and not can_play)
  "inspect": done = is_instance_valid(table.inspect_overlay) or p.hand.is_empty()
  "end": done = table.engine.state.turn > baseline_turn or not table.engine.is_turn(p) or table.engine.state.finished
  "bot": done = table.engine.state.finished or table.engine.active().seat == table.human_seat
 if done: advance()
