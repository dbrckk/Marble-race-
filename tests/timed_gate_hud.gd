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
                    if director.piston_up(gate_index,t+eta) and (
                        not director.piston_up(gate_index,t)) and not blocked_found:
                        blocked_clock = t
                        blocked_found = true
                    if not director.piston_up(gate_index,t+eta) and (
                        director.piston_up(gate_index,t)) and not clear_found:
                        clear_clock = t
                        clear_found = true
                assert(blocked_found and clear_found,
                    "Forge tests must prove opposite current and arrival states")
            var collision_x: float = director.position_at(
                gate_index,blocked_clock+eta).x
            # Deliberately enter the moving body's future footprint.
            game.player.global_position = Vector3(
                collision_x,game.height_at(approach_z)+0.8,approach_z)
            game.player.linear_velocity = Vector3(0,0,-speed)
            # World-space timing signs must describe the real collision
            # phase, not a decorative fake animation. No new 3D objects.
            var sign: Label3D = director.signs[gate_index]
            assert(sign.text.contains(DIRECTOR.EVENT_NAMES[biome]),
                "Every physical gate retains its world-specific name")
            if biome == 2:
                assert(sign.text.contains("BLOCKED") or
                    sign.text.contains("RISING"),
                    "Forge signs must communicate actual piston danger")
                director.animate(clear_clock)
                assert(director.signs[gate_index].text.contains("OPEN") or
                    director.signs[gate_index].text.contains("RISING"),
                    "A retracted piston should visually communicate a safe window")
                director.animate(blocked_clock)
            else:
                assert(sign.text.contains("SWEEP"),
                    "Woodland and Glacier signs must show true movement direction")
                var first_x: float = director.position_at(
                    gate_index,blocked_clock).x
                var next_x: float = director.position_at(
                    gate_index,blocked_clock+0.08).x
                if absf(next_x-first_x) > 0.004:
                    assert(sign.text.contains("LEFT" if next_x < first_x else "RIGHT"),
                        "Displayed sweep direction must agree with physical motion")
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
            assert(label.text.contains("DODGE!"),
                "A real future lane intersection should clearly demand evasive action")
            assert(director.threatens_line(
                gate_index,blocked_clock,eta,collision_x,0.0),
                "A stationary lateral line through the collision envelope is unsafe")
            # The same moving gate is NOT a risk on the other side of
            # the course: neither warning sound nor red HUD cue is justified.
            var clear_x: float = game.track_center_at(gate_z)-(
                director.side_at(gate_index)*2.5)
            assert(not director.threatens_line(
                gate_index,blocked_clock,eta,clear_x,0.0),
                "Opposite-side lanes must remain safe and playable")
            game.audio.warned_timed_gates.clear()
            game.player.global_position.x = clear_x
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.text.contains("LINE CLEAR"),
                "The phone HUD must distinguish a safe racing line")
            assert(game.audio.warned_timed_gates.is_empty(),
                "Do not sound a dangerous-gate siren for a safe line")
            # Fast lateral drift into the predicted body is dangerous even
            # if the marble does not currently overlap the collider's X.
            assert(director.threatens_line(gate_index,blocked_clock,eta,
                collision_x-1.8,4.0),
                "Bounded lateral trajectory prediction must include ongoing drift")
            game.player.global_position.x = collision_x
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.text.contains("DODGE!") and
                game.audio.warned_timed_gates.has(gate_index),
                "Returning to the collision lane must restore the real hazard warning")
            if biome == 2:
                # An upward piston *right now* is harmless if it will have
                # retracted when this marble arrives. Clear the warning log
                # and verify no false alarm is issued for that safe arrival.
                game.audio.warned_timed_gates.clear()
                director.animate(clear_clock)
                game.race_time = clear_clock
                assert(director.piston_up(gate_index,clear_clock))
                assert(not director.piston_up(gate_index,clear_clock+eta))
                game.ui.label_timer = 0.25
                game.ui.update_hud()
                assert(label.text.contains("EST. OPEN") and
                    label.text.contains("LINE CLEAR"),
                    "A retracted future piston must show an explicitly safe window")
                assert(not director.threatens_line(
                    gate_index,clear_clock,eta,collision_x,0.0),
                    "Buried pistons must not be reported as dangerous")
                assert(game.audio.warned_timed_gates.is_empty(),
                    "No audio danger alert is allowed for a predicted clear piston")
                director.animate(blocked_clock)
                game.race_time = blocked_clock
                assert(not director.piston_up(gate_index,blocked_clock))
                assert(director.piston_up(gate_index,blocked_clock+eta))
                game.ui.label_timer = 0.25
                game.ui.update_hud()
                assert(game.audio.warned_timed_gates.has(gate_index),
                    "The audio must warn when a currently down piston WILL rise")
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
    print("TIMED_HUD_PASS: 9 layouts, actual lane intersections, quiet safe lines, future Forge timing and bounded drift")
    quit(0)
