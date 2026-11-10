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
 UIStyle.button(menu, "Quit", func(): get_tree().quit())
func start():
 var table = load("res://scenes/table.tscn").instantiate()
 table.player_count = count.get_selected_id()
 table.difficulty = difficulty.selected
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func rules():
 var popup = Window.new()
 popup.title = "Original rules • Front / Back"
 popup.size = Vector2i(1050, 900)
 popup.transient = true
 popup.exclusive = true
 add_child(popup)
 var box = VBoxContainer.new()
 box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 popup.add_child(box)
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 box.add_child(scroll)
 var picture = UIStyle.picture("res://assets/rules/front.jpg", Vector2(1000, 1370))
 scroll.add_child(picture)
 var buttons = HBoxContainer.new()
 box.add_child(buttons)
 for side in ["front", "back"]:
  UIStyle.button(buttons, side.capitalize(), func(): picture.texture = load("res://assets/rules/" + side + ".jpg"); scroll.scroll_vertical = 0)
 UIStyle.button(buttons, "Close", popup.queue_free)
 popup.close_requested.connect(popup.queue_free)
 popup.popup_centered()
