extends Node
# Observe input before Control routing, including emulated mouse events.
var touch_mode: bool = OS.has_feature("mobile")
var cards: Array[Control] = []
var scrollers: Array[Control] = []
var held: Control
var origin: Vector2
var last_position: Vector2
var scrolling: Control
var active: bool = false
var cancelled: bool = false
var serial: int = 0
var screen_gesture: bool = false
var suppress_mouse_release: bool = false
func register_card(control: Control, inspect: Callable):
 control.set_meta("inspect", inspect)
 cards.append(control)
 control.tree_exiting.connect(func(): cards.erase(control))
func register_scroll(control: Control):
 scrollers.append(control)
 control.tree_exiting.connect(func(): scrollers.erase(control))
func contains(control: Control, point: Vector2) -> bool:
 if not control.is_visible_in_tree() or not control.get_global_rect().has_point(point): return false
 var parent = control.get_parent()
 while parent is Control:
  if parent.clip_contents and not parent.get_global_rect().has_point(point): return false
  parent = parent.get_parent()
 return true
# Reset BaseButton's internal press state before release, including toggle buttons.
func reset_button():
 if is_instance_valid(held) and held is BaseButton:
  var was_disabled = held.disabled
  held.disabled = true
  held.disabled = was_disabled
func _input(event):
 if event is InputEventScreenTouch or event is InputEventScreenDrag or ((event is InputEventMouse) and event.device == InputEvent.DEVICE_ID_EMULATION):
  touch_mode = true
 elif event is InputEventMouseMotion and not OS.has_feature("mobile"):
  touch_mode = false
 var screen = event is InputEventScreenTouch or event is InputEventScreenDrag
 # Screen events own the gesture; ignore their duplicate mouse stream.
 if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
  if suppress_mouse_release and event is InputEventMouseButton and not event.pressed:
   suppress_mouse_release = false
   get_viewport().set_input_as_handled()
   return
  if screen_gesture: return
 var down = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
 var up = (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
 if screen and event.index != 0: return
 if down:
  screen_gesture = screen
  suppress_mouse_release = false
  active = true
  cancelled = false
  origin = event.position
  last_position = origin
  held = null
  scrolling = null
  var modals = get_tree().get_nodes_in_group("touch_modal")
  var modal = modals.back() if not modals.is_empty() else null
  for control in cards:
   if (modal == null or modal.is_ancestor_of(control)) and contains(control, origin): held = control
  if screen:
   for control in scrollers:
    if (modal == null or modal.is_ancestor_of(control)) and contains(control, origin): scrolling = control
  serial += 1
  var token = serial
  await get_tree().create_timer(0.45).timeout
  if active and not cancelled and serial == token and is_instance_valid(held):
   cancelled = true
   reset_button()
   held.get_meta("inspect").call()
 elif active and (event is InputEventScreenDrag or event is InputEventMouseMotion):
  if event.position.distance_to(origin) > 24:
   cancelled = true
   reset_button()
  if screen and cancelled and is_instance_valid(scrolling):
   var delta = last_position - event.position
   if scrolling is RichTextLabel:
    scrolling.get_v_scroll_bar().value += delta.y
   elif scrolling is ScrollContainer:
    scrolling.scroll_vertical += roundi(delta.y)
    scrolling.scroll_horizontal += roundi(delta.x)
   get_viewport().set_input_as_handled()
  last_position = event.position
 elif up and active:
  active = false
  if screen:
   suppress_mouse_release = cancelled
   screen_gesture = false
  serial += 1
  if cancelled:
   reset_button()
   # Native scrollers still need the finger release to end their touch tracking.
   # Suppress the paired emulated mouse release instead (above).
   if not screen: get_viewport().set_input_as_handled()
