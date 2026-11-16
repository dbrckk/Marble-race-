extends SceneTree
## Exercise the real physics-loop classification on all three finish decks.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_finish_crossing.cfg"
    game.career.unlocked = 3
    for track in range(3):
        assert(game.set_track(track))
        game.start_race("Grip Tape")
        game.countdown = 0.01
        while game.race_state == "COUNTDOWN":
            await physics_frame
        var line: Node3D = game.board.get_node("FinishLine")
        var z: float = line.position.z
        var y: float = line.position.y
        var x: float = line.position.x
        _approach(game.racers[0],Vector3(x,y+0.48,z+0.70),Vector3(0,0,-14))
        _approach(game.racers[1],Vector3(x+3.2,y+1.75,z+0.70),Vector3(0,2,-14))
        _approach(game.racers[2],Vector3(x,y-2.0,z+0.70),Vector3(0,0,-14))
        _approach(game.racers[3],Vector3(x-7.5,y+0.75,z+0.70),Vector3(0,0,-14))
        for frame in range(9):
            await physics_frame
        assert(game.racers[0].finished,"A grounded crossing must count")
        assert(game.racers[1].finished,"A jump over the stripe must count")
        assert(not game.racers[2].finished and game.racers[2].finish_time == 0.0,
            "A marble passing beneath the deck must stay unclassified")
        assert(not game.racers[3].finished and game.racers[3].finish_time == 0.0,
            "A marble outside the physical deck must stay unclassified")
        assert(game.racer_finish_order.size() == 2)
        assert(game.get_rankings().slice(0,2).all(func(racer): return racer.finished))
        game.return_to_menu()
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_finish_crossing.cfg"))
    game.queue_free()
    await process_frame
    print("FINISH_CROSSING_PASS: grounded, airborne, under-deck and outside crossings on all three circuits")
    quit()

func _approach(racer: RigidBody3D, location: Vector3, velocity: Vector3) -> void:
    racer.position = location
    racer.linear_velocity = velocity
