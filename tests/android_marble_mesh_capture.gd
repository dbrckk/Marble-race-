extends Node

const RACER = preload("res://scripts/marble.gd")
const VIEWS := [[0.0,0.0,0],[-18.0,1.45,0],[-97.0,3.0,0],[-108.0,2.3,1]]
const DETAIL_CUTS := [0.0,22.0]

func _ready() -> void:
    if OS.get_name() == "Android":
        call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var game = get_parent()
    print("MARBLE_DETAIL_DEVICE ",RenderingServer.get_video_adapter_name(),
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
        for pose in [0,2,3]:
            game.cam_mode = VIEWS[pose][2]
            if pose > 0:
                _place_pack(game,VIEWS[pose][0],VIEWS[pose][1])
            game._update_camera(0.1,true)
            game.ui.label_timer = 1.0
            game.ui.update_hud()
            var expected: Transform3D = game.camera.global_transform
            for pass_index in range(DETAIL_CUTS.size()):
                var cut: float = DETAIL_CUTS[posmod(pass_index+pose+layout,DETAIL_CUTS.size())]
                var simplified := _apply_detail(game,cut)
                if cut > 0.0 and pose > 0:
                    assert(simplified > 0)
                for warm in range(4):
                    await RenderingServer.frame_post_draw
                var triangles := PackedInt32Array()
                var calls := PackedInt32Array()
                for frame in range(4):
                    await RenderingServer.frame_post_draw
                    triangles.append(RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
                    calls.append(RenderingServer.get_rendering_info(
                        RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
                assert(game.camera.global_transform.is_equal_approx(expected))
                triangles.sort()
                calls.sort()
                print("MARBLE_DETAIL ",JSON.stringify({"layout":layout+1,"pose":pose,
                    "cut":cut,"primitives":triangles[2],"calls":calls[2],"simplified":simplified}))
                if layout == 0:
                    var image := get_viewport().get_texture().get_image()
                    assert(image.save_png("user://mesh-%d-%d.png" % [pose,int(cut)]) == OK)
        game.return_to_menu()
    print("MARBLE_DETAIL_PASS")

func _place_pack(game: Node, at_z: float, spacing: float) -> void:
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        var z := at_z+1.4-floorf(i/4.0)*spacing
        var x: float = game.track_center_at(z)+(float(i%4)-1.5)*1.56
        if marble == game.player:
            z = at_z
            x = game.track_center_at(z)-1.0
        marble.global_position = Vector3(x,game.height_at(z)+0.46,z)
        marble.linear_velocity = Vector3(0.0,0.0,-18.0)

func _apply_detail(game: Node, cut: float) -> int:
    for marble in game.racers:
        marble.set_render_quality(1)
    if cut > 0.0:
        game._update_marble_detail(1.0)
    var count := 0
    for marble in game.racers:
        count += int(marble.using_distant_mesh)
    assert(game.player.mesh.mesh == RACER.get_sphere(true,1))
    return count
