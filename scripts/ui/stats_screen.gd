extends Control
var experimental_view = false
var store
var content: VBoxContainer
var confirmation: ConfirmationDialog
static func open(parent: Node):
 var screen = load("res://scripts/ui/stats_screen.gd").new()
 parent.add_child(screen)
 return screen
func _ready():
 name = "LifetimeStats"
 z_index = 100
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 UIStyle.apply(self)
 UIStyle.background(self)
 store = load("res://scripts/ui/lifetime_stats.gd").new()
 var margin = MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
 add_child(margin)
 var layout = VBoxContainer.new()
 margin.add_child(layout)
 UIStyle.label(layout, "Lifetime stats", 36)
 UIStyle.label(layout, "Stats are stored on this device only.", 22)
 var tabs = HBoxContainer.new()
 layout.add_child(tabs)
 UIStyle.button(tabs, "Lifetime", func(): experimental_view = false; refresh())
 UIStyle.button(tabs, "Experimental decks", func(): experimental_view = true; refresh())
 var scroll = ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation", 18)
 scroll.add_child(content)
 var row = HBoxContainer.new()
 layout.add_child(row)
 UIStyle.button(row, "Reset stats", confirm_reset)
 UIStyle.button(row, "Close", queue_free)
 confirmation = ConfirmationDialog.new()
 confirmation.title = "Reset stats"
 confirmation.dialog_text = "This deletes your stats on this device. It cannot be undone."
 confirmation.confirmed.connect(func(): store.reset(); refresh())
 add_child(confirmation)
 refresh()
 UIStyle.touch_fit(self)
func confirm_reset():
 confirmation.popup_centered(Vector2i(740, 260))
 UIStyle.touch_fit(confirmation)
func line(text: String, parent: Node = content, size: int = 24, color: Color = UIStyle.TEXT) -> Label:
 var label = UIStyle.label(parent, text, size)
 # Grid cells size to their text; wrapping there would break them into one letter per line.
 if not parent is GridContainer: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_color_override("font_color", color)
 return label
## A titled, framed block. Returns the box to fill.
func section(parent: Node, title: String) -> VBoxContainer:
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var style = UIStyle.box(UIStyle.PANEL, Color(UIStyle.CYAN, 0.35), 0)
 style.set_content_margin_all(16)
 panel.add_theme_stylebox_override("panel", style)
 parent.add_child(panel)
 var box = VBoxContainer.new()
 box.add_theme_constant_override("separation", 8)
 panel.add_child(box)
 line("// " + title.to_upper(), box, 20, UIStyle.CYAN)
 return box
