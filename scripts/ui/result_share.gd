extends Node
const SITE = "https://phreaknic-ccg.net"
var png = PackedByteArray()
var data: Dictionary = {}
var status: Label
var saved_path = ""
var open_button: Button
static func compose_url(platform: String, text: String) -> String:
 match platform:
  "X": return "https://x.com/intent/post?text=" + text.uri_encode()
  "Bluesky": return "https://bsky.app/intent/compose?text=" + text.uri_encode()
  "Reddit": return "https://www.reddit.com/submit?title=" + text.uri_encode() + "&url=" + SITE.uri_encode()
  "Facebook": return "https://www.facebook.com/sharer/sharer.php?u=" + SITE.uri_encode()
 return ""
static func copy_text(d: Dictionary) -> String:
 if d.get("kind") == "stats":
  return "My PhreakNIC CCG record: %d wins in %d games (%s), best streak %d, favourite Hero %s. %s" % [d.wins, d.games, d.rate, d.best_streak, d.hero_name, SITE]
 var opponents = d.opponents.size()
 var outcome = "beat" if d.victory else "played against"
 var level = " on " + d.difficulty if d.difficulty != "" else ""
 return "I %s %d %s%s in %d turns as %s in PhreakNIC CCG v%s — %d damage dealt. %s" % [outcome, opponents, "bots" if d.all_bots else "opponents", level, d.turns, d.hero_name, d.version, d.damage, SITE]
static func filename(date: Dictionary, kind = "match") -> String:
 if kind == "stats": return "phreaknic-ccg-stats-%04d%02d%02d-%02d%02d%02d.png" % [date.year, date.month, date.day, date.hour, date.minute, date.second]
 return "phreaknic-ccg-%04d%02d%02d-%02d%02d%02d.png" % [date.year, date.month, date.day, date.hour, date.minute, date.second]
static func card_label(parent: Control, text: String, rect: Rect2, font_size = 26, color = UIStyle.TEXT):
 var label = UIStyle.label(parent, text, font_size)
 label.position = rect.position
 label.size = rect.size
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_color_override("font_color", color)
 return label
