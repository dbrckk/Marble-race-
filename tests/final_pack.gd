extends SceneTree
## A dense pack can stop racers against the final posts even with the
## ordinary recovery impulse. Run all layouts through that contact at 60 Hz.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_final_pack_career.cfg"
    game.career.unlocked = 3
    for biome in range(3):
        assert(game.set_track(biome))
        for layout in range(3):
            assert(await _run_pack(game,biome,layout,37.0))
    # Enter earlier to exercise the Woodworks spring-post pocket and
    # the Glacier crest with the original collision and mechanism phases.
    assert(game.set_track(0))
    assert(await _run_pack(game,0,2,51.0))
    assert(game.set_track(1))
    assert(await _run_pack(game,1,0,51.0))
    assert(game.set_track(0))
    assert(_check_clearance_modes(game,0,2,"PhysicalPinballKickers/PinballKicker_1_L",-130.55))
    assert(game.set_track(1))
    assert(_check_clearance_modes(game,1,0,"Course_14/RideableCrest_14",-158.5))
    assert(game.set_track(2))
    # All solo Forge variants now move the final crest beyond the bank;
    # network matches retain the deployed collider position.
    for layout in range(3):
        assert(_check_clearance_modes(game,2,layout,
            "Course_14/RideableCrest_14",-158.5))
    assert(_check_clearance_modes(game,2,0,"Course_12/SwingHammer_12",-137.6,1.0))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_final_pack_career.cfg"))
    game.queue_free()
    for frame in range(4):
        await process_frame
    print("FINAL_PACK_PASS: nine layouts and two earlier approaches with 40 real marbles")
    quit()

func _check_clearance_modes(game: Node3D, biome: int, layout: int,
        obstacle_path: String, online_z: float, min_change := 2.0) -> bool:
    game.race_variation = layout
    game.start_race("Grip Tape")
    var solo_z: float = game.board.get_node(obstacle_path).position.z
    assert(absf(solo_z-online_z) > min_change,"Solo must space the obstacle away from the jam")
    game.return_to_menu()
    game.net.role = "client"
    game.net._begin_round(biome,layout,PackedInt32Array())
    assert(is_equal_approx(game.board.get_node(obstacle_path).position.z,online_z),
        "A match on the same layout must rebuild the deployed server's geometry")
    game.net.leave_room()
    game.race_variation = layout
    game.start_race("Grip Tape")
    assert(is_equal_approx(game.board.get_node(obstacle_path).position.z,solo_z),
        "The solo rematch must restore the clearance")
    game.return_to_menu()
    return true

func _run_pack(game: Node3D, biome: int, layout: int, approach_distance: float) -> bool:
    game.race_variation = layout
    game.start_race("Grip Tape")
    game.countdown = 0.01
    while game.race_state == "COUNTDOWN":
        await physics_frame
    # Isolate the last obstacle while retaining normal collisions,
    # AI, hazard timing and the real finish-line check. Keep the
    # pack rolling after the human has finished for this measurement.
    game.set_process(false)
    assert(game.racers.size() == game.MARBLE_COUNT)
    for index in range(game.racers.size()):
        var racer: RigidBody3D = game.racers[index]
        var z: float = game.FINISH_Z+approach_distance+floorf(index/8.0)*1.3
        var x: float = game.track_center_at(z)+(float(index%8)-3.5)*1.27
        racer.position = Vector3(x,game.height_at(z)+0.62,z)
        racer.linear_velocity = Vector3(0.0,0.0,-18.0)
    for tick in range(1,3601):
        game.race_time = tick/60.0
        await physics_frame
        if game.racer_finish_order.size() == game.racers.size():
            break
    var finishers: int = game.racer_finish_order.size()
    print("FINAL_PACK course=%d layout=%d finishers=%d entry=%.0fm player=%.2fs window=%.2fs" % [
        biome,layout,finishers,approach_distance,game.player.finish_time,game.race_time])
    assert(game.player.finished and game.player.position.z < game.FINISH_Z,
        "Player stayed trapped in the final sector (%d/%d)" % [biome,layout])
    assert(finishers >= 38,"Final obstacle stalled the pack (%d/%d)" % [biome,layout])
    for racer in game.racers:
        assert(racer.finished or racer.eliminated,
            "Racer %d was still trapped in the final sector (%d/%d)" % [
                racer.racer_id,biome,layout])
    game.set_process(true)
    game.return_to_menu()
    await process_frame
    return true
