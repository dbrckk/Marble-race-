extends Node3D
## Full 3D toy race stage, deterministic course layout, 40 simulated rigidbodies.
## Android-friendly: no downloaded textures, no runtime network, GLES3 compatibility.

const Racer = preload("res://scripts/marble.gd")
const HUD = preload("res://scripts/hud.gd")
const WOOD_SHADER = preload("res://shaders/wood.gdshader")
const OAK = preload("res://assets/textures/oak_albedo.png")
const OAK_NORMAL = preload("res://assets/textures/oak_normal.png")
const Audio = preload("res://scripts/audio.gd")
const Visuals = preload("res://scripts/visuals.gd")
const TrackFX = preload("res://scripts/track_fx.gd")
const ContactShadows = preload("res://scripts/contact_shadows.gd")
const LACQUER_SHADER = preload("res://shaders/lacquer.gdshader")
const LACQUER_MICRO = preload("res://assets/textures/lacquer_micro.png")
const MechanismArt = preload("res://scripts/mechanism_art.gd")
const CourseDressing = preload("res://scripts/course_dressing.gd")
const ObstacleFinish = preload("res://scripts/obstacle_finish.gd")
const TrackSurface = preload("res://scripts/track_surface.gd")
const Career = preload("res://scripts/career.gd")

const MARBLE_COUNT := 40
const SLOPE := 0.085
const SEGMENT_LENGTH := 12.0
const SEGMENTS := 18
const FINISH_Z := -185.0
const RACE_TIMEOUT := 155.0
const TRACK_NAMES := ["WOODWORKS","SWITCHBACK","GAUNTLET"]
const TRACK_SUBTITLES := [
    "Precision & flowing chicanes",
    "Moving gates & tighter openings",
    "Unforgiving hazards & fast paddles"
]
const TRACK_COLORS := [Color("#e6b972"),Color("#86bfbd"),Color("#dc8c82")]
const BARRIER_COLORS := [
    Color("#ce6958"), Color("#dbb66d"), Color("#62a89f"),
    Color("#799eb7"), Color("#9c88b4"), Color("#ca9670")
]
const WOOD_COLORS := [
    Color("#855b42"), Color("#8f664a"), Color("#946b4c"),
    Color("#a37958"), Color("#8f6246"), Color("#a17a57"),
    Color("#966b4d"), Color("#967454")
]

var rng := RandomNumberGenerator.new()
var ui: CanvasLayer
var audio: Node3D
var camera: Camera3D
var board: Node3D
var moving_obstacles: Array[Node3D] = []
var racers: Array[RigidBody3D] = []
var player: RigidBody3D
var racer_finish_order: Array[String] = []
var render_materials := {}
var race_state := "MENU"
var race_time := 0.0
var countdown := 3.0
var result_delay := 0.0
var boost_energy := 1.0
var boosting := false
var steer := 0.0
var steer_target := 0.0
var selected_perk := ""
var cam_mode := 0
var world_time := 0.0
var finish_announced := false
var camera_shake := 0.0
var camera_lookahead := Vector3.ZERO
var feedback_cooldown := 0.0
var obstacle_notice := 0.0
var last_count := -1
var last_checkpoint := -1
var course_flash := 0.0
var trail: CPUParticles3D
var starting_camera_target := Vector3(0, 0, 0)
var player_marker: Label3D
var contact_shadows: Node3D
var workshop_lamps: Array[OmniLight3D] = []
var lamp_refresh := 0.0
var kinetic_time := 0.0
var obstacle_finish: Node3D
var track_surface: Node3D
var track_physics_material: PhysicsMaterial
var primary_light: DirectionalLight3D
var world_environment: Environment
var graphics_quality := 1
var show_fps := false
var career: RefCounted
var selected_track := 0
var race_variation := 0
var result_saved := false
var last_result: Dictionary = {}
const QUALITY_NAMES := ["ECONOMY","BALANCED","ULTRA"]

func _ready() -> void:
    rng.seed = 424242
    career = Career.new()
    career.load_save()
    track_physics_material = PhysicsMaterial.new()
    track_physics_material.friction = 0.85
    track_physics_material.bounce = 0.09
    var prefs := ConfigFile.new()
    if prefs.load("user://marble_settings.cfg") == OK:
        graphics_quality = clampi(int(prefs.get_value("video","quality",1)),0,2)
        show_fps = bool(prefs.get_value("video","fps",false))
    _make_environment()
    _make_course()
    contact_shadows = ContactShadows.new()
    contact_shadows.name = "DynamicContactShadows"
    add_child(contact_shadows)
    camera = Camera3D.new()
    camera.name = "RaceCamera"
    camera.current = true
    camera.fov = 64.0
    # Avoid the 6000:1 depth range that caused distant plank z-fighting.
    camera.near = 0.16
    camera.far = 140.0
    add_child(camera)
    audio = Audio.new()
    audio.name = "RaceAudio"
    add_child(audio)
    audio.bind_mechanisms(moving_obstacles)
    ui = HUD.new()
    add_child(ui)
    ui.attach_game(self)
    _position_intro_camera(true)
    _spawn_racers() # Frozen showroom preview gives the menu moving-world context.
    _apply_graphics_quality()
    ui.show_menu()

