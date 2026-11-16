extends SceneTree
## Real same-level braking and overtaking beside the Glacier shutter.
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
        for gap in [3.0,3.4,4.0]:
            await _start_layout(game,layout)
            assert(await _test_queue(game,gap),
                "Three Glacier bots must brake and recover in order at %.1f m on layout %d" % [gap,layout])
            game.return_to_menu()
        await _start_layout(game,layout)
        assert(await _test_reopening(game),
            "Glacier layout %d must reopen a pass without a rear-end collision" % layout)
        game.return_to_menu()
    for layout in range(3):
        for approach in [Vector2(2.4,4),Vector2(2.7,14),Vector2(2.55,19)]:
            await _start_layout(game,layout)
            assert(await _test_cut_in(game,approach.x,int(approach.y)),
                "Glacier layout %d must abort without contact when a rival cuts in after %d ticks" % [
                    layout,int(approach.y)])
            game.return_to_menu()
    game.queue_free()
    for tick in range(4):
        await process_frame
    print("GLACIER_SHUTTER_TRAFFIC_PASS: six passes, six braking runs, nine queues, three reopened passes and nine cut-ins without contact")
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
    var bots := _isolate_bots(game,2)
    var follower := bots[0]
    var blocker := bots[1]
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

func _test_queue(game: Node3D, gap: float) -> bool:
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var start_z := gate_z+0.6
    var lane := side*0.1
    var bots := _isolate_bots(game,5)
    _place(game,game.player,lane,start_z,0.15)
    var approach_speeds := [12.5,15.0,17.0]
    for index in range(3):
        _place(game,bots[index],lane,start_z+gap*(index+1),approach_speeds[index])
    _place(game,bots[3],-side*Strategy.GLACIER_PASS_OFFSET,start_z+gap*1.2,7.0)
    _place(game,bots[4],-side*Strategy.GLACIER_PASS_OFFSET,start_z+gap*2.6,9.0)

    var contacts: Array[Node] = []
    for bot in bots:
        _watch_queue_contacts(bot,game.player,bots,contacts)
    var slowest := approach_speeds.duplicate()
    var exited := 0
    for frame in range(150):
        await physics_frame
        if not contacts.is_empty():
            return false
        for index in range(3):
            var bot := bots[index]
            if bot.eliminated:
                return false
            var speed := -bot.linear_velocity.z
            slowest[index] = minf(slowest[index],speed)
            if index >= exited and bot.position.z < gate_z-3.0:
                if index != exited or slowest[index] > approach_speeds[index]-3.0 or (
                    speed < slowest[index]+1.0):
                    return false
                exited += 1
        if exited == 3:
            return true
    return false

func _isolate_bots(game: Node3D, count: int) -> Array[RigidBody3D]:
    var bots: Array[RigidBody3D] = []
    for marble in game.racers:
        marble.freeze = true
        marble.collision_layer = 0
        marble.collision_mask = 0
        if bots.size() < count and not marble.is_player and not marble.wants_shortcut():
            bots.append(marble)
    return bots

func _watch_queue_contacts(bot: RigidBody3D, player: RigidBody3D,
        bots: Array[RigidBody3D], contacts: Array[Node]) -> void:
    bot.contact_monitor = true
    bot.max_contacts_reported = 8
    bot.body_entered.connect(func(body: Node):
        if body is RigidBody3D and (body == player or body in bots):
            contacts.append(body)
    )

func _place(game: Node3D, racer: RigidBody3D, lane: float, z: float, speed: float) -> void:
    racer.global_position = Vector3(game.track_center_at(z)+lane,game.height_at(z)+0.46,z)
    racer.collision_layer = 1
    racer.collision_mask = 1
    racer.freeze = false
    racer.sleeping = false
    racer.linear_velocity = Vector3(0,0,-speed)
    racer.ai_lane_goal = lane
    racer.ai_lane_timer = 3.0

func _test_reopening(game: Node3D) -> bool:
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var bots := _isolate_bots(game,3)
    var lead: RigidBody3D = game.player
    var first := bots[0]
    var rear := bots[1]
    var blocker := bots[2]
    _place(game,lead,side*0.08,gate_z+5.0,0.2)
    _place(game,first,side*0.08,gate_z+8.85,15.0)
    _place(game,rear,side*0.08,gate_z+11.85,17.0)
    _place(game,blocker,-side*Strategy.GLACIER_PASS_OFFSET,gate_z+8.45,20.0)
    var contacts: Array[Node] = []
    for bot in bots:
        _watch_queue_contacts(bot,lead,bots,contacts)
    var first_committed := false
    var completed := false
    var slowed := false
    for frame in range(205):
        # Simulate a sustained slowdown using force, then release it. The
        # blocker opens the passing lane by racing away under its own drive.
        if frame < 100:
            var brake := clampf((-lead.linear_velocity.z-2.3)*16.0+15.0,0.0,24.0)
            lead.apply_central_force(Vector3(0,0,brake)*lead.mass)
        await physics_frame
        if not contacts.is_empty() or first.eliminated or rear.eliminated:
            return false
        slowed = slowed or -first.linear_velocity.z < 11.0
        if first.glacier_pass_remaining > 0.0:
            if not slowed or frame < 12:
                return false
            first_committed = true
        if rear.glacier_pass_remaining > 0.0 and not completed:
            return false
        if first_committed and first.position.z < lead.position.z-0.78:
            completed = true
        if completed and rear.position.z < gate_z-2.5:
            return first.position.z < gate_z-1.3
    return false


func _test_cut_in(game: Node3D, advance: float, delay: int) -> bool:
    var leader: RigidBody3D = game.player
    var bots := _isolate_bots(game,2)
    var follower := bots[0]
    var rival := bots[1]
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var follower_z := gate_z+11.0
    var passing_lane := -side*Strategy.GLACIER_PASS_OFFSET
    var outer_lane := -side*3.5
    _place(game,leader,side*0.08,follower_z-7.5,2.7)
    _place(game,follower,side*0.08,follower_z,16.0)
    _place(game,rival,outer_lane,follower_z-advance,13.0)
    var contacts: Array[Node] = []
    for bot in bots:
        _watch_queue_contacts(bot,leader,bots,contacts)
    var committed_at := -1
    var cut_in_at := -1
    var cancelled := false
    var entered_lane := false
    for frame in range(100):
        if committed_at >= 0 and frame == committed_at+delay:
            cut_in_at = frame
        var rival_lane := passing_lane if cut_in_at >= 0 else outer_lane
        # Apply a steering force to the moving rival after the pass starts.
        # Its position and all contacts remain under the race physics.
        rival.ai_lane_goal = rival_lane
        var rival_center: float = game.track_center_at(rival.position.z)
        var lateral_force := clampf(
            (rival_center+rival_lane-rival.position.x)*25.0-rival.linear_velocity.x*6.0,-36.0,36.0)
        rival.apply_central_force(Vector3(lateral_force,0,0)*rival.mass)
        await physics_frame
        if not contacts.is_empty() or follower.eliminated or rival.eliminated:
            return false
        if committed_at < 0 and follower.glacier_pass_remaining > 0.0:
            committed_at = frame
        if cut_in_at >= 0:
            if not cancelled and follower.glacier_pass_remaining <= 0.0:
                cancelled = true
            if not cancelled and frame-cut_in_at >= 12:
                return false
            var rival_offset: float = rival.position.x-game.track_center_at(rival.position.z)
            entered_lane = entered_lane or absf(rival_offset-passing_lane) < 0.45
        if follower.position.z < gate_z-4.0 and rival.position.z < gate_z-4.0:
            return cancelled and entered_lane
    return false
