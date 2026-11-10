class_name NetTransport
extends RefCounted
signal received(message: Dictionary)
signal closed
func send(_message: Dictionary):
	push_error("NetTransport.send must be implemented")
func close():
	closed.emit()
static func safe_value(value, max_nodes: int = 8192, max_bytes: int = 65536) -> bool:
	var queue = [[value, 0]]
	var count = 0
	var bytes = 0
	while not queue.is_empty():
		var item = queue.pop_back()
		var v = item[0]
		var depth = item[1]
		count += 1
		if count > max_nodes or depth > 32: return false
		if v is String:
			bytes += v.length()
			if bytes > max_bytes: return false
		elif v is float:
			if not is_finite(v) or absf(v) > 9007199254740991.0: return false
		elif v is Array:
			if v.size() > max_nodes: return false
			for child in v: queue.append([child, depth + 1])
		elif v is Dictionary:
			if v.size() > max_nodes: return false
			for key in v:
				if not (key is String or key is StringName): return false
				queue.append([key, depth + 1])
				queue.append([v[key], depth + 1])
	return true
# JSON numbers are doubles; only integral protocol numbers become integers.
static func normalize(value):
	if not safe_value(value, 100000, 2 * 1024 * 1024): return null
	return _normalize(value)
static func _normalize(value):
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Array: return value.map(_normalize)
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = _normalize(value[key])
		return result
	return value
