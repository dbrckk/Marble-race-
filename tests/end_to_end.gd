extends SceneTree
func _initialize() -> void: call_deferred("_go")
func _go() -> void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path="user://test_results_career.cfg"
    game.career.starts=0
    for i in range(3):
        game.career.track_best[i]=0
        game.career.stars[i]=0
    game.career.finishes=0
    for track in range(3):
        game.career.unlocked=3
        assert(game.set_track(track))
        game.start_race("Grip Tape")
        game.countdown=0.01
        var frames=0
        while game.race_state != "RESULTS" and frames < 14500:
            frames+=1
            await physics_frame
        assert(game.race_state=="RESULTS","Race must reach results")
        assert(game.result_saved,"Race result not stored")
        assert(game.career.starts==track+1)
        print("END",track,"time",game.race_time,"rank",game.player_rank(),"finish",game.player.finished,
            "player_z",game.player.position.z,"finishers",game.racer_finish_order.size())
        game.return_to_menu()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_results_career.cfg"))
    print("END_TO_END_PASS: all 3 courses reach final results and store progress")
    game.queue_free()
    for i in range(4): await process_frame
    quit(0)
