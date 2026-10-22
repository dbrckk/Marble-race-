extends SceneTree
## Purely tactical lane planning: actual physics, stable personalities,
## collision-safe corridor choices, no speed/position cheats or extra nodes.
const Strategy = preload("res://scripts/ai_race_strategy.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    assert(Strategy.TRAFFIC_SCAN_PERIOD >= 0.30,
        "AI must not scan 39 rivals every physics frame")
    for id in range(39):
        for track in range(3):
            for variation in range(3):
                var temperament: int = Strategy.temperament(id,track,variation)
                assert(temperament >= 0 and temperament <= 2)
                assert(Strategy.temperament(id,track,variation) == temperament,
                    "Driving personality cannot depend on client RNG")
            assert(Strategy.temperament(id,track,0) !=
                Strategy.temperament(id,track,1) and
                Strategy.temperament(id,track,1) !=
                Strategy.temperament(id,track,2),
                "Every rematch layout must reshuffle the same AI's temperament")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.start_race("Grip Tape")
    var follower: RigidBody3D = game.racers[1]
    var leader: RigidBody3D = game.racers[2]
    var blocker: RigidBody3D = game.racers[3]
    var human: RigidBody3D = game.player
    for racer in game.racers:
        racer.global_position = Vector3(25,0,12)
    var base_z := 5.0 # Clear start straight: safe for the tactical sampling check.
    var center: float = game.track_center_at(base_z)
    var y: float = game.height_at(base_z)+0.8
    follower.global_position = Vector3(center,y,base_z)
    follower.linear_velocity = Vector3(0,0,-13)
    leader.global_position = Vector3(center,y,base_z-4.0)
    leader.linear_velocity = Vector3(0,0,-6)
    var open_choice: float = Strategy.traffic_lane(
        follower,game.racers,center,0.0,1)
    assert(absf(open_choice) >= 1.3 and absf(open_choice) <= 3.15,
        "A slower rival ahead should make the bot search a safe passing lane")
    assert(Strategy.traffic_lane(
        follower,game.racers,center,0.0,1) == open_choice,
        "The same snapshot must always produce the same steering choice")
    # A competitor already occupying the right passing lane forces the
    # overtaker to use the free left corridor instead of a three-marble pile.
    blocker.global_position = Vector3(center+1.55,y,base_z-3.0)
    blocker.linear_velocity = Vector3(0,0,-10)
    var free_left: float = Strategy.traffic_lane(
        follower,game.racers,center,0.0,1)
    assert(free_left < -1.3,
        "Tactical planning must avoid an occupied right corridor")
    # A lateral mover can enter a passing corridor before the bot gets
    # there. Predict the occupied lane without granting AI a speed cheat.
    blocker.global_position = Vector3(center+2.85,y,base_z-3.0)
    blocker.linear_velocity = Vector3(-3.5,0,-10)
    var merging_left: float = Strategy.traffic_lane(
        follower,game.racers,center,0.0,1)
    assert(merging_left < -1.3,
        "A rival moving laterally into the right lane must block that overtake")
    blocker.linear_velocity = Vector3.ZERO
    # A fast rival approaching from behind should not be cut off by
    # a new overtaking move into its corridor. It is a real marble
    # with a measured closing velocity, not a scripted obstacle.
    blocker.global_position = Vector3(center+1.55,y,base_z+3.0)
    blocker.linear_velocity = Vector3(0,0,-24)
    follower.linear_velocity = Vector3(0,0,-12)
    var protected_rear: float = Strategy.traffic_lane(
        follower,game.racers,center,0.0,1)
    assert(protected_rear < -1.3,
        "AI must avoid the right lane when a faster marble approaches behind")
    # A multi-level intersection is not same-lane traffic.
    blocker.global_position.y += 5.0
    leader.global_position.y += 5.0
    var bridge: float = Strategy.traffic_lane(
        follower,game.racers,center,0.2,1)
    assert(is_equal_approx(bridge,0.2),
        "Traffic on a separate elevation must not change AI intent")
    leader.global_position.y = y
    blocker.global_position.x = center+15.0
    follower.linear_velocity = Vector3(0,0,-4)
    leader.linear_velocity = Vector3(0,0,-12)
    leader.global_position.z = base_z-7.0
    assert(is_equal_approx(Strategy.traffic_lane(
        follower,game.racers,center,0.3,1),0.3),
        "A leader moving faster than the bot is not an urgent obstacle")
    # No wall clipping, even when the preferred sinusoidal lane is too wide.
    leader.linear_velocity = Vector3(0,0,-2)
    for preferred in [-30.0,-3.6,0.0,3.6,30.0]:
        var target: float = Strategy.traffic_lane(
            follower,game.racers,center,preferred,2)
        assert(absf(target) <= Strategy.TRAFFIC_SAFE_LANE+0.001,
            "Passing intent must remain in the existing physical guardrails")
    # Do not destabilize the crowded start or either shortcut portal.
    # Full 3D traffic decisions begin only after the last fork merges.
    follower.ai_traffic_timer = 0.0
    follower.ai_lane_timer = 2.0
    follower.ai_lane_goal = 0.0
    var human_timer: float = human.ai_traffic_timer
    follower.drive(0.016,5.0,0.0,false)
    assert(follower.ai_traffic_timer == 0.0,
        "Opening pack must preserve the physically tested racing line")
    var final_z := -135.0
    var final_center: float = game.track_center_at(final_z)
    var final_hazard: Dictionary = game.upcoming_hazard(final_z)
    assert(final_hazard.is_empty() or (
        float(final_hazard["distance"]) >= 3.5),
        "Later overtaking test needs a real clear corridor")
    follower.global_position = Vector3(final_center,
        game.height_at(final_z)+0.8,final_z)
    follower.ai_traffic_timer = 0.0
    follower.ai_lane_timer = 2.0
    follower.ai_lane_goal = 0.0
    var before: Vector3 = follower.position
    follower.drive(0.016,5.0,0.0,false)
    assert(follower.position.is_equal_approx(before),
        "AI planner must not teleport racers across the course")
    assert(follower.ai_traffic_timer > 0.25,
        "Final-half passing decisions must cache the lane between physics frames")
    assert(human.ai_traffic_timer == human_timer,
        "A remote or local human must retain direct steering")
    # Near a physical guard the new planner must deliberately fall back
    # to the old, already validated obstacle-navigation behavior.
    var gate_z := -30.0
    var gate_center: float = game.track_center_at(gate_z)
    var gate_hint: Dictionary = game.upcoming_hazard(gate_z)
    assert(not gate_hint.is_empty() and float(gate_hint["distance"]) < 3.5,
        "Regression needs a real guard close ahead")
    follower.global_position = Vector3(gate_center,
        game.height_at(gate_z)+0.8,gate_z)
    follower.ai_traffic_timer = 0.0
    follower.ai_lane_timer = 2.0
    follower.ai_lane_goal = 0.0
    follower.drive(0.016,5.0,0.0,false)
    assert(follower.ai_traffic_timer == 0.0,
        "AI must abandon new passing plans beside a real hazard")
    follower.teleport_to_start(Vector3(center,y,0))
    assert(follower.ai_traffic_timer == 0.0 and
        follower.ai_traffic_goal == 0.0 and
        follower.ai_traffic_offset == 0.0,
        "Rematches and recoveries must clear old tactical decisions")
    game.return_to_menu()
    game.queue_free()
    await process_frame
    print("AI_TRAFFIC_PASS: deterministic tactical passes, open lanes, safe bounds, human authority, cached scans")
    quit(0)
