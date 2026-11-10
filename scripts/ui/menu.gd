extends Control
const PLAYER_COUNTS = [2] # Add 3 and 4 here to enable additional seats.
var difficulty: OptionButton
var count: OptionButton
func _ready():
 UIStyle.apply(self)
 var bg = ColorRect.new()
 bg.color = Color("080f15")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var row = HBoxContainer.new()
 row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 row.position = Vector2(-620, -410)
 row.size = Vector2(1240, 820)
 row.add_theme_constant_override("separation", 100)
 add_child(row)
 row.add_child(UIStyle.picture(UIStyle.BACK, Vector2(520, 720)))
 var menu = VBoxContainer.new()
 menu.custom_minimum_size.x = 570
 menu.add_theme_constant_override("separation", 24)
 row.add_child(menu)
 UIStyle.label(menu, "PhreakNIC CCG", 48)
 var credit = UIStyle.label(menu, "Original FOTTR TCG created by 5ud0, bitwize & crook3dfingers (FOTTR)", 18)
 credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var version = UIStyle.label(self, "v" + str(ProjectSettings.get_setting("application/config/version", "")), 16)
 version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 version.position -= Vector2(110, 40)
 UIStyle.label(menu, "> CONNECT / SHUFFLE / HACK", 22)
 UIStyle.label(menu, "Opponent difficulty")
 difficulty = OptionButton.new()
 for name in BotDifficulty.DISPLAY_NAMES: difficulty.add_item(name)
 menu.add_child(difficulty)
 var flavor = UIStyle.label(menu, "")
 var descriptions = ["Runs downloaded scripts. Occasionally dangerous.", "Knows the network. Finds the weak points.", "Owns the box before you log in."]
 difficulty.item_selected.connect(func(i): flavor.text = descriptions[i])
 flavor.text = descriptions[0]
 UIStyle.label(menu, "Players")
 count = OptionButton.new()
 for n in [2, 3, 4]:
  count.add_item(str(n) + (" — coming soon" if n not in PLAYER_COUNTS else ""), n)
  count.set_item_disabled(n - 2, n not in PLAYER_COUNTS)
 menu.add_child(count)
 UIStyle.button(menu, "Start Game", start)
 UIStyle.button(menu, "Rules", rules)
 var sound = CheckButton.new()
 sound.text = "Sound enabled"
 sound.button_pressed = not Sfx.muted
 menu.add_child(sound)
 sound.toggled.connect(func(enabled): Sfx.muted = not enabled; Sfx.save())
 var volume = HSlider.new()
 volume.max_value = 1.0
 volume.step = 0.01
 volume.value = Sfx.volume
 volume.tooltip_text = "Sound volume"
 menu.add_child(volume)
 volume.value_changed.connect(func(value): Sfx.volume = value; Sfx.save())
 UIStyle.button(menu, "Quit", func(): get_tree().quit())
func start():
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = count.get_selected_id()
 table.difficulty = difficulty.selected
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func rules():
 var overlay = PanelContainer.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 var text = RichTextLabel.new()
 text.bbcode_enabled = true
 text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 text.add_theme_color_override("default_color", Color("a8e6ad"))
 text.text = UIStyle.rules_bbcode(FileAccess.get_file_as_string("res://data/rules.txt"))
 box.add_child(text)
 UIStyle.button(box, "Back", overlay.queue_free)
