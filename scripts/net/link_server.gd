class_name LinkServer
extends Node
# HTTP is parsed here because GDScript's TCP streams have no peek/unread API.
# A loopback bridge replays the headers to WebSocketPeer.accept_stream(), leaving
# framing, fragmentation, close and control frames entirely to Godot.
class SeatTransport extends NetTransport:
	var output: Callable
	var open = true
	func send(message: Dictionary):
		if open: output.call(message)
	func close():
		if not open: return
		open = false
		closed.emit()
var listener = TCPServer.new()
var bridge_listener = TCPServer.new()
var requests: Array = []
var bridges: Array = []
var link: WebSocketPeer
var game: GameServer
var endpoints: Dictionary = {}
var port = 8080
var room = ""
func listen(on_port: int = 8080) -> Error:
	var result = listener.listen(on_port, "0.0.0.0")
	if result != OK: return result
	result = bridge_listener.listen(0, "127.0.0.1")
	if result != OK:
		listener.stop()
		return result
	port = listener.get_local_port()
	print("room server listening 0.0.0.0:%d" % port)
	return OK
func stop():
	listener.stop()
	bridge_listener.stop()
	_drop_link()
	for request in requests: request.tcp.disconnect_from_host()
	requests.clear()
	for bridge in bridges:
		bridge.remote.disconnect_from_host()
		bridge.local.disconnect_from_host()
	bridges.clear()
	if game != null:
		game.running = false
		game.queue_free()
		game = null
func _exit_tree(): stop()
func _drop_link():
	if link != null:
		link.close(-1)
		link = null
		print("room link down")
	for endpoint in endpoints.values(): endpoint.close()
	endpoints.clear()
func _send(message: Dictionary):
	if link != null and link.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if link.send_text(JSON.stringify(message)) != OK: _drop_link()
