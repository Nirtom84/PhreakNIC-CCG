extends LinkServer
func _ready():
	var value = OS.get_environment("PORT")
	var selected = int(value) if not value.is_empty() else 8080
	var args = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size(): selected = int(args[i + 1])
	if selected < 1 or selected > 65535:
		push_error("Invalid server port")
		get_tree().quit(1)
		return
	var result = listen(selected)
	if result != OK:
		push_error("Server listen failed: %s" % error_string(result))
		get_tree().quit(1)
