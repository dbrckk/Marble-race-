extends SceneTree
## Phone-safe forecasts for all nine moving-gate layouts. Warnings use
## the real physical piston's future state and sound at most once per gate.
const DIRECTOR = preload("res://scripts/race_director.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_timed_hud_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    game.audio.enabled = true
    var label: Label = game.ui.timed_gate_label
    assert(is_instance_valid(label))
    assert(label.name == "PredictedTimedGate")
    assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The new HUD cannot intercept Android taps or swipes")
    assert(label.anchor_top > game.ui.duel_label.anchor_bottom,
        "The threat predictor must not obscure the live rival prompt")
    assert(label.anchor_bottom < game.ui.race_moment_label.anchor_top,
        "The threat predictor must not hide exciting race moments")
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.racers.size() == 40)
            var director: Node3D = game.race_director
            assert(director.variation == layout and director.biome == biome)
            var gate_index := 1
            var gate_z: float = director.event_z(gate_index)
            var approach_z := gate_z+13.0
            var speed := 12.0
            var eta := 13.0/speed
            var blocked_clock := 1.0
            var clear_clock := 0.0
            if biome == 2:
                var blocked_found := false
                var clear_found := false
                for sample in range(120):
                    var t: float = float(sample)*0.08
                    if director.piston_up(gate_index,t+eta) and not blocked_found:
                        blocked_clock = t
                        blocked_found = true
                    if not director.piston_up(gate_index,t+eta) and not clear_found:
                        clear_clock = t
                        clear_found = true
                assert(blocked_found and clear_found,
                    "Forge pistons require both real future blocked and open states")
            game.player.global_position = Vector3(
                game.track_center_at(approach_z),
                game.height_at(approach_z)+0.8,approach_z)
            game.player.linear_velocity = Vector3(0,0,-speed)
            director.animate(blocked_clock)
            game.race_time = blocked_clock
            var actual: Dictionary = director.event_ahead(approach_z)
            assert(int(actual["index"]) == gate_index)
            assert(is_equal_approx(float(actual["z"]),gate_z))
            assert(str(actual["side"]) != "")
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.visible,"A timed hazard must be independently visible on phone")
            assert(label.text.contains(DIRECTOR.EVENT_NAMES[biome]),
                "The HUD must identify the actual physical moving gate")
            assert(label.text.contains("1.1s"),
                "Arrival forecast should use measured speed and distance")
            if biome == 2:
                assert(label.text.contains("EST. BLOCKED"),
                    "Forge should warn about future piston height, not current phase")
            assert(game.audio.warned_timed_gates.has(gate_index),
                "One audio danger cue must sound as the moving gate approaches")
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(game.audio.warned_timed_gates.size() == 1,
                "The warning cannot spam ten overlapping sounds per second")
            if biome == 2:
                director.animate(clear_clock)
                game.race_time = clear_clock
                game.ui.label_timer = 0.25
                game.ui.update_hud()
                assert(label.text.contains("EST. OPEN"),
                    "A retracted Forge piston must give an accurate safe-window cue")
                # No new warning is allowed for the estimated-open passage.
                assert(game.audio.warned_timed_gates.size() == 1)
            game.player.global_position.z = gate_z+35.0
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(not label.visible,
                "Do not clutter the HUD with hazards beyond the lookahead")
            game.return_to_menu()
            assert(not game.ui.hud_layer.visible)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_timed_hud_career.cfg"))
    print("TIMED_HUD_PASS: 9 layouts, truthful Forge arrival windows, touch-safe warning and deduplicated audio")
    quit(0)