func tile(parent: Node, value: String, caption: String):
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var style = UIStyle.box(Color(UIStyle.CYAN, 0.07), Color(UIStyle.CYAN, 0.45), 6)
 style.set_content_margin_all(14)
 panel.add_theme_stylebox_override("panel", style)
 parent.add_child(panel)
 var box = VBoxContainer.new()
 panel.add_child(box)
 line(value, box, 48, UIStyle.GREEN).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 line(caption, box, 20, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
## Games / wins / losses rows; rows with no games are left out.
func record_table(parent: Node, rows: Array):
 var grid = GridContainer.new()
 grid.columns = 5
 grid.add_theme_constant_override("h_separation", 28)
 parent.add_child(grid)
 for title in ["", "Games", "Wins", "Losses", "Win rate"]: line(title, grid, 20, UIStyle.MUTED)
 for row in rows:
  var b = row[1]
  if b.games == 0: continue
  line(row[0], grid)
  for value in [b.games, b.wins, b.games - b.wins, "%d%%" % roundi(100.0 * b.wins / b.games)]: line(str(value), grid)
func feature(parent: Node, caption: String, id: String, fallback: String):
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.alignment = BoxContainer.ALIGNMENT_BEGIN
 parent.add_child(box)
 line(caption, box, 20, UIStyle.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if CardDB.cards.has(id):
  var picture = UIStyle.picture(CardDB.image_path(id), Vector2(170, 232))
  picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
  box.add_child(picture)
 line(str(CardDB.cards[id].name) if CardDB.cards.has(id) else fallback, box).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
func refresh():
 for child in content.get_children(): content.remove_child(child); child.queue_free()
 if experimental_view:
  refresh_experimental()
  return
 var d = store.data
 if d.games == 0:
  line("No finished games yet. Play a game and your stats will show up here.")
  return
 line("%d %s played since %s · last game %s" % [d.games, "game" if d.games == 1 else "games", d.first_date, d.last_date], content, 22, UIStyle.MUTED)
 var tiles = HBoxContainer.new()
 tiles.add_theme_constant_override("separation", 14)
 content.add_child(tiles)
 tile(tiles, str(d.games), "GAMES")
 tile(tiles, str(d.wins), "WINS")
 tile(tiles, "%d%%" % roundi(store.win_rate()), "WIN RATE")
 tile(tiles, str(d.best_streak), "BEST STREAK")
 tile(tiles, "%dh %02dm" % [d.play_time / 3600, (d.play_time / 60) % 60], "TIME PLAYED")
 var columns = HBoxContainer.new()
 columns.add_theme_constant_override("separation", 18)
 content.add_child(columns)
 var left = VBoxContainer.new()
 left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 left.add_theme_constant_override("separation", 18)
 columns.add_child(left)
 var right = VBoxContainer.new()
 right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 right.add_theme_constant_override("separation", 18)
 columns.add_child(right)
 var names = {"local": "Against bots", "online_humans": "Online, against players", "online_bots": "Online, against bots"}
 record_table(section(left, "Your record"), ["local", "online_humans", "online_bots"].map(func(mode): return [names[mode], d.modes.get(mode, store.bucket())]))
 var levels = d.difficulties.keys()
 levels.sort()
 if not levels.is_empty(): record_table(section(left, "By toughest bot faced"), levels.map(func(id): return [BotDifficulty.DISPLAY_NAMES[int(id)], d.difficulties[id]]))
 var sets = d.sets.keys()
 sets.sort()
 record_table(section(left, "By card set"), sets.map(func(id): return [UIStyle.pool_label(id), d.sets[id]]))
 var counts = d.players.keys()
 counts.sort()
 record_table(section(left, "By table size"), counts.map(func(id): return ["%s players" % id, d.players[id]]))
 var cards = HBoxContainer.new()
 cards.add_theme_constant_override("separation", 12)
 section(right, "Your cards").add_child(cards)
 feature(cards, "Favourite Hero", store.favourite_hero(), "No Hero")
 feature(cards, "Signature card", store.top("stars"), "—")
 feature(cards, "Most bought", store.top("bought"), "—")
 var records = section(right, "Records")
 line("Biggest hit: %d  (%s)" % [d.biggest_hit, d.biggest_hit_date], records)
 line("Most damage in one game: %d" % d.most_damage, records)
 if d.wins > 0:
  line("Fastest win: %d turns as %s  (%s)" % [d.fastest_win, CardDB.get_card(d.fastest_hero).get("name", "no Hero"), d.fastest_date], records)
  line("Average turns per win: %.1f" % store.average_win_turns(), records)
 line("Longest game: %d turns" % d.longest_game, records)
 var totals = GridContainer.new()
 totals.columns = 2
 totals.add_theme_constant_override("h_separation", 28)
 section(right, "Totals").add_child(totals)
 for k in store.TOTALS:
  if k in ["win_turns", "play_time"]: continue
  line(k.replace("_", " ").capitalize(), totals, 24, UIStyle.MUTED)
  line(str(d[k]), totals)
 var share = section(content, "Share your record")
 var sharing = load("res://scripts/ui/result_share.gd").new()
 share.add_child(sharing)
 sharing.install(share, store.share_details(Sfx.handle))
 UIStyle.touch_fit(content)
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"):
  if confirmation.visible: confirmation.hide()
  else: queue_free()
  get_viewport().set_input_as_handled()
func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST: queue_free()

func refresh_experimental():
 var d = store.experimental()
 line("Experimental decks · offline games")
 if d.games == 0:
  line("No finished custom-deck games yet.")
  return
 line("%d games · %d wins · %d losses · %d%% win rate" % [d.games, d.wins, d.losses, roundi(100.0 * d.wins / d.games)])
 var levels = d.difficulties.keys()
 levels.sort()
 record_table(section(content, "By difficulty"), levels.map(func(id): return [BotDifficulty.DISPLAY_NAMES[int(id)], d.difficulties[id]]))
 var names = d.decks.keys()
 names.sort()
 record_table(section(content, "By deck name"), names.map(func(id): return [id, d.decks[id]]))
