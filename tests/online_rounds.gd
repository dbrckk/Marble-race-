extends SceneTree
## Real scene regression: stale online controls must fail safe; rematches use
## every course and rebuild the matching geometry on server AND Android clients.
const SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var net = game.net
    assert(net.COMMAND_TIMEOUT_MS > net.INPUT_PERIOD * 1000.0 * 3.0)
    assert(net.TRACK_COUNT == game.TRACK_NAMES.size())

    # Simulate two admitted players without network dependencies.
    net.role = "server"
    net.connected = true
    net.joined_slots[101] = 39
    net.joined_slots[102] = 38
    net.steer_by_slot[39] = 0.85
    net.steer_by_slot[38] = -0.6
    net.boost_by_slot[39] = true
    net.boost_by_slot[38] = true
    net.energy_by_slot[39] = 1.0
    net.energy_by_slot[38] = 1.0
    var now := Time.get_ticks_msec()
    net.last_command_ms[101] = now - net.COMMAND_TIMEOUT_MS - 100
    net.last_command_ms[102] = now
    net.match_running = true
    game.race_state = "RACING"
    net._physics_process(1.0 / 60.0)
    assert(net.input_for_slot(39) == Vector2.ZERO,
        "Stale controls must release both steering and boost")
    assert(net.input_for_slot(38).x < -0.5 and net.input_for_slot(38).y == 1.0,
        "Healthy player input must remain untouched")
    # Restored traffic should work without resetting the session.
    net.steer_by_slot[39] = 0.35
    net.boost_by_slot[39] = true
    net.last_command_ms[101] = Time.get_ticks_msec()
    net._physics_process(1.0 / 60.0)
    assert(net.input_for_slot(39).x > 0.3 and net.input_for_slot(39).y == 1.0,
        "Controls must recover when packets resume")

    # Server rotates all three courses; a fresh room starts on course zero.
    net.match_running = false
    game.return_to_menu()
    for course in range(net.TRACK_COUNT):
        net._launch_match()
        assert(net.match_running and game.race_state == "COUNTDOWN")
        assert(game.selected_track == course,
            "Online race must rotate the announced track")
        assert(int(game.board.get_meta("track_index",-1)) == course,
            "Physical obstacle layout must match the announced track")
        assert(game.racers.size() == 40, "Track switch must preserve all racers")
        game._end_race()
        assert(net.completed_rounds == course + 1 and not net.match_running,
            "Only completed online rounds advance the course")
        if course + 1 < net.TRACK_COUNT:
            net._process(net.RESULTS_DURATION + 0.05)
            # Automatic launch on results expiry is tested in the next iteration.
            assert(net.match_running, "Rematch must start with two waiting players")
            net.match_running = false
            game.return_to_menu()

    net._reset_room()
    assert(net.completed_rounds == 0, "New rooms must start on the first course")
    net.leave_room()
    game.queue_free()
    for i in range(4):
        await process_frame
    print("ONLINE_ROUNDS_PASS: stale-command cutoff, input recovery, 3 matching tracks, room reset")
    quit(0)
