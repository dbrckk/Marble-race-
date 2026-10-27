extends SceneTree
## A skill-based moving-obstacle duel in all 9 actual track layouts.
## Precision and streaks must be physically earned and remain identical
## for human and AI bodies; signed online events only render feedback.
const DIRECTOR = preload("res://scripts/race_director.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(DIRECTOR.precision_grade(1.43,16.0) > DIRECTOR.PRECISION_THRESHOLD,
        "A fast near-clearance pass is a real precision skill event")
    assert(DIRECTOR.precision_grade(1.90,8.0) <
        DIRECTOR.PRECISION_THRESHOLD,
        "Slower wide passes still earn normal events, not precision")
    assert(DIRECTOR.precision_grade(1.10,16.0) == 0.0,
        "Physical contact cannot be misreported as an earned clean pass")
    assert(DIRECTOR.precision_grade(2.60,16.0) == 0.0,
        "Distant marbles cannot generate a precision near miss")
    assert(DIRECTOR.precision_grade(1.43,-3.0) == 0.0,
        "Reverse driving cannot farm precision rewards")
    assert(DIRECTOR.precision_grade(NAN,16.0) == 0.0,
        "Invalid geometry must not mint velocity")
    assert(DIRECTOR.earned_impulse(0.0,1) >= 1.6 and
        DIRECTOR.earned_impulse(1.0,3) <= 3.0,
        "Maximum precision momentum remains a bounded small reward")
    assert(DIRECTOR.earned_impulse(0.9,3) >
        DIRECTOR.earned_impulse(0.9,2) and
        DIRECTOR.earned_impulse(0.9,2) >
        DIRECTOR.earned_impulse(0.9,1),
        "A second and third earned gate must reward precision streaks")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_precision_gate_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var verified_gates := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout and game.racers.size() == 40)
            var director: Node3D = game.race_director
            var human: RigidBody3D = game.player
            human.freeze = false
            human.sleeping = false
            assert(director.precision_streak.is_empty())
            assert(director.flash_events == 0)
            var last_strength := 0.0
            for gate in range(3):
                var t: float = 3.0+float(gate)*7.0
                if biome == 2:
                    var found := false
                    for attempt in range(120):
                        var candidate: float = t+float(attempt)*0.05
                        if director.piston_up(gate,candidate):
                            t = candidate
                            found = true
                            break
                    assert(found,"Forge precision gates must be genuinely raised")
                director.animate(t)
                var body: AnimatableBody3D = director.obstacles[gate]
                var before: Vector3 = human.global_position
                var contact: Vector3 = body.global_position
                var side: float = director.side_at(gate)
                human.global_position = contact+Vector3(
                    -side*1.43,0.75,-1.0)
                human.linear_velocity = Vector3(0.0,0.0,-16.0)
                human.angular_velocity = Vector3.ZERO
                var position_before: Vector3 = human.global_position
                var vel_before: Vector3 = human.linear_velocity
                var saved_awards: int = director.awarded.size()
                # Client replicas cannot generate movement or progression.
                game.net.role = "client"
                game.net.match_running = true
                director.tick(game.racers,game.net)
                assert(director.awarded.size() == saved_awards and
                    human.linear_velocity.is_equal_approx(vel_before),
                    "Online client cannot mint earned obstacle impulses")
                game.net.role = "offline"
                game.net.match_running = false
                director.tick(game.racers,game.net)
                var key := "%d:%d" % [gate,human.racer_id]
                assert(director.awarded.has(key),"A real moving-body near miss must be awarded")
                assert(director.last_award_grade[key] >=
                    DIRECTOR.PRECISION_THRESHOLD)
                assert(director.precision_streak.get(human.racer_id,0) == gate+1,
                    "Three distinct real gates should make a three-step skill chain")
                assert(director.last_award_strength[key] > last_strength,
                    "Successive physical precision gates earn bounded extra impulse")
                last_strength = director.last_award_strength[key]
                assert(director.flash_events == gate+1,
                    "Only a real earned player pass lights the existing mobile ring")
                assert(human.global_position.is_equal_approx(position_before),
                    "Near-miss code must apply forces, never teleport the marble")
                var expected_label: String = "PRECISION PASS" if gate == 0 else (
                    "PRECISION STREAK")
                assert(game.ui.checkpoint_label.text.contains(expected_label),
                    "Actual skill must have readable immediate Android feedback")
                director.animate(t+0.06)
                var ordinary_scale: float = 1.10+0.13*sin(
                    (t+0.06)*TAU/director.period()+float(gate)*1.7)
                assert(director.warning_rings[gate].scale.x >
                    ordinary_scale+0.25,
                    "A real earned event must visibly enlarge its animated ring above its biome baseline")
                var count: int = director.awarded.size()
                director.tick(game.racers,game.net)
                assert(director.awarded.size() == count,
                    "Standing beside the same gate cannot repeatedly farm streaks")
                verified_gates += 1
            assert(director.precision_streak[human.racer_id] == 3)
            director.reset_round()
            assert(director.awarded.is_empty() and
                director.precision_streak.is_empty() and
                director.last_award_strength.is_empty() and
                director.flash_events == 0,
                "All skill, glow and reward state resets on each rematch")
            game.net.role = "client"
            game.net.match_running = true
            var close: Vector3 = director.obstacles[2].global_position
            human.global_position = close+Vector3(0.0,0.75,-0.8)
            var velocity_before: Vector3 = human.linear_velocity
            game.net._course_event_notice("near_miss_chain")
            assert(director.flash_events == 1 and
                game.ui.checkpoint_label.text.contains("PRECISION STREAK"),
                "A verified server skill event should appear without client physics")
            assert(human.linear_velocity.is_equal_approx(velocity_before) and
                director.awarded.is_empty(),
                "Remote notification cannot create an authoritative skill reward")
            game.net.role = "offline"
            game.net.match_running = false
            game.return_to_menu()
    assert(verified_gates == 27,
        "All three timed colliders must be checked in nine physical course layouts")
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_precision_gate_career.cfg"))
    print("PRECISION_GATES_PASS: 27 physical gate passes, 3-step skill streaks, 9 layouts, no client authority, touch-safe ring")
    quit(0)
