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
    # Banked racing-line perception must remain optical only: no forced
    # marble rotation and no motion in overhead/alternate camera modes.
    assert(RaceFeedback.camera_roll(0.0,0.0,2.0,0) == 0.0)
    assert(RaceFeedback.camera_roll(8.0,19.0,2.4,0) < 0.0)
    assert(RaceFeedback.camera_roll(-8.0,19.0,-2.4,0) > 0.0)
    assert(absf(RaceFeedback.camera_roll(100.0,40.0,12.0,0)) <=
        RaceFeedback.CAMERA_ROLL_LIMIT,
        "Camera-only bank must stay below 2.6 degrees")
    assert(RaceFeedback.camera_roll(8.0,19.0,2.4,1) == 0.0 and
        RaceFeedback.camera_roll(8.0,19.0,2.4,2) == 0.0,
        "Overhead and manual alternate cameras cannot inherit chase roll")
    assert(RaceFeedback.camera_roll(NAN,19.0,2.4,0) == 0.0,
        "Invalid movement readings cannot tilt the Android camera")
    assert(RaceFeedback.feedback_interval(0.9) < RaceFeedback.feedback_interval(0.1))
    assert(RaceFeedback.smooth_factor(0.0,5.0) == 0.0)
    assert(RaceFeedback.smooth_factor(1.0,5.0) < 1.0)
    assert(absf(
        (1.0-pow(1.0-RaceFeedback.smooth_factor(1.0/60.0,5.0),60.0))-
        (1.0-pow(1.0-RaceFeedback.smooth_factor(1.0/30.0,5.0),30.0))
    ) < 0.001,"Camera damping must be frame-rate independent")
    # At race pace, the camera must reveal a gate earlier than at slow
    # speed. The horizon is bounded and invalid network/physics readings
    # cannot produce NaN camera transforms.
    assert(RaceFeedback.hazard_preview_weight(24.0,24.0) > 0.0)
    assert(RaceFeedback.hazard_preview_weight(24.0,4.0) == 0.0)
    assert(RaceFeedback.hazard_preview_weight(12.0,18.0) >
        RaceFeedback.hazard_preview_weight(24.0,18.0))
    assert(RaceFeedback.hazard_preview_weight(100.0,24.0) == 0.0)
    assert(RaceFeedback.hazard_preview_weight(-1.0,24.0) == 0.0)
    assert(RaceFeedback.hazard_preview_weight(12.0,NAN) == 0.0)
    assert(RaceFeedback.hazard_preview_weight(NAN,24.0) == 0.0)
    var fast_preview: Dictionary = RaceFeedback.camera_pose(
        Vector3(0,2,-50),Vector3(0,0,-24),0.0,0,false,24.0)
    var slow_preview: Dictionary = RaceFeedback.camera_pose(
        Vector3(0,2,-50),Vector3(0,0,-4),0.0,0,false,24.0)
    assert(float(fast_preview["risk"]) > float(slow_preview["risk"]))
    assert((fast_preview["position"] as Vector3).y >
        (RaceFeedback.camera_pose(
            Vector3(0,2,-50),Vector3(0,0,-24),0.0,0,false,-1.0
        )["position"] as Vector3).y)
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
    # The new 3D route has hills tall enough to obscure the traditional
    # flat-course lookahead. Preserve the original sightline on descents,
    # but lift it above a real crest without changing racing physics.
    var low := Vector3(2.0,-2.0,-76.0)
    var safe: Vector3 = RaceFeedback.terrain_safe_focus(low,1.45)
    assert(absf(safe.y-(1.45+RaceFeedback.TERRAIN_LOOK_CLEARANCE)) < 0.001,
        "The camera must aim above a physical hill")
    var naturally_high := Vector3(2.0,8.0,-76.0)
    assert(RaceFeedback.terrain_safe_focus(naturally_high,1.45) ==
        naturally_high,"Do not over-raise an already safe focus")
    var camera_low := Vector3(-1.0,0.5,-72.0)
    assert(RaceFeedback.terrain_safe_camera(camera_low,2.1).y >=
        2.1+RaceFeedback.CAMERA_GROUND_CLEARANCE-0.001,
        "Camera may not sink into a hill behind the player")
    assert(RaceFeedback.terrain_safe_camera(naturally_high,1.45) ==
        naturally_high,"Keep high camera poses stable")
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
    if not _verify_race_mix(stage,opponent,hammer):
        quit(1)
        return
    var strength_before: float = stage.camera_shake
    for mode in range(3):
        stage.cam_mode = mode
        stage._update_camera(0.016,true)
        assert(stage.camera.global_position.is_finite())
        assert(stage.camera.global_transform.basis.is_finite())
        assert(stage.camera.fov >= 60.0 and stage.camera.fov <= 80.0)
        assert(stage.camera_shake <= strength_before)
        strength_before = stage.camera_shake
    assert(stage.showroom_roof.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
        "The overhead camera must see the road through the ceiling while keeping its shadow")
    stage.cam_mode = 0
    stage._update_camera(0.016,true)
    assert(stage.showroom_roof.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
        "The roof should return when switching back to the chase camera")
    var before: Vector3 = stage.camera.global_position
    # Inspect the actual integrated follow camera near the strongest terrain
    # profile: the lookahead must stay above local collidable ground.
    for track in range(3):
        stage.selected_track = track
        stage.player.position = Vector3(stage.track_center_at(-84.0),
            stage.height_at(-84.0)+0.8,-84.0)
        stage.camera_shake = 0.0
        stage._update_camera(0.016,true)
        assert(stage.camera_lookahead.y >=
            stage.height_at(stage.camera_lookahead.z)+
            RaceFeedback.TERRAIN_LOOK_CLEARANCE-0.01,
            "Live camera must look above the actual 3D surface in every biome")
        assert(stage.camera.global_position.y >=
            stage.height_at(stage.camera.global_position.z)+
            RaceFeedback.CAMERA_GROUND_CLEARANCE-0.02,
            "Live camera position must clear the 3D hill in every biome")
    # Restore the original track and camera path before the smooth-follow test.
    stage.selected_track = 0
    stage.player.position = Vector3(0,stage.height_at(-84.0)+0.8,-84.0)
    stage._update_camera(0.016,true)
    before = stage.camera.global_position
    stage.player.position += Vector3(0.7,0.0,-1.0)
    stage._update_camera(0.016,false)
    assert(stage.camera.global_position.distance_to(before) < 1.3,
        "A 60Hz frame should not snap the camera as marbles jostle")
    assert(RaceFeedback.chase_forward_step(-12.0,1.0/60.0) == 0.0,
        "Recovery teleports must still use normal camera damping")
    stage.player.linear_velocity = Vector3(0,0,-23)
    for fps: int in [30,60]:
        var delta := 1.0/float(fps)
        stage.player.position.z = -64.0
        stage._update_camera(delta,true)
        for frame in fps:
            stage.player.position.z -= 23.0*delta
            stage._update_camera(delta)
        var target: Dictionary = RaceFeedback.camera_pose(stage.player.global_position,
            stage.player.linear_velocity,stage.track_center_at(stage.player.position.z-12.0),
            0,false,float(stage.upcoming_hazard(stage.player.position.z).get("distance",-1.0)))
        var offset: float = stage.camera.global_position.z-target["position"].z
        print("CHASE_DAMPING ",fps,"FPS ",offset,"m")
        assert(absf(offset) < 1.25,"Chase camera must stay near its desired offset at speed")
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

