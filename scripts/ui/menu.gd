extends Control
const PLAYER_COUNTS = [2, 3, 4]
var rules_overlay: Control
var difficulty: OptionButton
var handle_input: LineEdit
var avatar_preview: Control
var count: OptionButton
# Hero card art loads in the background so the picker opens instantly (a cold, synchronous load froze phones for seconds).
var hero_icons: Dictionary = {}
var loading_icons: Array[String] = []
var picker_buttons: Dictionary = {}
func _ready():
 get_tree().auto_accept_quit = true
 for id in UIStyle.heroes():
  var path = "res://assets/cards/" + id + ".jpg"
  if ResourceLoader.load_threaded_request(path) == OK: loading_icons.append(path)
 UIStyle.rotate_prompt(self)
 UIStyle.apply(self)
 UIStyle.background(self)
 var row = HBoxContainer.new()
 row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 row.position = Vector2(-780, -465)
 row.size = Vector2(1560, 930)
 row.add_theme_constant_override("separation", 70)
 add_child(row)
 var art = UIStyle.panel()
 art.custom_minimum_size = Vector2(520, 740)
 art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 row.add_child(art)
 art.add_child(UIStyle.picture(UIStyle.BACK, Vector2(500, 700)))
 if Sfx.visual_effects:
  var float_tween = create_tween().set_loops()
  float_tween.tween_property(art, "position:y", 8.0, 3.0).as_relative()
  float_tween.tween_property(art, "position:y", -8.0, 3.0).as_relative()
  UIStyle.pulse(art, UIStyle.CYAN.lightened(0.5))
 var menu = VBoxContainer.new()
 menu.custom_minimum_size.x = 900
 menu.add_theme_constant_override("separation", 5)
 # The compact menu fits the supported viewports; avoid native touch-scroll
 # interception around the handle and Hero button.
 row.add_child(menu)
 var title = UIStyle.label(menu, "PhreakNIC", 66)
 title.add_theme_color_override("font_color", UIStyle.CYAN)
 title.add_theme_color_override("font_shadow_color", Color(UIStyle.CYAN, 0.5))
 title.add_theme_constant_override("shadow_offset_x", 3)
 title.add_theme_constant_override("shadow_offset_y", 3)
 title.add_theme_constant_override("shadow_outline_size", 8)
 UIStyle.glitch(title)
 UIStyle.label(menu, "C C G  /  NETWORK DECKBUILDING", 26)
 if Sfx.visual_effects:
  var glitch = create_tween().set_loops()
  glitch.tween_interval(4.2)
  glitch.tween_property(title, "modulate", UIStyle.AMBER, 0.045)
  glitch.tween_property(title, "modulate", Color.WHITE, 0.055)
 var credit = UIStyle.label(menu, "Original FOTTR TCG created by 5ud0, bitwize & crook3dfingers (FOTTR)", 18)
 credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var version = UIStyle.label(self, "v" + str(ProjectSettings.get_setting("application/config/version", "")), 16)
 version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 version.position -= Vector2(110, 40)
 var terminal = UIStyle.label(menu, "> CONNECT / SHUFFLE / HACK ▌", 22)
 terminal.add_theme_color_override("font_color", UIStyle.GREEN)
 if Sfx.visual_effects:
  terminal.visible_characters = 0
  create_tween().tween_property(terminal, "visible_characters", terminal.text.length(), 1.3)
 UIStyle.label(menu, "// YOUR HANDLE", 18)
 var handle_row = HBoxContainer.new()
 menu.add_child(handle_row)
 avatar_preview = UIStyle.avatar(Sfx.hero_id)
 handle_row.add_child(avatar_preview)
 handle_input = LineEdit.new()
 handle_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 handle_input.placeholder_text = "You"
 handle_input.max_length = 0 # Hero printed names can be longer than custom handles.
 handle_input.text = Sfx.handle
 handle_row.add_child(handle_input)
 UIStyle.button(handle_row, "Pick a Hero", pick_hero)
 handle_input.text_changed.connect(func(value):
  var caret = handle_input.caret_column
  var filtered = value.replace("[", "").replace("]", "")
  if filtered != value:
   handle_input.text = filtered
   handle_input.caret_column = mini(caret, filtered.length())
  Sfx.hero_id = ""
  refresh_avatar()
  Sfx.handle = Sfx.clean_handle(filtered)
  Sfx.save())
 handle_input.focus_exited.connect(func(): handle_input.text = Sfx.handle)
 UIStyle.label(menu, "// SELECT YOUR ADVERSARY", 18)
 difficulty = OptionButton.new()
 difficulty.visible = false
 for name in BotDifficulty.DISPLAY_NAMES: difficulty.add_item(name)
 menu.add_child(difficulty)
 var tiles = HBoxContainer.new()
 tiles.add_theme_constant_override("separation", 12)
 menu.add_child(tiles)
 var group = ButtonGroup.new()
 var accents = [UIStyle.GREEN, UIStyle.AMBER, UIStyle.RED]
 var flavors = ["Borrowed scripts.", "Knows the network.", "Already owns the box."]
 for i in 3:
  var tile = UIStyle.button(tiles, BotDifficulty.DISPLAY_NAMES[i] + "\n" + flavors[i] + "\n" + "●".repeat(i + 1) + "○".repeat(2 - i), func(): difficulty.select(i))
  tile.toggle_mode = true
  tile.button_group = group
  tile.button_pressed = i == 0
  tile.custom_minimum_size = Vector2(280, 110)
  tile.add_theme_font_size_override("font_size", 18)
  tile.add_theme_color_override("font_color", accents[i])
  tile.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, accents[i], 0))
  tile.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL.lightened(0.06), accents[i], 10))
 var configuration = HBoxContainer.new()
 menu.add_child(configuration)
 var players_box = VBoxContainer.new()
 configuration.add_child(players_box)
 UIStyle.label(players_box, "// PLAYERS", 18)
 count = OptionButton.new()
 count.visible = false
 for n in [2, 3, 4]: count.add_item(str(n), n)
 menu.add_child(count)
 var seats = HBoxContainer.new()
 players_box.add_child(seats)
 var seat_group = ButtonGroup.new()
 for n in PLAYER_COUNTS:
  var seat = UIStyle.button(seats, str(n) + " players", func(): count.select(n - 2); count.item_selected.emit(n - 2))
  seat.toggle_mode = true
  seat.button_group = seat_group
  seat.button_pressed = n == 2
  seat.custom_minimum_size.x = 96
  seat.add_theme_font_size_override("font_size", 14)
 var sets_box = VBoxContainer.new()
 configuration.add_child(sets_box)
 UIStyle.label(sets_box, "// CARD SET", 18)
 var sets = HBoxContainer.new()
 sets_box.add_child(sets)
 var pool_group = ButtonGroup.new()
 for pool in ["2025", "2026"]:
  var description = "Base Set — PhreakNIC 26\n102 cards" if pool == "2025" else "Base Set + Expansion 1 — PhreakNIC 27\n150 cards"
  var tile = UIStyle.button(sets, description, func(): Sfx.card_pool = pool; Sfx.save())
  tile.toggle_mode = true
  tile.button_group = pool_group
  tile.button_pressed = Sfx.card_pool == pool
  tile.custom_minimum_size = Vector2(280, 60)
  tile.add_theme_font_size_override("font_size", 16)
  tile.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.PANEL, UIStyle.CYAN, 0))
  tile.add_theme_stylebox_override("pressed", UIStyle.box(UIStyle.PANEL.lightened(0.06), UIStyle.CYAN, 10))
 var life_row = HBoxContainer.new()
 menu.add_child(life_row)
 UIStyle.label(life_row, "Starting life", 18)
 var life = OptionButton.new()
 life_row.add_child(life)
 for n in [0, 20, 30, 40]:
  life.add_item("Standard · 24" if n == 0 else str(n), n)
  if n == Sfx.starting_life: life.select(life.item_count - 1)
 count.item_selected.connect(func(_i): life.set_item_text(0, "Standard · %d" % (24 if count.get_selected_id() == 2 else 10 * count.get_selected_id())))
 life.item_selected.connect(func(_i): Sfx.starting_life = life.get_selected_id(); Sfx.save())
 var actions = HBoxContainer.new()
 menu.add_child(actions)
 var saved = SaveGame.read()
 if not saved.is_empty():
  UIStyle.button(actions, "Resume game", func():
   var latest = SaveGame.read()
   if not latest.is_empty(): launch(latest)).custom_minimum_size.y = 56
  var state = SaveGame.restore(saved.game)
  var age = maxi(0, int(Time.get_unix_time_from_system()) - int(saved.get("saved_at", 0)))
  var saved_life = int(saved.table.get("starting_life", state.starting_life if state.starting_life != (24 if state.players.size() == 2 else 10 * state.players.size()) else 0))
  var resume_label = UIStyle.label(menu, "vs %s (%s) · %s · Turn %d · saved %d min ago" % [saved.table.seat_names[1], BotDifficulty.DISPLAY_NAMES[state.players[1].difficulty], UIStyle.pool_label(state.card_pool) + (" · %d life" % saved_life if saved_life != 0 else ""), state.turn, age / 60], 18)
  resume_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 for action in actions.get_children(): action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var start_button = UIStyle.button(actions, "Start Game  →", start)
 start_button.custom_minimum_size.y = 58
 start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 UIStyle.primary(start_button)
 var help_row = HBoxContainer.new()
 menu.add_child(help_row)
 UIStyle.button(help_row, "Rules", rules)
 UIStyle.button(help_row, "Report a bug", func(): load("res://scripts/ui/bug_report.gd").open())
 var switches = HBoxContainer.new()
 menu.add_child(switches)
 var auto_end = CheckButton.new()
 auto_end.text = "Auto-end turn"
 auto_end.button_pressed = Sfx.auto_end_turn
 switches.add_child(auto_end)
 auto_end.toggled.connect(func(enabled): Sfx.auto_end_turn = enabled; Sfx.save())
 var confirmation = CheckButton.new()
 confirmation.text = "Confirm end turn"
 confirmation.button_pressed = Sfx.confirm_end_turn
 switches.add_child(confirmation)
 confirmation.toggled.connect(func(enabled): Sfx.confirm_end_turn = enabled; Sfx.save())
 var sound = CheckButton.new()
 sound.text = "Sound enabled"
 sound.button_pressed = not Sfx.muted
 switches.add_child(sound)
 sound.toggled.connect(func(enabled): Sfx.muted = not enabled; Sfx.save())
 var effects = CheckButton.new()
 effects.text = "Visual effects"
 effects.button_pressed = Sfx.visual_effects
 switches.add_child(effects)
 effects.toggled.connect(func(enabled): Sfx.visual_effects = enabled; Sfx.save(); get_tree().reload_current_scene())
 var volume = HSlider.new()
 volume.max_value = 1.0
 volume.step = 0.01
 volume.value = Sfx.volume
 volume.tooltip_text = "Sound volume"
 var volume_row = HBoxContainer.new()
 menu.add_child(volume_row)
 UIStyle.label(volume_row, "Volume")
 volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 volume_row.add_child(volume)
 var percentage = UIStyle.label(volume_row, "%d%%" % roundi(Sfx.volume * 100))
 percentage.custom_minimum_size.x = 60
 volume.value_changed.connect(func(value):
  Sfx.volume = value
  percentage.text = "%d%%" % roundi(value * 100)
  Sfx.save())
 UIStyle.button(menu, "Quit", func(): get_tree().quit()).visible = not UIStyle.is_web()
