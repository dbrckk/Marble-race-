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
    assert(AUDIO.pack_wind_lift(1.0) <= 2.0 and
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
    for mode in [1,2]:
        normal = FEEDBACK.camera_pose(origin,speed,0.0,mode,false,-1.0,false)
        duel = FEEDBACK.camera_pose(origin,speed,0.0,mode,false,-1.0,true)
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
            game.audio.set_pack_pressure(game.race_moments.pack_pressure)
            game.audio._process(0.5)
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
            game.audio._process(1.0)
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
            game.return_to_menu()
            integrated += 1
    assert(integrated == 9)
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_adaptive_pack_audio.cfg"))
    print("PACK_DYNAMICS_PASS: 9 real courses, 40 marbles, high-deck exclusion, adaptive original audio and duel framing")
    quit(0)
