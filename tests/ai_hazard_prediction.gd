extends SceneTree
## Real, deterministic moving-gate avoidance: 3 biomes x 3 layouts.
## Tests future collider positions, Forge piston timing, physical steering,
## Android-safe O(3) planning, human authority and real-course integration.
const Strategy = preload("res://scripts/ai_race_strategy.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_ai_gate_prediction.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    assert(Strategy.GATE_LOOKAHEAD <= 22.0,
        "Predictive path scans should stay within readable hazard distance")
    assert(Strategy.GATE_ESCAPE_CLEARANCE > Strategy.GATE_CLEARANCE,
        "Avoidance target must clear a real marble plus barrier")
    var active_cases := 0
    var retracted_cases := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            assert(game.built_variation == layout)
            assert(game.racers.size() == 40)
            var director: Node3D = game.race_director
            assert(director.obstacles.size() == 3)
            var event_index := 1
            var gate_z: float = director.event_z(event_index)
            var distance := 11.0
            var arrival_seconds := distance/12.0
            var elapsed := 0.0
            if biome == 2:
                # The same future piston must be both blocked and open at
                # different elapsed timestamps, without visual-only tricks.
                var found_open := false
                var found_blocked := false
                for sample in range(130):
                    var clock: float = float(sample)*0.08
                    if director.piston_up(event_index,clock+arrival_seconds):
                        elapsed = clock
                        found_blocked = true
                    else:
                        found_open = true
                assert(found_open and found_blocked,
                    "Forge hazard must have genuine timed pass windows")
            var arrival: float = elapsed+arrival_seconds
            var future: Vector3 = director.position_at(event_index,arrival)
            var obstacle_offset: float = future.x-game.track_center_at(gate_z)
            var bounded_preference: float = clampf(obstacle_offset,
                -Strategy.TRAFFIC_SAFE_LANE,Strategy.TRAFFIC_SAFE_LANE)
            var safe: float = Strategy.timed_gate_safe_lane(director,
                gate_z+distance,-12.0,elapsed,obstacle_offset)
            var blocked: bool = biome != 2 or director.piston_up(event_index,arrival)
            if blocked:
                active_cases += 1
                assert(absf(safe-obstacle_offset) >=
                    Strategy.GATE_CLEARANCE-0.01,
                    "AI must leave sufficient clearance for the FUTURE gate position")
                assert(signf(safe-obstacle_offset) == -signf(obstacle_offset),
                    "The escape corridor must lead to the road interior")
                assert(absf(safe) <= Strategy.TRAFFIC_SAFE_LANE,
                    "Avoidance must remain inside real outer guardrails")
            else:
                retracted_cases += 1
                assert(is_equal_approx(safe,bounded_preference),
                    "Retracted Forge piston cannot trigger false avoidance")
            assert(is_equal_approx(safe,Strategy.timed_gate_safe_lane(
                director,gate_z+distance,-12.0,elapsed,obstacle_offset)),
                "AI predictions must be deterministic across client/server ticks")
            assert(is_equal_approx(Strategy.timed_gate_safe_lane(
                director,gate_z+30.0,-12.0,elapsed,obstacle_offset),
                bounded_preference),"Do not dodge an obstacle outside the lookahead")
            # Keep steering until the sphere has cleared the real collider.
            # Dropping avoidance one metre BEFORE contact causes late
            # oscillations and impacts at full speed.
            var crossing_lane: float = Strategy.timed_gate_safe_lane(
                director,gate_z+0.20,-12.0,elapsed,obstacle_offset)
            if biome != 2 or director.piston_up(event_index,elapsed+0.20/12.0):
                assert(absf(crossing_lane-obstacle_offset) >=
                    Strategy.GATE_CLEARANCE-0.01,
                    "Do not abandon the escape line inside the gate footprint")
            assert(is_equal_approx(Strategy.timed_gate_safe_lane(
                director,gate_z-4.0,-12.0,elapsed,obstacle_offset),
                bounded_preference),"Do not steer back toward an already passed gate")
            var opposite: float = -signf(obstacle_offset)*2.5
            assert(is_equal_approx(Strategy.timed_gate_safe_lane(
                director,gate_z+distance,-12.0,elapsed,opposite),opposite),
                "An already-safe opposite lane must not be disturbed")
            # The tactical helper must never write a rigid-body position or
            # speed. Godot's real force integration alone changes velocity.
            var bot: RigidBody3D = null
            for rival in game.racers:
                if not rival.is_player and not rival.wants_shortcut():
                    bot = rival
                    break
            assert(is_instance_valid(bot))
            var approach_z: float = gate_z+distance
            var approach_x: float = game.track_center_at(approach_z)+obstacle_offset
            bot.freeze = false
            bot.sleeping = false
            bot.global_position = Vector3(approach_x,
                game.height_at(approach_z)+0.82,approach_z)
            bot.linear_velocity = Vector3(0,0,-12)
            bot.ai_lane_timer = 2.0
            bot.ai_lane_goal = obstacle_offset
            bot.ai_traffic_timer = 0.0
            var before: Vector3 = bot.global_position
            var human_before: Vector3 = game.player.global_position
            bot.drive(1.0/60.0,elapsed,0.0,false)
            assert(bot.global_position.is_equal_approx(before),
                "AI may apply forces but must not teleport to a safe corridor")
            assert(game.player.global_position.is_equal_approx(human_before),
                "AI anticipation must not modify human inputs or transforms")
            # physics_frame is emitted before Godot integrates the queued
            # central force. Observe the completed physics tick, not the
            # pre-integration rigid-body velocity snapshot.
            await physics_frame
            await physics_frame
            await physics_frame
            if blocked:
                var measured_escape: float = bot.linear_velocity.x*signf(obstacle_offset)
                if measured_escape >= -0.025:
                    print("AI_GATE_STEER_DEBUG biome=",biome," layout=",layout,
                        " z=",approach_z," obstacle_offset=",obstacle_offset,
                        " planned=",safe," vel=",bot.linear_velocity,
                        " bot_x=",bot.global_position.x)
                assert(measured_escape < -0.025,
                    "Real physics must begin moving a threatened AI toward safety")
            game.return_to_menu()
    assert(active_cases >= 6 and retracted_cases >= 0)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_ai_gate_prediction.cfg"))
    print("AI_GATE_PREDICTION_PASS: 3x3 deterministic moving gates, physical escapes, Forge timing, human unchanged")
    quit(0)
