extends SceneTree
## Real same-level rear-end and passing regression beside the Glacier shutter.
const Strategy = preload("res://scripts/ai_race_strategy.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = preload("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_glacier_shutter_traffic.cfg"
    game.career.unlocked = 3
    assert(game.set_track(1))
    for layout in range(3):
        for gap in [6.0,8.0]:
            await _start_layout(game,layout)
            assert(await _test_passing(game,gap),
                "A real pass with a %.0f m gap must avoid rear contact on Glacier layout %d" % [gap,layout])
            game.return_to_menu()
        for gap in [4.0,6.0]:
            await _start_layout(game,layout)
            assert(await _test_passing(game,gap,true),
                "Glacier layout %d must slow down with a %.0f m gap and an occupied passing lane" % [layout,gap])
            game.return_to_menu()
    game.queue_free()
    for tick in range(4):
        await process_frame
    print("GLACIER_SHUTTER_TRAFFIC_PASS: six real passes and six physical braking runs without rear contact through the shutter")
    quit(0)

func _start_layout(game: Node3D, layout: int) -> void:
    game.race_variation = layout
    game.start_race("Grip Tape")
    game.countdown = 0.02
    for tick in range(8):
        await physics_frame
    assert(game.race_state == "RACING" and game.built_variation == layout)

func _test_passing(game: Node3D, gap: float, occupied := false) -> bool:
    var leader: RigidBody3D = game.player
    var follower: RigidBody3D
    var blocker: RigidBody3D
    for marble in game.racers:
        marble.freeze = true
        marble.collision_layer = 0
        marble.collision_mask = 0
        if marble == leader or marble.wants_shortcut():
            continue
        if follower == null:
            follower = marble
        elif blocker == null:
            blocker = marble
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var lane := side*0.1
    var leader_z := gate_z+1.8
    var follower_z := leader_z+gap
    _place(game,leader,lane,leader_z,1.8)
    _place(game,follower,lane,follower_z,16.0)
    if occupied:
        _place(game,blocker,-side*Strategy.GLACIER_PASS_OFFSET,follower_z-0.7,8.0)

    var contacts: Array[Node] = []
    follower.contact_monitor = true
    follower.max_contacts_reported = 8
    follower.body_entered.connect(func(body: Node):
        if body == leader or (occupied and body == blocker):
            contacts.append(body)
    )
    var entry_speed := 16.0
    var slowed := false
    for frame in range(140):
        await physics_frame
        var speed := -follower.linear_velocity.z
        if occupied and frame < 12:
            assert(follower.glacier_pass_remaining == 0.0,
                "A bot must wait when a rival occupies the passing lane")
        if occupied and speed < entry_speed-3.0:
            slowed = true
        if follower.eliminated or not contacts.is_empty():
            return false
        if occupied and follower.position.z < gate_z-3.0:
            return slowed and speed > 1.0
        if not occupied and follower.position.z < gate_z-1.3 and follower.position.z < leader.position.z-0.78:
            return true
    return false

func _place(game: Node3D, racer: RigidBody3D, lane: float, z: float, speed: float) -> void:
    racer.global_position = Vector3(game.track_center_at(z)+lane,game.height_at(z)+0.46,z)
    racer.collision_layer = 1
    racer.collision_mask = 1
    racer.freeze = false
    racer.sleeping = false
    racer.linear_velocity = Vector3(0,0,-speed)
    racer.ai_lane_goal = lane
    racer.ai_lane_timer = 3.0
