extends SceneTree
const Net = preload("res://scripts/internet_session.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var net := Net.new()
    root.add_child(net)
    assert(not net.is_active(), "No online connection by default")
    assert(net.MAX_PLAYERS == 4 and net.FLOATS_PER_RACER == 9)
    assert(net._valid_room_code("A2BC4D") and not net._valid_room_code("ABCDEF7"))
    assert(not net._valid_room_code("abc123") and not net._valid_room_code("../etc"))
    assert(net._local_ws_allowed("ws://127.0.0.1:8080"))
    assert(not net._local_ws_allowed("ws://192.168.1.2:8080"))
    assert(not net._local_ws_allowed("ws://evil.com"))
    assert(not net._local_ws_allowed("ws://localhost.evil.com"))
    assert(net.input_for_slot(39) == Vector2.ZERO)
    assert(not net.can_host_start())
    assert(FileAccess.file_exists("res://config/online_server.txt"), "Missing production endpoint")
    var default_url := FileAccess.get_file_as_string("res://config/online_server.txt").strip_edges()
    assert(default_url == "wss://marble-race-global.onrender.com",
        "Fresh Android installs must have the deployed TLS endpoint")
    assert(net.CONNECT_TIMEOUT >= 70.0,
        "Free hosting may cold-start; the client must wait long enough")
    print("INTERNET_VALIDATION_PASS: code checks, WSS requirement, no player-hosted games")
    net.queue_free()
    for n in range(2):
        await process_frame
    quit(0)
