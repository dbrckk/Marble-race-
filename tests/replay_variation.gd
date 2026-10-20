extends SceneTree
func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_variation_career.cfg"
    var first_layout: int = game.built_variation
    assert(first_layout == 0)
    var gates: int = game.hazard_beacons.size()
    assert(gates == 28, "Expected two physical edge hazards across fourteen sections")
    var near_gate: Dictionary = game.upcoming_hazard(float(game.hazard_beacons[0]["z"]) + 12.0)
    assert(not near_gate.is_empty() and int(near_gate["distance"]) <= 12,
        "Lookahead must report approaching gate")
    var layouts: Array[int] = []
    for attempt in range(4):
        game.start_race("Grip Tape")
        layouts.append(game.built_variation)
        assert(game.board.get_parent() == game)
        assert(game.board.get_meta("track_index") == game.selected_track)
        assert(game.ui.hazard_label != null, "Upcoming gate warning not attached")
        assert(game.racers.size() == 40, "Race must have 40 marbles")
        game.return_to_menu()
        await process_frame
    assert(layouts == [0,1,2,0], "Repeat runs must cycle all three obstacle layouts")
    assert(game.get_tree().get_nodes_in_group("placeholder_empty").size() == 0)
    var boards: int = 0
    for child in game.get_children():
        if child.name == "HandcraftedWoodenCourse":
            boards += 1
    assert(boards == 1, "Old course was left in the scene and could double physics")
    print("VARIATION_AND_HAZARD_PASS: 0-1-2-0, 28 edge hazards, HUD warning, one course, 40 racers")
    game.queue_free()
    for n in range(4):
        await process_frame
    quit(0)
