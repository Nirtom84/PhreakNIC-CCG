extends Control
signal answered(value)
var resume_data: Dictionary = {}
var game_menu: Control
var rules_overlay: Control
var menu_button: Button
var speed_button: Button
var mute_button: Button
var save_button: Button
var save_status: Label
var last_autosave_turn = -1
var saving = false
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
var inspect_overlay: CanvasLayer
var zoom: PanelContainer
var life_labels: Dictionary = {}
var textures: Dictionary = {}
var hover_serial: int = 0
var spotlights: Array[Control] = []
var card_names: Array = []
## Display name per seat; bots get a random Hero card name (seat 0 is "You").
var seat_names: Array[String] = []
var seat_heroes: Array[String] = []
var turn_avatar: Control
var auto_end_elapsed: float = 0.0
var auto_end_turn_number: int = -1
var previous_hack: Dictionary = {}
var moved_uids: Dictionary = {}
func _ready():
 get_tree().auto_accept_quit = false
 fast = (fast or Sfx.bot_fast) if resume_data.is_empty() else resume_data.table.fast
 UIStyle.apply(self)
 UIStyle.background(self)
 resized.connect(func(): if engine != null and engine.state != null: redraw.call_deferred())
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
 turn_avatar = UIStyle.avatar(Sfx.hero_id, 56)
 toolbar.add_child(turn_avatar)
 banner = UIStyle.label(toolbar, "Connecting…", 28)
 banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 speed_button = UIStyle.button(toolbar, "» 4×" if fast else "» 1×", toggle_speed)
 mute_button = UIStyle.button(toolbar, "♪ OFF" if Sfx.muted else "♪ ON", func():
  Sfx.muted = not Sfx.muted
  Sfx.save())
 mute_button.pressed.connect(sync_options)
 menu_button = UIStyle.button(toolbar, "Menu", menu)
 body = VBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 left.add_child(body)
 var log_panel = UIStyle.panel("// NETWORK LOG")
 columns.add_child(log_panel)
 var side = VBoxContainer.new()
 log_panel.add_child(side)
 side.custom_minimum_size.x = 300


 log_view = RichTextLabel.new()
 log_view.bbcode_enabled = true
 log_view.add_theme_constant_override("line_separation", 2)
 log_view.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BACKGROUND, Color(UIStyle.CYAN, 0.15), 0))
 log_view.custom_minimum_size.x = 300
 log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
 log_view.scroll_following = true
 log_view.meta_underlined = true
 log_view.meta_hover_started.connect(func(id):
  if not TouchInput.touch_mode: show_log_card(str(id)))
 log_view.meta_hover_ended.connect(func(_id): hide_zoom())
 log_view.meta_clicked.connect(func(id): show_log_card(str(id)))
 side.add_child(log_view)
 TouchInput.register_scroll(log_view)
 var cursor = UIStyle.label(side, "> _", 18)
 cursor.add_theme_color_override("font_color", UIStyle.CYAN)
 if Sfx.visual_effects:
  var blink = create_tween().set_loops()
  blink.tween_property(cursor, "modulate:a", 0.0, 0.6)
  blink.tween_property(cursor, "modulate:a", 1.0, 0.6)
 UIStyle.label(side, "Right-click or long-press to inspect", 14)
 engine = GameEngine.new()
 add_child(engine)
 var choices: Array = [scripted_decider if scripted_decider != null else HumanDecider.new(self)]
 var levels: Array = [-1]
 for i in range(1, player_count): levels.append(difficulty)
 for id in CardDB.cards:
  card_names.append({"id": id, "name": str(CardDB.cards[id].name)})
 card_names.sort_custom(func(a, b): return a.name.length() > b.name.length())
 var game_seed: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
 pick_seat_names(game_seed)
 engine.log_message.connect(append_log)
 if resume_data.is_empty():
  engine.setup(levels, game_seed, choices)
 else:
  engine.state = SaveGame.restore(resume_data.game)
  player_count = engine.state.players.size()
  difficulty = engine.state.players[1].difficulty
  seat_names.assign(resume_data.table.seat_names)
  seat_heroes.assign(resume_data.table.seat_heroes)
  fast = resume_data.table.fast
  engine.deciders = choices
  for p in engine.state.players.slice(1): engine.deciders.append(BotDecider.new(engine, p.difficulty))
  log_view.text = resume_data.table.log
  for p in engine.state.players:
   previous_life[p.seat] = p.life
   previous_hack[p.seat] = p.hacking
  last_autosave_turn = engine.state.turn
  sync_options()
 engine.state_changed.connect(redraw)

 engine.ice_counter_removed.connect(func(_card): Sfx.play("ice"))
 engine.damage_dealt.connect(damage)
 engine.card_moved.connect(moved)
 engine.turn_started.connect(func(p):
  Sfx.play("turn_start")
  if p.seat == 0: clear_spotlights(1.5)
  append_log("TURN %d · Seat %d connected" % [engine.state.turn, p.seat])
  turn_band(p)
  redraw())
 engine.game_over.connect(game_over)
 if resume_data.is_empty(): append_log("Network ready · %d players connected" % player_count)
 engine.turn_driver = drive_reaction
 if resume_data.is_empty(): await engine.start_turn()
 auto_save()
 redraw()
