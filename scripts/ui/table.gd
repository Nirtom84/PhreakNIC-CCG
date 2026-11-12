extends Control
var lifetime_recorded = false
var lifetime_test_enabled = false
var lifetime_key = ""
signal answered(value)
var online_session: OnlineSession
var human_seat = 0
var tutorial_mode = false
var tutorial_coach
var online_prompt_id = ""
var online_over = false
var online_final_players: Array = []
var countdowns: Dictionary = {}
var emote_ui
var connection_dot: Label
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
var starting_life: int = 0
var match_stats = preload("res://scripts/ui/match_stats.gd").new()
var engine: GameEngine
var player_count: int = 2
var difficulty: int = 0
var card_pool: String = "2026"
var banned: Array = []
var ban_picker: Control
var scripted_decider: Decider
var auto_drive: bool = true
var bot_pace: float = -1.0
var pace_popup: PopupPanel
var last_bot_action_delay = 0.0
var seed_value: int = 0
var pending: bool = false
# Answer the Back button / Escape gives the open dialog: its Cancel-like option, or null when Back should do nothing.
var back_answer = null
var acting: bool = false
var driving: bool = false
var body: VBoxContainer
var log_entries: Array = []
var log_panel: PanelContainer
var log_ticker: Button
var log_open = true
var selected_hand = null
var hand_selection: Control
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
var opening_rickroll = null
var incoming_source: String = "another player"
var table_rule_uids: Array = []
var safe_extra = Vector2.ZERO
func _ready():
 if tutorial_mode:
  player_count = 2
  difficulty = 0
  seed_value = preload("res://scripts/ui/tutorial.gd").SEED
  card_pool = "2025"
  banned = []
  starting_life = 0
 CardDB.select_pool(card_pool)
 install_page_listeners()
 get_tree().auto_accept_quit = false
 bot_pace = (Sfx.bot_pace if bot_pace < 0 else Sfx.nearest(bot_pace)) if resume_data.is_empty() else Sfx.saved_pace(resume_data.table)
 UIStyle.rotate_prompt(self)
 UIStyle.apply(self)
 UIStyle.background(self)
 resized.connect(func(): if engine != null and engine.state != null: redraw.call_deferred())
 var margin = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
 if OS.has_feature("android"):
  var safe = DisplayServer.get_display_safe_area()
  var screen = DisplayServer.screen_get_size()
  if safe.has_area():
   var scale_factor = get_viewport_rect().size / Vector2(screen)
   safe_extra = Vector2(maxf(0, safe.position.x * scale_factor.x - 16), maxf(0, (screen.x - safe.end.x) * scale_factor.x - 16))
   margin.add_theme_constant_override("margin_left", maxi(16, int(safe.position.x * scale_factor.x)))
   margin.add_theme_constant_override("margin_right", maxi(16, int((screen.x - safe.end.x) * scale_factor.x)))
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
 speed_button = UIStyle.button(toolbar, "» " + Sfx.pace_label(bot_pace, true), open_pace_popup)
 mute_button = UIStyle.button(toolbar, "♪ OFF" if Sfx.muted else "♪ ON", func():
  Sfx.muted = not Sfx.muted
  Sfx.save())
 mute_button.pressed.connect(sync_options)
 UIStyle.button(toolbar, "Log", toggle_log)
 menu_button = UIStyle.button(toolbar, "Menu", menu)
 body = VBoxContainer.new()
 body.size_flags_vertical = Control.SIZE_EXPAND_FILL
 left.add_child(body)
 log_ticker = UIStyle.button(left, "Network log", toggle_log)
 log_ticker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 log_open = bool(OnlineAPI.settings().get_value("ui", "log_open", not UIStyle.compact()))
 ghost_layer = CanvasLayer.new()
 ghost_layer.layer = 8
 add_child(ghost_layer)
 log_panel = UIStyle.panel("// NETWORK LOG")
 columns.add_child(log_panel)
 log_panel.visible = log_open
 log_ticker.visible = not log_open
 if UIStyle.compact():
  columns.remove_child(log_panel)
  add_child(log_panel)
  log_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
  log_panel.offset_left = -680
  log_panel.z_index = 20

 var side = VBoxContainer.new()
 log_panel.add_child(side)
 if UIStyle.compact(): UIStyle.button(side, "Close log", toggle_log)
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
  if not TouchInput.touch_mode: show_zoom({"id": str(id).uri_decode()}))
 log_view.meta_hover_ended.connect(func(_id): hide_zoom())
 log_view.meta_clicked.connect(func(id): show_log_card(str(id)))
 side.add_child(log_view)
 TouchInput.register_scroll(log_view)
 var cursor = UIStyle.label(side, "> _", 18)
 cursor.add_theme_color_override("font_color", UIStyle.CYAN)
 if Sfx.visual_effects:
  var blink = UIStyle.animation(cursor, true).set_loops()
  blink.tween_property(cursor, "modulate:a", 0.0, UIStyle.motion(0.6))
  blink.tween_property(cursor, "modulate:a", 1.0, UIStyle.motion(0.6))
 UIStyle.label(side, "Right-click or long-press to inspect", 14)
 if online_session != null:
  setup_online()
  return
 engine = GameEngine.new()
 add_child(engine)
 var choices: Array = [scripted_decider if scripted_decider != null else HumanDecider.new(self)]
 var levels: Array = [-1]
 for i in range(1, player_count): levels.append(difficulty)
 if not resume_data.is_empty(): card_pool = str(resume_data.game.state.get("card_pool", "2026"))
 CardDB.select_pool(card_pool)
 for id in CardDB.pool_ids(card_pool):
  card_names.append({"id": id, "name": str(CardDB.cards[id].name)})
 card_names.sort_custom(func(a, b): return a.name.length() > b.name.length())
 var game_seed: int = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
 pick_seat_names(game_seed)
 engine.log_message.connect(append_log)
 if resume_data.is_empty():
  engine.setup(levels, game_seed, choices, card_pool, starting_life, banned)
  if tutorial_mode: engine.state.active_seat = human_seat
 else:
  engine.state = SaveGame.restore(resume_data.game)
  starting_life = int(resume_data.table.get("starting_life", 0))
  player_count = engine.state.players.size()
  difficulty = engine.state.players[1].difficulty
  seat_names.assign(resume_data.table.seat_names)
  seat_heroes.assign(resume_data.table.seat_heroes)
  bot_pace = Sfx.saved_pace(resume_data.table)
  engine.deciders = choices
  for p in engine.state.players.slice(1): engine.deciders.append(BotDecider.new(engine, p.difficulty))
  log_entries = resume_data.table.get("log_entries", [resume_data.table.log]).slice(-400)
  for entry in log_entries: log_view.append_text(entry)
  if not log_entries.is_empty(): log_ticker.text = log_view.get_parsed_text().strip_edges().split("\n")[-1]
  for p in engine.state.players:
   previous_life[p.seat] = p.life
   previous_hack[p.seat] = p.hacking
  last_autosave_turn = engine.state.turn
  sync_options()
 lifetime_key = str(resume_data.get("table", {}).get("lifetime_key", "%s:%s" % [game_seed, Time.get_unix_time_from_system()]))
 match_stats.setup(player_count, card_pool, engine.state.players.map(func(p): return p.difficulty), not resume_data.is_empty())
 if not resume_data.is_empty() and resume_data.table.has("match_stats"):
  var restored_stats = match_stats.from_dict(resume_data.table.match_stats)
  if restored_stats != null: match_stats = restored_stats
 engine.card_played.connect(func(p, c): match_stats.played(p.seat, c.id))
 engine.purchase_paid.connect(func(p, c, cost): match_stats.bought(p.seat, c.id, cost))
 engine.life_gained.connect(func(p, amount): match_stats.gain(p.seat, amount))
 engine.damage_resolved.connect(func(p, q, amount, dealing): match_stats.damage(p.seat if dealing else -1, q.seat, amount))
 engine.state_changed.connect(redraw)

 engine.ice_counter_removed.connect(func(_card): Sfx.play("ice"))
 engine.damage_dealt.connect(damage)
 engine.damage_incoming.connect(func(source_player, target_player, _amount, source_card):
  if target_player.seat == human_seat:
   incoming_source = CardDB.cards[source_card.id].name + " / " + seat_name(source_player.seat) if source_card != null else seat_name(source_player.seat))
 engine.card_moved.connect(moved)
 engine.turn_started.connect(func(p):
  match_stats.turn(p.seat)
  opening_rickroll = null
  for card in engine.state.center_row:
   if card != null and card.id == "Rickroll": opening_rickroll = card
  Sfx.play("your_turn" if p.seat == human_seat else "turn_start")
  if p.seat == human_seat: begin_recap()
  append_log("TURN %d · Seat %d connected" % [engine.state.turn, p.seat])
  turn_band(p)
  redraw())
 engine.turn_ended.connect(func(p):
  if p.seat == human_seat: end_recap_turn())
 engine.game_over.connect(game_over)
 if resume_data.is_empty(): append_log("Network ready · %d players connected" % player_count)
 engine.turn_driver = drive_reaction
 if resume_data.is_empty():
  var first = seat_name(engine.active().seat)
  show_notice(first + (" go first" if first == "You" else " goes first"), 6.0)
  await engine.start_turn()
 auto_save()
 redraw()
 if tutorial_mode:
  tutorial_coach = load("res://scripts/ui/tutorial.gd").new()
  add_child(tutorial_coach)
  tutorial_coach.begin(self)
func pick_seat_names(game_seed: int):
 var heroes: Array[String] = []
 var hero_ids: Dictionary = {}
 for id in CardDB.pool_ids(card_pool):
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
 return seat_names[seat] if seat < seat_names.size() else ("You" if seat == human_seat else "Bot %d" % seat)
## A seat's avatar card: a card named after the seat's handle, else the seat's Hero.
func avatar_hero(seat: int) -> String:
 var match = CardDB.card_id_for_name(seat_name(seat))
 return match if not match.is_empty() else seat_heroes[seat]
func player_name(p) -> String:
 if online_session != null: return seat_name(p.seat)
 return seat_name(human_seat) if p.seat == human_seat else "%s · %s" % [seat_name(p.seat), BotDifficulty.DISPLAY_NAMES[p.difficulty]]
func available() -> bool:
 if online_session != null: return not online_over and online_session.client.can_act and not pending and online_session.client.prompts.is_empty() and engine.state != null
 return engine != null and engine.is_turn(engine.state.players[human_seat]) and not engine.busy and not pending and (not acting or engine.reaction_depth > 0)
var synchronous_redraw = DisplayServer.get_name() == "headless"
var redraw_dirty = false
var rebuild_count = 0
var rebuilding = false
var widget_cache: Dictionary = {}
var shown_widgets: Dictionary = {}
var zone_anchors: Dictionary = {}
var last_locations: Dictionary = {}
var ghost_layer: CanvasLayer
var ghosts: Array = []
var state_revision = 0
var action_cache_key: Array = []
var cached_save = false
var cached_nothing = false
func redraw():
 state_revision += 1
 auto_end_elapsed = 0
 auto_end_turn_number = -1
 if synchronous_redraw: redraw_now(); return
 if redraw_dirty: return
 redraw_dirty = true
 if not get_tree().process_frame.is_connected(_flush_redraw): get_tree().process_frame.connect(_flush_redraw, CONNECT_ONE_SHOT)
