extends SceneTree
## Four-sector race timing, persistence and anti-skip regression.
const Career = preload("res://scripts/career.gd")
func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var c := Career.new()
    c.save_path = "user://test_splits_v14.cfg"
    c.sector_best.fill(0.0)
    assert(c.record_sectors(0,[20.0,25.0,30.0,15.0]) == [true,true,true,true])
    assert(c.best_sector(0,0) == 20.0 and c.best_sector(1,0) == 0.0)
    assert(c.record_sectors(0,[22.0,24.0,30.0,17.0]) == [false,true,false,false])
    assert(c.record_sectors(0,[0.0,3.0,4.0,5.0]) == [false,false,false,false])
    assert(c.record_sectors(0,[NAN,2.0,3.0,4.0]) == [false,false,false,false])
    assert(c.record_sectors(0,[1.0,2.0,3.0]) == [false,false,false,false])
    assert(c.record_sectors(4,[5.0,5.0,5.0,5.0]) == [false,false,false,false])
    assert(c.record_sectors(2,[30.0,33.0,35.0,40.0]) == [true,true,true,true])
    var restored := Career.new()
    restored.save_path = c.save_path
    restored.load_save()
    assert(restored.best_sector(0,1) == 24.0 and restored.best_sector(2,3) == 40.0)
    assert(restored.best_sector(1,0) == 0.0)

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_live_splits_v14.cfg"
    game.career.sector_best.fill(0.0)
    game.best_ghost.save_path = "user://test_live_ghost_splits.cfg"
    game.race_variation = 1
    var ghost_key: String = game.best_ghost.storage_key(0,game.race_variation,"Grip Tape")
    var ghost := ConfigFile.new()
    ghost.set_value(ghost_key,"best_time",100.0)
    ghost.set_value(ghost_key,"checkpoints",PackedFloat64Array([21.0,44.0,80.0]))
    ghost.set_value(ghost_key,"points",PackedVector3Array([Vector3(0,1,8),Vector3(0,1,6),Vector3(0,1,4)]))
    assert(ghost.save(game.best_ghost.save_path) == OK)
    game.set_graphics_quality(0)
    game.start_race("Grip Tape")
    var grid_z: float = game.player.position.z
    game.countdown = 0.01
    await process_frame
    for marble in game.racers:
        marble.freeze = true
    assert(game.race_state == "RACING")
    var z_targets := [-47.0,-107.0,-167.0]
    var times := [20.0,45.0,79.0]
    for k in range(3):
        var z: float = z_targets[k]
        game.player.position = Vector3(0.0,game.height_at(z)+0.65,z)
        game.race_time = times[k]
        game._process(0.016)
        assert(game.checkpoint_splits.size() == k+1,"Sector not captured")
        assert(game.last_checkpoint == k,"Sector number incorrect")
        assert(game.ui.checkpoint_label.text.contains("SECTOR %d" % (k+1)))
        var expected := "+1.02s" if k == 1 else "-0.98s"
        assert(game.ui.checkpoint_label.text.contains(expected + " VS GHOST"),
            "HUD must compare cumulative crossings even in Economy")
    game.player.finished = true
    game.player.finish_time = 98.0
    game._end_race()
    var result: Dictionary = game.last_result
    assert(result.get("sector_times",[]).size() == 4)
    assert(result.get("sector_records",[]) == [true,true,true,true])
    var splits: Array = result["sector_times"]
    assert(absf(float(splits[3])-19.0) < 0.05,"Finish sector must use actual finish time")
    assert(game.career.best_sector(0,3) > 18.9)
    var hud = game.ui
    assert(hud.sector_results.is_visible_in_tree() and hud.sector_result_row.is_visible_in_tree())
    assert(hud.sector_result_times[0].text == "20.02s ★")
    assert(hud.sector_result_times[3].text == "18.98s ★")
    var expected_gaps := ["-0.98s","+2.00s","-2.00s","-1.02s"]
    for sector in expected_gaps.size():
        assert(hud.sector_result_gaps[sector].text == expected_gaps[sector],
            "Results must show time gained or lost in this sector")
    assert(hud.sector_result_hint.is_visible_in_tree() and
        hud.sector_result_hint.text.contains("SECTOR 2  +2.00s"))
    assert(hud.sector_result_header.text.contains("FINISH -2.00s VS GHOST"),
        "Show the old ghost difference even after replacing it")
    var summary := hud.results_scroll.get_node("Summary") as Label
    assert(summary.text.contains("S1 -0.98s  •  S2 +1.02s  •  S3 -0.98s"),
        "The detailed report should retain cumulative checkpoint gaps")
    assert(bool(result["ghost_record"]) and is_equal_approx(game.best_ghost.best_time,98.0))

    game.career.unlocked = 2
    game.show_fps = true
    game.performance_budget.reset()
    game.performance_budget.record_frame(1000000,0)
    game.performance_budget.record_frame(1016000,0)
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    for frame in range(4):
        await process_frame
    assert(hud.performance_actions.is_visible_in_tree() and hud.next_course_button.is_visible_in_tree())
    var sectors_rect: Rect2 = hud.sector_results.get_global_rect()
    var report_rect: Rect2 = hud.results_scroll.get_global_rect()
    assert(sectors_rect.end.y <= report_rect.position.y and report_rect.size.y > 70.0,
        "Pinned sectors must leave the report scrollable with all actions visible")
    assert(hud.replay_button_ref.get_global_rect().end.y <= hud.next_course_button.get_global_rect().position.y)
    game.show_fps = false

    hud.sector_result_hint.pressed.emit()
    for frame in range(4):
        await process_frame
    assert(hud.sector_map_panel.is_visible_in_tree() and not hud.results_card.visible)
    assert(hud.sector_map_title.text.contains("LAYOUT 2") and hud.sector_map.variation == 1)
    assert(hud.sector_map.sector_bounds() == Vector2(game.CHECKPOINT_Z[0],game.CHECKPOINT_Z[1]))
    assert(hud.sector_map_boundaries.text.contains("EXIT  SECTOR 2 SIGN"))
    assert(hud.sector_map_landmarks.text.contains("BRIDGE FORK") and hud.sector_map_landmarks.text.contains("BRIDGE MERGE"))
    assert(hud.sector_map.drawn_sections == 65 and hud.sector_map.mouse_filter == Control.MOUSE_FILTER_STOP)
    assert(hud.sector_map.get_global_rect().end.y < hud.sector_map_back.get_global_rect().position.y)
    assert(hud.sector_map_buttons[1].button_pressed)
    var tap := InputEventScreenTouch.new()
    tap.pressed = true
    var map_x: float = hud.sector_map.project((game.CHECKPOINT_Z[1]+game.CHECKPOINT_Z[2])*0.5,0.0).x
    tap.position = hud.sector_map.get_global_transform_with_canvas()*Vector2(map_x,hud.sector_map.size.y*0.35)
    root.push_input(tap,true)
    tap.pressed = false
    root.push_input(tap,true)
    assert(hud.sector_map.focused_sector == 2 and hud.sector_map_buttons[2].button_pressed,
        "A touch between two checkpoints must select the physical sector")
    assert(not hud.sector_map_buttons[1].button_pressed and hud.sector_map_title.text.contains("SECTOR 3"))
    assert(hud.sector_map_landmarks.text.contains("FINAL OBSTACLES") and not hud.sector_map_landmarks.text.contains("BRIDGE FORK"))
    var back := InputEventAction.new()
    back.action = "ui_cancel"
    back.pressed = true
    hud._unhandled_input(back)
    assert(hud.results_card.is_visible_in_tree() and not hud.sector_map_panel.visible)

    game.net.role = "client"
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    assert(not hud.sector_results.visible and summary.text.begins_with("TOP FINISHERS"))
    game.net.role = "offline"

    result["ghost_deltas"] = [-1.0,-1.5,-1.51,-1.51]
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    assert(hud.sector_result_hint.text == "VIEW MAP  →  CHOOSE A SECTOR" and hud.sector_result_gaps[3].text == "0.00s")
    result["ghost_deltas"] = [NAN,NAN,NAN,-0.25]
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    assert(hud.sector_result_row.is_visible_in_tree() and
        hud.sector_result_header.text.contains("FINISH -0.25s VS GHOST"))
    for gap_label in hud.sector_result_gaps:
        assert(not gap_label.visible, "Legacy ghosts only supply a finish gap")
    result["ghost_deltas"] = []
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    assert(hud.sector_result_header.text == "SECTOR TIMES" and hud.sector_result_hint.visible)
    hud.sector_result_hint.pressed.emit()
    assert(hud.sector_map.focused_sector == 0 and not hud.sector_map_title.text.contains("VS GHOST"))
    hud.sector_map_buttons[1].pressed.emit()
    assert(hud.sector_map.focused_sector == 1 and hud.sector_map_title.text.contains("25.00s"))
    hud.sector_map_back.pressed.emit()

    result["ghost_deltas"] = [2.5,1.0,1.0,1.0]
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    hud.sector_result_hint.pressed.emit()
    assert(hud.sector_map.sector_bounds().is_equal_approx(Vector2(grid_z,game.CHECKPOINT_Z[0])))
    assert(hud.sector_map_boundaries.text.contains("ENTRY  START GRID"))
    hud.sector_map_buttons[3].pressed.emit()
    assert(hud.slowest_sector == 0 and hud.sector_map_buttons[3].button_pressed)
    assert(hud.sector_map.sector_bounds() == Vector2(game.CHECKPOINT_Z[-1],game.FINISH_Z))
    assert(hud.sector_map_boundaries.text.contains("EXIT  FINISH LINE"))
    hud.sector_map_panel.find_child("RetryFromSectorMap",true,false).pressed.emit()
    assert(not hud.sector_map_panel.visible and game.race_state == "COUNTDOWN")
    assert(game.built_variation == 1 and game.selected_perk == "Grip Tape")
    assert(is_equal_approx(game.best_ghost.crossing_delta(0,20.016),0.0))
    assert(game.practice_sector == 3 and hud.practice_entry_pending)
    assert(is_equal_approx(game.practice_previous_time,float(splits[3])))
    var entry: float = game.CHECKPOINT_Z[2]
    assert(is_equal_approx(hud.race_radar.practice_progress,-entry/absf(game.FINISH_Z)))
    game.race_state = "RACING"
    # A fast approach needs an earlier cue than a slow approach at the same spot.
    game.player.position.z = entry+30.0
    game.player.linear_velocity = Vector3(0.0,0.0,-5.0)
    hud.label_timer = 0.12
    hud.update_hud()
    assert(not hud.practice_hint_ready and not hud.practice_sector_label.visible)
    game.player.linear_velocity.z = -22.0
    hud.label_timer = 0.12
    hud.update_hud()
    assert(hud.practice_hint_ready and hud.practice_sector_label.text.contains("30 m TO ENTRY"))
    hud.timed_gate_backdrop.hide()
    hud.final_danger_active = false
    hud._refresh_race_notification()
    assert(hud.practice_sector_label.visible and hud.practice_sector_label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    hud.show_checkpoint(3,13.0)
    assert(hud.checkpoint_label.visible and not hud.practice_sector_label.visible)
    hud.toast_remaining = 0.0
    hud.timed_gate_backdrop.show()
    hud._refresh_race_notification()
    assert(not hud.practice_sector_label.visible and is_finite(hud.race_radar.practice_progress))

    game.player.position.z = entry-0.1
    hud.label_timer = 0.12
    hud.update_hud()
    assert(not hud.practice_entry_pending and is_nan(hud.race_radar.practice_progress))
    game.player.position.z = entry+3.0
    hud.label_timer = 0.12
    hud.update_hud()
    assert(not hud.practice_sector_label.visible, "Crossing back must not rearm the cue")

    game.checkpoint_splits.assign([20.0,44.0,78.0])
    game.player.finished = true
    game.player.finish_time = 96.0
    game._end_race()
    assert(hud.sector_retry_comparison.is_visible_in_tree())
    assert(hud.sector_retry_comparison.text == "SECTOR 4 VS LAST TRY   18.98s → 18.00s   •   0.98s FASTER")
    assert(hud.sector_result_header.text.contains("FINISH -2.00s VS GHOST"))

    result["ghost_deltas"] = [2.5,1.0,1.0,1.0]
    game.last_result = result
    game.race_state = "RESULTS"
    hud.show_results(game.player_rank(),98.0,game.get_rankings())
    hud.replay_button_ref.pressed.emit()
    hud.label_timer = 0.12
    hud.update_hud()
    assert(game.practice_sector == 0 and hud.practice_sector_label.visible and
        hud.practice_sector_label.text.contains("FROM THE START"))
    hud.pause_race()
    hud._restart_from_pause()
    assert(game.practice_sector == 0 and hud.practice_entry_pending)
    assert(is_equal_approx(game.practice_previous_time,float(splits[0])))

    game.checkpoint_splits.assign([21.0,45.0,79.0])
    game.player.finished = true
    game.player.finish_time = 98.9
    game._end_race()
    assert(hud.sector_retry_comparison.text == "SECTOR 1 VS LAST TRY   20.02s → 21.00s   •   0.98s SLOWER")
    assert(hud.slowest_sector == 0)
    game.show_fps = true
    game.performance_budget.record_frame(1000000,0)
    game.performance_budget.record_frame(1016000,0)
    hud.show_results(game.player_rank(),98.9,game.get_rankings())
    for frame in range(4):
        await process_frame
    assert(hud.performance_actions.is_visible_in_tree() and hud.sector_result_hint.is_visible_in_tree())
    assert(hud.sector_retry_comparison.is_visible_in_tree() and hud.results_scroll.size.y > 70.0)
    game.show_fps = false
    hud.replay_button_ref.pressed.emit()
    assert(is_equal_approx(game.practice_previous_time,21.0),"A second retry must use the latest completed run")
    game.checkpoint_splits.assign([21.004,45.0,79.0])
    game.player.finished = true
    game.player.finish_time = 98.9
    game._end_race()
    assert(hud.sector_retry_comparison.text.ends_with("SAME TIME"))
    game.net.role = "client"
    hud.show_results(game.player_rank(),98.9,game.get_rankings())
    assert(not hud.sector_retry_comparison.visible)
    game.net.role = "offline"
    hud.show_results(game.player_rank(),98.9,game.get_rankings())
    hud.replay_button_ref.pressed.emit()
    assert(is_finite(game.practice_previous_time))
    game.player.eliminated = true
    game._end_race()
    assert(not game.last_result.has("practice_comparison") and not hud.sector_retry_comparison.visible)

    var first_best: float = game.career.best_sector(0,0)
    game.return_to_menu()
    game.start_race("Grip Tape")
    assert(game.practice_sector == -1 and is_nan(game.practice_previous_time) and is_nan(hud.race_radar.practice_progress))
    game.countdown = 0.01
    await process_frame
    for marble in game.racers:
        marble.freeze = true
    # Jump over checkpoints; must not fabricate impossibly fast split PBs.
    game.player.position = Vector3(0.0,game.height_at(-168.0)+0.65,-168.0)
    game.race_time = 49.0
    game._process(0.016)
    assert(game.checkpoint_splits.is_empty(),"Skipped checkpoints must invalidate splits")
    game._end_race()
    assert(game.career.best_sector(0,0) == first_best,"DNF must retain previous record")
    assert(game.last_result["ghost_deltas"].is_empty() and not hud.sector_results.visible)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.best_ghost.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.career.save_path))
    print("SECTOR_TIMING_PASS: sector timing, touch selection, retry guidance, prior-attempt comparison, legacy saves and DNF protection")
    game.queue_free()
    for k in range(4):
        await process_frame
    quit(0)