func _process(_delta):
	while listener.is_connection_available():
		requests.append({"tcp": listener.take_connection(), "header": PackedByteArray(), "at": Time.get_ticks_msec()})
	for request in requests.duplicate():
		var tcp = request.tcp
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - request.at > 10000:
			tcp.disconnect_from_host()
			requests.erase(request)
			continue
		# Read only through the header terminator, preserving any coalesced frames.
		while tcp.get_available_bytes() > 0 and request.header.size() < 16384:
			request.header.append(tcp.get_u8())
			if request.header.size() >= 4 and request.header.slice(-4).get_string_from_ascii() == "\r\n\r\n": break
		var header = request.header.get_string_from_ascii()
		if not header.ends_with("\r\n\r\n"):
			if request.header.size() >= 16384: tcp.disconnect_from_host(); requests.erase(request)
			continue
		requests.erase(request)
		var first = header.get_slice("\r\n", 0)
		if first == "GET /link HTTP/1.1" and "upgrade: websocket" in header.to_lower():
			var local = StreamPeerTCP.new()
			local.connect_to_host("127.0.0.1", bridge_listener.get_local_port())
			bridges.append({"remote": tcp, "local": local, "up": request.header, "down": PackedByteArray(), "peer": null, "at": request.at, "accepted": false})
		else:
			var status = "200 OK" if first == "GET /health HTTP/1.1" else "404 Not Found"
			var body = "ok" if status == "200 OK" else "not found"
			tcp.put_data(("HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.length(), body]).to_utf8_buffer())
			tcp.disconnect_from_host()
	while bridge_listener.is_connection_available():
		var stream = bridge_listener.take_connection()
		var matched = false
		for bridge in bridges:
			if bridge.peer == null and bridge.local.get_local_port() == stream.get_connected_port():
				var peer = WebSocketPeer.new()
				peer.inbound_buffer_size = 8 * 1024 * 1024
				peer.outbound_buffer_size = 8 * 1024 * 1024
				if peer.accept_stream(stream) == OK:
					bridge.peer = peer
					matched = true
				break
		if not matched: stream.disconnect_from_host()
	for bridge in bridges.duplicate(): _bridge(bridge)
	if link != null:
		link.poll()
		if link.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_drop_link()
		else:
			while link != null and link.get_available_packet_count():
				var bytes = link.get_packet()
				if not link.was_string_packet(): continue
				var message = JSON.parse_string(bytes.get_string_from_utf8())
				if message is Dictionary and NetTransport.safe_value(message, 100000, 2 * 1024 * 1024): _receive(NetTransport.normalize(message))
func _bridge(bridge: Dictionary):
	bridge.local.poll()
	bridge.remote.poll()
	for direction in ["up", "down"]:
		var source = bridge.remote if direction == "up" else bridge.local
		var target = bridge.local if direction == "up" else bridge.remote
		var count = source.get_available_bytes()
		if count > 0:
			var data = source.get_partial_data(count)
			if data[0] == OK: bridge[direction].append_array(data[1])
		if target.get_status() == StreamPeerTCP.STATUS_CONNECTED and not bridge[direction].is_empty():
			var sent = target.put_partial_data(bridge[direction])
			if sent[0] == OK: bridge[direction] = bridge[direction].slice(sent[1])
	if bridge.peer != null and not bridge.accepted:
		bridge.peer.poll()
		if bridge.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_drop_link()
			link = bridge.peer
			bridge.accepted = true
			print("room link up")
			_send({"t": "ready", "version": str(ProjectSettings.get_setting("application/config/version", ""))})
	if bridge.remote.get_status() != StreamPeerTCP.STATUS_CONNECTED or bridge.local.get_status() == StreamPeerTCP.STATUS_NONE or (not bridge.accepted and Time.get_ticks_msec() - bridge.at > 10000) or (bridge.peer != null and bridge.peer.get_ready_state() == WebSocketPeer.STATE_CLOSED):
		if bridge.peer != null and bridge.peer == link: _drop_link()
		if bridge.peer != null: bridge.peer.close(-1)
		bridge.remote.disconnect_from_host()
		bridge.local.disconnect_from_host()
		bridges.erase(bridge)
func _new_game():
	for endpoint in endpoints.values(): endpoint.close()
	endpoints.clear()
	if game != null:
		game.running = false
		game.queue_free()
	game = GameServer.new()
	add_child(game)
	game.snapshot.connect(func(data): _send({"t": "snapshot", "data": data}))
func _watch_over():
	game.engine.game_over.connect(func(winner):
		var seat = winner.seat if winner != null else -1
		print("room %s game over winner=%d" % [room, seat])
		_send({"t": "over", "winner": seat, "turns": game.engine.state.turn}))
func _receive(message: Dictionary):
	if not NetTransport.safe_value(message, 100000, 2 * 1024 * 1024) or not message.get("t") is String: return
	if message.get("t") == "setup":
		if not message.get("seats") is Array or message.seats.size() < 2 or message.seats.size() > 4: return
		for seat in message.seats:
			if not seat is Dictionary: return
			if not seat.get("difficulty", 1) is int or seat.get("difficulty", 1) < 0 or seat.get("difficulty", 1) > 2: return
			if not seat.get("bot", false) is bool: return
		for field in ["seed", "starting_life"]:
			if message.has(field) and not message[field] is int: return
		if not message.get("banned", []) is Array: return
		if message.get("starting_life", 0) < 0 or message.get("starting_life", 0) > 10000: return
	if message.get("t") == "restore" and not message.get("snapshot") is Dictionary: return
	match message.get("t"):
		"ping": _send({"t": "pong"})
		"setup":
			_new_game()
			room = str(message.get("room", ""))
			game.room_label = room
			if not game.setup(message.seats, str(message.get("card_pool", "2026")), int(message.get("starting_life", 0)), int(message.get("seed", 1)), message.get("banned", [])):
				for seat in message.seats.size(): _send({"t": "to", "seat": seat, "msg": {"t": "error", "reason": "At least 40 center-deck cards must remain. Change the banned cards and create a new room."}})
				_send({"t": "over", "winner": -1, "reason": "banned_minimum"})
				return
			for i in message.seats.size(): game.tokens[i] = str(message.seats[i].get("token", ""))
			_watch_over()
			print("room %s setup" % room)
			game.start()
		"restore":
			_new_game()
			room = str(message.get("room", ""))
			game.room_label = room
			if game.restore(message.snapshot):
				_watch_over()
				print("room %s restore" % room)
				if game.engine.state.finished:
					_send({"t": "over", "winner": game.engine.state.winner.seat if game.engine.state.winner != null else -1, "turns": game.engine.state.turn})
			else:
				# A snapshot from another server version can't be resumed: end the game cleanly instead of leaving players waiting.
				push_error("room %s restore failed" % room)
				_send({"t": "over", "winner": -1, "reason": "restore_failed"})
		"connect", "disconnect", "from":
			if game == null: return
			var seat = message.get("seat")
			if not seat is int or seat < 0 or seat >= game.seats.size() or game.seats[seat].bot: return
			if message.t == "connect":
				if not message.get("version") is String or message.version != game.version():
					_send({"t": "to", "seat": seat, "msg": {"t": "error", "reason": "version", "need": game.version()}})
					return
				if endpoints.has(seat): endpoints[seat].close()
				var endpoint = SeatTransport.new()
				endpoint.output = func(data): _send({"t": "to", "seat": seat, "msg": data})
				endpoints[seat] = endpoint
				game.attach(endpoint)
				endpoint.received.emit({"t": "hello", "seat": seat, "token": game.tokens[seat], "version": message.version})
			elif message.t == "disconnect":
				if endpoints.has(seat): endpoints[seat].close(); endpoints.erase(seat)
			elif endpoints.has(seat) and message.get("msg") is Dictionary and message.msg.get("t") in ["action", "answer"]:
				endpoints[seat].received.emit(message.msg)
