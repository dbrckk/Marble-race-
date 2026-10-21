extends RigidBody3D
## Rigid-body racer with visually distinct procedurally marbled glass.
signal crossed_finish(racer)
signal fell_off(racer)

const SHADER = preload("res://shaders/marble.gdshader")
const AIPath = preload("res://scripts/ai_race_strategy.gd")
static var mesh_cache: Dictionary = {}
static var default_physics: PhysicsMaterial

static func get_sphere(high_detail: bool, quality: int) -> SphereMesh:
    var key := "%d-%d" % [int(high_detail),quality]
    if mesh_cache.has(key):
        return mesh_cache[key]
    var sphere := SphereMesh.new()
    sphere.radius = RADIUS
    sphere.height = RADIUS * 2.0
    if quality == 0:
        sphere.radial_segments = 22 if high_detail else 14
        sphere.rings = 10 if high_detail else 7
    elif quality == 2:
        sphere.radial_segments = 40 if high_detail else 28
        sphere.rings = 20 if high_detail else 14
    else:
        sphere.radial_segments = 32 if high_detail else 24
        sphere.rings = 16 if high_detail else 12
    mesh_cache[key] = sphere
    return sphere

func set_render_quality(quality: int) -> void:
    if is_instance_valid(mesh):
        mesh.mesh = get_sphere(is_player,quality)
        if is_instance_valid(glass_material):
            glass_material.set_shader_parameter("visual_quality",float(clampi(quality,0,2)))
const RADIUS := 0.39
const PALETTE := [
    Color("#e98739"), Color("#46adb4"), Color("#e45d88"), Color("#a75ad0"),
    Color("#76bc64"), Color("#f1c353"), Color("#e76850"), Color("#468fdc"),
    Color("#e6e1e1"), Color("#bb6c50"), Color("#598c68"), Color("#384d9a")
]
const NAMES := [
    "Copper", "Turquoise", "Rosie", "Orchid", "Lucky Green", "Sunburst",
    "Ruby", "Blue Marble", "Snowfall", "Cinnamon", "Moss", "Midnight",
    "Tiger Eye", "Violet", "Lucky", "Poppy", "Spark", "Drift", "Mango",
    "Jasper", "Rainbow", "Atlas", "Comet", "Bolt", "Pebble", "Cobalt",
    "Swirl", "Mint", "Saffron", "Frost", "Plum", "Amber", "Quartz",
    "Bubble", "Blizzard", "Jade", "Nova", "Ripple", "Opal", "YOU"
]

var racer_id := 0
var course_owner: Node3D
var display_name := ""
var is_player := false
var network_controlled := false
var finished := false
var eliminated := false
var finish_time := 0.0
var perk := ""
var track_direction := -1.0
var mesh: MeshInstance3D
var collision: CollisionShape3D
var seed_value := 0.0
var target_sway := 0.0
var stuck_seconds := 0.0
var recovery_count := 0
var progress_anchor_z := 0.0
var progress_stall_seconds := 0.0
var boost_ring: MeshInstance3D
var glass_material: ShaderMaterial
var boost_glow := 0.0
var ai_lane_goal := 0.0
var ai_lane_timer := 0.0
var last_boosting := false

