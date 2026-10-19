extends SceneTree
## Synthetic two-finger touch regression; no physical Android device required.
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var race = load("res://scenes/main.tscn").instantiate()
    root.add_child(race)
    await process_frame
    race.start_race("Grip Tape")
    race.countdown = 0.01
    for i in range(8):
        await physics_frame
        await process_frame
    var pad = race.ui.touch_controls
    assert(pad != null, "Missing joystick")
    pad.left_handed = false
    pad.sensitivity = 1.0
    print("TOUCH_TEST_DIMENSIONS ",pad.get_viewport_rect().size," ",pad.visible," ",race.race_state)
    assert(race.race_state == "RACING", "Race did not begin")
    pad._finger_event(1,Vector2(210,590),true)
    pad._move_finger(1,Vector2(295,590))
    print("TOUCH_TEST_ANALOG ",pad.steer," finger ",pad.joystick_finger)
    assert(pad.steer > 0.4, "Analog finger movement not calibrated")
    assert(race.steer_target > 0.4, "Touch steering not connected to game")
    pad._finger_event(2,Vector2(890,570),true)
    assert(pad.boost_pressed and race.boosting, "Second finger should boost")
    pad._finger_event(2,Vector2(890,570),false)
    assert(not pad.boost_pressed and not race.boosting, "Boost release should not latch")
    assert(pad.steer > 0.4, "Second-finger release should not cancel joystick")
    pad._finger_event(1,Vector2(295,590),false)
    assert(is_zero_approx(pad.steer), "Joystick should recenter on lift")
    pad._finger_event(3,Vector2(890,698),true)
    assert(not pad.boost_pressed, "Camera button zone must not trigger boost")
    pad._finger_event(3,Vector2(890,698),false)
    race.ui._sensitivity_pressed()
    var config := ConfigFile.new()
    assert(config.load("user://marble_settings.cfg") == OK, "Settings not saved")
    assert(int(config.get_value("controls","sensitivity",-1)) == race.ui.sensitivity_index, "Sensitivity missing")
    race.ui.left_handed = false
    race.ui._hand_pressed()
    assert(pad.left_handed, "Left handed layout not activated")
    pad._finger_event(4,Vector2(1060,585),true)
    pad._move_finger(4,Vector2(965,585))
    assert(pad.steer < -0.3, "Left handed joystick should work on right side")
    pad.release_all()
    assert(not race.boosting and is_zero_approx(pad.steer), "Touch cleanup should release both controls")
    race.ui.show_menu()
    assert(not pad.is_visible_in_tree(), "Race pad must hide on title screen")
    print("TOUCH_CONTROLS_PASS: two fingers, boost release, analog steer, left hand, settings, safety")
    race.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
