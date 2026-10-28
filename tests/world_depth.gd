extends SceneTree
## Distinct 3D world depth on nine real playable layouts. All new terrain
## silhouettes and ambient accents stay off the physical road and bypass,
## consume only four batched GPU instances, and obey Android quality modes.
const WORLDS = preload("res://scripts/track_universes.gd")
const BYPASS = preload("res://scripts/shortcut_route.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path = "user://qa_world_depth.cfg"
    stage.career.unlocked = 3
    stage.set_process(false)
    stage.set_physics_process(false)
    var checked := 0
    for biome in range(3):
        stage.return_to_menu()
        assert(stage.set_track(biome))
        for layout in range(3):
            stage.race_variation = layout
            stage.start_race("Grip Tape")
            assert(stage.built_variation == layout and stage.racers.size() == 40)
            var name: String = "World_%s" % (
                WORLDS.THEMES[biome].replace(" ","_"))
            var world: Node3D = stage.board.get_node(name) as Node3D
            assert(world.get_child_count() == 7,
                "The whole original biome plus four depth layers costs seven GPU batches")
            assert(world.depth_ridges.multimesh.instance_count == 12)
            assert(world.near_forms.multimesh.instance_count == 36)
            assert(world.accent_lights.multimesh.instance_count == 36)
            assert(world.distant_positions.size() == 12)
            assert(world.near_positions.size() == 36)
            assert(world.glow_positions.size() == 36)
            assert(world.signature_landmarks.multimesh.instance_count == 12)
            assert(world.landmark_positions.size() == 12)
            for child in world.get_children():
                assert(child is MultiMeshInstance3D and
                    child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
                    "The extra world atmosphere may not create any physics or shadow passes")
            for point in world.distant_positions:
                var p: Vector3 = point
                assert(p.is_finite() and
                    absf(p.x-stage.track_center_at(p.z)) >= WORLDS.FAR_SHOULDER-0.01,
                    "Landscape silhouettes must remain safely outside the entire race")
            for point in world.near_positions:
                var p: Vector3 = point
                assert(p.is_finite() and
                    absf(p.x-stage.track_center_at(p.z)) >= WORLDS.NEAR_SHOULDER-0.01)
                assert(absf(p.x-stage.shortcut_route.point_at(p.z).x) > (
                    BYPASS.WIDTH*0.5+2.0),
                    "Middle-distance structures cannot obstruct the true raised bypass")
            for point in world.glow_positions:
                var p: Vector3 = point
                assert(p.is_finite() and
                    absf(p.x-stage.track_center_at(p.z)) >= WORLDS.GLOW_SHOULDER-0.01)
            for point in world.landmark_positions:
                var p: Vector3 = point
                assert(p.is_finite() and
                    absf(p.x-stage.track_center_at(p.z)) >= 23.99,
                    "Distinctive skyline anchors must remain outside the race road")
                assert(absf(p.x-stage.shortcut_route.point_at(p.z).x) > (
                    BYPASS.WIDTH*0.5+3.0),
                    "Skyline landmarks must never overlap the elevated route")
            for quality in range(3):
                stage.set_graphics_quality(quality)
                assert(world.near_forms.visible,
                    "Economy mode must preserve the world silhouette")
                assert(world.depth_ridges.visible == (quality >= 1))
                assert(world.signature_landmarks.visible == (quality >= 1))
                assert(world.accent_lights.visible == (quality >= 2),
                    "Small luminous props belong only in the ultrahigh Android tier")
                assert(stage.racers.size() == 40,
                    "Graphical LOD can never change the number of physical racers")
            stage.set_graphics_quality(1)
            stage.return_to_menu()
            checked += 1
    assert(checked == 9)
    stage.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_world_depth.cfg"))
    print("WORLD_DEPTH_PASS: nine 3D biomes/layouts, 864 original near/far accent transforms, four GPU batches, zero physics and safe quality LOD")
    quit(0)