func pick_seat_names(game_seed: int):
 var heroes: Array[String] = []
 var hero_ids: Dictionary = {}
 for id in CardDB.cards:
  var card = CardDB.cards[id]
  var name := str(card.name)
  if not card.get("starter", false) and CardDB.has_subtype(id, "Hero") and name not in heroes and name.to_lower() != Sfx.handle.to_lower() and id != Sfx.hero_id:
   heroes.append(name)
   hero_ids[name] = id
 var rng = RandomNumberGenerator.new()
 rng.seed = game_seed
 seat_heroes = [Sfx.hero_id]
 seat_names = [Sfx.handle if not Sfx.handle.is_empty() else "You"]
 for i in range(1, player_count):
  var pick = heroes.pop_at(rng.randi_range(0, heroes.size() - 1)) if not heroes.is_empty() else "Bot %d" % i
  while pick.to_lower() == seat_names[0].to_lower(): pick += "_"
  seat_names.append(pick)
  seat_heroes.append(hero_ids.get(pick, ""))
func seat_name(seat: int) -> String:
 return seat_names[seat] if seat < seat_names.size() else ("You" if seat == 0 else "Bot %d" % seat)
func player_name(p) -> String:
 return seat_name(0) if p.seat == 0 else "%s · %s" % [seat_name(p.seat), BotDifficulty.DISPLAY_NAMES[p.difficulty]]
func available() -> bool:
 return engine != null and engine.is_turn(engine.state.players[0]) and not engine.busy and not pending and (not acting or engine.reaction_depth > 0)
func redraw():
 auto_end_elapsed = 0
 auto_end_turn_number = -1
 if not is_instance_valid(body) or engine.state == null: return
 for child in body.get_children():
  body.remove_child(child)
  child.queue_free()
 life_labels.clear()
 banner.text = "Your turn" if engine.active().seat == 0 else player_name(engine.active()) + " is hacking…"
 banner.text += "  /  TURN %02d" % engine.state.turn
 banner.add_theme_color_override("font_color", UIStyle.GREEN if engine.active().seat == 0 else UIStyle.AMBER)
 var avatar_source = UIStyle.avatar(seat_heroes[engine.active().seat])
 turn_avatar.get_child(0).texture = avatar_source.get_child(0).texture
 avatar_source.free()
 var width = maxf(1538, size.x - 382)
 var canvas = Control.new()
 canvas.custom_minimum_size.y = 990
 body.add_child(canvas)
 var opponents = HBoxContainer.new()
 region(canvas, opponents, Vector2(0, 0), Vector2(width, 220), "// REMOTE HOSTS")
 for p in engine.state.players.slice(1): seat_area(opponents, p, false)
 var center = HBoxContainer.new()
 center.add_theme_constant_override("separation", maxi(18, int((width - 1120) / 5)))
 region(canvas, center, Vector2(0, 240), Vector2(width, 300), "// CENTER ROW")
 for c in engine.state.center_row:
  if c != null: center.add_child(card_widget(c, "market", 170))
  else:
   var slot = UIStyle.panel()
   slot.custom_minimum_size = Vector2(170, 233)
   slot.add_theme_stylebox_override("panel", UIStyle.box(Color(0.02,0.04,0.05,0.4), Color(UIStyle.CYAN,0.2), 0))
   center.add_child(slot)
 var piles = VBoxContainer.new()
 center.add_child(piles)
 piles.add_child(UIStyle.picture(UIStyle.BACK, Vector2(110, 150)))
 UIStyle.label(piles, "Deck: %d" % engine.state.center_deck.size())
 UIStyle.button(piles, "Removed: %d" % engine.state.removed.size(), func(): view_cards("Removed from game", engine.state.removed))
 var p = engine.state.players[0]
 var board_scroll = ScrollContainer.new()
 TouchInput.register_scroll(board_scroll)
 region(canvas, board_scroll, Vector2(0, 560), Vector2(width - 688, 194), "// YOUR RIG & RESERVED")
 board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 var board = HBoxContainer.new()
 board_scroll.add_child(board)
 for c in p.play_area: board.add_child(card_widget(c, "permanent", 100))
 for c in p.reserve: board.add_child(card_widget(c, "reserve", 100))
 if p.play_area.is_empty() and p.reserve.is_empty():
  board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var placeholder = UIStyle.label(board, "Build your network here.", 18)
  placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  placeholder.add_theme_color_override("font_color", UIStyle.MUTED)
 var status = VBoxContainer.new()
 region(canvas, status, Vector2(width - 638, 560), Vector2(600, 194), "// " + seat_name(0).to_upper() + " / SYSTEM STATUS")
 var stats = HBoxContainer.new()
 status.add_child(stats)
 stats.add_child(UIStyle.avatar(seat_heroes[0], 56))
 life_labels[0] = readout(stats, "life", p.life, 40)
 readout(stats, "hack", p.hacking, 40)
 var piles_button = UIStyle.button(status, "Deck %d   /   Discard %d" % [p.deck.size(), p.discard.size()], func(): view_cards("Your discard", p.discard))
 piles_button.name = "PlayerPiles"
 var hand = Control.new()
 hand.name = "Hand"
 region(canvas, hand, Vector2(0, 774), Vector2(width, 214), "// YOUR HAND · %d" % p.hand.size())
 var step = 158.0 if p.hand.size() <= 7 else minf(158.0, (width - 150) / maxf(1, p.hand.size() - 1))
 for i in p.hand.size():
  var card = card_widget(p.hand[i], "hand", 140)
  hand.add_child(card)
  card.position.x = i * step
 var actions = HBoxContainer.new()
 status.add_child(actions)
 play_button = UIStyle.button(actions, "▶ Play All", play_all)
 end_button = UIStyle.button(actions, "End Turn →", end_human_turn)
 play_button.custom_minimum_size.y = 38
 end_button.custom_minimum_size.y = 38
 play_button.disabled = not available()
 end_button.disabled = not available()
 UIStyle.primary(end_button)
 if available() and p.hand.filter(func(c): return engine.can_play(p, c)).is_empty(): UIStyle.pulse(end_button)
 moved_uids.clear()
 track_life()
 if auto_drive and engine.active().is_bot and not driving and not engine.busy and not engine.state.finished: drive_bot.call_deferred()
