extends Control
signal answered(value)
var engine: GameEngine
var player_count: int = 2
var difficulty: int = 0
var scripted_decider: Decider
var auto_drive: bool = true
var fast: bool = false
var seed_value: int = 0
var pending: bool = false
var acting: bool = false
var driving: bool = false
var body: VBoxContainer
var log_view: RichTextLabel
var banner: Label
var play_button: Button
var end_button: Button
var zoom: PanelContainer
var life_labels: Dictionary = {}
var textures: Dictionary = {}
var hover_serial: int = 0
var action_notice: Label
var moved_uids: Dictionary = {}
func _ready():
 UIStyle.apply(self)
 var bg = ColorRect.new()
 bg.color = Color("080f15")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var margin = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
 add_child(margin)
 var columns = HBoxContainer.new()
 margin.add_child(columns)
 var left = VBoxContainer.new()
 left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 columns.add_child(left)
 var toolbar = HBoxContainer.new()
 left.add_child(toolbar)
 banner = UIStyle.label(toolbar, "Connecting…", 28)
 banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 UIStyle.button(toolbar, "Speed: normal", func(): fast = not fast; toolbar.get_child(1).text = "Speed: fast" if fast else "Speed: normal")
 UIStyle.button(toolbar, "Menu", menu)
 body = VBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 left.add_child(body)
 var side = VBoxContainer.new()
 side.custom_minimum_size.x = 320
 columns.add_child(side)
 UIStyle.label(side, "// NETWORK LOG", 22)
 log_view = RichTextLabel.new()
 log_view.bbcode_enabled = true
 log_view.custom_minimum_size.x = 320
 log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
 log_view.scroll_following = true
 side.add_child(log_view)
 UIStyle.label(side, "Hover / right-click to inspect", 14)
 engine = GameEngine.new()
 add_child(engine)
 var choices: Array = [scripted_decider if scripted_decider != null else HumanDecider.new(self)]
 var levels: Array = [-1]
 for i in range(1, player_count): levels.append(difficulty)
 engine.log_message.connect(append_log)
 engine.setup(levels, seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()), choices)
 engine.state_changed.connect(redraw)

 engine.damage_dealt.connect(damage)
 engine.card_moved.connect(moved)
 engine.turn_started.connect(func(p):
  append_log("TURN %d · Seat %d connected" % [engine.state.turn, p.seat])
  redraw())
 engine.game_over.connect(game_over)
 append_log("Network ready · %d players connected" % player_count)
 engine.turn_driver = drive_reaction
 await engine.start_turn()
 redraw()
func player_name(p) -> String:
 return "You" if p.seat == 0 else "Bot %d · %s" % [p.seat, BotDifficulty.DISPLAY_NAMES[p.difficulty]]
func available() -> bool:
 return engine != null and engine.is_turn(engine.state.players[0]) and not engine.busy and not pending and (not acting or engine.reaction_depth > 0)
