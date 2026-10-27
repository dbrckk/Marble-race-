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
const TrackPath = preload("res://scripts/track_path.gd")
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const RaceMoments = preload("res://scripts/race_moments.gd")
const TemporarySkins = preload("res://scripts/temporary_skins.gd")
const MonetizationBridge = preload("res://scripts/monetization_bridge.gd")
const PremiumSkinVisuals = preload("res://scripts/premium_skin_visuals.gd")
const Slipstream = preload("res://scripts/slipstream.gd")
const PerformanceBudget = preload("res://scripts/performance_budget.gd")
const RaceDirector = preload("res://scripts/race_director.gd")
const ShortcutRoute = preload("res://scripts/shortcut_route.gd")
const Career = preload("res://scripts/career.gd")
const BestGhost = preload("res://scripts/best_ghost.gd")
const InternetSession = preload("res://scripts/internet_session.gd")
const StudioPolish = preload("res://scripts/studio_polish.gd")
const RaceItems = preload("res://scripts/race_items.gd")
const CourseMechanics = preload("res://scripts/course_mechanics.gd")
const ArcadeBumpers = preload("res://scripts/arcade_bumpers.gd")
const TrackUniverses = preload("res://scripts/track_universes.gd")
const BiomeSignature = preload("res://scripts/biome_signature.gd")
const CourseSculptures = preload("res://scripts/course_sculptures.gd")

