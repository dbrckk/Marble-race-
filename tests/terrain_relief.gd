extends SceneTree
## Verify physically rideable 3D elevation, synchronized visuals and an
## unchanged 40-marble ruleset. This is not a fake decorative ground bump.
const Path = preload("res://scripts/track_path.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for course in range(3):
        assert(is_equal_approx(Path.height_at(12.0,course),12.0*Path.BASE_SLOPE))
        assert(is_equal_approx(Path.height_at(-198.0,course),-198.0*Path.BASE_SLOPE))
        var max_relief := 0.0
        var max_grade := 0.0
        for step in range(211):
            var z: float = 12.0-float(step)
            var altitude: float = Path.height_at(z,course)
            var grade: float = Path.grade_at(z,course)
            max_relief = maxf(max_relief,absf(altitude-z*Path.BASE_SLOPE))
            max_grade = maxf(max_grade,grade)
            assert(is_finite(altitude) and is_finite(grade))
            assert(grade > -0.04 and grade < 0.22,
                "Course contour must remain physically traversable by rolling marbles")
        assert(max_relief >= [0.48,0.96,1.27][course],
            "Every biome needs a visibly different physical rise and fall")
        assert(max_grade >= [0.102,0.132,0.184][course],
            "Physical downhill grade needs meaningful variation")

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_terrain_relief_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    for course in range(3):
        assert(game.set_track(course))
        var road = game.track_surface
        assert(road.planks.size() == 180 and road.rails.size() == 106,
            "All original physical planks and protective rails must remain")
        for section in range(18):
            var z: float = 8.0-float(section)*12.0
            var module: Node3D = game.board.get_node("Course_%02d" % section)
            var plank: StaticBody3D = module.get_child(0) as StaticBody3D
            assert(plank != null and plank.get_child(0) is CollisionShape3D,
                "Each road section needs a real physical floor collision")
            var grade: float = game.track_grade_at(z)
            assert(absf(plank.rotation.x+atan(grade)) < 0.0001,
                "Physical plank tilts must follow the actual 3D hill")
            var batched: Dictionary = road.planks[section*10]
            assert(absf(float(batched["grade"])-grade) < 0.0001,
                "GPU road transforms must have the same pitch as physics")
            assert(absf((batched["at"] as Vector3).y-
                (game.height_at(z)-0.34)) < 0.0001,
                "Visual and physical floor elevations must agree")
        var ramp: StaticBody3D = game.shortcut_route.launch_ramps[0]
        var launch_z: float = float(game.shortcut_route.JUMP_Z[course])
        assert(absf(ramp.rotation.x+atan(game.track_grade_at(launch_z))-0.18) < 0.0001,
            "The alternate route launch must respect the new terrain angle")
        for zone in game.course_mechanics.zones:
            assert(absf(zone.global_position.y-game.height_at(zone.position.z)-0.035) < 0.001,
                "Biome effects cannot float above or vanish under the road")
        # Sections without gates have unobstructed collision floor. A ray
        # from above must strike real ground, including near the finish.
        await physics_frame
        for section in [0,17]:
            var sample_z: float = 8.0-float(section)*12.0
            var sample_x: float = game.track_center_at(sample_z)+0.67
            var origin := Vector3(sample_x,game.height_at(sample_z)+1.1,sample_z)
            var destination := Vector3(sample_x,game.height_at(sample_z)-1.9,sample_z)
            # The showroom legitimately spawns 40 frozen RigidBody3D marbles
            # at the start grid. A downward ground probe must ignore them;
            # otherwise it measures the top of a marble as "terrain".
            var floor_probe := PhysicsRayQueryParameters3D.create(origin,destination)
            # A Godot resource's Array property returns a copy here:
            # append to a local array and assign it back, otherwise the
            # ray exclusion is silently left empty.
            var ignored: Array[RID] = []
            for marble in game.racers:
                if is_instance_valid(marble):
                    ignored.append(marble.get_rid())
            floor_probe.exclude = ignored
            assert(floor_probe.exclude.size() == ignored.size(),
                "The physics query must actually exclude showroom marbles")
            var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(
                floor_probe)
            assert(not hit.is_empty(),"A marble must land on real physical road")
            if not (hit["collider"] is StaticBody3D):
                print("TERRAIN_RAY_DEBUG track=",course," section=",section,
                    " collider=",hit["collider"],
                    " type=",hit["collider"].get_class(),
                    " at=",hit["position"],
                    " origin=",origin,
                    " exclude_count=",floor_probe.exclude.size())
            assert(hit["collider"] is StaticBody3D,
                "Rideable elevation must be a physics surface, not a shader")
            assert(absf(float((hit["position"] as Vector3).y)-
                game.height_at(sample_z)) < 0.17,
                "Collision elevation must match the visible rolling surface")
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40 and game.player != null,
            "Richer terrain cannot reduce the real racing grid")
        game.return_to_menu()
    game.queue_free()
    await process_frame
    print("TERRAIN_RELIEF_PASS: 3 real hill profiles, 180 physical planks, visual parity, safe grade, 40 racers")
    quit(0)
