extends Control
var api
var handle_input: LineEdit
var avatar_preview: Control
var hero_picker
var ban_picker
var create_banned: Array = []
var bans_button: Button
var hero_overlay: Control
var session: OnlineSession
var content: VBoxContainer
var message: Label
var rooms_box: VBoxContainer
var code_input: LineEdit
var seat_count: OptionButton
var seat_types: Array = []
var public_choice: CheckButton
var pool: OptionButton
var life: OptionButton
var refresh_elapsed = 0.0
var listing = false
var submitting = false
var in_lobby = false
var launched = false
var default_count = 2
var default_difficulty = 0
var initial_code = ""
var updated: Label
var updated_at = 0.0
var toast: Label
var starting_indicator: Label
var initial_status = ""
var kick_overlay: Control
const SETS = ["Base Set · PhreakNIC 26", "Base Set + Expansion 1 · PhreakNIC 27", "Base Set + Expansion 1 · Mog Variant"]
var pending_join = ""
var join_button: Button
var join_anyway: Button
var identity_panel: Control
var identity_prompted = false
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 UIStyle.apply(self)
 UIStyle.background(self)
 hero_picker = load("res://scripts/ui/hero_picker.gd").new()
 add_child(hero_picker)
 ban_picker = load("res://scripts/ui/ban_picker.gd").new()
 add_child(ban_picker)
 if api == null:
  api = OnlineAPI.new()
  add_child(api)
 var margin = MarginContainer.new()
 add_child(margin)
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 30)
 content = VBoxContainer.new()
 content.add_theme_constant_override("separation", 16)
 margin.add_child(content)
 var banner = UIStyle.panel()
 content.add_child(banner)
 message = UIStyle.label(banner, "Connect with friends · Public games and private invites", 20)
 message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 toast = UIStyle.label(self, "Copied!", 24)
 toast.position = Vector2(50, 32)
 toast.z_index = 50
 toast.add_theme_color_override("font_color", UIStyle.GREEN)
 toast.hide()
 browser()
 if not initial_status.is_empty(): message.text = initial_status
func clear_content():
 for child in content.get_children():
  if child != message.get_parent():
   content.remove_child(child)
   child.queue_free()
