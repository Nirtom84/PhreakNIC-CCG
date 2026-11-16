class_name LoopbackTransport
extends NetTransport
var peer: LoopbackTransport
var queue: Array = []
var open = true
var scheduled = false
var automatic = true
static func pair(auto_pump: bool = true) -> Array:
	var a = LoopbackTransport.new()
	var b = LoopbackTransport.new()
	a.peer = b
	b.peer = a
	a.automatic = auto_pump
	b.automatic = auto_pump
	return [a, b]
func send(message: Dictionary):
	if not open or peer == null or not peer.open or not NetTransport.safe_value(message): return
	var normalized = NetTransport.normalize(JSON.parse_string(JSON.stringify(message)))
	if not normalized is Dictionary: return
	peer.queue.append(normalized)
	if peer.automatic and not peer.scheduled:
		peer.scheduled = true
		peer._next_frame()
func _next_frame():
	await Engine.get_main_loop().process_frame
	scheduled = false
	pump()
func pump():
	var pending = queue
	queue = []
	for message in pending:
		if open: received.emit(message)
func close():
	if not open: return
	open = false
	queue.clear()
	var other = peer
	peer = null
	closed.emit()
	if other != null:
		other.peer = null
		other.close()
