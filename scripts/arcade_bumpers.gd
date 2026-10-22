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

func set_quality(quality: int) -> void:
    # All collisions and bodies always remain; only nonessential neon can fade.
    if is_instance_valid(glow_rings):
        glow_rings.visible = quality > 0
