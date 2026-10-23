extends Node3D
## Six genuine springy pinball posts: three race stations, two edge approaches.
## They use static physics colliders and shared GPU-instanced art. A marble
## bounces through ordinary Godot contacts; no hidden impulse, scripted boost,
## teleport or client-authoritative effect can distort the championship.
const STATION_Z := [-10.0,-130.0,-178.0]
const SIDES := [-1,1]
const RADIUS := 0.67
const HEIGHT := 1.34
const EDGE_X := 4.65
const BOUNCE := [0.76,0.87,0.98]
const COLORS := [Color("#f5bf71"),Color("#8feeff"),Color("#ff9a72")]

var stage: Node3D
var biome := 0
var layout := 0
var bodies: Array[StaticBody3D] = []
var cylinders: MultiMeshInstance3D
var glow_rings: MultiMeshInstance3D
# Reuse the 12 instanced rings already drawn on mobile. A physical
# body_entered event refreshes only its own pair of rings; no new meshes,
# shaders, lights, colliders, timers, signals or audio channels are created.
const PULSE_DECAY := 2.2
const PULSE_REARM := 0.14
var ring_origins: Array[Transform3D] = []
var pulse_strength: Array[float] = []
var pulse_cooldowns: Array[float] = []
var pulse_events := 0
var quality_level := 1

static func station_z(index: int, next_layout: int) -> float:
    # At real module seams, away from peg gardens, moving gates and fork exits.
    # The ±0.55 m rematch offset remains inside each 2.8 m overlapping floor.
    return STATION_Z[index]+[-0.55,0.0,0.55][posmod(next_layout+index,3)]

static func side_offset(index: int, side: int, track: int,
        next_layout: int) -> float:
    var phase: int = posmod(index+next_layout+clampi(track,0,2),3)
    return float(side)*(EDGE_X+[-0.36,0.0,0.36][phase])

func location_at(index: int, side: int) -> Vector3:
    var z: float = station_z(index,layout)
    return Vector3(stage.track_center_at(z)+side_offset(
        index,side,biome,layout),stage.height_at(z)+HEIGHT*0.5,z)

func setup(owner: Node3D, track: int, next_layout: int) -> void:
    stage = owner
    biome = clampi(track,0,2)
    layout = posmod(next_layout,3)
    name = "PhysicalPinballKickers"
    var surface := PhysicsMaterial.new()
    surface.friction = 0.08
    surface.bounce = BOUNCE[biome]
    var posts: Array[Transform3D] = []
    var rings: Array[Transform3D] = []
    for station in range(STATION_Z.size()):
        for side in SIDES:
            var where: Vector3 = location_at(station,side)
            var post := StaticBody3D.new()
            post.name = "PinballKicker_%d_%s" % [
                station,"L" if side < 0 else "R"]
            post.position = where
            post.physics_material_override = surface
            post.set_meta("station",station)
            post.set_meta("side",side)
            var hit := CollisionShape3D.new()
            hit.name = "RealSpringCollider"
            var column := CylinderShape3D.new()
            column.radius = RADIUS
            column.height = HEIGHT
            hit.shape = column
            post.add_child(hit)
            add_child(post)
            bodies.append(post)
            posts.append(Transform3D(Basis(),where))
            for rim_height in [-HEIGHT*0.5+0.14,HEIGHT*0.5-0.12]:
                rings.append(Transform3D(Basis(),
                    where+Vector3(0.0,rim_height,0.0)))
    var barrel := CylinderMesh.new()
    barrel.top_radius = RADIUS
    barrel.bottom_radius = RADIUS
    barrel.height = HEIGHT
    barrel.radial_segments = 16
    barrel.rings = 1
    var metal := StandardMaterial3D.new()
    metal.albedo_color = COLORS[biome].darkened(0.24)
    metal.metallic = 0.55
    metal.roughness = 0.24
    metal.emission_enabled = true
    metal.emission = COLORS[biome]
    metal.emission_energy_multiplier = 0.27
    cylinders = _batch("BouncyLacquerColumns",barrel,metal,posts)
    var torus := TorusMesh.new()
    torus.inner_radius = 0.71
    torus.outer_radius = 0.85
    torus.rings = 18
    torus.ring_segments = 6
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = COLORS[biome].lightened(0.18)
    glow.emission_enabled = true
    glow.emission = COLORS[biome]
    glow.emission_energy_multiplier = 1.3
    glow_rings = _batch("SpringContactHalos",torus,glow,rings)
    ring_origins = rings.duplicate()
    pulse_strength.resize(bodies.size())
    pulse_cooldowns.resize(bodies.size())
    reset_pulses()

func _batch(label_text: String, mesh: Mesh, paint: Material,
        transforms: Array[Transform3D]) -> MultiMeshInstance3D:
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = mesh
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i,transforms[i])
    var art := MultiMeshInstance3D.new()
    art.name = label_text
    art.multimesh = instances
    art.material_override = paint
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(art)
    return art

func _write_ring_pair(index: int) -> void:
    if not is_instance_valid(glow_rings) or quality_level == 0:
        return
    var multiplier: float = 1.0+clampf(pulse_strength[index],0.0,1.0)*0.48
    for edge in range(2):
        var slot: int = index*2+edge
        var baseline: Transform3D = ring_origins[slot]
        var slightly_offset: float = multiplier if edge == 0 else (
            1.0+(multiplier-1.0)*0.72)
        glow_rings.multimesh.set_instance_transform(slot,Transform3D(
            baseline.basis.scaled(Vector3(slightly_offset,1.0,slightly_offset)),
            baseline.origin))

func reset_pulses() -> void:
    pulse_events = 0
    for index in range(pulse_strength.size()):
        pulse_strength[index] = 0.0
        pulse_cooldowns[index] = 0.0
        _write_ring_pair(index)

func notify_contact(body: Node, intensity: float) -> bool:
    # Called by the existing local player's real RigidBody3D body_entered
    # signal. No proximity guesses or invented contact events.
    if not is_instance_valid(body) or not (body is StaticBody3D) or (
        body.get_parent() != self):
        return false
    var index: int = bodies.find(body)
    if index < 0 or not is_finite(intensity) or intensity < 0.16 or (
        pulse_cooldowns[index] > 0.0):
        return false
    pulse_strength[index] = maxf(pulse_strength[index],
        clampf(intensity,0.0,1.0))
    pulse_cooldowns[index] = PULSE_REARM
    pulse_events += 1
    _write_ring_pair(index)
    return true

func advance_visuals(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    for index in range(pulse_strength.size()):
        pulse_cooldowns[index] = maxf(0.0,pulse_cooldowns[index]-delta)
        if pulse_strength[index] <= 0.0:
            continue
        pulse_strength[index] = move_toward(pulse_strength[index],0.0,
            delta*PULSE_DECAY)
        # Do not issue GPU writes in economy mode. Returning to balanced or
        # ultra re-synchronizes visible rings with these bounded CPU values.
        _write_ring_pair(index)

func set_quality(quality: int) -> void:
    # All six real collision posts persist on every mobile tier.
    quality_level = clampi(quality,0,2)
    if is_instance_valid(glow_rings):
        glow_rings.visible = quality_level > 0
        if quality_level > 0:
            for index in range(pulse_strength.size()):
                _write_ring_pair(index)