const MARBLE_COUNT := 40
const SLOPE := 0.085
const SEGMENT_LENGTH := 12.0
const SEGMENTS := 18
const FINISH_Z := -185.0
const RACE_TIMEOUT := 155.0
const TRACK_NAMES := ["WOODWORKS","SWITCHBACK","GAUNTLET"]
const TRACK_SUBTITLES := [
    "Woodland workshop & flowing chicanes",
    "Glacier pass & moving gates",
    "Ember forge & fast paddles"
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
var race_moments: RefCounted
var slipstream: RefCounted
var draft_cue_cooldown := 0.0
var performance_budget: RefCounted
var camera_lookahead := Vector3.ZERO
var feedback_cooldown := 0.0
var obstacle_notice := 0.0
var last_count := -1
var last_checkpoint := -1
var checkpoint_splits: Array[float] = []
var course_flash := 0.0
var trail: CPUParticles3D
var skins: Node
var monetization: Node
var starting_camera_target := Vector3(0, 0, 0)
var player_marker: Label3D
var contact_shadows: Node3D
var workshop_lamps: Array[OmniLight3D] = []
var lamp_refresh := 0.0
var kinetic_time := 0.0
var obstacle_finish: Node3D
var race_items: Node3D
var course_mechanics: Node3D
var arcade_bumpers: Node3D
var course_sculptures: Node3D
var race_director: Node3D
var shortcut_route: Node3D
var track_surface: Node3D
var track_physics_material: PhysicsMaterial
var primary_light: DirectionalLight3D
var world_environment: Environment
var graphics_quality := 1
var graphics_setting := 1 # 0 economy, 1 balanced, 2 ultra, 3 auto
var auto_fps_seconds := 0.0
var auto_fps_accum := 0.0
var auto_slow_seconds := 0.0
var auto_fast_seconds := 0.0
var show_fps := false
var career: RefCounted
var best_ghost: Node3D
var net: Node
var selected_track := 0
var race_variation := 0
var built_variation := -1
var hazard_beacons: Array[Dictionary] = []
var result_saved := false
var last_result: Dictionary = {}
const QUALITY_NAMES := ["ECONOMY","BALANCED","ULTRA","AUTO"]

func _ready() -> void:
    rng.seed = 424242
    career = Career.new()
    career.load_save()
    skins = TemporarySkins.new()
    skins.name = "TemporaryCosmeticPass"
    add_child(skins)
    skins.changed.connect(_refresh_premium_skin)
    monetization = MonetizationBridge.new()
    monetization.name = "VerifiedStoreBridge"
    add_child(monetization)
    monetization.configure(skins)
    track_physics_material = PhysicsMaterial.new()
    track_physics_material.friction = 0.85
    track_physics_material.bounce = 0.09
    var prefs := ConfigFile.new()
    if prefs.load("user://marble_settings.cfg") == OK:
        graphics_setting = clampi(int(prefs.get_value("video","quality",1)),0,3)
        graphics_quality = 1 if graphics_setting == 3 else graphics_setting
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
    audio.set_track_theme(selected_track)
    net = InternetSession.new()
    net.configure(self)
    add_child(net)
    ui = HUD.new()
    add_child(ui)
    ui.attach_game(self)
    race_moments = RaceMoments.new()
    race_moments.configure(self)
    slipstream = Slipstream.new()
    performance_budget = PerformanceBudget.new()
    _position_intro_camera(true)
    _spawn_racers() # Frozen showroom preview gives the menu moving-world context.
    best_ghost = BestGhost.new()
    best_ghost.name = "BestRunGhost"
    add_child(best_ghost)
    _apply_graphics_quality()
    ui.show_menu()

func _make_environment() -> void:
    var env_node = WorldEnvironment.new()
    env_node.name = "StudioEnvironment"
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#16191e")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#d9e4e6")
    env.ambient_light_energy = 0.46
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color("#22272d")
    env.fog_density = 0.005
    env.glow_enabled = true
    env.glow_intensity = 0.24
    env_node.environment = env
    world_environment = env
    add_child(env_node)

    var sun = DirectionalLight3D.new()
    sun.name = "LargeSoftbox"
    sun.rotation_degrees = Vector3(-48, -28, -8)
    sun.light_color = Color("#ffecd5")
    sun.light_energy = 1.13
    sun.light_angular_distance = 0.55
    sun.shadow_enabled = true
    primary_light = sun
    sun.directional_shadow_max_distance = 75.0
    add_child(sun)

    var fill = DirectionalLight3D.new()
    fill.name = "CoolFill"
    fill.rotation_degrees = Vector3(-30, 150, 0)
    fill.light_color = Color("#cae4f4")
    fill.light_energy = 0.38
    add_child(fill)

func _save_visual_preferences() -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://marble_settings.cfg")
    cfg.set_value("video","quality",graphics_setting)
    cfg.set_value("video","fps",show_fps)
    cfg.save("user://marble_settings.cfg")

func set_graphics_quality(next_quality: int) -> void:
    graphics_setting = clampi(next_quality,0,3)
    _reset_auto_quality_sampling()
    graphics_quality = 1 if graphics_setting == 3 else graphics_setting
    _apply_graphics_quality()
    _save_visual_preferences()

func graphics_mode_label() -> String:
    if graphics_setting == 3:
        return "AUTO (%s)" % QUALITY_NAMES[graphics_quality]
    return QUALITY_NAMES[graphics_setting]

func _reset_auto_quality_sampling() -> void:
    auto_fps_seconds = 0.0
    auto_fps_accum = 0.0
    auto_slow_seconds = 0.0
    auto_fast_seconds = 0.0

func _auto_quality_sample(fps: float, seconds: float) -> void:
    # Measured FPS is sampled once per second on real Android devices. Hysteresis
    # prevents flickering between profiles. Rendering is never touched each frame.
    if graphics_setting != 3 or seconds <= 0.0 or not is_finite(fps):
        return
    if fps < 39.0:
        auto_slow_seconds += seconds
        auto_fast_seconds = 0.0
    elif fps > 55.0:
        auto_fast_seconds += seconds
        auto_slow_seconds = 0.0
    else:
        auto_fast_seconds = 0.0
        auto_slow_seconds = 0.0
    if auto_slow_seconds >= 12.0 and graphics_quality > 0:
        graphics_quality -= 1
        _reset_auto_quality_sampling()
        _apply_graphics_quality()
    elif auto_fast_seconds >= 28.0 and graphics_quality < 1:
        graphics_quality += 1
        _reset_auto_quality_sampling()
        _apply_graphics_quality()
    # AUTO will not enable Ultra automatically: prioritize stable frame pacing.

func _tick_auto_quality(delta: float) -> void:
    if graphics_setting != 3 or not OS.has_feature("mobile") or race_state != "RACING":
        return
    auto_fps_seconds += delta
    auto_fps_accum += delta * Engine.get_frames_per_second()
    if auto_fps_seconds >= 1.0:
        var measured: float = auto_fps_accum / auto_fps_seconds
        var window: float = auto_fps_seconds
        auto_fps_seconds = 0.0
        auto_fps_accum = 0.0
        _auto_quality_sample(measured,window)

func toggle_fps_overlay() -> bool:
    show_fps = not show_fps
    if is_instance_valid(ui) and is_instance_valid(ui.fps_label):
        ui.fps_label.get_parent().visible = show_fps
        if is_instance_valid(ui.performance_label):
            ui.performance_label.get_parent().visible = show_fps
    if show_fps and performance_budget != null:
        performance_budget.reset()
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
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.set_quality(graphics_quality)
    if is_instance_valid(course_sculptures):
        course_sculptures.set_quality(graphics_quality)
    if is_instance_valid(race_items):
        race_items.set_quality(graphics_quality)
    if is_instance_valid(track_surface):
        track_surface.set_detail_quality(graphics_quality)
    if is_instance_valid(board):
        var dressing := board.get_node_or_null("ModularBrassAndSilkDressing")
        if is_instance_valid(dressing):
            dressing.visible = graphics_quality > 0
        var floor_details := board.get_node_or_null("StudioTrackGuides")
        if is_instance_valid(floor_details):
            floor_details.set_quality(graphics_quality)
        var signature := board.get_node_or_null("TrackSignatureLandmarks")
        if is_instance_valid(signature):
            signature.set_quality(graphics_quality)
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
    audio.set_track_theme(selected_track)
    _apply_graphics_quality()
    return true

func upcoming_hazard(at_z: float) -> Dictionary:
    # Cached tiny index; UI polls at 9 Hz. Only genuine physical rail gates.
    var nearest := 25.0
    var notice: Dictionary = {}
    for hazard in hazard_beacons:
        var distance: float = at_z - float(hazard["z"])
        if distance >= -1.0 and distance < nearest:
            nearest = distance
            notice = {"side":hazard["side"],"distance":maxi(0,int(round(distance)))}
    if is_instance_valid(race_director):
        var event: Dictionary = race_director.event_ahead(at_z)
        if not event.is_empty() and float(event["distance"]) < nearest:
            notice = event
    return notice

func current_timeout() -> float:
    return RACE_TIMEOUT + selected_track * 24.0

func track_title() -> String:
    return TRACK_NAMES[selected_track]

func height_at(z: float) -> float:
    return TrackPath.height_at(z,selected_track)

func track_grade_at(z: float) -> float:
    return TrackPath.grade_at(z,selected_track)

func track_center_at(z: float) -> float:
    # Identical centerline across local clients, bots and authoritative server.
    return TrackPath.center_at(z,selected_track)

func recovery_center_at(location: Vector3) -> float:
    if is_instance_valid(shortcut_route):
        return shortcut_route.recovery_center_at(location)
    return track_center_at(location.z)

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
        holder.rotation.x = -atan(track_grade_at(location.z))
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
        obstacle_finish.register_post(body.global_position,radius,tall,color)
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
        remove_child(board)
        board.queue_free()
    hazard_beacons.clear()
    workshop_lamps.clear()
    board = Node3D.new()
    board.name = "HandcraftedWoodenCourse"
    board.set_meta("track_index",selected_track)
    built_variation = race_variation
    add_child(board)
    moving_obstacles.clear()
    TrackUniverses.apply_atmosphere(world_environment,primary_light,selected_track)
    obstacle_finish = ObstacleFinish.new()
    obstacle_finish.name = "PremiumObstacleFinishes"
    board.add_child(obstacle_finish)
    track_surface = TrackSurface.new()
    track_surface.name = "InstancedTrackSurface"
    board.add_child(track_surface)
    for section in range(SEGMENTS):
        var center_z = 8.0 - float(section) * SEGMENT_LENGTH
        var section_node = Node3D.new()
        section_node.name = "Course_%02d" % section
        section_node.position.x = track_center_at(center_z)
        board.add_child(section_node)
        for lane in range(10):
            var x := (float(lane) - 4.5) * 1.34
            var material_index := (lane + section * 3) % WOOD_COLORS.size()
            var shade: Color = _themed_wood(WOOD_COLORS[material_index])
            var plank_at := Vector3(x,height_at(center_z)-0.34,center_z)
            # Render-only planks share GPU draw calls by material. Each keeps
            # the exact original independent tilted BoxShape3D collider.
            _box(section_node,plank_at,
                Vector3(1.315,0.65,SEGMENT_LENGTH+0.08),_wood_mat(shade),true,true,false)
            track_surface.register_plank(plank_at+section_node.position,material_index,track_grade_at(center_z))
            for j in range(2):
                var z: float = center_z+(float(j)-0.5)*4.4
                track_surface.register_groove(Vector3(x-0.34+(j%2)*0.31+section_node.position.x,height_at(z)+0.005,z),track_grade_at(z))
        for side in [-1,1]:
            for rail_piece in range(3):
                # Physical fork and merger through two full-width portals.
                if ShortcutRoute.opens_rail(section,side,rail_piece,selected_track):
                    section_node.set_meta("shortcut_portal",side)
                    continue
                var z: float = center_z+(rail_piece-1)*4.02
                var color_idx := (section+rail_piece+(0 if side==1 else 3))%BARRIER_COLORS.size()
                var pos := Vector3(side*6.84,height_at(z)+0.58,z)
                _box(section_node,pos,Vector3(0.57,1.26,4.04),
                    _lacquer(BARRIER_COLORS[color_idx]),true,true,false)
                track_surface.register_rail(pos+section_node.position,color_idx,track_grade_at(z))
        if section in [3, 9, 14]:
            _terrain_ramp(section_node,center_z,section)
        if section > 0 and section < SEGMENTS - 3:
            # Edge-specific baffles eliminate the dominant strategy of riding
            # permanently against either rail. Passages remain physically open.
            _edge_baffles(section_node,center_z,section)
            var layout := _obstacle_layout(section)
            if layout == 1:
                _pegs(section_node, center_z, section)
            elif layout == 2:
                _gate_with_posts(section_node, center_z, section)
            else:
                _slalom(section_node, center_z, section)

    _connect_winding_sections()
    # Real banked line options, plus collision-free landmark arches. The
    # central rolling corridor is still open and both artistic batches
    # and actual collision pieces share exactly the same transforms.
    course_sculptures = CourseSculptures.new()
    board.add_child(course_sculptures)
    course_sculptures.setup(self,selected_track,built_variation)
    race_director = RaceDirector.new()
    board.add_child(race_director)
    race_director.setup(self,selected_track,built_variation)
    shortcut_route = ShortcutRoute.new()
    board.add_child(shortcut_route)
    shortcut_route.setup(self,selected_track)
    obstacle_finish.rebuild()
    var woods: Array = []
    for color in WOOD_COLORS:
        woods.append(_wood_mat(_themed_wood(color)))
    var barriers: Array = []
    for color in BARRIER_COLORS:
        barriers.append(_lacquer(color))
    track_surface.finish(woods,barriers,_mat(Color("#82563d")))
    _start_arch()
    _finish_arch()
    _checkpoint_arches()
    _decorations()
    _showroom()
    var universe := TrackUniverses.new()
    universe.setup(selected_track,self)
    board.add_child(universe)
    # Three batched hero silhouettes and ambient atmosphere for each biome.
    # These are off-track, purely cosmetic and share no live physics logic.
    var signature := BiomeSignature.new()
    signature.setup(self,selected_track,built_variation)
    board.add_child(signature)
    race_items = RaceItems.new()
    race_items.name = "RareArcadePickups"
    board.add_child(race_items)
    race_items.setup(self,selected_track,race_variation)
    course_mechanics = CourseMechanics.new()
    course_mechanics.name = "CourseSpecificArcadeMechanics"
    board.add_child(course_mechanics)
    course_mechanics.setup(self,selected_track,built_variation)
    # Springy edge posts keep their physical colliders on every quality tier.
    # Six post arts / twelve light rings render in just two GPU batches.
    arcade_bumpers = ArcadeBumpers.new()
    board.add_child(arcade_bumpers)
    arcade_bumpers.setup(self,selected_track,built_variation)
    arcade_bumpers.set_quality(graphics_quality)
    var cosmetic = TrackFX.new()
    cosmetic.name = "PolishedToyDetails"
    board.add_child(cosmetic)
    var dressing := CourseDressing.new()
    dressing.name = "ModularBrassAndSilkDressing"
    board.add_child(dressing)
    var polish := StudioPolish.new()
    polish.name = "StudioTrackGuides"
    board.add_child(polish)

func _connect_winding_sections() -> void:
    # Overlapping ground seams and angled side guards join adjacent offset
    # physical modules: no open edge/gap at a directional change.
    for section in range(SEGMENTS-1):
        var seam_z: float = TrackPath.section_seam_z(section)
        var before: float = TrackPath.section_center(section,selected_track)
        var after: float = TrackPath.section_center(section+1,selected_track)
        var drift: float = after-before
        var mid: float = (before+after)*0.5
        var seam := _box(board,Vector3(mid,height_at(seam_z)-0.34,seam_z),
            Vector3(13.2+absf(drift),0.66,2.8),_wood_mat(_themed_wood(WOOD_COLORS[section%WOOD_COLORS.size()])),true,true,false)
        seam.name = "ContinuousBendFloor_%02d" % section
        for side in [-1.0,1.0]:
            var rail := _box(board,Vector3(mid+side*6.84,height_at(seam_z)+0.58,seam_z),
                Vector3(0.57,1.26,sqrt(3.6*3.6+drift*drift)+0.28),
                _lacquer(TRACK_COLORS[selected_track]),true,false)
            rail.name = "AngledBendGuard_%02d_%s" % [section,"L" if side < 0.0 else "R"]
            rail.rotation.y = atan2(-drift,3.6)

func _obstacle_layout(section: int) -> int:
    # 0: flowing slalom; 1: peg garden; 2: kinetic gates.
    # Course-specific frequency changes the actual playable obstacle rhythm.
    if selected_track == 0:
        # The original balanced 1:1:1 rhythm also guarantees at least five
        # genuinely moving paddles/hammers and enough peg obstacles.
        return (section+race_variation)%3
    if selected_track == 1:
        var glacier := (section*2+race_variation)%5
        return 2 if glacier in [0,2,4] else (0 if glacier == 1 else 1)
    var forge := (section+race_variation)%4
    return 2 if forge in [0,1] else (1 if forge == 2 else 0)

func _themed_wood(base: Color) -> Color:
    if selected_track == 1:
        return base.lerp(Color("#83b6c8"),0.34)
    if selected_track == 2:
        return base.lerp(Color("#aa6353"),0.29)
    return base

func _terrain_ramp(parent: Node3D, center_z: float, section: int) -> void:
    # Short, low physical crests alter suspension/rolling lines without
    # closing the entire lane or trapping the 40-marble pack.
    if selected_track == 0 and section != 9:
        return
    var lane := -2.2 if (section+selected_track)%2 == 0 else 2.2
    var z := center_z+1.5
    var ramp := _box(parent,Vector3(lane,height_at(z)+0.12,z),
        Vector3(3.55,0.22,2.35),_lacquer(TRACK_COLORS[selected_track].lightened(0.20)),true,true)
    ramp.name = "RideableCrest_%02d" % section
    ramp.rotation.x += -0.09 if selected_track == 1 else -0.16

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
        hazard_beacons.append({"z":z,"side":"LEFT" if side < 0.0 else "RIGHT"})
        obstacle_finish.register_block(node.global_transform,size,material_color)
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
        obstacle_finish.register_block(gate.global_transform,wide,tint)

func _pegs(parent: Node3D, center_z: float, n: int) -> void:
    # Checkerboard of rounded vertical posts, with traversable gaps.
    for row in range(3):
        var z = center_z + 3.0 - row * 3.2
        for c in range(5):
            # Each rematch shifts the real peg corridors, not just their paint.
            # Keep the outermost posts inside the 6.5m half-width and never
            # close a complete row: spacing remains 2.2m for 0.62m posts.
            var shift := sin(float(n*9+row*3+race_variation*7))*0.23
            shift += (float(race_variation)-1.0)*0.19*(1.0 if row%2==0 else -1.0)
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
            block.name = "GatePost_%02d_%02d_%02d" % [n,row,i]
            obstacle_finish.register_block(block.global_transform,size,gate_color)
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
        # The alternating barrier rhythm changes between layouts, but the
        # 3.4m obstacle always leaves a full-width outside escape lane.
        var side := -1.0 if (i+race_variation)%2==0 else 1.0
        var x: float = side*(3.5+0.20*sin(float(n*3+i)))
        var slalom_color: Color = BARRIER_COLORS[(n+i)%6]
        var size := Vector3(3.4,0.75,1.05)
        var block := _box(parent, Vector3(x,height_at(z)+0.36,z),
            size,_lacquer(slalom_color),true,true)
        block.name = "SlalomBlock_%02d_%02d" % [n,i]
        obstacle_finish.register_block(block.global_transform,size,slalom_color)
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
        _box(board, Vector3(x+track_center_at(z), height_at(z)+1.7, z), Vector3(0.52, 3.2, 0.45),
            _mat(Color("#c84d40")), false)
    _box(board, Vector3(track_center_at(z), height_at(z)+3.1, z),
        Vector3(12.4, 0.63, 0.52), _mat(Color("#ca5645")), false)
    _floating_sign("START · 40 MARBLES", Vector3(track_center_at(z), height_at(z)+3.64, z))

func _finish_arch() -> void:
    # Visual finish stripe and physical finish detector coincide.
    var z = FINISH_Z
    for x in [-6.0, 6.0]:
        _box(board, Vector3(x+track_center_at(z), height_at(z)+1.35, z),
            Vector3(0.48, 2.8, 0.45), _mat(Color("#eee1bd")), false)
    _box(board, Vector3(track_center_at(z), height_at(z)+2.62, z),
        Vector3(12.6, 0.52, 0.55), _mat(Color("#f3d779")), false)
    _floating_sign("FINISH", Vector3(track_center_at(z), height_at(z)+3.12, z))
    # Checkered line visible on the wooden surface.
    for i in range(12):
        _box(board, Vector3(track_center_at(z)-5.75 + i*1.04, height_at(z)+0.034, z),
            Vector3(1.02, 0.045, 0.63), _mat(Color("#f2e5d0") if i%2==0 else Color("#342a28")), false)

func _checkpoint_arches() -> void:
    for n in [4,9,14]:
        var z = 8.0 - float(n) * SEGMENT_LENGTH
        var y = height_at(z)
        for side in [-1.0,1.0]:
            _box(board,Vector3(side*6.28+track_center_at(z),y+2.4,z),Vector3(0.21,4.7,0.28),
                _mat(Color("#e6c488"),0.3,0.28),false)
        _box(board,Vector3(track_center_at(z),y+4.65,z),Vector3(12.7,0.32,0.38),
            _mat(Color("#dfb66c"),0.35,0.2),false)
        _floating_sign("CHECKPOINT %d" % int(n/5+1),Vector3(track_center_at(z),y+5.22,z))

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
    # Cleaner studio: keep real structural supports, omit the bright unrelated
    # carton towers that previously obscured obstacles in the distance.
    for k in range(12):
        var z = 5.0 - k * 17.0
        for side in [-1,1]:
            var x = side * 5.0
            _box(board, Vector3(x+track_center_at(z),height_at(z)-2.6,z),
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
                Vector3(1.3,19.0,SEGMENT_LENGTH+0.05),_mat(Color("#37353a")),false)
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
            # One restrained branded trophy block per shelf (rather than
            # two random bright boxes) reduces clutter and draw calls.
            var trophy_color: Color = TRACK_COLORS[selected_track].darkened(0.34)
            _box(board,Vector3(x-side*0.25,height_at(z)+4.5,z),
                Vector3(0.80,0.85,1.15),_mat(trophy_color,0.37,0.22),false)
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
    # Deep charcoal overhead beam frames the miniature track without glare.
    _box(board,Vector3(0,14,-80),Vector3(38,0.8,192),_mat(Color("#343339")),false)

func _spawn_racers() -> void:
    for m in racers:
        if is_instance_valid(m):
            remove_child(m)
            m.queue_free()
    racers.clear()
    racer_finish_order.clear()
    player_marker = null
    player = null
    var player_slot: int = net.local_slot if net.match_running else MARBLE_COUNT-1
    for i in range(MARBLE_COUNT):
        var row = i / 8
        var col = (i * 5 + 3) % 8
        var z = 12.2 - row * 1.12
        var x = (col - 3.5) * 1.36
        var p = Vector3(x+track_center_at(z), height_at(z) + 0.68, z)
        var m = Racer.new()
        var is_you = i == player_slot
        m.setup(i, is_you, p, selected_perk)
        m.course_owner = self
        add_child(m)
        # Cosmetic mastery rewards are entirely local to solo races. Public
        # network race marbles keep the original uniform player material.
        if is_you and not net.is_active():
            m.apply_player_style(career.selected_style)
        m.freeze = true
        racers.append(m)
        if is_you:
            player = m
            m.contact_monitor = true
            m.max_contacts_reported = 6
            _add_player_marker(m)
            if not net.is_active() and is_instance_valid(player_marker):
                player_marker.modulate = Racer.PLAYER_STYLE_BASE[career.selected_style].lightened(0.14)
            _add_player_trail(m)
            PremiumSkinVisuals.apply(self)

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
    if not net.is_active() and career.league_tier() >= 1:
        tag.text += "  •  " + career.league_name()
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

func _refresh_premium_skin() -> void:
    if is_instance_valid(player):
        PremiumSkinVisuals.apply(self)
    if is_instance_valid(ui):
        ui.refresh_skin_shop()

func _camera_bump(body: Node) -> void:
    if not is_instance_valid(player) or race_state != "RACING":
        return
    # Rolling past a plank at 18 m/s is not an 18 m/s crash.
    # Reuse the actual local contact event for the matching spring post
    # even when general camera shake is cooling down. The post owns its
    # own short rearm window and never changes the authoritative physics.
    var intensity: float = RaceFeedback.impact_intensity(
        player.linear_velocity,body)
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.notify_contact(body,intensity)
    if intensity < 0.17 or feedback_cooldown > 0.0:
        return
    camera_shake = minf(0.14,camera_shake+RaceFeedback.shake_strength(intensity))
    obstacle_notice = 0.46 if intensity > 0.45 else 0.22
    feedback_cooldown = RaceFeedback.feedback_interval(intensity)

func start_race(perk_name: String) -> void:
    selected_perk = perk_name
    if not net.is_active():
        career.begin()
    result_saved = false
    last_result = {}
    # Alternating geometry order on repeat attempts avoids an identical course
    # without changing the course identity or difficulty.
    if not is_instance_valid(board) or race_variation != built_variation or int(board.get_meta("track_index",-1)) != selected_track:
        _make_course()
        audio.bind_mechanisms(moving_obstacles)
        audio.set_track_theme(selected_track)
        _apply_graphics_quality()
    race_variation = (race_variation+1)%3
    race_state = "COUNTDOWN"
    race_time = 0.0
    countdown = 3.3
    result_delay = 0.0
    finish_announced = false
    last_checkpoint = -1
    checkpoint_splits.clear()
    course_flash = 0.0
    steer = 0.0
    steer_target = 0.0
    boosting = false
    boost_energy = 1.0 # A fresh race always has a full, fair turbo meter.
    if slipstream != null:
        slipstream.reset_round()
    draft_cue_cooldown = 0.0
    cam_mode = 0
    camera_shake = 0.0
    camera.set_meta("previous_jitter",Vector3.ZERO)
    if race_moments != null:
        race_moments.reset_round()
    if performance_budget != null:
        performance_budget.reset()
    _spawn_racers()
    if is_instance_valid(race_items):
        race_items.reset_round()
    if is_instance_valid(course_mechanics):
        course_mechanics.reset_round()
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.reset_pulses()
    if is_instance_valid(race_director):
        race_director.reset_round()
    if is_instance_valid(shortcut_route):
        shortcut_route.reset_round()
    best_ghost.begin(selected_track,built_variation,selected_perk,not net.is_active())
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
    if slipstream != null:
        slipstream.reset_round()
    draft_cue_cooldown = 0.0
    if is_instance_valid(best_ghost):
        best_ghost.stop()
    for m in racers:
        if is_instance_valid(m):
            remove_child(m)
            m.queue_free()
    racers.clear()
    player_marker = null
    player = null
    if is_instance_valid(contact_shadows):
        contact_shadows.clear_racers()
    race_state = "MENU"
    audio.menu_music()
    ui.show_menu()

func _process(delta: float) -> void:
    _tick_auto_quality(delta)
    # Expiry works in menus, races and following Android resume.
    if is_instance_valid(skins):
        skins.remaining()
    if race_state == "RACING" and is_instance_valid(arcade_bumpers):
        arcade_bumpers.advance_visuals(delta)
    if show_fps and race_state == "RACING" and performance_budget != null:
        performance_budget.tick(delta)
    world_time += delta
    feedback_cooldown = maxf(0.0,feedback_cooldown-delta)
    obstacle_notice = maxf(0.0,obstacle_notice-delta)
    lamp_refresh -= delta
    if lamp_refresh <= 0.0:
        lamp_refresh = 0.25
        var view_z := player.global_position.z if is_instance_valid(player) and race_state != "MENU" else -3.0
        for lamp in workshop_lamps:
            if is_instance_valid(lamp) and lamp.is_inside_tree():
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
            if not net.is_client():
                for m in racers:
                    m.freeze = false
                    m.sleeping = false
            ui.show_countdown("GO!")
            audio.tone("start")
    elif race_state == "RACING":
        race_time += delta
        if is_instance_valid(best_ghost) and is_instance_valid(player):
            best_ghost.tick(race_time,player.global_position,graphics_quality)
        if race_time > 1.0:
            ui.hide_countdown()
        if is_instance_valid(trail) and is_instance_valid(player):
            audio.update_progress(clampf(-player.position.z/absf(FINISH_Z),0.0,1.0))
            trail.emitting = graphics_quality > 0 and player.linear_velocity.length() > 4.0
            trail.initial_velocity_max = 2.6 if boosting else 0.75
            trail.color = PremiumSkinVisuals.trail_tint(self,boosting)
            var cp := -1
            if player.position.z < -46.0:
                cp = 0
            if player.position.z < -106.0:
                cp = 1
            if player.position.z < -166.0:
                cp = 2
            # Award split times only when the marble actually passes a sector
            # within the rolling surface; falling out of bounds is not progress.
            if cp > last_checkpoint and absf(player.global_position.x-track_center_at(player.global_position.z)) < 6.75 and (
                player.global_position.y > height_at(player.global_position.z)-0.3
                and player.global_position.y < height_at(player.global_position.z)+9.0):
                # A missing checkpoint invalidates split records: never invent a
                # zero-second sector when a marble skips a marker.
                if cp != last_checkpoint+1:
                    checkpoint_splits.clear()
                    last_checkpoint = cp
                else:
                    var sector := cp
                    var previous: float = 0.0 if checkpoint_splits.is_empty() else (
                        checkpoint_splits[checkpoint_splits.size()-1])
                    # Capture cumulative times; calculate each true sector duration.
                    var duration: float = maxf(0.01,race_time-previous)
                    checkpoint_splits.append(race_time)
                    var prior_best: float = career.best_sector(selected_track,sector)
                    ui.show_checkpoint(sector+1,duration,prior_best)
                    audio.tone("checkpoint")
                    var cosmetics := board.get_node_or_null("PolishedToyDetails")
                    if is_instance_valid(cosmetics):
                        cosmetics.pulse_checkpoint(sector)
                    _burst(player.global_position, false)
                    last_checkpoint = cp
        # Only an actual offline human owns this meter. A disconnected
        # replica or dedicated server must never regenerate local boost
        # simply because match_running changed to false.
        if net.role == "offline":
            if boosting:
                boost_energy = max(0.0, boost_energy - delta * 0.26)
                if boost_energy <= 0.0:
                    boosting = false
            else:
                # Sustained solo drafting earns a small extra charge without
                # modifying online authority or the human-only rare items.
                var draft_charge: float = slipstream.strength*Slipstream.RECOVERY_PER_SECOND if (
                    slipstream != null and not net.is_active()) else 0.0
                boost_energy = minf(1.0,boost_energy+delta*(0.08+draft_charge))
        if not net.is_client():
            var ended: bool = net.all_participants_finished() if net.is_host() else (
                is_instance_valid(player) and (player.finished or player.eliminated))
            if ended:
                result_delay += delta
                if result_delay > 1.5 and not finish_announced:
                    finish_announced = true
                    _end_race()
            elif race_time >= current_timeout():
                _end_race()
    course_flash = maxf(0.0, course_flash - delta)
    _update_camera(delta)
    if race_state == "RACING" or race_state == "COUNTDOWN":
        if race_moments != null:
            race_moments.tick(delta)
        ui.update_hud()
    # Audio tension reads the local HUD's existing 10Hz physics snapshot.
    # No extra 40-racer scans, AI updates or online rewards.
    if is_instance_valid(audio):
        audio.set_pack_pressure(race_moments.pack_pressure if (
            race_state == "RACING" and race_moments != null and
            net.role != "server") else 0.0)

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
    if is_instance_valid(race_director) and race_state == "RACING":
        # All clients animate the same scripted hazards; only authority
        # awards gameplay physics when a marble actually makes a near-miss.
        race_director.animate(race_time)
    if race_state != "RACING" or net.is_client():
        return
    if is_instance_valid(race_items):
        race_items.tick(delta,racers,net)
    if is_instance_valid(course_mechanics):
        course_mechanics.tick(delta,racers,net)
    if is_instance_valid(shortcut_route):
        shortcut_route.tick(delta,racers,net)
    if is_instance_valid(race_director):
        race_director.tick(racers,net)
    draft_cue_cooldown = maxf(0.0,draft_cue_cooldown-delta)
    # Drafting rewards actually following the same-elevation opponent.
    # Scan at 7Hz; apply only a bounded physical force on the authoritative
    # solo simulation. Online peers never receive untrusted local boosts.
    if slipstream != null and not net.is_active() and is_instance_valid(player) and (
        not player.freeze and not player.finished and not player.eliminated):
        var before_draft: float = slipstream.strength
        var draft: float = slipstream.tick(delta,player,racers)
        if before_draft < 0.55 and draft >= 0.55 and draft_cue_cooldown <= 0.0:
            # One soft sound and short callout at lock-on, not every frame.
            # Neither changes physics nor hides approaching obstacles.
            draft_cue_cooldown = 4.5
            audio.race_moment("slipstream")
            ui.show_race_moment("SLIPSTREAM!",0.72)
        if draft > 0.001:
            player.apply_central_force(
                Vector3(0.0,0.0,-Slipstream.FORWARD_FORCE*draft)*player.mass)
    for m in racers:
        if not is_instance_valid(m):
            continue
        var remote_input: Vector2 = net.input_for_slot(m.racer_id) if net.is_host() and m.network_controlled else Vector2.ZERO
        # Online participants always use server-validated commands, including slot 39.
        var axis: float = remote_input.x if m.network_controlled else (steer if m.is_player and not net.is_host() else 0.0)
        var turbo: bool = remote_input.y>0.5 if m.network_controlled else (boosting and boost_energy>0.0 and m.is_player and not net.is_host())
        m.drive(delta,race_time,axis,turbo)
        if not m.finished and not m.eliminated and m.position.z < FINISH_Z:
            m.finished = true
            m.finish_time = race_time
            m.freeze = true
            # A finished frozen sphere must not become a permanent obstacle
            # at the timing stripe. Keep it for ranking, disable its contacts.
            m.set_deferred("collision_layer",0)
            m.set_deferred("collision_mask",0)
            racer_finish_order.append(m.display_name)
            if m == player and not net.is_active() and race_moments != null:
                race_moments.on_finish()
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
        camera_shake = 0.0
        camera.set_meta("previous_jitter",Vector3.ZERO)
        _position_intro_camera(force)
        return
    # Use the centerline ahead so the racer can see approaching turns.
    # Pure math; multiplayer does not need camera replication.
    var ahead_x: float = track_center_at(player.global_position.z-12.0)
    var next_gate: Dictionary = upcoming_hazard(player.global_position.z)
    var distance: float = float(next_gate.get("distance",-1.0))
    var pose: Dictionary = RaceFeedback.camera_pose(
        player.global_position,player.linear_velocity,
        ahead_x,cam_mode,boosting,distance,
        race_moments != null and race_state == "RACING" and
        race_moments.side_by_side_active)
    var desired: Vector3 = pose["position"]
    var focus: Vector3 = pose["focus"]
    # Match the camera to the real 3D grade, not the old flat slope.
    # Smooth interpolation remains unchanged; no per-frame raycasts.
    focus = RaceFeedback.terrain_safe_focus(focus,height_at(focus.z))
    desired = RaceFeedback.terrain_safe_camera(desired,height_at(desired.z))
    var previous_jitter: Vector3 = camera.get_meta(
        "previous_jitter",Vector3.ZERO)
    var follow_rate: float = lerpf(4.5,6.0,float(pose["pace"]))
    var step: float = RaceFeedback.smooth_factor(delta,follow_rate)
    var base: Vector3 = camera.global_position-previous_jitter
    camera.global_position = desired if force else base.lerp(desired,step)
    var focus_step: float = RaceFeedback.smooth_factor(delta,7.0)
    camera_lookahead = focus if force else camera_lookahead.lerp(
        focus,focus_step)
    camera_shake *= exp(-clampf(delta,0.0,0.12)*9.5)
    var jitter := Vector3(sin(world_time*52.0),
        cos(world_time*47.0),0.0)*camera_shake
    camera.global_position += jitter
    camera.set_meta("previous_jitter",jitter)
    camera.look_at(camera_lookahead,Vector3.UP)
    camera.fov = lerpf(camera.fov,float(pose["fov"]),
        RaceFeedback.smooth_factor(delta,4.4))

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
    n.amount = [32,68,100][graphics_quality] if finale else [12,24,45][graphics_quality]
    n.lifetime = (1.3 if graphics_quality == 0 else 1.9) if finale else 0.9
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
        var completed: bool = is_instance_valid(player) and player.finished
        var ghost_record: bool = false
        if is_instance_valid(best_ghost):
            ghost_record = best_ghost.finish(
                player.finish_time if completed else race_time,completed)
        if net.is_active():
            # Network races have physical results but never rewrite solo career.
            last_result = {"finished":completed,"stars":0,"record":false,"unlocked":false}
        else:
            last_result = career.complete(selected_track,player_rank(),
                player.finish_time if completed else race_time,completed)
        var durations: Array[float] = []
        var previous_split := 0.0
        for elapsed in checkpoint_splits:
            durations.append(maxf(0.01,elapsed-previous_split))
            previous_split = elapsed
        # Fourth and final sector is measured at the actual finish crossing,
        # not at the later presentation of the results screen.
        if completed and checkpoint_splits.size() == 3:
            var finish_at: float = player.finish_time
            if is_finite(finish_at) and finish_at > previous_split:
                durations.append(finish_at-previous_split)
        last_result["ghost_record"] = ghost_record
        last_result["clean_passes"] = race_director.clean_pass_count(player.racer_id) if (
            is_instance_valid(race_director) and is_instance_valid(player)) else 0
        var real_precision: int = race_director.precision_pass_count(
            player.racer_id) if is_instance_valid(race_director) and (
            is_instance_valid(player)) else 0
        # Server owns all physical skill rewards, but only the authenticated
        # SOLO career may persist new medals/reputation. Remote clients
        # cannot submit their own precision count as a result payload.
        last_result["precision_passes"] = real_precision if not net.is_active() else 0
        # Presentation-only: do not feed local pass counters into career
        # rewards or anything that can be forged by an online client.
        last_result["overtakes"] = race_moments.unique_overtakes if (
            not net.is_active() and race_moments != null) else 0
        last_result["sector_times"] = durations
        last_result["sector_records"] = career.record_sectors(selected_track,durations) if completed and not net.is_active() else [false,false,false,false]
        # An offline, genuinely finished race is the only source of mastery.
        # Client snapshots and server online races must never modify career.
        if not net.is_active():
            var clean_count: int = race_director.clean_pass_count(player.racer_id) if (
                is_instance_valid(race_director) and is_instance_valid(player)) else 0
            var used_bypass: bool = is_instance_valid(shortcut_route) and (
                is_instance_valid(player) and
                shortcut_route.triggered.has(player.racer_id))
            var earned: Dictionary = career.complete_mastery(
                selected_track,completed,clean_count,used_bypass)
            last_result["mastery_new"] = earned["new_goals"]
            last_result["mastery_styles"] = earned["new_styles"]
            last_result["mastery_track"] = earned["track_count"]
            last_result["mastery_total"] = earned["count"]
            var precision: Dictionary = career.award_precision(
                selected_track,real_precision,completed)
            last_result["precision_medal"] = precision["medal"]
            last_result["precision_best"] = precision["best"]
            last_result["precision_new_record"] = precision["new_record"]
            last_result["precision_perfect_runs"] = precision["perfect_runs"]
            var league: Dictionary = career.award_league(
                selected_track,player_rank(),completed,clean_count,
                used_bypass,real_precision)
            last_result["league_earned"] = league["earned"]
            last_result["league_promoted"] = league["promoted"]
            last_result["league_tier"] = league["tier"]
            last_result["league_score"] = league["score"]
            last_result["league_next"] = league["next"]
    if net.is_host():
        net.on_host_finish()
    audio.tone("finish")
    if is_instance_valid(player) and player.finished:
        audio.finish_fanfare()
    audio.menu_music()
    ui.show_results(player_rank(), race_time, get_rankings())
