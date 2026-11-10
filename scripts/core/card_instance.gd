class_name CardInstance
extends RefCounted
var uid: int
var id: String
var owner: int
var controller: int
var counters: int = 0
var attached: Array = []
var flags: Dictionary = {}
func _init(serial: int = 0, card_id: String = "", seat: int = -1):
	uid = serial
	id = card_id
	owner = seat
	controller = seat
func effect_id() -> String:
	return flags.get("copy_id", id)
