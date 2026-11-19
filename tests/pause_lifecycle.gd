extends SceneTree
## Pause/resume/restart/OS-background regression on real game scene.
func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    for n in range(3):
        await process_frame
    assert(scene.ui.pause_layer != null and not scene.ui.pause_layer.visible,
        "Pause dialog must start hidden")
    scene.start_race("Grip Tape")
    scene.countdown = 0.02
    for n in range(6):
        await process_frame
    assert(scene.race_state == "RACING", "Race did not start")
    scene.ui.touch_controls._set_steer(0.8)
    scene.ui.touch_controls._set_boost(true)
    assert(scene.boosting and scene.steer_target > 0.0, "Controls failed before pause")
    scene.ui.pause_race()
    assert(paused, "SceneTree must pause on user pause")
    assert(scene.ui.pause_layer.visible, "Pause menu must show")
    assert(not scene.boosting and absf(scene.steer_target) < 0.001,
        "Pause must release both controls")
    assert(scene.ui.pause_details.text.contains("Grip Tape".to_upper()),
        "Pause overlay must show current perk")
    var frozen_time: float = scene.race_time
    for n in range(5):
        await process_frame
    assert(is_equal_approx(scene.race_time,frozen_time),
        "Paused gameplay time must not advance")
    scene.ui.resume_race()
    assert(not paused and not scene.ui.pause_layer.visible, "Resume should unpause")
    scene.ui.pause_race()
    assert(paused, "Pause should be repeatable")
    var previous_board: Node3D = scene.board
    var previous_layout: int = scene.built_variation
    scene.ui._restart_from_pause()
    assert(scene.board == previous_board and scene.built_variation == previous_layout,
        "Restart from pause must replay the selected layout")
    assert(is_zero_approx(scene.kinetic_time), "Retry must reset the course mechanism clock")
    assert(not paused and scene.race_state == "COUNTDOWN",
        "Restart must rebuild a live race")
    assert(scene.racers.size() == scene.MARBLE_COUNT and not scene.ui.pause_layer.visible,
        "Restart should preserve all racers and hide pause menu")
    scene.countdown = 0.02
    for n in range(5):
        await process_frame
    scene.ui.notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
    assert(paused and scene.ui.pause_layer.visible,
        "Android background must pause active race")
    scene.ui._leave_from_pause()
    assert(not paused and scene.race_state == "MENU", "Exit should return to menu")
    assert(not scene.ui.pause_layer.visible and not scene.ui.touch_controls.boost_pressed,
        "Leaving paused race must clear overlays and controls")
    scene.net.role = "client"
    scene.net.connected = true
    scene.start_race("Grip Tape")
    scene.race_state = "RACING"
    scene.ui.touch_controls._set_steer(-0.8)
    scene.ui.touch_controls._set_boost(true)
    scene.ui.pause_button_ref.pressed.emit()
    assert(scene.ui.online_leave_layer.visible and not paused and scene.net.is_active())
    assert(not scene.ui.touch_controls.enabled and not scene.boosting and scene.steer_target == 0.0)
    scene.ui.online_stay_button.pressed.emit()
    assert(not scene.ui.online_leave_layer.visible and scene.ui.touch_controls.enabled and scene.net.is_active())
    scene.ui.pause_button_ref.pressed.emit()
    var leave := scene.ui.online_leave_layer.find_child("ConfirmLeaveRace", true, false) as Button
    leave.pressed.emit()
    assert(scene.race_state == "MENU" and not scene.net.is_active() and scene.ui.touch_controls.enabled)
    print("PAUSE_LIFECYCLE_PASS: race-time freeze, controls, resume, restart, Android background, menu")
    scene.queue_free()
    for n in range(4):
        await process_frame
    quit(0)
