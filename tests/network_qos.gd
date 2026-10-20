extends SceneTree
const SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var net = game.net
    assert(net.PING_INTERVAL > 1.0 and net.SNAPSHOT_TIMEOUT >= 9.0)
    assert(net.quality_text() == "", "Solo must not show network telemetry")
    net.role = "client"
    net.connected = true
    net.local_slot = 39
    net.ping_ms = -1.0
    assert(net.quality_text() == "CHECKING PING")
    net._pending_ping = 17
    net._sent_ping_ms = Time.get_ticks_msec() - 85
    net._latency_reply(16)
    assert(net.ping_ms < 0.0, "Mismatched probe must be ignored")
    net._latency_reply(17)
    assert(net.ping_ms >= 50.0 and net.ping_ms < 400.0,"RTT calculation incorrect")
    assert(net.quality_text().contains("GOOD"), "Healthy connection must appear")
    net.ping_ms = 185.0
    assert(net.quality_text().contains("FAIR"),"Moderate latency indicator missing")
    net.ping_ms = 450.0
    assert(net.quality_text().contains("SLOW"),"High-latency indicator missing")

    net.match_running = true
    net.snapshot_age_seconds = 5.5
    assert(net.quality_text().contains("STALLED"), "Stale frame indicator missing")
    net._ping_elapsed = -100.0
    net.snapshot_age_seconds = net.SNAPSHOT_TIMEOUT - 0.05
    net._process(0.09)
    assert(net.role == "offline" and not net.connected and not net.match_running,
        "Stalled session must disconnect without trapping the player")
    assert(net.snapshot_age_seconds == 0.0,"Session reset must clear age")
    assert(game.ui.network_quality_label != null,"Race HUD missing ping label")

    net.role = "client"
    net.connected = true
    net.local_slot = -1
    net._join_elapsed = net.JOIN_TIMEOUT - 0.03
    net._process(0.06)
    assert(net.role == "offline","Waiting forever for admission is not allowed")
    net.role = "client"
    net.connected = false
    net._connect_elapsed = net.CONNECT_TIMEOUT - 0.05
    net._process(0.08)
    assert(net.role == "offline","Slow connect timeout must still work")
    print("NETWORK_QOS_PASS: RTT echo matching, status tiers, missing snapshot and join timeouts")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
