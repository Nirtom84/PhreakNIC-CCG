class_name OnlineSession
extends Node
signal room_changed(data)
signal status_changed(text)
signal finished(winner)
signal removed(text)
# Refused reconnects in a row (about a minute of backoff) before checking whether the server still answers.
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
		var address = str(credential.server).replace("https://", "wss://").replace("http://", "ws://")
		transport.connected.connect(func(): set_status("Connected"))
		transport.connect_to(address + "/ws/room/" + credential.code + "?token=" + str(credential.token).uri_encode())
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
	# A refused upgrade (revoked token, deleted room) closes before opening, just like a network failure. A server
	# that still answers HTTP after REFUSALS of them no longer has this seat: stop instead of retrying forever.
	if endpoint is WebSocketTransport and not endpoint.opened and attempts >= REFUSALS:
		var answered = await _server_answers()
		if stopped or endpoint != transport: return
		if answered:
			_room_closed("This room has closed or your seat was removed.")
			return
	retry = minf(15, pow(2, attempts - 1))
# An answer below 500 means the server is up, so it refused the socket; none (or a 5xx) means down or unreachable.
func _server_answers() -> bool:
	var http = HTTPRequest.new()
	http.timeout = 20
	add_child(http)
	var result = [HTTPRequest.RESULT_CANT_CONNECT, 0]
	if http.request(str(credential.server) + "/health") == OK: result = await http.request_completed
	http.queue_free()
	return result[0] == HTTPRequest.RESULT_SUCCESS and result[1] < 500
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
			attempts = 0
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
			OnlineAPI.remember({})
			if data.get("reason") == "restore_failed": set_status("The server was updated, so this game couldn't be resumed. Start a new one from Play online.")
			finished.emit(int(data.get("winner", -1)))
			# Resumed after the game ended: no view ever came, so no table is open to show the result on.
			if client.engine.state == null and not data.has("reason"): _room_closed("This game has already ended.")
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

