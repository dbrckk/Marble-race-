extends Node

const TRACE_A=preload("res://tests/opening_trace_a.gd")
const TRACE_B=preload("res://tests/opening_trace_b.gd")
const TRACE_BYTES := 129876
const FRAME_WIDTH := 411
const PHASE := ["grid","launch","obstacle","lead"]
var game: Node3D
var trace: PackedFloat32Array
var output := FileAccess.open("user://shadow-budget.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game=get_parent()
    trace=Marshalls.base64_to_raw(TRACE_A.DATA+TRACE_B.DATA).decompress(
        TRACE_BYTES,FileAccess.COMPRESSION_DEFLATE).to_float32_array()
    assert(trace.size()*4==TRACE_BYTES and trace.size()%FRAME_WIDTH==0)
    game.career.save_path="user://opening-budget-qa.cfg"
    game.show_fps=false
    game.audio.enabled=false
    game.set_process(false)
    game.set_physics_process(false)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await RenderingServer.frame_post_draw
    print("OPENING_BENCH_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    var modes := ["balanced","single36","single36","balanced"]
    for trial in range(modes.size()):
        await _trial(modes[trial],trial)
    print("OPENING_BENCH_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _trial(mode: String, trial: int) -> void:
    game.return_to_menu()
    await RenderingServer.frame_post_draw
    seed(48042)
    game.race_variation=0
    game.set_graphics_quality(0 if mode.begins_with("economy") else 1)
    game.start_race("Grip Tape")
    Engine.max_fps=0
    get_viewport().disable_3d=mode.ends_with("_off")
    _set_shadow_mode(mode)
    assert(game.racers.size()==40)
    var count:=trace.size()/FRAME_WIDTH
    for frame in [0,count/2,count-1,0]:
        _pose(frame)
        for warm in range(4):
            await RenderingServer.frame_post_draw
    var previous:=Time.get_ticks_usec()
    var measured := []
    for frame in range(count):
        _pose(frame)
        await RenderingServer.frame_post_draw
        var now:=Time.get_ticks_usec()
        measured.append({
            "stage":PHASE[int(trace[frame*FRAME_WIDTH])],
            "ms":float(now-previous)/1000.0,
            "z":game.player.position.z,
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
            "tris":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
        })
        previous=now
    output.store_line(JSON.stringify({"mode":mode,"trial":trial,"frames":measured}))
    output.flush()
    print("OPENING_BENCH_TRIAL ",trial," ",mode," ",measured.size())
    if trial==0:
        for idx in [15,44,64,76]:
            _pose(idx)
            for compare in ["balanced","single36"]:
                _set_shadow_mode(compare)
                for warm in range(3):
                    await RenderingServer.frame_post_draw
                assert(get_viewport().get_texture().get_image().save_png(
                    "user://%s-%d.png" % [compare,idx])==OK)
    get_viewport().disable_3d=false

func _set_shadow_mode(mode: String) -> void:
    var single := mode=="single36"
    game.primary_light.directional_shadow_max_distance=36.0 if single else 39.0
    game.primary_light.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if (
        single) else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func _pose(frame: int) -> void:
    var offset := frame*FRAME_WIDTH
    var frame_phase:=int(trace[offset])
    game.race_state="COUNTDOWN" if frame_phase==0 else "RACING"
    game.countdown=-trace[offset+1]+1.0/30.0
    game.race_time=maxf(0.0,trace[offset+1]-1.0/30.0)
    game.steer=trace[offset+2]
    game.steer_target=game.steer
    var index:=offset+11
    for racer in game.racers:
        racer.global_transform=_transform(index)
        racer.linear_velocity=Vector3(trace[index+7],trace[index+8],trace[index+9])
        index+=10
    if frame_phase>0:
        game.race_director.animate(game.race_time)
    game._process(1.0/30.0)
    game.camera.global_transform=_transform(offset+3)
    game.camera.fov=trace[offset+10]

func _transform(index: int) -> Transform3D:
    return Transform3D(Basis(Quaternion(trace[index+3],trace[index+4],trace[index+5],trace[index+6]).normalized()),
        Vector3(trace[index],trace[index+1],trace[index+2]))
