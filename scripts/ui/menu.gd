extends Control
const PLAYER_COUNTS = [2] # Add 3 and 4 here to enable additional seats.
var rules_overlay: Control
var difficulty: OptionButton
var handle_input: LineEdit
var avatar_preview: Control
var count: OptionButton
func _ready():
 get_tree().auto_accept_quit = true
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
 menu.add_theme_constant_override("separation", 10)
 var menu_scroll = ScrollContainer.new()
 menu_scroll.custom_minimum_size = Vector2(920, 930)
 menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 row.add_child(menu_scroll)
 menu_scroll.add_child(menu)
 TouchInput.register_scroll(menu_scroll)
 var title = UIStyle.label(menu, "PhreakNIC", 82)
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
 UIStyle.label(menu, "// PLAYERS", 18)
 count = OptionButton.new()
 count.visible = false
 for n in [2, 3, 4]: count.add_item(str(n), n)
 menu.add_child(count)
 var seats = HBoxContainer.new()
 menu.add_child(seats)
 for n in [2, 3, 4]:
  var seat = UIStyle.button(seats, str(n) + (" / SOON" if n > 2 else " / CONNECTED"), func(): count.select(n - 2))
  seat.disabled = n > 2
  seat.custom_minimum_size.x = 280
 var saved = SaveGame.read()
 if not saved.is_empty():
  UIStyle.button(menu, "Resume game", func():
   var latest = SaveGame.read()
   if not latest.is_empty(): launch(latest)).custom_minimum_size.y = 56
  var state = SaveGame.restore(saved.game)
  var age = maxi(0, int(Time.get_unix_time_from_system()) - int(saved.get("saved_at", 0)))
  UIStyle.label(menu, "vs %s (%s) · Turn %d · saved %d min ago" % [saved.table.seat_names[1], BotDifficulty.DISPLAY_NAMES[state.players[1].difficulty], state.turn, age / 60], 18)
 var start_button = UIStyle.button(menu, "Start Game  →", start)
 start_button.custom_minimum_size.y = 58
 UIStyle.primary(start_button)
 UIStyle.button(menu, "Rules", rules)
 var switches = HBoxContainer.new()
 menu.add_child(switches)
 var auto_end = CheckButton.new()
 auto_end.text = "Auto-end turn"
 auto_end.button_pressed = Sfx.auto_end_turn
 switches.add_child(auto_end)
 auto_end.toggled.connect(func(enabled): Sfx.auto_end_turn = enabled; Sfx.save())
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
 UIStyle.button(menu, "Quit", func(): get_tree().quit())
func launch(resume: Dictionary = {}):
 var table = load("res://scenes/table.tscn").instantiate()
 table.resume_data = resume
 table.player_count = count.get_selected_id()
 table.difficulty = difficulty.selected
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
  button.icon = load("res://assets/cards/" + id + ".jpg")
  button.expand_icon = true
  button.custom_minimum_size = Vector2(170, 260)
  button.clip_text = true
  button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
  button.add_theme_constant_override("icon_max_width", 160)
 UIStyle.button(box, "Back", overlay.queue_free)
 UIStyle.dialog(overlay, Vector2(1100, 900))

func start():
 if SaveGame.read().is_empty(): launch(); return
 var dialog = ConfirmationDialog.new()
 dialog.dialog_text = "Start a new game? Your saved game will be replaced."
 dialog.ok_button_text = "Yes"
 dialog.cancel_button_text = "No"
 add_child(dialog)
 dialog.confirmed.connect(func(): SaveGame.remove(); launch())
 dialog.canceled.connect(dialog.queue_free)
 dialog.popup_centered(Vector2i(650, 200))
