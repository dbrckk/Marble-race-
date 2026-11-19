extends SceneTree
## Product regression for HUD ranking, medal semantics and scaled celebration FX.
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    assert(game.ui.position_feedback != null, "Missing position feedback")
    for profile in range(3):
        game.set_graphics_quality(profile)
        var expected: int = [12,24,45][profile]
        game._burst(Vector3.ZERO,false)
        var fx: CPUParticles3D = null
        for node in game.get_children():
            if node is CPUParticles3D and node.name == "CheckpointGlitter":
                fx = node
        assert(fx != null and fx.amount == expected, "FX profile scaling mismatch")
        fx.emitting = false
        fx.queue_free()
        await process_frame
    game.start_race("Grip Tape")
    game.racers[0].finished = true
    game.racers[0].finish_time = 38.25
    game.racers[1].display_name = "Unfinished Rival"
    game.last_result = {"finished":true,"stars":3,"record":true,
        "unlocked":true,"clean_passes":2}
    game.ui.show_results(2,43.0,game.get_rankings())
    assert("3 STARS" in game.ui.result_header.text,"Gold presentation mismatched")
    var near_miss_summary: Label = game.ui.results_layer.find_child("Summary",true,false)
    assert("CLEAN PASSES  2 / 3" in near_miss_summary.text,
        "Successful near misses must become a visible replay goal")
    var report_scroll: ScrollContainer = game.ui.results_layer.find_child(
        "RaceResultsScroll",true,false) as ScrollContainer
    assert(report_scroll != null and near_miss_summary.get_parent() == report_scroll,
        "Long mastery/split result reports must scroll without hiding replay")
    assert(game.ui.replay_button_ref.visible,
        "Replay button must stay reachable after a detailed race report")
    var summary: Label = game.ui.results_layer.find_child("Summary",true,false)
    assert("CAREER STARS: 3 / 3" in summary.text, "Persistent stars must be visible")
    assert("TOP 5" in summary.text, "Leaderboard header should match five displayed rows")
    assert(summary.text.contains("38.25s") and not summary.text.contains("Unfinished Rival"))
    assert(game.ui.result_overview.text.contains("P2 / %d" % game.MARBLE_COUNT) and game.ui.result_overview.text.contains("43.00s"))
    var layout: int = game.built_variation
    game.ui.replay_button_ref.pressed.emit()
    assert(game.built_variation == layout and game.race_state == "COUNTDOWN")
    game.race_time = 15.0
    game.player.eliminated = true
    game._end_race()
    assert("DNF" in game.ui.result_header.text,"DNF must not show medals")
    assert(game.ui.result_overview.text.contains("OFF TRACK") and not game.ui.result_overview.text.contains("P%d" % game.MARBLE_COUNT))
    game.ui.next_layout_button.pressed.emit()
    assert(game.built_variation == (layout+1)%3 and game.race_state == "COUNTDOWN")
    game.race_time = game.current_timeout()
    game._end_race()
    assert(game.ui.result_overview.text.contains("TIME OUT"))
    game.ui.show_race_ui()
    game.race_state = "RACING"
    game.ui.last_seen_rank = game.MARBLE_COUNT
    game.ui.update_hud()
    assert(game.ui.position_feedback != null)
    print("POLISH_PASS: result grades, 5-racer summary, FX profiles, rank feedback")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
