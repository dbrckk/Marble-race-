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
        assert(_verify_same_step_order(game))
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
    print("FINISH_ORDER_PASS: same-step photo finishes and consecutive physics steps sharing one race timestamp")
    quit()

func _verify_same_step_order(game: Node3D) -> bool:
    game.set_physics_process(false)
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.race_time = 54.2
    var finish: Vector3 = game.finish_origin
    var a: RigidBody3D = game.racers[0]
    var b: RigidBody3D = game.racers[1]
    var c: RigidBody3D = game.player
    a.previous_race_position = finish+Vector3(-1.4,0.45,0.30)
    a.position = finish+Vector3(-1.4,0.45,-0.10)
    b.previous_race_position = finish+Vector3(1.4,0.45,0.10)
    b.position = finish+Vector3(1.4,0.45,-0.30)
    var step := 1.0/60.0
    game._physics_process(step)
    assert(absf(a.finish_time-b.finish_time-step*0.5) < 0.0002)
    assert(game.get_rankings().slice(0,2) == [b,a])
    assert(game.racer_finish_order == [b.display_name,a.display_name])
    c.previous_race_position = finish+Vector3(0,0.45,0.03)
    c.position = finish+Vector3(0,0.45,-0.37)
    game._physics_process(step)
    assert(c.finish_time > a.finish_time and game.player_rank() == 3)
    assert(game.ui.race_moment_label.text == "PHOTO FINISH!")
    assert(not game.ui.touch_controls.enabled and not game.boosting)
    var hud: CanvasLayer = game.ui
    game.race_time = 55.5
    hud.label_timer = 0.12
    hud.update_hud()
    assert(hud.clock_label.text == "00:54.20","The displayed time must stop at the crossing")
    game.checkpoint_splits.assign([10.0,20.0,30.0])
    var layout: int = game.built_variation
    game._end_race()
    assert(hud.result_photo_finish.is_visible_in_tree())
    assert(hud.result_photo_finish.text == "PHOTO FINISH  •  0.005s BEHIND %s" % a.display_name)
    assert(hud.sector_result_hint.is_visible_in_tree())
    hud.replay_button_ref.pressed.emit()
    assert(game.race_state == "COUNTDOWN" and game.built_variation == layout)
    assert(game.practice_sector == -1 and not hud.practice_entry_pending,
        "The main retry runs the full course without a sector practice goal")
    assert(hud.touch_controls.enabled and not game.race_moments.finish_seen)
    game.return_to_menu()
    game.set_physics_process(true)
    return true

func _approach(racer: RigidBody3D, location: Vector3, velocity: Vector3) -> void:
    racer.position = location
    racer.linear_velocity = velocity
