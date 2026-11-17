extends SceneTree
## Real-device frame telemetry plus broad-phase work budgets without
## changing any authoritative physics, finishes or rewards.
const Budget = preload("res://scripts/performance_budget.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var model = Budget.new()
    assert(Budget.percentile_95(PackedFloat32Array()) == 0.0)
    assert(is_equal_approx(Budget.percentile_95(
        PackedFloat32Array([11.0,13.0,30.0,19.0])),30.0))
    assert(Budget.slow_frame_fraction(PackedFloat32Array()) == 0.0)
    assert(is_equal_approx(Budget.slow_frame_fraction(
        PackedFloat32Array([16.0,17.0,34.0,50.0])),0.5),
        "Two out of four slow frames must yield 50 percent")
    for i in range(240):
        model.tick(1.0/60.0)
    assert(model.frame_ms.size() == Budget.HISTORY_FRAMES,
        "Opt-in telemetry must cap memory at 120 frames")
    assert(model.sample_count == 240 and not model.report.is_empty(),
        "Runtime monitor sampling should accumulate measured frames")
    assert(model.report.has("physics_ms") and model.report.has("draw_calls"))
    assert(float(model.report["slow_pct"]) == 0.0,
        "Stable 60 FPS must not be reported as stuttering")
    assert(absf(float(model.report["p95_ms"])-1000.0/60.0) < 0.03,
        "Measured 60 Hz frame pacing must be about 16.7 ms")
    var before: int = model.sample_count
    model.tick(0.9)
    model.tick(-1.0)
    model.tick(NAN)
    assert(model.sample_count == before,
        "Background spikes and invalid time must never corrupt a report")
    model.reset()
    assert(model.frame_ms.is_empty() and model.report.is_empty() and model.cursor == 0,
        "Each race needs a clean isolated performance window")
    assert(model.race_summary().is_empty())
    assert(Budget.focus_at(4.99,5.0,-104.0) == Budget.Focus.LAUNCH)
    assert(Budget.focus_at(5.0,5.0,-104.0) == Budget.Focus.NONE)
    assert(Budget.focus_at(12.0,-96.0,-104.0) == Budget.Focus.BRIDGE_RETURN)
    assert(Budget.focus_at(12.0,-112.0,-104.0) == Budget.Focus.BRIDGE_RETURN)
    assert(Budget.focus_at(12.0,-112.01,-104.0) == Budget.Focus.NONE)
    model.record_frame(0,0,Budget.Focus.LAUNCH)
    model.record_frame(16667,1)
    model.record_frame(56667,1,Budget.Focus.BRIDGE_RETURN)
    model.suspend()
    model.record_frame(10000000,2,Budget.Focus.BRIDGE_RETURN)
    model.record_frame(10400000,2)
    var measurements: String = model.race_summary()
    assert(measurements.contains("START | 1 frames | P95 17 ms | >33.3 ms 0.0%"))
    assert(measurements.contains("MID-RACE | 1 frames | P95 40 ms | >33.3 ms 100.0%"))
    assert(measurements.contains("FINAL SECTOR | 1 frames | P95 250+ ms | >33.3 ms 100.0%"),
        "A real slow foreground frame counts, while the pause interval is skipped")
    assert(measurements.contains("FIRST 5s | 1 frames | P95 17 ms"))
    assert(measurements.contains("BRIDGE RETURN ±8 m | 1 frames | P95 250+ ms"),
        "Only the preceding frame's window receives the interval")
    assert(model.focus_windows[Budget.Focus.BRIDGE_RETURN].monitor_samples == 1,
        "Short windows get a monitor sample even between periodic reports")

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    var originally_visible: bool = game.show_fps
    if not game.show_fps:
        game.toggle_fps_overlay()
    assert(game.ui.performance_label != null and
        game.ui.performance_label.get_parent().visible,
        "Phone can reveal performance telemetry through existing FPS toggle")
    assert(game.ui.performance_label.mouse_filter == Control.MOUSE_FILTER_IGNORE and
        game.ui.performance_label.get_parent().mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The P95 diagnostics must never steal Android touch input")
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40, "Maintain all 40 real rigid-body marbles")
    assert(game.performance_budget.frame_ms.is_empty(),
        "New races reset frame pacing samples")
    game.race_state = "RACING"
    for i in range(120):
        game.performance_budget.tick(1.0/60.0)
    game.ui.label_timer = 0.5
    game.ui.update_hud()
    assert(game.ui.performance_label.text.contains("SLOW") and
        game.ui.performance_label.text.contains("P95") and
        game.ui.performance_label.text.contains("PHYS") and
        game.ui.performance_label.text.contains("DRAW"),
        "Android overlay must expose actionable frame, physics and draw cost")
    var route: Node3D = game.shortcut_route
    assert(route.inside_effect_window(-48.0) and
        route.inside_effect_window(-79.0))
    for launch_z in route.JUMP_Z:
        assert(route.inside_effect_window(float(launch_z)+1.5) and
            route.inside_effect_window(float(launch_z)-1.5),
            "Broad phase must cover every physically rewarded launch pad")
    assert(not route.inside_effect_window(8.0) and
        not route.inside_effect_window(-125.0),
        "Outside the fork no expensive reward geometry is needed")
    for marble in game.racers:
        marble.global_position = Vector3(0.0,game.height_at(8.0)+0.7,8.0)
    route.tick(0.016,game.racers,game.net)
    assert(route.effect_candidates_last_tick == 0,
        "40 marbles on an unrelated track section must skip all route samples")
    var rival: RigidBody3D = game.racers[0]
    assert(rival != game.player)
    # The harness stops the countdown and scene physics, so manually
    # unfreeze the one contender whose route eligibility is being measured.
    rival.freeze = false
    rival.global_position = Vector3(0,game.height_at(-50.0)+0.7,-50.0)
    var original_position: Vector3 = rival.position
    route.tick(0.016,game.racers,game.net)
    assert(route.effect_candidates_last_tick == 1,
        "Exactly the one marble on the fork must enter detailed route checks")
    assert(rival.position.is_equal_approx(original_position),
        "Broad-phase filtering must never teleport or reposition marbles")
    game.race_items.tick(0.016,game.racers,game.net)
    assert(game.race_items.eligible_collectors.size() == 1 and
        game.race_items.eligible_collectors[0] == game.player,
        "Only the genuine local player should receive pickup collision tests")
    game.player.finished = true
    game.race_items.tick(0.016,game.racers,game.net)
    assert(game.race_items.eligible_collectors.is_empty(),
        "Finished players cannot farm arcade items")
    game.player.finished = false
    game.set_graphics_quality(1)
    var previous_layout: int = game.built_variation
    var previous_perk: String = game.selected_perk
    game.performance_budget.record_frame(1000,0)
    game.performance_budget.record_frame(17667,0)
    game._end_race()
    assert(game.ui.performance_actions.is_visible_in_tree() and
        game.ui.performance_text.contains("BALANCED") and
        game.ui.performance_text.contains("FINAL SECTOR | NO SAMPLES") and
        game.ui.performance_text.contains("BRIDGE RETURN ±8 m | NO SAMPLES"),
        "Results identify the measured profile and distinguish an unreached phase")
    var report: String = game.ui.performance_text
    game.ui._show_fps_report(report)
    await process_frame
    assert(game.ui.performance_report_dialog.visible and
        game.ui.performance_report_input.text == report and
        not game.ui.performance_report_input.editable,
        "The fallback exposes the complete report without changing its contents")
    game.ui.compare_performance.pressed.emit()
    assert(not game.ui.performance_report_dialog.visible,
        "An old report must close when a new race begins")
    assert(game.race_state == "COUNTDOWN" and game.built_variation == previous_layout and
        game.selected_perk == previous_perk and game.graphics_setting == 0 and
        game.performance_budget.race_summary().is_empty(),
        "Compare switches profiles and starts a fresh capture on the same layout and perk")
    game.toggle_fps_overlay()
    game._end_race()
    assert(not game.ui.performance_actions.is_visible_in_tree(),
        "Performance actions must stay hidden when metrics are disabled")
    if originally_visible:
        game.toggle_fps_overlay()
    game.return_to_menu()
    game.queue_free()
    for i in range(3):
        await process_frame
    print("PERFORMANCE_BUDGET_PASS: bounded P95, phone metrics, zero-touch HUD, " +
        "40-marble spatial culling and authorized human-only collisions")
    quit(0)
