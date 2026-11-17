extends Node

const CANDIDATES := [
    ["stock",true,DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,47.0,0.1],
    ["two47",true,DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,47.0,0.24],
    ["two33",true,DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,33.0,0.30],
    ["off",false,DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,47.0,0.1]
]

func _ready() -> void:
    if OS.get_name() == "Android":
        call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var game = get_parent()
    print("SHADOW_SWEEP_DEVICE ",RenderingServer.get_video_adapter_name(),
        " ",DisplayServer.window_get_size())
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    assert(game.set_track(2))
    game.set_graphics_quality(1)
    for layout in range(1):
        game.race_variation = layout
        game.start_race("Grip Tape")
        game.race_state = "RACING"
        game.ui.hide_countdown()
        assert(game.racers.size() == 40)
        for marble in game.racers:
            marble.freeze = true
        for pose in [0,2]:
            if pose > 0:
                _position_pack(game, [0.0,-15.0,-100.0,-112.0][pose])
            game._update_camera(0.1,true)
            game.ui.label_timer = 1.0
            game.ui.update_hud()
            var expected: Transform3D = game.camera.global_transform
            var light: DirectionalLight3D = game.primary_light
            for ii in range(CANDIDATES.size()):
                var option: Array = CANDIDATES[posmod(ii+pose+layout,CANDIDATES.size())]
                light.shadow_enabled = option[1]
                light.directional_shadow_mode = option[2]
                light.directional_shadow_max_distance = option[3]
                light.directional_shadow_split_1 = option[4]
                for warm in range(4):
                    await RenderingServer.frame_post_draw
                var draw_calls := PackedInt32Array()
                var triangles := PackedInt32Array()
                for frame in range(4):
                    await RenderingServer.frame_post_draw
                    draw_calls.append(RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
                    triangles.append(RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
                assert(game.camera.global_transform.is_equal_approx(expected))
                draw_calls.sort()
                triangles.sort()
                print("SHADOW_SWEEP ",JSON.stringify({"layout":layout+1,"pose":pose,
                    "mode":option[0],"calls":draw_calls[2],"primitives":triangles[2]}))
                if layout == 0:
                    var image := get_viewport().get_texture().get_image()
                    assert(image.save_png("user://shadow-%d-%s.png" % [pose,option[0]]) == OK)
        game.return_to_menu()
    print("SHADOW_SWEEP_PASS")

func _position_pack(game: Node, at_z: float) -> void:
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        var z := at_z+floorf(i/8.0)*1.06-1.65
        var x: float = game.track_center_at(z)+(float(i%8)-3.5)*1.28
        if marble == game.player:
            z = at_z
            x = game.track_center_at(z)-1.3
        marble.global_position = Vector3(x,game.height_at(z)+0.45,z)
        marble.linear_velocity = Vector3(0.0,0.0,-18.0)
