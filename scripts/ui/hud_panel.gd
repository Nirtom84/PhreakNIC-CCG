extends PanelContainer
## Static corner geometry redraws only when the panel changes size.
var title: String = ""
func _ready():
 mouse_filter = Control.MOUSE_FILTER_PASS
 resized.connect(queue_redraw)
func _draw():
 var c = UIStyle.CYAN
 c.a = 0.8
 for origin in [Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(1, size.y - 1), size - Vector2.ONE]:
  var dx = 1.0 if origin.x < size.x / 2 else -1.0
  var dy = 1.0 if origin.y < size.y / 2 else -1.0
  draw_line(origin, origin + Vector2(12 * dx, 0), c, 2)
  draw_line(origin, origin + Vector2(0, 12 * dy), c, 2)
 if not title.is_empty():
  var font = UIStyle.heading()
  draw_style_box(UIStyle.box(UIStyle.BACKGROUND, Color.TRANSPARENT, 0), Rect2(18, -10, font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20, 22))
  draw_string(font, Vector2(28, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
