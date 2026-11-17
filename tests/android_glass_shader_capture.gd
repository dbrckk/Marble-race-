extends Node

const OLD_SHADER = preload("res://tests/android_glass_baseline.gdshader")

const RACER = preload("res://scripts/marble.gd")
const COOL := Color("#cae4f4")
const PARAMS := ["base_color","accent_color","vein_color","pattern_seed",
    "stripe_scale","boost_strength","visual_quality","skin_radiance","skin_signature"]

func _ready() -> void:
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
    fill_light.light_color = COOL
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
        var marble := RACER.new()
        marble.setup(i,i==39,Vector3((float(i%10)-4.5)*0.91,(float(i/10)-1.5)*0.91,-7.25))
        marble.rotation = Vector3(float(i)*0.21,float(i)*0.32,0.13)
        marble.freeze = true
        stage.add_child(marble)
        marbles.append(marble)
        var prior := ShaderMaterial.new()
        prior.shader = OLD_SHADER
        for parameter in PARAMS:
            var value: Variant = marble.glass_material.get_shader_parameter(parameter)
            if value != null:
                prior.set_shader_parameter(parameter,value)
        prior_materials.append(prior)
    var viewport := get_viewport()
    var viewport_rid := viewport.get_viewport_rid()
    RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
    await RenderingServer.frame_post_draw
    print("GLASS_PAIR_DEVICE ", JSON.stringify({
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "width": int(viewport.get_visible_rect().size.x),
        "height": int(viewport.get_visible_rect().size.y),
    }))

    for quality in [1,0]:
        for i in range(marbles.size()):
            marbles[i].set_render_quality(quality)
            prior_materials[i].set_shader_parameter("visual_quality",float(quality))
        for block in range(3):
            for j in range(2):
                var revision := (j+block)%2
                for i in range(marbles.size()):
                    marbles[i].mesh.material_override = marbles[i].glass_material if revision == 1 else prior_materials[i]
                for warm in range(6):
                    await RenderingServer.frame_post_draw
                var wall := PackedFloat64Array()
                var gpu := PackedFloat64Array()
                var before := Time.get_ticks_usec()
                for frame in range(16):
                    await RenderingServer.frame_post_draw
                    var now := Time.get_ticks_usec()
                    wall.append(float(now-before)/1000.0)
                    before = now
                    gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
                wall.sort()
                gpu.sort()
                print("GLASS_PAIR ",JSON.stringify({"quality":quality,"revision":revision,"block":block,
                    "median_ms":(wall[7]+wall[8])*0.5,"p95_ms":wall[15],"gpu_ms":(gpu[7]+gpu[8])*0.5,
                    "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
                    "triangles":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}))
                if block == 2:
                    assert(viewport.get_texture().get_image().save_png("user://plain-%d-%d.png" % [quality,revision]) == OK)

    # Freeze both shader clocks at the same instant to compare the ten waves.
    var frozen_old := Shader.new()
    frozen_old.code = OLD_SHADER.code.replace("TIME","0.73")
    var frozen_new := Shader.new()
    frozen_new.code = marbles[0].glass_material.shader.code.replace("TIME","0.73")
    for i in range(marbles.size()):
        prior_materials[i].shader = frozen_old
        (marbles[i].glass_material as ShaderMaterial).shader = frozen_new
        for material in [prior_materials[i],marbles[i].glass_material]:
            material.set_shader_parameter("skin_radiance",1.0 if i < 10 else 0.0)
            material.set_shader_parameter("skin_signature",float(i % 10))
            material.set_shader_parameter("boost_strength",0.55 if i % 2 == 0 else 0.0)
    for quality in [0,1,2]:
        for i in range(marbles.size()):
            marbles[i].set_render_quality(quality)
            prior_materials[i].set_shader_parameter("visual_quality",float(quality))
        for revision in range(2):
            for i in range(marbles.size()):
                marbles[i].mesh.material_override = marbles[i].glass_material if revision == 1 else prior_materials[i]
            for warm in range(8):
                await RenderingServer.frame_post_draw
            assert(viewport.get_texture().get_image().save_png("user://premium-%d-%d.png" % [quality,revision]) == OK)
    print("GLASS_PAIR_PASS")
