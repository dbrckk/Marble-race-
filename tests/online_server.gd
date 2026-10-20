extends SceneTree
## Runs an actual dedicated authority over WebSocket and verifies inbound controls.
const SCENE = preload("res://scenes/main.tscn")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var requested := OS.get_environment("PORT")
    var port := int(requested) if requested.is_valid_int() else 28999
    var err: Error = game.net.start_dedicated(port)
    assert(err == OK,"Could not open dedicated online test server")
    print("ONLINE_SERVER_TEST_READY ",port)
    var deadline: int = Time.get_ticks_msec()+40000
    var connected_two := false
    var controls_seen := false
    var snapshots_seen := false
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if game.net.joined_slots.size() >= 2:
            connected_two = true
        if game.net.match_running and game.racers.size() == 40:
            snapshots_seen = game.net.frame_clock >= 0.0 and game.race_time > 0.3
            for value in game.net.steer_by_slot.values():
                if absf(float(value)) >= 0.2:
                    controls_seen = true
        if connected_two and controls_seen and snapshots_seen:
            print("ONLINE_SERVER_PASS: 2 clients, authoritative 40-body simulation, validated steering, snapshots")
            # Keep the server alive while each client checks at least one full
            # second of authoritative state, so test teardown is not a disconnect race.
            for n in range(210):
                await process_frame
            game.net.leave_room()
            game.queue_free()
            quit(0)
            return
    push_error("ONLINE_SERVER_TIMEOUT clients=%d controls=%s frames=%s" % [
        game.net.joined_slots.size(),str(controls_seen),str(snapshots_seen)])
    game.net.leave_room()
    game.queue_free()
    quit(7)
