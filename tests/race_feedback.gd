extends SceneTree
## Race feel regression: pure camera math, real scene, audio contacts and HUD.
const RaceFeedback = preload("res://scripts/race_feedback.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var ground := StaticBody3D.new()
    ground.name = "StaticBody3D"
    var wall := StaticBody3D.new()
    wall.name = "AntiEdgeBaffle_Test"
    var peg := StaticBody3D.new()
    peg.name = "ToyPeg"
    var hammer := AnimatableBody3D.new()
    hammer.name = "SwingHammer_Test"
    var opponent := RigidBody3D.new()
    opponent.linear_velocity = Vector3(0.0,0.0,-12.0)
    assert(RaceFeedback.collision_kind(ground) == "surface")
    assert(RaceFeedback.collision_kind(wall) == "bumper")
    assert(RaceFeedback.collision_kind(peg) == "bumper")
    assert(RaceFeedback.collision_kind(hammer) == "mechanism")
    assert(RaceFeedback.collision_kind(opponent) == "glass")
    var roll := Vector3(0.0,-0.3,-18.0)
    assert(RaceFeedback.impact_intensity(roll,ground) == 0.0,
        "Rolling at speed should not trigger a heavy floor impact")
    assert(RaceFeedback.impact_intensity(Vector3(0,-12,-7),ground) > 0.5,
        "A hard downward landing needs a thump")
    assert(RaceFeedback.impact_intensity(Vector3(0,0,-12),opponent) == 0.0,
        "Racers travelling together should not sound like a hard crash")
    assert(RaceFeedback.impact_intensity(Vector3(0,0,10),opponent) > 0.8,
        "Head-on marble collision needs stronger feedback")
    assert(RaceFeedback.impact_intensity(roll,peg) > 0.7)
    assert(RaceFeedback.impact_intensity(roll,hammer) > 0.7)
    assert(RaceFeedback.feedback_interval(0.9) < RaceFeedback.feedback_interval(0.1))
    assert(RaceFeedback.smooth_factor(0.0,5.0) == 0.0)
    assert(RaceFeedback.smooth_factor(1.0,5.0) < 1.0)
    assert(absf(
        (1.0-pow(1.0-RaceFeedback.smooth_factor(1.0/60.0,5.0),60.0))-
        (1.0-pow(1.0-RaceFeedback.smooth_factor(1.0/30.0,5.0),30.0))
    ) < 0.001,"Camera damping must be frame-rate independent")
    for mode in range(3):
        var idle: Dictionary = RaceFeedback.camera_pose(
            Vector3(0,2,-60),Vector3.ZERO,0.0,mode,false,-1.0)
        var fast: Dictionary = RaceFeedback.camera_pose(
            Vector3(0,2,-60),Vector3(7,0,-22),2.0,mode,true,9.0)
        assert((fast["position"] as Vector3).z > -60.0,
            "Camera always follows behind downhill direction")
        assert(float(fast["fov"]) <= RaceFeedback.FOV_MAX)
        assert(float(idle["fov"]) >= RaceFeedback.FOV_MIN)
        assert(float(fast["fov"]) > float(idle["fov"]),
            "Boosting at speed must convey motion without extreme fish-eye")
        assert(is_finite((fast["focus"] as Vector3).length()))
        if mode == 0:
            assert((fast["position"] as Vector3).y >
                (idle["position"] as Vector3).y,
                "Chase camera should lift over a nearby physical hazard")
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.start_race("Grip Tape")
    stage.race_state = "RACING"
    stage.player.freeze = false
    stage.player.linear_velocity = roll
    stage.feedback_cooldown = 0.0
    stage.camera_shake = 0.0
    stage._camera_bump(ground)
    assert(stage.camera_shake == 0.0 and stage.feedback_cooldown == 0.0,
        "Sliding on wood must not shake the chase camera")
    stage._camera_bump(wall)
    assert(stage.camera_shake > 0.0 and stage.camera_shake <= 0.14,
        "Real wall impacts should be visible, capped and short")
    assert(stage.feedback_cooldown > 0.0)
    stage.feedback_cooldown = 0.0
    stage.audio.collision_delay = 0.0
    stage.audio._on_marble_collision(ground)
    assert(stage.audio.collision_delay == 0.0,
        "Surface rolling must use the looping roll track, not impact Foley")
    stage.audio._on_marble_collision(hammer)
    assert(stage.audio.collision_delay > 0.0,
        "Kinetic obstacles need spatially located impact Foley")
    var strength_before: float = stage.camera_shake
    for mode in range(3):
        stage.cam_mode = mode
        stage._update_camera(0.016,true)
        assert(stage.camera.global_position.is_finite())
        assert(stage.camera.global_transform.basis.is_finite())
        assert(stage.camera.fov >= 60.0 and stage.camera.fov <= 80.0)
        assert(stage.camera_shake <= strength_before)
        strength_before = stage.camera_shake
    stage.cam_mode = 0
    stage._update_camera(0.016,true)
    var before: Vector3 = stage.camera.global_position
    stage.player.position += Vector3(0.7,0.0,-1.0)
    stage._update_camera(0.016,false)
    assert(stage.camera.global_position.distance_to(before) < 1.3,
        "A 60Hz frame should not snap the camera as marbles jostle")
    var beacon: Dictionary = stage.hazard_beacons[0]
    stage.player.position.z = float(beacon["z"])+8.0
    stage.player.linear_velocity = Vector3(0,0,-18)
    stage.ui.label_timer = 0.5
    stage.ui.update_hud()
    assert(stage.ui.hazard_label.visible and
        stage.ui.hazard_label.text.contains("s"),
        "Time-to-impact hazard hint must be visible before a gate")
    stage.return_to_menu()
    ground.free()
    wall.free()
    peg.free()
    hammer.free()
    opponent.free()
    stage.queue_free()
    await process_frame
    print("RACE_FEEL_PASS: camera modes, stable damping, impact filtering, spatial Foley, hazard ETA")
    quit()