func _flush_redraw():
 if redraw_dirty: redraw_now()
func locations() -> Dictionary:
 var result = {}
 for p in engine.state.players:
  for zone in ["deck", "hand", "discard", "play_area", "reserve"]:
   for c in p.get(zone): result[c.uid] = {"zone": "%d:%s" % [p.seat, zone], "hidden": zone == "deck" or (zone == "hand" and p.seat != human_seat), "id": c.id}
 for c in engine.state.resolving: result[c.uid] = {"zone": "%d:resolving" % c.controller, "hidden": false, "id": c.id}
 for zone in ["center_deck", "center_row", "removed"]:
  for c in engine.state.get(zone):
   if c != null: result[c.uid] = {"zone": zone, "hidden": zone == "center_deck", "id": c.id}
 return result
func anchor(key: String, node: Control):
 zone_anchors[key] = node
func card_rects() -> Dictionary:
 var result = {}
 for uid in shown_widgets:
  var widget = shown_widgets[uid]
  if is_instance_valid(widget) and widget.is_inside_tree(): result[uid] = widget.get_child(0).get_global_rect()
 return result
func anchor_rects() -> Dictionary:
 var result = {}
 for key in zone_anchors:
  if is_instance_valid(zone_anchors[key]): result[key] = zone_anchors[key].get_global_rect()
 return result
func toggle_log():
 log_open = not log_open
 log_panel.visible = log_open
 log_ticker.visible = not log_open
 var config = OnlineAPI.settings()
 config.set_value("ui", "log_open", log_open)
 config.save("user://settings.cfg")
 redraw()
func redraw_now():
 UIStyle.touch_fit(self)
 clear_hand_selection()
 state_revision += 1
 redraw_dirty = false
 auto_end_elapsed = 0
 auto_end_turn_number = -1
 if not is_instance_valid(body) or engine.state == null: return
 if opening_rickroll != null and not engine.busy:
  show_notice("Rickroll was in the Center Row when your turn started, so you had to buy it" if opening_rickroll not in engine.state.center_row else "Rickroll forced buy was blocked", 7.0)
  opening_rickroll = null
 rebuild_count += 1
 hover_serial += 1
 hide_zoom()
 var old_rects = card_rects()
 var old_anchors = anchor_rects()
 var old_locations = last_locations
 var next_locations = locations()
 var moves = moved_uids.duplicate(true)
 moved_uids.clear()
 for uid in next_locations:
  if old_locations.has(uid) and old_locations[uid].zone != next_locations[uid].zone: moves[uid] = true
 for uid in widget_cache:
  var widget = widget_cache[uid]
  if is_instance_valid(widget) and widget.get_parent() != null: widget.get_parent().remove_child(widget)
 shown_widgets.clear()
 zone_anchors.clear()
 rebuilding = true
 for child in body.get_children():
  body.remove_child(child)
  child.queue_free()
 life_labels.clear()
 banner.text = "Your turn" if engine.active().seat == human_seat else player_name(engine.active()) + " is hacking…"
 banner.text += "  /  TURN %02d" % engine.state.turn
 banner.add_theme_color_override("font_color", UIStyle.GREEN if engine.active().seat == human_seat else UIStyle.AMBER)
 var avatar_source = UIStyle.avatar(avatar_hero(engine.active().seat))
 turn_avatar.get_child(0).texture = avatar_source.get_child(0).texture
 avatar_source.free()
 var width = get_viewport_rect().size.x - (382 if log_open and not UIStyle.compact() else 64) - safe_extra.x - safe_extra.y
 var compact = UIStyle.compact()
 var human = engine.state.players[human_seat]
 var empty_rig = human.play_area.is_empty() and human.reserve.is_empty()
 var height = get_viewport_rect().size.y - (184 if compact or not log_open else 100)
 var remote_h = 110.0 if compact else 220.0
 var rule_h = 88.0 if compact else 56.0
 var center_y = remote_h + 20
 var rig_h = 60.0 if empty_rig else (92.0 if compact else 194.0)
 var hand_h = clampf(height * 0.27, 240, 340)
 if not compact and not empty_rig and engine.permanents().any(func(c): return not CardDB.get_card(c.effect_id()).get("table_rule", "").is_empty()): hand_h = maxf(214, hand_h - 56)
 var hand_y = height - hand_h
 var rig_y = hand_y - (212 if compact and not empty_rig else (180 if empty_rig else 214))
 var market_h = rig_y - center_y - 20
 var canvas = Control.new()
 canvas.custom_minimum_size.y = height
 body.add_child(canvas)
 var opponents = HBoxContainer.new()
 region(canvas, opponents, Vector2(0, 0), Vector2(width, remote_h), "// REMOTE HOSTS")
 for p in engine.state.players:
  if p.seat != human_seat: seat_area(opponents, p, false)
 var active_rules = engine.permanents().filter(func(c): return not CardDB.get_card(c.effect_id()).get("table_rule", "").is_empty())
 var next_uids = active_rules.map(func(c): return c.uid)
 var entered = active_rules.filter(func(c): return c.uid not in table_rule_uids)
 table_rule_uids = next_uids
 if not entered.is_empty():
  show_notice(" · ".join(entered.map(func(c): return CardDB.get_card(c.effect_id()).name + " is in play: " + CardDB.get_card(c.effect_id()).table_rule)), 7.0)
 if not active_rules.is_empty():
  var strip = HBoxContainer.new()
  strip.name = "InEffect"
  canvas.add_child(strip)
  strip.position = Vector2(0, remote_h)
  strip.size = Vector2(width, rule_h)
  UIStyle.label(strip, "⚠ IN EFFECT", 14).add_theme_color_override("font_color", UIStyle.AMBER)
  var rule_scroll = ScrollContainer.new()
  rule_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  rule_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  strip.add_child(rule_scroll)
  TouchInput.register_scroll(rule_scroll)
  var chips = HBoxContainer.new()
  rule_scroll.add_child(chips)
  for c in active_rules:
   var data = CardDB.get_card(c.effect_id())
   var chip = UIStyle.button(chips, data.name + " · " + seat_name(c.controller) + "\n" + data.table_rule, func(): inspect_card(c, true))
   chip.set_meta("table_rule_uid", c.uid)
   chip.add_theme_font_size_override("font_size", 13)
   chip.add_theme_color_override("font_color", UIStyle.AMBER)
 # Reserve room for the strip and its scrollbar without overlapping the rig below.
 if not active_rules.is_empty(): center_y += rule_h; market_h -= rule_h
 # Height is the real limit: the cards fill the row, less the frame and the cost readout below each card.
 var market_width = int(clampf(minf((width - 320) / 6.0, (market_h - 70) / 1.367), 110, 240))
 var center = HBoxContainer.new()
 center.add_theme_constant_override("separation", 18)
 region(canvas, center, Vector2(0, center_y), Vector2(width, market_h), "// CENTER ROW")
 anchor("center", center)
 for c in engine.state.center_row:
  if c != null: center.add_child(card_widget(c, "market", market_width))
  else:
   var slot = UIStyle.panel()
   slot.custom_minimum_size = Vector2(market_width, market_width * 1.367)
   slot.add_theme_stylebox_override("panel", UIStyle.box(Color(0.02,0.04,0.05,0.4), Color(UIStyle.CYAN,0.2), 0))
   center.add_child(slot)
 var piles = VBoxContainer.new()
 center.add_child(piles)
 var deck_label = UIStyle.label(piles, "Deck: %d" % engine.state.center_deck.size(), 16)
 anchor("center_deck", deck_label)
 deck_label.custom_minimum_size.x = 180
 if not compact: UIStyle.label(piles, UIStyle.pool_label(engine.state.card_pool), 14)
 var banned_button = UIStyle.button(piles, "Banned: %d" % engine.state.banned.size(), func():
  if is_instance_valid(ban_picker): return
  ban_picker = load("res://scripts/ui/ban_picker.gd").new()
  add_child(ban_picker)
  ban_picker.open_bans(engine.state.card_pool, engine.state.banned, Callable(), true)
  ban_picker.overlays[0].tree_exited.connect(ban_picker.queue_free))
 banned_button.icon = load(UIStyle.BACK)
 banned_button.expand_icon = true
 banned_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
 banned_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
 banned_button.add_theme_constant_override("icon_max_width", 32)
 banned_button.custom_minimum_size = Vector2(110, 72)
 anchor("removed", UIStyle.button(piles, "Removed: %d" % engine.state.removed.size(), func(): view_cards("Removed from game", engine.state.removed)))
 var p = engine.state.players[human_seat]
 var board_scroll = ScrollContainer.new()
 TouchInput.register_scroll(board_scroll)
 region(canvas, board_scroll, Vector2(0, rig_y), Vector2(width if compact else width - 820, rig_h), "// YOUR RIG & RESERVED")
 board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 var board = HBoxContainer.new()
 board_scroll.add_child(board)
 anchor("%d:play_area" % human_seat, board_scroll)
 anchor("%d:resolving" % human_seat, board_scroll)
 if compact and not empty_rig:
  UIStyle.button(board, "Rig: %d · Reserved: %d · Open board" % [p.play_area.size(), p.reserve.size()], func(): view_cards("Your rig & reserved", p.play_area + p.reserve))
 else:
  for c in p.play_area: board.add_child(card_widget(c, "permanent", 100))
  for c in p.reserve: board.add_child(card_widget(c, "reserve", 100))
 anchor("%d:reserve" % human_seat, board_scroll)
 if p.play_area.is_empty() and p.reserve.is_empty():
  board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var placeholder = UIStyle.label(board, "Build your network here.", 18)
  placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  placeholder.add_theme_color_override("font_color", UIStyle.MUTED)
 var status = HBoxContainer.new() if compact or empty_rig else VBoxContainer.new()
 region(canvas, status, Vector2(0, rig_y + (102 if compact and not empty_rig else 70)) if compact or empty_rig else Vector2(width - 780, rig_y), Vector2(width, 100) if compact or empty_rig else Vector2(780, 194), "// " + seat_name(human_seat).to_upper() + " / SYSTEM STATUS")
 var stats = HBoxContainer.new()
 status.add_child(stats)
 stats.add_child(UIStyle.avatar(avatar_hero(human_seat), 56))
 life_labels[human_seat] = readout(stats, "life", p.life, 40)
 anchor("hack", readout(stats, "hack", p.hacking, 40))
 anchor("life", life_labels[human_seat])
 var piles_button = UIStyle.button(status, "Deck %d   /   Discard %d" % [p.deck.size(), p.discard.size()], func(): view_cards("Your discard", p.discard))
 piles_button.name = "PlayerPiles"
 anchor("%d:deck" % human_seat, piles_button)
 anchor("%d:discard" % human_seat, piles_button)
 var hand_scroll = ScrollContainer.new()
 hand_scroll.name = "HandViewport"
 hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 region(canvas, hand_scroll, Vector2(0, hand_y), Vector2(width, hand_h), "// YOUR HAND · %d" % p.hand.size())
 TouchInput.register_scroll(hand_scroll)
 anchor("%d:hand" % human_seat, hand_scroll)
 var hand = Control.new()
 hand.name = "Hand"
 hand_scroll.add_child(hand)
 var hand_width = int(clampf(minf((width - 40) / 8.0, (hand_h - 44) / 1.367), 150 if compact else 140, 260))
 var step = maxf(72, minf(hand_width + 12, (width - hand_width - 24) / maxf(1, p.hand.size() - 1)))
 hand.custom_minimum_size = Vector2(maxf(width - 20, (p.hand.size() - 1) * step + hand_width), hand_h - 36)
 for i in p.hand.size():
  var card = card_widget(p.hand[i], "hand", hand_width)
  hand.add_child(card)
  card.position.x = i * step
 var actions = HBoxContainer.new()
 status.add_child(actions)
 actions.add_theme_constant_override("separation", 16)
 play_button = UIStyle.button(actions, "▶ Play All", play_all)
 var basics = UIStyle.button(actions, "Play Basics", play_basics)
 basics.disabled = not available()
 end_button = UIStyle.button(actions, "End Turn →", end_human_turn)
 anchor("end", end_button)
 anchor("banner", banner)
 anchor("log", log_panel if log_open else log_ticker)
 anchor("rules", menu_button)
 play_button.custom_minimum_size.y = 72 if compact else 38
 end_button.custom_minimum_size.y = 72 if compact else 38
 play_button.disabled = not available()
 end_button.disabled = not available()
 UIStyle.primary(end_button)
 if available() and p.hand.filter(func(c): return engine.can_play(p, c)).is_empty(): UIStyle.pulse(end_button)
 rebuilding = false
 if online_session != null and not old_locations.is_empty():
  # Masked hand UIDs are deliberately unstable online. Animate count increases
  # with backs; never correlate masks with newly revealed public identities.
  for player in engine.state.players:
   if player.seat == human_seat: continue
   var hand_zone = "%d:hand" % player.seat
   var old_count = old_locations.values().filter(func(entry): return entry.zone == hand_zone).size()
   var draws = player.hand.size() - old_count
   for c in player.hand.slice(0, maxi(0, draws)):
    moves[c.uid] = {"from": {"zone": "%d:deck" % player.seat, "hidden": true}, "to": next_locations[c.uid]}
 if not old_locations.is_empty():
  for uid in shown_widgets:
   if not old_locations.has(uid): moves[uid] = moves.get(uid, true)
 for uid in widget_cache.keys():
  if not shown_widgets.has(uid):
   if is_instance_valid(widget_cache[uid]): widget_cache[uid].queue_free()
   widget_cache.erase(uid)
 last_locations = next_locations
 if not moves.is_empty(): animate_moves(moves, old_rects, old_anchors, old_locations, next_locations)
 track_life()
 if online_session == null and auto_drive and engine.active().is_bot and not driving and not engine.busy and not engine.state.finished: drive_bot.call_deferred()
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
 if UIStyle.compact():
  var summary = UIStyle.button(parent, "%s · ♥ %d\nHand %d · Deck %d · Discard %d" % [seat_name(p.seat), p.life, p.hand.size(), p.deck.size(), p.discard.size()], func(): view_cards(seat_name(p.seat) + " · Board", p.play_area + p.reserve + p.discard))
  var avatar = UIStyle.avatar(avatar_hero(p.seat))
  summary.icon = avatar.get_child(0).texture
  avatar.free()
  summary.expand_icon = true
  summary.add_theme_constant_override("icon_max_width", 64)
  summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  summary.alignment = HORIZONTAL_ALIGNMENT_LEFT
  var mini_board = HBoxContainer.new()
  mini_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
  summary.add_child(mini_board)
  mini_board.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
  mini_board.offset_left = -84
  mini_board.offset_top = -48
  mini_board.offset_right = -8
  mini_board.offset_bottom = -4
  for card in p.play_area.slice(0, 2):
   var miniature = UIStyle.picture(CardDB.image_path(card.id), Vector2(32, 44))
   miniature.mouse_filter = Control.MOUSE_FILTER_IGNORE
   mini_board.add_child(miniature)
  for zone in ["deck", "hand", "discard", "play_area", "reserve"]: anchor("%d:%s" % [p.seat, zone], summary)
  return
 var panel = UIStyle.panel()
 panel.name = "Opponent%d" % p.seat
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var inset = UIStyle.box()
 inset.set_content_margin_all(0)
 panel.add_theme_stylebox_override("panel", inset)
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 var status = HBoxContainer.new()
 box.add_child(status)
 status.add_child(UIStyle.avatar(avatar_hero(p.seat), 40))
 var name_label = UIStyle.label(status, seat_name(p.seat), 20)
 name_label.custom_minimum_size.x = 80
 name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 name_label.clip_text = true
 var human_remote = online_session != null and not online_session.client.seats[p.seat].get("bot", false)
 var badge = UIStyle.label(status, "HUMAN" if human_remote else BotDifficulty.DISPLAY_NAMES[p.difficulty].to_upper(), 14)
 badge.visible = player_count == 2
 if not p.alive:
  panel.modulate = Color(0.5, 0.5, 0.5)
  name_label.text = "DISCONNECTED · " + seat_name(p.seat)
 badge.add_theme_color_override("font_color", UIStyle.CYAN if human_remote else [UIStyle.GREEN, UIStyle.AMBER, UIStyle.RED][p.difficulty])
 life_labels[p.seat] = readout(status, "life", p.life, 28)
 var life_frame = life_labels[p.seat].get_parent().get_parent()
 var compact = life_frame.get_theme_stylebox("panel").duplicate()
 compact.content_margin_top = 2
 compact.content_margin_bottom = 2
 life_frame.add_theme_stylebox_override("panel", compact)
 anchor("%d:deck" % p.seat, UIStyle.label(box, "Hand %d · Deck %d · Discard %d" % [p.hand.size(), p.deck.size(), p.discard.size()], 16))
 var row = HBoxContainer.new()
 box.add_child(row)
 var fan = Control.new()
 fan.custom_minimum_size = Vector2(100, 100)
 row.add_child(fan)
 anchor("%d:hand" % p.seat, fan)
 for i in mini(p.hand.size(), 5):
  var back = UIStyle.picture(UIStyle.BACK, Vector2(55, 75))
  fan.add_child(back)
  back.position = Vector2(i * 8, 25 + abs(i - 2) * 3)
  back.rotation = (i - 2) * 0.07
 # Discard pile is public: show its top card face up and let the human browse it.
 var pile = VBoxContainer.new()
 row.add_child(pile)
 anchor("%d:discard" % p.seat, pile)
 if p.discard.is_empty():
  var empty = UIStyle.label(pile, "Discard\nempty", 14)
  empty.custom_minimum_size = Vector2(60, 75)
 else:
  pile.add_child(card_widget(p.discard.back(), "opponent", 55))
 var opponent_name = seat_name(p.seat)
 UIStyle.button(pile, "Discard", func(): view_cards("%s's discard pile" % opponent_name, p.discard))
 var scroll = ScrollContainer.new()
 TouchInput.register_scroll(scroll)
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size.y = 110
 scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 row.add_child(scroll)
 var board = HBoxContainer.new()
 scroll.add_child(board)
 anchor("%d:play_area" % p.seat, scroll)
 anchor("%d:resolving" % p.seat, scroll)
 for c in p.play_area: board.add_child(card_widget(c, "opponent", 70))
 for c in p.reserve: board.add_child(card_widget(c, "opponent_reserve", 70))
