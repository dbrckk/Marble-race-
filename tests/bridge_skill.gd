extends SceneTree
## Nine-layout authoritative three-gate precision run on real elevated roads.
## Tests actual stage/rigid-body objects, collision markers, anti-farming,
## a valid local human, ordinary AI and a display-only network client.
const BYPASS = preload("res://scripts/shortcut_route.gd")

func _initialize() -> void:
    call_deferred("_check")

func _entry(road: Node3D, marble: RigidBody3D, game: Node3D) -> void:
    var start: Vector3 = road.point_at(BYPASS.ENTRY_Z-8.0)
    marble.global_position = start+Vector3.UP*0.68
    marble.linear_velocity = Vector3(0.0,0.0,-12.0)
    road.tick(0.016,game.racers,game.net)
    assert(road.entered.has(marble.racer_id),
        "Only a real physical fork entrant may earn bridge precision rewards")

func _cross(road: Node3D, marble: RigidBody3D, game: Node3D,
        gate: int, side_error: float = 0.0, elevation: float = 0.68,
        speed: float = 13.0) -> void:
    var gate_z: float = float(BYPASS.BRIDGE_POST_Z[gate])
    var before: Vector3 = road.point_at(gate_z+0.30)
    var after: Vector3 = road.point_at(gate_z-0.20)
    marble.linear_velocity = Vector3(0.0,0.0,-speed)
    marble.global_position = before+Vector3(side_error,elevation,0.0)
    road.tick(0.016,game.racers,game.net)
    marble.global_position = after+Vector3(side_error,elevation,0.0)
    road.tick(0.016,game.racers,game.net)

func _check() -> void:
    assert(BYPASS.BRIDGE_POST_Z.size() == 3)
    assert(BYPASS.EFFECT_WINDOW_FAR < BYPASS.BRIDGE_POST_Z[2])
    assert(BYPASS.valid_precision_line(0.0,0.68,13.0,0.50))
    assert(not BYPASS.valid_precision_line(1.5,0.68,13.0,0.50))
    assert(not BYPASS.valid_precision_line(0.0,2.80,13.0,0.50))
    assert(not BYPASS.valid_precision_line(0.0,0.68,2.0,0.50))
    assert(not BYPASS.valid_precision_line(0.0,0.68,13.0,8.0))
    assert(not BYPASS.valid_precision_line(NAN,0.68,13.0,0.50))

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_three_bridge_gates.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var passes := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout and game.racers.size() == 40)
            var road: Node3D = game.shortcut_route
            var marks := road.get_node_or_null(
                "BypassPrecisionSkillStripes") as MultiMeshInstance3D
            assert(is_instance_valid(marks) and
                marks.multimesh.instance_count == 3 and
                marks.get_child_count() == 0)
            assert(marks.cast_shadow ==
                GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
            var human: RigidBody3D = game.player
            var ai: RigidBody3D = game.racers[0]
            human.freeze = false
            ai.freeze = false

            # A remote player cannot award any local progress or impulse.
            game.net.role = "client"
            game.net.match_running = true
            var frozen_velocity: Vector3 = human.linear_velocity
            human.global_position = road.point_at(
                BYPASS.BRIDGE_POST_Z[0])+Vector3.UP*0.68
            road.tick(0.016,game.racers,game.net)
            assert(road.precision_progress.is_empty() and
                human.linear_velocity.is_equal_approx(frozen_velocity))
            game.net.role = "offline"
            game.net.match_running = false

            _entry(road,human,game)
            for gate in range(3):
                _cross(road,human,game,gate)
                assert(road.bridge_gate_count(human.racer_id) == gate+1,
                    "Three physical gates must be earned in exact forward order")
                assert(not road.precision_failed.has(human.racer_id))
            assert(road.precision_complete.has(human.racer_id))
            assert(game.ui.checkpoint_label.text.contains("PERFECT BRIDGE"),
                "Final skill gate must have an Android-visible racing cue")
            var earned_count: int = road.bridge_gate_count(human.racer_id)
            _cross(road,human,game,2)
            assert(road.bridge_gate_count(human.racer_id) == earned_count,
                "Repeating a gate must never farm skill or impulse rewards")

            # A real AI competitor may complete the same three gates.
            _entry(road,ai,game)
            for gate in range(3):
                _cross(road,ai,game,gate)
            assert(road.precision_complete.has(ai.racer_id) and
                road.bridge_gate_count(ai.racer_id) == 3,
                "The skill challenge must never be human-only pay-to-win")

            # Rematches clear all transient server skill state.
            road.reset_round()
            assert(road.precision_complete.is_empty() and
                road.precision_progress.is_empty() and
                road.precision_last_z.is_empty() and
                road.precision_failed.is_empty())
            assert(road.bridge_gate_count(human.racer_id) == 0)

            # Slow, off-center or teleported approaches fail closed.
            _entry(road,human,game)
            _cross(road,human,game,0,0.0,0.68,1.0)
            assert(road.bridge_gate_count(human.racer_id) == 0 and
                road.precision_failed.has(human.racer_id),
                "Moving slowly through the opening is not an earned racing line")
            road.reset_round()
            _entry(road,human,game)
            _cross(road,human,game,0,1.38)
            assert(road.precision_failed.has(human.racer_id))
            road.reset_round()
            _entry(road,human,game)
            _cross(road,human,game,0,0.0,3.10)
            assert(road.precision_failed.has(human.racer_id),
                "A marble flying too high above the physical bridge is invalid")
            road.reset_round()
            _entry(road,human,game)
            human.linear_velocity = Vector3(0.0,0.0,-13.0)
            human.global_position = road.point_at(
                BYPASS.BRIDGE_POST_Z[0]+3.0)+Vector3.UP*0.68
            road.tick(0.016,game.racers,game.net)
            human.global_position = road.point_at(
                BYPASS.BRIDGE_POST_Z[0]-0.2)+Vector3.UP*0.68
            road.tick(0.016,game.racers,game.net)
            assert(road.precision_failed.has(human.racer_id),
                "Position jumps and skipped track segments must not count")
            road.reset_round()

            # A signed server course-event notice displays text only.
            game.net.role = "client"
            game.net.match_running = true
            human.linear_velocity = Vector3(0.0,0.0,-10.0)
            frozen_velocity = human.linear_velocity
            game.net._course_event_notice("bridge_perfect")
            assert(human.linear_velocity.is_equal_approx(frozen_velocity) and
                road.precision_complete.is_empty(),
                "No online client event may alter race physics or skill counters")
            game.net.role = "offline"
            game.net.match_running = false
            passes += 1
            game.return_to_menu()

    assert(passes == 9)
    game.queue_free()
    for frame in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_three_bridge_gates.cfg"))
    print("BRIDGE_SKILL_PASS: 27 consecutive real gates over 9 layouts, authentic AI fairness, tamper-resistant replay and client-only presentation")
    quit(0)
