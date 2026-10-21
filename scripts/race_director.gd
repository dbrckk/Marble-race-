extends Node3D
## Lightweight arcade race director: collidable timed hazards and earned clean
## passes. Real marbles and server authority decide the results; graphics never
## infer hits. Deterministic phases vary by biome and rematch variation.
const EVENT_Z := [-34.0,-118.0,-154.0]
const EVENT_NAMES := ["SWEEPING ARM","ICE SHUTTER","FORGE PISTON"]
const EVENT_COLORS := [Color("#edbe72"),Color("#a5ecf4"),Color("#ff9c63")]
const BODY_WIDTH := 1.65
const BODY_HEIGHT := 0.82
const BODY_DEPTH := 0.76
const NEAR_MISS_IMPULSE := 2.05
const EVENT_LENGTH := 2.1
const SPEEDS := [5.8,4.65,5.25]
const VERTICAL_CYCLE := 5.25
const VERTICAL_DUTY := 0.47

var game: Node3D
var biome := 0
var variation := 0
var obstacles: Array[AnimatableBody3D] = []
var warning_rings: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
var awarded: Dictionary = {}
var clock := 0.0
var collisions_enabled := true

func setup(owner: Node3D, track: int, layout: int) -> void:
    game = owner
    biome = clampi(track,0,2)
    variation = posmod(layout,3)
    name = "ReactiveRaceDirector"
    var metal := StandardMaterial3D.new()
    metal.albedo_color = EVENT_COLORS[biome].darkened(0.23)
    metal.metallic = 0.48
    metal.roughness = 0.29
    var glow := StandardMaterial3D.new()
    glow.albedo_color = EVENT_COLORS[biome]
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.emission_enabled = true
    glow.emission = EVENT_COLORS[biome]
    glow.emission_energy_multiplier = 0.65
    var mesh := BoxMesh.new()
    mesh.size = Vector3(BODY_WIDTH,BODY_HEIGHT,BODY_DEPTH)
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.88
    ring_mesh.outer_radius = 1.04
    ring_mesh.rings = 18
    ring_mesh.ring_segments = 7
    for i in range(EVENT_Z.size()):
        var z: float = EVENT_Z[i]
        var side: float = side_at(i)
        var x: float = game.track_center_at(z)+side*3.22
        var body := AnimatableBody3D.new()
        body.name = "ReactiveHazard_%02d" % i
        body.sync_to_physics = true
        body.position = Vector3(x,game.height_at(z)+0.42,z)
        var contact := PhysicsMaterial.new()
        contact.friction = 0.30
        contact.bounce = 0.24 if biome == 2 else 0.12
        body.physics_material_override = contact
        var collider := CollisionShape3D.new()
        collider.name = "ActiveObstacleCollider"
        var shape := BoxShape3D.new()
        shape.size = Vector3(BODY_WIDTH,BODY_HEIGHT,BODY_DEPTH)
        collider.shape = shape
        body.add_child(collider)
        var art := MeshInstance3D.new()
        art.name = "TimedObstacleArt"
        art.mesh = mesh
        art.material_override = metal
        art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        body.add_child(art)
        add_child(body)
        obstacles.append(body)
        var marker := MeshInstance3D.new()
        marker.name = "WarningHalo_%02d" % i
        marker.mesh = ring_mesh
        marker.material_override = glow
        marker.position = Vector3(x,game.height_at(z)+0.10,z)
        marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(marker)
        warning_rings.append(marker)
        var notice := Label3D.new()
        notice.name = "TimedHazardSign_%02d" % i
        notice.text = EVENT_NAMES[biome]
        notice.font_size = 30
        notice.pixel_size = 0.009
        notice.outline_size = 8
        notice.modulate = EVENT_COLORS[biome]
        notice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        notice.position = Vector3(x,game.height_at(z)+2.25,z)
        add_child(notice)
        signs.append(notice)
    reset_round()

func side_at(index: int) -> float:
    return -1.0 if (index+biome+variation)%2 == 0 else 1.0

func period() -> float:
    return SPEEDS[biome]

func phase_at(index: int, elapsed: float) -> float:
    return fposmod(elapsed+float(index)*1.71+float(variation)*1.29,period())/period()

func piston_up(index: int, elapsed: float) -> bool:
    if biome != 2:
        return true
    return phase_at(index,elapsed) < VERTICAL_DUTY

func position_at(index: int, elapsed: float) -> Vector3:
    var z: float = EVENT_Z[index]
    var center: float = game.track_center_at(z)
    var side: float = side_at(index)
    var phase: float = phase_at(index,elapsed)
    if biome == 2:
        # Fully buried below the track when inactive. The circular warning
        # stays visible so competitors understand the timing of the piston.
        return Vector3(center+side*3.26,
            game.height_at(z)+(0.40 if piston_up(index,elapsed) else -1.08),z)
    var radius: float = 0.85 if biome == 0 else 1.12
    return Vector3(center+side*(3.22+radius*sin(phase*TAU)),
        game.height_at(z)+0.42,z)

func animate(elapsed: float) -> void:
    clock = maxf(0.0,elapsed)
    for i in range(obstacles.size()):
        var point: Vector3 = position_at(i,clock)
        obstacles[i].position = point
        warning_rings[i].position = Vector3(point.x,
            game.height_at(EVENT_Z[i])+0.10,EVENT_Z[i])
        var rising: bool = piston_up(i,clock)
        # Cheap, readable telegraph without realtime lights/shadows.
        warning_rings[i].scale = Vector3.ONE*(
            1.10+0.13*sin(clock*TAU/period()+float(i)*1.7))
        warning_rings[i].visible = biome != 2 or rising or (
            phase_at(i,clock) > 0.78)
        signs[i].modulate.a = 0.86 if rising else 0.35

func reset_round() -> void:
    awarded.clear()
    animate(0.0)

func event_ahead(z: float) -> Dictionary:
    var nearest: float = 24.0
    var result: Dictionary = {}
    for i in range(EVENT_Z.size()):
        var distance: float = z-EVENT_Z[i]
        if distance <= 0.0 or distance >= nearest:
            continue
        nearest = distance
        result = {"distance":maxi(0,int(round(distance))),
            "side":"LEFT" if side_at(i) < 0 else "RIGHT",
            "kind":EVENT_NAMES[biome],
            "active":piston_up(i,clock),
            "phase":phase_at(i,clock)}
    return result

func tick(racers: Array[RigidBody3D], net: Node) -> void:
    if net.role == "client" or not collisions_enabled:
        return
    for i in range(obstacles.size()):
        var event: AnimatableBody3D = obstacles[i]
        if biome == 2 and not piston_up(i,clock):
            continue
        for marble in racers:
            if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
                continue
            var key: String = "%d:%d" % [i,marble.racer_id]
            if awarded.has(key):
                continue
            var offset: Vector3 = marble.global_position-event.global_position
            # Only passing forward behind the active moving body counts.
            # A clean lateral gap is required: body half-width 0.825.
            if offset.z > -0.35 or offset.z < -EVENT_LENGTH:
                continue
            var lateral: float = absf(offset.x)
            if lateral < 1.36 or lateral > 2.36 or absf(offset.y) > 1.6:
                continue
            if marble.linear_velocity.z > -0.85:
                continue
            awarded[key] = true
            marble.apply_central_impulse(
                Vector3(0.0,0.10,-NEAR_MISS_IMPULSE)*marble.mass)
            _feedback(marble,net)

func _feedback(marble: RigidBody3D, net: Node) -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,"near_miss")
    elif net.role == "offline" and marble.is_player:
        game.audio.course_event("near_miss")
        game.ui.show_course_event("near_miss")