static func build_card(d: Dictionary) -> SubViewport:
 var viewport = SubViewport.new()
 viewport.name = "ShareCard"
 viewport.size = Vector2i(1200, 630)
 viewport.disable_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 var canvas = Control.new()
 canvas.size = Vector2(1200, 630)
 viewport.add_child(canvas)
 var theme = Theme.new()
 theme.default_font = load("res://assets/fonts/JetBrainsMonoNerdFontMono-Regular.ttf")
 theme.default_font_size = 24
 theme.set_color("font_color", "Label", UIStyle.TEXT)
 canvas.theme = theme
 var bg = ColorRect.new()
 bg.color = UIStyle.BACKGROUND
 bg.size = canvas.size
 canvas.add_child(bg)
 var frame = Panel.new()
 frame.position = Vector2(22, 22)
 frame.size = Vector2(1156, 586)
 frame.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BACKGROUND, UIStyle.CYAN, 0))
 canvas.add_child(frame)
 # Faint grid, then: title and date, the result, the Hero card, who it was against,
 # five stat tiles and the most-played card. Every string here is public match data.
 for i in range(1, 12):
  var line = ColorRect.new()
  line.color = Color(UIStyle.CYAN, 0.05)
  line.position = Vector2(22 + i * 96.3, 22)
  line.size = Vector2(1, 586)
  canvas.add_child(line)
 card_label(canvas, "FOTTR TCG // PHREAKNIC CCG", Rect2(48, 40, 700, 40), 26, UIStyle.CYAN)
 card_label(canvas, d.date + " · v" + d.version, Rect2(752, 42, 400, 36), 22, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 if d.get("kind") == "stats":
  build_stats(canvas, d)
  return viewport
 card_label(canvas, d.headline, Rect2(48, 78, 860, 96), 72, UIStyle.GREEN if d.victory else UIStyle.RED).autowrap_mode = TextServer.AUTOWRAP_OFF
 var avatar_id = UIStyle.seat_avatar(d.handle, d.hero, false, -1)
 var hero = UIStyle.picture(CardDB.image_path(avatar_id), Vector2(205, 280)) if CardDB.cards.has(avatar_id) else UIStyle.avatar(avatar_id, 205)
 hero.position = Vector2(48, 190)
 hero.size = Vector2(205, 280)
 canvas.add_child(hero)
 card_label(canvas, d.handle, Rect2(285, 186, 640, 52), 40)
 var versus = "vs " + ", ".join(d.opponents)
 if d.hero_name not in ["", "–", "-"] and d.hero_name.to_lower() != d.handle.to_lower(): versus = "as " + d.hero_name + "\n" + versus
 card_label(canvas, versus, Rect2(285, 242, 640, 150), 24, UIStyle.MUTED)
 var tiles = [[d.life, "LIFE LEFT"], [d.turns, "TURNS"], [d.damage, "DAMAGE DEALT"], [d.bought, "CARDS BOUGHT"], [d.biggest, "BIGGEST HIT"]]
 for i in tiles.size():
  var tile = Panel.new()
  tile.position = Vector2(285 + i * 175, 410)
  tile.size = Vector2(163, 110)
  tile.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.CYAN, 0.07), Color(UIStyle.CYAN, 0.45), 6))
  canvas.add_child(tile)
  card_label(tile, str(tiles[i][0]), Rect2(0, 6, 163, 62), 46, UIStyle.GREEN).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  card_label(tile, tiles[i][1], Rect2(0, 72, 163, 28), 17, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if d.most_played != "" and d.most_played != "hidden":
  card_label(canvas, "STAR CARD", Rect2(940, 114, 212, 30), 20, UIStyle.CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  var image = UIStyle.picture(CardDB.image_path(d.most_played), Vector2(150, 205))
  image.position = Vector2(1002, 148)
  image.size = Vector2(150, 205)
  canvas.add_child(image)
  card_label(canvas, d.most_played_name, Rect2(900, 358, 252, 44), 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 card_label(canvas, "phreaknic-ccg.net", Rect2(48, 548, 500, 40), 30, UIStyle.CYAN)
 card_label(canvas, UIStyle.pool_label(d.pool, d.get("custom_deck", {})), Rect2(552, 540 if d.pool == "custom" else 554, 600, 70 if d.pool == "custom" else 34), 18 if d.pool == "custom" else 22, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 return viewport
static func render_card(owner: Node, d: Dictionary) -> Image:
 var viewport = build_card(d)
 if DisplayServer.get_name() == "headless":
  viewport.free()
  return null
 owner.add_child(viewport)
 viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 var image = viewport.get_texture().get_image()
 viewport.queue_free()
 return image
func install(parent: Control, details: Dictionary):
 data = details
 UIStyle.label(parent, "Share", 26)
 var row = HFlowContainer.new()
 row.add_theme_constant_override("h_separation", 12)
 row.add_theme_constant_override("v_separation", 12)
 parent.add_child(row)
 var save_button = UIStyle.button(row, "Save image", save_image)
 save_button.disabled = true
 var share_button = UIStyle.button(row, "Share…", web_share)
 share_button.visible = false
 UIStyle.button(row, "Copy text", func(): DisplayServer.clipboard_set(copy_text(data)); status.text = "Text copied")
 for platform in ["X", "Bluesky", "Reddit", "Facebook"]:
  UIStyle.button(row, platform, func(): OS.shell_open(compose_url(platform, copy_text(data))))
 var discord = UIStyle.button(row, "Discord", func():
  var saved = save_image()
  DisplayServer.clipboard_set(copy_text(data))
  if saved: status.text = "Image saved and text copied — paste or drop it into Discord")
 discord.disabled = true
 var hint = UIStyle.label(parent, "Attach the saved image to your post", 22)
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status = UIStyle.label(parent, "Preparing image…", 22)
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 open_button = UIStyle.button(parent, "Open folder", func(): OS.shell_show_in_file_manager(saved_path))
 open_button.visible = false
 UIStyle.touch_fit(row)
 var image = await render_card(self, data)
 if not is_instance_valid(parent): return
 if image == null:
  status.text = "Image rendering unavailable"
  return
 png = image.save_png_to_buffer()
 save_button.disabled = png.is_empty()
 discord.disabled = png.is_empty()
 status.text = ""
 if OS.has_feature("web"):
  # tools/web/share.js (same-origin, loaded by the page) does the browser work, so the site CSP can forbid eval.
  var bridge = JavaScriptBridge.get_interface("pnShare")
  share_button.visible = bridge != null and bool(bridge.prepare(Marshalls.raw_to_base64(png), filename(Time.get_datetime_dict_from_system(), data.get("kind", "match"))))
func web_share():
 if not OS.has_feature("web") or png.is_empty(): return
 # No await before share: browser transient user activation must still be live.
 var bridge = JavaScriptBridge.get_interface("pnShare")
 if bridge != null: bridge.share(copy_text(data))
func save_image() -> bool:
 if png.is_empty():
  status.text = "Image rendering unavailable"
  return false
 var name = filename(Time.get_datetime_dict_from_system(), data.get("kind", "match"))
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(png, name, "image/png")
  status.text = "Image downloaded"
  return true
 var directories: Array = [OS.get_system_dir(OS.SYSTEM_DIR_PICTURES, OS.has_feature("android"))]
 if OS.has_feature("android"): directories.append(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS, true))
 directories.append(ProjectSettings.globalize_path("user://"))
 for directory in directories:
  if directory == "": continue
  var path = str(directory).path_join(name)
  var file = FileAccess.open(path, FileAccess.WRITE)
  if file == null: continue
  file.store_buffer(png)
  file.flush()
  var ok = file.get_error() == OK
  file.close()
  if not ok: continue
  saved_path = path
  status.text = "Saved: " + path
  open_button.visible = not OS.has_feature("android")
  return true
 status.text = "Could not save image"
 return false

static func build_stats(canvas: Control, d: Dictionary):
 card_label(canvas, d.headline, Rect2(48, 86, 860, 80), 52, UIStyle.GREEN)
 var avatar_id = UIStyle.seat_avatar(d.handle, d.hero, false, -1)
 var hero = UIStyle.picture(CardDB.image_path(avatar_id), Vector2(205, 280)) if CardDB.originals.has(avatar_id) else UIStyle.avatar(avatar_id, 205)
 hero.position = Vector2(48, 190)
 hero.size = Vector2(205, 280)
 canvas.add_child(hero)
 var modes = []
 for mode in ["local", "online_humans", "online_bots"]:
  var b = d.modes.get(mode, {})
  if b.get("games", 0): modes.append("%s %d–%d" % [{"local": "vs bots", "online_humans": "online", "online_bots": "online bots"}[mode], b.wins, b.losses])
 card_label(canvas, " · ".join(modes), Rect2(285, 186, 640, 100), 24, UIStyle.MUTED)
 card_label(canvas, "Playing since %s · %dh %dm played" % [d.first_date, d.play_time / 3600, (d.play_time / 60) % 60], Rect2(285, 300, 640, 80), 22, UIStyle.MUTED)
 var tiles = [[d.games, "GAMES"], [d.wins, "WINS"], [d.rate, "WIN RATE"], [d.best_streak, "BEST STREAK"], [d.biggest_hit, "BIGGEST HIT"]]
 for i in tiles.size():
  var tile = Panel.new()
  tile.position = Vector2(285 + i * 175, 410)
  tile.size = Vector2(163, 110)
  tile.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.CYAN, 0.07), Color(UIStyle.CYAN, 0.45), 6))
  canvas.add_child(tile)
  card_label(tile, str(tiles[i][0]), Rect2(0, 6, 163, 62), 46, UIStyle.GREEN).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  card_label(tile, tiles[i][1], Rect2(0, 72, 163, 28), 17, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if CardDB.originals.has(d.signature):
  card_label(canvas, "SIGNATURE CARD", Rect2(940, 114, 212, 30), 20, UIStyle.CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  var picture = UIStyle.picture(CardDB.image_path(d.signature), Vector2(150, 205))
  picture.position = Vector2(1002, 148)
  picture.size = Vector2(150, 205)
  canvas.add_child(picture)
  card_label(canvas, CardDB.get_card(d.signature).name, Rect2(900, 358, 252, 44), 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 card_label(canvas, "phreaknic-ccg.net", Rect2(48, 548, 500, 40), 30, UIStyle.CYAN)
 card_label(canvas, "LIFETIME RECORD", Rect2(752, 554, 400, 34), 22, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
