extends SceneTree
## Authentic opponent-pack audio and camera tension. Real 40-marble scene,
## nine biome/layout combinations, same-height checks and zero physics cheats.
const MOMENTS = preload("res://scripts/race_moments.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")
const AUDIO = preload("res://scripts/audio.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    assert(MOMENTS.genuine_pack_rival(2.0,1.2,0.2,13.0,12.0))
    assert(not MOMENTS.genuine_pack_rival(2.0,1.2,3.0,13.0,12.0),
        "A rival on a higher physical bridge cannot raise crowd tension")
    assert(not MOMENTS.genuine_pack_rival(2.0,1.2,0.2,0.0,12.0),
        "Parked player must not receive a fabricated race-pack soundtrack")
    assert(not MOMENTS.genuine_pack_rival(11.0,1.2,0.2,13.0,12.0))
    assert(not MOMENTS.genuine_pack_rival(1.0,4.2,0.2,13.0,12.0))
    assert(not MOMENTS.genuine_pack_rival(NAN,1.2,0.2,13.0,12.0))
    assert(MOMENTS.pack_intensity(0) == 0.0 and
        MOMENTS.pack_intensity(2) == 0.5 and
        MOMENTS.pack_intensity(40) == 1.0,
        "The 40-marble crowd detector must saturate at four true rivals")
    assert(AUDIO.pack_percussion_lift(0.0) == 0.0 and
        AUDIO.pack_percussion_lift(1.0) <= 5.5)
    assert(AUDIO.pack_wind_trim(1.0) == 3.0 and
        AUDIO.pack_percussion_lift(NAN) == 0.0)
    var speed := Vector3(0.0,0.0,-16.0)
    var origin := Vector3(0.0,1.0,-83.0)
    var normal: Dictionary = FEEDBACK.camera_pose(
        origin,speed,0.0,0,false,-1.0,false)
    var duel: Dictionary = FEEDBACK.camera_pose(
        origin,speed,0.0,0,false,-1.0,true)
    assert((duel["position"] as Vector3).y >
        (normal["position"] as Vector3).y and
        (duel["position"] as Vector3).z >
        (normal["position"] as Vector3).z and
        float(duel["fov"]) > float(normal["fov"]),
        "The chase camera should show a little more of a REAL close duel")
    var crowded: Dictionary = FEEDBACK.camera_pose(
        origin,speed,0.0,0,false,4.0,true,0.0,0.0,1.0)
    var approach: Dictionary = FEEDBACK.camera_pose(
        origin,speed,0.0,0,false,4.0,true)
    assert((crowded["position"] as Vector3).y > (approach["position"] as Vector3).y and
        crowded["focus"] == approach["focus"],
        "A dense pack raises the chase view over the same approach line")
    assert(FEEDBACK.camera_pose(origin,speed,0.0,0,false,-1.0,true,0.0,0.0,1.0) == duel,
        "Crowd framing must stay idle outside an obstacle approach")
    for mode in [1,2]:
        normal = FEEDBACK.camera_pose(origin,speed,0.0,mode,false,-1.0,false)
        duel = FEEDBACK.camera_pose(origin,speed,0.0,mode,false,-1.0,true,0.0,0.0,1.0)
        assert(duel == normal,
            "Manual overhead camera angles may not be silently overridden")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.career.save_path = "user://qa_adaptive_pack_audio.cfg"
    game.career.unlocked = 3
    var integrated := 0
    for track in range(3):
        game.return_to_menu()
        assert(game.set_track(track))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout and game.racers.size() == 40)
            var bend_z: float = [-128.0,-43.0,-113.0][track]
            assert(game.race_moments.approach_turn_weight(bend_z,19.0,false) > 0.45)
            assert(game.race_moments.approach_turn_weight(bend_z,2.0,false) == 0.0)
            assert(game.race_moments.approach_turn_weight(-6.0,19.0,false) < 0.1)
            assert(game.race_moments.approach_turn_weight(-55.0,19.0,true) >
                game.race_moments.approach_turn_weight(-55.0,19.0,false)+0.25,
                "Follow the actual bridge bend rather than the main course below it")
            var player: RigidBody3D = game.player
            var z := -82.0
            var center: float = game.track_center_at(z)
            var deck: float = game.height_at(z)+0.8
            for rival in game.racers:
                if rival != player:
                    rival.global_position = Vector3(80.0,deck,20.0)
                    rival.linear_velocity = Vector3.ZERO
                    rival.finished = false
            player.global_position = Vector3(center,deck,z)
            player.freeze = false
            player.linear_velocity = Vector3(0.0,0.0,-13.0)
            for i in range(4):
                var rival: RigidBody3D = game.racers[i]
                rival.global_position = Vector3(
                    center+[1.35,-1.4,2.3,-2.7][i],deck,
                    z+[-0.4,0.65,-2.0,3.2][i])
                rival.linear_velocity = Vector3(0.0,0.0,-12.4)
            # A fifth apparent challenger belongs to another bridge.
            game.racers[4].global_position = Vector3(
                center+0.9,deck+4.0,z-0.6)
            game.racers[4].linear_velocity = Vector3(0.0,0.0,-13.0)
            for sample in range(6):
                game.race_moments.tick(0.12)
            assert(game.race_moments.nearby_pack_count == 4 and
                game.race_moments.pack_pressure == 1.0,
                "Four real moving opponents must fill the local pack score")
            assert(game.race_moments.side_by_side_active,
                "The normal race duel tracker must still work during pack audio")
            assert(game.race_director.awarded.is_empty() and
                game.race_items.used.is_empty(),
                "A cosmetic music/camera cue cannot mint race rewards")
            game.audio.enabled = true
            game.audio.race_active = true
            game.audio.set_pack_pressure(game.race_moments.pack_pressure)
            # Warm the *actual* pooled audio mixer to the playing target.
            # Otherwise a track still fading in from silence would be
            # mistakenly judged louder AFTER the pack disperses.
            for audio_frame in range(55):
                game.audio._process(0.12)
            assert(game.audio.pack_pressure_target == 1.0 and
                game.audio.pack_pressure > 0.80,
                "Soundtrack tension should respond smoothly to verified traffic")
            var loud_pace: float = game.audio.percussion.volume_db
            # Move the same rival spheres up to the elevated bridge: none
            # is physically close enough to count as same-deck traffic.
            for i in range(5):
                game.racers[i].global_position.y = deck+5.0
            game.race_moments.tick(0.12)
            assert(game.race_moments.nearby_pack_count == 0 and
                game.race_moments.pack_pressure == 0.0,
                "Elevated roads must not spoof local sound intensity")
            game.audio.set_pack_pressure(game.race_moments.pack_pressure)
            for audio_frame in range(12):
                game.audio._process(0.12)
            assert(game.audio.pack_pressure < 0.05 and
                game.audio.percussion.volume_db < loud_pace,
                "The soundtrack must relax when actual competitors disperse")
            # A player-only chase camera cannot change collision geometry
            # or override steering: the three user-controlled modes persist.
            var position_before: Vector3 = player.global_position
            var velocity_before: Vector3 = player.linear_velocity
            game.cam_mode = 0
            game._update_camera(0.016,true)
            assert(player.global_position.is_equal_approx(position_before) and
                player.linear_velocity.is_equal_approx(velocity_before))
            game.race_moments.reset_round()
            assert(game.race_moments.nearby_pack_count == 0 and
                game.race_moments.pack_pressure == 0.0 and
                not game.race_moments.side_by_side_active,
                "A rematch must clear all cinematic pack state")
            game.audio.menu_music()
            assert(game.audio.pack_pressure_target == 0.0 and
                game.audio.pack_pressure == 0.0,
                "The menu cannot inherit a crowded finish-line soundtrack")
            if not _verify_obstacle_pointer(game):
                quit(1)
                return
            if track == 1:
                assert(await _verify_shutter_mark(game))
                assert(await _verify_glacier_exit_gap(game))
            if track == 1 and layout == 0 and not await _verify_evasion(game):
                quit(1)
                return
            if layout == 0 and not _verify_exit_speed(game):
                quit(1)
                return
            game.return_to_menu()
            integrated += 1
    assert(integrated == 9)
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_adaptive_pack_audio.cfg"))
    print("PACK_DYNAMICS_PASS: 9 real courses, 40 marbles, high-deck exclusion, adaptive original audio and duel framing")
    print("PACK_OBSTACLE_READABILITY_PASS: 9 layouts, real obstacle projection, sightline overlap and touch-safe clearance")
    print("GLACIER_CENTER_MARK_PASS: batched real road paint and occlusion-only camera overlay on three layouts")
    print("GLACIER_EXIT_GAP_PASS: three layouts at 23 m/s, shutter priority, touch HUD and downstream collision")
    print("EVASION_PREVIEW_PASS: real moving gate, projected lane, downstream physical obstruction and stale cue cleanup")
    print("EXIT_SPEED_PASS: grounded recovery, consecutive obstacles, stable speed, turbo and round reset")
    quit(0)

