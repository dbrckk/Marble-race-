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
const RivalRenderBatch = preload("res://scripts/rival_render_batch.gd")
const LACQUER_SHADER = preload("res://shaders/lacquer.gdshader")
const LACQUER_MICRO = preload("res://assets/textures/lacquer_micro.png")
const MechanismArt = preload("res://scripts/mechanism_art.gd")
const CourseDressing = preload("res://scripts/course_dressing.gd")
const ObstacleFinish = preload("res://scripts/obstacle_finish.gd")
const OpeningObstacles = preload("res://scripts/opening_obstacles.gd")
const TrackSurface = preload("res://scripts/track_surface.gd")
const StartGate = preload("res://scripts/start_gate.gd")
const FinishLine = preload("res://scripts/finish_line.gd")
const TrackPath = preload("res://scripts/track_path.gd")
const PracticeTiming = preload("res://scripts/practice_timing.gd")
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
const AirtimeDirector = preload("res://scripts/airtime_director.gd")
const JumpGuides = preload("res://scripts/jump_guides.gd")

const MARBLE_COUNT := 40
const MARBLE_DETAIL_INTERVAL := 0.125
const MARBLE_DETAIL_NEAR_DISTANCE_SQUARED := 81.0
const SLOPE := 0.085
const SEGMENT_LENGTH := 12.0
const GLACIER_EXIT_REACH := 6.0
const GLACIER_EXIT_PREVIEW_REACH := 9.0
const GLACIER_EXIT_WARNING_SECONDS := 0.80
const FORGE_PISTON_EXIT_REACH := 12.0
const FORGE_PISTON_EXIT_WARNING_SECONDS := 0.90
const PASSING_TRAFFIC_CLEARANCE := Racer.RADIUS*2.0+0.16
const WOODWORKS_RETURN_DEPTH := 8.0
const WOODWORKS_RETURN_WARNING_SECONDS := 0.90
const SEGMENTS := 18
const FINAL_OBSTACLE_SECTION := SEGMENTS-4
const FINAL_OBSTACLE_Z := 8.0-FINAL_OBSTACLE_SECTION*SEGMENT_LENGTH
const FINISH_Z := -185.0
const PLANK_COUNT := 10
const PLANK_SPACING := 1.34
const FINISH_HALF_WIDTH := ((PLANK_COUNT-1)*PLANK_SPACING+TrackSurface.PLANK.x)*0.5
const FINISH_AIR_CLEARANCE := 8.0
const CHECKPOINT_Z := [-46.0,-106.0,-166.0]
const RACE_TIMEOUT := 155.0
const TRACK_NAMES := ["WOODWORKS","SWITCHBACK","GAUNTLET"]
const SHOWROOM_ROOF_HEIGHT := 14.0
const SHOWROOM_ROOF_THICKNESS := 0.8
const BALANCED_SHADOW_RANGES := [36.0,47.0,33.0]
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
var jump_guides: Node3D
var ui: CanvasLayer
var audio: Node3D
var camera: Camera3D
var board: Node3D
var moving_obstacles: Array[Node3D] = []
var opening_obstacle_art: MeshInstance3D
var final_obstacle_art: MeshInstance3D
var first_obstacle_entry_z := INF
var final_straight_z := 0.0
var racers: Array[RigidBody3D] = []
var player: RigidBody3D
var racer_finish_order: Array[String] = []
var finish_crossings: Array[RigidBody3D] = []
var finish_step_end := -INF
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
var airtime: Node3D
var slipstream: RefCounted
var draft_cue_cooldown := 0.0
var performance_budget: RefCounted
var camera_lookahead := Vector3.ZERO
var camera_previous_racer_z := NAN
var feedback_cooldown := 0.0
var obstacle_notice := 0.0
var last_count := -1
var last_checkpoint := -1
var checkpoint_splits: Array[float] = []
var race_start_z := 0.0
var practice_sector := -1
var practice_passage := 0
var practice_previous_time := NAN
var practice_previous_passages := PackedFloat64Array()
var practice_timing := PracticeTiming.new()
var course_flash := 0.0
var trail: CPUParticles3D
var skins: Node
var monetization: Node
var starting_camera_target := Vector3(0, 0, 0)
var contact_shadows: Node3D
var rival_render: Node3D
var workshop_lamps: Array[OmniLight3D] = []
var showroom_roof: MeshInstance3D
var secondary_showroom_art: Array[MeshInstance3D] = []
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
var start_gate: Node3D
var finish_origin := Vector3.ZERO
var track_physics_material: PhysicsMaterial
var primary_light: DirectionalLight3D
var world_environment: Environment
var graphics_quality := 1
var marble_detail_refresh := 0.0
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
var glacier_first_shutter_z := NAN
var glacier_exit_obstacles: Array[Dictionary] = []
var forge_piston_exit_obstacles: Array[Dictionary] = []
var forge_first_piston_z := NAN
var woodworks_return_obstacles: Array[Dictionary] = []
var evasion_probe := SphereShape3D.new()
var result_saved := false
var last_result: Dictionary = {}
const QUALITY_NAMES := ["ECONOMY","BALANCED","ULTRA","AUTO"]

func _ready() -> void:
    rng.seed = 424242
    evasion_probe.radius = Racer.RADIUS
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
    rival_render = RivalRenderBatch.new()
    rival_render.name = "InstancedRivalGlass"
    add_child(rival_render)
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
    airtime = AirtimeDirector.new()
    airtime.name = "LocalPhysicalAirAndLandings"
    add_child(airtime)
    airtime.configure(self)
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
    # Resume/background spikes must not force an unwanted quality downgrade.
    if not is_finite(delta) or delta <= 0.0 or delta > 0.25:
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
    var balanced := graphics_quality == 1
    if is_instance_valid(primary_light):
        primary_light.shadow_enabled = graphics_quality > 0
        if balanced:
            primary_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
            primary_light.directional_shadow_max_distance = BALANCED_SHADOW_RANGES[selected_track]
        else:
            primary_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
            primary_light.directional_shadow_max_distance = 72.0 if graphics_quality == 2 else 47.0
        primary_light.directional_shadow_split_1 = 0.10
    # The room's walls and overhead beam still shade the course.
    var secondary_shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (
        balanced and selected_track != 1) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for art in secondary_showroom_art:
        art.cast_shadow = secondary_shadows
    if is_instance_valid(camera):
        camera.far = [85.0,115.0,155.0][graphics_quality]
    if world_environment != null:
        world_environment.glow_enabled = graphics_quality > 0
        world_environment.fog_enabled = graphics_quality > 0
        # Keep luminous obstacle and marble accents readable without
        # washing out the track on mid-range Android screens. No extra
        # lights, draw calls, or post-processing passes are introduced.
        world_environment.glow_intensity = [0.0,0.19,0.27][graphics_quality]
        # High quality retains distant scenery depth; medium uses gentler
        # fog so small hazards stay distinguishable in landscape mode.
        world_environment.fog_density = [0.0,0.0035,0.0045][graphics_quality]
    if is_instance_valid(contact_shadows):
        contact_shadows.visible = graphics_quality > 0
        contact_shadows.set_update_rate(60 if graphics_quality == 2 else 30)
    if is_instance_valid(obstacle_finish):
        obstacle_finish.visible = graphics_quality > 0
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.set_quality(graphics_quality)
    if is_instance_valid(course_sculptures):
        course_sculptures.set_quality(graphics_quality)
    if is_instance_valid(airtime):
        airtime.set_quality(graphics_quality)
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
        # Three original distant landscape layers cull progressively on
        # slower devices; scenery cannot alter race collisions or AI routes.
        var world_name: String = "World_%s" % (
            TrackUniverses.THEMES[selected_track].replace(" ","_"))
        var world := board.get_node_or_null(world_name)
        if is_instance_valid(world):
            world.set_quality(graphics_quality)
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
    rival_render.set_quality(graphics_quality)

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

func upcoming_hazard_distance(at_z: float) -> float:
    # Presentation-only fast path: avoid building a hazard notice dictionary
    # at camera frame rate. Keep the same gate/event priority as the HUD.
    var nearest := 25.0
    var found := false
    for hazard in hazard_beacons:
        var candidate: float = at_z-float(hazard["z"])
        if candidate >= -1.0 and candidate < nearest:
            nearest = candidate
            found = true
    var result: float = float(maxi(0,int(round(nearest)))) if found else -1.0
    if is_instance_valid(race_director):
        var event: Dictionary = race_director.event_ahead(at_z)
        if not event.is_empty() and float(event["distance"]) < nearest:
            result = float(event["distance"])
    return result

func upcoming_hazard(at_z: float, downstream_limit := INF) -> Dictionary:
    # An exterior bridge bypasses main-track hazards upstream of its merge.

    var nearest := 25.0
    var notice: Dictionary = {}
    for hazard in hazard_beacons:
        var hazard_z := float(hazard["z"])
        var distance := at_z-hazard_z
        if hazard_z <= downstream_limit and distance >= -1.0 and distance < nearest:
            nearest = distance
            notice = {"side":hazard["side"],"distance":maxi(0,int(round(distance))),
                "z":hazard["z"], "final":hazard.get("final",false)}
    if is_instance_valid(race_director):
        var event: Dictionary = race_director.event_ahead(at_z,downstream_limit)
        if not event.is_empty() and float(event["distance"]) < nearest:
            notice = event
    return notice

func pack_hazard_ahead(at: Vector3, velocity: Vector3) -> Vector3:
    var forward := -velocity.z
    if forward < 6.0 or not at.is_finite() or not velocity.is_finite():
        return Vector3.INF
    var bridge: bool = shortcut_route.on_separate_deck(at) or (
        at.z >= ShortcutRoute.EXIT_Z and airtime.bridge_grounded)
    var limit := ShortcutRoute.EXIT_Z if bridge else INF
    var nearest := clampf(forward*1.25,9.0,25.0)
    var target := Vector3.INF
    var gate: Dictionary = race_director.event_ahead(at.z,limit,nearest)
    if not gate.is_empty():
        var index: int = gate["index"]
        var distance: float = at.z-float(gate["z"])
        var threatened: bool
        if selected_track != 0 and index == 0:
            threatened = is_finite(race_director.first_gate_contact_eta(at,velocity))
        elif selected_track == 0 and index == RaceDirector.WOODWORKS_RETURN_ARM:
            threatened = not bridge and (at.z <= ShortcutRoute.EXIT_Z or shortcut_route.merge_traffic_lane(at) >= 0) and is_finite(
                race_director.woodworks_arm_contact_eta(distance/forward,forward,at.x,velocity.x))
        else:
            threatened = race_director.threatens_line(index,race_director.clock,distance/forward,at.x,velocity.x)
        if threatened:
            nearest = distance
            target = race_director.obstacles[index].global_position
            target.y = maxf(target.y,height_at(target.z)+0.28)
    for hazard in hazard_beacons:
        var z: float = hazard["z"]
        var distance := at.z-z
        if z > limit or distance < 1.2 or distance >= nearest:
            continue
        var body: StaticBody3D = hazard["body"]
        var center := body.global_position
        var approach_x := RaceFeedback.projected_lane_x(at.x,velocity.x,distance/forward)
        if absf(approach_x-center.x) > float(hazard["half_width"])+Racer.RADIUS:
            continue
        nearest = distance
        target = center
    return target

func woodworks_opening_cleared(z: float) -> bool:
    return selected_track == 0 and is_instance_valid(opening_obstacle_art) and z < opening_obstacle_art.clear_z

