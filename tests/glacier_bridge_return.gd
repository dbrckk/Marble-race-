extends SceneTree
## Real touch steering across the bridge return, in clean air and with
## four- and ten-marble packs converging at the merge.
const ROUTE = preload("res://scripts/shortcut_route.gd")
const STRATEGY = preload("res://scripts/ai_race_strategy.gd")
const EXIT_CHECKPOINT := 1
const SHUTTER_PHASE_SAMPLES := 12
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
    var passes_after_impact := 0
    for layout in range(3):
        for sample in range(SHUTTER_PHASE_SAMPLES):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.02
            for frame in range(8):
                await physics_frame
            var director: Node3D = game.race_director
            game.race_time = director.period()*float(sample)/SHUTTER_PHASE_SAMPLES
            director.animate(game.race_time)
            var timing := {}
            assert(await _cross_return(game,19.0,Traffic.PACK,timing),
                "Glacier layout %d, shutter phase sample %d" % [layout,sample])
            if timing.get("passed_after_impact",false):
                passes_after_impact += 1
            game.return_to_menu()
    assert(passes_after_impact > 0,"A real shutter impact must leave passing room for following racers")
    for layout in range(3):
        # The middle layout has an earlier shutter. Start its faster pack
        # slightly nearer the join to exercise the merge before that sweep.
        var faster_gap := 2.6 if layout == 1 else 2.8
        for approach in [Vector2(2.5,14.0),Vector2(faster_gap,15.0)]:
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.02
            for frame in range(8):
                await physics_frame
            assert(game.race_state == "RACING" and game.built_variation == layout)
            assert(await _player_merges_into_pack(game,approach.x,approach.y),
                "Glacier layout %d at %.0f m/s must let the player merge without contact" % [
                    layout,approach.y])
            game.return_to_menu()
        for spacing in [2.6,3.0]:
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.02
            for frame in range(8):
                await physics_frame
            assert(await _player_merges_into_pack(game,2.8,15.0,spacing,true),
                "Glacier layout %d must protect the %.1f m queue behind a yielding bot" % [layout,spacing])
            game.return_to_menu()
    for layout in range(3):
        for pace in [15.0,16.0]:
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.02
            for frame in range(8):
                await physics_frame
            assert(game.race_state == "RACING" and game.built_variation == layout)
            assert(await _player_merges_into_pack(game,2.8,pace,3.6,true,true),
                "Glacier layout %d at %.0f m/s must regain pace and respect the passing lane" % [
                    layout,pace])
            game.return_to_menu()
    game.queue_free()
    for frame in range(4):
        await process_frame
    print("GLACIER_BRIDGE_RETURN_PASS: 27 approach trials, 36 shutter-phase trials, %d passes after a real shutter impact, 6 player merges, 6 close queues and 6 merge recoveries without contact" % passes_after_impact)
    quit()

func _cross_return(game: Node3D, speed: float, traffic: Traffic,
        timing: Dictionary = {}) -> bool:
    var route: Node3D = game.shortcut_route
    var racer: RigidBody3D = game.player
    for marble: RigidBody3D in game.racers:
        if marble != racer:
            marble.freeze = true
    var rivals: Array[RigidBody3D] = []
    var contacts := {"rival": false,"baffle": false,"frame": 0,"shutter": {}}
    if traffic == Traffic.DUEL:
        rivals = _place_rivals(game)
    elif traffic == Traffic.PACK:
        rivals = _place_pack(game)
        assert(rivals.size() == 9)
        var baffle: StaticBody3D = game.board.get_node("Course_10/AntiEdgeBaffle_10_L")
        var shutter: AnimatableBody3D = game.race_director.obstacles[game.race_director.GLACIER_RETURN_GATE]
        for marble in [racer]+rivals:
            _watch_pack_contacts(marble,baffle,shutter,contacts)
    var alongside := false
    var passed_main_rival := false
    var launch_z := ROUTE.EXIT_Z+10.0
    var tangent: Vector3 = (route.point_at(launch_z-0.7)-route.point_at(launch_z+0.7)).normalized()
    racer.global_position = route.point_at(launch_z)+Vector3.UP*0.68
    racer.linear_velocity = tangent*speed

    var pad: Control = game.ui.touch_controls
    var finger := pad.get_viewport_rect().size*Vector2(0.20,0.83)
    pad._finger_event(1,finger,true)
    var clear_z: float = game.race_director.event_z(game.race_director.GLACIER_RETURN_GATE)-2.0
    var frame_budget := 240 if traffic == Traffic.PACK else 210
    var through_shutter: Dictionary = {}
    var field: Array[RigidBody3D] = [racer]
    field.append_array(rivals)
    for frame in range(frame_budget):
        contacts["frame"] = frame
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
                    through_shutter[marble.racer_id] = frame
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
        var shutter_hits: Dictionary = contacts["shutter"]
        if not shutter_hits.is_empty():
            var first_hit: int = shutter_hits.values().min()
            for id in through_shutter:
                if through_shutter[id] > first_hit and not shutter_hits.has(id):
                    timing["passed_after_impact"] = true
                    break
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

