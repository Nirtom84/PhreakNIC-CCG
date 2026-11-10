class_name NetTransport
extends RefCounted
signal received(message: Dictionary)
signal closed
func send(_message: Dictionary):
	push_error("NetTransport.send must be implemented")
func close():
	closed.emit()
# JSON numbers are doubles; only integral protocol numbers become integers.
static func normalize(value):
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Array: return value.map(normalize)
	if value is Dictionary:
		var result = {}
		for key in value: result[key] = normalize(value[key])
		return result
	return value
