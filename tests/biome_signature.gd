extends SceneTree
## Verify genuinely distinct landscapes, cheap GPU batching and mobile tiers.
const SIGNATURE = preload("res://scripts/biome_signature.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_biome_visuals.cfg"
    game.career.unlocked = 3
    for track in range(3):
        assert(game.set_track(track),"All three test circuits should be unlocked")
        var art: Node3D = game.board.get_node("TrackSignatureLandmarks")
        assert(art.biome == track)
        assert(art.hero is MultiMeshInstance3D)
        assert(art.details is MultiMeshInstance3D)
        assert(art.motes is MultiMeshInstance3D)
        assert(art.hero.name == SIGNATURE.CORE_NAMES[track])
        assert(art.details.name == SIGNATURE.DETAIL_NAMES[track])
        assert(art.hero.multimesh.instance_count == 12,
            "Each biome gets 12 readable hero landmarks")
        assert(art.details.multimesh.instance_count == (36 if track == 1 else 24),
            "Each track's secondary geometry must be distinct")
        assert(art.motes.multimesh.instance_count == 72,
            "Ambient movement must be one shared GPU-instanced draw")
        assert(art.signs.size() == 6)
        assert(art.motes.material_override is ShaderMaterial)
        assert(art.motes.material_override.shader == SIGNATURE.MOTE_SHADER)
        # Headless Godot rendering does not reliably round-trip GPU
        # instance transforms (it can return identity for every instance).
        # Validate the exact CPU poses used to fill those MultiMesh batches.
        assert(art.landmark_positions.size() == 12)
        assert(art.mote_positions.size() == 72)
        for pos in art.landmark_positions:
            assert(pos.is_finite())
            assert(absf(pos.x-game.track_center_at(pos.z)) > 13.0,
                "Landmarks may not block the track or its physical side route")
        for pos in art.mote_positions:
            assert(absf(pos.x-game.track_center_at(pos.z)) > 13.3,
                "Atmosphere must not obscure the competitive center lane")
        for level in range(3):
            game.set_graphics_quality(level)
            assert(art.hero.visible, "Strong biome silhouettes survive economy mode")
            assert(art.details.visible == (level >= 1))
            assert(art.motes.visible == (level >= 1),
                "Budget-friendly quality tiers should hide glowing motes")
            assert(art.signs[0].visible == (level >= 1))
        game.set_graphics_quality(1)
        assert(art.detail_origins.size() == art.details.multimesh.instance_count)
        assert(art.detail_bases.size() == art.detail_origins.size())
        for origin in art.detail_origins:
            assert(origin.is_finite() and absf(origin.x-game.track_center_at(origin.z)) > 12.5,
                "Animated landmarks must stay beyond shortcut physics")
        art.motion_accumulator = 0.0
        var frame_before: int = art.motion_frame_count
        art._process(0.01)
        assert(art.motion_frame_count == frame_before,
            "Animation updates must be throttled below 20Hz")
        art._process(0.05)
        assert(art.motion_frame_count == frame_before+1,
            "Each biome must animate secondary geometry on its own clock")
        assert(art.motion_clock > 0.0 and art.detail_material.emission_energy_multiplier > 0.0)
        game.set_graphics_quality(0)
        art.motion_accumulator = 0.0
        frame_before = art.motion_frame_count
        art._process(0.20)
        assert(art.motion_frame_count == frame_before,
            "Economy mode must skip animated GPU transform updates")
        game.set_graphics_quality(1)
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40)
        assert(game.board.get_node("TrackSignatureLandmarks").hero.visible)
        game.return_to_menu()
    print("BIOME_SIGNATURE_PASS: 3 distinct scenes, 3 GPU batches, safe course geometry")
    game.queue_free()
    await process_frame
    quit(0)