func forge_merge_threat(at: Vector3, velocity: Vector3, bridge_merge: bool) -> Dictionary:
    # Preview the hazards around the Forge join using the same clocks and
    # entry times as the HUD. The bridge bypasses the main-track vent.
    var speed := -velocity.z
    if selected_track != 2 or not at.is_finite() or not velocity.is_finite() or speed < 6.0 or (
            at.z > ShortcutRoute.MERGE_TRAFFIC_NEAR):
        return {}
    var gate := RaceDirector.FORGE_EXIT_GATE
    var gate_z: float = race_director.event_z(gate)
    if at.z <= gate_z or (not bridge_merge and absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.85):
        return {}
    var gate_eta := (at.z-gate_z)/speed
    var piston_eta: float = race_director.forge_piston_contact_eta(
        gate,gate_eta,speed,NAN if bridge_merge else at.x,velocity.x)
    if not bridge_merge:
        var vent: Dictionary = course_mechanics.upcoming_lane(at,velocity,INF)
        var vent_eta := float(vent.get("contact_eta",INF))
        if vent_eta <= CourseMechanics.VENT_WARNING_SECONDS and vent_eta < piston_eta:
            var point: Vector3 = course_mechanics.zones[int(vent["index"])].global_position
            return {"position":point+Vector3.UP*0.35,"kind":"VENT"}
    if piston_eta <= RaceDirector.PISTON_WARNING_SECONDS:
        var point: Vector3 = race_director.position_at(gate,race_director.clock+piston_eta)
        point.y = maxf(point.y,height_at(gate_z)+0.35)
        return {"position":point,"kind":"PISTON"}
    return {}

func glacier_shutter_exit_active(z: float) -> bool:
    return selected_track == 1 and z >= glacier_first_shutter_z-GLACIER_EXIT_REACH and (
        z <= glacier_first_shutter_z+GLACIER_EXIT_PREVIEW_REACH)

func glacier_exit_threat(at: Vector3, velocity: Vector3) -> Dictionary:
    var speed := -velocity.z
    if not at.is_finite() or not velocity.is_finite() or speed < 5.0 or (
            not glacier_shutter_exit_active(at.z) or (
                absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.55 or airtime.airborne)):
        return {}
    return _first_exit_contact(at,velocity,glacier_exit_obstacles,0.0,GLACIER_EXIT_WARNING_SECONDS)

func forge_piston_exit_active(z: float) -> bool:
    return selected_track == 2 and z <= forge_first_piston_z-RaceDirector.BODY_DEPTH*0.5-Racer.RADIUS and (
        z >= maxf(forge_first_piston_z-FORGE_PISTON_EXIT_REACH,ShortcutRoute.ENTRY_Z+0.5))

func forge_piston_exit_threat(at: Vector3, velocity: Vector3) -> Dictionary:
    if not at.is_finite() or not velocity.is_finite() or -velocity.z < 5.0 or (
            not forge_piston_exit_active(at.z) or airtime.airborne or (
                absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.55 or absf(at.x-track_center_at(at.z)) > 6.3)):
        return {}
    var runway := (at.z-ShortcutRoute.ENTRY_Z-0.25)/-velocity.z
    var horizon := minf(runway,FORGE_PISTON_EXIT_WARNING_SECONDS)
    var contact := _first_exit_contact(at,velocity,forge_piston_exit_obstacles,0.0,horizon)
    if not contact.is_empty():
        contact["blocking"] = true
        return contact
    # Preview the next nearby row when the current line already misses
    # its blockers. The lane solver still checks the whole approach.
    var next_row: Dictionary = {}
    var nearest := -velocity.z*horizon
    for obstacle in forge_piston_exit_obstacles:
        var point: Vector3 = obstacle["position"]
        var extent: Vector2 = obstacle["half_size"]
        var entry := point.z+extent.y+Racer.RADIUS
        var distance := at.z-entry
        if obstacle["moving"] or distance < 3.0 or distance >= nearest or (
                absf(at.x-point.x) > extent.x+2.5):
            continue
        nearest = distance
        next_row = {"position":point,"label":obstacle["label"],"entry_z":entry,
            "last_z":point.z-extent.y-Racer.RADIUS,"blocking":false}
    return next_row

func woodworks_return_active(z: float) -> bool:
    return selected_track == 0 and z <= ShortcutRoute.EXIT_Z+9.0 and (
        z >= ShortcutRoute.EXIT_Z-WOODWORKS_RETURN_DEPTH-2.0)

func woodworks_return_threat(at: Vector3, velocity: Vector3) -> Dictionary:
    var speed := -velocity.z
    if not at.is_finite() or not velocity.is_finite() or speed < 6.0 or (
            not woodworks_return_active(at.z) or airtime.airborne or not is_instance_valid(shortcut_route)):
        return {}
    var bridge: bool = at.z > ShortcutRoute.EXIT_Z and shortcut_route.merge_traffic_lane(at) < 0
    var delay := 0.0
    if bridge:
        delay = (at.z-ShortcutRoute.EXIT_Z)/speed
        var landing_x := RaceFeedback.projected_lane_x(at.x,velocity.x,delay)
        if delay >= WOODWORKS_RETURN_WARNING_SECONDS or (
                absf(landing_x-track_center_at(ShortcutRoute.EXIT_Z)) > 6.3):
            return {}
    elif absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.55 or (
            absf(at.x-track_center_at(at.z)) > 6.3):
        return {}
    return _first_exit_contact(at,velocity,woodworks_return_obstacles,delay,WOODWORKS_RETURN_WARNING_SECONDS)

func _first_exit_contact(at: Vector3, velocity: Vector3, obstacles: Array[Dictionary],
        delay: float, horizon: float) -> Dictionary:
    var speed := -velocity.z
    # Preserve the observed drift until the same short limit used by the
    # other previews. An exterior approach starts at the plane of the join.
    var split := minf(horizon,maxf(delay,0.40))
    var origin := Vector2(RaceFeedback.projected_lane_x(at.x,velocity.x,delay),at.z-speed*delay)
    var pivot := Vector2(RaceFeedback.projected_lane_x(at.x,velocity.x,split),at.z-speed*split)
    var end := Vector2(pivot.x,at.z-speed*horizon)
    var soonest := INF
    var target: Dictionary = {}
    for obstacle in obstacles:
        var point: Vector3 = obstacle["position"]
        var center := Vector2(point.x,point.z)
        var half_size: Vector2 = obstacle["half_size"]
        var reach_z := half_size.y+Racer.RADIUS
        if center.y+reach_z < end.y or center.y-reach_z > origin.y:
            continue
        var hit := _predicted_obstacle_contact(obstacle,origin-center,pivot-center,delay,split) if split > delay else INF
        var eta := delay+hit*(split-delay) if is_finite(hit) else INF
        if hit == INF and horizon > split:
            hit = _predicted_obstacle_contact(obstacle,pivot-center,end-center,split,horizon)
            eta = split+hit*(horizon-split)
        if eta < soonest:
            soonest = eta
            target = obstacle
    if target.is_empty():
        return {}
    var point: Vector3 = target["position"]
    var half_size: Vector2 = target["half_size"]
    return {
        "position":target["position"],"label":target["label"],
        "entry_z":at.z-soonest*speed,"last_z":point.z-half_size.y-Racer.RADIUS,
        "moving":target.get("moving",false)
    }

func _predicted_obstacle_contact(obstacle: Dictionary, from: Vector2, to: Vector2,
        first: float, last: float) -> float:
    var spinner := obstacle.get("spinner") as AnimatableBody3D
    var extent: Vector2 = obstacle["half_size"]
    var envelope := _exit_obstacle_contact(from,to,extent,obstacle["peg"])
    if not is_instance_valid(spinner) or net.is_client() or not is_finite(envelope):
        return envelope
    # The local spinner advances at a constant angular speed. Rotate each
    # chord into the arm's frame and cover its movement between samples.
    var rate: float = spinner.get_meta("spin_speed")
    var intervals := maxi(1,ceili((last-first)/0.08))
    var padding := extent.x*absf(rate)*(last-first)/(2.0*intervals)
    for part in range(intervals):
        var a := float(part)/intervals
        var b := float(part+1)/intervals
        var phase := spinner.rotation.y+rate*lerpf(first,last,(a+b)*0.5)
        var hit := INF
        for child in spinner.get_children():
            if child is CollisionShape3D and child.shape is BoxShape3D:
                var angle: float = phase+child.rotation.y
                var size: Vector3 = child.shape.size
                var half_size := Vector2(size.x,size.z)*0.5+Vector2.ONE*padding
                hit = minf(hit,_exit_obstacle_contact(
                    from.lerp(to,a).rotated(angle),from.lerp(to,b).rotated(angle),half_size,false))
        if is_finite(hit):
            return lerpf(a,b,hit)
    return INF

static func _exit_obstacle_contact(from: Vector2, to: Vector2, half_size: Vector2, peg: bool) -> float:
    if peg:
        return _glacier_circle_entry(from,to,half_size.x+Racer.RADIUS)
    # A marble expands the blocker by its radius, with round corners.
    var entry := minf(
        _glacier_rect_entry(from,to,half_size+Vector2(Racer.RADIUS,0)),
        _glacier_rect_entry(from,to,half_size+Vector2(0,Racer.RADIUS)))
    for side_x in [-1.0,1.0]:
        for side_z in [-1.0,1.0]:
            var corner := Vector2(half_size.x*side_x,half_size.y*side_z)
            entry = minf(entry,_glacier_circle_entry(from-corner,to-corner,Racer.RADIUS))
    return entry

static func _glacier_circle_entry(from: Vector2, to: Vector2, radius: float) -> float:
    if from.length_squared() <= radius*radius:
        return 0.0
    var hit := Geometry2D.segment_intersects_circle(from,to,Vector2.ZERO,radius)
    return hit if hit >= 0.0 else INF

static func _glacier_rect_entry(from: Vector2, to: Vector2, reach: Vector2) -> float:
    var entry := 0.0
    var exit := 1.0
    var motion := to-from
    for axis in range(2):
        if is_zero_approx(motion[axis]):
            if absf(from[axis]) > reach[axis]:
                return INF
            continue
        var a := (-reach[axis]-from[axis])/motion[axis]
        var b := (reach[axis]-from[axis])/motion[axis]
        entry = maxf(entry,minf(a,b))
        exit = minf(exit,maxf(a,b))
    return entry if entry <= exit else INF