func browser():
 in_lobby = false
 pending_join = ""
 clear_content()
 var header = HBoxContainer.new()
 content.add_child(header)
 UIStyle.label(header, "// PLAY ONLINE", 40).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 action(header, "Back to menu", back)
 if not OnlineAPI.remembered().is_empty(): UIStyle.primary(action(content, "Resume online game", func(): enter(OnlineAPI.remembered())))
 var columns = HBoxContainer.new()
 columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
 columns.add_theme_constant_override("separation", 24)
 content.add_child(columns)
 var left = VBoxContainer.new()
 left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 left.size_flags_stretch_ratio = 1.1
 left.add_theme_constant_override("separation", 18)
 columns.add_child(left)
 var you = section(left, "// YOU")
 identity_panel = you.get_parent()
 var identity_row = HBoxContainer.new()
 you.add_child(identity_row)
 avatar_preview = UIStyle.avatar(Sfx.hero_id)
 identity_row.add_child(avatar_preview)
 handle_input = LineEdit.new()
 handle_input.max_length = 16
 handle_input.placeholder_text = "You"
 handle_input.text = Sfx.handle
 handle_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 identity_row.add_child(handle_input)
 action(identity_row, "Pick a Hero", pick_hero)
 handle_input.text_changed.connect(func(value):
  Sfx.handle = Sfx.clean_handle(value)
  Sfx.hero_id = ""
  handle_input.text = value.replace("[", "").replace("]", "")
  handle_input.caret_column = handle_input.text.length()
  refresh_avatar()
  refresh_join_button()
  Sfx.save())
 handle_input.focus_exited.connect(func(): handle_input.text = Sfx.handle)
 var create = section(left, "// CREATE GAME", true)
 public_choice = CheckButton.new()
 public_choice.text = "Public game · switch off for invite only"
 public_choice.custom_minimum_size.y = 56
 public_choice.button_pressed = true
 create.add_child(public_choice)
 seat_count = option(create, ["2 seats", "3 seats", "4 seats"], default_count - 2)
 seat_types.clear()
 for i in 3:
  var row = HBoxContainer.new()
  create.add_child(row)
  UIStyle.label(row, "Seat %d" % (i + 2), 20)
  var choice = option(row, ["Open seat"] + Array(BotDifficulty.DISPLAY_NAMES).map(func(n): return "Bot · " + n), default_difficulty + 1)
  seat_types.append(choice)
  row.visible = i < default_count - 1
 seat_count.item_selected.connect(func(n):
  for i in 3: seat_types[i].get_parent().visible = i <= n)
 UIStyle.label(create, "Card set", 18)
 pool = option(create, SETS, CardDB.POOLS.find(Sfx.card_pool))
 create_banned = Sfx.banned_cards(CardDB.POOLS[pool.selected])
 bans_button = action(create, "Banned cards: %d" % create_banned.size(), func(): ban_picker.open_bans(CardDB.POOLS[pool.selected], create_banned, func(ids): create_banned = ids; Sfx.set_banned(CardDB.POOLS[pool.selected], ids); Sfx.save(); bans_button.text = "Banned cards: %d" % ids.size()))
 pool.item_selected.connect(func(_n): CardDB.select_pool(CardDB.POOLS[pool.selected]); create_banned = Sfx.banned_cards(CardDB.POOLS[pool.selected]); bans_button.text = "Banned cards: %d" % create_banned.size())
 UIStyle.label(create, "Starting life", 18)
 life = option(create, ["Standard", "20", "30", "40"], [0,20,30,40].find(Sfx.starting_life))
 UIStyle.primary(action(create, "Create game", create_game))
 var join_box = section(left, "// JOIN BY CODE")
 var join_row = HBoxContainer.new()
 join_box.add_child(join_row)
 code_input = LineEdit.new()
 code_input.max_length = 4
 code_input.placeholder_text = "CODE"
 code_input.custom_minimum_size = Vector2(260, 64)
 code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var code_font = FontVariation.new()
 code_font.base_font = load("res://assets/fonts/JetBrainsMonoNerdFontMono-Regular.ttf")
 code_font.spacing_glyph = 12
 code_input.add_theme_font_override("font", code_font)
 code_input.add_theme_font_size_override("font_size", 32)
 code_input.text = initial_code
 join_row.add_child(code_input)
 code_input.text_changed.connect(func(value):
  var clean = ""
  for c in value.to_upper():
   if c in OnlineAPI.ALPHABET: clean += c
  code_input.text = clean
  code_input.caret_column = clean.length())
 action(join_row, "Join", func(): request_join(code_input.text))
 var open = section(columns, "// OPEN GAMES", true)
 rooms_box = VBoxContainer.new()
 rooms_box.add_theme_constant_override("separation", 16)
 open.add_child(rooms_box)
 updated = UIStyle.label(open, "Updating…", 16)
 updated.add_theme_color_override("font_color", UIStyle.MUTED)
 refresh_rooms()
 if not initial_code.is_empty():
  var code = initial_code
  initial_code = ""
  request_join(code, true)
func action(parent, text: String, callback: Callable) -> Button:
 var button = UIStyle.button(parent, text, callback)
 button.custom_minimum_size.y = 56
 return button
func section(parent, title: String, scrolling: bool = false) -> VBoxContainer:
 var panel = UIStyle.panel(title)
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 if scrolling: panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
 parent.add_child(panel)
 var box = VBoxContainer.new()
 box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 box.add_theme_constant_override("separation", 10)
 if scrolling:
  var scroll = ScrollContainer.new()
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  panel.add_child(scroll)
  TouchInput.register_scroll(scroll)
  scroll.add_child(box)
 else: panel.add_child(box)
 return box
func option(parent, labels: Array, selected: int = 0) -> OptionButton:
 var choice = OptionButton.new()
 for label in labels: choice.add_item(str(label))
 choice.select(maxi(0, selected))
 choice.custom_minimum_size.y = 56
 choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(choice)
 return choice
func identity() -> Dictionary:
 return {"name": Sfx.handle.left(16) if not Sfx.handle.is_empty() else "You", "hero": Sfx.hero_id, "version": str(ProjectSettings.get_setting("application/config/version", "")), "platform": OS.get_name().to_lower()}
func create_game():
 if submitting: return
 submitting = true
 message.text = "Creating game…"
 var body = identity()
 body.public = public_choice.button_pressed
 body.card_pool = CardDB.POOLS[pool.selected]
 body.banned = create_banned.duplicate()
 body.starting_life = [0,20,30,40][life.selected]
 body.seats = [{"bot": false, "difficulty": 0}]
 for i in seat_count.selected + 1:
  var selected = seat_types[i].selected
  body.seats.append({"bot": selected > 0, "difficulty": maxi(0, selected - 1)})
 var result = await api.request(HTTPClient.METHOD_POST, "/rooms", body)
 handle_result(result, "")