func _make_environment() -> void:
    var env_node = WorldEnvironment.new()
    env_node.name = "StudioEnvironment"
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#211b1d")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#e5d2bb")
    env.ambient_light_energy = 0.62
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("#40332f")
    env.fog_density = 0.007
    env.glow_enabled = true
    env.glow_intensity = 0.24
    env_node.environment = env
    world_environment = env
    add_child(env_node)

    var sun = DirectionalLight3D.new()
    sun.name = "LargeSoftbox"
    sun.rotation_degrees = Vector3(-48, -28, -8)
    sun.light_color = Color("#ffecd5")
    sun.light_energy = 1.08
    sun.light_angular_distance = 0.55
    sun.shadow_enabled = true
    primary_light = sun
    sun.directional_shadow_max_distance = 75.0
    add_child(sun)

    var fill = DirectionalLight3D.new()
    fill.name = "CoolFill"
    fill.rotation_degrees = Vector3(-30, 150, 0)
    fill.light_color = Color("#cae4f4")
    fill.light_energy = 0.31
    add_child(fill)

func _save_visual_preferences() -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://marble_settings.cfg")
    cfg.set_value("video","quality",graphics_quality)
    cfg.set_value("video","fps",show_fps)
    cfg.save("user://marble_settings.cfg")

func set_graphics_quality(next_quality: int) -> void:
    graphics_quality = clampi(next_quality,0,2)
    _apply_graphics_quality()
    _save_visual_preferences()

func toggle_fps_overlay() -> bool:
    show_fps = not show_fps
    if is_instance_valid(ui) and is_instance_valid(ui.fps_label):
        ui.fps_label.get_parent().visible = show_fps
    _save_visual_preferences()
    return show_fps

func _apply_graphics_quality() -> void:
    if is_instance_valid(primary_light):
        primary_light.shadow_enabled = graphics_quality > 0
        primary_light.directional_shadow_max_distance = 72.0 if graphics_quality == 2 else 47.0
    if is_instance_valid(camera):
        camera.far = [85.0,115.0,155.0][graphics_quality]
    if world_environment != null:
        world_environment.glow_enabled = graphics_quality > 0
        world_environment.fog_enabled = graphics_quality > 0
    if is_instance_valid(contact_shadows):
        contact_shadows.visible = graphics_quality > 0
        contact_shadows.set_update_rate(60 if graphics_quality == 2 else 30)
    if is_instance_valid(obstacle_finish):
        obstacle_finish.visible = graphics_quality > 0
    if is_instance_valid(track_surface):
        track_surface.set_detail_quality(graphics_quality)
    if is_instance_valid(board):
        var dressing := board.get_node_or_null("ModularBrassAndSilkDressing")
        if is_instance_valid(dressing):
            dressing.visible = graphics_quality > 0
    # Compatibility renderer: avoid costly multisample AA outside ULTRA.
    var viewport := get_viewport()
    viewport.msaa_3d = Viewport.MSAA_2X if graphics_quality == 2 else Viewport.MSAA_DISABLED
    if OS.has_feature("mobile"):
        Engine.max_fps = 30 if graphics_quality == 0 else 60
    if is_instance_valid(trail):
        trail.amount = [12,22,36][graphics_quality]
        if graphics_quality == 0:
            trail.emitting = false
    for marble in racers:
        if is_instance_valid(marble):
            marble.set_render_quality(graphics_quality)

func set_track(index: int) -> bool:
    if index < 0 or index >= TRACK_NAMES.size() or not career.is_unlocked(index):
        return false
    if race_state != "MENU" and race_state != "RESULTS":
        return false
    if index == selected_track:
        return true
    selected_track = index
    race_variation = 0
    _make_course()
    audio.bind_mechanisms(moving_obstacles)
    _apply_graphics_quality()
    return true

func current_timeout() -> float:
    return RACE_TIMEOUT + selected_track * 24.0

func track_title() -> String:
    return TRACK_NAMES[selected_track]

func height_at(z: float) -> float:
    return z * SLOPE

func _mat(color: Color, roughness := 0.74, metalness := 0.0) -> StandardMaterial3D:
    var key = color.to_html() + "_" + str(roughness) + "_" + str(metalness)
    if render_materials.has(key):
        return render_materials[key]
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metalness
    if metalness > 0.08:
        m.metallic_specular = 0.8
    render_materials[key] = m
    return m

func _lacquer(color: Color) -> ShaderMaterial:
    var key := "lacquer_" + color.to_html()
    if render_materials.has(key):
        return render_materials[key]
    var finish := ShaderMaterial.new()
    finish.shader = LACQUER_SHADER
    finish.set_shader_parameter("pigment",color)
    finish.set_shader_parameter("polish",0.68)
    finish.set_shader_parameter("micro_texture",LACQUER_MICRO)
    render_materials[key] = finish
    return finish

func _wood_mat(color: Color) -> ShaderMaterial:
    var key = "wood_" + color.to_html()
    if render_materials.has(key):
        return render_materials[key]
    var m = ShaderMaterial.new()
    m.shader = WOOD_SHADER
    m.set_shader_parameter("timber_color", color)
    m.set_shader_parameter("oak_albedo", OAK)
    m.set_shader_parameter("oak_normal", OAK_NORMAL)
    m.set_shader_parameter("grain_offset", float(render_materials.size() % 8)*0.13)
    render_materials[key] = m
    return m

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, material: Material, solid := true, tilt := false, show_art := true) -> Node3D:
    var holder: Node3D
    if solid:
        holder = StaticBody3D.new()
        var collision = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = dimensions
        collision.shape = shape
        holder.add_child(collision)
        (holder as StaticBody3D).physics_material_override = track_physics_material
    else:
        holder = Node3D.new()
    holder.position = location
    if tilt:
        holder.rotation.x = -atan(SLOPE)
    if show_art:
        var art := MeshInstance3D.new()
        var bevel := minf(0.11, minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.12)
        art.mesh = Visuals.rounded_box(dimensions, bevel)
        art.material_override = material
        holder.add_child(art)
    parent.add_child(holder)
    return holder

