extends SceneTree
## Phone input physics: real, modest sideways grip when released. Active
## steering retains its old strength, across all three physical biomes.
const RACER = preload("res://scripts/marble.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    for course in range(3):
        var grip: float = RACER.human_steering_force(0.0,-12.0,10.0,course)
        assert(grip < 0.0 and absf(grip) <= 4.2,
            "Releasing a sideways slide must brake gently, not reverse direction")
        assert(RACER.human_steering_force(0.0,-12.0,-10.0,course) == -grip,
            "Releasing Android left and right must have symmetric grip")
        assert(RACER.human_steering_force(0.0,-12.0,0.0,course) == 0.0,
            "No hidden steering force on a naturally straight roll")
        var expected: float = 0.65*lerpf(18.5,26.0,12.0/18.0)
        assert(absf(RACER.human_steering_force(0.65,-12.0,9.0,course)-
            expected) < 0.0001,
            "Full active human touch input retains original steering strength")
        assert(RACER.human_steering_force(0.0,-12.0,NAN,course) == 0.0,
            "Invalid network/physics input cannot produce a NaN force")
    var woodland: float = absf(RACER.human_steering_force(0.0,-12.0,8.0,0))
    var glacier: float = absf(RACER.human_steering_force(0.0,-12.0,8.0,1))
    var forge: float = absf(RACER.human_steering_force(0.0,-12.0,8.0,2))
    assert(woodland > forge and forge > glacier,
        "Each biome retains distinct lateral slide character")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_mobile_coast_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var checked := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.racers.size() == 40)
            var player: RigidBody3D = game.player
            player.freeze = false
            player.sleeping = false
            player.linear_velocity = Vector3(7.0,0.0,-12.0)
            var before: Vector3 = player.global_position
            player.drive(1.0/60.0,2.0,0.0,false)
            assert(player.global_position.is_equal_approx(before) and
                player.linear_velocity == Vector3(7.0,0.0,-12.0),
                "Touch release adds actual force; it cannot teleport or snap momentum")
            # Online-controlled humans use the exact same authoritative
            # force function, rather than an unfair alternate client path.
            player.network_controlled = true
            player.drive(1.0/60.0,2.0,-0.75,false)
            assert(player.global_position.is_equal_approx(before),
                "Server human steering remains real rigid-body dynamics")
            player.network_controlled = false
            checked += 1
            game.return_to_menu()
    assert(checked == 9)
    game.queue_free()
    for frame in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_mobile_coast_career.cfg"))
    print("MOBILE_COAST_PASS: 9 real layouts, distinctive biome grip, unchanged full steering and 40 fair physics racers")
    quit(0)
