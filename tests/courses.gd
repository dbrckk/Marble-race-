extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path="user://test_course_career.cfg"
    assert(game.selected_track == 0 and not game.set_track(2))
    var all_results: Array[int] = []
    var forge_deck_breaches := 0
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
        # This check measures course traversability. A single human DNF
        # must not stop the other 39 racers before they reach the line.
        # The separate end-to-end test covers actual result-screen timing.
        var elapsed := 0
        while game.race_state == "COUNTDOWN":
            await physics_frame
        game.set_process(false)
        for frame in range(7200):
            game.race_time = float(frame)/60.0
            await physics_frame
            elapsed = frame+1
            if level == 2:
                for racer in game.racers:
                    var p: Vector3 = racer.position
                    if p.z > -141.0 and p.z < -133.0 and (
                        absf(p.x-game.track_center_at(p.z)) < 5.5 and
                        p.y < game.height_at(p.z)-0.8):
                        forge_deck_breaches += 1
            if game.race_state == "RESULTS":
                break
        game.set_process(true)
        var finished=game.racer_finish_order.size()
        var candidates: int = 0
        for racer in game.racers:
            if racer.wants_shortcut():
                candidates += 1
        var entry_count: int = game.shortcut_route.entered.size()
        var launch_count: int = game.shortcut_route.jumped.size()
        var bonus_count: int = game.shortcut_route.triggered.size()
        print("AI_ROUTE_TELEMETRY course=",level," candidates=",candidates,
            " entered=",entry_count," jumped=",launch_count,
            " bonus=",bonus_count," finishers=",finished)
        all_results.append(finished)
        print("COURSE",level,"finished",finished,"player_z",game.player.position.z,"seconds",game.race_time,
            "result",game.race_state,"elapsed_frames",elapsed)
        assert(finished >= 30,"Most of the 40-marble field must physically finish each circuit")
        game.return_to_menu()
    assert(forge_deck_breaches == 0,"A Forge racer passed under the deck near the paddle and hammer")
    print("COURSE_PASS:",all_results)
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_course_career.cfg"))
    game.queue_free()
    await process_frame
    quit(0)