func _cylinder(parent: Node3D, location: Vector3, radius: float, tall: float, color: Color) -> StaticBody3D:
    var body = StaticBody3D.new()
    body.name = "ToyPeg"
    body.position = location
    parent.add_child(body)
    if is_instance_valid(obstacle_finish):
        obstacle_finish.register_post(location,radius,tall,color)
    var hitbox = CollisionShape3D.new()
    var cylinder = CylinderShape3D.new()
    cylinder.radius = radius
    cylinder.height = tall
    hitbox.shape = cylinder
    body.add_child(hitbox)
    var art = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = tall
    mesh.radial_segments = 24
    art.mesh = mesh
    # Neutral molded bodies; color is reserved for safety rings and cap.
    # Avoids dozens of equally saturated rainbow poles competing for attention.
    art.material_override = _mat(Color("#85756a").lerp(color,0.16),0.43,0.08)
    body.add_child(art)
    var cap = MeshInstance3D.new()
    var cap_mesh = SphereMesh.new()
    cap_mesh.radius = radius * 0.99
    cap_mesh.height = radius * 0.30
    cap_mesh.radial_segments = 16
    cap_mesh.rings = 4
    cap.mesh = cap_mesh
    cap.position.y = tall * 0.5
    cap.material_override = _mat(color.lightened(0.17), 0.19)
    body.add_child(cap)
    return body

func _make_course() -> void:
    if is_instance_valid(board):
        board.queue_free()
    board = Node3D.new()
    board.name = "HandcraftedWoodenCourse"
    board.set_meta("track_index",selected_track)
    add_child(board)
    moving_obstacles.clear()
    obstacle_finish = ObstacleFinish.new()
    obstacle_finish.name = "PremiumObstacleFinishes"
    board.add_child(obstacle_finish)
    track_surface = TrackSurface.new()
    track_surface.name = "InstancedTrackSurface"
    board.add_child(track_surface)
    var incline = -atan(SLOPE)
    for section in range(SEGMENTS):
        var center_z = 8.0 - float(section) * SEGMENT_LENGTH
        var section_node = Node3D.new()
        section_node.name = "Course_%02d" % section
        board.add_child(section_node)
        for lane in range(10):
            var x := (float(lane) - 4.5) * 1.34
            var material_index := (lane + section * 3) % WOOD_COLORS.size()
            var shade: Color = WOOD_COLORS[material_index]
            var plank_at := Vector3(x,height_at(center_z)-0.34,center_z)
            # Render-only planks share GPU draw calls by material. Each keeps
            # the exact original independent tilted BoxShape3D collider.
            _box(section_node,plank_at,
                Vector3(1.315,0.65,SEGMENT_LENGTH+0.08),_wood_mat(shade),true,true,false)
            track_surface.register_plank(plank_at,material_index)
            for j in range(2):
                var z: float = center_z+(float(j)-0.5)*4.4
                track_surface.register_groove(Vector3(x-0.34+(j%2)*0.31,height_at(z)+0.005,z))
        for side in [-1,1]:
            for rail_piece in range(3):
                var z: float = center_z+(rail_piece-1)*4.02
                var color_idx := (section+rail_piece+(0 if side==1 else 3))%BARRIER_COLORS.size()
                var pos := Vector3(side*6.84,height_at(z)+0.58,z)
                _box(section_node,pos,Vector3(0.57,1.26,4.04),
                    _lacquer(BARRIER_COLORS[color_idx]),true,true,false)
                track_surface.register_rail(pos,color_idx)
        if section > 0 and section < SEGMENTS - 3:
            # Edge-specific baffles eliminate the dominant strategy of riding
            # permanently against either rail. Passages remain physically open.
            _edge_baffles(section_node,center_z,section)
            var layout := (section + selected_track + race_variation) % 3
            if layout == 1:
                _pegs(section_node, center_z, section)
            elif layout == 2:
                _gate_with_posts(section_node, center_z, section)
            else:
                _slalom(section_node, center_z, section)

    obstacle_finish.rebuild()
    var woods: Array = []
    for color in WOOD_COLORS:
        woods.append(_wood_mat(color))
    var barriers: Array = []
    for color in BARRIER_COLORS:
        barriers.append(_lacquer(color))
    track_surface.finish(woods,barriers,_mat(Color("#82563d")))
    _start_arch()
    _finish_arch()
    _checkpoint_arches()
    _decorations()
    _showroom()
    var cosmetic = TrackFX.new()
    cosmetic.name = "PolishedToyDetails"
    board.add_child(cosmetic)
    var dressing := CourseDressing.new()
    dressing.name = "ModularBrassAndSilkDressing"
    board.add_child(dressing)