func launch(resume: Dictionary = {}):
 var table = load("res://scenes/table.tscn").instantiate()
 table.resume_data = resume
 table.player_count = count.get_selected_id()
 table.difficulty = difficulty.selected
 table.card_pool = Sfx.card_pool
 table.starting_life = Sfx.starting_life
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func rules():
 if is_instance_valid(rules_overlay): return
 rules_overlay = RulesPage.open(self)

func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST: go_back()
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"): go_back(); get_viewport().set_input_as_handled()
func go_back():
 if is_instance_valid(rules_overlay): rules_overlay.queue_free()
 else: get_tree().quit()

func refresh_avatar():
 var replacement = UIStyle.avatar(Sfx.hero_id)
 avatar_preview.get_child(0).texture = replacement.get_child(0).texture
 replacement.free()
func select_hero(id: String):
 Sfx.hero_id = id
 Sfx.handle = str(CardDB.cards[id].name)
 handle_input.text = Sfx.handle
 Sfx.save()
 refresh_avatar()
func pick_hero():
 if is_instance_valid(rules_overlay): return
 var overlay = PanelContainer.new()
 rules_overlay = overlay
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.label(box, "Pick a Hero", 26)
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 box.add_child(scroll)
 TouchInput.register_scroll(scroll)
 var grid = GridContainer.new()
 grid.columns = 6
 scroll.add_child(grid)
 for id in UIStyle.heroes():
  var button = UIStyle.button(grid, str(CardDB.cards[id].name), func(): select_hero(id); overlay.queue_free())
  var path = "res://assets/cards/" + id + ".jpg"
  if hero_icons.has(path): button.icon = hero_icons[path]
  elif path in loading_icons: picker_buttons[path] = button
  else: button.icon = load(path)
  button.expand_icon = true
  button.custom_minimum_size = Vector2(170, 260)
  button.clip_text = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  button.add_theme_constant_override("icon_max_width", 160)
 UIStyle.button(box, "Back", overlay.queue_free)
 UIStyle.dialog(overlay, Vector2(1100, 900))

