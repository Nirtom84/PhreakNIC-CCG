extends VBoxContainer
var remaining = 0.0
var limit = 1.0
var warned = false
var local = true
var active = false
var kind = "turn"
var text: Label
var bar: ProgressBar
var phase = "normal"
func _ready():
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 text = UIStyle.label(self, "", 22)
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bar = ProgressBar.new()
 bar.custom_minimum_size = Vector2(300, 10)
 bar.show_percentage = false
 bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(bar)
 hide()
func configure(seconds: float, duration: float, timer_kind: String, own = true):
 if not active or kind != timer_kind or seconds > remaining + 10: warned = false
 active = true
 remaining = maxf(0, seconds)
 limit = maxf(1, duration)
 local = own
 kind = timer_kind
 show()
 update_display()
func clear():
 active = false
 warned = false
 hide()
func _process(delta):
 if not active: return
 remaining = maxf(0, remaining - delta)
 update_display()
func update_display():
 var seconds = ceili(remaining)
 phase = "red" if seconds <= 10 else ("amber" if seconds <= 30 else "normal")
 var color = UIStyle.RED if phase == "red" else (UIStyle.AMBER if phase == "amber" else UIStyle.CYAN)
 text.text = ("Auto-answer" if kind == "prompt" else "Bot takeover") + " in %ds" % seconds if local else "idle %d:%02d" % [seconds / 60, seconds % 60]
 text.add_theme_color_override("font_color", color)
 bar.visible = local
 bar.max_value = limit
 bar.value = remaining
 bar.add_theme_stylebox_override("fill", UIStyle.box(color, color, 0))
 if local and seconds <= 10 and seconds > 0 and not warned:
  warned = true
  Sfx.play("warning")
