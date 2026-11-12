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
static var compact_override = null
static func compact() -> bool:
 if compact_override != null: return bool(compact_override)
 var layout = OnlineAPI.settings().get_value("ui", "layout", "auto")
 if layout != "auto": return layout == "compact"
 if OS.has_feature("android") or OS.has_feature("ios"): return true
 if OS.has_feature("web"):
  var window = JavaScriptBridge.get_interface("window")
  return bool(window.matchMedia("(pointer: coarse)").matches) and minf(float(window.screen.width), float(window.screen.height)) < 900
 return false
static func layout_setting(parent: Control):
 var picker = OptionButton.new()
 for title in ["Layout: Auto", "Layout: Desktop", "Layout: Phone"]: picker.add_item(title)
 picker.selected = maxi(0, ["auto", "desktop", "compact"].find(OnlineAPI.settings().get_value("ui", "layout", "auto")))
 parent.add_child(picker)
 picker.item_selected.connect(func(index):
  var config = OnlineAPI.settings()
  config.set_value("ui", "layout", ["auto", "desktop", "compact"][index])
  config.save("user://settings.cfg"))
static func touch_fit_id(id: int):
 var node = instance_from_id(id)
 if is_instance_valid(node): touch_fit(node)
static func touch_fit(node: Node):
 if not compact(): return
 if node is Button:
  node.custom_minimum_size.y = maxf(72, node.custom_minimum_size.y)
  node.add_theme_font_size_override("font_size", 22)
 if node is LineEdit or node is Slider: node.custom_minimum_size.y = maxf(64, node.custom_minimum_size.y)
 if node is Label: node.add_theme_font_size_override("font_size", maxi(22, node.get_theme_font_size("font_size")))
 if node is RichTextLabel:
  for kind in ["normal_font_size", "bold_font_size", "italics_font_size"]: node.add_theme_font_size_override(kind, maxi(22, node.get_theme_font_size(kind)))
 if node is BoxContainer: node.add_theme_constant_override("separation", 12)
 for child in node.get_children(): touch_fit(child)
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
 var t = animation(node, true).set_loops()
 t.tween_property(node, "self_modulate", tint, UIStyle.motion(0.8))
 t.tween_property(node, "self_modulate", Color.WHITE, UIStyle.motion(0.8))
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
static func avatar_id(handle: String, hero_id: String, catalog = null) -> String:
 var book = CardDB if catalog == null else catalog
 var matched = book.card_id_for_name(handle)
 return hero_id if matched.is_empty() else matched
static func avatar(card_id: String, width: int = 64) -> Control:
 var frame = PanelContainer.new()
 var border = box(BACKGROUND, CYAN, 0)
 border.set_content_margin_all(2)
 frame.add_theme_stylebox_override("panel", border)
 var image = picture("res://assets/icon/icon.png", Vector2(width, width))
 if CardDB.cards.has(card_id):
  var atlas = AtlasTexture.new()
  atlas.atlas = load(CardDB.image_path(card_id))
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
 var t = animation(label, true).set_loops()
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
 theme.default_font_size = 22 if compact() else 18
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
 if compact(): theme.set_constant("v_separation", "PopupMenu", 48)
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
 var added = func(node):
  if compact() and control.is_ancestor_of(node): touch_fit_id.call_deferred(node.get_instance_id())
 control.get_tree().node_added.connect(added)
 control.tree_exiting.connect(func():
  if control.get_tree().node_added.is_connected(added): control.get_tree().node_added.disconnect(added), CONNECT_ONE_SHOT)
 touch_fit_id.call_deferred(control.get_instance_id())
static func label(parent: Node, text: String, size: int = 18) -> Label:
 var node = Label.new()
 node.text = text
 node.add_theme_font_size_override("font_size", maxi(22, size) if compact() else size)
 if size >= 22: node.add_theme_font_override("font", heading())
 parent.add_child(node)
 return node
static func button(parent: Node, text: String, action: Callable) -> Button:
 var node = Button.new()
 node.text = text
 node.pressed.connect(func(): Sfx.play("button"))
 node.pressed.connect(action)
 parent.add_child(node)
 if compact():
  node.custom_minimum_size.y = 72
  node.add_theme_font_size_override("font_size", 22)
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
 if pool == "2026mog": return "Mog Variant · PhreakNIC 27"
 return "Base Set · PhreakNIC 26" if pool == "2025" else "Base Set + Expansion 1 · PhreakNIC 27"

static func motion(seconds: float) -> float:
 return seconds if Sfx.visual_effects else 0.0
static func animation(node: Node, looping: bool = false) -> Tween:
 var tween = node.create_tween()
 var finish = func(enabled):
  if enabled or not tween.is_valid(): return
  if looping:
   tween.kill()
   if node is CanvasItem: node.modulate = Color.WHITE; node.self_modulate = Color.WHITE
   if node.get_parent() is Container: node.get_parent().queue_sort()
   if node is Label: node.add_theme_constant_override("shadow_offset_x", 0)
  else: tween.custom_step(100000.0)
 Sfx.visuals_changed.connect(finish)
 node.tree_exiting.connect(func():
  if Sfx.visuals_changed.is_connected(finish): Sfx.visuals_changed.disconnect(finish), CONNECT_ONE_SHOT)
 return tween
static func music_controls(parent: Control):
 var row = HBoxContainer.new()
 parent.add_child(row)
 var toggle = CheckButton.new()
 toggle.text = "Music"
 toggle.button_pressed = not Sfx.music_muted
 row.add_child(toggle)
 toggle.toggled.connect(func(enabled): Sfx.music_muted = not enabled; Sfx.save())
 var slider = HSlider.new()
 slider.custom_minimum_size = Vector2(140, 40)
 slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 slider.max_value = 1.0
 slider.step = 0.01
 slider.value = Sfx.music_volume
 row.add_child(slider)
 # Follow the drag live, but write the settings file once, on release.
 slider.value_changed.connect(func(value): Sfx.music_volume = value; Sfx.apply_music())
 slider.drag_ended.connect(func(_changed): Sfx.save())
