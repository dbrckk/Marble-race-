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
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.01
            while game.race_state == "COUNTDOWN":
                await physics_frame
            # Isolate the last obstacle while retaining normal collisions,
            # AI, hazard timing and the real finish-line check. Keep the
            # pack rolling after the human has finished for this measurement.
            game.set_process(false)
            assert(game.racers.size() == 40)
            for index in range(game.racers.size()):
                var racer: RigidBody3D = game.racers[index]
                var z: float = game.FINISH_Z+37.0+floorf(index/8.0)*1.3
                var x: float = game.track_center_at(z)+(float(index%8)-3.5)*1.27
                racer.position = Vector3(x,game.height_at(z)+0.62,z)
                racer.linear_velocity = Vector3(0.0,0.0,-18.0)
            for tick in range(1,3601):
                game.race_time = tick/60.0
                await physics_frame
                if game.racer_finish_order.size() == game.racers.size():
                    break
            var finishers: int = game.racer_finish_order.size()
            print("FINAL_PACK course=%d layout=%d finishers=%d player=%.2fs window=%.2fs" % [
                biome,layout,finishers,game.player.finish_time,game.race_time])
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
    # Switching modes on the same layout must rebuild the crest at the
    # deployed server's location, then restore the solo version on rematch.
    var crest_path := "Course_14/RideableCrest_14"
    game.net.role = "client"
    game.net._begin_round(2,2,PackedInt32Array())
    assert(is_equal_approx(game.board.get_node(crest_path).position.z,-158.5),
        "Online Forge must match the deployed server's crest")
    game.net.leave_room()
    game.race_variation = 2
    game.start_race("Grip Tape")
    var solo_crest: Node3D = game.board.get_node(crest_path)
    assert(solo_crest.position.z < game.final_straight_z and solo_crest.position.z > game.FINISH_Z,
        "The solo rematch must restore the crest between the bank and the finish")
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_final_pack_career.cfg"))
    game.queue_free()
    for frame in range(4):
        await process_frame
    print("FINAL_PACK_PASS: nine layouts with 40 real marbles")
    quit()