func _edge_baffles(parent: Node3D, center_z: float, section: int) -> void:
    # Two solid edge shutters per module, plus a staggered inboard obstacle
    # for advanced circuits. These are real collisions, not cosmetic warnings.
    for side in [-1.0, 1.0]:
        var z: float = center_z + (3.75 if side < 0.0 else -3.75)
        var material_color: Color = TRACK_COLORS[selected_track].darkened(0.13)
        var size := Vector3(2.72,1.05,1.32)
        var node := _box(parent,Vector3(side * 5.17,height_at(z)+0.49,z),
            size,_lacquer(material_color),true,true)
        node.name = "AntiEdgeBaffle_%02d_%s" % [section, "L" if side < 0.0 else "R"]
        obstacle_finish.register_block(node.transform,size,material_color)
    if selected_track >= 1 and section % 3 == 0:
        # This diagonal gate reaches further into the lane but leaves a
        # broad side opening. Alternates its side across modules.
        var side := -1.0 if (section/2 + race_variation)%2==0 else 1.0
        var z: float = center_z
        var wide := Vector3(3.45 if selected_track == 1 else 3.95,0.82,1.25)
        var x := side * (4.45 if selected_track == 1 else 4.30)
        var tint: Color = TRACK_COLORS[selected_track].lightened(0.05)
        var gate := _box(parent,Vector3(x,height_at(z)+0.37,z),
            wide,_lacquer(tint),true,true)
        gate.name = "Chicane_%02d" % section
        obstacle_finish.register_block(gate.transform,wide,tint)

func _pegs(parent: Node3D, center_z: float, n: int) -> void:
    # Checkerboard of rounded vertical posts, with traversable gaps.
    for row in range(3):
        var z = center_z + 3.0 - row * 3.2
        for c in range(5):
            var shift := sin(float(n*9+row*3+race_variation*7))*0.23
            var x = (c - 2) * 2.20 + (0.56 if row % 2 == 1 else 0.0) + shift
            var tint = BARRIER_COLORS[(n + c + row) % BARRIER_COLORS.size()]
            _cylinder(parent, Vector3(x, height_at(z)+0.8, z), 0.31, 1.6, tint)

func _gate_with_posts(parent: Node3D, center_z: float, n: int) -> void:
    for row in range(3 if selected_track == 2 else 2):
        var z = center_z + 3.2 - row * (4.2 if selected_track == 2 else 6.0)
        for i in range(3):
            var x = -4.6 + i * 4.7 + (0.65 if row == 1 else 0.0)
            var gate_color: Color = BARRIER_COLORS[(n+row+i)%6]
            var size := Vector3(0.91,1.37,1.25)
            var block := _box(parent, Vector3(x,height_at(z)+0.67,z),
                size,_lacquer(gate_color),true,true)
            obstacle_finish.register_block(block.transform,size,gate_color)
    _add_spinner(parent, center_z, n)
    _swing_hammer(parent, center_z - 1.6, n)

func _swing_hammer(parent: Node3D, z: float, n: int) -> void:
    var hinge = AnimatableBody3D.new()
    hinge.name = "SwingHammer_%02d" % n
    hinge.sync_to_physics = true
    hinge.position = Vector3(2.4 if n%2==0 else -2.4, height_at(z)+1.25, z)
    parent.add_child(hinge)
    var size := Vector3(2.25, 0.52, 0.72)
    var hit = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    hit.shape = shape
    hit.position.y = -0.45
    hinge.add_child(hit)
    var art = MeshInstance3D.new()
    art.mesh = Visuals.rounded_box(size, 0.15)
    art.position = hit.position
    art.material_override = _lacquer(BARRIER_COLORS[(n+3)%6])
    hinge.add_child(art)
    MechanismArt.decorate_hammer(hinge, parent, _mat(Color("#d6ad67"),0.27,0.72), _mat(Color("#262b33"),0.52,0.12))
    hinge.set_meta("motion_kind","hammer")
    hinge.set_meta("speed",(1.3+float(n%3)*0.22)*(1.0+0.18*selected_track))
    hinge.set_meta("phase",float(n)*1.8)
    moving_obstacles.append(hinge)

func _slalom(parent: Node3D, center_z: float, n: int) -> void:
    for i in range(5 if selected_track == 2 else 4):
        var z = center_z + 4.4 - float(i) * (2.2 if selected_track == 2 else 2.8)
        var x = (-3.5 if i % 2 == 0 else 3.5)
        var slalom_color: Color = BARRIER_COLORS[(n+i)%6]
        var size := Vector3(3.4,0.75,1.05)
        var block := _box(parent, Vector3(x,height_at(z)+0.36,z),
            size,_lacquer(slalom_color),true,true)
        obstacle_finish.register_block(block.transform,size,slalom_color)
    for i in range(3):
        var z = center_z + 2.3 - i * 3.5
        _cylinder(parent, Vector3(0, height_at(z)+0.65, z), 0.34, 1.3, BARRIER_COLORS[(n+2*i)%6])