func redraw():
 if not is_instance_valid(body) or engine.state == null: return
 for child in body.get_children():
  body.remove_child(child)
  child.queue_free()
 life_labels.clear()
 banner.text = "Your turn" if engine.active().seat == 0 else player_name(engine.active()) + " is hacking…"
 banner.text += "  /  TURN %d" % engine.state.turn
 var canvas = Control.new()
 canvas.custom_minimum_size.y = 970
 body.add_child(canvas)
 var opponents = HBoxContainer.new()
 region(canvas, opponents, Vector2(0, 0), Vector2(1538, 180))
 for p in engine.state.players.slice(1): seat_area(opponents, p, false)
 var center = HBoxContainer.new()
 center.add_theme_constant_override("separation", 18)
 region(canvas, center, Vector2(0, 220), Vector2(1538, 280))
 for c in engine.state.center_row:
  if c != null: center.add_child(card_widget(c, "market", 180))
 var piles = VBoxContainer.new()
 center.add_child(piles)
 piles.add_child(UIStyle.picture(UIStyle.BACK, Vector2(110, 150)))
 UIStyle.label(piles, "Deck: %d" % engine.state.center_deck.size())
 UIStyle.button(piles, "Removed: %d" % engine.state.removed.size(), func(): view_cards("Removed from game", engine.state.removed))
 var p = engine.state.players[0]
 var board_scroll = ScrollContainer.new()
 region(canvas, board_scroll, Vector2(0, 508), Vector2(850, 195))
 board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 var board = HBoxContainer.new()
 board_scroll.add_child(board)
 for c in p.play_area: board.add_child(card_widget(c, "permanent", 110))
 for c in p.reserve: board.add_child(card_widget(c, "reserve", 110))
 if p.play_area.is_empty() and p.reserve.is_empty(): UIStyle.label(board, "// YOUR RIG & RESERVED CARDS\nBuild your network here.", 18)
 var status = VBoxContainer.new()
 region(canvas, status, Vector2(900, 510), Vector2(600, 175))
 var stats = HBoxContainer.new()
 status.add_child(stats)
 life_labels[0] = readout(stats, "life", p.life, 48)
 readout(stats, "hack", p.hacking, 48)
 var piles_button = UIStyle.button(status, "Deck %d   /   Discard %d" % [p.deck.size(), p.discard.size()], func(): view_cards("Your discard", p.discard))
 piles_button.name = "PlayerPiles"
 var hand_title = UIStyle.label(canvas, "// YOUR HAND  ·  %d CARDS" % p.hand.size(), 16)
 hand_title.position = Vector2(0, 710)
 var hand = Control.new()
 hand.name = "Hand"
 region(canvas, hand, Vector2(0, 735), Vector2(1538, 233))
 var step = 158.0 if p.hand.size() <= 7 else minf(158.0, (1538.0 - 150) / maxf(1, p.hand.size() - 1))
 for i in p.hand.size():
  var card = card_widget(p.hand[i], "hand", 150)
  hand.add_child(card)
  card.position.x = i * step
 var actions = HBoxContainer.new()
 region(canvas, actions, Vector2(1090, 946), Vector2(440, 62))
 play_button = UIStyle.button(actions, "▶ Play All", play_all)
 end_button = UIStyle.button(actions, "End Turn →", end_human_turn)
 play_button.custom_minimum_size.y = 58
 end_button.custom_minimum_size.y = 58
 play_button.disabled = not available()
 end_button.disabled = not available()
 moved_uids.clear()
 track_life()
 if auto_drive and engine.active().is_bot and not driving and not engine.busy and not engine.state.finished: drive_bot.call_deferred()
func region(parent, node, pos: Vector2, dimensions: Vector2):
 parent.add_child(node)
 node.position = pos
 node.size = dimensions
func readout(parent, icon: String, value: int, font_size: int) -> Label:
 parent.add_child(UIStyle.picture("res://assets/icons/" + icon + ".png", Vector2(font_size, font_size)))
 return UIStyle.label(parent, str(value), font_size)
func seat_area(parent: Node, p, _human: bool):
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var status = HBoxContainer.new()
 box.add_child(status)
 UIStyle.label(status, player_name(p), 18)
 life_labels[p.seat] = readout(status, "life", p.life, 28)
 UIStyle.label(status, " · Hand %d" % p.hand.size(), 16)
 var row = HBoxContainer.new()
 box.add_child(row)
 var fan = Control.new()
 fan.custom_minimum_size = Vector2(100, 150)
 row.add_child(fan)
 for i in mini(p.hand.size(), 5):
  var back = UIStyle.picture(UIStyle.BACK, Vector2(55, 75))
  fan.add_child(back)
  back.position = Vector2(i * 8, 25 + abs(i - 2) * 3)
  back.rotation = (i - 2) * 0.07
 var scroll = ScrollContainer.new()
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size.y = 154
 scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 row.add_child(scroll)
 var board = HBoxContainer.new()
 scroll.add_child(board)
 for c in p.play_area: board.add_child(card_widget(c, "opponent", 110))
 for c in p.reserve: board.add_child(card_widget(c, "opponent_reserve", 110))