func texture_for(id: String) -> Texture2D:
 if not textures.has(id): textures[id] = load(CardDB.image_path(id))
 return textures[id]
func card_widget(c, zone: String, width: int) -> Control:
 var human = engine.state.players[human_seat]
 var legal = engine.can_play(human, c) if zone == "hand" else engine.can_buy(human, c)
 var abilities_key = engine.activatable_abilities(human, c) if zone == "permanent" else []
 var key = [c, c.id, c.effect_id(), zone, width, legal, c.counters, str(abilities_key), engine.effective_cost(human, c), available() if zone == "permanent" else true]
 if rebuilding and widget_cache.has(c.uid):
  var previous = widget_cache[c.uid]
  if is_instance_valid(previous) and previous.get_meta("visual_key") == key:
   previous.z_index = 0
   previous.position = Vector2.ZERO
   previous.modulate.a = 0.0 if previous.has_meta("flight") else 1.0
   previous.get_child(0).position = Vector2.ZERO
   previous.get_child(0).add_theme_stylebox_override("normal", previous.get_meta("card_style"))
   shown_widgets[c.uid] = previous
   return previous
  if is_instance_valid(previous): previous.queue_free()
 var box = VBoxContainer.new()
 box.set_meta("card_uid", c.uid)
 box.set_meta("zone", zone)
 var button = Button.new()
 button.custom_minimum_size = Vector2(width, width * 1.367)
 button.tooltip_text = engine.db().get_card(c.id).name + "\nRight-click or long-press to inspect"
 box.add_child(button)
 var picture = TextureRect.new()
 picture.texture = texture_for(c.id)
 picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
 button.add_child(picture)
 picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if legal and zone in ["hand", "market", "reserve"]:
  var badge = UIStyle.label(button, "▶" if zone == "hand" else "+", 20)
  badge.name = "LegalBadge"
  badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
  badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
  badge.offset_left = 4
  badge.offset_top = -28
  badge.offset_right = 28
  badge.offset_bottom = -4
  badge.add_theme_color_override("font_color", Color.WHITE)
  badge.add_theme_constant_override("outline_size", 5)
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
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: inspect_card(c))
 button.mouse_entered.connect(func():
  if TouchInput.touch_mode: return
  hover_serial += 1
  var serial = hover_serial
  if zone == "hand" and Sfx.visual_effects:
   box.z_index = 5
   button.position.y = -30
  button.add_theme_stylebox_override("normal", hover_border())
  delayed_zoom(weakref(button), c, serial))
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
  if UIStyle.compact():
   button.add_child(cost)
   cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
   cost.position = Vector2(6, width * 1.367 - 50)
  else: box.add_child(cost)
  readout(cost, "hack", engine.effective_cost(human, c), 16)
 if rebuilding:
  box.set_meta("visual_key", key)
  box.set_meta("card_style", card_style)
  widget_cache[c.uid] = box
  shown_widgets[c.uid] = box
 return box
func reveal_staged_cards(staged: Array):
 for reference in staged:
  var widget = reference.get_ref()
  if widget != null and not widget.has_meta("flight"): widget.modulate.a = 1
