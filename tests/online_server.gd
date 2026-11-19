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
    var glacier_layout := OS.get_environment("GLACIER_ONLINE_LAYOUT")
    if glacier_layout.is_valid_int():
        await _glacier_cut_in(game,int(glacier_layout))
        return
    var deadline: int = Time.get_ticks_msec()+40000
    var connected_two := false
    var controls_seen := false
    var snapshots_seen := false
    while Time.get_ticks_msec() < deadline:
        await process_frame
        if game.net.joined_slots.size() >= 2:
            connected_two = true
        if game.net.match_running and game.racers.size() == game.MARBLE_COUNT:
            snapshots_seen = game.net.frame_clock >= 0.0 and game.race_time > 0.3
            for value in game.net.steer_by_slot.values():
                if absf(float(value)) >= 0.2:
                    controls_seen = true
        if connected_two and controls_seen and snapshots_seen:
            await _drive_bridge_fixture(game)
            print("ONLINE_SERVER_PASS: 2 clients, authoritative 30-body simulation, validated steering, bridge snapshots")
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

func _drive_bridge_fixture(game: Node3D) -> void:
    # Drive two distinct replica traces through the normal broadcast path
    # after the authority has already accepted live player inputs.
    var riders: Array[RigidBody3D] = []
    for slot in game.net.joined_slots.values():
        var rider: RigidBody3D = game.racers[int(slot)]
        rider.freeze = true
        rider.collision_layer = 0
        rider.collision_mask = 0
        riders.append(rider)
    for frame in range(388):
        if not game.net.match_running:
            return
        for i in range(riders.size()):
            var z := -43.0-maxf(0.0,float(frame-18))*0.18+float(i)*0.75
            var main_x: float = game.track_center_at(z)
            var deck: Vector3 = game.shortcut_route.point_at(z)
            var blend := smoothstep(0.0,1.0,(-46.0-z)/9.0)
            blend *= smoothstep(0.0,1.0,(z+106.0)/10.0)
            var x := lerpf(main_x,deck.x,blend)
            var height: float = game.height_at(z)
            if absf(x-deck.x) < 1.9:
                height = maxf(height,deck.y+0.28)
            riders[i].global_position = Vector3(x,height+0.40,z)
        await physics_frame

func _glacier_cut_in(game: Node3D, layout: int) -> void:
    game.net.completed_rounds = 1
    game.race_variation = layout
    var deadline := Time.get_ticks_msec()+25000
    while game.race_state != "RACING" and Time.get_ticks_msec() < deadline:
        await physics_frame
    if game.race_state != "RACING" or game.selected_track != 1 or game.built_variation != layout:
        _finish_glacier(game,false,"Glacier round failed to start")
        return

    var slots: Array = game.net.joined_slots.values()
    slots.sort()
    var rider: RigidBody3D = game.racers[slots.back()]
    var bots: Array[RigidBody3D] = []
    for marble: RigidBody3D in game.racers:
        marble.freeze = true
        marble.collision_layer = 0
        marble.collision_mask = 0
        if not marble.wants_shortcut() and not marble.network_controlled and not marble.is_player and bots.size() < 3:
            bots.append(marble)

    var follower := bots[0]
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var start_z := gate_z+11.0
    _place_glacier_racer(game,bots[1],0.0,start_z-7.5,7.0)
    _place_glacier_racer(game,follower,0.0,start_z,16.0)
    _place_glacier_racer(game,bots[2],0.0,start_z+4.6,15.0)
    # Start at the bridge-to-main-track handoff with real authoritative bodies.
    _place_glacier_racer(game,rider,-side*3.45,start_z-2.0,11.0)
    game.shortcut_route.entered[rider.racer_id] = true

    var field: Array[RigidBody3D] = [rider]
    field.append_array(bots)
    var contacts: Array[String] = []
    for marble in field:
        marble.contact_monitor = true
        marble.max_contacts_reported = 8
        marble.body_entered.connect(func(body: Node):
            if body is RigidBody3D and body in field:
                contacts.append("%d/%d" % [marble.racer_id,body.racer_id])
        )

    var committed_at := -1
    var input_at := -1
    var aborted_at := -1
    var crossed: Dictionary = {}
    for frame in range(140):
        await physics_frame
        if committed_at < 0 and follower.glacier_pass_remaining > 0.0:
            committed_at = frame
        var input: Vector2 = game.net.input_for_slot(rider.racer_id)
        if input_at < 0 and input.x*side > 0.3:
            input_at = frame
        if aborted_at < 0 and follower.glacier_abort_remaining > 0.0:
            aborted_at = frame
        for marble in field:
            if marble.position.z < gate_z-3.0:
                crossed[marble.racer_id] = true
        if crossed.size() == field.size() or not contacts.is_empty() or (
                field.any(func(marble: RigidBody3D): return marble.eliminated)):
            break
    var success: bool = rider.network_controlled and committed_at >= 0 and input_at > committed_at and (
        aborted_at > input_at and contacts.is_empty() and crossed.size() == field.size())
    _finish_glacier(game,success,"layout=%d server_ticks pass=%d input=%d abort=%d contacts=%s crossed=%d" % [
        layout,committed_at,input_at,aborted_at,", ".join(contacts),crossed.size()])


func _finish_glacier(game: Node3D, success: bool, details: String) -> void:
    if success:
        print("GLACIER_ONLINE_SERVER_PASS: ",details)
    else:
        push_error("GLACIER_ONLINE_SERVER_FAILED: "+details)
    game.net.leave_room()
    game.queue_free()
    quit(0 if success else 8)


func _place_glacier_racer(game: Node3D, marble: RigidBody3D, lane: float, z: float, speed: float) -> void:
    marble.global_position = Vector3(game.track_center_at(z)+lane,game.height_at(z)+0.46,z)
    marble.linear_velocity = Vector3(0,0,-speed)
    marble.ai_lane_goal = lane
    marble.ai_lane_timer = 4.0
    marble.collision_layer = 1
    marble.collision_mask = 1
    marble.freeze = false
    marble.sleeping = false
