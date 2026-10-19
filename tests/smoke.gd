extends SceneTree
## Deterministic smoke checks run by Godot on CI, no graphics or network required.

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var scene = load("res://scenes/main.tscn")
    assert(scene != null, "Main scene not importable")
    var race = scene.instantiate()
    root.add_child(race)
    await process_frame
    assert(is_instance_valid(race.camera), "Missing camera")
    assert(is_instance_valid(race.board), "Missing 3D track")
    assert(race.moving_obstacles.size() >= 10, "Expected animated paddles and hammers")
    var spinning := 0
    var swinging := 0
    for motor in race.moving_obstacles:
        if motor.get_meta("motion_kind","") == "spinner":
            spinning += 1
            assert(is_instance_valid(motor.get_node_or_null("PolishedCenterCap")), "Missing premium center cap")
        elif motor.get_meta("motion_kind","") == "hammer":
            swinging += 1
            assert(is_instance_valid(motor.get_node_or_null("OscillatorCenterCap")), "Missing hammer hinge")
    assert(spinning >= 5 and swinging >= 5, "Five matching paddles and hammers needed")
    var course_fx = race.board.get_node_or_null("PolishedToyDetails")
    assert(course_fx != null, "Missing checkpoint effects")
    course_fx.pulse_checkpoint(0)
    assert(course_fx.checkpoint_flashes[0] > 1.0, "Checkpoint flash not triggered")
    assert(ResourceLoader.exists("res://assets/audio/sfx/metal_hit_1.ogg"), "Metal impact sound missing")
    var props: Node = race.board.get_node_or_null("ModularBrassAndSilkDressing")
    assert(props != null, "Missing v0.7 scenery")
    assert(props.get_node_or_null("GoldRailTopTrim_36Segments") != null, "Missing batched brass rail details")
    var flag_count := 0
    var side_labels := 0
    for child in props.get_children():
        if child.name.begins_with("AnimatedSilkPennant"):
            flag_count += 1
        if child.name.begins_with("SectionMarker"):
            side_labels += 1
        assert(not child is CollisionObject3D, "Decorative art cannot change collisions")
    assert(flag_count == 6 and side_labels == 6, "Expected six flags and six section indicators")
    assert(ResourceLoader.exists("res://shaders/race_flag.gdshader"), "Missing animated-flag shader")
    var track_surface: Node3D = race.board.get_node_or_null("InstancedTrackSurface")
    assert(is_instance_valid(track_surface), "Missing v0.10 instanced track")
    assert(track_surface.original_mesh_count == 648, "180 planks + 108 rails + 360 inlays must be rendered")
    assert(track_surface.get_batch_count() <= 15, "Repeated track meshes must be batched by material")
    for batch in track_surface.get_children():
        assert(batch is MultiMeshInstance3D, "Track decoration must be drawn with GPU instancing")
        assert(not batch is CollisionObject3D, "Track rendering must not introduce new colliders")
    var fx_lines := 0
    for decoration in course_fx.get_children():
        if decoration.name.begins_with("LanePaintInstanced_"):
            fx_lines += 1
    assert(fx_lines == 2, "Road markings should use two GPU batches")
    assert(ResourceLoader.exists("res://assets/textures/lacquer_micro.png"), "Missing baked microtexture")

    var finish: Node3D = race.board.get_node_or_null("PremiumObstacleFinishes")
    assert(finish != null, "Missing v0.8 obstacle detailing")
    assert(int(finish.get("post_count")) >= 90, "Pegs must have instanced art")
    assert(int(finish.get("block_count")) >= 20, "Box obstacles must be registered")
    for detail in finish.get_children():
        assert(detail is MultiMeshInstance3D, "Obstacle details must remain GPU-instanced")
        assert(not detail is CollisionObject3D, "Obstacle art must not affect collisions")
    assert(finish.get_child_count() == 4, "Exactly four artwork batches expected")
    assert(ResourceLoader.exists("res://assets/audio/sfx/bumper_soft.ogg"), "Missing original bump audio")
    assert(ResourceLoader.exists("res://assets/audio/sfx/bumper_hard.ogg"), "Missing stronger bump audio")
    assert(race.ui.fps_label != null and race.ui.quality_button != null, "Graphics controls absent")
    race.set_graphics_quality(0)
    assert(not race.primary_light.shadow_enabled, "Economy should disable primary shadows")
    assert(not track_surface.get_node("GrooveInlays").visible, "Economy must disable tiny engraving details")
    assert(race.camera.far <= 90.0, "Economy should cull remote geometry")
    assert(not finish.visible, "Economy should hide decorative batches")
    race.set_graphics_quality(2)
    assert(race.primary_light.shadow_enabled and finish.visible, "Ultra graphics preset did not apply")
    assert(race.get_viewport().msaa_3d == Viewport.MSAA_2X, "Ultra MSAA visual smoothing must be active")
    assert(track_surface.get_node("GrooveInlays").visible, "Ultra should keep detail")
    assert(race.camera.far > 140.0, "Ultra should provide a deep sight line")
    race.set_graphics_quality(1)
    var sound_on_start: bool = race.audio.enabled
    race.audio.toggle_sound()
    var settings := ConfigFile.new()
    assert(settings.load("user://marble_settings.cfg") == OK, "Missing persisted user preferences")
    assert(int(settings.get_value("video","quality",-1)) == 1, "Audio toggle must retain graphics settings")
    assert(bool(settings.get_value("audio","enabled",sound_on_start)) != sound_on_start,
        "Sound setting not stored")
    race.audio.toggle_sound()
    var previously_visible: bool = race.show_fps
    assert(race.toggle_fps_overlay() != previously_visible, "FPS monitor toggle failed")
    race.toggle_fps_overlay()

    assert(race.race_state == "MENU", "Should start on title screen")
    assert(race.workshop_lamps.size() >= 8, "Workshop lights missing")
    assert(race.audio.spatial_channels.size() == 7, "Impact audio channels missing")
    assert(is_instance_valid(race.audio.mechanism), "Spatial mechanical sound missing")
    assert(is_instance_valid(race.contact_shadows), "Batch shadows missing")
    race.start_race("Lead Core")
    await process_frame
    assert(race.racers.size() == 40, "40 racers must spawn")
    assert(race.racers[0].mesh.mesh == race.racers[1].mesh.mesh,
        "NPC marbles should share cached geometry instead of allocating 40 identical meshes")
    assert(race.racers[0].physics_material_override == race.racers[1].physics_material_override,
        "Regular racers should share the same immutable physics material")
    assert(is_instance_valid(race.player), "Missing controlled racer")
    assert(race.player.is_player, "Wrong player identity")
    assert(race.contact_shadows.pool.visible_instance_count == 40, "40 ground shadows required")
    assert(is_instance_valid(race.ui.course_progress), "Race progress bar missing")
    assert(is_instance_valid(race.ui.boost_progress), "Boost progress bar missing")
    assert(race.player.mass > 1.0, "Lead Core perk did not affect real physics")
    assert(race.player_rank() >= 1 and race.player_rank() <= 40, "Invalid leaderboard")
    var seen = {}
    for marble in race.racers:
        var p = str(marble.position)
        assert(not seen.has(p), "Overlapping starting marbles")
        seen[p] = true
        assert(marble.position.y > race.height_at(marble.position.z), "Marble below track")
    race.countdown = 0.01
    for frame in range(40):
        await physics_frame
        await process_frame
    assert(race.race_state == "RACING", "Countdown never finished")
    var active = 0
    for marble in race.racers:
        if marble.linear_velocity.length() > 0.01:
            active += 1
    assert(active > 0, "Rigidbodies did not start moving")
    assert(race.kinetic_time > 0.0, "Moving obstacle animation not advanced")
    var previous_mode = race.cam_mode
    race.cycle_camera()
    assert(race.cam_mode != previous_mode, "Camera change not registered")
    race.change_boost(true)
    await process_frame
    assert(race.boosting, "Boost controls do not work")
    assert(race.audio.spatial_channels[0] is AudioStreamPlayer3D, "Impacts must be positional")
    assert(race.player_marker.top_level, "Player marker must not roll with the marble")
    race.change_boost(false)
    race.return_to_menu()
    assert(race.race_state == "MENU", "Menu return failed")
    assert(race.contact_shadows.pool.visible_instance_count == 0, "Menu should release race shadows")
    print("SMOKE_PASS: 40 racers, 648 GPU-instanced track parts, AA/LOD profiles, cached geometry, audio, controls")
    race.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