func _add_spinner(parent: Node3D, z: float, n: int) -> void:
    var pivot = AnimatableBody3D.new()
    pivot.name = "KineticPaddle_%02d" % n
    pivot.sync_to_physics = true
    pivot.position = Vector3(0.0, height_at(z) + 0.73, z)
    parent.add_child(pivot)
    var color = BARRIER_COLORS[(n + 1) % BARRIER_COLORS.size()]
    # A single wide paddle that rotates and pushes marbles physically.
    for i in range(2):
        var spoke = Node3D.new()
        spoke.rotation.y = PI * 0.5 * i
        pivot.add_child(spoke)
        var mesh = MeshInstance3D.new()
        var arm_size = Vector3(7.1 if i==0 else 4.8, 0.56, 0.34)
        mesh.mesh = Visuals.rounded_box(arm_size,0.12)
        mesh.material_override = _lacquer(color if i==0 else BARRIER_COLORS[(n+3)%6])
        spoke.add_child(mesh)
        # Collider needs rotation on CollisionShape rather than relying on untransformed parent body.
        var hit = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = arm_size
        hit.shape = shape
        hit.rotation.y = spoke.rotation.y
        pivot.add_child(hit)
        MechanismArt.stripe_arm(spoke,arm_size, _mat(Color("#242936"),0.37,0.24))
    var axle = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.height = 1.3
    cyl.top_radius = 0.42
    cyl.bottom_radius = 0.42
    axle.mesh = cyl
    axle.material_override = _mat(Color("#f0c361"), 0.25, 0.16)
    pivot.add_child(axle)
    MechanismArt.decorate_spinner(pivot, parent, _mat(Color("#d6ad67"),0.27,0.72), _mat(Color("#292d35"),0.36,0.22))
    pivot.set_meta("motion_kind","spinner")
    pivot.set_meta("spin_speed", (1.0 if n%2==0 else -1.0) * (0.72 + n*0.022) * (1.0 + 0.19*selected_track))
    moving_obstacles.append(pivot)

func _start_arch() -> void:
    var z = 2.25
    for x in [-6.0, 6.0]:
        _box(board, Vector3(x, height_at(z)+1.7, z), Vector3(0.52, 3.2, 0.45),
            _mat(Color("#c84d40")), false)
    _box(board, Vector3(0, height_at(z)+3.1, z),
        Vector3(12.4, 0.63, 0.52), _mat(Color("#ca5645")), false)
    _floating_sign("START · 40 MARBLES", Vector3(0, height_at(z)+3.64, z))

func _finish_arch() -> void:
    var z = FINISH_Z - 1.6
    for x in [-6.0, 6.0]:
        _box(board, Vector3(x, height_at(z)+1.35, z),
            Vector3(0.48, 2.8, 0.45), _mat(Color("#eee1bd")), false)
    _box(board, Vector3(0, height_at(z)+2.62, z),
        Vector3(12.6, 0.52, 0.55), _mat(Color("#f3d779")), false)
    _floating_sign("FINISH", Vector3(0, height_at(z)+3.12, z))
    # Checkered line visible on the wooden surface.
    for i in range(12):
        _box(board, Vector3(-5.75 + i*1.04, height_at(z)+0.034, z),
            Vector3(1.02, 0.045, 0.63), _mat(Color("#f2e5d0") if i%2==0 else Color("#342a28")), false)

func _checkpoint_arches() -> void:
    for n in [4,9,14]:
        var z = 8.0 - float(n) * SEGMENT_LENGTH
        var y = height_at(z)
        for side in [-1.0,1.0]:
            _box(board,Vector3(side*6.28,y+2.4,z),Vector3(0.21,4.7,0.28),
                _mat(Color("#e6c488"),0.3,0.28),false)
        _box(board,Vector3(0,y+4.65,z),Vector3(12.7,0.32,0.38),
            _mat(Color("#dfb66c"),0.35,0.2),false)
        _floating_sign("CHECKPOINT %d" % int(n/5+1),Vector3(0,y+5.22,z))

func _floating_sign(message: String, location: Vector3) -> void:
    var label = Label3D.new()
    label.text = message
    label.font_size = 34
    label.pixel_size = 0.015
    label.outline_size = 6
    label.modulate = Color("#fff5e1")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = location
    board.add_child(label)

func _decorations() -> void:
    # Oversized toy building blocks and wooden track supports outside the racing lanes.
    for j in range(18):
        var z = 9.0 - j * 6.0
        for side in [-1, 1]:
            if j % 3 == 0:
                var x = side * (8.1 + (j%4)*0.48)
                var c = BARRIER_COLORS[(j + (0 if side==1 else 2)) % 6]
                var y = height_at(z) + 0.20 + (j%3)*0.16
                _box(board, Vector3(x,y,z), Vector3(1.18,1.25+(j%4)*0.35,1.45),
                    _mat(c,0.59), false)
    for k in range(12):
        var z = 5.0 - k * 17.0
        for side in [-1,1]:
            var x = side * 5.0
            _box(board, Vector3(x,height_at(z)-2.6,z),
                Vector3(0.6, 4.4, 0.65), _mat(Color("#79523b")), false)