func _verify_race_mix(stage: Node3D, opponent: RigidBody3D, hammer: Node3D) -> bool:
    var sound: Node3D = stage.audio
    sound._reset_priority_mix()
    stage.player.linear_velocity = Vector3(0,0,-18)
    for frame in range(40):
        sound._process(0.10)
    var open_wind: float = sound.air.volume_db
    var board_roll: float = sound.rolling.volume_db
    sound.set_pack_pressure(1.0)
    for frame in range(35):
        sound._process(0.10)
    var crowded_wind: float = sound.air.volume_db
    assert(crowded_wind < open_wind-2.9 and is_equal_approx(sound.rolling.volume_db,board_roll))
    assert(sound.rolling is AudioStreamPlayer and sound.bridge_rolling is AudioStreamPlayer)

    var next_voice: int = (sound.current_channel+1)%sound.channels.size()
    sound.race_moment("overtake")
    assert(sound.current_channel == next_voice,"One clean pass uses one short cue")
    sound._process(0.04)
    assert(sound.air.volume_db < crowded_wind-1.0)
    assert(is_equal_approx(sound.rolling.volume_db,board_roll))

    opponent.linear_velocity = Vector3(0,0,-12.5)
    sound._on_marble_collision(opponent)
    var soft_impact: float = sound.last_impact_intensity
    assert(soft_impact >= 0.14 and soft_impact < 0.25 and sound.collision_duck < 0.1)
    sound._on_marble_collision(hammer)
    assert(sound.last_impact_intensity > soft_impact+0.5,
        "A strong obstacle hit must survive a recent light glass tap")
    sound._process(0.05)
    assert(sound.air.volume_db < crowded_wind-3.0)

    sound.warn_timed_gate(0,true)
    next_voice = sound.current_channel
    sound.race_moment("overtake")
    assert(sound.current_channel == next_voice,"Predictive warnings have priority over pass cues")
    sound._process(0.05)
    assert(sound.air.volume_db < crowded_wind-3.5)
    for frame in range(20):
        sound._process(0.10)
    assert(absf(sound.air.volume_db-crowded_wind) < 0.1 and sound.pass_mix_seconds == 0.0)
    sound.set_pack_pressure(0.0)
    assert(stage.player.linear_velocity == Vector3(0,0,-18))
    return true