func _verify_obstacle_pointer(game: Node3D) -> bool:
    var body: StaticBody3D = game.hazard_beacons[3]["body"]
    var target := body.global_position
    var z := target.z+10.0
    var player: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    var locator: Control = game.ui.player_locator
    player.global_position = Vector3(target.x,game.height_at(z)+0.42,z)
    player.linear_velocity = Vector3(0.0,0.0,-16.0)
    game.cam_mode = 0
    game._update_camera(0.1,true)
    var eye: Vector3 = game.camera.global_position
    assert(game.pack_hazard_ahead(player.global_position,player.linear_velocity).is_equal_approx(target))
    rival.global_position = eye.lerp(target,0.95)
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(game.race_moments.occluded_hazard.is_equal_approx(target) and locator.hazard_center.is_finite())
    assert(locator.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(locator.hazard_center.is_equal_approx(game.camera.unproject_position(target)-Vector2(0,21)))
    rival.global_position.x -= 2.0
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(not locator.hazard_center.is_finite() and not game.race_moments.occluded_hazard.is_finite())
    rival.global_position = eye.lerp(target,0.95)
    game.race_moments.tick(0.12)
    game.cam_mode = 1
    locator.refresh(0.12)
    assert(not locator.hazard_center.is_finite())
    game.cam_mode = 0
    game.race_moments.reset_round()
    assert(not game.race_moments.occluded_hazard.is_finite())
    var director: Node3D = game.race_director
    var gate_z: float = director.event_z(0)
    var found_gate := false
    for sample in range(12):
        var time: float = director.period()*float(sample)/12.0
        director.animate(time)
        var gate: Vector3 = director.position_at(0,time+0.30)
        var approach := Vector3(gate.x,game.height_at(gate_z+4.8)+0.42,gate_z+4.8)
        var ahead: Vector3 = game.pack_hazard_ahead(approach,player.linear_velocity)
        if ahead.is_finite() and is_equal_approx(ahead.z,gate_z):
            found_gate = true
            break
    assert(found_gate,"The timed obstacle is announced on a blocking approach")
    return true

func _verify_shutter_mark(game: Node3D) -> bool:
    for frame in range(4):
        await physics_frame
    var guide: Node3D = game.jump_guides
    assert(guide.baked and guide.shutter_marks.size() >= 2)
    var mark: Vector3 = guide.shutter_marks.back()
    var z := mark.z+7.0
    var player: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    for marble in game.racers:
        if marble == player:
            continue
        marble.freeze = true
        marble.global_position = Vector3(80,0,30)
    player.global_position = Vector3(mark.x,game.height_at(z)+0.39,z)
    player.linear_velocity = Vector3(0,0,-12)
    game.cam_mode = 0
    game._update_camera(0.10,true)
    var eye: Vector3 = game.camera.global_position
    assert(guide.shutter_mark_ahead(z).is_equal_approx(mark))
    game.race_moments.reset_round()
    game.race_moments.tick(0.12)
    var locator: Control = game.ui.player_locator
    locator.refresh(0.12)
    assert(not game.race_moments.occluded_shutter_mark.is_finite() and not locator.evasion_center.is_finite())
    rival.global_position = eye.lerp(mark,0.95)
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(game.race_moments.occluded_shutter_mark.is_equal_approx(mark) and (
        locator.evasion_center.is_finite() and locator.evasion_tint == guide.SHUTTER_INK),
        "A rival in the sightline should raise the same road mark above the pack")
    assert(locator.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    game.cam_mode = 1
    locator.refresh(0.12)
    assert(not locator.evasion_center.is_finite(),"Other cameras retain the world paint")
    game.cam_mode = 0
    rival.global_position.x += 2.0
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(not locator.evasion_center.is_finite())
    game.race_moments.reset_round()
    assert(not game.race_moments.occluded_shutter_mark.is_finite())
    return true

func _verify_glacier_exit_gap(game: Node3D) -> bool:
    for frame in range(4):
        await physics_frame
    var layout: int = game.built_variation
    var director: Node3D = game.race_director
    var player: RigidBody3D = game.player
    var gate_z: float = game.glacier_first_shutter_z
    var distance: float = [2.5,6.9,8.9][layout]
    var z := gate_z+distance
    var x: float = game.track_center_at(z)+[-0.8,2.0,1.2][layout]
    var at := Vector3(x,game.height_at(z)+0.39,z)
    var velocity := Vector3(-2.6 if layout < 2 else 2.6,0.0,-23.0)
    var phase: float = director.period()*(5.0/12.0 if layout == 2 else 0.0)
    director.animate(phase)
    game.cam_mode = 0
    game.airtime.reset_round()
    player.global_position = at
    player.linear_velocity = velocity
    game.race_moments.reset_round()
    game.race_moments.tick(0.12)
    var threat: Dictionary = game.race_moments.glacier_exit_threat
    var lane: Vector3 = game.race_moments.evasion_target
    assert(not threat.is_empty() and lane.is_finite() and game.race_moments.glacier_gap_marked)
    assert(signf(lane.x-at.x) == (-1.0 if layout < 2 else 1.0))
    game._update_camera(0.016,true)
    game.ui.label_timer = 0.25
    game.ui.update_hud()
    assert(game.ui.timed_gate_label.visible and game.ui.timed_gate_label.text.contains(
        "GAP LEFT" if layout < 2 else "GAP RIGHT"))
    assert(game.ui.player_locator.evasion_center.is_finite())

    var shutter: int = director.GLACIER_FIRST_SHUTTER
    var straight := Vector3(0.0,0.0,-23.0)
    var shutter_blocks := false
    for phase_step in range(24):
        var clock: float = director.period()*float(phase_step)/24.0
        director.animate(clock)
        var shutter_position: Vector3 = director.position_at(shutter,clock+distance/23.0)
        var blocked_at := Vector3(shutter_position.x,at.y,z)
        var blocked_threat: Dictionary = game.glacier_exit_threat(blocked_at,straight)
        if blocked_threat.is_empty():
            continue
        assert(director.glacier_shutter_threatens_crossing(shutter,distance/23.0,23.0,blocked_at.x,0.0))
        assert(not game.glacier_exit_lane(blocked_at,straight,blocked_threat).is_finite())
        shutter_blocks = true
        break
    assert(shutter_blocks)
    director.animate(phase)
    game.airtime.ice_touching = true
    assert(not game.glacier_exit_lane(at,velocity,threat).is_finite())
    game.airtime.ice_touching = false

    var blocked_z := lane.z-1.5
    var barrier: Node3D = game._box(game.board,Vector3(game.track_center_at(blocked_z),
        game.height_at(blocked_z)+1.10,blocked_z),Vector3(12.0,2.2,0.35),null,true,false,false)
    for frame in range(3):
        await physics_frame
    player.global_position = at
    player.linear_velocity = velocity
    game.race_moments.tick(0.12)
    assert(not game.race_moments.glacier_gap_marked and not game.race_moments.evasion_target.is_finite(),
        "A collision behind the first blocker must withhold the opening")
    barrier.queue_free()
    game.race_moments.reset_round()
    assert(not game.race_moments.glacier_gap_marked)
    return true

func _verify_evasion(game: Node3D) -> bool:
    for frame in range(4):
        await physics_frame
    var director: Node3D = game.race_director
    var index := 1
    var gate_z: float = director.event_z(index)
    var velocity := Vector3(0,0,-21)
    var at := Vector3.INF
    var lane := Vector3.INF
    for distance in [15.0,19.0,22.0]:
        for sample in range(8):
            var time: float = director.period()*float(sample)/8.0
            director.animate(time)
            var gate: Vector3 = director.position_at(index,time+distance/21.0)
            at = Vector3(gate.x,game.height_at(gate_z+distance)+0.42,gate_z+distance)
            var hazard: Vector3 = game.pack_hazard_ahead(at,velocity)
            if not hazard.is_finite() or not is_equal_approx(hazard.z,gate_z):
                continue
            lane = game.evasion_lane(at,velocity,hazard)
            if lane.is_finite():
                break
        if lane.is_finite():
            break
    assert(lane.is_finite(),"A verified path exists on the real Glacier shutter approach")
    game.player.global_position = at
    game.player.linear_velocity = velocity
    game.race_moments.reset_round()
    game.race_moments.tick(0.12)
    assert(game.race_moments.evasion_target.is_equal_approx(lane))
    game._update_camera(0.016,true)
    game.ui.player_locator.refresh(0.12)
    assert(game.ui.player_locator.evasion_center.is_finite())

    var z := gate_z-4.0
    var barrier: Node3D = game._box(game.board,Vector3(game.track_center_at(z),
        game.height_at(z)+1.10,z),Vector3(12.0,2.2,0.5),null,true,false,false)
    for frame in range(3):
        await physics_frame
    game.player.global_position = at
    game.player.linear_velocity = velocity
    game.race_moments.tick(0.12)
    game.ui.player_locator.refresh(0.12)
    assert(not game.race_moments.evasion_target.is_finite() and (
        not game.ui.player_locator.evasion_center.is_finite()),
        "The first gate's lane must be withheld when a second real obstacle blocks it")
    barrier.queue_free()
    return true

func _verify_exit_speed(game: Node3D) -> bool:
    var moments: RefCounted = game.race_moments
    var first: float = game.hazard_beacons[3]["z"]
    var second: float = game.hazard_beacons[4]["z"]
    assert(first > second and first-second < 8.5)
    var ground_z := -11.0
    var player: RigidBody3D = game.player
    player.freeze = false
    player.global_position = Vector3(game.track_center_at(ground_z)+0.67,
        game.height_at(ground_z)+0.44,ground_z)
    player.linear_velocity = Vector3(0.0,0.0,-13.0)
    game.airtime.clear_motion()
    game.airtime.tick_physics(0.06)
    assert(game.airtime.course_grounded)
    var grounded: bool = game.airtime.course_grounded
    moments.reset_round()
    moments.sample_obstacle_exit(first+7.0,13.0,first,grounded,false)
    moments.sample_obstacle_exit(first-1.6,9.4,second,grounded,false)
    moments.sample_obstacle_exit(second+1.0,10.1,second,grounded,false)
    assert(moments.exit_speed_weight() == 0.0)
    moments.sample_obstacle_exit(second-1.4,10.1,INF,grounded,false)
    moments.sample_obstacle_exit(second-2.4,10.1,INF,grounded,false)
    assert(moments.exit_speed_weight() == 0.0)
    moments.sample_obstacle_exit(second-3.6,10.7,INF,grounded,false)
    assert(moments.exit_speed_weight() == 0.0)
    moments.sample_obstacle_exit(second-4.8,11.1,INF,grounded,false)
    assert(is_equal_approx(moments.exit_speed_weight(),1.0))
    game.ui.update_hud()
    assert(game.ui.speed_label.self_modulate.g > game.ui.speed_label.self_modulate.r)
    moments.sample_obstacle_exit(second-5.9,11.8,INF,grounded,true)
    assert(moments.exit_speed_weight() == 0.0)
    moments.sample_obstacle_exit(first+6.0,13.0,first,grounded,false)
    moments.sample_obstacle_exit(first-1.6,9.4,INF,false,false)
    assert(not is_finite(moments.exit_gate_z))
    moments.reset_round()
    assert(moments.exit_speed_weight() == 0.0)
    return true