func request_join(code: String, shared_link: bool = false):
 code = code.to_upper()
 if not OnlineAPI.valid_code(code): message.text = "Enter a four-character game code."; return
 if shared_link or (not identity_prompted and Sfx.hero_id.is_empty() and Sfx.handle.strip_edges().to_lower() in ["", "you"]):
  identity_prompted = true
  pending_join = code
  # Move the existing YOU panel so edits and avatar stay visible before joining.
  identity_panel.get_parent().remove_child(identity_panel)
  clear_content()
  UIStyle.label(content, "Join game " + code, 40)
  content.add_child(identity_panel)
  UIStyle.label(content, "Set a handle or pick a Hero before joining.", 24)
  join_button = action(content, "", func(): join(pending_join))
  UIStyle.primary(join_button)
  join_anyway = action(content, "Join anyway", func(): join(pending_join))
  refresh_join_button()
  action(content, "Back to online games", browser)
 else: join(code)
func refresh_join_button():
 if is_instance_valid(join_button):
  var who = identity()
  join_button.text = "Join as " + str(who.name)
  # With the default identity, offer only "Join anyway" so the two buttons never do the same thing.
  var default_identity = who.name.to_lower() == "you" and who.hero.is_empty()
  join_button.visible = not default_identity
  if is_instance_valid(join_anyway): join_anyway.visible = default_identity
func join(code: String):
 if submitting: return
 code = code.to_upper()
 if not OnlineAPI.valid_code(code): message.text = "Enter a four-character game code."; return
 submitting = true
 message.text = "Joining game…"
 var result = await api.request(HTTPClient.METHOD_POST, "/rooms/" + code + "/join", identity())
 handle_result(result, code)
func handle_result(result: Dictionary, code: String):
 submitting = false
 if result.status >= 200 and result.status < 300:
  var data = result.data.duplicate()
  data.code = data.get("code", code)
  data.server = OnlineAPI.server()
  enter(data)
 else:
  message.text = OnlineAPI.error_text(result.status, result.data)
  if result.data.get("error") == "version": action(content, "Get the latest release", func(): OS.shell_open("https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest"))
