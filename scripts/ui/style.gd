class_name UIStyle
extends RefCounted
const BACK = "res://assets/cards/phreaknic_fottr_tcg_card_back.jpg"
const BACKGROUND = Color("05090d")
const PANEL = Color(0.031, 0.071, 0.094, 0.82)
const CYAN = Color("29e6ff")
const AMBER = Color("f2c14e")
const RED = Color("ff3b3b")
const GREEN = Color("6dff9a")
const MUTED = Color("9fb3bd")
const TEXT = Color("d9f2ea")
const HUD = preload("res://scripts/ui/hud_panel.gd")
# Null uses the real platform; tests can simulate browser features.
static var web_override = null
static var web_android_override = null
static var web_ios_override = null
static func is_web() -> bool:
 return OS.has_feature("web") if web_override == null else bool(web_override)
static func is_touch_platform() -> bool:
 var android = OS.has_feature("web_android") if web_android_override == null else bool(web_android_override)
 var ios = OS.has_feature("web_ios") if web_ios_override == null else bool(web_ios_override)
 return OS.has_feature("mobile") or (is_web() and (android or ios))
static func rotate_prompt(parent: Control):
 if is_web(): parent.add_child(load("res://scripts/ui/rotate_prompt.gd").new())

static var display_font: FontVariation
static func heading() -> Font:
 if display_font == null:
  display_font = FontVariation.new()
  display_font.base_font = load("res://assets/fonts/NotoSansMono-CondensedBlack.ttf")
  display_font.spacing_glyph = 1
 return display_font
static func box(fill: Color = PANEL, accent: Color = CYAN, glow: int = 8) -> StyleBoxFlat:
 var b = StyleBoxFlat.new()
 b.bg_color = fill
 b.border_color = Color(accent, 0.45)
 b.set_border_width_all(1)
 b.set_corner_radius_all(4)
 b.set_content_margin_all(10)
 b.shadow_color = Color(accent, 0.25)
 b.shadow_size = glow
 return b
static func panel(title: String = "") -> PanelContainer:
 var p = HUD.new()
 p.title = title
 return p
static func background(parent: Control) -> ColorRect:
 var bg = ColorRect.new()
 bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var material = ShaderMaterial.new()
 material.shader = load("res://assets/shaders/network.gdshader")
 material.set_shader_parameter("effects", Sfx.visual_effects)
 bg.material = material
 parent.add_child(bg)
 Sfx.visuals_changed.connect(func(enabled): material.set_shader_parameter("effects", enabled))
 return bg
static func primary(b: Button):
 b.add_theme_stylebox_override("normal", box(AMBER.darkened(0.12), AMBER))
 b.add_theme_stylebox_override("hover", box(AMBER, AMBER, 12))
 b.add_theme_color_override("font_color", BACKGROUND)
 b.add_theme_color_override("font_hover_color", BACKGROUND)
static func pulse(node: Control, tint: Color = Color(1.0, 0.86, 0.62)):
 if not Sfx.visual_effects: return
 var t = node.create_tween().set_loops()
 t.tween_property(node, "self_modulate", tint, 0.8)
 t.tween_property(node, "self_modulate", Color.WHITE, 0.8)
static func dialog(p: PanelContainer, dimensions: Vector2 = Vector2(640, 400)):
 viewport_cover(p)
 var content = p.get_child(0)
 var layout = func():
  var view = p.get_viewport_rect().size
  # Grow to fit the content (e.g. a two-line prompt) instead of letting it spill past the box.
  var extent = dimensions.max(content.get_combined_minimum_size()).min(view - Vector2(80, 80))
  var shade = box(Color(0, 0, 0, 0.7), Color.TRANSPARENT, 0)
  shade.content_margin_left = (view.x - extent.x) / 2
  shade.content_margin_right = shade.content_margin_left
  shade.content_margin_top = (view.y - extent.y) / 2
  shade.content_margin_bottom = shade.content_margin_top
  p.add_theme_stylebox_override("panel", shade)
  # A control never shrinks on its own after its content was briefly too big; snap the backdrop back to the screen.
  p.size = view
 p.get_viewport().size_changed.connect(layout)
 p.tree_exiting.connect(func(): p.get_viewport().size_changed.disconnect(layout), CONNECT_ONE_SHOT)
 content.minimum_size_changed.connect(layout)
 layout.call()
 content.draw.connect(func(): content.draw_style_box(box(), Rect2(Vector2(-20,-20), content.size + Vector2(40,40))))
 content.resized.connect(content.queue_redraw)

const AVATAR_CROP = Rect2(90, 62, 420, 420)
static func avatar(card_id: String, width: int = 64) -> Control:
 var frame = PanelContainer.new()
 var border = box(BACKGROUND, CYAN, 0)
 border.set_content_margin_all(2)
 frame.add_theme_stylebox_override("panel", border)
 var image = picture("res://assets/icon/icon.png", Vector2(width, width))
 if CardDB.cards.has(card_id):
  var atlas = AtlasTexture.new()
  atlas.atlas = load("res://assets/cards/" + card_id + ".jpg")
  atlas.region = AVATAR_CROP
  image.texture = atlas
 frame.add_child(image)
 return frame
static func heroes() -> Array:
 var result: Array = []
 var names: Array = []
 for id in CardDB.cards:
  var card = CardDB.cards[id]
  if not card.get("starter", false) and CardDB.has_subtype(id, "Hero") and card.name not in names:
   names.append(card.name)
   result.append(id)
 result.sort_custom(func(a, b): return str(CardDB.cards[a].name) < str(CardDB.cards[b].name))
 return result
