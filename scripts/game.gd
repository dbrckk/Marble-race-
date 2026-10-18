extends Node3D
## Full 3D toy race stage, deterministic course layout, 40 simulated rigidbodies.
## Android-friendly: no downloaded textures, no runtime network, GLES3 compatibility.

const Racer = preload("res://scripts/marble.gd")
const HUD = preload("res://scripts/hud.gd")
const WOOD_SHADER = preload("res://shaders/wood.gdshader")

const MARBLE_COUNT := 40
const SLOPE := 0.085
const SEGMENT_LENGTH := 12.0
const SEGMENTS := 18
const FINISH_Z := -193.5
const RACE_TIMEOUT := 110.0
const BARRIER_COLORS := [
    Color("#fa746b"), Color("#f1c757"), Color("#64c5a1"),
    Color("#6da5d8"), Color("#b67cd2"), Color("#fcad60")
]
const WOOD_COLORS := [
    Color("#956043"), Color("#ab7553"), Color("#9e6b49"),
    Color("#ad7957"), Color("#976849"), Color("#b2845d"),
    Color("#a16d4c"), Color("#ac7754")
]

var rng := RandomNumberGenerator.new()
var ui: CanvasLayer
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
var selected_perk := ""
var cam_mode := 0
var world_time := 0.0
var finish_announced := false
var starting_camera_target := Vector3(0, 0, 0)

func _ready() -> void:
    rng.seed = 424242
    _make_environment()
    _make_course()
    camera = Camera3D.new()
    camera.name = "RaceCamera"
    camera.current = true
    camera.fov = 64.0
    camera.near = 0.05
    camera.far = 300.0
    add_child(camera)
    ui = HUD.new()
    add_child(ui)
    ui.attach_game(self)
    _position_intro_camera(true)
    ui.show_menu()

func _make_environment() -> void:
    var env_node = WorldEnvironment.new()
    env_node.name = "StudioEnvironment"
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#342820")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#f2d8bd")
    env.ambient_light_energy = 0.85
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env_node.environment = env
    add_child(env_node)

    var sun = DirectionalLight3D.new()
    sun.name = "LargeSoftbox"
    sun.rotation_degrees = Vector3(-48, -28, -8)
    sun.light_color = Color("#ffecd5")
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 75.0
    add_child(sun)

    var fill = DirectionalLight3D.new()
    fill.name = "CoolFill"
    fill.rotation_degrees = Vector3(-30, 150, 0)
    fill.light_color = Color("#cae4f4")
    fill.light_energy = 0.52
    add_child(fill)

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
    render_materials[key] = m
    return m

func _wood_mat(color: Color) -> ShaderMaterial:
    var key = "wood_" + color.to_html()
    if render_materials.has(key):
        return render_materials[key]
    var m = ShaderMaterial.new()
    m.shader = WOOD_SHADER
    m.set_shader_parameter("timber_color", color)
    render_materials[key] = m
    return m

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, material: Material, solid := true, tilt := false) -> Node3D:
    var holder: Node3D
    if solid:
        holder = StaticBody3D.new()
        var collision = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = dimensions
        collision.shape = shape
        holder.add_child(collision)
        var physic = PhysicsMaterial.new()
        physic.friction = 0.85
        physic.bounce = 0.09
        (holder as StaticBody3D).physics_material_override = physic
    else:
        holder = Node3D.new()
    holder.position = location
    if tilt:
        holder.rotation.x = -atan(SLOPE)
    var art = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = dimensions
    art.mesh = mesh
    art.material_override = material
    holder.add_child(art)
    parent.add_child(holder)
    return holder

func _cylinder(parent: Node3D, location: Vector3, radius: float, tall: float, color: Color) -> StaticBody3D:
    var body = StaticBody3D.new()
    body.position = location
    parent.add_child(body)
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
    mesh.radial_segments = 18
    art.mesh = mesh
    art.material_override = _mat(color, 0.35)
    body.add_child(art)
    return body

func _make_course() -> void:
    if is_instance_valid(board):
        board.queue_free()
    board = Node3D.new()
    board.name = "HandcraftedWoodenCourse"
    add_child(board)
    moving_obstacles.clear()
    var incline = -atan(SLOPE)
    for section in range(SEGMENTS):
        var center_z = 8.0 - float(section) * SEGMENT_LENGTH
        var section_node = Node3D.new()
        section_node.name = "Course_%02d" % section
        board.add_child(section_node)
        for lane in range(10):
            var x = (float(lane) - 4.5) * 1.34
            var shade = WOOD_COLORS[(lane + section * 3) % WOOD_COLORS.size()]
            _box(section_node, Vector3(x, height_at(center_z)-0.34, center_z),
                Vector3(1.315, 0.65, SEGMENT_LENGTH + 0.08), _wood_mat(shade), true, true)
            # Short engraved joints and subtle board grain accents.
            for j in range(2):
                var grain = Color("#553b2c")
                grain.a = 0.45
                var z = center_z + (float(j) - 0.5) * 4.4
                _box(section_node, Vector3(x - 0.34 + (j%2)*0.31, height_at(z)+0.005, z),
                    Vector3(0.018, 0.012, 5.0), _mat(Color("#82563d")), false, true)

        # Tall segmented painted rails match the tabletop toy-set appearance.
        for side in [-1, 1]:
            for rail_piece in range(3):
                var z = center_z + (rail_piece - 1) * 4.02
                var color_idx = (section + rail_piece + (0 if side == 1 else 3)) % BARRIER_COLORS.size()
                _box(section_node, Vector3(side * 6.84, height_at(z)+0.58, z),
                    Vector3(0.57, 1.26, 4.04), _mat(BARRIER_COLORS[color_idx], 0.49), true, true)
        if section > 0 and section < SEGMENTS - 1:
            if section % 3 == 1:
                _pegs(section_node, center_z, section)
            elif section % 3 == 2:
                _gate_with_posts(section_node, center_z, section)
            else:
                _slalom(section_node, center_z, section)

    _start_arch()
    _finish_arch()
    _decorations()
    _showroom()

