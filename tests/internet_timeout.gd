extends SceneTree
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    for n in range(4):
        await process_frame
    var net = stage.net
    assert(net.connect_server("ws://example.org:8080") != "", "Public plaintext must be rejected")
    assert(net.connect_server("wss://") != "", "Empty host must be rejected")
    assert(net.connect_server("wss://bad host") != "", "Spaces must be rejected")
    assert(net.connect_server("wss://user@host.example") != "", "Userinfo must be rejected")
    assert(net.connect_server("wss://host.example#fragment") != "", "Fragments must be rejected")
    assert(not net.is_active(), "Invalid endpoints must not open a socket")
    # Simulate an already-initialized client waiting for a TCP/WebSocket handshake.
    # The timeout path must close the transport and restore the offline state.
    net.role = "client"
    net.connected = false
    net._connect_elapsed = net.CONNECT_TIMEOUT - 0.02
    net._process(0.04)
    assert(not net.is_active(), "Timed-out connection must close")
    assert(net._connect_elapsed == 0.0, "Timeout timer must reset")
    print("INTERNET_TIMEOUT_PASS: endpoint validation and stale connection cleanup")
    stage.queue_free()
    for n in range(4):
        await process_frame
    quit(0)
