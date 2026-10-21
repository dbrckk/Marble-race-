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
    game.last_result = {"finished":true,"stars":3,"record":true,
        "unlocked":true,"clean_passes":2}
    game.ui.show_results(2,43.0,game.get_rankings())
    assert("3 STARS" in game.ui.result_header.text,"Gold presentation mismatched")
    var near_miss_summary: Label = game.ui.results_layer.find_child("Summary",true,false)
    assert("CLEAN PASSES  2 / 3" in near_miss_summary.text,
        "Successful near misses must become a visible replay goal")
    var summary: Label = game.ui.results_layer.find_child("Summary",true,false)
    assert("CAREER STARS: 3 / 3" in summary.text, "Persistent stars must be visible")
    assert("TOP 5" in summary.text, "Leaderboard header should match five displayed rows")
    game.last_result = {"finished":false,"stars":0,"record":false,"unlocked":false}
    game.ui.show_results(40,155.0,game.get_rankings())
    assert("DNF" in game.ui.result_header.text,"DNF must not show medals")
    game.ui.show_race_ui()
    game.race_state = "RACING"
    game.ui.last_seen_rank = 40
    game.ui.update_hud()
    assert(game.ui.position_feedback != null)
    print("POLISH_PASS: result grades, 5-racer summary, FX profiles, rank feedback")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
