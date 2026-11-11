extends Node
const PRESETS = ["GG", "Nice play", "Oops", "Thinking…", "Hack the planet!", "RIP", "Thanks", "Rickrolled!"]
var table
var popup: PanelContainer
var bubbles: Dictionary = {}
func enabled() -> bool:
 return bool(OnlineAPI.settings().get_value("ui", "emotes", true))
func mute(value: bool):
 var config = OnlineAPI.settings()
 config.set_value("ui", "emotes", not value)
 config.save("user://settings.cfg")
 if value:
  for bubble in bubbles.values(): bubble.queue_free()
  bubbles.clear()
func open():
 if is_instance_valid(popup): close(); return
 popup = UIStyle.panel("// EMOTE")
 popup.z_index = 40
 popup.add_to_group("touch_modal")
 table.add_child(popup)
 var box = VBoxContainer.new()
 popup.add_child(box)
 var grid = GridContainer.new()
 grid.columns = 2
 box.add_child(grid)
 for id in PRESETS.size():
  var button = UIStyle.button(grid, PRESETS[id], func(): send(id); close())
  button.custom_minimum_size.y = 72
 UIStyle.button(box, "Close", close).custom_minimum_size.y = 72
 UIStyle.dialog(popup, Vector2(620, 460))
 UIStyle.touch_fit(popup)
func close():
 if is_instance_valid(popup): popup.queue_free()
 popup = null
func send(id: int):
 if id >= 0 and id < PRESETS.size(): table.online_session.client.send_emote(id)
func receive(data: Dictionary):
 if not enabled() or data.size() != 3 or data.get("type") != "emote" or not data.get("seat") is int or not data.get("id") is int: return
 var seat: int = data.seat
 var id: int = data.id
 if seat < 0 or seat >= table.player_count or id < 0 or id >= PRESETS.size(): return
 table.append_log(table.seat_name(seat) + ": " + PRESETS[id])
 if bubbles.has(seat): bubbles[seat].queue_free()
 var bubble = UIStyle.panel()
 bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bubble.z_index = 35
 table.add_child(bubble)
 var label = UIStyle.label(bubble, PRESETS[id], 22)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bubbles[seat] = bubble
 var tween = UIStyle.animation(bubble)
 tween.tween_interval(3)
 tween.tween_callback(func():
  if bubbles.get(seat) == bubble: bubbles.erase(seat)
  bubble.queue_free())
func _process(_delta):
 for seat in bubbles:
  var anchor = table.life_labels.get(seat)
  if is_instance_valid(anchor): bubbles[seat].position = anchor.global_position - table.global_position + Vector2(20, -60)
