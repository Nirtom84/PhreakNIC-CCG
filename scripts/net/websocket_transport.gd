class_name WebSocketTransport
extends NetTransport
# RefCounted transport: call poll() from the owning Node's _process.
signal connected
var peer = WebSocketPeer.new()
var error: Error = OK
var close_code = -1
var close_reason = ""
var active = false
var opened = false
func connect_to(url: String) -> Error:
	peer = WebSocketPeer.new()
	peer.inbound_buffer_size = 8 * 1024 * 1024
	peer.outbound_buffer_size = 8 * 1024 * 1024
	opened = false
	close_code = -1
	close_reason = ""
	error = peer.connect_to_url(url)
	active = error == OK
	if not active: closed.emit()
	return error
func poll():
	if not active: return
	peer.poll()
	var state = peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not opened:
			opened = true
			connected.emit()
		while peer.get_available_packet_count():
			var packet = peer.get_packet()
			if not peer.was_string_packet(): continue
			var message = JSON.parse_string(packet.get_string_from_utf8())
			if message is Dictionary and NetTransport.safe_value(message): received.emit(NetTransport.normalize(message))
	elif state == WebSocketPeer.STATE_CLOSED:
		active = false
		close_code = peer.get_close_code()
		close_reason = peer.get_close_reason()
		if close_code == -1: error = ERR_CONNECTION_ERROR
		closed.emit()
func send(message: Dictionary):
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error = ERR_UNCONFIGURED
		return
	error = peer.send_text(JSON.stringify(message))
func close():
	if active: peer.close()
