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
static func normalize(value, max_nodes: int = 100000, max_bytes: int = 2 * 1024 * 1024):
	var budget = {"nodes": max_nodes, "bytes": max_bytes, "ok": true}
	var result = _bounded_normalize(value, budget, 0)
	return result if budget.ok else null
static func _bounded_normalize(value, budget: Dictionary, depth: int):
	budget.nodes -= 1
	if budget.nodes < 0 or depth > 32:
		budget.ok = false
		return null
	if value is String or value is StringName:
		budget.bytes -= value.length()
		if budget.bytes < 0: budget.ok = false
	elif value is float:
		if not is_finite(value) or absf(value) > 9007199254740991.0: budget.ok = false; return null
		if value == floor(value): return int(value)
	elif value is Array or value is Dictionary:
		if value.size() > budget.nodes: budget.ok = false; return null
		var result = [] if value is Array else {}
		for key in value:
			if not budget.ok: break
			if value is Array: result.append(_bounded_normalize(key, budget, depth + 1))
			else:
				if not (key is String or key is StringName): budget.ok = false; break
				_bounded_normalize(key, budget, depth + 1)
				result[key] = _bounded_normalize(value[key], budget, depth + 1)
		return result
	return value

static func valid_emote(message: Dictionary) -> bool:
	return message.size() == 2 and message.get("type") == "emote" and message.get("id") is int and message.id >= 0 and message.id < 8