func region(parent, node, pos: Vector2, dimensions: Vector2, title: String = ""):
 if title.is_empty():
  parent.add_child(node)
  node.position = pos
  node.size = dimensions
 else:
  var frame = UIStyle.panel(title)
  parent.add_child(frame)
  frame.position = pos
  frame.size = dimensions
  frame.add_child(node)
func readout(parent, icon: String, value: int, font_size: int) -> Label:
 var frame = UIStyle.panel()
 frame.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BACKGROUND, UIStyle.GREEN if icon == "life" else UIStyle.AMBER, 3))
 parent.add_child(frame)
 var row = HBoxContainer.new()
 frame.add_child(row)
 row.add_child(UIStyle.picture("res://assets/icons/" + icon + ".png", Vector2(font_size, font_size)))
 var number = UIStyle.label(row, str(value), font_size)
 if icon == "hack" and font_size >= 40: number.name = "HackGauge"
 number.add_theme_font_override("font", UIStyle.heading())
 var color = UIStyle.AMBER
 if icon == "life": color = UIStyle.GREEN if value > 10 else (UIStyle.AMBER if value > 5 else UIStyle.RED)
 number.add_theme_color_override("font_color", color)
 return number
func seat_area(parent: Node, p, _human: bool):
 var panel = UIStyle.panel()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var inset = UIStyle.box()
 inset.set_content_margin_all(0)
 panel.add_theme_stylebox_override("panel", inset)
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var status = HBoxContainer.new()
 box.add_child(status)
 status.add_child(UIStyle.avatar(seat_heroes[p.seat], 56))
 UIStyle.label(status, seat_name(p.seat), 24)
 var badge = UIStyle.label(status, BotDifficulty.DISPLAY_NAMES[p.difficulty].to_upper(), 14)
 badge.add_theme_color_override("font_color", [UIStyle.GREEN, UIStyle.AMBER, UIStyle.RED][p.difficulty])
 life_labels[p.seat] = readout(status, "life", p.life, 28)
 var life_frame = life_labels[p.seat].get_parent().get_parent()
 var compact = life_frame.get_theme_stylebox("panel").duplicate()
 compact.content_margin_top = 2
 compact.content_margin_bottom = 2
 life_frame.add_theme_stylebox_override("panel", compact)
 UIStyle.label(status, " · Hand %d · Deck %d · Discard %d" % [p.hand.size(), p.deck.size(), p.discard.size()], 16)
 var row = HBoxContainer.new()
 box.add_child(row)
 var fan = Control.new()
 fan.custom_minimum_size = Vector2(100, 100)
 row.add_child(fan)
 for i in mini(p.hand.size(), 5):
  var back = UIStyle.picture(UIStyle.BACK, Vector2(55, 75))
  fan.add_child(back)
  back.position = Vector2(i * 8, 25 + abs(i - 2) * 3)
  back.rotation = (i - 2) * 0.07
 # Discard pile is public: show its top card face up and let the human browse it.
 var pile = VBoxContainer.new()
 row.add_child(pile)
 if p.discard.is_empty():
  var empty = UIStyle.label(pile, "Discard\nempty", 14)
  empty.custom_minimum_size = Vector2(60, 75)
 else:
  pile.add_child(card_widget(p.discard.back(), "opponent", 55))
 var opponent_name = seat_name(p.seat)
 UIStyle.button(pile, "Discard (%d)" % p.discard.size(), func(): view_cards("%s's discard pile" % opponent_name, p.discard))
 var scroll = ScrollContainer.new()
 TouchInput.register_scroll(scroll)
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size.y = 137
 scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 row.add_child(scroll)
 var board = HBoxContainer.new()
 scroll.add_child(board)
 for c in p.play_area: board.add_child(card_widget(c, "opponent", 100))
 for c in p.reserve: board.add_child(card_widget(c, "opponent_reserve", 100))
