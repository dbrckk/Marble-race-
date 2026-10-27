extends SceneTree
## Winding v1.15 scene regression: physical segments, seam rails, AI and gameplay zones.
const Path = preload("res://scripts/track_path.gd")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_winding_courses.cfg"
    game.career.unlocked = 3
    assert(is_zero_approx(Path.center_at(12.0,0)))
    assert(absf(Path.center_at(-198.0,2)) < 0.001)
    for course in range(3):
        # The same relief drives collision modules, visual planks and AI.
        # Both endpoints must retain the original safe starting/finish grade.
        assert(absf(Path.height_at(12.0,course)-12.0*Path.BASE_SLOPE) < 0.001)
        assert(absf(Path.height_at(-198.0,course)+198.0*Path.BASE_SLOPE) < 0.001)
        var max_grade := 0.0
        var relief_range := 0.0
        for sample in range(421):
            var z: float = 12.0-float(sample)*0.5
            var grade: float = Path.grade_at(z,course)
            assert(is_finite(grade) and absf(grade) < 0.58,
                "Rolling crests must not become near-vertical physical ramps")
            max_grade = maxf(max_grade,absf(grade))
            relief_range = maxf(relief_range,absf(
                Path.height_at(z,course)-z*Path.BASE_SLOPE))
        assert(relief_range > [0.40,0.80,1.10][course],
            "All biomes must have real, measurable 3D terrain relief")
        assert(max_grade > 0.08)
        assert(game.set_track(course))
        assert(game.board.get_meta("track_index") == course)
        var farthest := 0.0
        var drift_max := 0.0
        for section in range(18):
            var z := 8.0-float(section)*12.0
            var module: Node3D = game.board.get_node("Course_%02d" % section)
            var expected: float = Path.center_at(z,course)
            assert(absf(module.position.x-expected) < 0.001,
                "Physics section and centerline must match")
            farthest = maxf(farthest,absf(expected))
            if section < 17:
                var diff: float = Path.seam_drift(section,course)
                drift_max = maxf(drift_max,absf(diff))
                assert(absf(diff) < 1.5,"Turn exceeds protective overlap")
                var seam: StaticBody3D = game.board.get_node("ContinuousBendFloor_%02d" % section)
                assert(is_instance_valid(seam), "Physical ground joins must not be missing")
                var seam_shape: CollisionShape3D = seam.get_child(0) as CollisionShape3D
                assert(seam_shape != null and (seam_shape.shape as BoxShape3D).size.x >=
                    13.2+absf(diff)-0.01,"Bend floor must cover staggered edges")
                for side in ["L","R"]:
                    var guard: StaticBody3D = game.board.get_node(
                        "AngledBendGuard_%02d_%s" % [section,side])
                    assert(is_instance_valid(guard),"Both angled safety rails required")
                    assert(absf(guard.rotation.y) < 0.42,
                        "Sudden wall direction changes would trap marbles")
        assert(farthest > [0.30,0.50,0.85][course],
            "Each course must feature visible lateral turns")
        assert(drift_max > [0.05,0.13,0.22][course],
            "Directional curvature must affect physical junctions")
        assert(game.track_surface.planks.size() == 180,
            "Original GPU-batched track density is preserved")
        var first_plank: Dictionary = game.track_surface.planks[10]
        assert(absf(float((first_plank["at"] as Vector3).x)-
            (game.board.get_node("Course_01").position.x-6.03)) < 0.2,
            "GPU ground meshes must follow physical section translation")
        for item in game.race_items.items:
            assert(absf(item.global_position.x-game.track_center_at(item.position.z)) < 4.0,
                "Rare collectibles must stay inside the winding track")
        for zone in game.course_mechanics.zones:
            assert(absf(zone.global_position.x-game.track_center_at(zone.position.z)) < 4.0,
                "Terrain power zones must follow the active racing line")
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40)
        for marble in game.racers:
            assert(marble.course_owner == game,"AI needs authoritative track center")
            assert(absf(marble.position.x-game.track_center_at(marble.position.z)) < 6.1,
                "Starting grid may not spawn outside the bends")
        game.return_to_menu()
    print("WINDING_TRACKS_PASS:")
    game.queue_free()
    await process_frame
    quit()
