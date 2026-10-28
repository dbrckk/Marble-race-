extends SceneTree
## Real 3D elevated-bridge precision gates in all biomes. Their outer
## physics posts create meaningful risk, but never block the racing center.
const BYPASS = preload("res://scripts/shortcut_route.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_bridge_precision.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var verified := 0
    for biome in range(3):
        assert(game.set_track(biome))
        var route: Node3D = game.shortcut_route
        assert(route.precision_posts.size() == 6)
        assert(route.precision_post_positions.size() == 6)
        var art := route.get_node("BypassPrecisionEdgePosts") as MultiMeshInstance3D
        var arches := route.get_node("BypassPrecisionPortalArches") as MultiMeshInstance3D
        assert(art.multimesh.instance_count == 6)
        assert(arches.multimesh.instance_count == 9)
        assert(art.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        assert(arches.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        for station in range(BYPASS.BRIDGE_POST_Z.size()):
            var z: float = BYPASS.BRIDGE_POST_Z[station]
            var center: Vector3 = route.point_at(z)
            for flank in range(2):
                var index: int = station*2+flank
                var post: StaticBody3D = route.precision_posts[index]
                var side: float = -1.0 if flank == 0 else 1.0
                var origin: Vector3 = route.precision_post_positions[index]
                assert(absf(origin.x-center.x-side*BYPASS.BRIDGE_POST_OFFSET) < 0.0001)
                assert(absf(origin.z-z) < 0.0001)
                assert(post.physics_material_override.bounce >= 0.45)
                assert(post.get_node("PhysicalShape") is CollisionShape3D)
                assert(absf(origin.x-center.x) > 1.60,
                    "Each banked bridge keeps a wide collision-free middle lane")
                assert(origin.y-center.y >= 0.70,
                    "Physical posts sit on the raised deck, not the valley below")
                verified += 1
            await physics_frame
            # Only the new physical posts may answer the side ray. Ignore
            # bridge decks and other existing course colliders.
            var ignored: Array[RID] = []
            for deck in route.decks:
                ignored.append(deck.get_rid())
            for guard in route.guards:
                ignored.append(guard.get_rid())
            for ramp in route.launch_ramps:
                ignored.append(ramp.get_rid())
            for marble in game.racers:
                ignored.append(marble.get_rid())
            var point: Vector3 = route.precision_post_positions[station*2]
            var ray := PhysicsRayQueryParameters3D.create(
                point+Vector3.UP*1.4,point+Vector3.DOWN*1.4)
            ray.exclude = ignored
            var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
            assert(hit.get("collider") == route.precision_posts[station*2],
                "A raised precision obstacle must be a genuine Godot collision")
            # The same ray through the center must not touch any of the
            # new physical precision posts.
            var middle := PhysicsRayQueryParameters3D.create(
                center+Vector3.UP*1.4,center+Vector3.DOWN*1.4)
            middle.exclude = ignored
            var center_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(middle)
            assert(not route.precision_posts.has(center_hit.get("collider")),
                "The centerline must remain free for human and AI racing")
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40)
        game.return_to_menu()
    assert(verified == 18)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_bridge_precision.cfg"))
    print("BRIDGE_PRECISION_PASS: 18 real raised edge colliders, nine GPU arch pieces, three safe racing corridors, 40 marbles")
    quit(0)
