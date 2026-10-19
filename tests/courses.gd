extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path="user://test_course_career.cfg"
    assert(game.selected_track == 0 and not game.set_track(2))
    var all_results: Array[int] = []
    for level in range(3):
        game.career.unlocked = 3
        assert(game.set_track(level))
        var shutters=0
        var chokepoints=0
        for segment in game.board.get_children():
            for obstacle in segment.get_children():
                if obstacle.name.begins_with("AntiEdgeBaffle"):
                    shutters += 1
                if obstacle.name.begins_with("Chicane_"):
                    chokepoints += 1
        assert(shutters == 28,"Expected 2 anti-edge gates across fourteen obstacle sections")
        if level > 0:
            assert(chokepoints >= 4,"Advanced courses require inward chicanes")
        game.start_race("Grip Tape")
        game.countdown = 0.01
        var elapsed := 0
        for frame in range(6300):
            await physics_frame
            if game.race_state == "RESULTS":
                elapsed=frame
                break
        var finished=game.racer_finish_order.size()
        all_results.append(finished)
        print("COURSE",level,"finished",finished,"player_z",game.player.position.z,"seconds",game.race_time,
            "result",game.race_state,"elapsed_frames",elapsed)
        assert(finished > 0,"Circuit must remain physically finishable")
        game.return_to_menu()
    print("COURSE_PASS:",all_results)
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_course_career.cfg"))
    game.queue_free()
    await process_frame
    quit(0)
