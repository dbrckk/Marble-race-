extends Node
## Bench the real 40-racer Woodworks track, both with normal rendering and
## with only the viewport's 3D pass disabled. Physics keeps running in both.

const WINDOWS := ["grid","go","opening"]
const CONFIGURATIONS := [[true,false],[false,true],[false,false],[true,true],
    [true,true],[false,false],[false,true],[true,false]]
var game: Node3D
var view_rid: RID
var samples: Dictionary
var last_draw := -1
var entry_z := 0.0
var run_active := false
var saved_opening := false
var output := FileAccess.open("user://race-profile.jsonl", FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    game.career.save_path = "user://race-profile-career.cfg"
    game.set_graphics_quality(1)
    game.show_fps = false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 60
    view_rid = get_viewport().get_viewport_rid()
    RenderingServer.viewport_set_measure_render_time(view_rid,true)
    game.qa_tick = _record_tick
    RenderingServer.frame_post_draw.connect(_record_draw)
    await RenderingServer.frame_post_draw
    print("RACE_PROFILE_DEVICE ", RenderingServer.get_current_rendering_driver_name())
    var id := 0
    for configuration in CONFIGURATIONS:
        var draw_3d: bool = configuration[0]
        var skip_forecasts: bool = configuration[1]
        RenderingServer.viewport_set_disable_3d(view_rid,not draw_3d)
        game.return_to_menu()
        game.race_variation = 0
        game.qa_skip_unused_forecasts = skip_forecasts
        game.start_race("Grip Tape")
        var opening = game.board.find_child("OpeningObstacleArt",true,false)
        assert(is_instance_valid(opening) and is_finite(opening.entry_z))
        assert(game.racers.size() == 40 and game.built_variation == 0)
        entry_z = opening.entry_z
        last_draw = -1
        samples = {}
        for phase in WINDOWS:
            samples[phase] = {"ticks":[],"frames":[]}
        run_active = true
        var deadline := Time.get_ticks_msec()+75000
        var crossed := false
        while Time.get_ticks_msec() < deadline and not game.player.eliminated:
            await RenderingServer.frame_post_draw
            var z: float = game.player.position.z
            if game.race_state == "RACING" and z <= entry_z-7.0:
                crossed = true
                break
        run_active = false
        assert(crossed,"Player failed to pass the real opening")
        for phase in WINDOWS:
            var phase_samples: Dictionary = samples[phase]
            print("RACE_PROFILE_WINDOW ", id, " ", phase, " ", phase_samples.ticks.size(), " ", phase_samples.frames.size(), " ", entry_z)
            assert(phase_samples.ticks.size() >= 5 and phase_samples.frames.size() >= 3, phase)
            var result := {"run":id,"draw_3d":draw_3d,"skip_forecasts":skip_forecasts,
                "phase":phase,"entry_z":entry_z,"cross_time":game.race_time}
            result.merge(phase_samples)
            output.store_line(JSON.stringify(result))
        output.flush()
        print("RACE_PROFILE_RUN ", id, " ", draw_3d, " ", skip_forecasts, " ", game.race_time)
        id += 1
    print("RACE_PROFILE_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _phase() -> String:
    if game.race_state == "COUNTDOWN" and game.countdown < 2.4 and game.countdown > 0.20:
        return "grid"
    if game.race_state == "RACING":
        if absf(game.player.position.z-entry_z) <= 7.0:
            return "opening"
    return ""

func _is_launch() -> bool:
    return game.race_state == "RACING" and game.race_time >= 0.0 and game.race_time <= 2.0

func _record_tick(script_us: int, bot_us: int, forecasts: int) -> void:
    if not run_active:
        return
    var phase := _phase()
    var sample := [script_us,bot_us,forecasts]
    if not phase.is_empty():
        samples[phase].ticks.append(sample)
    if _is_launch():
        samples["go"].ticks.append(sample)

func _record_draw() -> void:
    if not run_active:
        return
    var now := Time.get_ticks_usec()
    var before := last_draw
    last_draw = now
    var phase := _phase()
    if before < 0 or (phase.is_empty() and not _is_launch()):
        return
    var sample := [
        now-before,
        Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0,
        RenderingServer.viewport_get_measured_render_time_cpu(view_rid)*1000.0,
        RenderingServer.viewport_get_measured_render_time_gpu(view_rid)*1000.0,
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
        PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS)
    ]
    if not phase.is_empty():
        samples[phase].frames.append(sample)
    if _is_launch():
        samples["go"].frames.append(sample)
    if phase == "opening" and not saved_opening and game.qa_skip_unused_forecasts == false and (
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) > 100):
        saved_opening = true
        assert(get_viewport().get_texture().get_image().save_png("user://opening.png") == OK)
        last_draw = -1
