extends Node
const ROUTE = preload("res://scripts/shortcut_route.gd")
const PERK := "Grip Tape"
const BRIDGE_PASSES := 3

func _ready() -> void:
    if OS.get_name() == "Android":
        call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var game = get_parent()
    game.career.unlocked = 3
    if not game.set_track(2):
        _fail("Forge did not open")
        return
    game.race_variation = 0
    game.set_graphics_quality(1)
    if not game.show_fps:
        game.toggle_fps_overlay()
    print("MARBLE_GLES_DEVICE ",JSON.stringify({
        "os": OS.get_name(), "api": OS.get_version(),
        "adapter": RenderingServer.get_video_adapter_name(),
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "drawable": str(DisplayServer.window_get_size()),
        "viewport": str(get_viewport().get_visible_rect().size),
        "fps_cap": Engine.max_fps
    }))
    await get_tree().create_timer(2.0).timeout
    game.start_race(PERK)

    for quality in ["BALANCED","ECONOMY"]:
        if game.built_variation != 0 or game.racers.size() != 40 or (
            game.selected_perk != PERK or game.graphics_mode_label() != quality):
            _fail("The replay changed a comparison condition")
            return
        var deadline := Time.get_ticks_msec()+95000
        while game.race_time < 5.5:
            if game.race_state == "RESULTS" or Time.get_ticks_msec() >= deadline:
                _fail(quality+" launch exceeded the capture deadline")
                return
            await get_tree().process_frame
        if not await _capture(quality.to_lower()+"-launch"):
            _fail(quality+" launch did not render")
            return
        for section in range(BRIDGE_PASSES):
            await _place_pack_near_merge(game,section)
            deadline = Time.get_ticks_msec()+52000
            while game.race_time < 19.0 and game.player.global_position.z >= ROUTE.EXIT_Z-7.5:
                if game.race_state != "RACING" or Time.get_ticks_msec() >= deadline:
                    _fail(quality+" merge sample stalled")
                    return
                await get_tree().process_frame
        if not await _capture(quality.to_lower()+"-merge"):
            _fail(quality+" merge did not render")
            return
        game._end_race()
        var report: String = game.ui.performance_text
        for label in ["FIRST 5s","BRIDGE RETURN ±8 m"]:
            if not report.contains(label+" | ") or report.contains(label+" | NO SAMPLES"):
                _fail(quality+" missing "+label)
                return
        print("MARBLE_GLES_REPORT ",JSON.stringify({
            "quality": quality, "merge_passes": BRIDGE_PASSES,
            "report": report
        }))
        if quality == "BALANCED":
            await get_tree().create_timer(2.0).timeout
            game.ui.compare_performance.pressed.emit()
            if game.race_state != "COUNTDOWN":
                _fail("Profile compare did not start a replay")
                return
    print("MARBLE_GLES_PASS")

func _place_pack_near_merge(game: Node, section: int) -> void:
    # Real marbles and the same physical course. Repeat the same initial state
    # so neither profile journeys through different obstacle timings upstream.
    game.set_process(false)
    game.set_physics_process(false)
    game.performance_budget.suspend()
    game.race_time = 16.0
    game.kinetic_time = 16.0
    # Sample ahead of, at and just after the join, without depending on a
    # specific collision sequence to escape the approach in software.
    var entry: float = ROUTE.EXIT_Z+[5.0,0.0,-4.5][section]
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        marble.freeze = true
        var z: float = entry+1.15+floorf(i/8.0)*1.27
        var x: float = game.track_center_at(z)+(float(i%8)-3.5)*1.27
        if marble == game.player:
            z = entry
            x = game.track_center_at(z)-1.65
        marble.global_position = Vector3(x,game.height_at(z)+0.62,z)
        marble.previous_race_position = marble.position
        marble.angular_velocity = Vector3.ZERO
    game._update_camera(0.1,true)
    await get_tree().process_frame
    for marble in game.racers:
        marble.freeze = false
        marble.sleeping = false
        marble.linear_velocity = Vector3(0.0,0.0,-15.0)
    game.set_physics_process(true)
    game.set_process(true)

func _capture(label: String) -> bool:
    await RenderingServer.frame_post_draw
    var frame := get_viewport().get_texture().get_image()
    if frame == null or frame.is_empty():
        return false
    var path := "user://marble-gles-"+label+".png"
    if frame.save_png(path) != OK:
        return false
    var palette := {}
    for y in range(int(frame.get_height()*0.21),int(frame.get_height()*0.77),7):
        for x in range(int(frame.get_width()*0.24),int(frame.get_width()*0.76),7):
            var pixel := frame.get_pixel(x,y)
            var rgb := Vector3i(int(pixel.r*15.0),int(pixel.g*15.0),int(pixel.b*15.0))
            palette[rgb] = true
    print("MARBLE_GLES_FRAME ",label," colors=",palette.size(),
        " resolution=",frame.get_size())
    return palette.size() >= 32

func _fail(message: String) -> void:
    print("MARBLE_GLES_FAILURE ",message)
    get_tree().quit(1)