func setup(index: int, player: bool, base_position: Vector3, chosen_perk: String = "") -> void:
    racer_id = index
    is_player = player
    display_name = "YOU" if player else NAMES[index % (NAMES.size() - 1)]
    perk = chosen_perk if player else ""
    seed_value = float(index) * 2.317
    name = "Marble_%02d" % index
    position = base_position
    progress_anchor_z = base_position.z
    mass = 0.73
    gravity_scale = 1.0
    linear_damp = 0.20
    angular_damp = 0.16
    continuous_cd = true
    can_sleep = false
    contact_monitor = false
    if default_physics == null:
        default_physics = PhysicsMaterial.new()
        default_physics.friction = 0.72
        default_physics.bounce = 0.19
    physics_material_override = default_physics.duplicate() if is_player else default_physics

    if perk == "Lead Core":
        mass = 1.65
    elif perk == "Grip Tape":
        physics_material_override.friction = 1.28
    elif perk == "Bounce Back":
        physics_material_override.bounce = 0.80
    elif perk == "Aerodynamic":
        linear_damp = 0.045

    mesh = MeshInstance3D.new()
    mesh.name = "ArtGlass"
    mesh.mesh = get_sphere(is_player,1)
    var material = ShaderMaterial.new()
    material.shader = SHADER
    var base: Color = PALETTE[index % PALETTE.size()]
    var accent: Color = PALETTE[(index * 7 + 5) % PALETTE.size()]
    if player:
        base = Color("#f29b48")
        accent = Color("#542b1d")
    material.set_shader_parameter("base_color", base)
    material.set_shader_parameter("accent_color", accent)
    material.set_shader_parameter("vein_color", Color(0.98, 0.94, 0.82) if index % 3 == 0 else Color(0.75, 0.92, 0.93))
    material.set_shader_parameter("pattern_seed", seed_value)
    material.set_shader_parameter("stripe_scale", 0.3 + float(index % 7) * 0.29)
    glass_material = material
    material.set_shader_parameter("visual_quality",1.0)
    mesh.material_override = material
    # One cheap blended contact-shadow batch already grounds all marbles.
    # Rendering individual moving shadow maps here costs a second geometry pass.
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)

    if is_player:
        boost_ring = MeshInstance3D.new()
        boost_ring.name = "TurboHalo"
        var halo = TorusMesh.new()
        halo.inner_radius = 0.44
        halo.outer_radius = 0.48
        halo.rings = 28
        halo.ring_segments = 7
        boost_ring.mesh = halo
        boost_ring.rotation.x = 0.15
        var ring_material = StandardMaterial3D.new()
        ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring_material.albedo_color = Color(0.49,0.93,1.0,0.65)
        ring_material.emission_enabled = true
        ring_material.emission = Color("#6ff1f9")
        ring_material.emission_energy_multiplier = 1.9
        boost_ring.material_override = ring_material
        boost_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        boost_ring.visible = false
        add_child(boost_ring)

    collision = CollisionShape3D.new()
    collision.name = "SphereCollision"
    var shape = SphereShape3D.new()
    shape.radius = RADIUS
    collision.shape = shape
    add_child(collision)

func wants_shortcut() -> bool:
    # About one in seven bot rivals per course, with a different set in
    # each biome. Never select a local or remotely controlled human racer.
    if is_player or network_controlled or not is_instance_valid(course_owner):
        return false
    # Opponents rotate on rematches; track layout and AI stay deterministic.
    return (racer_id*7+course_owner.selected_track*11+course_owner.built_variation*5)%13 < 2