static func viewport_cover(control: Control):
 control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 var fit = func(): control.size = control.get_viewport_rect().size
 control.get_viewport().size_changed.connect(fit)
 control.tree_exiting.connect(func(): control.get_viewport().size_changed.disconnect(fit), CONNECT_ONE_SHOT)
 fit.call()

static func glitch(label: Label):
 if not Sfx.visual_effects: return
 label.add_theme_color_override("font_shadow_color", Color(RED, 0.6))
 var t = label.create_tween().set_loops()
 t.tween_interval(4.0)
 t.tween_callback(func(): label.add_theme_constant_override("shadow_offset_x", -5); label.position.x += 3)
 t.tween_interval(0.05)
 t.tween_callback(func(): label.add_theme_constant_override("shadow_offset_x", 4); label.position.x -= 6)
 t.tween_interval(0.05)
 t.tween_callback(func(): label.add_theme_constant_override("shadow_offset_x", 0); label.position.x += 3)
static func dialog_box() -> StyleBoxFlat:
 var b = box(Color(0.015, 0.035, 0.045, 0.97), CYAN, 12)
 b.set_content_margin_all(42)
 return b
static func apply(control: Control):
 var theme = Theme.new()
 theme.default_font = load("res://assets/fonts/JetBrainsMonoNerdFontMono-Regular.ttf")
 theme.default_font_size = 18
 for kind in ["Label", "RichTextLabel", "LineEdit", "CheckButton", "OptionButton"]:
  theme.set_color("font_color", kind, TEXT)
 theme.set_color("default_color", "RichTextLabel", TEXT)
 theme.set_font("bold_font", "RichTextLabel", load("res://assets/fonts/JetBrainsMonoNerdFontMono-Bold.ttf"))
 theme.set_constant("line_separation", "RichTextLabel", 7)
 for kind in ["PanelContainer", "PopupPanel"]: theme.set_stylebox("panel", kind, box())
 for kind in ["Button", "OptionButton", "CheckButton"]:
  theme.set_font("font", kind, heading())
  theme.set_color("font_color", kind, AMBER)
  theme.set_color("font_hover_color", kind, TEXT)
  theme.set_color("font_pressed_color", kind, TEXT)
  theme.set_color("font_disabled_color", kind, Color(MUTED, 0.4))
  theme.set_stylebox("normal", kind, box(PANEL, AMBER, 0))
  theme.set_stylebox("hover", kind, box(Color("253027"), AMBER, 10))
  theme.set_stylebox("pressed", kind, box(BACKGROUND, CYAN, 2))
  theme.set_stylebox("disabled", kind, box(Color(0.04,0.06,0.07,0.4), Color(MUTED,0.4), 0))
  theme.set_stylebox("focus", kind, box(Color.TRANSPARENT, CYAN, 3))
 theme.set_stylebox("normal", "LineEdit", box(BACKGROUND))
 theme.set_stylebox("focus", "LineEdit", box(BACKGROUND, AMBER))
 theme.set_color("font_placeholder_color", "LineEdit", MUTED)
 theme.set_color("caret_color", "LineEdit", CYAN)
 theme.set_stylebox("panel", "PopupMenu", box(BACKGROUND))
 theme.set_stylebox("hover", "PopupMenu", box(PANEL, AMBER))
 for kind in ["VScrollBar", "HScrollBar", "HSlider"]:
  var track = box(BACKGROUND, Color.TRANSPARENT, 0)
  track.set_content_margin_all(3)
  theme.set_stylebox("scroll", kind, track)
  theme.set_stylebox("slider", kind, track)
  for state in ["grabber", "grabber_highlight", "grabber_pressed", "grabber_area", "grabber_area_highlight"]:
   var handle = box(Color(CYAN,0.55), CYAN, 0)
   handle.set_content_margin_all(3)
   theme.set_stylebox(state, kind, handle)
 for state in ["checked", "checked_disabled"]: theme.set_icon(state, "CheckButton", load("res://assets/ui/toggle_on.svg"))
 for state in ["unchecked", "unchecked_disabled"]: theme.set_icon(state, "CheckButton", load("res://assets/ui/toggle_off.svg"))
 for state in ["grabber", "grabber_highlight", "grabber_disabled"]: theme.set_icon(state, "HSlider", load("res://assets/ui/slider_grip.svg"))
 control.theme = theme
static func label(parent: Node, text: String, size: int = 18) -> Label:
 var node = Label.new()
 node.text = text
 node.add_theme_font_size_override("font_size", size)
 if size >= 22: node.add_theme_font_override("font", heading())
 parent.add_child(node)
 return node
static func button(parent: Node, text: String, action: Callable) -> Button:
 var node = Button.new()
 node.text = text
 node.pressed.connect(func(): Sfx.play("button"))
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

static func rules_bbcode(source: String) -> String:
 var lines = PackedStringArray()
 for line in source.split("\n"):
  if line.begins_with("- "): line = "[indent]• " + line.substr(2) + "[/indent]"
  lines.append(line)
 return icon_text("\n".join(lines).replace("[h1]", "[font=res://assets/fonts/NotoSansMono-CondensedBlack.ttf][font_size=32][color=#29e6ff][b]").replace("[/h1]", "[/b][/color][/font_size][/font]").replace("[h2]", "[font=res://assets/fonts/NotoSansMono-CondensedBlack.ttf][font_size=24][color=#f2c14e][b]").replace("[/h2]", "[/b][/color][/font_size][/font]"))

static func escape_bbcode(text: String) -> String:
 var result = ""
 for character in text:
  result += "[lb]" if character == "[" else ("[rb]" if character == "]" else character)
 return result

static func pool_label(pool: String) -> String:
 return "Base Set · PhreakNIC 26" if pool == "2025" else "Base Set + Expansion 1 · PhreakNIC 27"