func refresh_rooms():
 if listing or in_lobby or not pending_join.is_empty(): return
 listing = true
 var result = await api.request(HTTPClient.METHOD_GET, "/rooms")
 listing = false
 if in_lobby or not pending_join.is_empty() or not is_instance_valid(rooms_box): return
 for child in rooms_box.get_children():
  rooms_box.remove_child(child)
  child.queue_free()
 if result.status != 200:
  message.text = OnlineAPI.error_text(result.status, result.data)
  return
 updated_at = Time.get_ticks_msec() / 1000.0
 if result.data.get("rooms", []).is_empty():
  UIStyle.label(rooms_box, "No open games right now. Create one!", 22).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 for room in result.data.get("rooms", []):
  var box = section(rooms_box, "// " + str(room.code))
  var row = HBoxContainer.new()
  box.add_child(row)
  row.add_child(UIStyle.avatar(str(room.seats[0].get("hero", ""))))
  UIStyle.label(row, str(room.host), 26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
  action(row, "Join", request_join.bind(room.code))
  UIStyle.label(box, "%d cards banned" % int(room.get("banned_count", 0)), 18)
  var seats = []
  for seat in room.seats:
   seats.append("◈ " + BotDifficulty.DISPLAY_NAMES[int(seat.difficulty)] if seat.bot else ("● " + seat.name if not seat.name.is_empty() else "○ Open seat"))
  UIStyle.label(box, " · ".join(seats), 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  UIStyle.label(box, UIStyle.pool_label(room.card_pool) + " · " + ("Standard" if room.starting_life == 0 else str(room.starting_life)) + " life", 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
func enter(data: Dictionary):
 while hero_picker.close_top(): pass
 while ban_picker.close_top(): pass
 hero_overlay = null
 message.text = "Connecting…"
 in_lobby = true
 clear_content()
 UIStyle.label(content, "Connecting to room…", 32)
 if session == null:
  session = OnlineSession.new()
  add_child(session)
 session.room_changed.connect(lobby)
 session.status_changed.connect(func(text): message.text = text)
 session.client.view_changed.connect(launch_table)
 session.client.error.connect(func(reason):
  if reason not in ["room_version", "version", "busy", "maintenance", "rate_limit"]: message.text = reason)
 session.removed.connect(func(text):
  session.queue_free()
  session = null
  browser()
  message.text = text)
 session.start(data)
func lobby(room: Dictionary):
 if ban_picker.selected_pool != room.card_pool:
  while ban_picker.close_top(): pass
 clear_content()
 starting_indicator = null
 var columns = HBoxContainer.new()
 columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
 columns.add_theme_constant_override("separation", 24)
 content.add_child(columns)
 var main = section(columns, "// ROOM", true)
 var code = UIStyle.label(main, room.code, 64)
 code.add_theme_color_override("font_color", UIStyle.CYAN)
 var link = "https://phreaknic-ccg.net/join/" + room.code
 var invite = HBoxContainer.new()
 main.add_child(invite)
 UIStyle.label(invite, link, 20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 action(invite, "Copy invite link", func():
  # On the web this uses navigator.clipboard; no JavaScript eval (the site's CSP forbids it).
  DisplayServer.clipboard_set(link)
  toast.show()
  get_tree().create_timer(2).timeout.connect(func(): if is_instance_valid(toast): toast.hide()))
 UIStyle.label(main, "Share this code with friends", 20)
 var host = int(room.host_seat) == int(session.credential.seat)
 for i in room.seats.size():
  var seat = room.seats[i]
  var card = section(main, "")
  var row = HBoxContainer.new()
  card.add_child(row)
  row.add_child(UIStyle.avatar(str(seat.get("hero", ""))))
  var dot = UIStyle.label(row, "●", 22)
  dot.add_theme_color_override("font_color", UIStyle.GREEN if seat.get("connected", false) or seat.bot else UIStyle.MUTED)
  dot.tooltip_text = "Connected" if seat.get("connected", false) or seat.bot else "Offline"
  var title = "Bot · " + BotDifficulty.DISPLAY_NAMES[int(seat.difficulty)] if seat.bot else (seat.name if not seat.name.is_empty() else "Open seat — waiting…")
  var name_label = UIStyle.label(row, title, 22)
  name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  if i == int(session.credential.seat): UIStyle.label(row, "[you]", 18)
  if i == int(room.host_seat): UIStyle.label(row, "HOST", 18).add_theme_color_override("font_color", UIStyle.AMBER)
  if host and i != int(room.host_seat) and not room.started:
   if not seat.bot and not seat.name.is_empty(): action(row, "Remove", kick_seat.bind(i))
   action(row, "Remove seat", func(): session.lobby("remove_seat", {"seat": i})).disabled = room.seats.size() <= 2
 var settings = section(columns, "// HOST SETTINGS" if host else "// READY ROOM", true)
 settings.get_parent().custom_minimum_size.x = 520
 if room.started:
  starting_indicator = UIStyle.label(settings, "", 26)
  starting_indicator.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 elif host:
  var bot = option(settings, Array(BotDifficulty.DISPLAY_NAMES), 1)
  action(settings, "Add bot", func(): session.lobby("add_bot", {"difficulty": bot.selected})).disabled = room.seats.size() >= 4
  var publicity = CheckButton.new()
  publicity.text = "Public game"
  publicity.custom_minimum_size.y = 56
  publicity.button_pressed = room.public
  settings.add_child(publicity)
  publicity.toggled.connect(func(value): session.lobby("settings", {"public": value}))
  var sets = option(settings, SETS, CardDB.POOLS.find(room.card_pool))
  sets.item_selected.connect(func(n): session.lobby("settings", {"card_pool": CardDB.POOLS[n]}))
  UIStyle.label(settings, "Starting life", 18)
  var lives = option(settings, ["Standard", "20", "30", "40"], [0,20,30,40].find(int(room.starting_life)))
  lives.item_selected.connect(func(n): session.lobby("settings", {"starting_life": [0,20,30,40][n]}))
  var start = action(settings, "Start", func(): session.lobby("start"))
  UIStyle.primary(start)
  start.disabled = room.seats.any(func(seat): return not seat.bot and seat.name.is_empty())
  UIStyle.label(settings, "Fill every open human seat before starting." if start.disabled else "Everyone is ready!", 18).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 else:
  UIStyle.label(settings, "Waiting for " + str(room.seats[int(room.host_seat)].name) + " to start…", 26).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 UIStyle.label(settings, "%d cards banned" % room.get("banned", []).size(), 18)
 action(settings, "Banned cards: %d" % room.get("banned", []).size() if host and not room.started else "View banned cards", func(): ban_picker.open_bans(room.card_pool, room.get("banned", []), func(ids): session.lobby("settings", {"banned": ids}), not host or room.started))
 action(settings, "Close room" if host and not room.started else "Leave", leave_lobby)
func leave_lobby():
 if not session.room.get("started", false):
  if int(session.credential.seat) == int(session.room.get("host_seat", 0)):
   if is_instance_valid(kick_overlay): return
   var overlay = UIStyle.panel()
   kick_overlay = overlay
   overlay.add_to_group("touch_modal")
   add_child(overlay)
   var box = VBoxContainer.new()
   overlay.add_child(box)
   UIStyle.label(box, "This closes the room for everyone.", 26)
   UIStyle.button(box, "Close room", func(): kick_confirmed.emit(true))
   UIStyle.button(box, "Cancel", func(): kick_confirmed.emit(false))
   UIStyle.dialog(overlay, Vector2(640, 210))
   var confirmed = await kick_confirmed
   kick_overlay = null
   overlay.queue_free()
   if not confirmed or session == null: return
  session.lobby("leave")
  # Allow the transport to flush leave before freeing its polling session.
  await get_tree().process_frame
  await get_tree().process_frame
  if session == null: return
  OnlineAPI.remember({})
 session.disconnect_game()
 back()
func launch_table():
 if launched: return
 launched = true
 var table = load("res://scenes/table.tscn").instantiate()
 session.reparent(table)
 table.online_session = session
 get_tree().root.add_child(table)
 get_tree().current_scene = table
 queue_free()
func back(): get_tree().change_scene_to_file("res://scenes/menu.tscn")
func _process(delta):
 if is_instance_valid(starting_indicator):
  starting_indicator.text = ["◐", "◓", "◑", "◒"][int(Time.get_ticks_msec() / 250) % 4] + " Starting the game server… (this can take ~10 s)"
 if in_lobby: return
 if is_instance_valid(updated) and updated_at > 0: updated.text = "updated %ds ago" % int(Time.get_ticks_msec() / 1000.0 - updated_at)
 refresh_elapsed += delta
 if refresh_elapsed >= 5:
  refresh_elapsed = 0
  refresh_rooms()

func _exit_tree():
 if not launched and session != null: session.disconnect_game()

func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if is_instance_valid(kick_overlay):
   kick_confirmed.emit(false)
   return
  if ban_picker.close_top(): return
  if hero_picker.close_top(): return
  if in_lobby: leave_lobby()
  else: back()
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"):
  if is_instance_valid(kick_overlay):
   kick_confirmed.emit(false)
   get_viewport().set_input_as_handled()
   return
  if ban_picker.close_top():
   get_viewport().set_input_as_handled()
   return
  if hero_picker.close_top():
   get_viewport().set_input_as_handled()
   return
  if in_lobby: leave_lobby()
  else: back()
  get_viewport().set_input_as_handled()

func refresh_avatar():
 var replacement = UIStyle.avatar(Sfx.hero_id)
 avatar_preview.get_child(0).texture = replacement.get_child(0).texture
 replacement.free()
func select_hero(id: String):
 if in_lobby: return
 Sfx.hero_id = id
 Sfx.handle = str(CardDB.cards[id].name)
 handle_input.text = Sfx.handle.left(16)
 refresh_avatar()
 refresh_join_button()
 Sfx.save()
func pick_hero():
 if in_lobby or is_instance_valid(hero_overlay): return
 hero_overlay = hero_picker.open(select_hero)

signal kick_confirmed(value)
func kick_seat(seat: int):
 if is_instance_valid(kick_overlay): return
 var overlay = UIStyle.panel()
 kick_overlay = overlay
 overlay.add_to_group("touch_modal")
 add_child(overlay)
 var box = VBoxContainer.new()
 overlay.add_child(box)
 UIStyle.label(box, "Remove this player from the room?", 26)
 UIStyle.button(box, "Remove", func(): kick_confirmed.emit(true))
 UIStyle.button(box, "Cancel", func(): kick_confirmed.emit(false))
 UIStyle.dialog(overlay, Vector2(600, 210))
 var confirmed = await kick_confirmed
 kick_overlay = null
 overlay.queue_free()
 if confirmed and session != null: session.lobby("kick", {"seat": seat})
