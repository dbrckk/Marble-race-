extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path="user://test_feasibility_career.cfg"
    game.career.unlocked=3
    for track in [0,1]:
        game.career.unlocked=3
        game.set_track(track)
        game.start_race("Aerodynamic")
        game.countdown=0.01
        var frame := 0
        while game.race_state != "RESULTS" and frame < 17000:
            await physics_frame
            frame+=1
            if game.race_state=="RACING":
                game.change_boost(game.boost_energy >= 0.18)
                game.change_steer(clampf(-game.player.position.x*0.23,-0.7,0.7))
        print("ACTIVE",track,"rank",game.player_rank(),"finished",game.player.finished,"time",game.player.finish_time,"boost",game.boost_energy)
        game.return_to_menu()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_feasibility_career.cfg"))
    game.queue_free()
    for i in range(4): await process_frame
    quit(0)
