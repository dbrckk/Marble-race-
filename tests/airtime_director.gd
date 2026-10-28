extends SceneTree
## Real surface probes and deterministic flight/landing trajectories in all
## nine layouts. The feedback layer never edits marble velocity, positions,
## race rewards, purchases, network messages or collision geometry.
const AIR = preload("res://scripts/airtime_director.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(AIR.landing_grade(0.10,0.8,18.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.04,18.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.8,1.0,2.0) == "")
    assert(AIR.landing_grade(0.5,0.8,18.0,2.0) == "PERFECT LANDING")
    assert(AIR.landing_grade(0.95,0.9,18.0,2.0) == "BIG AIR")
    assert(AIR.landing_grade(0.45,0.4,13.0,8.0) == "TOUCHDOWN")
    assert(AIR.landing_grade(NAN,0.9,18.0,2.0) == "")
    var start := Vector3(0.0,1.0,-60.0)
    var velocity := Vector3(0.0,1.8,-15.0)
    for mode in [0,1,2]:
        var base: Dictionary = FEEDBACK.camera_pose(
            start,velocity,0.0,mode,false,-1.0,false,0.0)
        var flight: Dictionary = FEEDBACK.camera_pose(
            start,velocity,0.0,mode,false,-1.0,false,1.0)
        if mode == 0:
            assert((flight["position"] as Vector3).y >
                (base["position"] as Vector3).y and
                float(flight["fov"]) > float(base["fov"]),
                "True jumps should reveal more of the course in chase mode")
        else:
            assert(base == flight,
                "The user's alternate camera angles must not be changed")

    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path = "user://qa_flight_career.cfg"
    stage.career.unlocked = 3
    stage.set_process(false)
    stage.set_physics_process(false)
    assert(stage.airtime != null and stage.airtime.ripple.multimesh.instance_count == 3)
    var checked := 0
    for biome in range(3):
        stage.return_to_menu()
        assert(stage.set_track(biome))
        for layout in range(3):
            stage.race_variation = layout
            stage.start_race("Grip Tape")
            stage.race_state = "RACING"
            assert(stage.built_variation == layout and stage.racers.size() == 40)
            var flight: Node3D = stage.airtime
            var player: RigidBody3D = stage.player
            player.freeze = false
            for marble in stage.racers:
                marble.freeze = true if marble != player else false
            assert(flight.ignored_rids.size() == 40,
                "Physics probes must ignore all marbles, not mistake their tops for road")
            assert(not flight.probe_floor(player).is_empty())
            # Sample a real collision floor, not an invented deck height.
            var z: float = -15.0
            var x: float = stage.track_center_at(z)
            var ground_probe := Vector3(x,stage.height_at(z)+0.48,z)
            player.global_position = ground_probe
            var hit: Dictionary = flight.probe_floor(player)
            assert(hit.has("ground") and hit["touching"],
                "The real board must give a correct marble floor probe")
            # The physics probe is independent of video quality and uses
            # one static ray for the local human, never 40 raycasts per tick.
            for quality in range(3):
                stage.set_graphics_quality(quality)
                assert(flight.ripple.visible == (quality != 0))
                assert(flight.probe_floor(player)["touching"])
            stage.set_graphics_quality(1)
            flight.reset_round()
            var before: Vector3 = player.global_position
            var before_velocity: Vector3 = player.linear_velocity
            assert(flight.ignored_rids.size() == 40)
            var p := Vector3(x,stage.height_at(z)+0.40,z)
            # Prime on a real road. Then take off over 0.6 seconds and
            # land on a REAL ground hit below the player.
            assert(flight.sample_motion(0.05,true,0.0,p,
                Vector3(0,0,-13)).is_empty())
            var earned: Dictionary = {}
            for n in range(10):
                var dt := 0.06
                var height := 0.24+0.67*sin(float(n+1)/11.0*PI)
                var air_pos: Vector3 = p+Vector3(0.0,height,-float(n+1)*0.78)
                var speed_y: float = 3.0 if n < 5 else -3.0
                earned = flight.sample_motion(dt,false,height,air_pos,
                    Vector3(0,speed_y,-13))
                assert(earned.is_empty())
            earned = flight.sample_motion(0.06,true,0.0,
                p+Vector3(0.0,0.0,-8.2),Vector3(0,-3,-13))
            assert(earned.get("grade","") == "PERFECT LANDING" and
                float(earned["seconds"]) >= 0.38,
                "A true timed air arc must receive exactly one valid landing grade")
            assert(flight.landing_count == 1 and flight.perfect_landings == 1)
            assert(flight.sample_motion(0.06,true,0.0,
                p+Vector3(0,0,-9.0),Vector3(0,0,-13)).is_empty() and
                flight.landing_count == 1,
                "Continuous rolling must never farm additional landings")
            flight._show_landing(earned,hit["ground"])
            assert(stage.ui.race_moment_label.text.contains("PERFECT LANDING"))
            assert(flight.ripple_age[0] > 0.0)
            flight.advance_visuals(0.77)
            assert(flight.ripple_age[0] == 0.0)
            # Clear and arm again. A seam hop shorter than 0.125s must
            # produce zero false positives.
            flight.reset_round()
            flight.sample_motion(0.05,true,0.0,p,Vector3(0,0,-13))
            flight.sample_motion(0.05,false,0.04,p+Vector3(0,0.04,-0.6),
                Vector3(0,0.7,-13))
            flight.sample_motion(0.05,true,0.0,p+Vector3(0,0,-1.2),
                Vector3(0,0,-13))
            assert(flight.landing_count == 0)
            # A sudden network correction/teleport cancels any pending
            # airborne achievement, irrespective of vertical speed.
            flight.sample_motion(0.05,false,0.7,p+Vector3(0,0.7,-1.8),
                Vector3(0,2,-13))
            flight.sample_motion(0.05,false,1.1,p+Vector3(0,1.1,-2.4),
                Vector3(0,2,-13))
            assert(flight.sample_motion(0.05,true,0.0,
                p+Vector3(0,0,-48.0),Vector3(0,-2,-13)).is_empty())
            assert(flight.landing_count == 0 and not flight.airborne)
            # A visual callback must never change player racing physics,
            # and no paid item or career credit is awarded here.
            assert(player.global_position.is_equal_approx(before) and
                player.linear_velocity.is_equal_approx(before_velocity))
            assert(stage.race_items.used.is_empty() and
                stage.course_sculptures.earned_apex.is_empty())
            flight.reset_round()
            assert(flight.landing_count == 0 and
                flight.longest_airtime == 0.0 and
                flight.ignored_rids.size() == 40)
            stage.return_to_menu()
            checked += 1
    assert(checked == 9)
    stage.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_flight_career.cfg"))
    print("AIRTIME_PASS: nine real floor probes, safe jump and touchdown arcs, 40 marble exclusion, mobile pooled ripples and physics integrity")
    quit(0)
