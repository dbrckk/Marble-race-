extends Node
## Compare the existing camera and the exact same pack for each profile.
var game: Node3D
var results := FileAccess.open("user://woodworks-shadows.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    game.career.save_path = "user://woodworks-shadows-qa.cfg"
    assert(game.set_track(0))
    game.set_graphics_quality(1)
    await RenderingServer.frame_post_draw
    print("WOOD_SHADOW_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    for layout in range(3):
        game.return_to_menu()
        game.race_variation = layout
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40 and game.built_variation == layout)
        assert(game.start_gate.signal_stage == -1 and game.race_state == "COUNTDOWN")
        _pause_scene(true)
        await _compare(layout,"grid")
        game._apply_graphics_quality()
        _pause_scene(false)

        # Wait for the same normal GO transition and physical approach a player sees.
        var art = game.board.find_child("OpeningObstacleArt",true,false)
        assert(is_instance_valid(art) and is_finite(art.entry_z))
        var deadline := Time.get_ticks_msec()+85000
        while Time.get_ticks_msec() < deadline and (game.race_state != "RACING" or
            game.player.position.z > art.entry_z-2.0):
            await RenderingServer.frame_post_draw
        assert(game.race_state == "RACING" and game.player.position.z <= art.entry_z-2.0)
        assert(not game.player.eliminated and not game.player.freeze)
        assert(game.player.linear_velocity.z < -3.0 and game.race_time > 0.5)
        _pause_scene(true)
        await _compare(layout,"opening")
        game._apply_graphics_quality()
        _pause_scene(false)
        print("WOOD_SHADOW_LAYOUT ",layout," ",game.race_time)
    print("WOOD_SHADOW_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _pause_scene(paused: bool) -> void:
    game.set_process(not paused)
    game.set_physics_process(not paused)
    get_tree().paused = paused
    process_mode = Node.PROCESS_MODE_ALWAYS

func _compare(layout: int, phase: String) -> void:
    var observed_camera: Transform3D = game.camera.global_transform
    var observed_ball: Vector3 = game.player.position
    for offset in range(2):
        var candidate := (layout+offset+int(phase=="opening"))%2 == 1
        game._apply_graphics_quality()
        if not candidate:
            game.primary_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
            game.primary_light.directional_shadow_split_1 = 0.10
            game.primary_light.directional_shadow_max_distance = 47.0
            for prop in game.secondary_showroom_art:
                prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        assert(game.primary_light.shadow_enabled)
        for warm in range(3):
            await RenderingServer.frame_post_draw
        var calls := PackedInt32Array()
        for sample in range(3):
            await RenderingServer.frame_post_draw
            calls.append(RenderingServer.get_rendering_info(
                RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        calls.sort()
        assert(game.camera.global_transform == observed_camera and game.player.position == observed_ball)
        var result := {"layout":layout,"phase":phase,"candidate":candidate,"draws":calls[1],
            "elapsed":game.race_time,"signal":game.start_gate.signal_stage,
            "z":game.player.position.z,"triangles":RenderingServer.get_rendering_info(
                RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
        results.store_line(JSON.stringify(result))
        results.flush()
        var path := "user://shadow-%d-%s-%d.png" % [layout,phase,int(candidate)]
        assert(get_viewport().get_texture().get_image().save_png(path) == OK)
