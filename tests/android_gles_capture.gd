extends Node
const ROUTE = preload("res://scripts/shortcut_route.gd")
const PERK := "Grip Tape"

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
        var launch_saved := false
        var merge_saved := false
        var bridge_used := false
        var merge_x: Variant = null
        var previous_z := INF
        var deadline := Time.get_ticks_msec()+250000
        while game.race_state != "RESULTS":
            if Time.get_ticks_msec() >= deadline:
                _fail(quality+" did not reach results")
                return
            if game.race_state == "RACING":
                var at: Vector3 = game.player.global_position
                if not bridge_used and at.z <= ROUTE.ENTRY_Z and at.z >= ROUTE.EXIT_Z:
                    bridge_used = game.shortcut_route.on_separate_deck(at)
                if merge_x == null and previous_z > ROUTE.EXIT_Z and at.z <= ROUTE.EXIT_Z:
                    merge_x = snappedf(at.x,0.01)
                previous_z = at.z
                # Read pixels after each focused interval so readback does not skew it.
                if not launch_saved and game.race_time > 5.5:
                    launch_saved = await _capture(quality.to_lower()+"-launch")
                    if not launch_saved:
                        _fail(quality+" launch did not render")
                        return
                if not merge_saved and at.z < ROUTE.EXIT_Z-9.0:
                    merge_saved = await _capture(quality.to_lower()+"-merge")
                    if not merge_saved:
                        _fail(quality+" merge did not render")
                        return
            await get_tree().process_frame
        if not game.player.finished or merge_x == null or not launch_saved or not merge_saved:
            _fail(quality+" did not produce both visible race windows")
            return
        if game.built_variation != 0 or game.racers.size() != 40 or (
            game.selected_perk != PERK or game.graphics_mode_label() != quality):
            _fail("The replay changed a comparison condition")
            return
        var report: String = game.ui.performance_text
        for label in ["FIRST 5s","BRIDGE RETURN ±8 m"]:
            if not report.contains(label+" | ") or report.contains(label+" | NO SAMPLES"):
                _fail(quality+" missing "+label)
                return
        print("MARBLE_GLES_REPORT ",JSON.stringify({
            "quality": quality, "finish_s": game.player.finish_time,
            "merge_x": merge_x, "bridge_deck": bridge_used, "report": report
        }))
        if quality == "BALANCED":
            await get_tree().create_timer(2.0).timeout
            game.ui.compare_performance.pressed.emit()
            if game.race_state != "COUNTDOWN":
                _fail("Profile compare did not start a replay")
                return
    print("MARBLE_GLES_PASS")

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
