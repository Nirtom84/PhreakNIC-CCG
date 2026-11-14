extends "res://tests/custom_selfplay.gd"
func _initialize():
 OS.set_environment("CB_BENCH", "1")
 super._initialize()