func animate_moves(moves, old_rects, old_anchors, old_locations, next_locations):
 if bot_pace == 0 or not Sfx.visual_effects: return
 var generation = rebuild_count
 var staged: Array = []
 for uid in moves:
  if staged.size() >= maxi(0, 12 - ghosts.size()): break
  var widget = shown_widgets.get(uid)
  if is_instance_valid(widget):
   staged.append(weakref(widget))
   widget.modulate.a = 0
 await get_tree().process_frame
 if not is_inside_tree() or generation != rebuild_count or bot_pace == 0 or not Sfx.visual_effects:
  reveal_staged_cards(staged)
  return
 var new_rects = card_rects()
 var new_anchors = anchor_rects()
 if not is_instance_valid(ghost_layer):
  ghost_layer = CanvasLayer.new()
  ghost_layer.layer = 8
  add_child(ghost_layer)
 var index = 0
 for uid in moves:
  if ghosts.size() >= 12: break
  var after = next_locations.get(uid, {})
  var before = old_locations.get(uid, {})
  var event = moves[uid]
  if before.is_empty() and event is Dictionary: before = event.from
  if after.is_empty() and event is Dictionary: after = event.to
  if after.is_empty(): continue
  if before.is_empty():
   before = {"zone": "center_deck" if after.zone == "center_row" else ("%d:hand" % int(after.zone.get_slice(":", 0)) if after.zone.ends_with(":play_area") or after.zone.ends_with(":discard") else "%d:deck" % human_seat), "hidden": true}
  var start = old_rects.get(uid, old_anchors.get(before.zone, Rect2()))
  var end = new_rects.get(uid, new_anchors.get(after.zone, Rect2()))
  if start.size == Vector2.ZERO or end.size == Vector2.ZERO: continue
  var ghost = TextureRect.new()
  ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
  ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  ghost.texture = load(UIStyle.BACK) if before.get("hidden", false) or after.get("hidden", false) else texture_for(after.get("id", before.get("id", "")))
  ghost.set_meta("uid", uid)
  ghost.set_meta("start_rect", start)
  ghost.set_meta("end_rect", end)
  ghost_layer.add_child(ghost)
  ghost.position = start.position
  ghost.size = start.size
  ghosts.append(ghost)
  var real = shown_widgets.get(uid)
  var real_ref = weakref(real) if is_instance_valid(real) else null
  if is_instance_valid(real):
   real.modulate.a = 0
   real.set_meta("flight", ghost.get_instance_id())
  var tween = UIStyle.animation(ghost)
  tween.tween_interval(UIStyle.motion(index * 0.035))
  tween.chain().tween_property(ghost, "position", end.position, UIStyle.motion(0.28)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tween.parallel().tween_property(ghost, "size", end.size, UIStyle.motion(0.28))
  if not new_rects.has(uid): tween.parallel().tween_property(ghost, "modulate:a", 0.0, UIStyle.motion(0.28))
  tween.chain().tween_callback(func():
   if real_ref != null and real_ref.get_ref() != null:
    var target = real_ref.get_ref()
    if target.get_meta("flight", 0) == ghost.get_instance_id():
     target.modulate.a = 1
     target.remove_meta("flight")
   ghosts.erase(ghost)
   ghost.queue_free())
  index += 1
 reveal_staged_cards(staged)
func delayed_zoom(button_ref: WeakRef, c, serial: int):
 await get_tree().create_timer(0.4).timeout
 if button_ref.get_ref() != null and serial == hover_serial and not pending and not TouchInput.touch_mode: show_zoom(c)
func card_clicked(c, zone: String):
 var player = engine.state.players[human_seat]
 var blocked = engine.why_not_play(player, c) if zone == "hand" else (engine.why_not_buy(player, c) if zone in ["market", "reserve"] else "")
 if not blocked.is_empty(): show_notice(blocked)
 if zone in ["market", "reserve", "permanent", "opponent"]:
  inspect_card(c, true)
  return
 if zone == "hand" and UIStyle.compact() and selected_hand != c:
  select_hand(c)
  return
 var reason = engine.why_not_play(engine.state.players[human_seat], c) if zone == "hand" else ""
 if not reason.is_empty(): show_notice(reason); return
 if not available(): return
 hide_zoom()
 if zone == "hand":
  if online_session != null: online_action("play", c.uid); return
  acting = true
  redraw()
  await engine.play_card(engine.state.players[human_seat], c)
  acting = false

 redraw()
func clear_hand_selection():
 if is_instance_valid(hand_selection): hand_selection.queue_free()
 hand_selection = null
 if selected_hand != null and shown_widgets.has(selected_hand.uid): shown_widgets[selected_hand.uid].position.y = 0
 selected_hand = null
func select_hand(c):
 clear_hand_selection()
 selected_hand = c
 if shown_widgets.has(c.uid):
  shown_widgets[c.uid].position.y = -16
  shown_widgets[c.uid].z_index = 6
 var panel = UIStyle.panel()
 hand_selection = panel
 panel.z_index = 30
 add_child(panel)
 panel.position = Vector2(get_viewport_rect().size.x - 520, get_viewport_rect().size.y - 300)
 panel.custom_minimum_size.x = 480
 var box = VBoxContainer.new()
 panel.add_child(box)
 UIStyle.label(box, CardDB.get_card(c.id).name, 22)
 var row = HBoxContainer.new()
 box.add_child(row)
 var play = UIStyle.button(row, "Play", func():
  if is_instance_valid(hand_selection): hand_selection.queue_free()
  hand_selection = null
  card_clicked(c, "hand"))
 play.disabled = not engine.can_play(engine.state.players[human_seat], c)
 UIStyle.primary(play)
 UIStyle.button(row, "Inspect", func(): clear_hand_selection(); inspect_card(c, true))
 UIStyle.button(row, "Close", clear_hand_selection)
func activate_card(c, index: int):
 if not available(): return
 if online_session != null: online_action("activate", c.uid, index); return
 acting = true
 redraw()
 await engine.activate(engine.state.players[human_seat], c, index)
 acting = false
 redraw()
func play_basics():
 await play_all(true)
func play_all(basics: bool = false):
 if not available(): return
 if online_session != null: online_action("play_basics" if basics else "play_all"); return
 acting = true
 redraw()
 var p = engine.state.players[human_seat]
 await engine.play_all(p, basics)
 acting = false
 redraw()
func end_human_turn(automatic: bool = false):
 if not available(): return
 if not automatic and Sfx.confirm_end_turn and not nothing_left():
  var p = engine.state.players[human_seat]
  var n = p.hand.filter(func(c): return engine.can_play(p, c)).size()
  if await decision("End your turn? You still have %d Hacking and %d playable cards." % [p.hacking, n], ["End turn", "Keep playing"], [], 1, 1, false) != 0: return
 if online_session != null:
  if available(): online_action("end_turn")
  return
 acting = true
 redraw()
 await engine.end_turn(engine.state.players[human_seat])
 acting = false
 redraw()
func drive_reaction(p):
 var driver = BotPlayer.new(engine)
 driver.pace_provider = func():
  last_bot_action_delay = bot_pace
  return bot_pace
 # Only used for zero delay, including a change to Instant during this turn.
 driver.yield_frame = true
 await driver.take_turn(p)
func drive_bot():
 if driving or engine.busy or engine.state.finished or engine.reaction_depth > 0: return
 driving = true
 while engine.active().is_bot and not engine.state.finished:
  await drive_reaction(engine.active())
 driving = false
 redraw()
func decision(prompt: String, options: Array, cards: Array, min_n: int, max_n: int, multi: bool, searchable: bool = false):
 dismiss_recap()
 hide_zoom()
 hover_serial += 1
 pending = true
 back_answer = null
 if multi and max_n == 0: back_answer = []
 elif not multi:
  for label in ["Cancel", "Close", "Keep playing", "Stay"]:
   if label in options:
    back_answer = options.find(label)
    break
 redraw()
 var overlay = UIStyle.panel()
 overlay.add_to_group("touch_modal")
 # Above bot card spotlights (z 15) so a prompt during a bot turn is never hidden.
 # After the game the summary sits at 50; a dialog opened from it (View final deck) must draw above it.
 overlay.z_index = 60 if online_over or (engine != null and engine.state != null and engine.state.finished) else 20
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 var prompt_label = UIStyle.rich_label(box, escaped(prompt), 26)
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
 # Give the wrapping prompt its real width up front; at width 0 it wraps per character and asks for a huge height.
 prompt_label.custom_minimum_size.x = mini(int(dimensions.x), int(get_viewport_rect().size.x) - 120)
 # Option buttons claim their height, so a two-line prompt grows the box instead of squeezing the buttons into a scroll.
 if cards.is_empty(): scroll.custom_minimum_size.y = mini(rows * 60, 480)
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
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: inspect_card(cards[i]))
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
   if max_n == 0 and not cards.is_empty(): inspect_card(cards[i]); return
   if i in selected: selected.erase(i)
   elif selected.size() < max_n: selected.append(i)
   else: b.button_pressed = false
   counter.text = "Selected %d / %d–%d" % [selected.size(), min_n, max_n]
   done.disabled = selected.size() < min_n or selected.size() > max_n)
 search.text_changed.connect(func(value):
  for i in buttons.size(): buttons[i].visible = value.to_lower() in str(options[i]).to_lower())
 done.pressed.connect(func(): answered.emit(selected.duplicate()))
 var result = await answered
 back_answer = null
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
 zoom.add_child(UIStyle.picture(CardDB.image_path(c.id), Vector2(450, 615)))
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
  if player.seat == human_seat and player.hacking != int(previous_hack.get(player.seat, player.hacking)):
   var status = body.find_child("HackGauge", true, false)
   if status != null: flash_readout(status)
  previous_hack[player.seat] = player.hacking
 for p in engine.state.players:
  var before = previous_life.get(p.seat, p.life)
  if before != p.life:
   Sfx.play("damage" if p.life < before else "life_gain")
   float_life.call_deferred(p.seat, p.life - before)
   if life_labels.has(p.seat):
    flash_readout(life_labels[p.seat])
    if p.life < before and Sfx.visual_effects: shake_life.call_deferred(p.seat)
  previous_life[p.seat] = p.life
func shake_life(seat: int):
 await get_tree().process_frame
 if not life_labels.has(seat): return
 var label = life_labels[seat]
 var origin = label.position
 var tween = UIStyle.animation(label)
 for offset in [5, -5, 3, -3, 0]: tween.tween_property(label, "position", origin + Vector2(0, offset), UIStyle.motion(0.03))
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
 if not Sfx.visual_effects:
  get_tree().create_timer(0.9).timeout.connect(floating.queue_free)
  return
 var tween = UIStyle.animation(floating).set_parallel(true)
 tween.tween_property(floating, "position:y", floating.position.y - 65, UIStyle.motion(0.9))
 tween.tween_property(floating, "modulate:a", 0.0, UIStyle.motion(0.9))
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
 if "eliminat" in message.to_lower() and online_session == null:
  Sfx.play("eliminated")
  show_notice(display, 7.0)
 for verbs in [["plays", "play"], ["buys", "buy"], ["takes", "take"], ["reserves", "reserve"], ["reveals", "reveal"], ["goes", "go"], ["loses", "lose"], ["gains", "gain"], ["discards", "discard"], ["draws", "draw"]]:
  if seat_name(human_seat) == "You" and message.begins_with("Seat %d " % human_seat + verbs[0] + " "):
   display = "You " + verbs[1] + " " + display.substr(("You " + verbs[0] + " ").length())
 var entry = "[color=#%s]%s[/color]\n" % [colors[seat] if seat >= 0 else "a1b1bb", "[color=#536c78]> [/color]" + link_cards(display)]
 log_ticker.text = display.replace("\n", " ")
 log_entries.append(entry)
 if log_entries.size() > 400:
  log_entries.pop_front()
  log_view.clear()
  for retained in log_entries: log_view.append_text(retained)
 else: log_view.append_text(entry)
 for action in ["plays", "buys", "reserves"]:
  if " " + action + " " not in message: continue
  if online_session == null: Sfx.play({"plays": "card_play", "buys": "buy", "reserves": "reserve"}[action])
  if online_session == null and seat != human_seat and seat >= 0:
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
 inspect_card({"id": id})
