class_name OnlineAPI
extends Node
const DEFAULT_SERVER = "https://online-01.phreaknic-ccg.net"
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
class SettingsFile extends RefCounted:
	var data: Dictionary = {}
	func get_value(section: String, key: String, fallback = null):
		return data.get(section, {}).get(key, fallback)
	func has_section_key(section: String, key: String) -> bool:
		return data.has(section) and data[section].has(key)
	func set_value(section: String, key: String, value):
		if not OnlineAPI.plain_value(value): return
		if not data.has(section): data[section] = {}
		data[section][key] = value
	func erase_section_key(section: String, key: String):
		if data.has(section):
			data[section].erase(key)
			if data[section].is_empty(): data.erase(section)
	func get_sections() -> PackedStringArray:
		return PackedStringArray(data.keys())
	func save(_path: String = "") -> Error:
		var text = JSON.stringify(data)
		if text.to_utf8_buffer().size() > 65536: return ERR_OUT_OF_MEMORY
		var file = FileAccess.open("user://settings.json.tmp", FileAccess.WRITE)
		if file == null: return FileAccess.get_open_error()
		file.store_string(text)
		file.flush()
		var error = file.get_error()
		file.close()
		if error != OK: return error
		return DirAccess.rename_absolute("user://settings.json.tmp", "user://settings.json")
static func plain_value(value, depth: int = 0) -> bool:
	if depth > 32: return false
	if value is String or value is bool or value is int: return true
	if value is float: return is_finite(value)
	if value is Array: return value.all(func(v): return plain_value(v, depth + 1))
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not plain_value(value[key], depth + 1): return false
		return true
	return false
static func legacy_value(text: String):
	# Only these two ConfigFile string escapes are accepted. Never invoke its Variant parser.
	if text.begins_with('"'):
		var result = ""
		var i = 1
		while i < text.length():
			var ch = text[i]
			if ch == '"': return result if i == text.length() - 1 else null
			if ch == "\\":
				i += 1
				if i >= text.length() or text[i] not in ['"', "\\"]: return null
				ch = text[i]
			result += ch
			i += 1
		return null
	if text == "true": return true
	if text == "false": return false
	if text.is_valid_int(): return int(text)
	if text.is_valid_float():
		var number = float(text)
		return number if is_finite(number) else null
	if text.begins_with("[") or text.begins_with("{"):
		var value = JSON.parse_string(text)
		if (value is Array or value is Dictionary) and plain_value(value): return value
	return null
static func settings() -> SettingsFile:
	var config = SettingsFile.new()
	var migrating = not FileAccess.file_exists("user://settings.json") and FileAccess.file_exists("user://settings.cfg")
	var file = FileAccess.open("user://settings.cfg" if migrating else "user://settings.json", FileAccess.READ)
	if file != null and file.get_length() <= 65536:
		var text = file.get_as_text()
		file.close()
		if migrating:
			var section = ""
			for raw in text.split("\n"):
				var line = raw.strip_edges()
				if line.begins_with("[") and line.ends_with("]"):
					section = line.substr(1, line.length() - 2)
				elif not section.is_empty() and "=" in line and not line.begins_with(";") and not line.begins_with("#"):
					var split = line.find("=")
					var key = line.left(split).strip_edges()
					var value = legacy_value(line.substr(split + 1).strip_edges())
					if not key.is_empty() and value != null: config.set_value(section, key, value)
		else:
			var value = NetTransport.normalize(JSON.parse_string(text))
			if value is Dictionary and plain_value(value):
				for section in value:
					if value[section] is Dictionary: config.data[section] = value[section]
	for entry in [["game", "online_server", TYPE_STRING], ["ui", "emotes", TYPE_BOOL], ["ui", "log_open", TYPE_BOOL], ["ui", "tutorial_seen", TYPE_BOOL], ["ui", "layout", TYPE_STRING]]:
		if config.has_section_key(entry[0], entry[1]) and typeof(config.get_value(entry[0], entry[1])) != entry[2]:
			config.erase_section_key(entry[0], entry[1])
	if migrating and config.save() == OK:
		DirAccess.rename_absolute("user://settings.cfg", "user://settings.cfg.migrated")
	return config
static func server() -> String:
	var override = OS.get_environment("PHREAKNIC_SERVER")
	return safe_server(override if not override.is_empty() else str(settings().get_value("game", "online_server", DEFAULT_SERVER)))
static func safe_server(address: String) -> String:
	address = address.trim_suffix("/")
	if address.begins_with("https://") or address.begins_with("wss://"): return address
	if address.begins_with("http://") or address.begins_with("ws://"):
		var authority = address.split("://")[1].split("/")[0]
		if RegEx.create_from_string("^(localhost|127\\.0\\.0\\.1|\\[::1\\])(:[0-9]+)?$").search(authority) != null: return address
	print("Ignoring insecure or invalid online server address")
	return DEFAULT_SERVER
static func remembered() -> Dictionary:
	var value = settings().get_value("game", "online_seat", {})
	if not value is Dictionary: return {}
	for key in ["server", "code", "token"]:
		if not value.get(key) is String or value[key].length() > 4096: return {}
	if not valid_code(value.code) or not (value.token.length() == 32 and Array(value.token.split("")).all(func(c): return c in "abcdef0123456789")): return {}
	if not value.get("seat") is int or value.seat < 0 or value.seat > 3: return {}
	if safe_server(value.server) != value.server: return {}
	return value
static func remember(value: Dictionary):
	var config = settings()
	config.set_value("game", "online_seat", value)
	config.save("user://settings.cfg")
static func valid_code(code: String) -> bool:
	return code.length() in [4, 6] and Array(code.split("")).all(func(c): return c in ALPHABET)
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
		"name_taken": return "Someone in this room already uses that name. Pick another handle."
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
	address = safe_server(address)
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 20
	http.body_size_limit = 1024 * 1024
	var err = http.request(address + path, ["Content-Type: application/json"], method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if err != OK:
		http.queue_free()
		return {"status": 0, "data": {}}
	var result = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS: return {"status": 0, "data": {}}
	var data = JSON.parse_string(result[3].get_string_from_utf8())
	return {"status": int(result[1]) if result[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data if data is Dictionary else {}}
