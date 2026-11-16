extends Node
## Android-only capture, attached to the packaged scene by the QA workflow.
const ROUTE = preload("res://scripts/shortcut_route.gd")
const PERK := "Grip Tape"

func _ready() -> void:
    if OS.get_name() == "Android" or OS.has_environment("MARBLE_DESKTOP_QA"):
        call_deferred("_capture")

func _capture() -> void:
    await get_tree().process_frame
    var game = get_parent()
    game.career.unlocked = 3
    if not game.set_track(2):
        _fail("Forge could not be selected")
        return
    game.race_variation = 0
    game.set_graphics_quality(1)
    if not game.show_fps:
        game.toggle_fps_overlay()
    print("MARBLE_BENCH_DEVICE ",JSON.stringify({
        "os": OS.get_name(), "version": OS.get_version(),
        "gpu": RenderingServer.get_video_adapter_name(),
        "viewport": str(get_viewport().get_visible_rect().size),
        "fps_cap": Engine.max_fps
    }))
    await get_tree().create_timer(2.0).timeout
    game.start_race(PERK)
    for expected_quality in [1,0]:
        var saw_bridge_deck := false
        var merge_x: Variant = null
        var last_z := INF
        var deadline := Time.get_ticks_msec()+240000
        while game.race_state != "RESULTS":
            if Time.get_ticks_msec() >= deadline:
                _fail("Race did not reach results")
                return
            if game.race_state == "RACING" and is_instance_valid(game.player):
                var at: Vector3 = game.player.global_position
                if not saw_bridge_deck and at.z <= ROUTE.ENTRY_Z and at.z >= ROUTE.EXIT_Z:
                    saw_bridge_deck = game.shortcut_route.on_separate_deck(at)
                if merge_x == null and last_z > ROUTE.EXIT_Z and at.z <= ROUTE.EXIT_Z:
                    merge_x = snappedf(at.x,0.01)
                last_z = at.z
            await get_tree().process_frame
        if not game.player.finished or merge_x == null or game.racers.size() != 40:
            _fail("Race did not finish naturally with 40 racers and a sampled merge")
            return
        if game.selected_track != 2 or game.built_variation != 0 or (
            game.selected_perk != PERK or game.graphics_quality != expected_quality):
            _fail("The profile replay changed the comparison conditions")
            return
        var report: String = game.ui.performance_text
        for label in ["FIRST 5s","BRIDGE RETURN ±8 m"]:
            if not report.contains(label+" | ") or report.contains(label+" | NO SAMPLES"):
                _fail("Report missing samples for "+label)
                return
        game.ui.copy_performance.pressed.emit()
        print("MARBLE_BENCH_REPORT ",JSON.stringify({
            "quality": game.graphics_mode_label(),
            "finish_s": game.player.finish_time,
            "merge_x": merge_x, "bridge_deck": saw_bridge_deck,
            "clipboard_match": DisplayServer.clipboard_get() == report,
            "report": report
        }))
        if expected_quality == 1:
            if not game.ui.compare_performance.is_visible_in_tree():
                _fail("Same-layout profile replay button missing")
                return
            await get_tree().create_timer(2.0).timeout
            game.ui.compare_performance.pressed.emit()
            if game.race_state != "COUNTDOWN":
                _fail("Profile replay did not restart the race")
                return
    print("MARBLE_BENCH_COMPLETE")
    if OS.get_name() != "Android":
        get_tree().quit()

func _fail(message: String) -> void:
    print("MARBLE_BENCH_FAILURE ",message)
    get_tree().quit(1)
