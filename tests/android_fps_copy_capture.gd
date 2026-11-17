extends Node
const Budget = preload("res://scripts/performance_budget.gd")

func _ready() -> void:
    if OS.get_name() == "Android":
        call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var focus_deadline := Time.get_ticks_msec()+18000
    while not get_window().has_focus() and Time.get_ticks_msec() < focus_deadline:
        await get_tree().process_frame
    if not get_window().has_focus():
        _fail("Android did not give the game window focus")
        return
    var game = get_parent()
    if not game.show_fps:
        game.toggle_fps_overlay()
    var seed := "Marble clipboard QA seed"
    DisplayServer.clipboard_set(seed)
    if not await _wait_for_clipboard(seed):
        _fail("Could not seed Android clipboard in the foreground")
        return
    var probe := "Marble clipboard timing\nNext line ±8 m"
    DisplayServer.clipboard_set(probe)
    var immediate := DisplayServer.clipboard_get() == probe
    var delayed := await _wait_for_clipboard(probe)
    print("MARBLE_CLIPBOARD_TIMING immediate=",immediate," delayed=",delayed)
    if not delayed:
        _fail("Android did not deliver the clipboard probe")
        return

    game.start_race("Grip Tape")
    _show_sample_results(game)
    await get_tree().process_frame
    await get_tree().process_frame
    var report: String = game.ui.performance_text
    var button: Button = game.ui.copy_performance
    if report.is_empty() or not button.is_visible_in_tree():
        _fail("FPS report action was missing in results")
        return
    var center := button.get_global_rect().get_center()
    var window_size := Vector2(DisplayServer.window_get_size())
    var tap := center*window_size/get_viewport().get_visible_rect().size
    print("MARBLE_CLIPBOARD_READY ",int(tap.x)," ",int(tap.y))
    var deadline := Time.get_ticks_msec()+35000
    while button.text != "REPORT COPIED" and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    if button.text != "REPORT COPIED" or DisplayServer.clipboard_get() != report:
        _fail("Tapping COPY FPS REPORT did not put the full report in Android clipboard")
        return
    print("MARBLE_CLIPBOARD_MATCH bytes=",report.to_utf8_buffer().size(),
        " lines=",report.split("\n").size())

    game.ui._show_fps_report(report)
    await get_tree().process_frame
    if not game.ui.performance_report_dialog.visible or (
        game.ui.performance_report_input.text != report or game.ui.performance_report_input.editable):
        _fail("The full report fallback was not visible and read-only")
        return
    game.ui.performance_report_dialog.hide()
    game.ui.copy_performance.pressed.emit()
    game.ui.compare_performance.pressed.emit()
    _show_sample_results(game)
    await get_tree().create_timer(0.8).timeout
    if game.ui.copy_performance.text != "COPY FPS REPORT" or (
        game.ui.copy_performance.disabled or game.ui.performance_report_dialog.visible):
        _fail("A stale copy affected a newer results screen")
        return
    game.ui._show_fps_report(game.ui.performance_text)
    print("MARBLE_CLIPBOARD_PASS copy, exact contents, fallback, replay")

func _show_sample_results(game: Node) -> void:
    game.performance_budget.record_frame(1000,0,Budget.Focus.LAUNCH)
    game.performance_budget.record_frame(17667,1,Budget.Focus.BRIDGE_RETURN)
    game.performance_budget.record_frame(57667,1)
    game._end_race()

func _wait_for_clipboard(expected: String) -> bool:
    for attempt in range(12):
        await get_tree().create_timer(0.15).timeout
        if DisplayServer.clipboard_get() == expected:
            return true
    return false

func _fail(message: String) -> void:
    print("MARBLE_CLIPBOARD_FAILURE ",message)
    get_tree().quit(1)