func texture_for(id: String) -> Texture2D:
 if not textures.has(id): textures[id] = load("res://assets/cards/" + id + ".jpg")
 return textures[id]
func card_widget(c, zone: String, width: int) -> Control:
 var box = VBoxContainer.new()
 box.set_meta("card_uid", c.uid)
 box.set_meta("zone", zone)
 var button = Button.new()
 button.custom_minimum_size = Vector2(width, width * 1.367)
 button.tooltip_text = engine.db().get_card(c.id).name + "\nRight-click to inspect"
 box.add_child(button)
 if moved_uids.has(c.uid):
  button.modulate.a = 0.25
  create_tween().tween_property(button, "modulate:a", 1.0, 0.25)
 var picture = TextureRect.new()
 picture.texture = texture_for(c.id)
 picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
 button.add_child(picture)
 picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var human = engine.state.players[0]
 var legal = engine.can_play(human, c) if zone == "hand" else engine.can_buy(human, c)
 if legal: button.modulate = Color("9affb1") if zone == "hand" else Color("ffda83")
 button.pressed.connect(func(): card_clicked(c, zone))
 button.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: show_zoom(c))
 button.mouse_entered.connect(func():
  hover_serial += 1
  var serial = hover_serial
  if zone == "hand":
   box.z_index = 5
   button.position.y = -30
  button.add_theme_stylebox_override("normal", hover_border())
  await get_tree().create_timer(0.4).timeout
  if is_instance_valid(button) and serial == hover_serial and not pending: show_zoom(c))
 button.mouse_exited.connect(func():
  hover_serial += 1
  if is_instance_valid(button):
   button.position.y = 0
   box.z_index = 0
   button.remove_theme_stylebox_override("normal")
  hide_zoom())
 if zone == "permanent":
  # Counters sit inside the artwork rather than consuming row height.
  if c.counters > 0 or engine.effects.initial_ice(c.effect_id()) > 0:
   var badge = PanelContainer.new()
   badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
   button.add_child(badge)
   badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
   badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
   UIStyle.label(badge, str(c.counters), 16)
  var abilities = engine.activatable_abilities(human, c)
  var ability_row = HBoxContainer.new()
  if not abilities.is_empty(): box.add_child(ability_row)
  else: ability_row.free()
  for ability in abilities:
   var b = UIStyle.button(ability_row, "Use %d" % (ability.index + 1) if abilities.size() > 1 else "Activate", activate_card.bind(c, ability.index))
   b.disabled = not available() or not ability.enabled
   b.add_theme_font_size_override("font_size", 12)
   b.tooltip_text = ability.label
 if zone == "market" or zone == "reserve":
  var cost = HBoxContainer.new()
  box.add_child(cost)
  readout(cost, "hack", engine.effective_cost(human, c), 16)
 return box
func card_clicked(c, zone: String):
 if not available(): return
 hide_zoom()
 if zone == "hand":
  acting = true
  redraw()
  await engine.play_card(engine.state.players[0], c)
  acting = false
 elif zone == "reserve":
  acting = true
  await engine.buy_card(engine.state.players[0], c)
  acting = false
 elif zone == "market":
  var p = engine.state.players[0]
  var options: Array[String] = ["Inspect", "Cancel"]
  if engine.can_buy(p, c): options.push_front("Buy — %d hacking" % engine.effective_cost(p, c))
  if engine.can_reserve(p, c): options.push_front("Reserve")
  var selected: int = await decision(engine.db().get_card(c.id).name, options, [], 1, 1, false)
  if not available(): return
  if options[selected] == "Reserve": engine.reserve_card(p, c)
  elif options[selected].begins_with("Buy"):
   acting = true
   await engine.buy_card(p, c)
   acting = false
  elif options[selected] == "Inspect": show_zoom(c)
 redraw()
func activate_card(c, index: int):
 if not available(): return
 acting = true
 redraw()
 await engine.activate(engine.state.players[0], c, index)
 acting = false
 redraw()