func texture_for(id: String) -> Texture2D:
 if not textures.has(id): textures[id] = load("res://assets/cards/" + id + ".jpg")
 return textures[id]
func card_widget(c, zone: String, width: int) -> Control:
 var box = VBoxContainer.new()
 box.set_meta("card_uid", c.uid)
 box.set_meta("zone", zone)
 var button = Button.new()
 button.custom_minimum_size = Vector2(width, width * 1.367)
 button.tooltip_text = engine.db().get_card(c.id).name + "\nRight-click or long-press to inspect"
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
 var accent = UIStyle.GREEN if zone == "hand" and legal else (UIStyle.AMBER if zone in ["market", "reserve"] and legal else Color(0,0,0,0.8))
 var card_style = UIStyle.box(UIStyle.BACKGROUND, accent, 7)
 card_style.set_content_margin_all(0)
 card_style.set_border_width_all(2)
 card_style.set_expand_margin_all(2)
 button.add_theme_stylebox_override("normal", card_style)
 button.add_theme_stylebox_override("hover", hover_border())
 button.add_theme_stylebox_override("pressed", hover_border())
 TouchInput.register_card(button, func(): inspect_card(c))
 button.pressed.connect(func(): card_clicked(c, zone))
 button.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: show_zoom(c))
 button.mouse_entered.connect(func():
  if TouchInput.touch_mode: return
  hover_serial += 1
  var serial = hover_serial
  if zone == "hand":
   box.z_index = 5
   button.position.y = -30
  button.add_theme_stylebox_override("normal", hover_border())
  await get_tree().create_timer(0.4).timeout
  if is_instance_valid(button) and serial == hover_serial and not pending and not TouchInput.touch_mode: show_zoom(c))
 button.mouse_exited.connect(func():
  hover_serial += 1
  if is_instance_valid(button):
   button.position.y = 0
   box.z_index = 0
   button.add_theme_stylebox_override("normal", card_style)
  hide_zoom())
 if zone in ["permanent", "opponent", "opponent_reserve"]:
  # Counters sit inside the artwork rather than consuming row height.
  if c.counters > 0 or engine.effects.initial_ice(c.effect_id()) > 0:
   var badge = PanelContainer.new()
   badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
   button.add_child(badge)
   badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
   badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
   UIStyle.label(badge, str(c.counters), 16)
  var abilities = engine.activatable_abilities(human, c) if zone == "permanent" else []
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
 elif zone in ["market", "reserve"]:
  var p = engine.state.players[0]
  var options: Array[String] = ["Inspect", "Cancel"]
  if engine.can_buy(p, c): options.push_front("Buy — %d hacking" % engine.effective_cost(p, c))
  if zone == "market" and engine.can_reserve(p, c): options.push_front("Reserve")
  var selected: int = await decision(engine.db().get_card(c.id).name, options, [], 1, 1, false, false, c)
  if not available(): return
  if options[selected] == "Reserve": engine.reserve_card(p, c)
  elif options[selected].begins_with("Buy"):
   acting = true
   await engine.buy_card(p, c)
   acting = false
  elif options[selected] == "Inspect":
   if TouchInput.touch_mode: inspect_card(c)
   else: show_zoom(c)
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
func decision(prompt: String, options: Array, cards: Array, min_n: int, max_n: int, multi: bool, searchable: bool = false, preview_card = null):
 hide_zoom()
 hover_serial += 1
 pending = true
 redraw()
 var overlay = UIStyle.panel("// SECURE INPUT")
 overlay.add_to_group("touch_modal")
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.rich_label(box, escaped(prompt), 26)
 var search = LineEdit.new()
 search.placeholder_text = "Search all card names…"
 search.visible = searchable
 box.add_child(search)
 var counter = UIStyle.label(box, "Select %d–%d" % [min_n, max_n])
 counter.visible = multi
 var scroll = ScrollContainer.new()
 TouchInput.register_scroll(scroll)
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 box.add_child(scroll)
 var grid = GridContainer.new()
 grid.columns = mini(cards.size(), 7) if not cards.is_empty() else (2 if options.size() > 6 else 1)
 grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(grid)
 var selected: Array = []
 var buttons: Array = []
 var done = Button.new()
 done.text = "Confirm selection"
 done.disabled = min_n > 0
 done.visible = multi
 box.add_child(done)
 var rows = ceili(float(cards.size() if not cards.is_empty() else options.size()) / grid.columns)
 var dimensions = Vector2(grid.columns * 178, rows * 241 + 120) if not cards.is_empty() else Vector2(640, rows * 60 + 65)
 if preview_card != null:
  dimensions = Vector2(860, maxf(310, dimensions.y))
  var padding = StyleBoxEmpty.new()
  padding.content_margin_left = 220
  scroll.add_theme_stylebox_override("panel", padding)
  var preview = UIStyle.picture("res://assets/cards/" + preview_card.id + ".jpg", Vector2(200, 274))
  overlay.add_child(preview)
  preview.set_as_top_level(true)
  var place = func(): preview.global_position = box.global_position + Vector2(0, 42)
  box.resized.connect(place)
  box.item_rect_changed.connect(place)
 UIStyle.dialog(overlay, dimensions)
 UIStyle.primary(done)
 for i in range(cards.size() if not cards.is_empty() else options.size()):
  var b = Button.new()
  b.toggle_mode = multi
  b.add_theme_stylebox_override("pressed", hover_border())
  if multi and not cards.is_empty():
   var check = UIStyle.label(b, "✓", 26)
   check.position = Vector2(8, 4)
   check.mouse_filter = Control.MOUSE_FILTER_IGNORE
   check.visible = false
   b.toggled.connect(func(on): check.visible = on)
  if not cards.is_empty():
   b.icon = texture_for(cards[i].id)
   b.expand_icon = true
   b.custom_minimum_size = Vector2(170, 233)
   TouchInput.register_card(b, func(): inspect_card(cards[i]))
   b.tooltip_text = engine.db().get_card(cards[i].id).name + "\nRight-click or long-press to inspect"
   b.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: show_zoom(cards[i]))
   b.mouse_exited.connect(hide_zoom)
  else:
   b.custom_minimum_size.y = 56
   b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   b.text = str(options[i]).replace("{H}", "").replace("{D}", "")
   if "{H}" in str(options[i]) or "{D}" in str(options[i]):
    b.icon = load("res://assets/icons/hack.png" if "{H}" in str(options[i]) else "res://assets/icons/damage.png")
    b.add_theme_constant_override("icon_max_width", 26)
  grid.add_child(b)
  buttons.append(b)
  b.pressed.connect(func():
   Sfx.play("button")
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
 if TouchInput.touch_mode: return
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
 for player in engine.state.players:
  if player.hacking > int(previous_hack.get(player.seat, player.hacking)): Sfx.play("hack")
  if player.seat == 0 and player.hacking != int(previous_hack.get(player.seat, player.hacking)):
   var status = body.find_child("HackGauge", true, false)
   if status != null: flash_readout(status)
  previous_hack[player.seat] = player.hacking
 for p in engine.state.players:
  var before = previous_life.get(p.seat, p.life)
  if before != p.life:
   Sfx.play("damage" if p.life < before else "life_gain")
   float_life.call_deferred(p.seat, p.life - before)
   if life_labels.has(p.seat): flash_readout(life_labels[p.seat])
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
 floating.add_theme_font_override("font", UIStyle.heading())
 floating.add_theme_color_override("font_outline_color", UIStyle.BACKGROUND)
 floating.add_theme_constant_override("outline_size", 6)
 floating.modulate = UIStyle.RED if amount < 0 else UIStyle.GREEN
 floating.z_index = 40
 add_child(floating)
 floating.global_position = label.global_position
 var tween = floating.create_tween().set_parallel(true)
 tween.tween_property(floating, "position:y", floating.position.y - 65, 0.9)
 tween.tween_property(floating, "modulate:a", 0.0, 0.9)
 tween.chain().tween_callback(floating.queue_free)
func hover_border() -> StyleBoxFlat:
 var style = UIStyle.box(Color.TRANSPARENT, UIStyle.CYAN, 12)
 style.set_border_width_all(2)
 style.set_expand_margin_all(3)
 return style
func append_log(message: String):
 var colors = ["8fe6b0", "efc878", "89c9ff", "d7a0f5"]
 var seat = -1
 for i in player_count:
  if "Seat %d" % i in message: seat = i
 var display = message
 for i in player_count: display = display.replace("Seat %d" % i, seat_name(i))
 for verbs in [["plays", "play"], ["buys", "buy"], ["takes", "take"], ["reserves", "reserve"], ["reveals", "reveal"]]:
  if Sfx.handle.is_empty() and message.begins_with("Seat 0 " + verbs[0] + " "):
   display = "You " + verbs[1] + " " + display.substr(("You " + verbs[0] + " ").length())
 log_view.append_text("[color=#%s]%s[/color]\n" % [colors[seat] if seat >= 0 else "a1b1bb", "[color=#536c78]> [/color]" + link_cards(display)])
 for action in ["plays", "buys", "reserves"]:
  if " " + action + " " not in message: continue
  Sfx.play({"plays": "card_play", "buys": "buy", "reserves": "reserve"}[action])
  if seat > 0:
   var name_part = message.split(" " + action + " ", true, 1)[1]
   for card in card_names:
    if name_part == card.name or name_part.begins_with(card.name + " for "):
     spotlight(card.id, "%s %s %s" % [seat_name(seat), {"plays": "played", "buys": "bought", "reserves": "reserved"}[action], card.name])
     break
func escaped(text: String) -> String:
 return UIStyle.escape_bbcode(text)
func link_cards(message: String) -> String:
 var result = ""
 var offset = 0
 while offset < message.length():
  var match_card = null
  for card in card_names:
   if message.substr(offset).begins_with(card.name):
    var end = offset + card.name.length()
    if (offset == 0 or not word_character(message[offset - 1])) and (end == message.length() or not word_character(message[end])):
     match_card = card
     break
  if match_card != null:
   result += "[url=%s][color=#efc878]%s[/color][/url]" % [str(match_card.id).uri_encode(), escaped(match_card.name)]
   offset += match_card.name.length()
  else:
   result += escaped(message[offset])
   offset += 1
 return UIStyle.icon_text(result)
func word_character(character: String) -> bool:
 return character.to_lower() != character.to_upper() or character in "0123456789_"
func show_log_card(id: String):
 id = id.uri_decode()
 if not CardDB.cards.has(id): return
 if TouchInput.touch_mode:
  inspect_card({"id": id})
  return
 show_zoom({"id": id})
 zoom.position = Vector2(maxf(0, log_view.global_position.x - 480), clampf(get_local_mouse_position().y - 300, 0, maxf(0, size.y - 635)))
## Fades out bot spotlights so they never hide the center row during the human's turn.
func clear_spotlights(delay: float):
 for panel in spotlights.duplicate():
  if not is_instance_valid(panel): continue
  var tween = panel.create_tween()
  tween.tween_interval(delay)
  tween.tween_property(panel, "modulate:a", 0.0, 0.3)
  tween.tween_callback(func():
   spotlights.erase(panel)
   if is_instance_valid(panel): panel.queue_free())
func spotlight(id: String, caption: String):
 # Four side-by-side slots over the center row; wait for a free slot so cards never overlap.
 var slot = -1
 while slot < 0:
  var used = spotlights.map(func(s): return s.get_meta("slot"))
  for i in 4:
   if i not in used:
    slot = i
    break
  if slot < 0: await get_tree().create_timer(0.1).timeout
 # A queued spotlight that only gets a slot once the human's turn has begun is dropped.
 if not is_inside_tree() or (engine.active().seat == 0 and not engine.state.finished): return
 var panel = PanelContainer.new()
 panel.set_meta("slot", slot)
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.z_index = 15
 panel.position = Vector2(30 + slot * 360, 215)
 var box = VBoxContainer.new()
 box.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_child(box)
 var image = UIStyle.picture("res://assets/cards/" + id + ".jpg", Vector2(330, 450))
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 box.add_child(image)
 var label = UIStyle.label(box, caption, 16)
 label.custom_minimum_size.x = 330
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(panel)
 spotlights.append(panel)
 panel.modulate.a = 0
 var tween = panel.create_tween()
 tween.tween_property(panel, "modulate:a", 1.0, 0.2)
 tween.tween_interval(4.6)
 tween.tween_property(panel, "modulate:a", 0.0, 0.2)
 tween.tween_callback(func():
  spotlights.erase(panel)
  if is_instance_valid(panel): panel.queue_free())
func moved(_card, _from, _to):
 moved_uids[_card.uid] = true
 if _to == "hand" and _from == "deck": Sfx.play("card_draw")
 if _from == "discard" and _to == "deck": Sfx.play("shuffle")
 if not is_instance_valid(banner): return
 banner.modulate = Color("e9c778")
 create_tween().tween_property(banner, "modulate", Color.WHITE, 0.25)
func game_over(winner):
 SaveGame.remove()
 Sfx.play("win" if winner != null and winner.seat == 0 else "lose")
 show_result.call_deferred(winner)
func show_result(winner):
 var dim = ColorRect.new()
 dim.color = Color(0,0,0,0.6)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(dim)
 var panel = UIStyle.panel("// CONNECTION STATUS")
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 panel.position -= Vector2(300, 120)
 panel.custom_minimum_size = Vector2(600, 240)
 add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var headline = UIStyle.label(box, "STALEMATE" if winner == null else ("ACCESS GRANTED" if winner.seat == 0 else "CONNECTION TERMINATED"), 42)
 headline.add_theme_color_override("font_color", UIStyle.AMBER if winner == null else (UIStyle.GREEN if winner.seat == 0 else UIStyle.RED))
 UIStyle.label(box, "Connection closed" if winner == null else player_name(winner) + " wins!", 22)
 if winner != null: box.add_child(UIStyle.avatar(seat_heroes[winner.seat]))
 UIStyle.glitch(headline)
 UIStyle.button(box, "Play Again", restart)
 UIStyle.button(box, "Menu", menu)
func restart():
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = player_count
 table.difficulty = difficulty
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func menu():
 if is_instance_valid(game_menu): close_menu(); return
 if pending: return
 hide_zoom()
 auto_end_elapsed = 0
 var blocker = Control.new()
 game_menu = blocker
 blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 blocker.add_to_group("touch_modal")
 add_child(blocker)
 blocker.gui_input.connect(func(event):
  if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: close_menu())
 var panel = UIStyle.panel("// GAME MENU")
 blocker.add_child(panel)
 panel.mouse_filter = Control.MOUSE_FILTER_STOP
 var right = menu_button.global_position.x + menu_button.size.x
 panel.position = Vector2(maxf(16, right - 500), menu_button.global_position.y + menu_button.size.y + 8)
 panel.custom_minimum_size = Vector2(500, 0)
 var scroll = ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(480, minf(850, size.y - panel.position.y - 40))
 panel.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(box)
 UIStyle.button(box, "Resume", close_menu).custom_minimum_size.y = 56
 UIStyle.label(box, "Options", 24)
 for setting in ["muted", "visual_effects", "auto_end_turn"]:
  var toggle = CheckButton.new()
  toggle.text = {"muted": "Sound enabled", "visual_effects": "Visual effects", "auto_end_turn": "Auto-end turn"}[setting]
  toggle.custom_minimum_size.y = 56
  toggle.button_pressed = not Sfx.muted if setting == "muted" else Sfx.get(setting)
  box.add_child(toggle)
  toggle.toggled.connect(func(value):
   Sfx.set(setting, not value if setting == "muted" else value)
   Sfx.save()
   sync_options())
 var volume = HSlider.new()
 volume.custom_minimum_size.y = 56
 volume.max_value = 1.0
 volume.step = 0.01
 volume.value = Sfx.volume
 UIStyle.label(box, "Volume")
 box.add_child(volume)
 volume.value_changed.connect(func(value): Sfx.volume = value; Sfx.save())
 UIStyle.button(box, "Bot speed: " + ("4×" if fast else "1×"), func(): toggle_speed(); close_menu(); menu()).custom_minimum_size.y = 56
 UIStyle.button(box, "Rules", func():
  close_menu()
  rules_overlay = RulesPage.open(self)).custom_minimum_size.y = 56
 save_button = UIStyle.button(box, "Save game", func():
  if save_game(): save_status.text = "Game saved"
  else: save_status.text = "Could not save game")
 save_button.custom_minimum_size.y = 56
 save_status = UIStyle.label(box, "", 16)
 save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 UIStyle.button(box, "Main menu", leave_game.bind(false)).custom_minimum_size.y = 56
 UIStyle.button(box, "Exit game", leave_game.bind(true)).custom_minimum_size.y = 56
 update_save_button()
func close_menu():
 if is_instance_valid(game_menu):
  game_menu.queue_free()
 game_menu = null
 auto_end_elapsed = 0
func toggle_speed():
 fast = not fast
 Sfx.bot_fast = fast
 Sfx.save()
 sync_options()
func sync_options():
 speed_button.text = "» 4×" if fast else "» 1×"
 mute_button.text = "♪ OFF" if Sfx.muted else "♪ ON"
func can_save() -> bool:
 return not saving and not pending and not acting and not driving and SaveGame.safe(engine) and not engine.state.players[0].is_bot and engine.state.players.slice(1).all(func(p): return p.is_bot)
func save_game() -> bool:
 if not can_save(): return false
 saving = true
 auto_end_elapsed = 0
 var ok = SaveGame.write(engine, {"seat_names": seat_names, "seat_heroes": seat_heroes, "player_count": player_count, "difficulties": engine.state.players.map(func(p): return p.difficulty), "handle": seat_names[0], "hero_id": seat_heroes[0], "fast": fast, "log": log_view.text})
 saving = false
 return ok
func auto_save():
 if can_save() and last_autosave_turn != engine.state.turn:
  if save_game(): last_autosave_turn = engine.state.turn
func update_save_button():
 if not is_instance_valid(game_menu): return
 save_button.disabled = not can_save()
 if save_button.disabled: save_status.text = "Save is available on your turn when nothing is resolving"
 elif save_status.text.begins_with("Save is available"): save_status.text = ""
func leave_game(quit_game: bool):
 close_menu()
 if not engine.state.finished and not save_game():
  if pending: return
  var answer = await decision("Leave without saving? Progress since the last save will be lost.", ["Leave", "Stay"], [], 1, 1, false)
  if answer != 0: return
 if quit_game: get_tree().quit()
 else: get_tree().change_scene_to_file("res://scenes/menu.tscn")

func turn_band(p):
 var band = UIStyle.panel()
 band.mouse_filter = Control.MOUSE_FILTER_IGNORE
 band.position = Vector2(-size.x, 360)
 band.size = Vector2(size.x, 100)
 var row = HBoxContainer.new()
 band.add_child(row)
 row.add_child(UIStyle.avatar(seat_heroes[p.seat]))
 add_child(band)
 var text = UIStyle.label(row, ("YOUR TURN" + (" · " + seat_name(0).to_upper() if not Sfx.handle.is_empty() else "")) if p.seat == 0 else seat_name(p.seat).to_upper() + " IS HACKING…", 48)
 text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 UIStyle.glitch(text)
 text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 text.add_theme_color_override("font_color", UIStyle.GREEN if p.seat == 0 else UIStyle.AMBER)
 var t = create_tween()
 t.tween_property(band, "position:x", 0.0, 0.18 if Sfx.visual_effects else 0.0)
 t.tween_interval(0.85)
 t.tween_property(band, "modulate:a", 0.0, 0.17)
 t.tween_callback(band.queue_free)

func flash_readout(node: Control):
 if not Sfx.visual_effects: return
 node.modulate = Color(1.5, 1.5, 1.5)
 node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.35)

