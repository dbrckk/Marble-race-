extends SceneTree
## Real touch steering across the bridge return, in clean air and with
## four- and ten-marble packs converging at the merge.
const ROUTE = preload("res://scripts/shortcut_route.gd")
const EXIT_CHECKPOINT := 1
enum Traffic { SOLO, DUEL, PACK }

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = preload("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_glacier_bridge_return_career.cfg"
    game.career.unlocked = 3
    assert(game.set_track(1))
    for speed in [16.0,19.0,22.0]:
        for layout in range(3):
            for traffic in [Traffic.SOLO,Traffic.DUEL,Traffic.PACK]:
                game.race_variation = layout
                game.start_race("Grip Tape")
                game.countdown = 0.02
                for frame in range(8):
                    await physics_frame
                assert(game.race_state == "RACING" and game.built_variation == layout)
                assert(await _cross_return(game,speed,traffic),
                    "Glacier layout %d at %.0f m/s with %s traffic" % [
                        layout,speed,Traffic.keys()[traffic]])
                game.return_to_menu()
    game.queue_free()
    for frame in range(4):
        await process_frame
    print("GLACIER_BRIDGE_RETURN_PASS: 27 solo, duel and ten-marble trials across three layouts and speeds")
    quit()

func _cross_return(game: Node3D, speed: float, traffic: Traffic) -> bool:
    var route: Node3D = game.shortcut_route
    var racer: RigidBody3D = game.player
    for marble: RigidBody3D in game.racers:
        if marble != racer:
            marble.freeze = true
    var rivals: Array[RigidBody3D] = []
    var contacts := { "rival": false, "baffle": false }
    if traffic == Traffic.DUEL:
        rivals = _place_rivals(game)
    elif traffic == Traffic.PACK:
        rivals = _place_pack(game)
        assert(rivals.size() == 9)
        var baffle: StaticBody3D = game.board.get_node("Course_10/AntiEdgeBaffle_10_L")
        for marble in [racer]+rivals:
            _watch_pack_contacts(marble,baffle,contacts)
    var alongside := false
    var passed_main_rival := false
    var launch_z := ROUTE.EXIT_Z+10.0
    var tangent: Vector3 = (route.point_at(launch_z-0.7)-route.point_at(launch_z+0.7)).normalized()
    racer.global_position = route.point_at(launch_z)+Vector3.UP*0.68
    racer.linear_velocity = tangent*speed

    var pad: Control = game.ui.touch_controls
    var finger := pad.get_viewport_rect().size*Vector2(0.20,0.83)
    pad._finger_event(1,finger,true)
    var clear_z: float = game.race_director.event_z(1)-2.0
    var frame_budget := 240 if traffic == Traffic.PACK else 210
    var through_shutter: Dictionary = {}
    var field: Array[RigidBody3D] = [racer]
    field.append_array(rivals)
    for frame in range(frame_budget):
        var ahead := racer.position.z-4.0
        var target_x: float = route.point_at(ahead).x
        if ahead <= ROUTE.EXIT_Z:
            var blend := smoothstep(0.0,1.0,(ROUTE.EXIT_Z-ahead)/15.0)
            target_x = lerpf(route.point_at(ROUTE.EXIT_Z).x,game.track_center_at(ahead),blend)
        var axis := clampf((target_x-racer.position.x)*0.25-racer.linear_velocity.x*0.075,-1.0,1.0)
        pad._move_finger(1,finger+Vector2(axis*105.0,0))
        await physics_frame
        if traffic == Traffic.DUEL and racer.position.z < ROUTE.EXIT_Z+1.0 and racer.position.z > clear_z:
            var pace_rival: RigidBody3D = rivals.back()
            var dx := absf(racer.position.x-pace_rival.position.x)
            var dz := racer.position.z-pace_rival.position.z
            if absf(dz) < 1.15 and dx >= 0.79 and dx < 4.0:
                alongside = true
            if dz < -0.80 and alongside:
                passed_main_rival = true
        if traffic == Traffic.PACK:
            for marble in field:
                if not through_shutter.has(marble.racer_id) and marble.position.z < clear_z:
                    through_shutter[marble.racer_id] = true
            if through_shutter.size() == field.size():
                break
        elif racer.eliminated or _all_clear(racer,rivals,clear_z):
            break
    pad._finger_event(1,finger,false)
    if traffic == Traffic.PACK:
        for marble in field:
            assert(not marble.eliminated,"A racer fell during the pack merge")
        assert(through_shutter.size() == field.size(),"All ten marbles must clear the shutter within four seconds")
        assert(contacts["rival"],"The pack must exercise a real marble-to-marble contact at the merge")
        assert(not contacts["baffle"],"Pack contact must not throw a racer into the first left baffle")
        return game.last_checkpoint >= EXIT_CHECKPOINT
    var cleared: bool = _all_clear(racer,rivals,clear_z) and game.last_checkpoint >= EXIT_CHECKPOINT
    # The middle-speed duel places the two routes side by side at the join.
    return cleared and (traffic == Traffic.SOLO or speed != 19.0 or passed_main_rival)

func _all_clear(player: RigidBody3D, rivals: Array[RigidBody3D], z: float) -> bool:
    if player.eliminated or player.position.z >= z or player.linear_velocity.z >= -6.0:
        return false
    for rival in rivals:
        if rival.eliminated or rival.position.z >= z:
            return false
    return true

func _place_rivals(game: Node3D) -> Array[RigidBody3D]:
    var bridge_rival: RigidBody3D
    var main_rivals: Array[RigidBody3D] = []
    for marble: RigidBody3D in game.racers:
        if marble == game.player:
            continue
        if marble.wants_shortcut():
            if bridge_rival == null:
                bridge_rival = marble
        elif main_rivals.size() < 2:
            main_rivals.append(marble)
    var route: Node3D = game.shortcut_route
    bridge_rival.position = route.point_at(ROUTE.EXIT_Z+11.0)+Vector3(0.83,0.68,0)
    bridge_rival.linear_velocity = Vector3(4.2,0,-17.2)
    bridge_rival.freeze = false
    route.entered[bridge_rival.racer_id] = true

    _place_main_rival(game,main_rivals[0],8.4,-2.5,-12.5)
    _place_main_rival(game,main_rivals[1],8.9,0.8,-11.0)
    return [main_rivals[0],bridge_rival,main_rivals[1]]

func _watch_pack_contacts(marble: RigidBody3D, baffle: StaticBody3D, contacts: Dictionary) -> void:
    marble.contact_monitor = true
    marble.max_contacts_reported = 8
    marble.body_entered.connect(func(body: Node):
        if body == baffle:
            contacts["baffle"] = true
        if body is RigidBody3D and absf(marble.position.z-ROUTE.EXIT_Z) <= 8.0:
            contacts["rival"] = true
    )

func _place_pack(game: Node3D) -> Array[RigidBody3D]:
    # Distance upstream, lateral offset, approach speed. The slower front
    # pair makes faster marbles catch up while the two roads are converging.
    var bridge_slots := [Vector3(7.4,0.9,10.0),Vector3(11.5,0.74,18.8),Vector3(12.3,-0.65,21.0)]
    var main_slots := [Vector3(9.8,-2.45,11.0),Vector3(6.4,-1.15,9.0),Vector3(9.3,0.6,16.0),
        Vector3(8.0,2.9,16.5),Vector3(11.5,0.8,21.0),Vector3(10.0,3.7,12.0)]
    var route: Node3D = game.shortcut_route
    var rivals: Array[RigidBody3D] = []
    for marble: RigidBody3D in game.racers:
        if marble == game.player:
            continue
        if marble.wants_shortcut():
            if bridge_slots.is_empty():
                continue
            var slot: Vector3 = bridge_slots.pop_front()
            var z := ROUTE.EXIT_Z+slot.x
            var tangent: Vector3 = (route.point_at(z-0.7)-route.point_at(z+0.7)).normalized()
            marble.position = route.point_at(z)+Vector3(slot.y,0.68,0)
            marble.linear_velocity = tangent*slot.z
            marble.freeze = false
            route.entered[marble.racer_id] = true
        else:
            if main_slots.is_empty():
                continue
            var slot: Vector3 = main_slots.pop_front()
            _place_main_rival(game,marble,slot.x,slot.y,-slot.z)
        rivals.append(marble)
    return rivals

func _place_main_rival(game: Node3D, rival: RigidBody3D, distance: float,
        lateral: float, speed_z: float) -> void:
    var z := ROUTE.EXIT_Z+distance
    rival.position = Vector3(game.track_center_at(z)+lateral,game.height_at(z)+0.48,z)
    rival.linear_velocity = Vector3(0,0,speed_z)
    rival.ai_lane_goal = lateral
    rival.ai_lane_timer = 4.0
    rival.freeze = false
