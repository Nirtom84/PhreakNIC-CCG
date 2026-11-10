extends CanvasLayer
# Above inspection layers and dialogs; scene ownership handles cleanup.
var cover: ColorRect
func _ready():
 layer = 1000
 cover = ColorRect.new()
 cover.name = "RotateCover"
 cover.color = UIStyle.BACKGROUND
 cover.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(cover)
 cover.add_to_group("rotate_cover")
 var center = CenterContainer.new()
 center.mouse_filter = Control.MOUSE_FILTER_IGNORE
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 cover.add_child(center)
 var lines = VBoxContainer.new()
 lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
 center.add_child(lines)
 var title = UIStyle.label(lines, "Turn your phone sideways", 90)
 title.add_theme_color_override("font_color", UIStyle.CYAN)
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var subtitle = UIStyle.label(lines, "PhreakNIC plays in landscape", 56)
 subtitle.add_theme_color_override("font_color", UIStyle.AMBER)
 subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 get_window().size_changed.connect(update_size)
 update_size()
func update_size():
 var dimensions = get_window().size
 cover.size = get_viewport().get_visible_rect().size
 cover.visible = UIStyle.is_web() and dimensions.y > dimensions.x
 if cover.visible:
  var focus = get_viewport().gui_get_focus_owner()
  if focus != null: focus.release_focus()
func _input(_event):
 if cover.visible: get_viewport().set_input_as_handled()
