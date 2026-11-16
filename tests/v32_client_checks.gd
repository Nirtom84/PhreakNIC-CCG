extends SceneTree
var checks = 0
var failures = 0
var backups = {}
func _finalize():
 for path in backups:
  if backups[path] == null: DirAccess.remove_absolute(path)
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_buffer(backups[path])
   file.close()
func _initialize(): run.call_deferred()
func verify(ok, text):
 checks += 1
 if not ok: failures += 1; print("FAIL: ", text)
func run():
 for path in ["user://settings.json", "user://settings.cfg", "user://settings.cfg.migrated"]:
  backups[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
  DirAccess.remove_absolute(path)
 var file = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
 file.store_string('[bad]\nc=#fff x=Object(GDScript,"script/source":"extends Node")\nx=Object(Node)\n[player]\nhandle="Object(Node)"\n[game]\nplayer_count=3\nbot_pace=0.5\nauto_end_turn=true\nonline_seat={"server":"https://example.test","code":"ABCD","seat":1,"token":"secret"}\n')
 file.close()
 var orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
 var config = OnlineAPI.settings()
 verify(not config.has_section_key("bad", "c") and not config.has_section_key("bad", "x"), "malicious Variant lines skipped")
 verify(orphans == Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "migration constructs no Nodes")
 verify(OnlineAPI.legacy_value(JSON.stringify('Object(Node) "quoted" \\tail')) == 'Object(Node) "quoted" \\tail', "quoted string escapes preserved")
 verify(config.get_value("player", "handle") == "Object(Node)", "constructor-looking quoted string preserved")
 verify(config.get_value("game", "player_count") == 3 and config.get_value("game", "bot_pace") == 0.5 and config.get_value("game", "auto_end_turn") == true, "scalar migration")
 verify(OnlineAPI.remembered().is_empty(), "invalid migrated token rejected")
 var credential = {"code":"ABCD","seat":0,"token":"a".repeat(32)}
 credential.server = OnlineAPI.DEFAULT_SERVER
 OnlineAPI.remember(credential)
 verify(OnlineAPI.remembered().get("token") == "a".repeat(32), "remember accepts dictionary dot-assigned keys")
 verify(FileAccess.file_exists("user://settings.json") and not FileAccess.file_exists("user://settings.cfg"), "one-time migration")
 config.set_value("ui", "layout", "compact")
 verify(config.save("user://ignored.cfg") == OK and not FileAccess.file_exists("user://ignored.cfg") and OnlineAPI.settings().get_value("ui", "layout") == "compact", "atomic JSON save ignores legacy path")
 config.erase_section_key("ui", "layout")
 verify(not config.has_section_key("ui", "layout"), "compatible settings erase")
 for address in ["http://evil.test", "http://localhost.evil", "ws://example.test", "http://localhost@evil.test"]:
  verify(OnlineAPI.safe_server(address) == OnlineAPI.DEFAULT_SERVER, "reject insecure remote " + address)
 for address in ["http://localhost:9", "http://127.0.0.1", "ws://[::1]:9", "https://example.test"]:
  verify(OnlineAPI.safe_server(address) == address, "allow secure or loopback " + address)
 var old_server = OS.get_environment("PHREAKNIC_SERVER")
 OS.set_environment("PHREAKNIC_SERVER", "http://remote.invalid")
 verify(OnlineAPI.server() == OnlineAPI.DEFAULT_SERVER, "insecure environment override ignored")
 OS.set_environment("PHREAKNIC_SERVER", "")
 config = OnlineAPI.settings()
 config.set_value("game", "online_server", "http://remote.invalid")
 config.save()
 verify(OnlineAPI.server() == OnlineAPI.DEFAULT_SERVER, "insecure settings override ignored")
 OS.set_environment("PHREAKNIC_SERVER", old_server)
 for bad_token in ["", "a".repeat(31), "A".repeat(32), "a".repeat(32) + "\r\nX: bad"]:
  credential.token = bad_token
  OnlineAPI.remember(credential)
  verify(OnlineAPI.remembered().is_empty(), "Reject unsafe stored token")
 var client = NetClient.new()
 root.add_child(client)
 verify(client.valid_message({"t":"event","kind":"removed","seat":-1}), "Ownerless removed event accepted")
 verify(not client.valid_message({"t":"event","kind":"removed","seat":-2}), "Invalid removed seat rejected")
 verify(client.valid_message({"t":"timers","timers":[{"seat":0,"kind":"turn","remaining_seconds":12,"limit":180,"handable":true}]}), "Timer-only message accepted")
 verify(not client.valid_message({"t":"timers","timers":[{"seat":0}]}), "Malformed timer-only message rejected")
 verify(not client.valid_message({"t":"welcome","seat":9,"seats":[{},{}]}), "invalid welcome rejected")
 verify(not client.valid_message({"t":"event","kind":"waiting","seat":-1}), "invalid waiting rejected")
 verify(not client.valid_message({"t":"view","state":{"ready":true},"timers":[{"seat":0}]}), "incomplete timer rejected")
 verify(not client.valid_message({"t":"event","kind":"played","seat":0}), "event required fields checked")
 verify(not client.valid_message({"t":"event","kind":"turn_started","seat":9}), "event seat range checked")
 verify(not NetClient.valid_card({"id":"Hacking","uid":1,"owner":9,"controller":0,"counters":0}), "prompt card seat range checked")
 var room = {"code":"ABCD","card_pool":"2026","starting_life":0,"public":true,"started":false,"host_seat":0,"seats":[{"name":"A","bot":false,"difficulty":0},{"name":"B","bot":false,"difficulty":0}]}
 verify(NetClient.valid_room(room), "valid room")
 room.host_seat = 9
 verify(not NetClient.valid_room(room), "host range checked")
 room.host_seat = 0
 room.seats[0] = "invalid"
 verify(not NetClient.valid_room(room), "seat dictionary required")
 var engine = GameEngine.new()
 root.add_child(engine)
 engine.setup([-1, 0], 42)
 var view = NetView.build(engine, 0)
 verify(NetView.apply(view) != null, "valid view")
 var invalid_view = view.duplicate(true)
 invalid_view.seat = 9
 verify(NetView.apply(invalid_view) == null, "view seat range checked")
 var card_index = -1
 for i in view.objects.size():
  if view.objects[i].type == "card": card_index = i; break
 view.objects[card_index].data.attached = [{"ref":card_index}]
 verify(NetView.apply(view) == null, "attachment self cycle rejected")
 var deck = load("res://scripts/ui/deck_builder.gd").playable()[0].duplicate(true)
 for name in ["Bad\nDeck", "Bad\u202eDeck", "Bad\u200bDeck"]:
  deck.name = name
  verify(CustomDeck.parse_payload(JSON.stringify(deck)).is_empty(), "unsafe deck name rejected")
 verify(OnlineAPI.error_text(409, {"error":"name_taken"}) == "Someone in this room already uses that name. Pick another handle.", "duplicate name explanation")
 var save = SaveGame.snapshot(engine.state)
 save.state.erase("rng_seed")
 verify(SaveGame.restore(save) == null, "missing rng seed returns null")
 save.state.rng_seed = []
 verify(SaveGame.restore(save) == null, "wrong rng seed type returns null")
 var endpoints = LoopbackTransport.pair(false)
 endpoints[0].send({"number":9223372036854775807})
 verify(endpoints[1].queue.is_empty(), "failed JSON normalization dropped")
 endpoints[0].close()
 client.queue_free()
 engine.queue_free()
 print("v32 client checks: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