func evasion_lane(at: Vector3, velocity: Vector3, hazard: Vector3) -> Vector3:
    var distance := at.z-hazard.z
    var speed := -velocity.z
    if not hazard.is_finite() or not at.is_finite() or not velocity.is_finite() or (
            speed < 13.0 or distance < 5.0 or distance > speed*1.35 or
            absf(at.x-track_center_at(at.z)) > 6.1 or
            absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.28 or
            shortcut_route.on_separate_deck(at) or airtime.bridge_grounded):
        return Vector3.INF
    var entry_z := hazard.z+2.6
    var end_z := hazard.z-8.0
    var eta := distance/speed
    var return_arm: bool = selected_track == 0 and absf(hazard.z-race_director.event_z(RaceDirector.WOODWORKS_RETURN_ARM)) < 0.08
    var center := track_center_at(hazard.z)
    var drift := RaceFeedback.projected_lane_x(at.x,velocity.x,eta)
    const REACTION_SECONDS := 0.10
    var duration := (distance-RaceDirector.BODY_DEPTH*0.5-Racer.RADIUS)/speed-REACTION_SECONDS
    var anticipated_x := at.x+velocity.x*REACTION_SECONDS
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = evasion_probe
    query.collision_mask = 1
    var ignored: Array[RID] = airtime.ignored_rids.duplicate()
    for gate in race_director.obstacles:
        ignored.append(gate.get_rid())
    query.exclude = ignored
    var best := Vector3.INF
    var cost := INF
    for offset in [0.0,-1.55,1.55,-2.85,2.85]:
        var x: float = center+offset
        var change := absf(x-drift)
        if change >= cost or change > 0.5+5.3*eta:
            continue
        var displacement := x-anticipated_x
        if return_arm:
            var max_accel := Racer.human_steering_force(1.0,velocity.z,velocity.x,0)*0.72
            if duration <= 0.0 or maxf(absf(6.0*displacement-4.0*velocity.x*duration),
                    absf(6.0*displacement-2.0*velocity.x*duration)) > max_accel*duration*duration:
                continue
        var blocked := false
        for index in range(race_director.obstacles.size()):
            var z: float = race_director.event_z(index)
            if z >= at.z or z < end_z:
                continue
            var arrival := (at.z-z)/speed
            var lane_x := lerpf(at.x,x,minf(1.0,arrival/eta))+(
                track_center_at(z)-center if z < hazard.z else 0.0)
            if return_arm and index == RaceDirector.WOODWORKS_RETURN_ARM:
                if is_finite(race_director.woodworks_arm_contact_eta(arrival,speed,x,0.0)):
                    blocked = true
                    break
                continue
            # Check the front, center and rear of the marble crossing.
            for phase_offset in [-0.06,0.0,0.06]:
                if race_director.threatens_line(index,race_director.clock,
                        maxf(0.0,arrival+phase_offset),lane_x,0.0):
                    blocked = true
                    break
            if blocked:
                break
        if blocked:
            continue
        var middle := Vector3(x,height_at(hazard.z)+0.53,hazard.z)
        var last := Vector3(track_center_at(end_z)+offset,height_at(end_z)+0.53,end_z)
        # Test the lane at the obstacle and through the next encounter.
        # The lateral-reach limit above controls how far ahead it is offered.
        var start := Vector3(track_center_at(entry_z)+offset,height_at(entry_z)+0.53,entry_z)
        if return_arm:
            var previous := Vector3(at.x,height_at(at.z)+0.53,at.z)
            for step in range(5):
                var u := float(step)*0.25
                var z := at.z-speed*(REACTION_SECONDS+u*duration)
                var path_x := anticipated_x+displacement*u*u*(3.0-2.0*u)+velocity.x*duration*u*(1.0-u)*(1.0-u)
                var sample := Vector3(path_x,height_at(z)+0.53,z)
                if not _evasion_span_clear(query,previous,sample):
                    blocked = true
                    break
                previous = sample
            if blocked:
                continue
            start = previous
        if not _evasion_span_clear(query,start,middle) or not _evasion_span_clear(query,middle,last):
            continue
        cost = change
        best = middle
    return best

func _evasion_span_clear(query: PhysicsShapeQueryParameters3D, start: Vector3, end: Vector3) -> bool:
    var space := get_world_3d().direct_space_state
    query.transform = Transform3D(Basis.IDENTITY,start)
    query.motion = Vector3.ZERO
    if not space.intersect_shape(query,1).is_empty():
        return false
    query.motion = end-start
    var travel := space.cast_motion(query)
    return travel.size() >= 2 and travel[0] >= 0.999

func glacier_exit_lane(at: Vector3, velocity: Vector3, threat: Dictionary) -> Vector3:
    var speed := -velocity.z
    if threat.is_empty() or speed < 5.0 or not velocity.is_finite() or not at.is_finite() or (
            not glacier_shutter_exit_active(at.z) or airtime.airborne or airtime.ice_touching or (
            shortcut_route.on_separate_deck(at) or airtime.bridge_grounded or (
                absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.28))):
        return Vector3.INF
    return _rolling_exit_lane(at,velocity,threat,true)

func woodworks_return_lane(at: Vector3, velocity: Vector3, threat: Dictionary) -> Vector3:
    if threat.is_empty() or at.z > ShortcutRoute.EXIT_Z or airtime.bridge_grounded or (
            absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.35):
        return Vector3.INF
    return _rolling_exit_lane(at,velocity,threat,false)

func forge_piston_exit_lane(at: Vector3, velocity: Vector3, threat: Dictionary,
        rivals: Array[RigidBody3D]) -> Vector3:
    if threat.is_empty() or not at.is_finite() or not velocity.is_finite() or -velocity.z < 5.0 or (
            not forge_piston_exit_active(at.z) or airtime.airborne) or (
            absf(at.y-height_at(at.z)-Racer.RADIUS) > 0.35):
        return Vector3.INF
    return _rolling_exit_lane(at,velocity,threat,false,rivals)

func _rolling_exit_lane(at: Vector3, velocity: Vector3, threat: Dictionary, watch_shutter: bool,
        rivals: Array[RigidBody3D] = []) -> Vector3:
    var speed := -velocity.z
    var blocker: Vector3 = threat["position"]
    var forge_exit := selected_track == 2
    var nose_z: float = 2.0*blocker.z-float(threat["last_z"])+0.04
    if forge_exit and threat.get("moving",false):
        nose_z = float(threat["entry_z"])+0.25
    var mark_z := minf(blocker.z,nose_z-0.55) if forge_exit else blocker.z
    var steering_time := (at.z-nose_z)/speed
    if steering_time < 0.22 or at.z-mark_z < 2.6:
        return Vector3.INF
    var shutter := RaceDirector.GLACIER_FIRST_SHUTTER
    var shutter_eta := (at.z-glacier_first_shutter_z)/speed
    var half_window := (RaceDirector.BODY_DEPTH*0.5+Racer.RADIUS)/speed
    var shutter_ahead := watch_shutter and shutter_eta+half_window >= 0.0
    if shutter_ahead and race_director.glacier_shutter_threatens_crossing(
            shutter,shutter_eta,speed,at.x,velocity.x):
        return Vector3.INF

    # Leave one forecast interval for the player to see the cue, then require
    # room to settle the lateral movement before the blocker’s front face.
    const REACTION_SECONDS := 0.10
    var duration := steering_time-REACTION_SECONDS
    var start_x := at.x+velocity.x*REACTION_SECONDS
    # Racer applies the steering force scaled by mass. Leave headroom for
    # rolling contact and damping before treating a lane as reachable.
    var max_accel := Racer.human_steering_force(1.0,velocity.z,velocity.x,selected_track)*0.72
    var center := track_center_at(mark_z)
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = evasion_probe
    query.collision_mask = 1
    query.margin = 0.04
    var ignored: Array[RID] = airtime.ignored_rids.duplicate()
    if watch_shutter:
        ignored.append(race_director.obstacles[shutter].get_rid())
    if forge_exit and not net.is_client():
        for obstacle in forge_piston_exit_obstacles:
            var spinner := obstacle.get("spinner") as AnimatableBody3D
            if is_instance_valid(spinner):
                ignored.append(spinner.get_rid())
    query.exclude = ignored
    var rival_positions := PackedVector2Array()
    var rival_velocities := PackedVector2Array()
    for rival in rivals:
        var motion: Vector3 = net.replica_velocity(rival) if net.is_client() else (
            Vector3.ZERO if rival.freeze else rival.linear_velocity)
        if not motion.is_finite():
            return Vector3.INF
        rival_positions.append(Vector2(rival.global_position.x,rival.global_position.z))
        rival_velocities.append(Vector2(motion.x,motion.z))
    var exit_z := blocker.z-2.4 if watch_shutter else float(threat["last_z"])-0.55
    if forge_exit and exit_z < ShortcutRoute.ENTRY_Z+0.25:
        return Vector3.INF
    var best := Vector3.INF
    var best_cost := INF
    var offsets := [0.0,-0.55,0.55,-1.10,1.10,-1.65,1.65,-2.20,2.20,-2.75,2.75]
    if not watch_shutter:
        offsets.append_array([-3.30,3.30,-3.85,3.85,-4.40,4.40])
    if forge_exit:
        offsets.push_front(clampf(start_x-center,-5.1,5.1))
    for offset in offsets:
        var lane_x: float = center+offset
        var cost := absf(lane_x-start_x)
        # Cubic steering path with the measured approach velocity and zero
        # sideways speed through the gap. Acceleration peaks at an endpoint.
        var displacement := lane_x-start_x
        var start_accel := (6.0*displacement-4.0*velocity.x*duration)/(duration*duration)
        var end_accel := (-6.0*displacement+2.0*velocity.x*duration)/(duration*duration)
        if cost >= best_cost or maxf(absf(start_accel),absf(end_accel)) > max_accel:
            continue
        var path_x := func(t: float) -> float:
            if t <= REACTION_SECONDS:
                return at.x+velocity.x*t
            var u := minf(1.0,(t-REACTION_SECONDS)/duration)
            return start_x+displacement*u*u*(3.0-2.0*u)+velocity.x*duration*u*(1.0-u)*(1.0-u)
        if shutter_ahead:
            var first := maxf(0.0,shutter_eta-half_window)
            var last := shutter_eta+half_window
            var lanes := Vector2(INF,-INF)
            for fraction in [0.0,0.25,0.5,0.75,1.0]:
                var t := lerpf(first,last,fraction)
                var gap: float = path_x.call(t)-race_director.position_at(shutter,race_director.clock+t).x
                lanes = Vector2(minf(lanes.x,gap),maxf(lanes.y,gap))
            if lanes.x < RaceDirector.LANE_THREAT_RADIUS and lanes.y > -RaceDirector.LANE_THREAT_RADIUS:
                continue
        var previous := Vector3(at.x,height_at(at.z)+0.53,at.z)
        var previous_time := 0.0
        var clear := true
        for part in range(1,5):
            var t := REACTION_SECONDS+duration*float(part-1)/3.0
            var z := at.z-speed*t
            var sample := Vector3(path_x.call(t),height_at(z)+0.53,z)
            if not _evasion_span_clear(query,previous,sample) or (forge_exit and not (
                    _forge_exit_span_clear(previous,sample,previous_time,t,rival_positions,rival_velocities))):
                clear = false
                break
            previous = sample
            previous_time = t
        # Clear the blocker’s entire depth and leave space for the next turn.
        var end := Vector3(lane_x,height_at(exit_z)+0.53,exit_z)
        if clear and _evasion_span_clear(query,previous,end) and (not forge_exit or (
                _forge_exit_span_clear(previous,end,previous_time,(at.z-exit_z)/speed,rival_positions,rival_velocities))):
            best = Vector3(lane_x,height_at(mark_z)+0.53,mark_z)
            best_cost = cost
    return best

func _forge_exit_span_clear(start: Vector3, end: Vector3, first: float, last: float,
        rivals: PackedVector2Array, velocities: PackedVector2Array) -> bool:
    var from := Vector2(start.x,start.z)
    var to := Vector2(end.x,end.z)
    if not RaceFeedback.traffic_span_clear(from,to,first,last,rivals,velocities,PASSING_TRAFFIC_CLEARANCE):
        return false
    for obstacle in forge_piston_exit_obstacles:
        if not obstacle["moving"]:
            continue
        var center: Vector3 = obstacle["position"]
        var local := Vector2(center.x,center.z)
        if is_finite(_predicted_obstacle_contact(obstacle,from-local,to-local,first,last)):
            return false
    return true

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

func recovery_center_at(location: Vector3, main_center := NAN) -> float:
    var center := track_center_at(location.z) if is_nan(main_center) else main_center
    if is_instance_valid(shortcut_route):
        return shortcut_route.recovery_center_at(location,center)
    return center

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

