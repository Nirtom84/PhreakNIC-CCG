class_name OnlineSession
extends Node
signal room_changed(data)
signal status_changed(text)
signal finished(winner)
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
	set_status("Reconnecting…")
	retry = minf(15, pow(2, attempts))
	attempts += 1
func _message(data: Dictionary):
	match data.get("t"):
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

