extends SceneTree
## Sustained, truly physical 3D solo drafting; no free boost from teleports,
## bridges, stopped opponents, network clients, or accidental pack overlaps.
const Draft = preload("res://scripts/slipstream.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_slipstream_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    assert(Draft.SAMPLE_PERIOD >= 0.12,
        "Android slipstream must not scan 39 rivals each physics tick")
    assert(Draft.FORWARD_FORCE <= 2.0 and Draft.RECOVERY_PER_SECOND <= 0.10,
        "Draft should reward strategy, never replace driving skill")
    for track in range(3):
        game.return_to_menu()
        assert(game.set_track(track))
        game.start_race("Grip Tape")
        assert(game.slipstream != null)
        assert(game.racers.size() == 40)
        game.race_state = "RACING"
        var human: RigidBody3D = game.player
        var rival: RigidBody3D = game.racers[1]
        for marble in game.racers:
            marble.global_position = Vector3(25.0,0.0,12.0)
        var z := -12.0
        var x: float = game.track_center_at(z)
        var y: float = game.height_at(z)+0.8
        human.freeze = false
        human.sleeping = false
        rival.freeze = false
        rival.sleeping = false
        human.global_position = Vector3(x,y,z)
        rival.global_position = Vector3(x,y,z-5.0)
        human.linear_velocity = Vector3(0,0,-14)
        rival.linear_velocity = Vector3(0,0,-14)
        assert(Draft.draft_score(human,game.racers) > 0.85,
            "A moving rival directly ahead must create real aerodynamic drafting")
        game.slipstream.reset_round()
        for step in range(4):
            game.slipstream.tick(1.0/60.0,human,game.racers)
        assert(game.slipstream.strength == 0.0,
            "Brief pack overlaps must not generate free boost")
        for step in range(65):
            game.slipstream.tick(1.0/60.0,human,game.racers)
        assert(game.slipstream.strength > 0.60,
            "Sustained close pursuit should visibly charge the player's turbo")
        assert(game.slipstream.scanned_last < 14,
            "Drafting scans must remain throttled even at 60Hz")
        game.ui.label_timer = 0.5
        game.ui.update_hud()
        assert(game.ui.boost_label.text.contains("DRAFT"),
            "Touch HUD should show physically earned slipstream assistance")
        game.boost_energy = 0.25
        game.boosting = false
        var before_boost: float = game.boost_energy
        var cached: float = game.slipstream.strength
        game._process(0.20)
        var expected: float = before_boost+0.20*(
            0.08+cached*Draft.RECOVERY_PER_SECOND)
        assert(absf(game.boost_energy-expected) < 0.001,
            "Draft charge must be added only to the actual solo boost meter")
        # A local client cannot mint energy by placing itself near replicated
        # opponents. The dedicated server remains authoritative online.
        game.net.role = "client"
        before_boost = game.boost_energy
        game._process(0.20)
        assert(is_equal_approx(game.boost_energy,before_boost),
            "A client replica must not regenerate authoritative turbo")
        game.net.role = "offline"
        rival.global_position.y += 3.0
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "A marble above on another bridge cannot create false drafting")
        rival.global_position = Vector3(x,y,z+5.0)
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "Drafting must not work when the rival is behind")
        rival.global_position = Vector3(x,y,z-1.0)
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "Collision range cannot count as a drafting corridor")
        rival.global_position = Vector3(x,y,z-5.0)
        rival.linear_velocity = Vector3.ZERO
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "A stopped obstacle is not an aerodynamic pacemaker")
        rival.linear_velocity = Vector3(0,0,-14)
        human.linear_velocity = Vector3(0,0,-3)
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "Stationary or crawling racer must not farm turbo")
        human.linear_velocity = Vector3(0,0,-14)
        rival.global_position.x += 3.0
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "A parallel rival in a distant lane gives no slipstream")
        rival.global_position.x -= 3.0
        rival.finished = true
        assert(Draft.draft_score(human,game.racers) == 0.0,
            "Finished frozen marbles cannot be used as wind shields")
        rival.finished = false
        game.slipstream.reset_round()
        assert(game.slipstream.strength == 0.0)
        game.return_to_menu()
        assert(game.slipstream.strength == 0.0,
            "Reset and rematch must not inherit an old drafting charge")
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_slipstream_career.cfg"))
    print("SLIPSTREAM_PASS: three worlds, real following, recharge, throttled scans, online authority and no cross-bridge drafting")
    quit(0)
