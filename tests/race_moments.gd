extends SceneTree
## Race presentation is based on actual crossing geometry, never positions
## invented from rankings or data written by network clients.
const Moments = preload("res://scripts/race_moments.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(Moments.genuine_overtake(-1.3,1.4,0.3,0.1,-2.5,2.7,false),
        "A real downhill crossing near a rival must be recognizable")
    assert(not Moments.genuine_overtake(-1.3,1.4,5.5,0.0,-2.5,2.7,false),
        "Passing in a separate lane too far away is not a close overtake")
    assert(not Moments.genuine_overtake(-1.3,1.4,0.2,4.0,-2.5,2.7,false),
        "Different track elevations must not become false overtakes")
    assert(not Moments.genuine_overtake(-1.3,1.4,0.2,0.1,2.5,2.7,false),
        "Retreating or reversing cannot earn a downhill overtake")
    assert(not Moments.genuine_overtake(-1.3,1.4,0.2,0.1,-2.5,18.0,false),
        "Teleportation must not trigger the pass announcement")
    assert(not Moments.genuine_overtake(-1.3,1.4,0.2,0.1,-2.5,2.7,true),
        "A teleporting AI cannot award a race pass")
    assert(Moments.genuine_side_duel(0.45,1.25,0.25,14.0,13.0),
        "Two fast marbles at the same road height should enter a close duel")
    assert(not Moments.genuine_side_duel(0.45,1.25,4.0,14.0,13.0),
        "Marbles on different elevation decks cannot become a duel")
    assert(not Moments.genuine_side_duel(0.45,1.25,0.0,2.0,13.0),
        "Parked rivals do not generate false shoulder-to-shoulder drama")
    assert(not Moments.genuine_side_duel(0.45,3.5,0.0,14.0,13.0),
        "Distant lanes do not qualify as a close contest")
    assert(not Moments.genuine_side_duel(0.45,0.2,0.0,14.0,13.0),
        "Actual overlapping marbles are a collision, not a duel")
    assert(not Moments.genuine_side_duel(6.0,1.25,0.0,14.0,13.0),
        "A lone chase several metres behind is not side-by-side")
    assert(Moments.edge_intensity(30.0,true,0) == 0.0,
        "Economy preset must disable decorative motion streaks")
    assert(Moments.edge_intensity(20.0,false,2) >
        Moments.edge_intensity(20.0,false,1),
        "Ultra may show slightly stronger speed motion")
    assert(Moments.edge_intensity(2.0,false,2) == 0.0,
        "Stopped racers must never show fake velocity streaks")
    assert(Moments.edge_intensity(7.0,true,1) > 0.0,
        "Boost ignition should remain perceptible below maximum speed")

    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path = "user://test_arcade_race_moments.cfg"
    stage.start_race("Grip Tape")
    stage.set_process(false)
    stage.set_physics_process(false)
    stage.race_state = "RACING"
    var p: RigidBody3D = stage.player
    assert(stage.race_moments != null)
    assert(stage.ui.race_moment_label != null)
    assert(stage.ui.duel_label != null and
        stage.ui.duel_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "Nearby rival callout must never block steering or boost touches")
    assert(stage.ui.speed_stripes.size() == 4,
        "Four tiny color rectangles are the full speed FX budget")
    for quad in stage.ui.speed_stripes:
        assert(quad.mouse_filter == Control.MOUSE_FILTER_IGNORE,
            "Speed FX must never steal joystick or boost touches")
    var rival: RigidBody3D = stage.racers[0]
    var second_rival: RigidBody3D = stage.racers[1]
    var third_rival: RigidBody3D = stage.racers[2]
    for marble in stage.racers:
        if marble != p:
            marble.global_position = Vector3(25,0,14)
    var elevation: float = stage.height_at(-20.0)+0.8
    p.global_position = Vector3(0,elevation,-20.0)
    rival.global_position = Vector3(0,elevation,-22.2)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.unique_overtakes == 0)
    assert(stage.race_moments.closest_rival_name == rival.display_name and
        stage.race_moments.closest_rival_ahead and
        absf(stage.race_moments.closest_rival_gap-2.2) < 0.01,
        "Real closest challenger must be sampled from physics positions")
    stage.ui.label_timer = 0.50
    stage.ui.update_hud()
    assert(stage.ui.duel_label.visible and
        stage.ui.duel_label.text.contains("CHASE"),
        "Player should see the nearest opponent ahead")
    p.global_position = Vector3(0,elevation,-23.5)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.unique_overtakes == 1,
        "A real relative crossing should count exactly one rival")
    assert(stage.ui.race_moment_label.text == "CLEAN OVERTAKE!")
    stage.ui.label_timer = 0.50
    stage.ui.update_hud()
    assert(stage.ui.duel_label.visible and
        stage.ui.duel_label.text.contains("DEFEND"),
        "Passing the opponent should reverse the close-rival callout")
    # Back-and-forth movement may change ranking but must never farm a
    # second visual achievement against the same marble.
    p.global_position = Vector3(0,elevation,-20.0)
    stage.race_moments.tick(0.12)
    p.global_position = Vector3(0,elevation,-23.5)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.unique_overtakes == 1,
        "An already counted rival must not yield duplicate overtake credit")
    # Teleporting an ahead opponent behind the player is not a pass.
    second_rival.global_position = Vector3(0,elevation,-25.0)
    stage.race_moments.tick(0.12)
    second_rival.global_position = Vector3(0,elevation,12.0)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.unique_overtakes == 1,
        "Recovery jumps cannot be counted as overtakes")
    second_rival.global_position = Vector3(0,elevation+8.0,-24.0)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.closest_rival_name != second_rival.display_name,
        "Opponents on elevated bridges must not appear as nearby duels")
    # Final-straight cue fires once. It never adds boosts, wins, mastery or
    # arbitrary extra finishers.
    stage.race_moments.message_at = -100.0
    p.global_position = Vector3(0,stage.height_at(-161.0)+0.8,-161.0)
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.final_stretch_seen)
    assert(stage.ui.race_moment_label.text == "FINAL STRAIGHT")
    stage.race_moments.tick(0.12)
    assert(stage.race_moments.unique_overtakes == 1)
    stage.race_moments.reset_round()
    assert(stage.race_moments.unique_overtakes == 0 and
        not stage.race_moments.final_stretch_seen,
        "Rematches must reset local one-time race direction flags")

    # Hold a true same-level two-marble duel for multiple real 10Hz
    # samples. Only that verified fight may receive a one-shot cue.
    for marble in stage.racers:
        if marble != p:
            marble.global_position = Vector3(25.0,0.0,14.0)
    var duel_z: float = -80.0
    var duel_center: float = stage.track_center_at(duel_z)
    var duel_height: float = stage.height_at(duel_z)+0.80
    p.global_position = Vector3(duel_center,duel_height,duel_z)
    rival.global_position = Vector3(duel_center+1.30,duel_height,duel_z-0.40)
    p.linear_velocity = Vector3(0.0,0.0,-13.0)
    rival.linear_velocity = Vector3(0.0,0.0,-13.5)
    rival.finished = false
    for sample in range(6):
        stage.race_moments.tick(0.12)
    assert(stage.race_moments.side_by_side_active and
        stage.race_moments.side_by_side_events == 1,
        "A sustained honest wheel-to-wheel duel must get exactly one cue")
    assert(stage.ui.race_moment_label.text == "SIDE BY SIDE!",
        "Duel announcement must come from actual rigid-body track positions")
    stage.ui.label_timer = 0.5
    stage.ui.update_hud()
    assert(stage.ui.duel_label.visible and
        stage.ui.duel_label.text.contains("SIDE BY SIDE"),
        "Android's existing no-touch duel banner should identify a real contest")
    for sample in range(15):
        stage.race_moments.tick(0.12)
    assert(stage.race_moments.side_by_side_events == 1,
        "Staying alongside the same opponent must not spam sound and alerts")
    rival.global_position.y += 5.0
    stage.race_moments.tick(0.12)
    assert(not stage.race_moments.side_by_side_active,
        "An elevated road must immediately end the same-level duel cue")
    stage.race_moments.reset_round()
    assert(stage.race_moments.side_by_side_events == 0 and
        not stage.race_moments.side_by_side_active and
        stage.race_moments.duel_announced.is_empty(),
        "Rematches must reset duel anti-spam and local presentation stats")
    p.global_position = Vector3(0,stage.height_at(-182.0)+0.8,-182.0)
    p.finished = true
    p.finish_time = 52.0
    rival.finished = true
    rival.finish_time = 52.2
    stage.race_moments.on_finish()
    assert(stage.race_moments.finish_seen)
    assert(stage.ui.race_moment_label.text == "PHOTO FINISH!",
        "Two real finishing times within half a second deserve a photo cue")
    stage.race_moments.on_finish()
    assert(stage.ui.race_moment_label.text == "PHOTO FINISH!",
        "Repeated finish signals must not retrigger the cinematic cue")

    # Both Android graphic tiers and rest screen stay usable without
    # any postprocess shaders or gameplay camera changes.
    p.finished = false
    stage.race_moments.local_speed = 25.0
    for quality in range(3):
        stage.set_graphics_quality(quality)
        stage.ui.label_timer = 0.50
        stage.ui.update_hud()
        for streak in stage.ui.speed_stripes:
            assert(streak.visible == (quality > 0),
                "Only BALANCED and ULTRA are allowed speed streaks")
            assert(streak.color.a <= 0.20,
                "Speed streaks must not obscure track visibility")
    stage.ui.show_race_moment("TEST",0.1)
    stage.ui.update_hud()
    assert(stage.ui.race_moment_label.visible)
    # Solo results show presentation stats, but no online rewards are
    # credited from this locally computed number.
    stage.last_result = {"finished":true,"stars":1,
        "overtakes":4,"record":false,"unlocked":false}
    stage.ui.show_results(8,60.0,stage.get_rankings())
    var summary: Label = stage.ui.results_layer.find_child("Summary",true,false)
    assert(summary.text.contains("OVERTAKES 4"),
        "Physical pass total must appear on solo results without affecting rewards")
    stage.return_to_menu()
    stage.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://test_arcade_race_moments.cfg"))
    print("RACE_MOMENTS_PASS: legitimate overtakes, held side duels, clean resets, finish drama, mobile HUD, no ranking cheats")
    quit()
