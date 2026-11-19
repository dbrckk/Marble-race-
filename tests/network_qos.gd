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
    net.local_slot = 29
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
    if not _verify_local_replica_velocity(game,net) or not _verify_opening_replica_guidance(game,net):
        quit(1)
        return
    print("NETWORK_QOS_PASS: RTT, snapshot-only visual speed, staleness, teleport rejection and session reset")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)

func _verify_local_replica_velocity(game: Node3D, net: Node) -> bool:
    net.role = "client"
    net.local_slot = 29
    net._begin_round(0,0,PackedInt32Array([29]))
    var packet := PackedFloat32Array()
    for racer: RigidBody3D in game.racers:
        var at := racer.global_position
        packet.append_array(PackedFloat32Array([at.x,at.y,at.z,0,0,0,1,0,0]))
    var local_z: int = net.local_slot*net.FLOATS_PER_RACER+2
    var rival: RigidBody3D = game.racers[28]
    var rival_x: int = rival.racer_id*net.FLOATS_PER_RACER
    net._receive_snapshot(packet,1.0,PackedFloat32Array())
    assert(not net.local_replica_velocity().is_finite(),"One snapshot cannot establish speed")
    assert(not net.replica_velocity(rival).is_finite())
    packet[local_z] -= 1.4
    packet[rival_x] += 0.25
    packet[rival_x+2] -= 0.70
    net._receive_snapshot(packet,1.1,PackedFloat32Array())
    assert(is_equal_approx(net.local_replica_velocity().z,-14.0))
    assert(net.replica_velocity(rival).is_equal_approx(Vector3(2.5,0.0,-7.0)))
    net.snapshot_age_seconds = net.PRESENTATION_MAX_AGE+0.05
    assert(not net.local_replica_velocity().is_finite(),"Stalls cannot keep an old roll alive")
    assert(not net.replica_velocity(rival).is_finite())
    packet[local_z] -= 25.0
    net._receive_snapshot(packet,1.2,PackedFloat32Array())
    assert(not net.local_replica_velocity().is_finite(),"A correction is not a crossing")
    packet[local_z] -= 1.2
    net._receive_snapshot(packet,1.3,PackedFloat32Array())
    assert(not net.local_replica_velocity().is_finite(),"Wait for the visible replica to catch up")
    game.player.global_position = net.targets[net.local_slot].origin
    assert(is_equal_approx(net.local_replica_velocity().z,-12.0))
    net.leave_room()
    assert(not net.local_replica_velocity().is_finite())
    assert(not net.replica_velocity(rival).is_finite())
    return true

func _verify_opening_replica_guidance(game: Node3D, net: Node) -> bool:
    net.role = "client"
    net.local_slot = 29
    net._begin_round(2,2,PackedInt32Array([29,28]))
    game.race_state = "RACING"
    game.ui.hide_countdown()
    var art: MeshInstance3D = game.opening_obstacle_art
    var gap: Vector2 = art.entry_gaps[0]
    var x := art.global_position.x+(gap.x+gap.y)*0.5
    var z: float = art.entry_z+5.8
    var velocity := Vector3(0,0,-10.0)
    var at := Vector3(x,game.height_at(z)+0.45,z)
    var rival_at := Vector3(x+1.8,game.height_at(z-1.65)+0.45,z-1.65)
    var packet := PackedFloat32Array()
    for i in range(game.MARBLE_COUNT):
        packet.append_array([80.0,0.0,20.0,0.0,0.0,0.0,1.0,0.0,0.0])
    var player_slot: int = net.local_slot*net.FLOATS_PER_RACER
    var rival_slot: int = 28*net.FLOATS_PER_RACER
    _write_position(packet,player_slot,at-velocity*0.1)
    _write_position(packet,rival_slot,rival_at-velocity*0.1)
    net._receive_snapshot(packet,1.0,PackedFloat32Array())
    _write_position(packet,player_slot,at)
    _write_position(packet,rival_slot,rival_at)
    net._receive_snapshot(packet,1.1,PackedFloat32Array())
    game.player.position = at
    game.racers[28].position = rival_at
    game.race_moments.tick(0.12)
    assert(game.race_moments.live_opening_guidance(at,net.local_replica_velocity()).get("target",Vector3.INF).is_finite())
    net.snapshot_age_seconds = net.PRESENTATION_MAX_AGE+0.01
    assert(game.race_moments.live_opening_guidance(at,net.local_replica_velocity()).is_empty())
    net.leave_room()
    return true

func _write_position(packet: PackedFloat32Array, index: int, at: Vector3) -> void:
    packet[index] = at.x
    packet[index+1] = at.y
    packet[index+2] = at.z