func _pegs(parent: Node3D, center_z: float, n: int) -> void:
    # Checkerboard of rounded vertical posts, with traversable gaps.
    for row in range(3):
        var z = center_z + 3.0 - row * 3.2
        for c in range(5):
            var x = (c - 2) * 2.20 + (0.56 if row % 2 == 1 else 0.0)
            var tint = BARRIER_COLORS[(n + c + row) % BARRIER_COLORS.size()]
            _cylinder(parent, Vector3(x, height_at(z)+0.8, z), 0.31, 1.6, tint)

func _gate_with_posts(parent: Node3D, center_z: float, n: int) -> void:
    for row in range(2):
        var z = center_z + 3.2 - row * 6.0
        for i in range(3):
            var x = -4.6 + i * 4.7 + (0.65 if row == 1 else 0.0)
            _box(parent, Vector3(x, height_at(z)+0.67, z),
                Vector3(0.91, 1.37, 1.25), _mat(BARRIER_COLORS[(n+row+i)%6], 0.45), true, true)
    _add_spinner(parent, center_z, n)

func _slalom(parent: Node3D, center_z: float, n: int) -> void:
    for i in range(4):
        var z = center_z + 4.4 - float(i) * 2.8
        var x = (-3.5 if i % 2 == 0 else 3.5)
        _box(parent, Vector3(x, height_at(z)+0.36, z),
            Vector3(3.4, 0.75, 1.05), _mat(BARRIER_COLORS[(n+i)%6], 0.53), true, true)
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
        var box = BoxMesh.new()
        box.size = Vector3(7.1 if i==0 else 4.8, 0.56, 0.34)
        mesh.mesh = box
        mesh.material_override = _mat(color if i==0 else BARRIER_COLORS[(n+3)%6], 0.44)
        spoke.add_child(mesh)
        # Collider needs rotation on CollisionShape rather than relying on untransformed parent body.
        var hit = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = box.size
        hit.shape = shape
        hit.rotation.y = spoke.rotation.y
        pivot.add_child(hit)
    var axle = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.height = 1.3
    cyl.top_radius = 0.42
    cyl.bottom_radius = 0.42
    axle.mesh = cyl
    axle.material_override = _mat(Color("#f0c361"), 0.25, 0.16)
    pivot.add_child(axle)
    pivot.set_meta("spin_speed", (1.0 if n%2==0 else -1.0) * (0.72 + n*0.022))
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
    for j in range(34):
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
    # No asset dependencies: warm blurred-out-look room made with large muted geometry.
    for i in range(8):
        var z = 24.0 - float(i)*34.0
        for side in [-1,1]:
            var c = Color("#5b3f33") if i%2==0 else Color("#6e5345")
            _box(board, Vector3(side*18.0,height_at(z)+3.4,z),
                Vector3(2.2,10.0,7.0), _mat(c), false)

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
            _add_player_marker(m)

    if selected_perk == "Head Start" and is_instance_valid(player):
        player.position.z -= 3.2
        player.position.y = height_at(player.position.z)+0.68
    boost_energy = 1.0

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

func start_race(perk_name: String) -> void:
    selected_perk = perk_name
    race_state = "COUNTDOWN"
    race_time = 0.0
    countdown = 3.3
    result_delay = 0.0
    finish_announced = false
    steer = 0.0
    boosting = false
    cam_mode = 0
    _spawn_racers()
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
    race_state = "MENU"
    ui.show_menu()

func _process(delta: float) -> void:
    world_time += delta
    for obj in moving_obstacles:
        if is_instance_valid(obj):
            obj.rotation.y += delta * float(obj.get_meta("spin_speed"))
    if race_state == "COUNTDOWN":
        countdown -= delta
        if countdown > 0.0:
            ui.show_countdown(str(int(ceil(countdown))))
        else:
            race_state = "RACING"
            for m in racers:
                m.freeze = false
                m.sleeping = false
            ui.show_countdown("GO!")
    elif race_state == "RACING":
        race_time += delta
        if race_time > 1.0:
            ui.hide_countdown()
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
        elif race_time >= RACE_TIMEOUT:
            _end_race()
    _update_camera(delta)
    if race_state == "RACING" or race_state == "COUNTDOWN":
        ui.update_hud()

func _physics_process(delta: float) -> void:
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
    camera.global_position = desired if force else camera.global_position.lerp(desired, min(delta*3.7,1.0))
    camera.look_at(focus, Vector3.UP)

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
    steer = clampf(value, -1.0, 1.0)

func change_boost(value: bool) -> void:
    boosting = value and boost_energy > 0.03

func _unhandled_input(event: InputEvent) -> void:
    if race_state != "RACING":
        return
    if event is InputEventScreenDrag:
        change_steer(clampf(event.relative.x/38.0, -1.0, 1.0))
    if event is InputEventScreenTouch and not event.pressed:
        change_steer(0.0)
    if event is InputEventKey:
        if event.keycode == KEY_LEFT or event.keycode == KEY_A:
            change_steer(-1.0 if event.pressed else 0.0)
        elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
            change_steer(1.0 if event.pressed else 0.0)
        elif event.keycode == KEY_SPACE:
            change_boost(event.pressed)
        elif event.keycode == KEY_C and event.pressed:
            cycle_camera()

func _end_race() -> void:
    if race_state == "RESULTS":
        return
    race_state = "RESULTS"
    boosting = false
    steer = 0.0
    ui.show_results(player_rank(), race_time, get_rankings())