func play_all():
 if not available(): return
 acting = true
 redraw()
 var p = engine.state.players[0]
 # Draws and reshuffles can return an already played card to hand. Re-read
 # the live hand after each resolution, with the same safety cap as bots.
 for action in BotPlayer.MAX_ACTIONS:
  var playable = p.hand.filter(func(c): return engine.can_play(p, c))
  if playable.is_empty(): break
  await engine.play_card(p, playable[0])
 acting = false
 redraw()
func end_human_turn():
 if not available(): return
 acting = true
 redraw()
 await engine.end_turn(engine.state.players[0])
 acting = false
 redraw()
func drive_reaction(p):
 var driver = BotPlayer.new(engine)
 driver.action_delay = 0.03 if fast else 0.6
 await driver.take_turn(p)
func drive_bot():
 if driving or engine.busy or engine.state.finished or engine.reaction_depth > 0: return
 driving = true
 while engine.active().is_bot and not engine.state.finished:
  await drive_reaction(engine.active())
 driving = false
 redraw()
func decision(prompt: String, options: Array, cards: Array, min_n: int, max_n: int, multi: bool, searchable: bool = false):
 hide_zoom()
 hover_serial += 1
 pending = true
 redraw()
 var overlay = PanelContainer.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.rich_label(box, prompt, 26)
 var search = LineEdit.new()
 search.placeholder_text = "Search all card names…"
 search.visible = searchable
 box.add_child(search)
 var counter = UIStyle.label(box, "Select %d–%d" % [min_n, max_n])
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 box.add_child(scroll)
 var grid = GridContainer.new()
 grid.columns = 7 if not cards.is_empty() else 3
 scroll.add_child(grid)
 var selected: Array = []
 var buttons: Array = []
 var done = Button.new()
 done.text = "Confirm selection"
 done.disabled = min_n > 0
 done.visible = multi
 box.add_child(done)
 for i in range(cards.size() if not cards.is_empty() else options.size()):
  var b = Button.new()
  b.toggle_mode = multi
  if not cards.is_empty():
   b.icon = texture_for(cards[i].id)
   b.expand_icon = true
   b.custom_minimum_size = Vector2(180, 246)
   b.tooltip_text = engine.db().get_card(cards[i].id).name
   b.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: show_zoom(cards[i]))
   b.mouse_exited.connect(hide_zoom)
  else:
   b.text = str(options[i]).replace("{H}", "").replace("{D}", "")
   if "{H}" in str(options[i]) or "{D}" in str(options[i]):
    b.icon = load("res://assets/icons/hack.png" if "{H}" in str(options[i]) else "res://assets/icons/damage.png")
    b.add_theme_constant_override("icon_max_width", 26)
  grid.add_child(b)
  buttons.append(b)
  b.pressed.connect(func():
   if not multi: answered.emit(i); return
   if i in selected: selected.erase(i)
   elif selected.size() < max_n: selected.append(i)
   else: b.button_pressed = false
   counter.text = "Selected %d / %d–%d" % [selected.size(), min_n, max_n]
   done.disabled = selected.size() < min_n or selected.size() > max_n)
 search.text_changed.connect(func(value):
  for i in buttons.size(): buttons[i].visible = value.to_lower() in str(options[i]).to_lower())
 done.pressed.connect(func(): answered.emit(selected.duplicate()))
 var result = await answered
 remove_child(overlay)
 overlay.queue_free()
 pending = false
 redraw()
 return result
func view_cards(title: String, cards: Array):
 if pending or engine.busy or driving or acting: return
 await decision(title, ["Close"] if cards.is_empty() else [], cards, 0, 0, true)
func show_zoom(c):
 hide_zoom()
 zoom = PanelContainer.new()
 zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
 zoom.position = (get_local_mouse_position() + Vector2(24, 24)).clamp(Vector2.ZERO, size - Vector2(470, 635))
 zoom.add_child(UIStyle.picture("res://assets/cards/" + c.id + ".jpg", Vector2(450, 615)))
 zoom.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(zoom)
