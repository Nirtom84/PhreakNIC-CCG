class_name OnlineSession
extends Node
signal room_changed(data)
signal status_changed(text)
signal finished(winner)
signal removed(text)
# Refused reconnects in a row (about a minute of backoff) before asking the server whether the seat still exists.
const REFUSALS = 8
var client: NetClient
var credential: Dictionary = {}
var room: Dictionary = {}
var transport: NetTransport
var transport_factory: Callable
var stopped = false
var retry = 0.0
var attempts = 0
var status = "Connecting…"
func _init():
	client = NetClient.new()
	add_child(client)
func start(data: Dictionary):
	credential = data.duplicate()
	OnlineAPI.remember(credential)
	connect_socket()
func set_status(value: String):
	status = value
	status_changed.emit(value)
func connect_socket():
	if stopped: return
	client.can_act = false
	transport = transport_factory.call() if transport_factory.is_valid() else WebSocketTransport.new()
	client.bind_transport(transport)
	transport.received.connect(_message)
	transport.closed.connect(_closed.bind(transport))
	if transport is WebSocketTransport:
		var address = OnlineAPI.safe_server(str(credential.server)).replace("https://", "wss://").replace("http://", "ws://")
		transport.connected.connect(func(): set_status("Connected"))
		transport.connect_to(address + "/ws/room/" + credential.code, str(credential.token))
func _closed(endpoint):
	if stopped or endpoint != transport: return
	client.can_act = false
	if endpoint is WebSocketTransport and endpoint.close_code == 4002:
		_room_closed()
		return
	if endpoint is WebSocketTransport and endpoint.close_reason in ["room_version", "busy", "maintenance", "rate_limit"]:
		stopped = true
		retry = 0
		set_status(OnlineAPI.error_text(0, {"error": endpoint.close_reason, "room": room.get("version", "?")}))
		return
	# Kicked (4001) or the host's Remove seat (1000 "removed"): either way the seat's token is gone.
	var kicked = endpoint is WebSocketTransport and (endpoint.close_code == 4001 or (endpoint.close_code == 1000 and endpoint.close_reason == "removed"))
	if endpoint is WebSocketTransport and (endpoint.close_code == 4000 or kicked):
		stopped = true
		retry = 0
		var text = "The host removed you from the room." if kicked else "This seat was opened somewhere else."
		OnlineAPI.remember({})
		set_status(text)
		if kicked: removed.emit(text)
		return
	set_status("Reconnecting…")
	attempts += 1
	# A refused upgrade (revoked token, deleted room) closes before opening, just like a network failure, a rate
	# limit or a proxy that blocks WebSockets. After REFUSALS of them, ask the room itself (with the seat's token)
	# and forget the seat only when it answers that the seat is gone; anything else keeps retrying.
	if endpoint is WebSocketTransport and not endpoint.opened and attempts >= REFUSALS:
		var gone = await _seat_gone()
		if stopped or endpoint != transport: return
		if gone:
			_room_closed("This room has closed or your seat was removed.")
			return
	retry = minf(15, pow(2, attempts - 1))
# The room answers a plain GET on the socket address with 401 {"error":"token"} once the seat or room is gone
# (426 while the seat still exists). No answer, a rate limit or any other status means: keep the seat.
func _seat_gone() -> bool:
	var http = HTTPRequest.new()
	http.timeout = 20
	http.body_size_limit = 1024 * 1024
	add_child(http)
	var result = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	var url = OnlineAPI.safe_server(str(credential.server)) + "/ws/room/" + str(credential.code)
	if http.request(url, ["Authorization: Bearer " + str(credential.token)]) == OK: result = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 401: return false
	var body = JSON.parse_string(result[3].get_string_from_utf8())
	return body is Dictionary and body.get("error") == "token"
func _message(data: Dictionary):
	match data.get("t"):
		"room_closed": _room_closed()
		"error":
			var reason = data.get("reason", data.get("error", ""))
			if reason in ["room_version", "version", "busy", "maintenance", "rate_limit"]:
				var error = data.duplicate()
				error.error = reason
				set_status(OnlineAPI.error_text(0, error))
		"room":
			var normalized = NetTransport.normalize(data)
			if not normalized is Dictionary or not NetClient.valid_room(normalized): return
			data = normalized
			attempts = 0
			# The server says which seat this socket holds: the host's Remove seat renumbers the seats after it.
			if not credential.is_empty() and data.get("seat") is int and data.seat >= 0 and data.seat < data.seats.size() and data.seat != credential.get("seat"):
				credential.seat = data.seat
				OnlineAPI.remember(credential)
			room = data
			room_changed.emit(data)
		"server":
			match data.get("status"):
				"restarting":
					client.can_act = false
					set_status("The game server is restarting…")
				"ok": set_status("Connected")
				"unavailable":
					client.can_act = false
					set_status("Game server unavailable. Return to the menu and try resuming.")
		"welcome": attempts = 0; set_status("Connected")
		"game_over", "over":
			if not data.get("winner", -1) is int or data.get("winner", -1) < -1 or data.get("winner", -1) >= 4: return
			OnlineAPI.remember({})
			# The server couldn't resume an unfinished game, so it has no result: close it with the reason, even with a
			# table open, instead of finishing it as a draw.
			if data.get("reason") == "restore_failed":
				_room_closed("The server was updated, so this game couldn't be resumed. Start a new one from Play online.")
				return
			finished.emit(int(data.get("winner", -1)))
			# No view ever came (resumed after the game ended, or the game couldn't start), so no table is open to
			# show the result on: go back to the game list with the reason instead of leaving the room screen stuck.
			if client.engine.state == null:
				var reasons = {"banned_minimum": "At least 40 center-deck cards must remain. Change the banned cards and create a new room."}
				_room_closed(reasons.get(str(data.get("reason", "")), "This game has already ended."))
func _room_closed(text: String = "The host closed the room."):
	if stopped: return
	stopped = true
	retry = 0
	client.can_act = false
	credential = {}
	OnlineAPI.remember({})
	set_status(text)
	if transport != null: transport.close()
	removed.emit(text)
func lobby(action: String, fields: Dictionary = {}):
	var message = fields.duplicate()
	message.t = "lobby"
	message.action = action
	transport.send(message)
func disconnect_game():
	stopped = true
	if transport != null: transport.close()
func _process(delta):
	if transport is WebSocketTransport: transport.poll()
	if retry > 0:
		retry -= delta
		if retry <= 0: connect_socket()

