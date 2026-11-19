extends SceneTree
const Radar = preload("res://scripts/race_progress_radar.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(Radar.progress_at(0.0) == 0.0)
    assert(Radar.progress_at(-92.5) == 0.5)
    assert(Radar.progress_at(-185.0) == 1.0)
    assert(Radar.progress_at(100.0) == 0.0)
    assert(Radar.progress_at(-1000.0) == 1.0)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_race_radar.cfg"
    game.start_race("Grip Tape")
    game.set_process(false)
    game.set_physics_process(false)
    var radar: Control = game.ui.race_radar
    assert(radar != null and radar.name == "FortyMarbleRadar")
    assert(radar.opponent_dots.instance_count == 40 and
        radar.opponent_dots.transform_format == MultiMesh.TRANSFORM_2D,
        "The race radar must reuse one batch sized for all physical racers")
    assert(radar.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "Race radar must never block joystick, boost or rare items")
    assert(not radar.visible and game.ui.opening_grid.is_visible_in_tree())
    game.countdown = 0.01
    game._process(1.0/60.0)
    assert(radar.visible and not game.ui.opening_grid.visible)
    var launch_updates: int = radar.updates
    radar.elapsed = 0.0
    radar.sample(0.02)
    assert(radar.updates == launch_updates, "Radar must not update on every rendered frame")
    radar.sample(Radar.UPDATE_PERIOD)
    assert(radar.updates == launch_updates+1 and radar.last_count == 40,
        "Radar must show all 30 physical competitors")
    assert(radar.player_id >= 0 and radar.player_id < 40,
        "Human marble must be distinguishable from the 29 opponents")
    assert(radar.positions[radar.player_id] >= 0.0)
    var player = game.player
    player.global_position.z = -92.5
    radar.sample(Radar.UPDATE_PERIOD)
    assert(is_equal_approx(radar.positions[radar.player_id],0.5),
        "Actual marble position, not rankings, drives the player marker")
    game.return_to_menu()
    game.start_race("Grip Tape")
    assert(radar.positions.is_empty() and radar.updates == launch_updates+2 and
        radar.opponent_dots.visible_instance_count == 0,
        "Rematch must clear old player and opponent positions")
    game.set_graphics_quality(0)
    game.countdown = 0.01
    game._process(1.0/60.0)
    radar.sample(Radar.UPDATE_PERIOD)
    assert(radar.last_count == 40,
        "Economy devices must retain useful race-position information")
    game.return_to_menu()
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_race_radar.cfg"))
    print("RACE_RADAR_PASS: 30 racers, genuine physical progress, touch-safe throttled UI")
    quit()