## Fades the non-interactive opponent row and recap chip together.
func clear_spotlights(delay: float):
 spotlight_serial += 1
 var fading = spotlights.duplicate()
 if is_instance_valid(recap_chip): fading.append(recap_chip)
 recap_chip = null
 for panel in fading:
  if not is_instance_valid(panel): continue
  spotlights.erase(panel)
  if not Sfx.visual_effects:
   panel.queue_free()
   continue
  var tween = UIStyle.animation(panel)
  tween.tween_interval(delay)
  tween.tween_property(panel, "modulate:a", 0.0, UIStyle.motion(0.2))
  tween.tween_callback(func():
   if is_instance_valid(panel): panel.queue_free())
const SPOTLIGHT_LARGE = Vector2(330, 450)
const SPOTLIGHT_SMALL = Vector2(120, 164)
const SPOTLIGHT_THUMBS = 9
var spotlight_serial = 0
## Shows what opponents play as one row over the center row: the newest card large with its caption,
## earlier cards of the same stretch as thumbnails to its right (newest first). Nothing is queued or
## dropped, so a long bot turn stays readable without opening the log.
var recap_history: Array = []
var recap_count = 0
var recap_active = false
var recap_names: Array[String] = []
var recap_chip: Label
var recap_elapsed = 0.0
func dismiss_recap():
 if not recap_active: return
 recap_active = false
 clear_spotlights(0)
func end_recap_turn():
 dismiss_recap()
 clear_spotlights(0)
 recap_count = 0
 recap_names.clear()
 recap_history.clear()
func begin_recap():
 if recap_count == 0: return
 # Rebuild even if the opponent inactivity timeout already hid the live row.
 for panel in spotlights: panel.queue_free()
 spotlights.clear()
 for entry in recap_history:
  spotlights.append(make_spotlight_panel(entry.id, entry.caption))
 spotlight_serial += 1
 recap_active = true
 recap_elapsed = 0
 if is_instance_valid(recap_chip): recap_chip.queue_free()
 recap_chip = UIStyle.label(self, (recap_names[0] + "'s turn" if recap_names.size() == 1 else "Since your turn") + ": %d cards · tap to dismiss" % recap_count, 16)
 recap_chip.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, UIStyle.CYAN, 8))
 recap_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
 recap_chip.z_index = 15
 # The caption sits just above the row so all the thumbnails fit beside the log.
 recap_chip.position = Vector2(30, 215 - recap_chip.get_minimum_size().y - 6)
 var left = 30
 for i in spotlights.size():
  var panel = spotlights[i]
  panel.get_child(0).get_child(0).custom_minimum_size = SPOTLIGHT_SMALL
  panel.get_child(0).get_child(1).hide()
  panel.reset_size()
  panel.position = Vector2(left + i * (SPOTLIGHT_SMALL.x + 12), 215)
func make_spotlight_panel(id: String, caption: String) -> Control:
 var panel = PanelContainer.new()
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.z_index = 15
 var box = VBoxContainer.new()
 box.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_child(box)
 var image = UIStyle.picture(CardDB.image_path(id), SPOTLIGHT_LARGE)
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 box.add_child(image)
 var label = UIStyle.label(box, caption, 16)
 label.custom_minimum_size.x = SPOTLIGHT_LARGE.x
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(panel)
 panel.position = Vector2(30, 215)
 return panel
func spotlight_timeout() -> float:
 return maxf(6.0, bot_pace * 2 + 4) if online_session == null else 6.0
func spotlight(id: String, caption: String):
 if not is_inside_tree() or (engine.active().seat == human_seat and not engine.state.finished): return
 recap_count += 1
 var opponent = caption.split(" played ")[0].split(" bought ")[0].split(" reserved ")[0]
 if opponent not in recap_names: recap_names.append(opponent)
 recap_history.push_front({"id": id, "caption": caption})
 if recap_history.size() > SPOTLIGHT_THUMBS + 1: recap_history.pop_back()
 var panel = make_spotlight_panel(id, caption)
 spotlights.push_front(panel)
 while spotlights.size() > SPOTLIGHT_THUMBS + 1:
  var oldest = spotlights.pop_back()
  if is_instance_valid(oldest): oldest.queue_free()
 for i in range(1, spotlights.size()):
  var older = spotlights[i]
  if not is_instance_valid(older): continue
  # Earlier cards shrink to thumbnails and slide along; their caption goes (the log has it).
  older.z_index = 14
  older.get_child(0).get_child(0).custom_minimum_size = SPOTLIGHT_SMALL
  older.get_child(0).get_child(1).visible = false
  older.reset_size()
  var target = Vector2(30 + SPOTLIGHT_LARGE.x + 20 + (i - 1) * (SPOTLIGHT_SMALL.x + 12), 215)
  if Sfx.visual_effects: UIStyle.animation(older).tween_property(older, "position", target, UIStyle.motion(0.18))
  else: older.position = target
 panel.modulate.a = 0 if Sfx.visual_effects else 1
 if Sfx.visual_effects: UIStyle.animation(panel).tween_property(panel, "modulate:a", 1.0, UIStyle.motion(0.2))
 # With no further plays for a while (an opponent thinking online), the row clears itself.
 spotlight_serial += 1
 var serial = spotlight_serial
 await get_tree().create_timer(spotlight_timeout()).timeout
 if is_inside_tree() and not recap_active and serial == spotlight_serial: clear_spotlights(0.0)
func moved(_card, _from, _to):
 if _to == "removed": match_stats.removed(_card.owner)
 var seat = _card.owner
 var from_key = _from if _from in ["center_deck", "center_row", "removed"] else "%d:%s" % [seat, _from]
 var to_key = _to if _to in ["center_deck", "center_row", "removed"] else "%d:%s" % [seat, _to]
 var origin = moved_uids.get(_card.uid, {}).get("from", {"zone": from_key, "hidden": _from in ["deck", "center_deck"] or (_from == "hand" and seat != human_seat), "id": _card.id})
 moved_uids[_card.uid] = {"from": origin, "to": {"zone": to_key, "hidden": _to in ["deck", "center_deck"] or (_to == "hand" and seat != human_seat), "id": _card.id}}
 if _to == "hand" and _from == "deck": Sfx.play("card_draw")
 if _from == "discard" and _to == "deck": Sfx.play("shuffle")
 if not is_instance_valid(banner) or not Sfx.visual_effects: return
 banner.modulate = Color("e9c778")
 UIStyle.animation(banner).tween_property(banner, "modulate", Color.WHITE, UIStyle.motion(0.25))
func game_over(winner):
 match_stats.finish(winner.seat if winner != null else -1, engine.state.players)
 if online_session != null:
  if online_over: return
  online_over = true
  engine.state.finished = true
  engine.state.winner = winner
  for i in mini(online_final_players.size(), match_stats.seats.size()):
   match_stats.seats[i].final_life = int(online_final_players[i].life)
   match_stats.seats[i].final_deck_size = int(online_final_players[i].deck_size)
  for timer in countdowns.values(): timer.clear()
  online_prompt_id = ""
  if pending: answered.emit(null)
  OnlineAPI.remember({})
 if online_session == null and not tutorial_mode: SaveGame.remove()
 Sfx.play("win" if winner != null and winner.seat == human_seat else "lose")
 show_result.call_deferred(winner)
func record_lifetime():
 if tutorial_mode or lifetime_recorded or not match_stats.finished: return
 if DisplayServer.get_name() == "headless" and not lifetime_test_enabled: return
 lifetime_recorded = true
 var mode = "local"
 if online_session != null:
  mode = "online_bots"
  for p in engine.state.players:
   if p.seat != human_seat and not p.is_bot: mode = "online_humans"
 var key = lifetime_key
 if online_session != null:
  var room = online_session.room
  key = "online:%s:%s" % [room.get("code", ""), room.get("started_at", room.get("seed", get_instance_id()))]
 load("res://scripts/ui/lifetime_stats.gd").new().record(match_stats, human_seat, seat_heroes[human_seat], mode, key)
func show_result(winner):
 record_lifetime()
 var dim = ColorRect.new()
 dim.z_index = 49
 dim.color = Color(0,0,0,0.6)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(dim)
 dim.modulate.a = 0
 var transition = UIStyle.animation(dim)
 transition.tween_property(dim, "modulate:a", 1.0, UIStyle.motion(0.4))
 var flash = TextureRect.new()
 flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var gradient = Gradient.new()
 var tint = UIStyle.GREEN if winner != null and winner.seat == human_seat else UIStyle.RED
 gradient.offsets = PackedFloat32Array([0, 0.55, 1])
 gradient.colors = PackedColorArray([Color(tint, 0), Color(tint, 0), Color(tint, 0.35)])
 var vignette = GradientTexture2D.new()
 vignette.gradient = gradient
 vignette.fill = GradientTexture2D.FILL_RADIAL
 vignette.fill_from = Vector2(0.5, 0.5)
 vignette.fill_to = Vector2(1, 0.5)
 flash.texture = vignette
 flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(flash)
 var flash_tween = UIStyle.animation(flash)
 flash_tween.tween_property(flash, "modulate:a", 0.0, UIStyle.motion(0.25))
 flash_tween.tween_callback(flash.queue_free)
 var panel = UIStyle.panel("// MATCH SUMMARY")
 panel.name = "MatchSummary"
 panel.z_index = 50
 panel.add_to_group("touch_modal")
 add_child(panel)
 var scroll = ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation", 12)
 scroll.add_child(box)
 UIStyle.dialog(panel, Vector2(1000, 850))
 panel.modulate.a = 0
 panel.scale = Vector2(0.92, 0.92) if Sfx.visual_effects else Vector2.ONE
 var entrance = UIStyle.animation(panel)
 entrance.tween_interval(UIStyle.motion(0.4))
 entrance.tween_property(panel, "modulate:a", 1.0, UIStyle.motion(0.18))
 entrance.parallel().tween_property(panel, "scale", Vector2.ONE, UIStyle.motion(0.18))
 var headline = UIStyle.label(box, result_headline(winner), 36)
 headline.add_theme_color_override("font_color", UIStyle.AMBER if winner == null else (UIStyle.GREEN if winner.seat == human_seat else UIStyle.RED))
 if winner != null:
  var hero = HBoxContainer.new()
  box.add_child(hero)
  hero.add_child(UIStyle.avatar(avatar_hero(winner.seat), 96))
  UIStyle.label(hero, seat_name(winner.seat), 28)
 if match_stats.since_resume: UIStyle.label(box, "Statistics since resume", 22)
 var rows = GridContainer.new()
 rows.columns = 5
 rows.add_theme_constant_override("h_separation", 16)
 box.add_child(rows)
 for title in ["Seat", "Life", "Damage", "Bought", "Played"]: UIStyle.label(rows, title, 22)
 for i in match_stats.seats.size():
  var stat = match_stats.seats[i]
  for text in [seat_name(i), str(stat.final_life), str(stat.damage_dealt), str(stat.cards_bought), str(stat.cards_played)]:
   var label = UIStyle.label(rows, text, 22)
   label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   label.custom_minimum_size.x = 44
 var stat = match_stats.seats[human_seat]
 var highlights = UIStyle.label(box, "Biggest hit: %d · Turns: %d · Duration: %d:%02d\nStar card: %s\nPriciest buy: %s (%d Hacking)" % [stat.biggest_hit, stat.turns, int(match_stats.duration) / 60, int(match_stats.duration) % 60, stats_card_name(match_stats.star_card(human_seat)), stats_card_name(stat.priciest_id), maxi(0, stat.priciest_cost)], 22)
 highlights.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 UIStyle.button(box, "View final deck", func(): view_cards("Your final deck", final_deck()))
 UIStyle.button(box, "Lifetime stats", func(): load("res://scripts/ui/stats_screen.gd").open(self))
 if not tutorial_mode:
  var sharing = load("res://scripts/ui/result_share.gd").new()
  add_child(sharing)
  sharing.install(box, share_details(winner))
 else: UIStyle.label(box, "Tutorial · practice game", 22)
 if online_session == null: UIStyle.button(box, "Play Again", restart)
 UIStyle.button(box, "Menu", leave_game.bind(false) if online_session != null else menu)
 if UIStyle.compact(): UIStyle.touch_fit(panel)
