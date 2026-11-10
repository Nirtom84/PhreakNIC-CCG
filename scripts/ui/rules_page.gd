class_name RulesPage
extends RefCounted
static func open(parent: Control) -> Control:
 var overlay = UIStyle.panel("// FIELD MANUAL")
 overlay.add_to_group("touch_modal")
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 parent.add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.dialog(overlay, Vector2(1100, 900))
 var text = RichTextLabel.new()
 text.bbcode_enabled = true
 text.size_flags_vertical = Control.SIZE_EXPAND_FILL
 text.add_theme_color_override("default_color", UIStyle.TEXT)
 text.text = UIStyle.rules_bbcode(FileAccess.get_file_as_string("res://data/rules.txt"))
 box.add_child(text)
 TouchInput.register_scroll(text)
 UIStyle.button(box, "Back", overlay.queue_free).custom_minimum_size.y = 56
 return overlay