func _showroom() -> void:
    # Warm miniature workshop: walnut workbench, paneled walls, lit windows and
    # hanging display lamps. Deliberately sparse near the play area for 60fps.
    for i in range(SEGMENTS):
        var z = 8.0 - i * SEGMENT_LENGTH
        _box(board,Vector3(0,height_at(z)-3.7,z),
            Vector3(35.0,0.75,SEGMENT_LENGTH+0.12),_wood_mat(Color("#604535")),false,true)
        for side in [-1.0,1.0]:
            var base_x = side * 17.0
            _box(board,Vector3(base_x,height_at(z)+4.5,z),
                Vector3(1.3,19.0,SEGMENT_LENGTH+0.05),_mat(Color("#4c3933")),false)
            if i%2==0:
                _box(board,Vector3(base_x-side*0.73,height_at(z)+0.5,z),
                    Vector3(0.2,0.28,SEGMENT_LENGTH-0.6),
                    _mat(Color("#957052"),0.64),false)
    # Exposed beams, side shelves and colored toy cartons.
    for i in range(8):
        var z = 7.5-i*25.0
        for side in [-1.0,1.0]:
            var x=side*15.5
            _box(board,Vector3(x,height_at(z)+3.9,z),Vector3(2.5,0.28,8.5),
                _wood_mat(Color("#91715a")),false)
            for k in range(2):
                var box_color=BARRIER_COLORS[(i+k+(0 if side>0 else 3))%6]
                _box(board,Vector3(x-side*0.25,height_at(z)+4.6,z+(k-1)*2.7),
                    Vector3(1.0,1.1,1.6),_mat(box_color.darkened(0.28),0.63),false)
        var lamp=OmniLight3D.new()
        lamp.name="PendantLight_%02d" % i
        lamp.position=Vector3(0,height_at(z)+10.5,z)
        lamp.light_color=Color("#ffe3b4")
        lamp.light_energy=0.22
        lamp.omni_range=19
        lamp.shadow_enabled=false
        board.add_child(lamp)
        workshop_lamps.append(lamp)
        var glass=MeshInstance3D.new()
        var globe=SphereMesh.new()
        globe.radius=0.45
        globe.height=0.9
        glass.mesh=globe
        var mat=StandardMaterial3D.new()
        mat.albedo_color=Color("#f5d39b")
        mat.emission_enabled=true
        mat.emission=Color("#e9b96d")
        mat.emission_energy_multiplier=0.75
        glass.material_override=mat
        glass.position=lamp.position
        board.add_child(glass)
    # Big workshop awning visible above the distant track.
    _box(board,Vector3(0,14,-80),Vector3(38,0.8,192),_mat(Color("#49342d")),false)

func _spawn_racers() -> void:
    for m in racers:
        if is_instance_valid(m):
            m.queue_free()
    racers.clear()
    racer_finish_order.clear()
    player = null
    for i in range(MARBLE_COUNT):
        var row = i / 8
        var col = (i * 5 + 3) % 8
        var z = 12.2 - row * 1.12
        var x = (col - 3.5) * 1.36
        var p = Vector3(x, height_at(z) + 0.68, z)
        var m = Racer.new()
        var is_you = i == MARBLE_COUNT - 1
        m.setup(i, is_you, p, selected_perk)
        add_child(m)
        m.freeze = true
        racers.append(m)
        if is_you:
            player = m
            m.contact_monitor = true
            m.max_contacts_reported = 6
            _add_player_marker(m)
            _add_player_trail(m)

    if selected_perk == "Head Start" and is_instance_valid(player):
        player.position.z -= 3.2
        player.position.y = height_at(player.position.z)+0.68
    boost_energy = 1.0
    for marble in racers:
        marble.set_render_quality(graphics_quality)
    if is_instance_valid(trail):
        trail.amount = [12,22,36][graphics_quality]
    if is_instance_valid(contact_shadows):
        contact_shadows.bind_racers(racers)

func _add_player_marker(m: RigidBody3D) -> void:
    var tag = Label3D.new()
    tag.text = "▼ YOU"
    tag.name = "PlayerTag"
    tag.font_size = 41
    tag.pixel_size = 0.014
    tag.outline_size = 8
    tag.modulate = Color("#ffcb70")
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.no_depth_test = true
    tag.position = Vector3(0, 1.23, 0)
    m.add_child(tag)
    tag.top_level = true
    player_marker = tag

func _add_player_trail(m: RigidBody3D) -> void:
    trail = CPUParticles3D.new()
    trail.name = "CopperDustSpeedTrail"
    trail.position = Vector3(0,0,0.12)
    trail.amount = 28
    trail.lifetime = 0.52
    trail.explosiveness = 0.0
    trail.randomness = 0.35
    trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    trail.emission_sphere_radius = 0.18
    trail.direction = Vector3(0,0,1)
    trail.spread = 20.0
    trail.gravity = Vector3(0,-0.12,0)
    trail.initial_velocity_min = 0.2
    trail.initial_velocity_max = 0.8
    trail.color = Color(1.0,0.66,0.24,0.65)
    var dust = SphereMesh.new()
    dust.radius = 0.053
    dust.height = 0.105
    dust.radial_segments = 6
    dust.rings = 3
    trail.mesh = dust
    trail.emitting = false
    m.add_child(trail)

func _camera_bump(_body: Node) -> void:
    if not is_instance_valid(player) or race_state != "RACING":
        return
    var impact_speed: float = player.linear_velocity.length()
    if impact_speed < 2.2 or feedback_cooldown > 0.0:
        return
    camera_shake = minf(0.14,camera_shake+impact_speed*0.005)
    obstacle_notice = 0.46 if impact_speed > 7.0 else 0.20
    feedback_cooldown = 0.16