func _cylinder(parent: Node3D, location: Vector3, radius: float, tall: float, color: Color,
        section: int) -> StaticBody3D:
    var body = StaticBody3D.new()
    body.name = "ToyPeg"
    body.position = location
    parent.add_child(body)
    var batched_art := section == 1 or section == FINAL_OBSTACLE_SECTION
    if not batched_art and is_instance_valid(obstacle_finish):
        obstacle_finish.register_post(body.global_position,radius,tall,color)
    var hitbox = CollisionShape3D.new()
    var cylinder = CylinderShape3D.new()
    cylinder.radius = radius
    cylinder.height = tall
    hitbox.shape = cylinder
    body.add_child(hitbox)
    _register_exit_obstacle(body,Vector2.ONE*radius,"PEG",true)
    if batched_art:
        return body
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
    glacier_exit_obstacles.clear()
    forge_piston_exit_obstacles.clear()
    woodworks_return_obstacles.clear()
    workshop_lamps.clear()
    secondary_showroom_art.clear()
    opening_obstacle_art = null
    first_obstacle_entry_z = INF
    board = Node3D.new()
    board.name = "HandcraftedWoodenCourse"
    board.set_meta("track_index",selected_track)
    built_variation = race_variation
    glacier_first_shutter_z = RaceDirector.event_z_for(1,built_variation,RaceDirector.GLACIER_FIRST_SHUTTER) if (
        selected_track == 1) else NAN
    forge_first_piston_z = RaceDirector.event_z_for(2,built_variation,0) if selected_track == 2 else NAN
    board.set_meta("solo_course_clearance",_uses_solo_course_clearance(built_variation))
    var last_bank: int = CourseSculptures.BANK_SECTIONS.back()
    final_straight_z = CourseSculptures.bank_z(last_bank,built_variation)-(
        CourseSculptures.BANK_HALF_LENGTH+Racer.RADIUS)
    add_child(board)
    moving_obstacles.clear()
    # A freshly assembled course must not inherit the previous race's
    # hammer phase. Finishing faster on another track changes no start phase.
    kinetic_time = 0.0
    TrackUniverses.apply_atmosphere(world_environment,primary_light,selected_track)
    obstacle_finish = ObstacleFinish.new()
    obstacle_finish.name = "PremiumObstacleFinishes"
    board.add_child(obstacle_finish)
    track_surface = TrackSurface.new()
    track_surface.name = "InstancedTrackSurface"
    board.add_child(track_surface)
    jump_guides = JumpGuides.new()
    jump_guides.game = self
    board.add_child(jump_guides)
    for section in range(SEGMENTS):
        var center_z = 8.0 - float(section) * SEGMENT_LENGTH
        var section_node = Node3D.new()
        section_node.name = "Course_%02d" % section
        section_node.position.x = track_center_at(center_z)
        board.add_child(section_node)
        for lane in range(PLANK_COUNT):
            var x := (float(lane) - (PLANK_COUNT-1)*0.5) * PLANK_SPACING
            var material_index := (lane + section * 3) % WOOD_COLORS.size()
            var shade: Color = _themed_wood(WOOD_COLORS[material_index])
            var plank_at := Vector3(x,height_at(center_z)-0.34,center_z)
            # Render-only planks share GPU draw calls by material. Each keeps
            # the exact original independent tilted BoxShape3D collider.
            var floor_body := _box(section_node,plank_at,
                TrackSurface.PLANK,_wood_mat(shade),true,true,false)
            floor_body.set_meta(TrackSurface.ROAD_FLOOR,true)
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
                var pos := Vector3(side*6.84,height_at(z)+0.58,z)
                _box(section_node,pos,TrackSurface.RAIL,null,true,true,false)
                track_surface.register_rail(pos+section_node.position,track_grade_at(z))
        if section in [3, 9, 14]:
            _terrain_ramp(section_node,center_z,section)
        if section > 0 and section <= FINAL_OBSTACLE_SECTION:
            # Edge-specific baffles eliminate the dominant strategy of riding
            # permanently against either rail. Passages remain physically open.
            var glacier_return := selected_track == 1 and section >= ShortcutRoute.EXIT_SECTION and (
                section <= ShortcutRoute.EXIT_SECTION+2)
            _edge_baffles(section_node,center_z,section,glacier_return)
            if glacier_return:
                _glacier_return_obstacles(section_node,center_z,section)
                continue
            var layout := _obstacle_layout(section)
            if layout == 1:
                _pegs(section_node, center_z, section)
            elif layout == 2:
                _gate_with_posts(section_node, center_z, section)
            else:
                _slalom(section_node, center_z, section)
            if section == 1 or section == FINAL_OBSTACLE_SECTION:
                var art := OpeningObstacles.new()
                art.name = "OpeningObstacleArt" if section == 1 else "FinalObstacleArt"
                # Paint the visible approach from the same collider geometry.
                art.build(section_node,self,center_z,section,layout)
                section_node.add_child(art)
                if section == 1:
                    opening_obstacle_art = art
                    first_obstacle_entry_z = art.entry_z
                else:
                    final_obstacle_art = art

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
    for ramp in shortcut_route.launch_ramps:
        var shape: BoxShape3D = ramp.get_child(0).shape
        jump_guides.add_ramp(ramp,shape.size,true)
    obstacle_finish.rebuild()
    var woods: Array = []
    for color in WOOD_COLORS:
        woods.append(_wood_mat(_themed_wood(color)))
    track_surface.finish(woods,selected_track,_mat(Color("#82563d")))
    _make_start_gate()
    _make_finish_line()
    _edge_checkpoint_markers()
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
    arcade_bumpers.setup(selected_track,built_variation,board.get_meta("solo_course_clearance"))
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
        seam.set_meta(TrackSurface.ROAD_FLOOR,true)
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

func _uses_solo_course_clearance(layout: int) -> bool:
    return (selected_track == 2 or layout == (0 if selected_track == 1 else 2)) and (
        net != null and not net.is_active())

func _terrain_ramp(parent: Node3D, center_z: float, section: int) -> void:
    # Short, low physical crests alter suspension/rolling lines without
    # closing the entire lane or trapping the 40-marble pack.
    if selected_track == 0 and section != ShortcutRoute.EXIT_SECTION:
        return
    var lane := -2.2 if (section+selected_track)%2 == 0 else 2.2
    var z := center_z+1.5
    var size := Vector3(3.55,0.22,2.35)
    if section == FINAL_OBSTACLE_SECTION and board.get_meta("solo_course_clearance"):
        # The first Forge layout can trap a no-input marble against the
        # initial final peg row when this crest overlaps its exit. Give
        # every solo layout the same bank-separated physical release path.
        # Online geometry remains identical to the deployed server.
        # Give the crest its own stretch past the last bank, clear of the
        # gate posts and the paddle's sweep.
        z = CourseSculptures.bank_z(CourseSculptures.BANK_SECTIONS.back(),built_variation)-5.8
        lane += track_center_at(z)-parent.position.x
    if selected_track == 1 and section == ShortcutRoute.EXIT_SECTION:
        # The raised crest belongs on the opposite shoulder. The main lane
        # next to the bridge is the passing line for the two converging roads.
        lane = 3.05
        z = center_z+2.9
        size = Vector3(1.75,0.22,2.35)
    var ramp := _box(parent,Vector3(lane,height_at(z)+0.12,z),
        size,_lacquer(TRACK_COLORS[selected_track].lightened(0.20)),true,true)
    ramp.name = "RideableCrest_%02d" % section
    ramp.rotation.x += -0.09 if selected_track == 1 else -0.16
    jump_guides.add_ramp(ramp,size)

func _edge_baffles(parent: Node3D, center_z: float, section: int, glacier_return: bool) -> void:
    # Two solid edge shutters per module, plus a staggered inboard obstacle
    # for advanced circuits. These are real collisions, not cosmetic warnings.
    for side in [-1.0, 1.0]:
        var z: float = center_z + (3.75 if side < 0.0 else -3.75)
        var material_color: Color = TRACK_COLORS[selected_track].darkened(0.13)
        # At Glacier's return, leave a shoulder for racers nudged sideways
        # as both lines merge. Keep the baffle visible and collidable by the rail.
        var woodworks_lip: bool = selected_track == 0 and section == ShortcutRoute.EXIT_SECTION and side > 0.0
        var merge_side: bool = woodworks_lip or (glacier_return and section == ShortcutRoute.EXIT_SECTION+1 and side < 0.0)
        var size := Vector3(0.94 if merge_side else 2.72,1.05,1.32)
        var edge_offset := 6.04 if merge_side else 5.17
        if selected_track == 2 and section == 1 and side > 0.0:
            # Leave space on the inside of the downstream shoulder baffle
            # for a pack exiting the opening pegs or staggered blocks.
            size.x = 2.10
            edge_offset = 5.33
        var batched_art := section == 1 or section == FINAL_OBSTACLE_SECTION
        var node := _box(parent,Vector3(side*edge_offset,height_at(z)+0.49,z),
            size,_lacquer(material_color),true,true,not batched_art)
        node.name = "AntiEdgeBaffle_%02d_%s" % [section, "L" if side < 0.0 else "R"]
        hazard_beacons.append({"z":z,"side":"LEFT" if side < 0.0 else "RIGHT",
            "final":section == FINAL_OBSTACLE_SECTION,"body":node,"half_width":size.x*0.5})
        _register_exit_obstacle(node,Vector2(size.x,size.z)*0.5,"EDGE BLOCK")
        if not batched_art:
            obstacle_finish.register_block(node.global_transform,size,material_color)
    if not glacier_return and selected_track >= 1 and section % 3 == 0:
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
        if selected_track == 2:
            _register_exit_obstacle(gate,Vector2(wide.x,wide.z)*0.5,"CHICANE")
        obstacle_finish.register_block(gate.global_transform,wide,tint)

func _glacier_return_obstacles(parent: Node3D, center_z: float, section: int) -> void:
    # Keep an inward chicane opposite the bridge and leave both evasive
    # lines open around the timed shutter farther down the course.
    if section == ShortcutRoute.EXIT_SECTION:
        var tint: Color = TRACK_COLORS[selected_track].lightened(0.05)
        var size := Vector3(2.66,0.82,1.25)
        var block := _box(parent,Vector3(4.82,height_at(center_z)+0.37,center_z),
            size,_lacquer(tint),true,true)
        block.name = "Chicane_%02d" % section
        obstacle_finish.register_block(block.global_transform,size,tint)
        return
    for flank in [-1.0,1.0]:
        var x: float = flank*(4.95 if section == ShortcutRoute.EXIT_SECTION+1 else 4.65)
        var z: float = center_z+flank*(1.45+float(built_variation)*0.75)
        var tint: Color = BARRIER_COLORS[(section+built_variation+int(flank))%BARRIER_COLORS.size()]
        if (section+built_variation+int(flank))%3 == 0:
            var peg := _cylinder(parent,Vector3(x,height_at(z)+0.71,z),0.38,1.42,tint,section)
            peg.name = "ToyPeg_GlacierShoulder_%02d_%s" % [section,"L" if flank < 0 else "R"]
        else:
            var size := Vector3(1.56,0.84,1.06)
            var block := _box(parent,Vector3(x,height_at(z)+0.40,z),
                size,_lacquer(tint),true,true)
            block.name = "GlacierShoulderBlock_%02d_%s" % [section,"L" if flank < 0 else "R"]
            obstacle_finish.register_block(block.global_transform,size,tint)

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
            var peg_z: float = z
            if selected_track == 0 and n == ShortcutRoute.EXIT_SECTION and row == 2 and c == 4:
                x = 3.55
                peg_z += 0.70
            var tint = BARRIER_COLORS[(n + c + row) % BARRIER_COLORS.size()]
            _cylinder(parent, Vector3(x,height_at(peg_z)+0.8,peg_z),0.31,1.6,tint,n)

