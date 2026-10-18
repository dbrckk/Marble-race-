extends RigidBody3D
## Rigid-body racer with visually distinct procedurally marbled glass.
signal crossed_finish(racer)
signal fell_off(racer)

const SHADER = preload("res://shaders/marble.gdshader")
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
var display_name := ""
var is_player := false
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

func setup(index: int, player: bool, base_position: Vector3, chosen_perk: String = "") -> void:
    racer_id = index
    is_player = player
    display_name = "YOU" if player else NAMES[index % (NAMES.size() - 1)]
    perk = chosen_perk if player else ""
    seed_value = float(index) * 2.317
    name = "Marble_%02d" % index
    position = base_position
    mass = 0.73
    gravity_scale = 1.0
    linear_damp = 0.20
    angular_damp = 0.16
    continuous_cd = true
    can_sleep = false
    contact_monitor = false
    physics_material_override = PhysicsMaterial.new()
    physics_material_override.friction = 0.72
    physics_material_override.bounce = 0.19

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
    var sphere = SphereMesh.new()
    sphere.radius = RADIUS
    sphere.height = RADIUS * 2.0
    sphere.radial_segments = 24
    sphere.rings = 12
    mesh.mesh = sphere
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
    mesh.material_override = material
    add_child(mesh)

    collision = CollisionShape3D.new()
    collision.name = "SphereCollision"
    var shape = SphereShape3D.new()
    shape.radius = RADIUS
    collision.shape = shape
    add_child(collision)

func drive(delta: float, elapsed: float, steering: float, boosting: bool) -> void:
    if finished or eliminated or sleeping:
        return
    # Downhill assistance counteracts stalls without prescribing a trajectory.
    var drive_force := 12.5
    if perk == "Aerodynamic":
        drive_force *= 1.22
    if is_player and boosting:
        drive_force += 8.0
    var side_force := 0.0
    if is_player:
        side_force = steering * 10.5
    else:
        # Small seed-deterministic AI corrections. Physics and collisions remain authoritative.
        var drift = sin(elapsed * (0.63 + racer_id * 0.013) + seed_value) * 0.65
        side_force = drift + (-position.x * 0.065)
    # Real physics recovery: give a marble a small nudge if trapped against a
    # rail/post for >2 sec. No teleportation, no fake position interpolation.
    var wall_proximity := clampf((absf(position.x)-5.2)/0.95,0.0,1.0)
    side_force += -signf(position.x) * 26.0 * wall_proximity
    if linear_velocity.length() < 0.35:
        stuck_seconds += delta
    else:
        stuck_seconds = maxf(0.0,stuck_seconds - delta*3.0)
    if stuck_seconds > 2.0:
        var push_side := -signf(position.x) * 1.7 if absf(position.x)>2.1 else (1.0 if recovery_count%2==0 else -1.0)*1.2
        apply_central_impulse(Vector3(push_side,0.24,-4.4) * mass)
        stuck_seconds = 0.0
        recovery_count += 1
    apply_central_force(Vector3(side_force, 0.0, -drive_force) * mass)
    if linear_velocity.length() > 24.0:
        linear_velocity = linear_velocity.limit_length(24.0)
    if position.y < -55.0 or abs(position.x) > 26.0:
        eliminated = true
        fell_off.emit(self)

func teleport_to_start(new_position: Vector3) -> void:
    freeze = true
    global_position = new_position
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    finished = false
    eliminated = false
    finish_time = 0.0
    stuck_seconds = 0.0
    recovery_count = 0
    freeze = false