func inspect_card(c):
 hide_zoom()
 hover_serial += 1
 close_inspect()
 inspect_overlay = CanvasLayer.new()
 inspect_overlay.layer = 100
 inspect_overlay.add_to_group("touch_modal")
 add_child(inspect_overlay)
 var dim = ColorRect.new()
 dim.color = Color(0, 0, 0, 0.7)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 inspect_overlay.add_child(dim)
 UIStyle.viewport_cover(dim)
 var image = TextureRect.new()
 image.texture = texture_for(c.id)
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 dim.add_child(image)
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.offset_top = 20
 image.offset_bottom = -65
 var hint = UIStyle.label(dim, "Tap anywhere to close", 22)
 hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 hint.offset_top = -55
 hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 dim.gui_input.connect(func(event):
  if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
   dim.accept_event()
   # Keep the blocker through release, so the closing gesture cannot hit the table.
   dim.set_meta("closing", true)
   image.hide()
   hint.hide()
  elif dim.has_meta("closing") and ((event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed)):
   dim.accept_event()
   close_inspect())
func close_inspect():
 if is_instance_valid(inspect_overlay):
  remove_child(inspect_overlay)
  inspect_overlay.queue_free()
 inspect_overlay = null
func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()
 if what == NOTIFICATION_APPLICATION_PAUSED: save_game()
 if what == NOTIFICATION_WM_CLOSE_REQUEST: leave_game(true)
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"): go_back(); get_viewport().set_input_as_handled()
func go_back():
 if is_instance_valid(inspect_overlay): close_inspect()
 elif is_instance_valid(rules_overlay): rules_overlay.queue_free(); rules_overlay = null
 elif is_instance_valid(game_menu): close_menu()
 elif not pending: menu()