func _gate_with_posts(parent: Node3D, center_z: float, n: int) -> void:
    var batched_art := n == 1 or n == FINAL_OBSTACLE_SECTION
    for row in range(3 if selected_track == 2 else 2):
        var z = center_z + 3.2 - row * (4.2 if selected_track == 2 else 6.0)
        for i in range(3):
            var x = -4.6 + i * 4.7 + (0.65 if row == 1 else 0.0)
            if selected_track == 0 and n == ShortcutRoute.EXIT_SECTION and row == 1 and i == 2:
                x = 3.72
            var gate_color: Color = BARRIER_COLORS[(n+row+i)%6]
            var size := Vector3(0.91,1.37,1.25)
            var block := _box(parent, Vector3(x,height_at(z)+0.67,z),
                size,_lacquer(gate_color),true,true,not batched_art)
            block.name = "GatePost_%02d_%02d_%02d" % [n,row,i]
            _register_exit_obstacle(block,Vector2(size.x,size.z)*0.5,"GATE POST")
            if not batched_art:
                obstacle_finish.register_block(block.global_transform,size,gate_color)
    _add_spinner(parent, center_z, n)
    # Reduce overlap with the Forge paddle so a marble can roll out from
    # between the two mechanisms before reaching the next post.
    var forge_clearance: bool = selected_track == 2 and board.get_meta("solo_course_clearance")
    _swing_hammer(parent,center_z-(3.2 if forge_clearance else 1.6),n)

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
    if selected_track == 2:
        var reach := Vector2(size.x*0.5,absf(hit.position.y)+size.y*0.5).length()
        _register_exit_obstacle(hinge,Vector2(reach,size.z*0.5),"HAMMER SWEEP",false,true)
    var art = MeshInstance3D.new()
    art.mesh = Visuals.rounded_box(size, 0.15)
    art.position = hit.position
    art.material_override = _lacquer(BARRIER_COLORS[(n+3)%6])
    hinge.add_child(art)
    MechanismArt.decorate_hammer(hinge, parent, _mat(Color("#d6ad67"),0.27,0.72), _mat(Color("#262b33"),0.52,0.12))
    hinge.set_meta("motion_kind","hammer")
    # A small, deterministic layout variation changes when each hammer
    # crosses the lane without increasing its collision reach.
    var hammer_tempo: float = [0.92,1.0,1.08][posmod(built_variation+n,3)]
    hinge.set_meta("speed",(1.3+float(n%3)*0.22)*(
        1.0+0.18*selected_track)*hammer_tempo)
    hinge.set_meta("phase",float(n)*1.8+float(built_variation)*0.45)
    # Small fixed ground warning marks the hammer sweep before contact.
    # No physics body, and the existing mechanism remains authoritative.
    var warning := MeshInstance3D.new()
    warning.name = "HammerSweepWarning"
    var warning_mesh := BoxMesh.new()
    warning_mesh.size = Vector3(2.55,0.025,0.16)
    warning.mesh = warning_mesh
    warning.position = Vector3(hinge.position.x,
        height_at(z)+0.035,z)
    warning.material_override = _mat(Color("#f5b74d"),0.55,0.06)
    parent.add_child(warning)
    moving_obstacles.append(hinge)

func _slalom(parent: Node3D, center_z: float, n: int) -> void:
    var batched_art := n == 1 or n == FINAL_OBSTACLE_SECTION
    for i in range(5 if selected_track == 2 else 4):
        var z = center_z + 4.4 - float(i) * (2.2 if selected_track == 2 else 2.8)
        # The alternating barrier rhythm changes between layouts, but the
        # 3.4m obstacle always leaves a full-width outside escape lane.
        var side := -1.0 if (i+race_variation)%2==0 else 1.0
        var x: float = side*(3.5+0.20*sin(float(n*3+i)))
        var slalom_color: Color = BARRIER_COLORS[(n+i)%6]
        var size := Vector3(3.4,0.75,1.05)
        if selected_track == 2 and n == 1 and i == 1 and side > 0.0:
            # This block and the trailing baffle used to funnel the opening
            # pack into the same shoulder. Keep the block close to the rail.
            x = 5.30
            size.x = 1.65
        if selected_track == 0 and n == ShortcutRoute.EXIT_SECTION and i == 3:
            # Keep the physical route from the bridge through the open rail.
            x = 2.35
            size.x = 2.80
        var block := _box(parent, Vector3(x,height_at(z)+0.36,z),
            size,_lacquer(slalom_color),true,true,not batched_art)
        block.name = "SlalomBlock_%02d_%02d" % [n,i]
        _register_exit_obstacle(block,Vector2(size.x,size.z)*0.5,"SLALOM BLOCK")
        if not batched_art:
            obstacle_finish.register_block(block.global_transform,size,slalom_color)
    for i in range(3):
        var z = center_z + 2.3 - i * 3.5
        _cylinder(parent, Vector3(0, height_at(z)+0.65, z), 0.34, 1.3, BARRIER_COLORS[(n+2*i)%6],n)

func _register_exit_obstacle(body: Node3D, half_size: Vector2, label: String, peg := false, moving := false) -> void:
    var center := body.global_position
    if glacier_shutter_exit_active(center.z) and center.z < glacier_first_shutter_z:
        glacier_exit_obstacles.append({"position":center,"half_size":half_size,"label":label,"peg":peg})
    elif selected_track == 0 and center.z <= ShortcutRoute.EXIT_Z and (
            center.z >= ShortcutRoute.EXIT_Z-WOODWORKS_RETURN_DEPTH):
        woodworks_return_obstacles.append({"position":center,"half_size":half_size,"label":label,"peg":peg})
    elif selected_track == 2 and center.z-half_size.y < forge_first_piston_z and (
            center.z+half_size.y >= maxf(forge_first_piston_z-FORGE_PISTON_EXIT_REACH-3.0,ShortcutRoute.ENTRY_Z-0.5)):
        forge_piston_exit_obstacles.append({"position":center,"half_size":half_size,"label":label,
            "peg":peg,"moving":moving,"spinner":body if label == "PADDLE SWEEP" else null})

func _add_spinner(parent: Node3D, z: float, n: int) -> void:
    var pivot = AnimatableBody3D.new()
    pivot.name = "KineticPaddle_%02d" % n
    pivot.sync_to_physics = true
    pivot.position = Vector3(0.0, height_at(z) + 0.73, z)
    parent.add_child(pivot)
    var color = BARRIER_COLORS[(n + 1) % BARRIER_COLORS.size()]
    # A single wide paddle that rotates and pushes marbles physically.
    var sweep_radius := 0.0
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
        sweep_radius = maxf(sweep_radius,Vector2(arm_size.x,arm_size.z).length()*0.5)
        hit.shape = shape
        hit.rotation.y = spoke.rotation.y
        pivot.add_child(hit)
        MechanismArt.stripe_arm(spoke,arm_size, _mat(Color("#242936"),0.37,0.24))
    if selected_track == 2:
        _register_exit_obstacle(pivot,Vector2.ONE*sweep_radius,"PADDLE SWEEP",true,true)
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
    # Distinct but bounded rotational cadences across repeat layouts.
    # The paddles remain the same physical obstacles and leave the same gaps.
    var spinner_tempo: float = [0.88,1.0,1.12][posmod(built_variation+n,3)]
    pivot.set_meta("spin_speed", (1.0 if n%2==0 else -1.0) * (
        0.72+n*0.022)*(1.0+0.19*selected_track)*spinner_tempo)
    # Four floor markers trace the actual 3.55 m arm reach. Position
    # them at half the arm length so the warning does not extend beyond
    # the physical hazard or imply a collision in a safe corridor.
    var warning_radius: float = 3.55
    var guide_length: float = warning_radius-0.52
    var guide_material := _mat(Color("#e6b34d"),0.58,0.05)
    for guide in range(4):
        var warning := MeshInstance3D.new()
        warning.name = "SpinnerSweepGuide_%d" % guide
        var guide_mesh := BoxMesh.new()
        guide_mesh.size = Vector3(0.09,0.025,guide_length)
        warning.mesh = guide_mesh
        var angle: float = float(guide)*TAU/4.0
        var radial_center: float = guide_length*0.5
        warning.position = Vector3(
            pivot.position.x+sin(angle)*radial_center,
            height_at(z)+0.035,
            z+cos(angle)*radial_center)
        warning.rotation.y = angle
        warning.material_override = guide_material
        parent.add_child(warning)
    moving_obstacles.append(pivot)

func _make_start_gate() -> void:
    var z := StartGate.TRACK_Z
    start_gate = StartGate.new()
    start_gate.name = "StartGate"
    start_gate.position = Vector3(track_center_at(z),height_at(z),z)
    start_gate.setup(selected_track)
    board.add_child(start_gate)

func _make_finish_line() -> void:
    var finish := FinishLine.new()
    finish.name = "FinishLine"
    # Place the paint on the same tilted plank plane as the physical deck.
    var module_z := 8.0-roundf((8.0-FINISH_Z)/SEGMENT_LENGTH)*SEGMENT_LENGTH
    var grade := track_grade_at(module_z)
    var pitch := atan(grade)
    var floor_y := height_at(module_z)-0.34+0.325/cos(pitch)+grade*(FINISH_Z-module_z)
    finish_origin = Vector3(track_center_at(module_z),floor_y,FINISH_Z)
    finish.position = finish_origin
    finish.setup(selected_track,grade)
    board.add_child(finish)

func finish_crossing_fraction(previous: Vector3, current: Vector3) -> float:
    if previous.z < FINISH_Z or current.z >= FINISH_Z:
        return -1.0
    var fraction := (previous.z-FINISH_Z)/(previous.z-current.z)
    var crossing := previous.lerp(current,fraction)-finish_origin
    return fraction if absf(crossing.x) <= FINISH_HALF_WIDTH and (
        crossing.y >= 0.0 and crossing.y <= FINISH_AIR_CLEARANCE) else -1.0

