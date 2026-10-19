extends SceneTree
## End-user flows that headless physics checks cannot cover by themselves.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path="user://test_ui_career.cfg"
    game.career.starts=0
    game.career.finishes=0
    game.career.victories=0
    game.career.podiums=0
    game.career.unlocked=1
    game.career.track_best[0]=0
    game.ui.show_menu()
    game.ui._refresh_career_menu()
    assert(game.ui.track_buttons.size()==3,"Expected three selectable courses")
    assert(not game.ui.track_buttons[0].disabled)
    assert(game.ui.track_buttons[1].disabled)
    assert(game.ui.track_buttons[2].disabled)
    game.ui._select_track(2)
    assert(game.selected_track==0,"Locked course must not be selectable")
    game.career.unlocked=3
    game.ui._refresh_career_menu()
    assert(not game.ui.track_buttons[2].disabled)
    game.ui._select_track(1)
    assert(game.selected_track==1 and game.board.get_meta("track_index")==1)
    game.start_race("Grip Tape")
    game.countdown=0.01
    for i in range(10):
        await physics_frame
        await process_frame
    assert(game.ui.hud_layer.visible)
    assert(game.ui.remaining_label.text.contains("SWITCHBACK"),"Course label missing")
    assert(game.ui.touch_controls.is_visible_in_tree())
    game.player.finished=true
    game.player.finish_time=game.race_time
    game._end_race()
    assert(game.race_state=="RESULTS")
    assert(game.ui.results_layer.visible)
    assert(game.ui.result_header.text.contains("SWITCHBACK"))
    assert(game.career.finishes==1)
    game.return_to_menu()
    assert(game.ui.menu_layer.visible)
    assert(not game.ui.touch_controls.is_visible_in_tree())
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ui_career.cfg"))
    print("UI_PASS: locked selection, course change, race HUD, results, offline career")
    game.queue_free()
    for i in range(4): await process_frame
    quit(0)
