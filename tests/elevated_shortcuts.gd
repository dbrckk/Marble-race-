extends SceneTree
## Three *physical* elevated alternate roads, not purely visual bridges.
## Confirms GPU batches, grade continuity, actual floor contacts, and 40 racers.
const Bypass = preload("res://scripts/shortcut_route.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_elevated_bypass_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var previous_peak := 0.0
    for biome in range(3):
        assert(game.set_track(biome))
        var road = game.shortcut_route
        assert(road.course_id == biome)
        assert(road.decks.size() == Bypass.SEGMENTS)
        assert(is_zero_approx(road.bridge_lift_at(Bypass.ENTRY_Z)))
        assert(is_zero_approx(road.bridge_lift_at(Bypass.EXIT_Z)))
        var bridge_mid: float = (Bypass.ENTRY_Z+Bypass.EXIT_Z)*0.5
        var peak: float = road.bridge_lift_at(bridge_mid)
        assert(peak >= previous_peak+0.29,
            "Each biome requires an increasingly pronounced real bridge crest")
        previous_peak = peak
        assert(peak >= [1.07,1.47,1.77][biome])
        var columns := road.get_node_or_null("BatchedBypassBridgePylons") as MultiMeshInstance3D
        var trusses := road.get_node_or_null("BatchedBypassBridgeTrusses") as MultiMeshInstance3D
        assert(is_instance_valid(columns) and is_instance_valid(trusses))
        assert(columns.multimesh.instance_count == 12)
        assert(trusses.multimesh.instance_count == 6)
        assert(columns.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        assert(trusses.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        assert(road.guards.size() >= 20,
            "Tall alternate road still needs real safety guard colliders")
        for sample in range(57):
            var z: float = lerpf(Bypass.ENTRY_Z,Bypass.EXIT_Z,float(sample)/56.0)
            var point: Vector3 = road.point_at(z)
            var relative: float = point.y-game.height_at(z)+0.28
            assert(absf(relative-road.bridge_lift_at(z)) < 0.0001,
                "The actual deck and its elevation profile must be identical")
            var next: Vector3 = road.point_at(z-0.20)
            var last: Vector3 = road.point_at(z+0.20)
            var grade: float = absf(next.y-last.y)/0.40
            assert(grade < Bypass.MAX_BRIDGE_GRADE,
                "Bridge entry/crest/exit too steep for stable rolling physics")
        await physics_frame
        # Test physical contact in the detached span, away from the side
        # rails. A decorative bridge without colliders must fail this test.
        for z in [-65.0,-77.0,-89.0]:
            var point: Vector3 = road.point_at(z)
            var query := PhysicsRayQueryParameters3D.create(
                point+Vector3.UP*1.45,point-Vector3.UP*1.45)
            var result: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
            assert(not result.is_empty(),
                "Raised bypass must have a physical landing surface")
            var collider: Object = result.get("collider")
            assert(collider is StaticBody3D)
            assert(str(collider.name).begins_with("BypassDeck_") or
                str(collider.name) == "BypassLaunchRamp",
                "Bridge rays must not collide with the distant main course")
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40)
        game.return_to_menu()
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_elevated_bypass_career.cfg"))
    print("ELEVATED_SHORTCUTS_PASS: three real graduated bridges, 12 pylons, six trusses, physical contacts, 40 racers")
    quit(0)
