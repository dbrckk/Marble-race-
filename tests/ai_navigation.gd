extends SceneTree
## Full-physics navigation measurement. Unlike course.gd this intentionally
## continues after the human crosses the line, for a fair 120-second window.
## All 40 rigid bodies, obstacles, jumps and collisions remain active.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_navigation_metrics_career.cfg"
    game.career.unlocked = 3
    # Disable results-screen timing only; _physics_process and the actual
    # PhysX/Godot collision resolution continue without any fake movement.
    game.set_process(false)
    for track in range(3):
        assert(game.set_track(track),"The three AI environments must be reachable")
        game.start_race("Grip Tape")
        game.race_state = "RACING"
        for racer in game.racers:
            racer.freeze = false
            racer.sleeping = false
        var simulated_frames := 0
        for frame in range(7200):
            game.race_time = float(frame)/60.0
            await physics_frame
            simulated_frames = frame+1
            if game.race_state != "RACING":
                break
        var candidates := 0
        var entries := 0
        var launches := 0
        var bonuses := 0
        var completed := 0
        var candidate_finished := 0
        var unexpected_ai := 0
        var route: Node3D = game.shortcut_route
        for marble in game.racers:
            if marble.racer_id == 39:
                assert(not marble.wants_shortcut(),
                    "The human-controlled racer must never be a navigation bot")
                continue
            if marble.finished:
                completed += 1
            if not marble.wants_shortcut():
                if route.entered.has(marble.racer_id):
                    unexpected_ai += 1
                continue
            candidates += 1
            if route.entered.has(marble.racer_id):
                entries += 1
            if route.jumped.has(marble.racer_id):
                launches += 1
            if route.triggered.has(marble.racer_id):
                bonuses += 1
            if marble.finished:
                candidate_finished += 1
        print("AI_NAVIGATION_METRICS track=",track,
            " frames=",simulated_frames,
            " candidates=",candidates,
            " entered=",entries,
            " jumped=",launches,
            " reward=",bonuses,
            " candidate_finished=",candidate_finished,
            " ordinary_entries=",unexpected_ai,
            " ai_finished=",completed,
            " total_finished=",game.racer_finish_order.size())
        assert(candidates >= 3 and candidates <= 9,
            "A minority of AI rivals should take risks in each biome")
        assert(completed >= 5,"Track physics must allow real bot finishes")
        assert(bonuses <= launches+entries and launches <= entries,
            "Reward telemetry cannot outrun actual route entries")
        game.return_to_menu()
    print("AI_NAVIGATION_PASS: fair 120-second 3-course physics telemetry")
    game.queue_free()
    await process_frame
    quit()