func _input(event):
 if event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION):
  hover_serial += 1
  hide_zoom()
  for control in TouchInput.cards:
   if is_ancestor_of(control) and control.get_parent().get_meta("zone", "") == "hand":
    control.position.y = 0
    control.get_parent().z_index = 0

func nothing_left() -> bool:
 if engine == null or engine.state == null or not available() or acting or driving or engine.reaction_depth > 0 or not engine.state.resolving.is_empty() or is_instance_valid(inspect_overlay): return false
 var p = engine.state.players[0]
 for c in p.hand:
  if engine.can_play(p, c): return false
 for c in engine.state.center_row:
  if c != null and (engine.can_buy(p, c) or engine.can_reserve(p, c)): return false
 for c in p.reserve:
  if engine.can_buy(p, c): return false
 for c in p.play_area:
  for ability in engine.activatable_abilities(p, c):
   if ability.enabled: return false
 return true
func _process(delta):
 auto_save()
 update_save_button()
 if saving or is_instance_valid(game_menu) or is_instance_valid(rules_overlay) or not Sfx.auto_end_turn or not nothing_left():
  auto_end_elapsed = 0
  auto_end_turn_number = -1
  return
 if auto_end_turn_number != engine.state.turn:
  auto_end_turn_number = engine.state.turn
  auto_end_elapsed = 0
  append_log("No moves left — ending turn")
 banner.text = "No moves left — ending turn"
 auto_end_elapsed += delta
 if auto_end_elapsed >= 1.2:
  auto_end_elapsed = 0
  end_human_turn()
