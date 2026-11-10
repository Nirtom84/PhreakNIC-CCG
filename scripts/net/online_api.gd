class_name OnlineAPI
extends Node
const DEFAULT_SERVER = "https://online-01.phreaknic-ccg.net"
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
static func settings() -> ConfigFile:
	var config = ConfigFile.new()
	var file = FileAccess.open("user://settings.cfg", FileAccess.READ)
	if file != null and file.get_length() <= 65536:
		if config.load("user://settings.cfg") != OK: config.clear()
	return config
static func server() -> String:
	var override = OS.get_environment("PHREAKNIC_SERVER")
	return (override if not override.is_empty() else str(settings().get_value("game", "online_server", DEFAULT_SERVER))).trim_suffix("/")
static func remembered() -> Dictionary:
	var value = settings().get_value("game", "online_seat", {})
	if not value is Dictionary: return {}
	for key in ["server", "code", "token"]:
		if not value.get(key) is String or value[key].length() > 4096: return {}
	if not valid_code(value.code) or value.token.is_empty(): return {}
	if not value.get("seat") is int or value.seat < 0 or value.seat > 3: return {}
	if not (value.server.begins_with("https://") or value.server.begins_with("http://")): return {}
	return value
static func remember(value: Dictionary):
	var config = settings()
	config.set_value("game", "online_seat", value)
	config.save("user://settings.cfg")
static func valid_code(code: String) -> bool:
	return code.length() == 4 and Array(code.split("")).all(func(c): return c in ALPHABET)
static func invite_code(url: String) -> String:
	var value = ""
	if "/join/" in url: value = url.split("/join/")[1].split("?")[0].split("#")[0]
	if "?" in url:
		for part in url.split("?")[1].split("&"):
			if part.begins_with("join="): value = part.trim_prefix("join=").split("#")[0].uri_decode()
	value = value.to_upper()
	return value if valid_code(value) else ""
static func error_text(status: int, data: Dictionary) -> String:
	match data.get("error"):
		"room_version": return "This game was created with an older version (%s). Create a new game or pick another." % data.get("room", "?")
		"busy": return "The servers are full right now. Try again in a few minutes."
		"maintenance": return "Online play is paused for maintenance."
		"rate_limit": return "Too many tries from your network. Wait a minute and try again."
	if data.get("error") == "version": return "This game runs version %s. Please update" % data.get("need", "?")
	if status == 429: return "Too many requests. Please try again later."
	if status == 404: return "Game not found. Check the code."
	if data.get("error") == "full": return "This game is full."
	if data.get("error") == "started": return "This game has already started."
	return "Network unavailable. Please try again." if status == 0 else "Could not complete the request: " + str(data.get("error", "server error"))
func request(method: int, path: String, body: Dictionary = {}, address: String = server()) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 20
	var err = http.request(address + path, ["Content-Type: application/json"], method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if err != OK:
		http.queue_free()
		return {"status": 0, "data": {}}
	var result = await http.request_completed
	http.queue_free()
	var data = JSON.parse_string(result[3].get_string_from_utf8())
	return {"status": int(result[1]) if result[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data if data is Dictionary else {}}