func start_race(perk_name: String) -> void:
    selected_perk = perk_name
    career.begin()
    result_saved = false
    last_result = {}
    # Alternating geometry order on repeat attempts avoids an identical course
    # without changing the course identity or difficulty.
    if race_variation > 0:
        _make_course()
        audio.bind_mechanisms(moving_obstacles)
        _apply_graphics_quality()
    race_variation = (race_variation+1)%3
    race_state = "COUNTDOWN"
    race_time = 0.0
    countdown = 3.3
    result_delay = 0.0
    finish_announced = false
    last_checkpoint = -1
    course_flash = 0.0
    steer = 0.0
    steer_target = 0.0
    boosting = false
    cam_mode = 0
    _spawn_racers()
    audio.bind_marble(player)
    player.body_entered.connect(_camera_bump)
    audio.begin_race()
    last_count = -1
    ui.show_race_ui()
    ui.show_countdown("READY?")
    _update_camera(0.1, true)

func restart_race() -> void:
    start_race(selected_perk)

func return_to_menu() -> void:
    for m in racers:
        if is_instance_valid(m):
            m.queue_free()
    racers.clear()
    player = null
    if is_instance_valid(contact_shadows):
        contact_shadows.clear_racers()
    race_state = "MENU"
    audio.menu_music()
    ui.show_menu()

func _process(delta: float) -> void:
    world_time += delta
    feedback_cooldown = maxf(0.0,feedback_cooldown-delta)
    obstacle_notice = maxf(0.0,obstacle_notice-delta)
    lamp_refresh -= delta
    if lamp_refresh <= 0.0:
        lamp_refresh = 0.25
        var view_z := player.global_position.z if is_instance_valid(player) and race_state != "MENU" else -3.0
        for lamp in workshop_lamps:
            if is_instance_valid(lamp):
                var illumination_range := 0.0 if graphics_quality == 0 else (42.0 if graphics_quality == 2 else 29.0)
                lamp.visible = absf(lamp.global_position.z - view_z) < illumination_range
    if is_instance_valid(player_marker) and is_instance_valid(player):
        player_marker.global_position = player.global_position + Vector3(0.0,1.22 + sin(world_time*3.6)*0.075,0.0)
    if race_state == "COUNTDOWN":
        countdown -= delta
        if countdown > 0.0:
            var count := int(ceil(countdown))
            ui.show_countdown(str(count))
            if count != last_count and count < 4:
                audio.tone("count")
                last_count = count
        else:
            race_state = "RACING"
            for m in racers:
                m.freeze = false
                m.sleeping = false
            ui.show_countdown("GO!")
            audio.tone("start")
    elif race_state == "RACING":
        race_time += delta
        if race_time > 1.0:
            ui.hide_countdown()
        if is_instance_valid(trail) and is_instance_valid(player):
            audio.update_progress(clampf(-player.position.z/absf(FINISH_Z),0.0,1.0))
            trail.emitting = graphics_quality > 0 and player.linear_velocity.length() > 4.0
            trail.initial_velocity_max = 2.6 if boosting else 0.75
            trail.color = Color("#91f5fd") if boosting else Color("#eeb65e")
            var cp := -1
            if player.position.z < -46.0:
                cp = 0
            if player.position.z < -106.0:
                cp = 1
            if player.position.z < -166.0:
                cp = 2
            if cp > last_checkpoint:
                last_checkpoint = cp
                if cp >= 0:
                    audio.tone("checkpoint")
                    var cosmetics := board.get_node_or_null("PolishedToyDetails")
                    if is_instance_valid(cosmetics):
                        cosmetics.pulse_checkpoint(cp)
                    ui.show_checkpoint(cp+1)
                    _burst(player.global_position, false)
        if boosting:
            boost_energy = max(0.0, boost_energy - delta * 0.26)
            if boost_energy <= 0.0:
                boosting = false
        else:
            boost_energy = min(1.0, boost_energy + delta * 0.08)
        if is_instance_valid(player) and (player.finished or player.eliminated):
            result_delay += delta
            if result_delay > 1.5 and not finish_announced:
                finish_announced = true
                _end_race()
        elif race_time >= current_timeout():
            _end_race()
    course_flash = maxf(0.0, course_flash - delta)
    _update_camera(delta)
    if race_state == "RACING" or race_state == "COUNTDOWN":
        ui.update_hud()

func _physics_process(delta: float) -> void:
    steer = move_toward(steer,steer_target,delta*8.5)
    kinetic_time += delta
    for obj in moving_obstacles:
        if not is_instance_valid(obj):
            continue
        if obj.get_meta("motion_kind", "") == "spinner":
            obj.rotation.y += delta * float(obj.get_meta("spin_speed"))
        else:
            obj.rotation.z = sin(kinetic_time*float(obj.get_meta("speed"))+float(obj.get_meta("phase")))*0.65
    if race_state != "RACING":
        return
    for m in racers:
        if not is_instance_valid(m):
            continue
        m.drive(delta, race_time, steer if m.is_player else 0.0, boosting and boost_energy>0.0 and m.is_player)
        if not m.finished and not m.eliminated and m.position.z < FINISH_Z:
            m.finished = true
            m.finish_time = race_time
            m.freeze = true
            racer_finish_order.append(m.display_name)
    if selected_perk == "Sticky Magnet" and is_instance_valid(player) and not player.finished:
        for m in racers:
            if m == player or m.finished or m.eliminated:
                continue
            var delta_pos: Vector3 = player.position - m.position
            var dist = delta_pos.length()
            if dist > 0.55 and dist < 3.8:
                var tug = delta_pos.normalized() * (3.8 - dist) * 1.65
                m.apply_central_force(tug * m.mass)
                player.apply_central_force(-tug * 0.14 * player.mass)
    if racer_finish_order.size() == MARBLE_COUNT:
        _end_race()