func hide_zoom():
 if is_instance_valid(zoom): zoom.queue_free()
 zoom = null
var previous_life: Dictionary = {}
func damage(_source, _target, _amount):
 pass # State changes also cover healing; track both through one path.
func track_life():
 for p in engine.state.players:
  var before = previous_life.get(p.seat, p.life)
  if before != p.life:
   float_life.call_deferred(p.seat, p.life - before)
  previous_life[p.seat] = p.life
func float_life(seat: int, amount: int):
 # Container positions settle at the end of the frame. Look up the current
 # label afterward: redraw may have replaced it several times during a play.
 await get_tree().process_frame
 if not life_labels.has(seat) or not is_instance_valid(life_labels[seat]): return
 var label = life_labels[seat]
 var floating = Label.new()
 floating.set_meta("life_float", true)
 floating.mouse_filter = Control.MOUSE_FILTER_IGNORE
 floating.text = "%+d" % amount
 floating.add_theme_font_size_override("font_size", 42)
 floating.modulate = Color("ff5555") if amount < 0 else Color("65ff99")
 floating.z_index = 40
 add_child(floating)
 floating.global_position = label.global_position
 var tween = floating.create_tween().set_parallel(true)
 tween.tween_property(floating, "position:y", floating.position.y - 65, 0.9)
 tween.tween_property(floating, "modulate:a", 0.0, 0.9)
 tween.chain().tween_callback(floating.queue_free)
func hover_border() -> StyleBoxFlat:
 var style = StyleBoxFlat.new()
 style.bg_color = Color("192c25")
 style.border_color = Color("90ffbb")
 style.set_border_width_all(4)
 style.expand_margin_left = 4
 style.expand_margin_right = 4
 style.expand_margin_top = 4
 style.expand_margin_bottom = 4
 return style
func append_log(message: String):
 var colors = ["8fe6b0", "efc878", "89c9ff", "d7a0f5"]
 var seat = -1
 for i in player_count:
  if "Seat %d" % i in message: seat = i
 var display = message
 for i in player_count: display = display.replace("Seat %d" % i, "You" if i == 0 else "Bot %d" % i)
 for verbs in [["plays", "play"], ["buys", "buy"], ["takes", "take"], ["reserves", "reserve"], ["reveals", "reveal"]]:
  display = display.replace("You " + verbs[0] + " ", "You " + verbs[1] + " ")
 log_view.append_text("[color=#%s]%s[/color]\n\n" % [colors[seat] if seat >= 0 else "a1b1bb", UIStyle.icon_text(display)])
 if seat > 0 and (" plays " in message or " buys " in message or " reserves " in message):
  if is_instance_valid(action_notice): action_notice.queue_free()
  var notice = Label.new()
  action_notice = notice
  notice.text = display
  notice.add_theme_font_size_override("font_size", 18)
  notice.position = Vector2(450, 22)
  notice.z_index = 20
  add_child(notice)
  var tween = create_tween()
  tween.tween_interval(1.5)
  tween.tween_property(notice, "modulate:a", 0.0, 0.2)
  tween.finished.connect(notice.queue_free)
func moved(_card, _from, _to):
 moved_uids[_card.uid] = true
 if not is_instance_valid(banner): return
 banner.modulate = Color("e9c778")
 create_tween().tween_property(banner, "modulate", Color.WHITE, 0.25)
func game_over(winner):
 show_result.call_deferred(winner)
func show_result(winner):
 var panel = PanelContainer.new()
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.position -= Vector2(300, 120)
 panel.custom_minimum_size = Vector2(600, 240)
 add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 UIStyle.label(box, "Draw" if winner == null else player_name(winner) + " wins!", 32)
 UIStyle.button(box, "Play Again", restart)
 UIStyle.button(box, "Menu", menu)
func restart():
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = player_count
 table.difficulty = difficulty
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func menu(): get_tree().change_scene_to_file("res://scenes/menu.tscn")
