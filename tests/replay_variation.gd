extends SceneTree
const TrackSurface = preload("res://scripts/track_surface.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _check_rail_batch(game: Node3D, biome: int) -> Mesh:
    var art := game.track_surface.get_node("ProfiledSafetyRails") as MultiMeshInstance3D
    var instances := art.multimesh
    var mesh := instances.mesh
    assert(mesh.get_surface_count() == 1 and mesh.get_faces().size()/3 <= 60,
        "Keep one lightweight draw surface per continuous rail profile")
    assert(mesh.get_aabb().size.is_equal_approx(TrackSurface.RAIL),
        "Rail silhouette needs to stay within the hitbox envelope")
    var expected := 105 if biome == 1 else 106
    assert(instances.instance_count == expected, "Preserve every rail and shortcut opening")
    var index := 0
    for section in game.board.get_children():
        if not section.name.begins_with("Course_"):
            continue
        for child in section.get_children():
            if not child is StaticBody3D or child.get_child_count() != 1:
                continue
            var collider := child.get_child(0) as CollisionShape3D
            if collider == null or not collider.shape is BoxShape3D:
                continue
            if not collider.shape.size.is_equal_approx(TrackSurface.RAIL):
                continue
            # The headless renderer's dummy MultiMesh does not read transforms back.
            var pose: Transform3D = art.global_transform * game.track_surface.rails[index]
            assert(child.global_transform.is_equal_approx(pose),
                "Rendered rails must follow the physical guards and track slope")
            index += 1
    assert(index == expected)
    game.set_graphics_quality(0)
    assert(art.is_visible_in_tree(), "Every quality tier must show the course boundaries")
    game.set_graphics_quality(1)
    return mesh

func _check_start_gate(game: Node3D) -> Mesh:
    var gate: Node3D = game.start_gate
    var towers := gate.get_node("StartTowers") as MeshInstance3D
    var lamps := gate.get_node("SignalLamps") as MultiMeshInstance3D
    var mesh := towers.mesh
    assert(gate.get_child_count() == 2 and mesh.get_surface_count() == 1)
    assert(lamps.multimesh.instance_count == 6 and lamps.multimesh.use_colors)
    assert(towers.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
        lamps.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    for vertex in mesh.get_faces():
        assert(absf(vertex.x) >= 5.6, "Keep the approach to the first obstacle unobstructed")
    var signal_label: Label = game.ui.countdown_label
    var panel := signal_label.get_parent() as Control
    assert(panel.anchor_right < 0.2 and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(signal_label.is_visible_in_tree() and signal_label.text == "READY")
    assert(gate.signal_stage == -1)
    for count in [3,2,1]:
        game.countdown = float(count)
        game._process(1.0/60.0)
        assert(gate.signal_stage == count and signal_label.text == str(count))
        assert(game.player.freeze and game.race_state == "COUNTDOWN")
    game.countdown = 0.01
    game._process(1.0/60.0)
    assert(gate.signal_stage == 0 and signal_label.text == "GO!")
    assert(not game.player.freeze and game.race_state == "RACING")
    game.race_time = 1.0
    game._process(1.0/60.0)
    assert(gate.signal_stage == -1 and not signal_label.is_visible_in_tree())
    return mesh

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
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var profiles: Array[Mesh] = []
    var gates_by_biome: Array[Mesh] = []
    for biome in range(3):
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            assert(game.built_variation == layout and game.racers.size() == 40)
            var profile := _check_rail_batch(game,biome)
            var frame := _check_start_gate(game)
            if layout == 0:
                assert(profile not in profiles, "Each biome needs its own geometry")
                assert(frame not in gates_by_biome, "Each biome needs its own starting towers")
                profiles.append(profile)
                gates_by_biome.append(frame)
            else:
                assert(profile == profiles[biome], "Reuse geometry across layout changes")
                assert(frame == gates_by_biome[biome], "Reuse tower geometry across layout changes")
            game.return_to_menu()
            await process_frame
    print("RAIL_PROFILE_PASS: 9 layouts, 40 racers, all guards match physics, one rail batch")
    print("START_GATE_PASS: 9 layouts, 40 racers, open sightline, countdown, launch and reset")
    game.queue_free()
    for n in range(4):
        await process_frame
    quit(0)
