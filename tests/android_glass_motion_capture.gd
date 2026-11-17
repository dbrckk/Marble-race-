extends Node

const GameScene := preload("res://scenes/main.tscn")
const Racer := preload("res://scripts/marble.gd")
const PreviousGlass := preload("res://tests/android_glass_baseline.gdshader")
const PARAMETERS := ["base_color","accent_color","vein_color","pattern_seed",
    "stripe_scale","boost_strength","visual_quality","skin_radiance","skin_signature"]
const MOTION_FRAMES := 18
var measurements := FileAccess.open("user://glass-motion.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    await RenderingServer.frame_post_draw
    print("GLASS_MOTION_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    await _measure_shadows()
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    var stage := Node3D.new()
    add_child(stage)
    var camera := Camera3D.new()
    camera.fov = 42.0
    stage.add_child(camera)
    camera.make_current()
    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48,-28,-8)
    key_light.light_color = Color("#ffecd5")
    key_light.light_energy = 1.13
    stage.add_child(key_light)
    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-30,150,0)
    fill_light.light_color = Color("#cae4f4")
    fill_light.light_energy = 0.38
    stage.add_child(fill_light)
    var env_holder := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#25242a")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#d9e4e6")
    env.ambient_light_energy = 0.46
    env_holder.environment = env
    stage.add_child(env_holder)

    var marbles: Array[RigidBody3D] = []
    var prior_materials: Array[ShaderMaterial] = []
    for i in range(40):
        var marble := Racer.new()
        var row := floorf(float(i)/10.0)
        marble.setup(i,i==39,Vector3((float(i%10)-4.5)*0.91,(row-1.5)*0.91,-7.25-row*0.33))
        marble.freeze = true
        stage.add_child(marble)
        marbles.append(marble)
        var prior := ShaderMaterial.new()
        prior.shader = PreviousGlass
        for parameter in PARAMETERS:
            var value: Variant = marble.glass_material.get_shader_parameter(parameter)
            if value != null:
                prior.set_shader_parameter(parameter,value)
        prior_materials.append(prior)

    for quality in [1,0]:
        for i in range(marbles.size()):
            marbles[i].set_render_quality(quality)
            prior_materials[i].set_shader_parameter("visual_quality",float(quality))
        for block in range(2):
            for offset in range(2):
                var revision := (offset+block)%2
                for i in range(marbles.size()):
                    marbles[i].mesh.material_override = marbles[i].glass_material if revision else prior_materials[i]
                for warm in range(5):
                    await RenderingServer.frame_post_draw
                var samples := PackedFloat64Array()
                for frame in range(MOTION_FRAMES):
                    _pose(marbles,frame)
                    var start := Time.get_ticks_usec()
                    await RenderingServer.frame_post_draw
                    samples.append(float(Time.get_ticks_usec()-start)/1000.0)
                samples.sort()
                var stats := _counts()
                stats.merge({"kind":"timing","quality":quality,"revision":revision,"block":block,
                    "median_ms":0.5*(samples[8]+samples[9]),"p95_ms":samples[17]})
                _record(stats)
                if block == 1:
                    for frame in range(MOTION_FRAMES):
                        _pose(marbles,frame)
                        await RenderingServer.frame_post_draw
                        var name := "user://glass-%d-%d-%02d.png" % [quality,revision,frame]
                        assert(get_viewport().get_texture().get_image().save_png(name) == OK)
        print("GLASS_MOTION_QUALITY ",quality)
    print("GLASS_MOTION_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _pose(marbles: Array[RigidBody3D], frame: int) -> void:
    for i in range(marbles.size()):
        marbles[i].rotation = Vector3(float(i)*0.21+float(frame)*0.019,
            float(i)*0.32+float(frame)*(0.018+0.002*float(i%5)),0.13)

func _measure_shadows() -> void:
    var game := GameScene.instantiate()
    add_child(game)
    await RenderingServer.frame_post_draw
    assert(game.set_track(0))
    game.career.save_path = "user://glass-motion-qa.cfg"
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40 and game.contact_shadows.pool.visible_instance_count == 40)
    game.set_process(false)
    game.set_physics_process(false)
    for direct_shadows in [false,true,false]:
        for marble in game.racers:
            if direct_shadows:
                marble.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
            else:
                marble.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        for warm in range(5):
            await RenderingServer.frame_post_draw
        var stats := _counts()
        stats.merge({"kind":"shadow","individual":direct_shadows})
        _record(stats)
    game.queue_free()
    await get_tree().process_frame

func _counts() -> Dictionary:
    return {"draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
        "triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}

func _record(stats: Dictionary) -> void:
    measurements.store_line(JSON.stringify(stats))
    measurements.flush()
    print("GLASS_MOTION ",JSON.stringify(stats))