func drive(delta: float, elapsed: float, steering: float, boosting: bool) -> void:
    if finished or eliminated or sleeping:
        return
    if is_player:
        boost_glow = move_toward(boost_glow,1.0 if boosting else 0.0,delta*4.4)
        if is_instance_valid(glass_material):
            glass_material.set_shader_parameter("boost_strength",boost_glow)
        if is_instance_valid(boost_ring):
            boost_ring.visible = boost_glow > 0.02
            boost_ring.rotation.y += delta*7.0*maxf(0.2,boost_glow)
            boost_ring.scale = Vector3.ONE*(0.92+0.11*sin(elapsed*12.0))
    # Downhill assistance counteracts stalls without prescribing a trajectory.
    var drive_force := 12.5
    if perk == "Aerodynamic":
        drive_force *= 1.22
    if (is_player or network_controlled) and boosting:
        drive_force += 8.0
    var side_force := 0.0
    if is_player or network_controlled:
        # Steering retains authority at high speed, without making tiny inputs twitchy.
        var forward_speed: float = absf(linear_velocity.z)
        side_force = steering * lerpf(18.5,26.0,clampf(forward_speed/18.0,0.0,1.0))
    else:
        # Predictable seeded weave prevents the AI from blindly hugging one rail.
        # Other marbles still interact solely through physical collisions.
        ai_lane_timer -= delta
        if ai_lane_timer <= 0.0:
            ai_lane_timer = 1.5 + float(racer_id % 5) * 0.37
            var phase: float = elapsed * 0.37 + seed_value * 2.1
            ai_lane_goal = sin(phase) * (2.0 + float(racer_id % 4) * 0.5)
        # Look ahead into the next bend: AI follows the physical winding road,
        # rather than steering towards the old straight-world X=0.
        var center_ahead: float = course_owner.track_center_at(position.z-5.0) if is_instance_valid(course_owner) else 0.0
        var lane_error: float = ai_lane_goal + center_ahead - position.x
        side_force = clampf(lane_error*1.0 - linear_velocity.x*0.18,-4.5,4.5)
        # A small, deterministic field of rivals takes the optional road.
        # AI must physically steer through its fork: no teleports, and the
        # server remains the sole source of racing physics.
        var following_bypass := false
        if wants_shortcut() and is_instance_valid(course_owner.shortcut_route):
            var road: Node3D = course_owner.shortcut_route
            var entered: bool = road.entered.has(racer_id)
            if AIPath.pursue_bypass(position.z,entered,
                road.ENTRY_Z,road.EXIT_Z,road.ENTRY_WINDOW):
                var aim_x: float = AIPath.bypass_target_x(road,position.z)
                side_force = AIPath.bypass_steering(aim_x,position.x,
                    linear_velocity.x)
                following_bypass = true
        if not following_bypass and is_instance_valid(course_owner):
            side_force += AIPath.baffle_dodge(position,
                course_owner.track_center_at(position.z))
    # Progress watchdog: collisions sometimes wedge a sphere with nonzero angular
    # velocity, fooling speed-based stall detection. Measure net forward progress.
    progress_stall_seconds += delta
    if progress_stall_seconds >= 2.0:
        if position.z > progress_anchor_z - 0.7:
            stuck_seconds += 1.35
        else:
            recovery_count = maxi(0,recovery_count-1)
        progress_anchor_z = position.z
        progress_stall_seconds = 0.0
    # Real physics recovery: give a marble a small nudge if trapped against a
    # rail/post for >2 sec. No teleportation, no fake position interpolation.
    # Let a marble keep its chosen outside lane instead of forcing it back.
    var center_now: float = course_owner.recovery_center_at(position) if is_instance_valid(course_owner) else 0.0
    var relative_x: float = position.x-center_now
    var wall_proximity := clampf((absf(relative_x)-4.70)/1.05,0.0,1.0)
    side_force += -signf(relative_x) * 31.0 * wall_proximity
    if linear_velocity.length() < 0.65 or (absf(linear_velocity.z) < 0.30 and absf(relative_x) > 3.5):
        stuck_seconds += delta
    else:
        stuck_seconds = maxf(0.0,stuck_seconds - delta*3.0)
    if stuck_seconds > 1.65:
        var side_direction := -signf(relative_x) if absf(relative_x)>1.0 else (1.0 if recovery_count%2==0 else -1.0)
        var effort := minf(2.8,1.0+float(recovery_count)*0.35)
        apply_central_impulse(Vector3(side_direction*3.6*effort,1.4*effort,-6.5*effort)*mass)
        stuck_seconds = 0.0
        recovery_count += 1
    apply_central_force(Vector3(side_force, 0.0, -drive_force) * mass)
    if linear_velocity.length() > 24.0:
        linear_velocity = linear_velocity.limit_length(24.0)
    if position.y < -55.0 or absf(relative_x) > 26.0:
        eliminated = true
        fell_off.emit(self)

func teleport_to_start(new_position: Vector3) -> void:
    freeze = true
    global_position = new_position
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    finished = false
    eliminated = false
    collision_layer = 1
    collision_mask = 1
    finish_time = 0.0
    stuck_seconds = 0.0
    recovery_count = 0
    progress_anchor_z = new_position.z
    progress_stall_seconds = 0.0
    ai_lane_timer = 0.0
    ai_lane_goal = 0.0
    network_controlled = false
    freeze = false
