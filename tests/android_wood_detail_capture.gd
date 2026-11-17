extends Node
const STOCK := preload("res://tests/android_wood_detail_baseline.gdshader")
const FILTERED := preload("res://shaders/wood.gdshader")
const MODES := ["stock","no_normal","no_filaments","depth"]
const PARAMS := ["timber_color","oak_albedo","oak_normal","grain_offset"]
const POSES := ["grid","grazing","first_module","sector_two"]
const BLOCKS := 2
const SAMPLE_COUNT := 8

var game: Node3D
var materials: Array[Dictionary] = []
var shaders: Dictionary
var out := FileAccess.open("user://wood-detail.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    game.career.save_path = "user://wood-detail-qa.cfg"
    assert(game.set_track(0))
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    assert(game.built_variation == 0 and game.racers.size() == 40)
    await RenderingServer.frame_post_draw
    print("WOOD_DETAIL_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    game.set_process(false)
    game.set_physics_process(false)
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    _collect()
    for pose in POSES:
        _position(pose)
        var camera: Transform3D = game.camera.global_transform
        for block in range(BLOCKS):
            for i in range(MODES.size()):
                var mode: String = MODES[i if block%2==0 else MODES.size()-1-i]
                _mode(mode)
                for warm in range(4):
                    await RenderingServer.frame_post_draw
                var samples := PackedFloat64Array()
                var before := Time.get_ticks_usec()
                for sample in range(SAMPLE_COUNT):
                    await RenderingServer.frame_post_draw
                    var now := Time.get_ticks_usec()
                    samples.append(float(now-before)/1000.0)
                    before = now
                samples.sort()
                assert(camera == game.camera.global_transform)
                var row := {"pose":pose,"mode":mode,"block":block,
                    "median_ms":0.5*(samples[SAMPLE_COUNT/2-1]+samples[SAMPLE_COUNT/2]),
                    "p90_ms":samples[ceili(float(SAMPLE_COUNT)*0.9)-1],
                    "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
                    "triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
                out.store_line(JSON.stringify(row))
                out.flush()
                print("WOOD_DETAIL ",JSON.stringify(row))
                if block == 0 and (pose != "grazing" or mode in ["stock","depth"]):
                    assert(get_viewport().get_texture().get_image().save_png(
                        "user://wood-%s-%s.png" % [pose,mode]) == OK)
        print("WOOD_DETAIL_POSE ",pose)
    print("WOOD_DETAIL_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _collect() -> void:
    var no_normal := Shader.new()
    no_normal.code = STOCK.code.replace("    NORMAL_MAP = texture(oak_normal,uv).rgb;\n    NORMAL_MAP_DEPTH = 0.27;\n","")
    assert(no_normal.code != STOCK.code)
    var no_filaments := Shader.new()
    no_filaments.code = STOCK.code.replace(" + filaments * 0.045","")
    assert(no_filaments.code != STOCK.code)
    shaders = {"stock":STOCK,"no_normal":no_normal,"no_filaments":no_filaments,"depth":FILTERED}
    for item in game.render_materials.values():
        if not item is ShaderMaterial or item.shader != FILTERED:
            continue
        var values := {}
        for field in PARAMS:
            values[field] = item.get_shader_parameter(field)
        materials.append({"ref":item,"values":values})
    assert(materials.size() >= 8)

func _mode(mode: String) -> void:
    for record in materials:
        var material: ShaderMaterial = record["ref"]
        material.shader = shaders[mode]
        for key in PARAMS:
            material.set_shader_parameter(key,record["values"][key])

func _position(pose: String) -> void:
    if pose == "grid":
        return
    game.race_state = "RACING"
    game.ui.hide_countdown()
    var location := -3.0 if pose != "sector_two" else -110.0
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        var z := location+floorf(float(i)/8.0)*1.07-1.7
        var x: float = game.track_center_at(z)+(float(i%8)-3.5)*1.26
        if marble == game.player:
            z = location
            x = game.track_center_at(z)-0.62
        marble.global_position = Vector3(x,game.height_at(z)+0.46,z)
        marble.linear_velocity = Vector3(0.0,0.0,-22.0)
    game.contact_shadows.update_shadows()
    game.camera.fov = 64.0
    game._update_camera(1.0,true)
    game.ui.label_timer = 1.0
    game.ui.update_hud()
    if pose == "grazing":
        var z := -13.2
        game.camera.global_position = Vector3(
            game.track_center_at(z)-0.82,game.height_at(z)+0.91,z)
        game.camera.fov = 54.0
        game.camera.look_at(Vector3(game.track_center_at(z-7.0)-0.62,game.height_at(z-7.0)+0.04,z-7.0))
