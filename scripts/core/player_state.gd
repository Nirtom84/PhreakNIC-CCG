class_name PlayerState
extends RefCounted
var seat: int
var life: int = 20
var alive: bool = true
var is_bot: bool = true
var difficulty: int = 0
var deck: Array = []
var hand: Array = []
var discard: Array = []
var play_area: Array = []
var reserve: Array = []
var hacking: int = 0
var played: Array = []
var turn_flags: Dictionary = {}
var turns: int = 0
func _init(index: int = 0): seat = index
