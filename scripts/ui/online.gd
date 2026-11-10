extends Control
var api
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
func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 UIStyle.apply(self)
 UIStyle.background(self)
 if api == null:
  api = OnlineAPI.new()
  add_child(api)
 var margin = MarginContainer.new()
 add_child(margin)
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 30)
 var scroll = ScrollContainer.new()
 margin.add_child(scroll)
 TouchInput.register_scroll(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(content)
 message = UIStyle.label(content, "", 24)
 browser()
func clear_content():
 for child in content.get_children():
  if child != message:
   content.remove_child(child)
   child.queue_free()
func browser():
 in_lobby = false
 clear_content()
 UIStyle.label(content, "ONLINE", 40)
 UIStyle.button(content, "Back to menu", back)
 if not OnlineAPI.remembered().is_empty(): UIStyle.button(content, "Resume online game", func(): enter(OnlineAPI.remembered()))
 var columns = HBoxContainer.new()
 columns.add_theme_constant_override("separation", 28)
 content.add_child(columns)
 var create = VBoxContainer.new()
 create.custom_minimum_size.x = 620
 columns.add_child(create)
 UIStyle.label(create, "Create game", 28)
 public_choice = CheckButton.new()
 public_choice.text = "Public (listed in Open games)"
 public_choice.button_pressed = true
 create.add_child(public_choice)
 seat_count = option(create, ["2 seats", "3 seats", "4 seats"], default_count - 2)
 seat_types.clear()
 for i in 3:
  var row = HBoxContainer.new()
  create.add_child(row)
  UIStyle.label(row, "Seat %d" % (i + 2), 20)
  var choice = option(row, ["Open (human)"] + Array(BotDifficulty.DISPLAY_NAMES).map(func(n): return "Bot · " + n), default_difficulty + 1)
  seat_types.append(choice)
  row.visible = i < default_count - 1
 seat_count.item_selected.connect(func(n):
  for i in 3: seat_types[i].get_parent().visible = i <= n)
 pool = option(create, ["Base Set · PhreakNIC 26", "Base Set + Expansion 1 · PhreakNIC 27"], 0 if Sfx.card_pool == "2025" else 1)
 life = option(create, ["Standard", "20", "30", "40"], [0,20,30,40].find(Sfx.starting_life))
 UIStyle.button(create, "Create game", create_game)
 UIStyle.label(create, "Join by code", 28)
 code_input = LineEdit.new()
 code_input.max_length = 4
 code_input.placeholder_text = "Game code"
 code_input.text = initial_code
 create.add_child(code_input)
 code_input.text_changed.connect(func(value):
  var clean = ""
  for c in value.to_upper():
   if c in OnlineAPI.ALPHABET: clean += c
  code_input.text = clean
  code_input.caret_column = clean.length())
 UIStyle.button(create, "Join", func(): join(code_input.text))
 var open = VBoxContainer.new()
 open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 columns.add_child(open)
 UIStyle.label(open, "Open games", 28)
 rooms_box = VBoxContainer.new()
 open.add_child(rooms_box)
 refresh_rooms()
 if not initial_code.is_empty():
  var code = initial_code
  initial_code = ""
  join(code)
func option(parent, labels: Array, selected: int = 0) -> OptionButton:
 var choice = OptionButton.new()
 for label in labels: choice.add_item(str(label))
 choice.select(maxi(0, selected))
 choice.custom_minimum_size.y = 56
 parent.add_child(choice)
 return choice
func identity() -> Dictionary:
 return {"name": Sfx.handle.left(16) if not Sfx.handle.is_empty() else "You", "hero": Sfx.hero_id, "version": str(ProjectSettings.get_setting("application/config/version", ""))}
func create_game():
 if submitting: return
 submitting = true
 message.text = "Creating game…"
 var body = identity()
 body.public = public_choice.button_pressed
 body.card_pool = "2025" if pool.selected == 0 else "2026"
 body.starting_life = [0,20,30,40][life.selected]
 body.seats = [{"bot": false, "difficulty": 0}]
 for i in seat_count.selected + 1:
  var selected = seat_types[i].selected
  body.seats.append({"bot": selected > 0, "difficulty": maxi(0, selected - 1)})
 var result = await api.request(HTTPClient.METHOD_POST, "/rooms", body)
 handle_result(result, "")
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
  if result.data.get("error") == "version": UIStyle.button(content, "Get the latest release", func(): OS.shell_open("https://github.com/Nirtom84/PhreakNIC-CCG/releases/latest"))
func refresh_rooms():
 if listing or in_lobby: return
 listing = true
 var result = await api.request(HTTPClient.METHOD_GET, "/rooms")
 listing = false
 if in_lobby or not is_instance_valid(rooms_box): return
 for child in rooms_box.get_children():
  rooms_box.remove_child(child)
  child.queue_free()
 if result.status != 200:
  message.text = OnlineAPI.error_text(result.status, result.data)
  return
 for room in result.data.get("rooms", []):
  var box = VBoxContainer.new()
  rooms_box.add_child(box)
  var seats = []
  for seat in room.seats: seats.append("Bot · " + BotDifficulty.DISPLAY_NAMES[int(seat.difficulty)] if seat.bot else (seat.name if not seat.name.is_empty() else "Open human"))
  UIStyle.label(box, "%s · %s\n%s\n%s · %s life · %d open" % [room.host, room.code, ", ".join(seats), "Base Set · PhreakNIC 26" if room.card_pool == "2025" else "Base Set + Expansion 1 · PhreakNIC 27", "Standard" if room.starting_life == 0 else str(room.starting_life), room.open_seats], 20).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  UIStyle.button(box, "Join", join.bind(room.code))
func enter(data: Dictionary):
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
 session.client.error.connect(func(reason): message.text = reason)
 session.start(data)
func lobby(room: Dictionary):
 clear_content()
 UIStyle.label(content, room.code, 64)
 var link = "https://phreaknic-ccg.net/join/" + room.code
 UIStyle.label(content, link, 24)
 UIStyle.button(content, "Copy invite link", func():
  DisplayServer.clipboard_set(link)
  if OS.has_feature("web"): JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(" + JSON.stringify(link) + ")"))
 var host = int(room.host_seat) == int(session.credential.seat)
 for i in room.seats.size():
  var seat = room.seats[i]
  var row = HBoxContainer.new()
  content.add_child(row)
  row.add_child(UIStyle.avatar(str(seat.get("hero", ""))))
  UIStyle.label(row, ("● " if seat.get("connected", false) else "○ ") + (seat.name if not seat.name.is_empty() else "Open (human)") + (" · " + BotDifficulty.DISPLAY_NAMES[int(seat.difficulty)] if seat.bot else "") + (" · you" if i == int(session.credential.seat) else ""), 24)
  if host and i > 0 and not room.started: UIStyle.button(row, "Remove seat", func(): session.lobby("remove_seat", {"seat": i}))
 if room.started:
  UIStyle.label(content, "Starting the game server…", 28)
 elif host:
  var bot = option(content, Array(BotDifficulty.DISPLAY_NAMES), 1)
  UIStyle.button(content, "Add bot", func(): session.lobby("add_bot", {"difficulty": bot.selected})).disabled = room.seats.size() >= 4
  var publicity = CheckButton.new()
  publicity.text = "Public game"
  publicity.button_pressed = room.public
  content.add_child(publicity)
  publicity.toggled.connect(func(value): session.lobby("settings", {"public": value}))
  var sets = option(content, ["Base Set · PhreakNIC 26", "Base Set + Expansion 1 · PhreakNIC 27"], 0 if room.card_pool == "2025" else 1)
  sets.item_selected.connect(func(n): session.lobby("settings", {"card_pool": "2025" if n == 0 else "2026"}))
  var lives = option(content, ["Standard", "20", "30", "40"], [0,20,30,40].find(int(room.starting_life)))
  lives.item_selected.connect(func(n): session.lobby("settings", {"starting_life": [0,20,30,40][n]}))
  UIStyle.button(content, "Start", func(): session.lobby("start")).disabled = room.seats.any(func(s): return not s.bot and s.name.is_empty())
 else: UIStyle.label(content, "Waiting for the host…", 28)
 UIStyle.button(content, "Leave", leave_lobby)
func leave_lobby():
 if not session.room.get("started", false):
  if int(session.credential.seat) != int(session.room.get("host_seat", 0)): session.lobby("leave")
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
 if in_lobby: return
 refresh_elapsed += delta
 if refresh_elapsed >= 5:
  refresh_elapsed = 0
  refresh_rooms()

func _exit_tree():
 if not launched and session != null: session.disconnect_game()

func _notification(what):
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if in_lobby: leave_lobby()
  else: back()
func _unhandled_key_input(event):
 if event.is_action_pressed("ui_cancel"):
  if in_lobby: leave_lobby()
  else: back()
  get_viewport().set_input_as_handled()
