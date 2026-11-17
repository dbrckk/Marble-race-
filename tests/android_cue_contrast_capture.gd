extends Node

const FRAMES := 12
const MODES := ["double","single","unshadowed"]
var game: Node3D
var rows := FileAccess.open("user://shadow-motion.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game=get_parent()
    game.set_process(false)
    game.set_physics_process(false)
    game.audio.enabled=false
    game.career.save_path="user://shadow-motion-qa.cfg"
    game.career.unlocked=3
    assert(game.set_track(2))
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await RenderingServer.frame_post_draw
    print("OPENING_BENCH_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    for layout in range(3):
        await _capture_layout(layout)
    print("OPENING_BENCH_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _capture_layout(layout: int) -> void:
    game.return_to_menu()
    game.race_variation=layout
    seed(1502)
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    Engine.max_fps=0
    game.race_state="RACING"
    game.ui.hud_layer.hide()
    game.contact_shadows.hide()
    for racer in game.racers:
        racer.freeze=true
        racer.hide()
    var light: DirectionalLight3D=game.primary_light
    assert(light.shadow_enabled and light.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
    assert(is_equal_approx(light.directional_shadow_max_distance,33.0))
    var director = game.race_director
    assert(is_equal_approx(light.directional_shadow_split_1,0.30))
    for section in range(3):
        var center_z: float=director.event_z(section)+6.5
        var piston_clock: float=fposmod(0.18*director.period()-float(section)*1.71-
            float(layout)*1.29,director.period())
        assert(director.piston_up(section,piston_clock))
        director.animate(piston_clock)
        var poses := []
        for frame in range(FRAMES):
            var z := center_z-float(frame)*(20.0/60.0)
            var lean := sin(float(frame)*0.18)*0.47
            game.player.position=Vector3(game.track_center_at(z)+lean,game.height_at(z)+0.54,z)
            game.player.linear_velocity=Vector3(cos(float(frame)*0.18)*5.0,0,-20.0)
            game._update_camera(1.0/60.0,frame==0)
            poses.append([game.camera.global_transform,game.camera.fov,z])
        for mode in MODES:
            light.shadow_enabled=mode!="unshadowed"
            light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if (
                mode=="double") else DirectionalLight3D.SHADOW_ORTHOGONAL
            light.directional_shadow_max_distance=33.0
            light.directional_shadow_split_1=0.30 if mode=="double" else 0.10
            game.camera.global_transform=poses[0][0]
            game.camera.fov=poses[0][1]
            for warm in range(4):
                await RenderingServer.frame_post_draw
            var draw_calls := []
            for frame in range(FRAMES):
                game.camera.global_transform=poses[frame][0]
                game.camera.fov=poses[frame][1]
                await RenderingServer.frame_post_draw
                var filename := "l%d-s%d-%s-%02d.png" % [layout,section,mode,frame]
                assert(get_viewport().get_texture().get_image().save_png("user://"+filename)==OK)
                draw_calls.append(RenderingServer.get_rendering_info(
                    RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
            rows.store_line(JSON.stringify({"layout":layout,"section":section,"mode":mode,
                "draw_calls":draw_calls,"start_z":poses[0][2],"end_z":poses[-1][2]}))
            rows.flush()
        print("OPENING_BENCH_SEQUENCE ",layout," ",section," ",FRAMES)