func result_headline(winner) -> String:
 if winner == null: return "Stalemate"
 if winner.seat == human_seat: return "Victory"
 if engine.state.players[human_seat].is_bot: return seat_name(winner.seat) + " wins"
 return "Defeat"
func stats_card_name(id: String) -> String:
 return str(CardDB.cards[id].name) if CardDB.cards.has(id) else "—"
func final_deck() -> Array:
 var p = engine.state.players[human_seat]
 var cards = p.deck + p.hand + p.discard + p.play_area + p.reserve
 var pending_cards = cards.duplicate()
 while not pending_cards.is_empty():
  var c = pending_cards.pop_back()
  cards.append_array(c.attached)
  pending_cards.append_array(c.attached)
 return cards

func restart():
 var table = load("res://scenes/table.tscn").instantiate()
 table.tutorial_mode = tutorial_mode
 table.player_count = player_count
 table.difficulty = difficulty
 table.card_pool = engine.state.card_pool
 table.banned = engine.state.banned.duplicate()
 table.starting_life = starting_life
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
 scroll.custom_minimum_size = Vector2(480, 0)
 panel.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(box)
 UIStyle.button(box, "Resume", close_menu).custom_minimum_size.y = 56
 UIStyle.label(box, "Options", 24)
 UIStyle.layout_setting(box)
 if online_session != null:
  var mute_emotes = CheckButton.new()
  mute_emotes.text = "Mute emotes"
  mute_emotes.button_pressed = not emote_ui.enabled()
  box.add_child(mute_emotes)
  mute_emotes.toggled.connect(emote_ui.mute)
 for setting in ["muted", "visual_effects", "auto_end_turn", "confirm_end_turn"]:
  var toggle = CheckButton.new()
  toggle.text = {"muted": "Sound enabled", "visual_effects": "Visual effects", "auto_end_turn": "Auto-end turn", "confirm_end_turn": "Confirm end turn"}[setting]
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
 var audio_row = HBoxContainer.new()
 box.add_child(audio_row)
 UIStyle.label(audio_row, "SFX", 16)
 volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 audio_row.add_child(volume)
 volume.value_changed.connect(func(value): Sfx.volume = value; Sfx.save())
 UIStyle.music_controls(audio_row)
 if online_session == null: Sfx.pace_option(box, bot_pace, set_bot_pace)
 UIStyle.button(box, "Rules", func():
  close_menu()
  rules_overlay = RulesPage.open(self)).custom_minimum_size.y = 56
 UIStyle.button(box, "Report a bug", report_bug)
 if online_session == null:
  save_button = UIStyle.button(box, "Save game", func():
   if save_game(): save_status.text = "Game saved"
   else: save_status.text = "Could not save game")
  save_button.custom_minimum_size.y = 56
  save_status = UIStyle.label(box, "", 16)
  save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 UIStyle.button(box, "Leave game" if online_session != null else "Main menu", leave_game.bind(false)).custom_minimum_size.y = 56
 var exit_button = UIStyle.button(box, "Exit game", leave_game.bind(true))
 exit_button.custom_minimum_size.y = 56
 exit_button.visible = not UIStyle.is_web()
 update_save_button()
 var fit_menu = func():
  scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, get_viewport_rect().size.y - panel.position.y - 40)
 box.minimum_size_changed.connect(fit_menu)
 fit_menu.call()
func close_menu():
 if is_instance_valid(game_menu):
  game_menu.queue_free()
 game_menu = null
 auto_end_elapsed = 0
func set_bot_pace(value: float):
 bot_pace = Sfx.nearest(value)
 Sfx.bot_pace = bot_pace
 Sfx.save()
 sync_options()
func open_pace_popup():
 if is_instance_valid(pace_popup): pace_popup.queue_free()
 pace_popup = PopupPanel.new()
 add_child(pace_popup)
 Sfx.pace_option(pace_popup, bot_pace, func(value): set_bot_pace(value); pace_popup.hide())
 pace_popup.popup_centered()
func sync_options():
 speed_button.text = "» " + Sfx.pace_label(bot_pace, true)
 mute_button.text = "♪ OFF" if Sfx.muted else "♪ ON"
func can_save_uncached() -> bool:
 if tutorial_mode: return false
 if online_session != null: return false
 return not saving and not pending and not acting and not driving and SaveGame.safe(engine) and not engine.state.players[human_seat].is_bot and engine.state.players.slice(1).all(func(p): return p.is_bot)
func save_game() -> bool:
 if not can_save(): return false
 saving = true
 auto_end_elapsed = 0
 var ok = SaveGame.write(engine, {"seat_names": seat_names, "seat_heroes": seat_heroes, "player_count": player_count, "starting_life": starting_life, "difficulties": engine.state.players.map(func(p): return p.difficulty), "handle": seat_names[0], "hero_id": seat_heroes[human_seat], "bot_pace": bot_pace, "log": "".join(log_entries), "log_entries": log_entries, "lifetime_key": lifetime_key, "match_stats": match_stats.to_dict()})
 saving = false
 return ok
func auto_save():
 if can_save() and last_autosave_turn != engine.state.turn:
  if save_game(): last_autosave_turn = engine.state.turn
func update_save_button():
 if online_session != null: return
 if not is_instance_valid(game_menu): return
 save_button.disabled = not can_save()
 if save_button.disabled: save_status.text = "Save is available on your turn when nothing is resolving"
 elif save_status.text.begins_with("Save is available"): save_status.text = ""
func leave_game(quit_game: bool):
 close_menu()
 if online_session != null:
  online_session.disconnect_game()
  if quit_game: get_tree().quit()
  else: get_tree().change_scene_to_file("res://scenes/menu.tscn")
  return
 if not tutorial_mode and not engine.state.finished and not save_game():
  if pending: return
  var answer = await decision("Leave without saving? Progress since the last save will be lost.", ["Leave", "Stay"], [], 1, 1, false)
  if answer != 0: return
 if quit_game: get_tree().quit()
 else: get_tree().change_scene_to_file("res://scenes/menu.tscn")

func turn_band(p):
 var band = UIStyle.panel()
 band.mouse_filter = Control.MOUSE_FILTER_IGNORE
 band.position = Vector2(-size.x if Sfx.visual_effects else 0.0, 360)
 band.size = Vector2(size.x, 100)
 var row = HBoxContainer.new()
 band.add_child(row)
 row.add_child(UIStyle.avatar(avatar_hero(p.seat)))
 add_child(band)
 var text = UIStyle.label(row, ("YOUR TURN" + (" · " + seat_name(human_seat).to_upper() if not Sfx.handle.is_empty() else "")) if p.seat == human_seat else seat_name(p.seat).to_upper() + " IS HACKING…", 48)
 text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 UIStyle.glitch(text)
 text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 text.add_theme_color_override("font_color", UIStyle.GREEN if p.seat == human_seat else UIStyle.AMBER)
 var t = UIStyle.animation(band)
 t.tween_property(band, "position:x", 0.0, UIStyle.motion(0.18))
 t.tween_interval(0.85)
 t.tween_property(band, "modulate:a", 0.0, UIStyle.motion(0.17))
 t.tween_callback(band.queue_free)

func flash_readout(node: Control):
 if not Sfx.visual_effects: return
 node.modulate = Color(1.5, 1.5, 1.5)
 UIStyle.animation(node).tween_property(node, "modulate", Color.WHITE, UIStyle.motion(0.35))

