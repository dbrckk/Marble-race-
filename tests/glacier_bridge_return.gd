extends SceneTree
## A real marble follows the bridge arrows with the touch joystick, from
## the last raised span to beyond even the deepest of the three shutters.
const ROUTE = preload("res://scripts/shortcut_route.gd")
const EXIT_CHECKPOINT := 1

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = preload("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_glacier_bridge_return_career.cfg"
    game.career.unlocked = 3
    assert(game.set_track(1))
    for speed in [16.0,19.0,22.0]:
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.countdown = 0.02
            for frame in range(8):
                await physics_frame
            assert(game.race_state == "RACING" and game.built_variation == layout)
            assert(await _cross_return(game,speed),
                "Glacier layout %d must clear the shutter at %.0f m/s" % [layout,speed])
            game.return_to_menu()
    game.queue_free()
    for frame in range(4):
        await process_frame
    print("GLACIER_BRIDGE_RETURN_PASS: three layouts at three approach speeds, real touch steering, checkpoint and timed shutter")
    quit()

func _cross_return(game: Node3D, speed: float) -> bool:
    var route: Node3D = game.shortcut_route
    var racer: RigidBody3D = game.player
    for marble: RigidBody3D in game.racers:
        if marble != racer:
            marble.freeze = true
    var launch_z := ROUTE.EXIT_Z+10.0
    var tangent: Vector3 = (route.point_at(launch_z-0.7)-route.point_at(launch_z+0.7)).normalized()
    racer.global_position = route.point_at(launch_z)+Vector3.UP*0.68
    racer.linear_velocity = tangent*speed

    var pad: Control = game.ui.touch_controls
    var finger := pad.get_viewport_rect().size*Vector2(0.20,0.83)
    pad._finger_event(1,finger,true)
    var clear_z: float = game.race_director.event_z(1)-2.0
    for frame in range(210):
        var ahead := racer.position.z-4.0
        var target_x: float = route.point_at(ahead).x
        if ahead <= ROUTE.EXIT_Z:
            var blend := smoothstep(0.0,1.0,(ROUTE.EXIT_Z-ahead)/15.0)
            target_x = lerpf(route.point_at(ROUTE.EXIT_Z).x,game.track_center_at(ahead),blend)
        var axis := clampf((target_x-racer.position.x)*0.25-racer.linear_velocity.x*0.075,-1.0,1.0)
        pad._move_finger(1,finger+Vector2(axis*105.0,0))
        await physics_frame
        if racer.eliminated or racer.position.z < clear_z:
            break
    pad._finger_event(1,finger,false)
    return not racer.eliminated and racer.position.z < clear_z and (
        game.last_checkpoint >= EXIT_CHECKPOINT) and racer.linear_velocity.z < -6.0
