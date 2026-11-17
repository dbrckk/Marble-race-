extends Node

var game: Node3D
var output := FileAccess.open("user://opening-budget.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game=get_parent()
    game.career.save_path="user://opening-budget-qa.cfg"
    game.show_fps=false
    game.audio.enabled=false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await RenderingServer.frame_post_draw
    print("OPENING_BENCH_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    var modes := ["balanced","economy","economy","balanced",
        "balanced_off","economy_off","economy_off","balanced_off",
        "balanced_no_shadow","balanced_no_shadow"]
    for trial in range(modes.size()):
        await _trial(modes[trial],trial)
    print("OPENING_BENCH_PASS")
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
    if mode.ends_with("_shadow"):
        game.primary_light.shadow_enabled=false
    var art: MeshInstance3D=game.board.find_child("OpeningObstacleArt",true,false)
    var previous := Time.get_ticks_usec()
    var measured := []
    var checkpoints := []
    var racing_frames := 0
    var entered := false
    for frame in range(480):
        await RenderingServer.frame_post_draw
        var now:=Time.get_ticks_usec()
        var dt:=float(now-previous)/1000.0
        previous=now
        var z: float=game.player.global_position.z
        var stage := "lead"
        if game.race_state=="COUNTDOWN":
            stage="grid" if game.countdown<=1.15 else "warm"
        elif game.race_state=="RACING":
            racing_frames+=1
            if absf(z-art.entry_z)<=4.0:
                stage="obstacle"
                entered=true
            elif racing_frames<=36:
                stage="launch"
            if racing_frames%15==0:
                checkpoints.append([racing_frames,float(snappedf(z,0.001))])
            if z<art.entry_z-4.0 and entered:
                break
        if stage=="warm":
            continue
        measured.append({
            "stage":stage,"ms":dt,"z":z,
            "phys":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
            "tris":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
        })
    assert(entered and measured.size()>85)
    output.store_line(JSON.stringify({"mode":mode,"trial":trial,"checkpoints":checkpoints,"frames":measured}))
    output.flush()
    print("OPENING_BENCH_TRIAL ",trial," ",mode," ",measured.size()," ",checkpoints)
    get_viewport().disable_3d=false