func inspect_card(c, interactive: bool = false):
 hide_zoom()
 hover_serial += 1
 close_inspect()
 inspect_overlay = CanvasLayer.new()
 inspect_overlay.layer = 100
 inspect_overlay.add_to_group("touch_modal")
 add_child(inspect_overlay)
 var dim = ColorRect.new()
 dim.z_index = 49
 dim.color = Color(0, 0, 0, 0.7)
 inspect_overlay.add_child(dim)
 UIStyle.viewport_cover(dim)
 var panel = UIStyle.panel()
 dim.add_child(panel)
 panel.mouse_filter = Control.MOUSE_FILTER_STOP
 # CanvasLayer separates the sheet from the table's inherited Control theme.
 UIStyle.apply(panel)
 var background = UIStyle.dialog_box()
 background.bg_color.a = 1.0
 panel.add_theme_stylebox_override("panel", background)
 var row = HBoxContainer.new()
 panel.add_child(row)
 row.add_theme_constant_override("separation", 24)
 var picture = UIStyle.picture(CardDB.image_path(c.id), Vector2(360, 492))
 picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
 row.add_child(picture)
 var scroll = ScrollContainer.new()
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 row.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation", 12)
 scroll.add_child(box)
 var data = CardDB.cards[c.id]
 UIStyle.label(box, data.name, 28).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var chips = HFlowContainer.new()
 box.add_child(chips)
 sheet_chip(chips, "Base Set · PhreakNIC 26" if data.get("set", "2025") == "2025" else "Expansion 1 · PhreakNIC 27")
 sheet_chip(chips, data.type_line)
 var p = engine.state.players[human_seat]
 var cost = engine.effective_cost(p, c) if c is CardInstance else int(data.cost)
 sheet_chip(chips, "Cost %d" % int(data.cost) + (" · %d for you" % cost if cost != int(data.cost) else ""))
 var rules = UIStyle.rich_label(box, escaped(data.text), 22)
 rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 for id in CardDB.cards:
  var name_text = str(CardDB.cards[id].name)
  if id != c.id and name_text.to_lower() in str(data.text).to_lower():
   var matched = (p.hand + p.played).any(func(partner): return partner.id == id)
   var partner = UIStyle.label(box, ("★ " if matched else "Combo: ") + name_text, 18)
   partner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   if matched: partner.add_theme_color_override("font_color", UIStyle.GREEN)
 if c is CardInstance and c in engine.permanents():
  UIStyle.label(box, "ICE: %d · Owner: %s" % [c.counters, seat_name(c.owner)], 18)
  if c.controller != c.owner: UIStyle.label(box, "Controller: " + seat_name(c.controller), 18)
  if c.flags.get("used", false): UIStyle.label(box, "Used this turn", 18)
 if c is CardInstance:
  var reason = engine.why_not_play(p, c) if c in p.hand else (engine.why_not_buy(p, c) if c in engine.state.center_row or c in p.reserve else "")
  if not reason.is_empty(): UIStyle.label(box, reason, 22).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 if c is CardInstance and c in p.hand and data.kind == "Permanent" and not engine.can_play(p, c) and engine.permanents().any(func(x): return x.effect_id() == "Nashville 2600"):
  UIStyle.label(box, "Nashville 2600 is in play: no one can play permanents.", 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 if c is CardInstance and available() and c in engine.permanents():
  for ability in engine.activatable_abilities(p, c):
   if ability.enabled: UIStyle.button(box, ability.label, sheet_activate.bind(c, ability.index))
 if interactive and available():
  if c in engine.state.center_row or c in p.reserve:
   var buy = UIStyle.button(box, "Buy — %d Hacking" % cost, sheet_buy.bind(c))
   UIStyle.primary(buy)
   buy.disabled = not engine.can_buy(p, c)
   if engine.can_reserve(p, c): UIStyle.button(box, "Reserve", func(): close_inspect(); reserve_selected(p, c))
   var can_reserve = engine.can_reserve(p, c)
   var hint = ""
   if cost > p.hacking: hint = "You need %d more Hacking" % (cost - p.hacking) + (", or reserve it to buy on a later turn" if can_reserve else "")
   elif can_reserve: hint = "If you reserve, you can't buy or acquire anything else this turn"
   if hint != "": UIStyle.label(box, hint, 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  if c in p.hand and engine.can_play(p, c): UIStyle.button(box, "Play", func(): close_inspect(); selected_hand = c; card_clicked(c, "hand"))
 UIStyle.button(box, "Close", close_inspect)
 for control in box.get_children():
  if control is Button:
   control.custom_minimum_size.y = 72 if UIStyle.compact() else 56
   control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var fit_sheet = func():
  if not dim.is_inside_tree(): return
  var view = dim.get_viewport_rect().size
  var limit = view * 0.9
  var width = minf(1100, limit.x)
  var image_scale = minf(1.0, minf((limit.y - 84) / 492, (width - 108) * 0.4 / 360))
  picture.custom_minimum_size = Vector2(360, 492) * maxf(0.1, image_scale)
  scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, limit.y - 84)
  panel.size = Vector2(width, maxf(picture.custom_minimum_size.y, scroll.custom_minimum_size.y) + 84)
  panel.position = (view - panel.size) / 2
 box.minimum_size_changed.connect(fit_sheet)
 dim.resized.connect(fit_sheet)
 fit_sheet.call_deferred()
 dim.gui_input.connect(func(event):
  if (event is InputEventScreenTouch or event is InputEventMouseButton):
   dim.accept_event()
   if event.pressed: dim.set_meta("closing", true)
   elif dim.has_meta("closing"): close_inspect())
func sheet_activate(c, index: int):
 close_inspect()
 await activate_card(c, index)
func sheet_buy(c):
 close_inspect()
 if not available(): return
 if online_session != null: online_action("buy", c.uid); return
 acting = true
 await engine.buy_card(engine.state.players[human_seat], c)
 acting = false
 redraw()
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
 if is_instance_valid(emote_ui) and is_instance_valid(emote_ui.popup):
  emote_ui.close()
  return
 if is_instance_valid(tutorial_coach) and not tutorial_coach.stopped:
  tutorial_coach.skip()
  return
 if is_instance_valid(hand_selection): clear_hand_selection(); return
 if is_instance_valid(ban_picker) and ban_picker.close_top(): return
 if is_instance_valid(inspect_overlay): close_inspect()
 elif is_instance_valid(rules_overlay): rules_overlay.queue_free(); rules_overlay = null
 elif is_instance_valid(game_menu): close_menu()
 elif pending:
  if back_answer != null: answered.emit(back_answer)
 else: menu()

func _input(event):
 if recap_active and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.pressed: dismiss_recap()
 if event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION):
  hover_serial += 1
  hide_zoom()
  for control in TouchInput.cards:
   if is_ancestor_of(control) and control.get_parent().get_meta("zone", "") == "hand":
    control.position.y = 0
    control.get_parent().z_index = 0

func nothing_left_uncached() -> bool:
 if engine == null or engine.state == null or not available() or acting or driving or engine.reaction_depth > 0 or not engine.state.resolving.is_empty() or is_instance_valid(inspect_overlay): return false
 var p = engine.state.players[human_seat]
 for c in p.hand:
  if engine.can_play(p, c): return false
 for c in engine.state.center_row:
  if c != null and (engine.can_buy(p, c) or engine.can_reserve(p, c)): return false
 for c in p.reserve:
  if engine.can_buy(p, c): return false
 for c in engine.permanents():
  for ability in engine.activatable_abilities(p, c):
   if ability.enabled: return false
 return true
func refresh_action_cache():
 var key = [state_revision, pending, acting, driving, saving, engine.busy, engine.reaction_depth, is_instance_valid(inspect_overlay), engine.state.turn, engine.state.finished, engine.simultaneous_depth, engine.state.resolving.size(), available()]
 if key == action_cache_key: return
 action_cache_key = key
 cached_save = can_save_uncached()
 cached_nothing = nothing_left_uncached()
func can_save() -> bool:
 if engine == null or engine.state == null: return false
 refresh_action_cache()
 return cached_save
func nothing_left() -> bool:
 if engine == null or engine.state == null: return false
 refresh_action_cache()
 return cached_nothing
func _process(delta):
 if recap_active:
  recap_elapsed += delta
  if recap_elapsed >= 20: dismiss_recap()
 if engine != null and engine.state != null and not match_stats.finished: match_stats.duration += delta
 if engine == null or engine.state == null: return
 position_countdowns()
 auto_save()
 update_save_button()
 if tutorial_mode or saving or is_instance_valid(game_menu) or is_instance_valid(rules_overlay) or not Sfx.auto_end_turn or not nothing_left():
  auto_end_elapsed = 0
  auto_end_turn_number = -1
  return
 if auto_end_turn_number != engine.state.turn:
  auto_end_turn_number = engine.state.turn
  auto_end_elapsed = 0
  append_log("No moves left — ending turn")
 show_notice("No moves left — ending turn")
 auto_end_elapsed += delta
 if auto_end_elapsed >= 1.2:
  auto_end_elapsed = 0
  end_human_turn(true)

# Keep both callbacks alive until their listeners have been removed.
var page_window
var visibility_callback
var pagehide_callback
func install_page_listeners():
 if not UIStyle.is_web(): return
 page_window = JavaScriptBridge.get_interface("window")
 if page_window == null: return # Headless tests with the web override.
 visibility_callback = JavaScriptBridge.create_callback(func(_args):
  if page_window.document.hidden: page_hidden())
 pagehide_callback = JavaScriptBridge.create_callback(func(_args): page_hidden())
 page_window.document.addEventListener("visibilitychange", visibility_callback)
 page_window.addEventListener("pagehide", pagehide_callback)
func page_hidden():
 if UIStyle.is_web(): save_game()
func _exit_tree():
 if online_session != null: online_session.disconnect_game()
 if not UIStyle.is_web() or page_window == null: return
 page_window.document.removeEventListener("visibilitychange", visibility_callback)
 page_window.removeEventListener("pagehide", pagehide_callback)
 visibility_callback = null
 pagehide_callback = null
 page_window = null

var notice: Control
var notice_text = ""
func show_notice(message: String, duration: float = 4.0):
 if message == notice_text and is_instance_valid(notice): return
 if is_instance_valid(notice): notice.queue_free()
 notice_text = message
 # A boxed strip centred over the play area, so it stays readable over the opponent panels.
 var strip = PanelContainer.new()
 var style = UIStyle.box(Color(0.015, 0.035, 0.045, 0.94), UIStyle.AMBER, 8)
 style.content_margin_left = 22
 style.content_margin_right = 22
 style.content_margin_top = 8
 style.content_margin_bottom = 8
 strip.add_theme_stylebox_override("panel", style)
 strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
 strip.z_index = 30
 add_child(strip)
 var text = UIStyle.label(strip, message, 22)
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
 text.add_theme_color_override("font_color", UIStyle.AMBER)
 strip.modulate.a = 0.0
 # Place it on the next frame, once the table and the strip have their real sizes (not yet true at game start).
 var strip_ref = weakref(strip)
 var place = func():
  var current = strip_ref.get_ref()
  if current == null: return
  var play_width = size.x
  if is_instance_valid(log_view) and log_view.is_visible_in_tree() and log_view.global_position.x - global_position.x > 400:
   play_width = log_view.global_position.x - global_position.x
  current.position = Vector2(maxf(20.0, (play_width - current.size.x) / 2.0), 58)
  current.modulate.a = 1.0
 get_tree().process_frame.connect(place, CONNECT_ONE_SHOT)
 notice = strip
 var tween = UIStyle.animation(strip)
 tween.tween_interval(duration)
 tween.tween_property(notice, "modulate:a", 0.0, UIStyle.motion(0.5))
 tween.tween_callback(notice.queue_free)
func report_bug():
 var details = "Seed: %s; Set: %s; Players: %d; Difficulties: %s; Turn: %d\n" % [engine.state.rng.seed, engine.state.card_pool, player_count, str(engine.state.players.map(func(p): return p.difficulty)), engine.state.turn]
 var private_log = "\n".join(log_view.get_parsed_text().strip_edges().split("\n").slice(-25))
 details += load("res://scripts/ui/bug_report.gd").redact(private_log, seat_names, engine.state.players.map(func(p): return p.is_bot), human_seat)
 load("res://scripts/ui/bug_report.gd").open(details)

func prevention_choice(amount: int, sources: Array) -> Array:
 dismiss_recap()
 pending = true
 back_answer = null
 var values: Array = []
 var remaining = amount
 var total = 0
 for source in sources:
  var n = mini(remaining, source.capacity)
  values.append(n)
  remaining -= n
  total += source.capacity
 var required = mini(amount, total)
 var overlay = UIStyle.panel()
 overlay.add_to_group("touch_modal")
 # Above bot card spotlights (z 15) so a prompt during a bot turn is never hidden.
 overlay.z_index = 20
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.label(box, "%d damage incoming from %s" % [amount, incoming_source], 26)
 var labels: Array = []
 var minus: Array = []
 var plus: Array = []
 for i in sources.size():
  var source = sources[i]
  var row = HBoxContainer.new()
  box.add_child(row)
  var source_name = CardDB.cards[source.card.id].name if source.card != null else source.get("name", "Prevention")
  UIStyle.label(row, "%s · ICE / capacity %d" % [source_name, source.capacity], 20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
  minus.append(UIStyle.button(row, "−", func(): values[i] -= 1; prevention_updated.emit()))
  labels.append(UIStyle.label(row, str(values[i]), 24))
  plus.append(UIStyle.button(row, "+", func(): values[i] += 1; prevention_updated.emit()))
  minus[i].custom_minimum_size = Vector2(56, 56)
  plus[i].custom_minimum_size = Vector2(56, 56)
 var summary = UIStyle.label(box, "", 22)
 var confirm = UIStyle.button(box, "Confirm", func(): answered.emit(values.duplicate()))
 var update = func():
  var absorbed = 0
  for n in values: absorbed += n
  for i in sources.size():
   labels[i].text = str(values[i])
   minus[i].disabled = values[i] <= 0
   plus[i].disabled = values[i] >= sources[i].capacity or absorbed >= required
  summary.text = "Your life: no change" if amount == absorbed else "Your life: −%d" % (amount - absorbed)
  confirm.disabled = absorbed != required
 prevention_updated.connect(update)
 update.call()
 UIStyle.dialog(overlay, Vector2(950, 650))
 var result = await answered
 prevention_updated.disconnect(update)
 overlay.queue_free()
 pending = false
 redraw()
 return result if result != null else []
signal prevention_updated

func sheet_chip(parent: Control, text: String):
 var chip = UIStyle.panel()
 chip.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, UIStyle.CYAN, 0))
 parent.add_child(chip)
 UIStyle.label(chip, text, 16)

