class_name UIStyle
extends RefCounted
const BACK = "res://assets/cards/phreaknic_fottr_tcg_card_back.jpg"
static func apply(control: Control):
 var theme = Theme.new()
 theme.default_font = SystemFont.new()
 theme.default_font.font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
 theme.default_font_size = 18
 for kind in ["Button", "PanelContainer", "PopupPanel", "LineEdit"]:
  var box = StyleBoxFlat.new()
  box.bg_color = Color("111c20")
  box.border_color = Color("677247")
  box.set_border_width_all(2)
  box.set_content_margin_all(9)
  theme.set_stylebox("normal" if kind == "Button" else "panel", kind, box)
 theme.set_color("font_color", "Label", Color("a8e6ad"))
 theme.set_color("font_color", "Button", Color("e9c778"))
 control.theme = theme
static func label(parent: Node, text: String, size: int = 18) -> Label:
 var node = Label.new()
 node.text = text
 node.add_theme_font_size_override("font_size", size)
 parent.add_child(node)
 return node
static func button(parent: Node, text: String, action: Callable) -> Button:
 var node = Button.new()
 node.text = text
 node.pressed.connect(action)
 parent.add_child(node)
 return node
static func picture(path: String, dimensions: Vector2) -> TextureRect:
 var node = TextureRect.new()
 node.texture = load(path)
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.custom_minimum_size = dimensions
 return node

static func icon_text(text: String) -> String:
 return text.replace("{H}", "[img=22x22]res://assets/icons/hack.png[/img]").replace("{D}", "[img=22x22]res://assets/icons/damage.png[/img]")
static func rich_label(parent: Node, text: String, font_size: int = 18) -> RichTextLabel:
 var node = RichTextLabel.new()
 node.bbcode_enabled = true
 node.fit_content = true
 node.add_theme_font_size_override("normal_font_size", font_size)
 node.text = icon_text(text)
 parent.add_child(node)
 return node
