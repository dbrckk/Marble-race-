extends SceneTree
## Deterministic smoke checks run by Godot on CI, no graphics or network required.

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var scene = load("res://scenes/main.tscn")
    assert(scene != null, "Main scene not importable")
    var race = scene.instantiate()
    root.add_child(race)
    await process_frame
    assert(is_instance_valid(race.camera), "Missing camera")
    assert(is_instance_valid(race.board), "Missing 3D track")
    assert(race.moving_obstacles.size() >= 4, "Expected working kinetic paddles")
    assert(race.race_state == "MENU", "Should start on title screen")
    race.start_race("Lead Core")
    await process_frame
    assert(race.racers.size() == 40, "40 racers must spawn")
    assert(is_instance_valid(race.player), "Missing controlled racer")
    assert(race.player.is_player, "Wrong player identity")
    assert(race.player.mass > 1.0, "Lead Core perk did not affect real physics")
    assert(race.player_rank() >= 1 and race.player_rank() <= 40, "Invalid leaderboard")
    var seen = {}
    for marble in race.racers:
        var p = str(marble.position)
        assert(not seen.has(p), "Overlapping starting marbles")
        seen[p] = true
        assert(marble.position.y > race.height_at(marble.position.z), "Marble below track")
    race.countdown = 0.01
    for frame in range(40):
        await physics_frame
        await process_frame
    assert(race.race_state == "RACING", "Countdown never finished")
    var active = 0
    for marble in race.racers:
        if marble.linear_velocity.length() > 0.01:
            active += 1
    assert(active > 0, "Rigidbodies did not start moving")
    var previous_mode = race.cam_mode
    race.cycle_camera()
    assert(race.cam_mode != previous_mode, "Camera change not registered")
    race.change_boost(true)
    await process_frame
    assert(race.boosting, "Boost controls do not work")
    race.change_boost(false)
    race.return_to_menu()
    assert(race.race_state == "MENU", "Menu return failed")
    print("SMOKE_PASS: scene, course, 40 marbles, perks, countdown, physics, camera, HUD")
    quit(0)
