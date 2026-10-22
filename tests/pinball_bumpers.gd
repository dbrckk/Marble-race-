extends SceneTree
## Nine layouts, six real bumper colliders, real physics queries and
## GPU-batched mobile art. No fake finish, no scripted position changes.
const KICKERS = preload("res://scripts/arcade_bumpers.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_spring_post_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            assert(game.built_variation == layout)
            var kickers: Node3D = game.arcade_bumpers
            assert(is_instance_valid(kickers) and kickers.get_parent() == game.board)
            assert(kickers.bodies.size() == 6,
                "Every course variant requires six genuine bumpers")
            assert(kickers.cylinders.multimesh.instance_count == 6 and
                kickers.glow_rings.multimesh.instance_count == 12,
                "18 pieces of pinball artwork must use just two GPU batches")
            assert(kickers.cylinders.cast_shadow ==
                GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
                "Never create individual shadow passes for spring posts")
            assert(game.racers.size() == 40,
                "Keep all 39 physical opponents and the human racer")
            await physics_frame
            for body in kickers.bodies:
                assert(body is StaticBody3D and
                    body.physics_material_override is PhysicsMaterial,
                    "Spring rebounds require real physical collision material")
                assert(is_equal_approx(body.physics_material_override.bounce,
                    KICKERS.BOUNCE[biome]),"Each biome needs its own rebound feel")
                var collider: CollisionShape3D = body.get_node("RealSpringCollider")
                assert(collider.shape is CylinderShape3D)
                assert(is_equal_approx(collider.shape.radius,KICKERS.RADIUS))
                var station: int = int(body.get_meta("station"))
                var side: int = int(body.get_meta("side"))
                assert(side == -1 or side == 1)
                assert(body.position.distance_to(kickers.location_at(station,side)) < 0.001)
                var z: float = body.position.z
                var x: float = body.position.x-game.track_center_at(z)
                assert(absf(x) >= 4.25 and absf(x) < 5.1,
                    "Bumpers must reward edge-line risk but keep the middle open")
                assert(absf(body.position.y-KICKERS.HEIGHT*0.5-
                    game.height_at(z)) < 0.001,
                    "Each collider must sit on the real 3D road, not below it")
                assert(body.position.z < 0.0 and body.position.z > game.FINISH_Z,
                    "Bumpers belong between the countdown and finish")
                assert(FEEDBACK.collision_kind(body) == "bumper",
                    "Spring-post hits need the existing impact sounds and camera")
                # An actual Godot physics ray must strike the intended post.
                # Pure scene-name checks cannot distinguish gameplay geometry
                # from a decorative cylinder lacking collision.
                var center: float = game.track_center_at(z)
                var origin := Vector3(center+float(side)*3.2,body.position.y,z)
                var target := Vector3(center+float(side)*6.0,body.position.y,z)
                var query := PhysicsRayQueryParameters3D.create(origin,target)
                var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
                assert(not hit.is_empty() and hit["collider"] == body,
                    "Every spring post must be the first real obstacle on its edge line")
            game.set_graphics_quality(0)
            assert(not kickers.glow_rings.visible and kickers.bodies.size() == 6,
                "ECONOMY hides only cosmetic neon and preserves all impacts")
            game.set_graphics_quality(1)
            assert(kickers.glow_rings.visible)
            game.return_to_menu()
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_spring_post_career.cfg"))
    print("PINBALL_BUMPERS_PASS: 9 layouts, 54 real edge collisions, 2 GPU batches, 40 marbles")
    quit(0)
