extends Node
const WOOD := preload("res://shaders/wood.gdshader")
const LACQUER := preload("res://shaders/lacquer.gdshader")
const TEX_KEYS := ["oak_albedo","oak_normal","micro_texture"]
const MODES := ["legacy","mips","flat_wood","flat_lacquer"]
const FRAME_COUNT := 14

var game: Node3D
var materials: Array[Dictionary] = []
var unfiltered: Dictionary = {}
var simple_wood := Shader.new()
var simple_lacquer := Shader.new()
var out := FileAccess.open("user://surface-profile.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    game.career.save_path = "user://surface-profile-qa.cfg"
    assert(game.set_track(0))
    game.set_graphics_quality(1)
    game.race_variation = 0
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40 and game.built_variation == 0)
    await RenderingServer.frame_post_draw
    print("SURFACE_PROFILE_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    game.set_process(false)
    game.set_physics_process(false)
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    _gather_materials()
    for block in range(2):
        for i in range(MODES.size()):
            var mode: String = MODES[i if block==0 else MODES.size()-1-i]
            _apply(mode)
            for warm in range(4):
                await RenderingServer.frame_post_draw
            var times := PackedFloat64Array()
            var before := Time.get_ticks_usec()
            for sample in range(10):
                await RenderingServer.frame_post_draw
                var now := Time.get_ticks_usec()
                times.append(float(now-before)/1000.0)
                before = now
            times.sort()
            _record({"kind":"timing","mode":mode,"block":block,
                "median_ms":0.5*(times[4]+times[5]),"p90_ms":times[8],
                "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
                "triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
            if block == 1 and mode in ["legacy","mips"]:
                _capture("grid-%s.png" % mode)

    game.race_state = "RACING"
    game.ui.hide_countdown()
    for mode in ["legacy","mips"]:
        _apply(mode)
        for i in range(FRAME_COUNT):
            # Move a chase camera along the authored course at 22 m/s.
            # Tiny sideways offsets at each position test subpixel response.
            _place_pack(5.0-float(i)*22.0/24.0,i)
            for offset in range(2):
                game.camera.h_offset = -0.002 if offset == 0 else 0.002
                await RenderingServer.frame_post_draw
                _capture("pass-%s-%02d-%d.png" % [mode,i,offset])
        game.camera.h_offset = 0.0
    print("SURFACE_PROFILE_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _gather_materials() -> void:
    simple_wood.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 timber_color : source_color;
void fragment() {
    ALBEDO = timber_color.rgb * 0.88;
    ROUGHNESS = 0.74;
    SPECULAR = 0.18;
}
"""
    simple_lacquer.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 pigment : source_color;
void fragment() {
    ALBEDO = pigment.rgb * 0.96;
    ROUGHNESS = 0.27;
    METALLIC = 0.045;
    SPECULAR = 0.86;
    CLEARCOAT = 0.82;
}
"""
    var wood_count := 0
    var lacquer_count := 0
    for material in game.render_materials.values():
        if not material is ShaderMaterial or material.shader not in [WOOD,LACQUER]:
            continue
        var wood: bool = material.shader == WOOD
        var params := {}
        for param in ["timber_color","oak_albedo","oak_normal","grain_offset"] if wood else (
            ["pigment","polish","micro_texture"]):
            params[param] = material.get_shader_parameter(param)
            if param in TEX_KEYS and not unfiltered.has(param):
                var image: Image = params[param].get_image()
                assert(image.has_mipmaps(),param)
                var with_mip := image.get_data_size()
                image.clear_mipmaps()
                _record({"kind":"texture","name":param,"bytes_base":image.get_data_size(),"bytes_mips":with_mip})
                unfiltered[param] = ImageTexture.create_from_image(image)
        materials.append({"ref":material,"wood":wood,"params":params})
        wood_count += int(wood)
        lacquer_count += int(not wood)
    assert(wood_count > 2 and lacquer_count > 2 and unfiltered.size() == 3)

func _apply(mode: String) -> void:
    for entry in materials:
        var material: ShaderMaterial = entry["ref"]
        var wood: bool = entry["wood"]
        var params: Dictionary = entry["params"]
        if wood and mode == "flat_wood":
            material.shader = simple_wood
            material.set_shader_parameter("timber_color",params["timber_color"])
        elif not wood and mode == "flat_lacquer":
            material.shader = simple_lacquer
            material.set_shader_parameter("pigment",params["pigment"])
        else:
            material.shader = WOOD if wood else LACQUER
            for param in params:
                var value: Variant = unfiltered[param] if mode=="legacy" and param in TEX_KEYS else params[param]
                material.set_shader_parameter(param,value)

func _place_pack(at_z: float, frame: int) -> void:
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        var z := at_z+floorf(float(i)/8.0)*1.07-1.70
        var x: float = game.track_center_at(z)+(float(i%8)-3.5)*1.26
        if marble == game.player:
            z = at_z
            x = game.track_center_at(z)-0.62
        marble.global_position = Vector3(x,game.height_at(z)+0.46,z)
        marble.linear_velocity = Vector3(0.0,0.0,-22.0)
    game.race_time = 0.6+float(frame)/24.0
    game.contact_shadows.update_shadows()
    game.camera.fov = 64.0
    game._update_camera(1.0,true)
    game.ui.label_timer = 1.0
    game.ui.update_hud()

func _capture(name: String) -> void:
    assert(get_viewport().get_texture().get_image().save_png("user://"+name) == OK)

func _record(row: Dictionary) -> void:
    out.store_line(JSON.stringify(row))
    out.flush()
    print("SURFACE_PROFILE ",JSON.stringify(row))