func _watch_pack_contacts(marble: RigidBody3D, baffle: StaticBody3D,
        shutter: AnimatableBody3D, contacts: Dictionary) -> void:
    marble.contact_monitor = true
    marble.max_contacts_reported = 8
    marble.body_entered.connect(func(body: Node):
        if body == shutter:
            (contacts["shutter"] as Dictionary).get_or_add(marble.racer_id,contacts["frame"])
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


func _player_merges_into_pack(game: Node3D, gap: float, pace: float,
        spacing := 3.6, watch_queue := false, check_recovery := false) -> bool:
    var route: Node3D = game.shortcut_route
    var player: RigidBody3D = game.player
    var rivals: Array[RigidBody3D] = []
    for marble: RigidBody3D in game.racers:
        if marble == player:
            continue
        marble.freeze = true
        if not marble.wants_shortcut() and rivals.size() < 3:
            rivals.append(marble)
    # Begin on the return deck with the same entry state as a bridge rider.
    var launch_z := ROUTE.EXIT_Z+5.0
    var tangent: Vector3 = (route.point_at(launch_z-0.7)-route.point_at(launch_z+0.7)).normalized()
    player.position = route.point_at(launch_z)+Vector3.UP*0.63
    player.linear_velocity = tangent*10.0
    route.entered[player.racer_id] = true
    var lane: float = route.side
    for index in range(rivals.size()):
        _place_main_rival(game,rivals[index],5.0+gap+index*spacing,lane,-(pace+index*1.5))
    var contacts: Array[Node] = []
    player.body_entered.connect(func(body: Node):
        if body is RigidBody3D and body in rivals:
            contacts.append(body)
    )
    if watch_queue:
        for rival in rivals:
            rival.contact_monitor = true
            rival.max_contacts_reported = 8
            rival.body_entered.connect(func(body: Node):
                if body is RigidBody3D and body in rivals:
                    contacts.append(body)
            )
    var pad: Control = game.ui.touch_controls
    var finger := pad.get_viewport_rect().size*Vector2(0.20,0.83)
    pad._finger_event(1,finger,true)
    var director: Node3D = game.race_director
    var gate: int = director.GLACIER_RETURN_GATE
    var clear_z: float = director.event_z(gate)-2.0
    var passing_offset: float = -director.side_at(gate)*STRATEGY.GLACIER_PASS_OFFSET
    var pass_expected := absf(passing_offset-lane) > 1.30
    var crossed: Dictionary = {}
    var approached_merge_at := -1
    var yielding_bot := rivals[1]
    var yielded := false
    var lowest_speed := INF
    var regained_speed := false
    var attempted_pass := false
    var passed := false
    for frame in range(230):
        var ahead := player.position.z-4.0
        var target_x: float = route.point_at(ahead).x
        if ahead <= ROUTE.EXIT_Z:
            var blend := smoothstep(0.0,1.0,(ROUTE.EXIT_Z-ahead)/10.0)
            target_x = lerpf(route.point_at(ROUTE.EXIT_Z).x,game.track_center_at(ahead)+lane,blend)
        var gain := 0.25
        var damping := 0.075
        if approached_merge_at >= 0:
            target_x = game.track_center_at(player.position.z)+lane
            gain = 0.50
            damping = 0.24
            if frame < approached_merge_at+85:
                # A prolonged slowdown gives the bots time to choose a line.
                var brake := clampf((-player.linear_velocity.z-6.5)*20.0+16.0,0.0,28.0)
                player.apply_central_force(Vector3(0,0,brake)*player.mass)
        var axis := clampf((target_x-player.position.x)*gain-player.linear_velocity.x*damping,-1.0,1.0)
        pad._move_finger(1,finger+Vector2(axis*105.0,0))
        await physics_frame
        if check_recovery:
            var player_offset: float = player.position.x-game.track_center_at(player.position.z)
            if approached_merge_at < 0 and player.position.z < ROUTE.EXIT_Z and absf(player_offset-lane) < 1.55:
                approached_merge_at = frame
            yielded = yielded or yielding_bot.glacier_merge_brake_time > 0.0
            if yielded:
                var speed := -yielding_bot.linear_velocity.z
                lowest_speed = minf(lowest_speed,speed)
                regained_speed = regained_speed or speed >= lowest_speed+2.0
                if approached_merge_at >= 0 and frame < approached_merge_at+85:
                    attempted_pass = attempted_pass or yielding_bot.glacier_pass_remaining > 0.0
                if attempted_pass and yielding_bot.position.z < player.position.z-0.85:
                    passed = true
        for marble in [player]+rivals:
            if marble.position.z < clear_z:
                crossed[marble.racer_id] = true
        if not contacts.is_empty() or player.eliminated or (
                crossed.size() == 4 and (not check_recovery or frame > 190)):
            break
    pad._finger_event(1,finger,false)
    var recovery_ok := not check_recovery or (yielded and regained_speed and (
        passed if pass_expected else not attempted_pass))
    return contacts.is_empty() and crossed.size() == 4 and recovery_ok and (
        game.last_checkpoint >= EXIT_CHECKPOINT and not player.eliminated and
        rivals.all(func(marble: RigidBody3D): return not marble.eliminated))