func reserve_selected(p, c):
 if online_session != null: online_action("reserve", c.uid)
 else: engine.reserve_card(p, c); redraw()
func online_action(kind: String, uid = null, index = null):
 online_session.client.send_action(kind, uid, index)
 redraw()
func setup_online():
 bot_pace = Sfx.nearest(online_session.room.get("bot_pace", 0.5))
 var client = online_session.client
 emote_ui = load("res://scripts/ui/emotes.gd").new()
 emote_ui.table = self
 add_child(emote_ui)
 UIStyle.button(menu_button.get_parent(), "Emote", emote_ui.open)
 engine = client.engine
 human_seat = client.seat
 player_count = engine.state.players.size()
 match_stats.setup(player_count, engine.state.card_pool, engine.state.players.map(func(p): return p.difficulty), engine.state.turn > 1)
 card_pool = engine.state.card_pool
 starting_life = engine.state.starting_life
 for seat in client.seats:
  seat_names.append(str(seat.name))
  seat_heroes.append(str(seat.get("hero", "")))
 for id in CardDB.pool_ids(card_pool): card_names.append({"id": id, "name": str(CardDB.cards[id].name)})
 card_names.sort_custom(func(a, b): return a.name.length() > b.name.length())
 connection_dot = UIStyle.label(menu_button.get_parent(), "●", 22)
 connection_dot.tooltip_text = online_session.status
 connection_dot.add_theme_color_override("font_color", UIStyle.GREEN if online_session.status == "Connected" else UIStyle.AMBER)
 speed_button.visible = false
 client.view_changed.connect(redraw)
 for text in client.log_history: append_log(text)
 client.log.connect(append_log)
 client.error.connect(func(reason): show_notice(str(reason)))
 client.prompt.connect(online_prompt)
 client.prompt_done.connect(func(id):
  if countdowns.has(human_seat): countdowns[human_seat].clear()
  if id == online_prompt_id:
   online_prompt_id = ""
   if pending: answered.emit(null))
 client.event.connect(online_event)
 client.message_received.connect(func(data):
  if data.get("t") == "game_over": online_final_players = data.get("final_players", [])
  if data.get("type") == "emote": emote_ui.receive(data)
  if data.get("t") == "view": apply_countdowns(data.get("timers", []))
  if data.get("t") == "welcome":
   waiting_seats.clear()
   update_waiting_banner())
 for data in client.waiting.values(): online_event(data)
 online_session.finished.connect(func(winner):
  game_over(engine.state.players[winner] if winner >= 0 and winner < engine.state.players.size() else null))
 online_session.removed.connect(func(text):
  var screen = load("res://scripts/ui/online.gd").new()
  screen.initial_status = text
  get_tree().root.add_child(screen)
  get_tree().current_scene = screen
  queue_free())
 online_session.status_changed.connect(func(text):
  redraw()
  connection_dot.tooltip_text = text
  connection_dot.add_theme_color_override("font_color", UIStyle.GREEN if text == "Connected" else UIStyle.AMBER)
  if text != "Connected": show_notice(text, 3600)
  elif is_instance_valid(notice): notice.queue_free(); notice_text = ""
  if text.begins_with("Game server unavailable"): UIStyle.button(menu_button.get_parent(), "Back to menu", leave_game.bind(false)))
 redraw()
 for id in client.prompts: online_prompt(id, client.prompts[id])
 if engine.state.finished: game_over(engine.state.winner)
func online_prompt(id: String, data: Dictionary):
 if online_prompt_id == id: return
 if pending:
  online_prompt_id = ""
  answered.emit(null)
 online_prompt_id = id
 if data.has("remaining_seconds"):
  timer_for(human_seat).configure(float(data.remaining_seconds), 45, "prompt")
 Sfx.play("your_turn")
 var value
 match data.kind:
  "choose_option", "choose_options":
   value = await decision(data.text, data.options, [], int(data.get("count", 1)), int(data.get("count", 1)), data.kind == "choose_options")
  "choose_cards":
   var cards = data.cards.map(NetClient.prompt_card)
   var indices = await decision(data.text, [], cards, data.min, data.max, true)
   if indices != null: value = indices.map(func(i): return cards[i].uid)
  "choose_player":
   var index = await decision(data.text, data.players.map(func(i): return seat_name(i)), [], 1, 1, false)
   if index != null: value = data.players[index]
  "choose_number":
   var index = await decision(data.text, data.allowed.map(func(n): return str(n)), [], 1, 1, false)
   if index != null: value = data.allowed[index]
  "confirm":
   var index = await decision(data.text, ["Yes", "No"], [], 1, 1, false)
   if index != null: value = index == 0
  "name_a_card":
   var ids = CardDB.pool_ids(data.card_pool)
   ids.sort_custom(func(a, b): return CardDB.cards[a].name < CardDB.cards[b].name)
   var index = await decision(data.text, ids.map(func(c): return CardDB.cards[c].name), [], 1, 1, false, true)
   if index != null: value = ids[index]
  "allocate_prevention":
   var sources = []
   for entry in data.sources:
    var source = entry.duplicate()
    source.card = NetClient.prompt_card(entry.card)
    sources.append(source)
   value = await prevention_choice(data.amount, sources)
 if online_prompt_id == id and value != null:
  online_prompt_id = ""
  online_session.client.answer(id, value)
var waiting_banner: Control
var waiting_seats: Dictionary = {}
func update_waiting_banner():
 if is_instance_valid(waiting_banner):
  remove_child(waiting_banner)
  waiting_banner.queue_free()
 waiting_banner = null
 if waiting_seats.is_empty(): return
 waiting_banner = UIStyle.panel()
 waiting_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
 waiting_banner.z_index = 29
 add_child(waiting_banner)
 waiting_banner.position = Vector2(30, 112)
 var text = UIStyle.label(waiting_banner, "Waiting for " + ", ".join(waiting_seats.values()) + " to choose…", 20)
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
func online_event(data: Dictionary):
 if engine.state == null: return
 match data.kind:
  "damage_dealt": match_stats.damage(int(data.source), int(data.target), int(data.amount))
  "damage_taken": match_stats.damage(-1, int(data.seat), int(data.amount))
  "life_gained": match_stats.gain(int(data.seat), int(data.amount))
  "purchase_paid": match_stats.bought(int(data.seat), str(data.id), int(data.cost))
  "removed": match_stats.removed(int(data.seat))
  "idle_warning":
   Sfx.play("warning")
   show_notice("Bot finishes this turn in 60 s; control returns next turn. Three consecutive idle turns make takeover permanent.", 60)
  "waiting":
   waiting_seats[int(data.seat)] = seat_name(int(data.seat))
   update_waiting_banner()
  "waiting_done":
   waiting_seats.erase(int(data.seat))
   update_waiting_banner()
  "turn_started":
   match_stats.turn(int(data.seat))
   Sfx.play("your_turn" if data.seat == human_seat else "turn_start")
   if data.seat == human_seat: begin_recap()
   turn_band(engine.state.players[data.seat])
  "turn_ended":
   if data.seat == human_seat: end_recap_turn()
  "draw": Sfx.play("card_draw")
  "ice_counter_removed": Sfx.play("ice")
  "played", "bought", "reserved":
   if data.kind == "played": match_stats.played(int(data.seat), str(data.id))
   Sfx.play({"played": "card_play", "bought": "buy", "reserved": "reserve"}[data.kind])
   if data.seat != human_seat: spotlight(str(data.id), seat_name(data.seat))
  "eliminated":
   Sfx.play("eliminated")
   show_notice(seat_name(data.seat) + " eliminated", 7)

func compact_node_added(node: Node):
 if UIStyle.compact() and is_ancestor_of(node): UIStyle.touch_fit_id.call_deferred(node.get_instance_id())

func share_details(winner) -> Dictionary:
 var stat = match_stats.seats[human_seat]
 var opponents: Array = []
 var all_bots = true
 var levels: Array = []
 for p in engine.state.players:
  if p.seat == human_seat: continue
  all_bots = all_bots and p.is_bot
  var level = BotDifficulty.DISPLAY_NAMES[p.difficulty] if p.is_bot else ""
  if p.is_bot and level not in levels: levels.append(level)
  opponents.append(seat_name(p.seat) + (" / " + level if p.is_bot else ""))
 var hero = seat_heroes[human_seat]
 return {"headline": result_headline(winner), "victory": winner != null and winner.seat == human_seat, "handle": seat_name(human_seat), "hero": hero, "hero_name": stats_card_name(hero), "life": stat.final_life, "turns": stat.turns, "damage": stat.damage_dealt, "bought": stat.cards_bought, "biggest": stat.biggest_hit, "most_played": match_stats.star_card(human_seat), "most_played_name": stats_card_name(match_stats.star_card(human_seat)), "opponents": opponents, "all_bots": all_bots, "difficulty": "/".join(levels), "pool": engine.state.card_pool, "version": str(ProjectSettings.get_setting("application/config/version")), "date": Time.get_date_string_from_system()}

func timer_for(seat: int):
 if not countdowns.has(seat):
  var timer = load("res://scripts/ui/turn_countdown.gd").new()
  add_child(timer)
  timer.z_index = 28
  countdowns[seat] = timer
 return countdowns[seat]
func apply_countdowns(timers: Array):
 var present = []
 for data in timers:
  var seat = int(data.get("seat", -1))
  if seat < 0 or seat >= player_count: continue
  if seat == human_seat and online_prompt_id != "": continue
  timer_for(seat).configure(float(data.remaining_seconds), float(data.limit), str(data.kind), seat == human_seat)
  present.append(seat)
 for seat in countdowns:
  if seat not in present and not (seat == human_seat and online_prompt_id != ""): countdowns[seat].clear()
 position_countdowns()
func position_countdowns():
 for seat in countdowns:
  var timer = countdowns[seat]
  if seat == human_seat: timer.position = Vector2(30, 142)
  elif life_labels.has(seat) and is_instance_valid(life_labels[seat]): timer.position = life_labels[seat].global_position - global_position + Vector2(0, 45)