func _update_camera(delta: float, force := false) -> void:
    if not is_instance_valid(camera):
        return
    if race_state == "MENU" or not is_instance_valid(player):
        _position_intro_camera(force)
        return
    var target = player.global_position
    var desired: Vector3
    var focus: Vector3
    if cam_mode == 1:
        desired = target + Vector3(0, 12.5, 18.0)
        focus = target + Vector3(0, 0, -8.0)
    elif cam_mode == 2:
        desired = target + Vector3(0, 19.0, 2.5)
        focus = target + Vector3(0, 0, -3.5)
    else:
        desired = target + Vector3(0, 6.5, 11.5)
        focus = target + Vector3(0, 0.3, -5.5)
    camera_shake = move_toward(camera_shake,0.0,delta*0.55)
    camera_lookahead = camera_lookahead.lerp(
        Vector3(clampf(player.linear_velocity.x*0.20,-1.8,1.8),0.0,
        clampf(player.linear_velocity.z*0.27,-5.0,0.0)),minf(1.0,delta*3.0))
    focus += camera_lookahead
    var jitter := Vector3(sin(world_time*49.0), cos(world_time*43.0),0.0)*camera_shake
    camera.global_position = desired if force else (camera.global_position - camera.get_meta("previous_jitter",Vector3.ZERO)).lerp(desired,min(delta*3.5,1.0))
    camera.global_position += jitter
    camera.set_meta("previous_jitter",jitter)
    camera.look_at(focus, Vector3.UP)
    camera.fov = lerpf(camera.fov,clampf(62.0+player.linear_velocity.length()*0.48,64.0,76.0),minf(1,delta*2.8))

func _position_intro_camera(force: bool) -> void:
    var target = Vector3(6.5, 12.6, 22.0)
    var focus = Vector3(0, 0, -9)
    camera.global_position = target if force else camera.global_position.lerp(target, 0.035)
    camera.look_at(focus, Vector3.UP)

func get_rankings() -> Array:
    var copy = racers.duplicate()
    copy.sort_custom(func(a,b):
        if a.finished != b.finished:
            return a.finished
        if a.finished and b.finished:
            return a.finish_time < b.finish_time
        if a.eliminated != b.eliminated:
            return not a.eliminated
        return a.global_position.z < b.global_position.z
    )
    return copy

func player_rank() -> int:
    var ranks = get_rankings()
    return ranks.find(player) + 1

func remaining() -> int:
    var result := 0
    for m in racers:
        if is_instance_valid(m) and not m.finished and not m.eliminated:
            result += 1
    return result

func cycle_camera() -> void:
    cam_mode = (cam_mode + 1) % 3

func change_steer(value: float) -> void:
    steer_target = clampf(value, -1.0, 1.0)

func change_boost(value: bool) -> void:
    if value and not boosting and boost_energy > 0.08:
        audio.boost()
    boosting = value and boost_energy > 0.03

func _unhandled_input(event: InputEvent) -> void:
    if race_state != "RACING":
        return
    if event is InputEventKey:
        if event.echo:
            return
        if event.keycode == KEY_LEFT or event.keycode == KEY_A:
            change_steer(-1.0 if event.pressed else 0.0)
        elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
            change_steer(1.0 if event.pressed else 0.0)
        elif event.keycode == KEY_SPACE:
            change_boost(event.pressed)
        elif event.keycode == KEY_C and event.pressed:
            cycle_camera()

func _burst(where: Vector3, finale: bool) -> void:
    # Short-lived particles carry no collision meshes and remain inexpensive on mobile.
    var n := CPUParticles3D.new()
    n.name = "FinishConfetti" if finale else "CheckpointGlitter"
    n.amount = 100 if finale else 45
    n.lifetime = 1.9 if finale else 0.9
    n.one_shot = true
    n.explosiveness = 0.96
    n.randomness = 0.48
    n.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    n.emission_sphere_radius = 0.7 if finale else 0.28
    n.direction = Vector3(0.0,1.0,0.0)
    n.spread = 140.0
    n.gravity = Vector3(0.0,-8.0,0.0)
    n.initial_velocity_min = 2.0
    n.initial_velocity_max = 7.5 if finale else 3.5
    var candy = Gradient.new()
    candy.set_color(0, Color("#fff5ac"))
    candy.set_color(1, Color("#ff687a") if finale else Color("#9df2ee"))
    n.color_ramp = candy
    var art = SphereMesh.new()
    art.radius = 0.07 if finale else 0.04
    art.height = 0.10 if finale else 0.07
    art.radial_segments = 5
    art.rings = 3
    n.mesh = art
    n.position = where + Vector3.UP * 0.5
    add_child(n)
    n.finished.connect(n.queue_free)
    n.emitting = true

func _end_race() -> void:
    if race_state == "RESULTS":
        return
    if is_instance_valid(player) and player.finished:
        _burst(player.global_position, true)
    race_state = "RESULTS"
    boosting = false
    steer = 0.0
    steer_target = 0.0
    if not result_saved:
        result_saved = true
        last_result = career.complete(selected_track,player_rank(),
            player.finish_time if is_instance_valid(player) and player.finished else race_time,
            is_instance_valid(player) and player.finished)
    audio.tone("finish")
    if is_instance_valid(player) and player.finished:
        audio.finish_fanfare()
    audio.menu_music()
    ui.show_results(player_rank(), race_time, get_rankings())