func _edge_checkpoint_markers() -> void:
    var forge := selected_track == 2
    var biome_name: String = ["Woodworks","Glacier","Forge"][selected_track]
    var shell := _mat([Color("#564233"),Color("#315266"),Color("#51383b")][selected_track],0.34,0.62)
    var enamel := _mat([Color("#efc487"),Color("#a8efff"),Color("#f0b56a")][selected_track],0.41,0.18)
    var post_x := CourseSculptures.EDGE_SECTOR_POST_OFFSET
    var sign_y := CourseSculptures.EDGE_SECTOR_SIGN_HEIGHT
    var pillar := BoxMesh.new()
    pillar.size = Vector3(0.28,2.2,0.42)
    var plaque := BoxMesh.new()
    plaque.size = Vector3(1.28,0.88,0.26)
    var lip := BoxMesh.new()
    lip.size = Vector3(1.42,0.095,0.33)
    var assembly := SurfaceTool.new()
    assembly.append_from(pillar,0,Transform3D(Basis(),Vector3.UP*1.10))
    assembly.append_from(plaque,0,Transform3D(Basis(),Vector3.UP*sign_y))
    assembly.append_from(lip,0,Transform3D(Basis(),Vector3.UP*(sign_y+0.43)))
    var mesh := assembly.commit()
    var posts := MultiMesh.new()
    posts.transform_format = MultiMesh.TRANSFORM_3D
    posts.mesh = mesh
    posts.instance_count = CHECKPOINT_Z.size()*2
    var post_art := MultiMeshInstance3D.new()
    post_art.name = biome_name+"SectorPostBatch"
    post_art.multimesh = posts
    post_art.material_override = shell
    post_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    board.add_child(post_art)
    for sector in range(CHECKPOINT_Z.size()):
        var z: float = CHECKPOINT_Z[sector]
        var floor_y: float = height_at(z)
        var center_x: float = track_center_at(z)
        var marker := Node3D.new()
        marker.name = "%sSectorMarker%d" % [biome_name,sector+1]
        marker.position = Vector3(center_x,floor_y,z)
        board.add_child(marker)
        for flank in range(2):
            var side := -1.0 if flank == 0 else 1.0
            posts.set_instance_transform(sector*2+flank,Transform3D(
                Basis(),marker.position+Vector3(side*post_x,0,0)))
            var number := _floating_sign("SECTOR %02d" % (sector+1),
                Vector3(side*post_x,sign_y,0.148),marker)
            number.font_size = 32
            number.pixel_size = 0.0085
            number.billboard = BaseMaterial3D.BILLBOARD_DISABLED
            var stripe := _box(marker,Vector3(side*5.35,0.055,0),
                Vector3(0.98,0.02,0.32),enamel,false)
            stripe.rotation.x = -atan(track_grade_at(z))
            for paint in stripe.get_children():
                (paint as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _floating_sign(message: String, location: Vector3, parent: Node3D = null) -> Label3D:
    var label = Label3D.new()
    label.text = message
    label.font_size = 34
    label.pixel_size = 0.015
    label.outline_size = 6
    label.modulate = Color("#fff5e1")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = location
    var holder := board if parent == null else parent
    holder.add_child(label)
    return label

func _secondary_showroom_box(location: Vector3, dimensions: Vector3,
        material: Material, tilt := false) -> void:
    var holder := _box(board,location,dimensions,material,false,tilt)
    secondary_showroom_art.append(holder.get_child(0) as MeshInstance3D)

func _decorations() -> void:
    # Cleaner studio: keep real structural supports, omit the bright unrelated
    # carton towers that previously obscured obstacles in the distance.
    for k in range(12):
        var z = 5.0 - k * 17.0
        for side in [-1,1]:
            var x = side * 5.0
            _secondary_showroom_box(Vector3(x+track_center_at(z),height_at(z)-2.6,z),
                Vector3(0.6,4.4,0.65),_mat(Color("#79523b")))

func _showroom() -> void:
    # Warm miniature workshop: walnut workbench, paneled walls, lit windows and
    # hanging display lamps. Deliberately sparse near the play area for 60fps.
    for i in range(SEGMENTS):
        var z = 8.0 - i * SEGMENT_LENGTH
        _secondary_showroom_box(Vector3(0,height_at(z)-3.7,z),
            Vector3(35.0,0.75,SEGMENT_LENGTH+0.12),_wood_mat(Color("#604535")),true)
        for side in [-1.0,1.0]:
            var base_x = side * 17.0
            _box(board,Vector3(base_x,height_at(z)+4.5,z),
                Vector3(1.3,19.0,SEGMENT_LENGTH+0.05),_mat(Color("#37353a")),false)
            if i%2==0:
                _secondary_showroom_box(Vector3(base_x-side*0.73,height_at(z)+0.5,z),
                    Vector3(0.2,0.28,SEGMENT_LENGTH-0.6),_mat(Color("#957052"),0.64))
    # Exposed beams, side shelves and colored toy cartons.
    for i in range(8):
        var z = 7.5-i*25.0
        for side in [-1.0,1.0]:
            var x=side*15.5
            _secondary_showroom_box(Vector3(x,height_at(z)+3.9,z),Vector3(2.5,0.28,8.5),
                _wood_mat(Color("#91715a")))
            # One restrained branded trophy block per shelf (rather than
            # two random bright boxes) reduces clutter and draw calls.
            var trophy_color: Color = TRACK_COLORS[selected_track].darkened(0.34)
            _secondary_showroom_box(Vector3(x-side*0.25,height_at(z)+4.5,z),
                Vector3(0.80,0.85,1.15),_mat(trophy_color,0.37,0.22))
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
        secondary_showroom_art.append(glass)
    # Deep charcoal overhead beam frames the miniature track without glare.
    var roof := _box(board,Vector3(0,SHOWROOM_ROOF_HEIGHT,-80),
        Vector3(38,SHOWROOM_ROOF_THICKNESS,192),_mat(Color("#343339")),false)
    roof.name = "ShowroomRoofBeam"
    showroom_roof = roof.get_child(0) as MeshInstance3D

func _spawn_racers() -> void:
    marble_detail_refresh = 0.0
    for m in racers:
        if is_instance_valid(m):
            remove_child(m)
            m.queue_free()
    racers.clear()
    racer_finish_order.clear()
    finish_crossings.clear()
    finish_step_end = -INF
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
    if net.role != "server":
        rival_render.refresh(racers,camera)

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
    var ice_impact := false
    if net.role == "offline":
        ice_impact = airtime.observe_ice_impact(body,player)
        if not ice_impact:
            audio._on_marble_collision(body)
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.notify_contact(body,intensity)
    if intensity < 0.17 or feedback_cooldown > 0.0:
        return
    camera_shake = minf(0.14,camera_shake+RaceFeedback.shake_strength(intensity))
    if not ice_impact:
        obstacle_notice = 0.46 if intensity > 0.45 else 0.22
    feedback_cooldown = RaceFeedback.feedback_interval(intensity)

func sector_entry_z(sector: int) -> float:
    return race_start_z if sector == 0 else CHECKPOINT_Z[sector-1]

func start_race(perk_name: String, sector_to_practice := -1, previous_sector_time := NAN,
        previous_passages := PackedFloat64Array(), passage_to_practice := 0) -> void:
    selected_perk = perk_name
    practice_sector = sector_to_practice if (
        not net.is_active() and sector_to_practice >= 0 and sector_to_practice <= CHECKPOINT_Z.size()) else -1
    practice_passage = passage_to_practice if practice_sector >= 0 and (
        passage_to_practice >= 1 and passage_to_practice <= PracticeTiming.PASSAGES) else 0
    practice_previous_time = previous_sector_time if (
        practice_sector >= 0 and is_finite(previous_sector_time) and previous_sector_time > 0.0) else NAN
    practice_previous_passages = previous_passages if is_finite(practice_previous_time) else PackedFloat64Array()
    if not net.is_active():
        career.begin()
    result_saved = false
    last_result = {}
    # Alternating geometry order on repeat attempts avoids an identical course
    # without changing the course identity or difficulty.
    if not is_instance_valid(board) or race_variation != built_variation or (
        int(board.get_meta("track_index",-1)) != selected_track or
        board.get_meta("solo_course_clearance") != _uses_solo_course_clearance(race_variation)):
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
    race_start_z = player.position.z
    if not net.is_active():
        practice_timing.begin(player.position,CHECKPOINT_Z,FINISH_Z)
    if is_instance_valid(race_items):
        race_items.reset_round()
    if is_instance_valid(course_mechanics):
        course_mechanics.reset_round()
    if is_instance_valid(arcade_bumpers):
        arcade_bumpers.reset_pulses()
    if is_instance_valid(course_sculptures):
        course_sculptures.reset_round()
    if is_instance_valid(airtime):
        airtime.reset_round()
    if is_instance_valid(race_director):
        race_director.reset_round()
    if is_instance_valid(shortcut_route):
        shortcut_route.reset_round()
    best_ghost.begin(selected_track,built_variation,selected_perk,not net.is_active())
    audio.bind_marble(player)
    player.body_entered.connect(_camera_bump)
    audio.begin_race()
    last_count = -1
    start_gate.set_signal(-1)
    ui.show_race_ui()
    ui.show_countdown("READY")
    _update_camera(0.1, true)

func restart_race() -> void:
    start_race(selected_perk)

func retry_current_layout(sector_to_practice := -1) -> void:
    var previous_time := NAN
    var passages := PackedFloat64Array()
    var target_passage := 0
    if race_state == "RESULTS" and bool(last_result.get("finished",false)):
        var times: Array = last_result.get("sector_times",[])
        if times.size() == CHECKPOINT_Z.size()+1 and sector_to_practice >= 0 and sector_to_practice < times.size():
            previous_time = float(times[sector_to_practice])
            var recorded: Array = last_result.get("passage_times",[])
            if sector_to_practice < recorded.size():
                passages = recorded[sector_to_practice]
            var practice: Dictionary = last_result.get("practice_comparison",{})
            if int(practice.get("sector",-1)) == sector_to_practice:
                var loss: Dictionary = practice.get("worst_passage",{})
                target_passage = int(loss.get("number",0))
    elif race_state in ["COUNTDOWN","RACING"] and sector_to_practice == practice_sector:
        previous_time = practice_previous_time
        passages = practice_previous_passages
        target_passage = practice_passage
    race_variation = built_variation
    kinetic_time = 0.0
    for obstacle in moving_obstacles:
        if is_instance_valid(obstacle):
            obstacle.rotation = Vector3.ZERO
    start_race(selected_perk,sector_to_practice,previous_time,passages,target_passage)

func return_to_menu() -> void:
    practice_sector = -1
    practice_passage = 0
    practice_previous_time = NAN
    practice_previous_passages.clear()
    if race_moments != null:
        race_moments.reset_round()
    if is_instance_valid(airtime):
        airtime.reset_round()
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
    player = null
    if is_instance_valid(contact_shadows):
        contact_shadows.clear_racers()
    rival_render.clear()
    start_gate.set_signal(-1)
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
    if is_instance_valid(airtime):
        airtime.advance_visuals(delta)
    if race_state == "RACING" and is_instance_valid(course_sculptures):
        course_sculptures.advance_visuals(delta)
    if show_fps and is_instance_valid(player) and not player.finished and not player.eliminated:
        if race_state == "COUNTDOWN" and countdown <= PerformanceBudget.GRID_SECONDS:
            performance_budget.record_frame(Time.get_ticks_usec(),-1,PerformanceBudget.Focus.GRID)
        elif race_state == "RACING":
            var z := player.position.z
            var phase := 2 if z <= CHECKPOINT_Z[-1] else int(z <= CHECKPOINT_Z[0])
            var focus := PerformanceBudget.focus_at(race_time,z,ShortcutRoute.EXIT_Z)
            var near_opening := PerformanceBudget.near_first_obstacle(z,first_obstacle_entry_z)
            performance_budget.record_frame(Time.get_ticks_usec(),phase,focus,near_opening)
    world_time += delta
    var replica_speed := -1.0
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
    if race_state == "COUNTDOWN":
        countdown -= delta
        if countdown > 0.0:
            var count := int(ceil(countdown))
            if count != last_count and count < 4:
                start_gate.set_signal(count)
                ui.show_countdown(str(count))
                audio.tone("count")
                last_count = count
        else:
            race_state = "RACING"
            if not net.is_client():
                for m in racers:
                    m.freeze = false
                    m.sleeping = false
            ui.show_countdown("GO!")
            start_gate.set_signal(0)
            audio.tone("start")
    elif race_state == "RACING":
        if net.is_client() and is_instance_valid(player) and not player.finished and not player.eliminated:
            var replica_velocity: Vector3 = net.local_replica_velocity()
            if replica_velocity.is_finite():
                replica_speed = Vector2(replica_velocity.x,replica_velocity.z).length()
        race_time += delta
        if not net.is_active() and is_instance_valid(player) and not player.finished and not player.eliminated:
            practice_timing.sample(self,player.position,race_time)
        if is_instance_valid(best_ghost) and is_instance_valid(player):
            best_ghost.tick(race_time,player.global_position,graphics_quality)
        if race_time > 1.0 and start_gate.signal_stage == 0:
            ui.hide_countdown()
            start_gate.set_signal(-1)
        if is_instance_valid(trail) and is_instance_valid(player):
            audio.update_progress(clampf(-player.position.z/absf(FINISH_Z),0.0,1.0))
            var speed: float = replica_speed if net.is_client() else player.linear_velocity.length()
            trail.emitting = graphics_quality > 0 and speed > 4.0
            trail.initial_velocity_max = 2.6 if boosting else 0.75
            trail.color = PremiumSkinVisuals.trail_tint(self,boosting)
            if is_instance_valid(airtime) and not boosting and (
                    not is_instance_valid(skins) or skins.active_id() < 0):
                var tint_weight := maxf(0.32 if airtime.bridge_grounded else 0.0,0.62*airtime.ice_skid)
                tint_weight = maxf(tint_weight,0.78*airtime.ice_entry_weight())
                trail.color = trail.color.lerp(AirtimeDirector.BRIDGE_TINTS[selected_track],tint_weight)
            var cp := -1
            for sector in range(CHECKPOINT_Z.size()-1,-1,-1):
                if player.position.z < float(CHECKPOINT_Z[sector]):
                    cp = sector
                    break
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
                    var ghost_delta: float = NAN
                    if not net.is_active() and checkpoint_splits.size() == sector+1:
                        ghost_delta = best_ghost.crossing_delta(sector,race_time)
                    ui.show_checkpoint(sector+1,duration,prior_best,ghost_delta)
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
        _update_marble_detail(delta)
        ui.update_hud()
    if not racers.is_empty() and net.role != "server":
        rival_render.refresh(racers,camera)
    # Audio tension reads the local HUD's existing 10Hz physics snapshot.
    # No extra 40-racer scans, AI updates or online rewards.
    if is_instance_valid(audio):
        audio.set_pack_pressure(race_moments.pack_pressure if (
            race_state == "RACING" and race_moments != null and
            net.role != "server") else 0.0)
        audio.set_flight_intensity(airtime.camera_weight() if (
            race_state == "RACING" and is_instance_valid(airtime)) else 0.0)
        var local_surface: bool = race_state == "RACING" and is_instance_valid(airtime) and (
            is_instance_valid(player) and not player.finished and not player.eliminated)
        audio.set_bridge_surface(local_surface and airtime.rolling_surface == AirtimeDirector.Surface.BRIDGE,
            local_surface and airtime.bridge_grounded,replica_speed)
        audio.set_ice_feedback(local_surface and airtime.glacier_grip == AirtimeDirector.Grip.ICE,
            local_surface and airtime.ice_touching,airtime.ice_skid if local_surface else 0.0,
            airtime.ice_entry_weight() if local_surface else 0.0)
        audio.set_control_recovery(airtime.control_weight() if local_surface else 0.0)
        var drive_audio: bool = local_surface and net.role != "server" and (
            replica_speed >= 0.0 if net.is_client() else not player.freeze)
        audio.set_drive_context(drive_audio and boosting and boost_energy > 0.0,
            race_moments.turn_weight if drive_audio and race_moments != null else 0.0,
            race_moments.exit_speed_weight() if drive_audio and race_moments != null else 0.0)

func _physics_process(delta: float) -> void:
    steer = move_toward(steer,steer_target,delta*8.5)
    # Drive mechanisms from a shared timebase instead of accumulating
    # spinner rotations. Clamp mobile resume hitches without changing the
    # physics-step motion cadence or abruptly resetting hammer phases.
    if is_finite(delta) and delta > 0.0:
        kinetic_time += minf(delta,0.10)
    for obj in moving_obstacles:
        if not is_instance_valid(obj):
            continue
        if obj.get_meta("motion_kind", "") == "spinner":
            obj.rotation.y = fposmod(kinetic_time*float(
                obj.get_meta("spin_speed")),TAU)
        else:
            obj.rotation.z = sin(kinetic_time*float(
                obj.get_meta("speed"))+float(obj.get_meta("phase")))*0.65
    if is_instance_valid(race_director) and race_state == "RACING":
        # All clients animate the same scripted hazards; only authority
        # awards gameplay physics when a marble actually makes a near-miss.
        race_director.animate(race_time)
    if race_state == "RACING" and is_instance_valid(airtime):
        airtime.tick_physics(delta)
    if race_state != "RACING" or net.is_client():
        return
    if is_instance_valid(ui) and ui.woodworks_guide_active and not net.is_active() and (
        is_instance_valid(player) and not player.freeze and not player.finished and not player.eliminated):
        ui.record_woodworks_controls(steer,boosting and boost_energy > 0.0)
    if is_instance_valid(race_items):
        race_items.tick(delta,racers,net)
    if is_instance_valid(course_mechanics):
        course_mechanics.tick(delta,racers,net)
    if is_instance_valid(shortcut_route):
        shortcut_route.tick(delta,racers,net)
    if is_instance_valid(race_director):
        race_director.tick(racers,net)
    if is_instance_valid(course_sculptures):
        course_sculptures.tick(racers,net)
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
    finish_crossings.clear()
    # Several physics ticks can share one render-clock timestamp. Keep
    # consecutive finish intervals ordered without changing the race clock.
    var sample_end := maxf(race_time,finish_step_end+delta)
    for m in racers:
        if not is_instance_valid(m):
            continue
        var remote_input: Vector2 = net.input_for_slot(m.racer_id) if net.is_host() and m.network_controlled else Vector2.ZERO
        # Online participants always use server-validated commands, including slot 39.
        var axis: float = remote_input.x if m.network_controlled else (steer if m.is_player and not net.is_host() else 0.0)
        var turbo: bool = remote_input.y>0.5 if m.network_controlled else (boosting and boost_energy>0.0 and m.is_player and not net.is_host())
        m.drive(delta,race_time,axis,turbo)
        var current: Vector3 = m.position
        var fraction := finish_crossing_fraction(m.previous_race_position,current) if (
            not m.finished and not m.eliminated) else -1.0
        m.previous_race_position = current
        if fraction >= 0.0:
            m.finished = true
            m.finish_time = maxf(0.0,sample_end-delta*(1.0-fraction))
            m.freeze = true
            # A finished frozen sphere must not become a permanent obstacle
            # at the timing stripe. Keep it for ranking, disable its contacts.
            m.set_deferred("collision_layer",0)
            m.set_deferred("collision_mask",0)
            finish_crossings.append(m)
    if not finish_crossings.is_empty():
        finish_step_end = sample_end
        finish_crossings.sort_custom(_finisher_precedes)
        for m in finish_crossings:
            racer_finish_order.append(m.display_name)
        if not net.is_active() and race_moments != null and is_instance_valid(player) and player.finished:
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

func _update_marble_detail(delta: float) -> void:
    if graphics_quality != 1 or net.role == "server" or not (
        is_instance_valid(player) and is_instance_valid(camera)):
        return
    marble_detail_refresh -= delta
    if marble_detail_refresh > 0.0:
        return
    marble_detail_refresh = MARBLE_DETAIL_INTERVAL
    var eye := camera.global_position
    var forward := -camera.global_basis.z
    var driver := player.global_position
    var diameter_scale := 720.0*Racer.RADIUS/tan(deg_to_rad(camera.fov*0.5))
    var featured: RigidBody3D = race_moments.closest_rival if race_moments != null else null
    for marble in racers:
        if not is_instance_valid(marble) or marble == player:
            continue
        var at := marble.global_position
        var depth := forward.dot(at-eye)
        var keep_detail := marble == featured or at.distance_squared_to(driver) <= (
            MARBLE_DETAIL_NEAR_DISTANCE_SQUARED)
        marble.update_render_detail(diameter_scale/maxf(depth,0.01),keep_detail)

func _update_camera(delta: float, force := false) -> void:
    if not is_instance_valid(camera):
        return
    if race_state == "MENU" or not is_instance_valid(player):
        camera_shake = 0.0
        camera_previous_racer_z = NAN
        camera.set_meta("previous_jitter",Vector3.ZERO)
        camera.set_meta("smoothed_bank",0.0)
        camera.set_meta("smoothed_fov",64.0)
        _position_intro_camera(force)
        _update_roof_visibility()
        return
    # A corrupt physics sample during Android resume must not reach the
    # course-height functions or camera.look_at(). Keep the last valid view
    # until the rigidbody reports a finite transform again.
    if not player.global_position.is_finite() or (
        not player.linear_velocity.is_finite()):
        camera_shake = 0.0
        camera.set_meta("previous_jitter",Vector3.ZERO)
        return
    # Use the centerline ahead so the racer can see approaching turns.
    # Pure math; multiplayer does not need camera replication.
    var racer_z := player.global_position.z
    var ahead_x: float = track_center_at(racer_z-12.0)
    var behind_x: float = track_center_at(racer_z+5.0)
    var next_gate: Dictionary = upcoming_hazard(racer_z)
    var distance: float = float(next_gate.get("distance",-1.0))
    var airborne_weight: float = airtime.camera_weight() if is_instance_valid(airtime) else 0.0
    var jump_preview: Dictionary = airtime.jump_preview if cam_mode == 0 and race_state == "RACING" and (
        not player.finished and not player.eliminated and is_instance_valid(airtime)) else {}
    var velocity: Vector3 = player.linear_velocity
    if net.is_client() and race_state == "RACING" and cam_mode == 0:
        var replica: Vector3 = net.local_replica_velocity()
        if replica.is_finite():
            velocity = replica
        else:
            velocity = Vector3.ZERO
            jump_preview = {}
    var forge_view: bool = selected_track == 2 and cam_mode == 0 and race_state == "RACING" and (
        not player.finished and not player.eliminated and is_instance_valid(final_obstacle_art))
    var woodworks_view: bool = selected_track == 0 and cam_mode == 0 and race_state == "RACING" and (
        not player.finished and not player.eliminated and is_instance_valid(opening_obstacle_art))
    if woodworks_view and is_instance_valid(shortcut_route) and (
            shortcut_route.on_separate_deck(player.global_position)):
        var deck_weight := smoothstep(0.0,4.0,ShortcutRoute.OUTER_START-racer_z)*(
            smoothstep(0.0,5.0,racer_z-ShortcutRoute.OUTER_END))
        var deck_ahead: Vector3 = shortcut_route.point_at(maxf(racer_z-12.0,ShortcutRoute.OUTER_END))
        var deck_behind: Vector3 = shortcut_route.point_at(racer_z+5.0)
        ahead_x = lerpf(ahead_x,deck_ahead.x,deck_weight)
        behind_x = lerpf(behind_x,deck_behind.x,deck_weight)
    var reading_art: MeshInstance3D = final_obstacle_art if forge_view else (
        opening_obstacle_art if woodworks_view else null)
    if reading_art != null and racer_z >= reading_art.clear_z:
        var release := 1.0-smoothstep(0.0,3.5,racer_z-reading_art.clear_z)
        var module_distance := maxf(racer_z-reading_art.entry_z,release*RaceFeedback.HAZARD_MAX_PREVIEW)
        distance = minf(distance,module_distance) if distance >= 0.0 else module_distance

    var pose: Dictionary = RaceFeedback.camera_pose(
        player.global_position,velocity,
        ahead_x,cam_mode,boosting,distance,
        race_moments != null and race_state == "RACING" and
        race_moments.side_by_side_active,
        airborne_weight,
        float(race_moments.closest_rival_side) if race_moments != null else 0.0,
        race_moments.pack_pressure if race_moments != null and race_state == "RACING" else 0.0,
        jump_preview,
        race_moments.evasion_target if race_moments != null and race_state == "RACING" and (
            not net.is_client() or velocity != Vector3.ZERO) else Vector3.INF)
    var desired: Vector3 = pose["position"]
    var focus: Vector3 = pose["focus"]
    var target_fov: float = pose["fov"]
    if forge_view and jump_preview.is_empty():
        var clear_z := minf(final_straight_z,final_obstacle_art.clear_z)
        var finish_weight := RaceFeedback.finish_focus_weight(racer_z,clear_z,FINISH_Z,-velocity.z)*(
            1.0-0.65*airborne_weight)
        var target := Vector3(finish_origin.x,finish_origin.y+1.3,minf(focus.z,FINISH_Z))
        focus = focus.lerp(target,finish_weight*0.58)
        desired.y += finish_weight*0.56
    elif woodworks_view or (selected_track == 1 and cam_mode == 0 and race_state == "RACING" and (
            not player.finished and not player.eliminated)):
        var clear_z := final_straight_z
        if woodworks_view and is_instance_valid(final_obstacle_art):
            clear_z = minf(clear_z,final_obstacle_art.clear_z)
        var weight := RaceFeedback.finish_view_weight(racer_z,clear_z,FINISH_Z,-velocity.z)
        var competing_cue := maxf(airborne_weight,float(jump_preview.get("weight",0.0)))
        if woodworks_view and race_moments != null and race_moments.evasion_target.is_finite():
            competing_cue = 1.0
        weight *= 1.0-0.65*competing_cue
        if weight > 0.0:
            var rival: RigidBody3D = race_moments.closest_rival if (
                race_moments != null and race_moments.side_by_side_active) else null
            var offset := Vector3.ZERO
            if is_instance_valid(rival) and not rival.finished and not rival.eliminated:
                var separation := rival.global_position-player.global_position
                if absf(separation.x) >= 0.55 and absf(separation.x) <= 2.65 and (
                        absf(separation.z) <= 1.70 and absf(separation.y) <= 1.25):
                    offset = separation
            var has_pair := offset != Vector3.ZERO
            var pair_x := player.global_position.x+offset.x*0.5
            var finish_weight := RaceFeedback.finish_focus_weight(racer_z,clear_z,FINISH_Z,-velocity.z)
            var line_x := lerpf(ahead_x,finish_origin.x,finish_weight)
            var reading_x := lerpf(line_x,pair_x,0.62 if has_pair else 0.18)
            desired.x = lerpf(desired.x,pair_x,0.72*weight) if has_pair else desired.x
            desired.y += weight*(1.0 if has_pair else 0.54)
            desired.z += weight*(0.72 if has_pair else 0.23)
            focus.x = lerpf(focus.x,reading_x,weight*0.65)
            focus.z = lerpf(focus.z,minf(focus.z,FINISH_Z),finish_weight*weight*0.56)
            target_fov = minf(RaceFeedback.FOV_MAX,target_fov+weight*(1.25 if has_pair else 0.45))
    # Match the camera to the real 3D grade without per-frame raycasts.
    focus = RaceFeedback.terrain_safe_focus(focus,height_at(focus.z))
    desired = RaceFeedback.terrain_safe_camera(desired,height_at(desired.z))
    var previous_jitter: Vector3 = camera.get_meta(
        "previous_jitter",Vector3.ZERO)
    if not previous_jitter.is_finite():
        previous_jitter = Vector3.ZERO
    var follow_rate: float = lerpf(4.5,6.0,float(pose["pace"]))
    var step: float = RaceFeedback.smooth_factor(delta,follow_rate)
    var forward_step := Vector3.ZERO
    if race_state == "RACING" and cam_mode == 0 and not force:
        forward_step.z = RaceFeedback.chase_forward_step(
            racer_z-camera_previous_racer_z,delta)
    camera_previous_racer_z = racer_z
    var base: Vector3 = camera.global_position-previous_jitter+forward_step
    # Combine physical forward-motion continuity with Android resume and
    # checkpoint-jump snap guards. Neither changes the rigidbody state.
    var snap_camera: bool = force or not base.is_finite() or (
        base.distance_squared_to(desired) > 36.0*36.0)
    camera.global_position = desired if snap_camera else base.lerp(desired,step)
    var focus_step: float = RaceFeedback.smooth_factor(delta,7.0)
    var shifted_focus: Vector3 = camera_lookahead+forward_step
    var snap_focus: bool = snap_camera or not shifted_focus.is_finite() or (
        shifted_focus.distance_squared_to(focus) > 36.0*36.0)
    camera_lookahead = focus if snap_focus else shifted_focus.lerp(

        focus,focus_step)
    # A recovery teleport is not a collision. Drop any residual shake so
    # the newly snapped camera does not jump on the very next rendered frame.
    if snap_camera:
        camera_shake = 0.0
    camera_shake *= exp(-clampf(delta,0.0,0.12)*9.5)
    var jitter := Vector3(sin(world_time*52.0),
        cos(world_time*47.0),0.0)*camera_shake
    camera.global_position += jitter
    camera.set_meta("previous_jitter",jitter)
    # look_at() requires a distinct target. Guard pathological camera
    # transforms without disturbing the normal smooth-follow path.
    if camera.global_position.is_finite() and (
        camera_lookahead.is_finite()) and (
        camera.global_position.distance_squared_to(camera_lookahead) > 0.0001):
        camera.look_at(camera_lookahead,Vector3.UP)
    # Light, reversible banking follows only real lateral velocity and the
    # course centreline. Never rotate a physics node or override overhead
    # camera choices. Stays below 2.6 degrees even at the 24m/s speed cap.
    var curve_delta: float = ahead_x-track_center_at(
        player.global_position.z+5.0)
    var target_bank: float = RaceFeedback.camera_roll(
        player.linear_velocity.x,-player.linear_velocity.z,
        curve_delta,cam_mode)
    # Smooth steering-induced banking to prevent one-frame twitching when
    # lateral velocity flips on mobile. Keep alternate views level.
    var previous_bank: float = float(camera.get_meta("smoothed_bank",0.0))
    if not is_finite(previous_bank):
        previous_bank = 0.0
    var bank: float = lerpf(previous_bank,target_bank,
        RaceFeedback.smooth_factor(delta,9.0))
    if force or not is_finite(bank):
        bank = target_bank
    camera.set_meta("smoothed_bank",bank)
    camera.rotate_object_local(Vector3.FORWARD,bank)
    # A quick lens response sells a real turbo activation, while a slower
    # recovery prevents FOV pumping when boost is tapped repeatedly.
    var previous_fov: float = float(camera.get_meta("smoothed_fov",camera.fov))
    if not is_finite(previous_fov):
        previous_fov = 64.0
    var fov_rate: float = 8.5 if target_fov > previous_fov else 3.8
    var smoothed_fov: float = target_fov if force else lerpf(
        previous_fov,target_fov,RaceFeedback.smooth_factor(delta,fov_rate))
    camera.fov = clampf(smoothed_fov,63.0,78.0)
    camera.set_meta("smoothed_fov",camera.fov)
    _update_roof_visibility()

func _update_roof_visibility() -> void:
    if not is_instance_valid(showroom_roof):
        return
    # Cut away the ceiling for elevated viewpoints while keeping its
    # cast shadow. Use the actual eye so the transition is safe as well.
    var underside := showroom_roof.global_position.y-SHOWROOM_ROOF_THICKNESS*0.5
    var roof_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if (
        camera.global_position.y >= underside-camera.near) else (
        GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
    if showroom_roof.cast_shadow != roof_mode:
        showroom_roof.cast_shadow = roof_mode


func _position_intro_camera(force: bool) -> void:
    var target = Vector3(6.5, 12.6, 22.0)
    var focus = Vector3(0, 0, -9)
    camera.global_position = target if force else camera.global_position.lerp(target, 0.035)
    camera.look_at(focus, Vector3.UP)

static func _finisher_precedes(a: RigidBody3D, b: RigidBody3D) -> bool:
    return a.racer_id < b.racer_id if a.finish_time == b.finish_time else a.finish_time < b.finish_time

func get_rankings() -> Array:
    var copy = racers.duplicate()
    copy.sort_custom(func(a,b):
        if a.finished != b.finished:
            return a.finished
        if a.finished and b.finished:
            return _finisher_precedes(a,b)
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
    boosting = value and boost_energy > 0.03

func _unhandled_input(event: InputEvent) -> void:
    if race_state != "RACING" or ui.online_leave_layer.visible or (
            is_instance_valid(player) and player.finished):
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
    start_gate.set_signal(-1)
    ui.hide_countdown()
    if is_instance_valid(player) and player.finished:
        _burst(player.global_position, true)
    race_state = "RESULTS"
    boosting = false
    steer = 0.0
    steer_target = 0.0
    if not result_saved:
        result_saved = true
        var completed: bool = is_instance_valid(player) and player.finished
        var outcome := "FINISHED" if completed else "DNF"
        if not completed and not net.is_active():
            outcome = "OFF TRACK" if is_instance_valid(player) and player.eliminated else "TIME OUT"
        var durations: Array[float] = []
        var previous_split := 0.0
        for elapsed in checkpoint_splits:
            durations.append(maxf(0.01,elapsed-previous_split))
            previous_split = elapsed
        if completed and checkpoint_splits.size() == CHECKPOINT_Z.size():
            var finish_at: float = player.finish_time
            if is_finite(finish_at) and finish_at > previous_split:
                durations.append(finish_at-previous_split)
        var complete_sectors := durations.size() == CHECKPOINT_Z.size()+1
        var ghost_deltas: Array[float] = []
        var ghost_record: bool = false
        if not net.is_active() and is_instance_valid(best_ghost):
            if completed and best_ghost.replay_available:
                for sector in CHECKPOINT_Z.size():
                    # Compare to the ghost that started this race, before saving a new PB.
                    var gap: float = best_ghost.crossing_delta(sector,checkpoint_splits[sector]) if (
                        complete_sectors) else NAN
                    ghost_deltas.append(gap)
                ghost_deltas.append(best_ghost.crossing_delta(CHECKPOINT_Z.size(),player.finish_time))
            ghost_record = best_ghost.finish(player.finish_time if completed else race_time,
                completed,PackedFloat64Array(checkpoint_splits))
        if net.is_active():
            # Network races have physical results but never rewrite solo career.
            last_result = {"finished":completed,"stars":0,"record":false,"unlocked":false}
        else:
            last_result = career.complete(selected_track,player_rank(),
                player.finish_time if completed else race_time,completed)
        last_result["outcome"] = outcome
        last_result["ghost_record"] = ghost_record
        last_result["ghost_deltas"] = ghost_deltas
        last_result["clean_passes"] = race_director.clean_pass_count(player.racer_id) if (
            is_instance_valid(race_director) and is_instance_valid(player)) else 0
        last_result["apex_passes"] = course_sculptures.apex_pass_count(
            player.racer_id) if is_instance_valid(course_sculptures) and (
            is_instance_valid(player) and not net.is_active()) else 0
        # A genuine sequence of three bridge lines is measured on the
        # authoritative offline physics simulation only. Remote clients
        # never feed counters into career, medals or store purchases.
        last_result["bridge_gates"] = shortcut_route.bridge_gate_count(
            player.racer_id) if is_instance_valid(shortcut_route) and (
            is_instance_valid(player) and not net.is_active()) else 0
        last_result["perfect_bridge"] = shortcut_route.precision_complete.has(
            player.racer_id) if is_instance_valid(shortcut_route) and (
            is_instance_valid(player) and not net.is_active()) else false
        # Measured client-side feel stats never become trusted league rewards.
        last_result["airtime_landings"] = airtime.landing_count if (
            is_instance_valid(airtime) and not net.is_active()) else 0
        last_result["airtime_best"] = airtime.longest_airtime if (
            is_instance_valid(airtime) and not net.is_active()) else 0.0
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
        if completed and complete_sectors and not net.is_active():
            var passage_times: Array[PackedFloat64Array] = []
            for sector in durations.size():
                var entry := 0.0 if sector == 0 else checkpoint_splits[sector-1]
                var exit: float = player.finish_time if sector == CHECKPOINT_Z.size() else checkpoint_splits[sector]
                passage_times.append(practice_timing.durations(sector,entry,exit))
            last_result["passage_times"] = passage_times
            if practice_sector >= 0 and is_finite(practice_previous_time):
                var current_passages := passage_times[practice_sector]
                last_result["practice_comparison"] = {
                    "sector":practice_sector,"previous":practice_previous_time,
                    "target_passage":PracticeTiming.target_comparison(practice_passage,
                        practice_previous_passages,current_passages),
                    "worst_passage":practice_timing.worst_loss(practice_sector,
                        practice_previous_passages,current_passages)}
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
    var recorded_time: float = player.finish_time if is_instance_valid(player) and player.finished else race_time
    var rankings := get_rankings()
    ui.show_results(rankings.find(player)+1,recorded_time,rankings)
