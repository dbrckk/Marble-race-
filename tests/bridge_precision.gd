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
        var stripes := route.get_node("BypassPrecisionSkillStripes") as MultiMeshInstance3D
        assert(art.multimesh.instance_count == 6)
        assert(arches.multimesh.instance_count == BYPASS.BRIDGE_POST_Z.size())
        var stripe_count := 9 if biome == 0 else 3
        if biome == 2:
            assert(BYPASS.FORGE_GATE_APPROACH.size() == BYPASS.BRIDGE_POST_Z.size(),
                "Forge must guide all three real precision gates")
            for approach: Array in BYPASS.FORGE_GATE_APPROACH:
                stripe_count += approach.size()*2
        assert(stripes.multimesh.instance_count == stripe_count)
        # The dummy renderer exposes instance counts but no transform data.
        if biome == 2 and DisplayServer.get_name() != "headless":
            var stripe := 0
            for gate in range(BYPASS.FORGE_GATE_APPROACH.size()):
                stripe += 1 # Crossing stripe before the lead-in paint.
                for distance: float in BYPASS.FORGE_GATE_APPROACH[gate]:
                    var z: float = BYPASS.BRIDGE_POST_Z[gate]+distance
                    var left := stripes.multimesh.get_instance_transform(stripe).origin
                    var right := stripes.multimesh.get_instance_transform(stripe+1).origin
                    stripe += 2
                    var center := (left+right)*0.5
                    var deck: Vector3 = route.point_at(z)
                    assert(absf(center.z-z) < 0.001 and absf(center.x-deck.x) < 0.001)
                    assert(absf(left.distance_to(right)-2.0*BYPASS.PRECISION_GATE_HALF_WIDTH) < 0.001)
                    assert(center.y-deck.y > 0.20 and center.y-deck.y < 0.40,
                        "The lead paint must sit on the banked bridge")
        var frame: Mesh = arches.multimesh.mesh
        assert(frame is ArrayMesh and frame.get_surface_count() == 1)
        assert(arches.get_child_count() == 0)
        var profile := frame.surface_get_arrays(0)
        var vertices: PackedVector3Array = profile[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = profile[Mesh.ARRAY_INDEX]
        for offset in range(0,indices.size(),3):
            var side := signf(vertices[indices[offset]].x)
            for corner in range(3):
                assert(side*vertices[indices[offset+corner]].x > 1.5,
                    "Each portal wing must leave the central sightline open")
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
        assert(game.racers.size() == game.MARBLE_COUNT)
        game.return_to_menu()
    assert(verified == 18)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_bridge_precision.cfg"))
    print("BRIDGE_PRECISION_PASS: 18 real raised edge colliders, open instanced frames, three safe racing corridors, 30 marbles")
    quit(0)