func _process(_delta):
 for i in range(loading_icons.size() - 1, -1, -1):
  var path = loading_icons[i]
  var status = ResourceLoader.load_threaded_get_status(path)
  if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
  loading_icons.remove_at(i)
  if status != ResourceLoader.THREAD_LOAD_LOADED: continue
  hero_icons[path] = ResourceLoader.load_threaded_get(path)
  if picker_buttons.has(path) and is_instance_valid(picker_buttons[path]): picker_buttons[path].icon = hero_icons[path]
  picker_buttons.erase(path)
func start():
 if SaveGame.read().is_empty(): launch(); return
 if await confirm("Start a new game? Your saved game will be replaced.", "Yes, new game", "Keep my save"):
  SaveGame.remove()
  launch()
signal confirm_answered(value: bool)
## A themed yes/no dialog with finger-sized buttons; Back/Escape answers no (it closes like the rules page).
func confirm(prompt: String, yes_text: String, no_text: String) -> bool:
 if is_instance_valid(rules_overlay): return false
 var overlay = UIStyle.panel()
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation", 14)
 overlay.add_child(box)
 var text = UIStyle.label(box, prompt, 22)
 text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 text.custom_minimum_size.x = 560
 var yes = UIStyle.button(box, yes_text, func(): confirm_answered.emit(true))
 UIStyle.primary(yes)
 var no = UIStyle.button(box, no_text, func(): confirm_answered.emit(false))
 for b in [yes, no]: b.custom_minimum_size.y = 56
 UIStyle.dialog(overlay, Vector2(600, 210))
 rules_overlay = overlay
 overlay.tree_exiting.connect(func(): confirm_answered.emit(false), CONNECT_ONE_SHOT)
 var answer: bool = await confirm_answered
 if is_instance_valid(overlay):
  rules_overlay = null
  overlay.queue_free()
 return answer
