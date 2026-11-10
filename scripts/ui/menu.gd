extends Control
const PLAYER_COUNTS = [2] # Add 3 and 4 here to enable additional seats.
var difficulty: OptionButton
var count: OptionButton
func _ready():
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
 row.add_child(menu)
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
 var handle_input = LineEdit.new()
 handle_input.placeholder_text = "You"
 handle_input.max_length = 16
 handle_input.text = Sfx.handle
 menu.add_child(handle_input)
 handle_input.text_changed.connect(func(value):
  var caret = handle_input.caret_column
  var filtered = value.replace("[", "").replace("]", "")
  if filtered != value:
   handle_input.text = filtered
   handle_input.caret_column = mini(caret, filtered.length())
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
 var start_button = UIStyle.button(menu, "Start Game  →", start)
 start_button.custom_minimum_size.y = 58
 UIStyle.primary(start_button)
 UIStyle.button(menu, "Rules", rules)
 var sound = CheckButton.new()
 sound.text = "Sound enabled"
 sound.button_pressed = not Sfx.muted
 menu.add_child(sound)
 sound.toggled.connect(func(enabled): Sfx.muted = not enabled; Sfx.save())
 var effects = CheckButton.new()
 effects.text = "Visual effects"
 effects.button_pressed = Sfx.visual_effects
 menu.add_child(effects)
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
func start():
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = count.get_selected_id()
 table.difficulty = difficulty.selected
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func rules():
 var overlay = UIStyle.panel("// FIELD MANUAL")
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 var padding = UIStyle.dialog_box()
 padding.content_margin_left = maxf(42, (size.x - 1100) / 2)
 padding.content_margin_right = padding.content_margin_left
 overlay.add_theme_stylebox_override("panel", padding)
 var text = RichTextLabel.new()
 text.bbcode_enabled = true
 text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 text.add_theme_color_override("default_color", UIStyle.TEXT)
 text.text = UIStyle.rules_bbcode(FileAccess.get_file_as_string("res://data/rules.txt"))
 box.add_child(text)
 UIStyle.button(box, "Back", overlay.queue_free)
