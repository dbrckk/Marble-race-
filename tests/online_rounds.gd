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
    net.joined_slots[101] = 29
    net.joined_slots[102] = 28
    net.steer_by_slot[29] = 0.85
    net.steer_by_slot[28] = -0.6
    net.boost_by_slot[29] = true
    net.boost_by_slot[28] = true
    net.energy_by_slot[29] = 1.0
    net.energy_by_slot[28] = 1.0
    var now := Time.get_ticks_msec()
    net.last_command_ms[101] = now - net.COMMAND_TIMEOUT_MS - 100
    net.last_command_ms[102] = now
    net.match_running = true
    game.race_state = "RACING"
    net._physics_process(1.0 / 60.0)
    assert(net.input_for_slot(29) == Vector2.ZERO,
        "Stale controls must release both steering and boost")
    assert(net.input_for_slot(28).x < -0.5 and net.input_for_slot(28).y == 1.0,
        "Healthy player input must remain untouched")
    # Restored traffic should work without resetting the session.
    net.steer_by_slot[29] = 0.35
    net.boost_by_slot[29] = true
    net.last_command_ms[101] = Time.get_ticks_msec()
    net._physics_process(1.0 / 60.0)
    assert(net.input_for_slot(29).x > 0.3 and net.input_for_slot(29).y == 1.0,
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
        assert(game.racers.size() == game.MARBLE_COUNT, "Track switch must preserve all racers")
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
    assert(_verify_client_results(game))
    net.leave_room()
    game.queue_free()
    for i in range(4):
        await process_frame
    print("ONLINE_ROUNDS_PASS: controls, track rotation, authoritative finish, rematch and room reset")
    quit(0)

func _verify_client_results(game: Node3D) -> bool:
    var net = game.net
    var hud: CanvasLayer = game.ui
    net.role = "client"
    net.local_slot = 29
    net._begin_round(0,0,PackedInt32Array([29,28]))
    game.race_state = "RACING"
    var starts: int = game.career.starts
    var snapshot := PackedFloat32Array()
    for racer in game.racers:
        var position: Vector3 = racer.position
        var finished: bool = racer.racer_id >= 28
        snapshot.append_array([position.x,position.y,position.z,0.0,0.0,0.0,1.0,
            1.0 if finished else 0.0,42.0 if racer.racer_id == 29 else 42.02])
    net._receive_snapshot(snapshot,42.1,PackedFloat32Array())
    assert(game.race_moments.photo_finish_seen and not hud.touch_controls.enabled,
        "A confirmed local and remote crossing triggers one cue on the client")
    var times := PackedFloat32Array()
    times.resize(game.MARBLE_COUNT)
    times.fill(-1.0)
    times[29] = 42.0
    times[28] = 42.02
    net._show_results(times,43.5)
    assert(game.career.starts == starts and game.race_state == "RESULTS")
    assert(hud.result_photo_finish.text.contains("0.020s AHEAD OF"))
    assert(hud.online_rematch_label.text == "NEXT RACE IN 15s" and not hud.replay_button_ref.is_visible_in_tree())
    net._ping_elapsed = -30.0
    net._process(2.1)
    assert(hud.online_rematch_label.text == "NEXT RACE IN 13s")
    net._lobby_state("Waiting",1)
    assert(hud.online_rematch_label.text == "WAITING FOR ANOTHER PLAYER")
    net._process(14.0)
    assert(game.race_state == "RESULTS" and hud.online_rematch_label.text == "WAITING FOR ANOTHER PLAYER")
    net._lobby_state("Starting",2)
    assert(hud.online_rematch_label.text == "STARTING NEXT RACE…")
    net._begin_round(1,2,PackedInt32Array([29,28]))
    assert(game.race_state == "COUNTDOWN" and game.built_variation == 2 and game.selected_track == 1)
    assert(hud.touch_controls.enabled and not hud.online_rematch_label.is_visible_in_tree())
    assert(not game.race_moments.finish_seen and game.career.starts == starts)
    assert(hud.remaining_label.text == "SWITCHBACK  •  LAYOUT 3 / 3")
    assert("POSTS & PADDLE" in hud.opening_grid_title.text and hud.opening_grid.is_visible_in_tree())
    assert(hud.opening_grid_gaps == game.opening_obstacle_art.entry_gaps)
    return true
