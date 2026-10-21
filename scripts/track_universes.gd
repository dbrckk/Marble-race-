extends Node3D
## Three lightweight track worlds. Decoration never owns collisions or alters lap physics.
## MultiMesh keeps the Android draw-call budget bounded across 18 track sections.
const THEMES := ["WOODLAND WORKSHOP", "GLACIER PASS", "EMBER FORGE"]
const THEME_FOG := [Color("#333c39"),Color("#142c42"),Color("#39201c")]
const THEME_SKY := [Color("#202923"),Color("#12283f"),Color("#2f1b1b")]
const THEME_SUN := [Color("#ffe4b8"),Color("#c9ecff"),Color("#ffae78")]
const THEME_TINT := [Color("#6fa38b"),Color("#81cbe5"),Color("#ce7560")]
const SEGMENTS := 18
const LEN := 12.0
const SLOPE := 0.085

static func apply_atmosphere(env: Environment, sun: DirectionalLight3D, track: int) -> void:
    if not is_instance_valid(env):
        return
    var theme: int = clampi(track,0,2)
    env.background_color = THEME_SKY[theme]
    env.fog_light_color = THEME_FOG[theme]
    env.ambient_light_color = THEME_SUN[theme]
    if is_instance_valid(sun):
        sun.light_color = THEME_SUN[theme]

func setup(track: int, stage: Node3D) -> void:
    var theme := clampi(track,0,2)
    name = "World_%s" % THEMES[theme].replace(" ","_")
    var base := StandardMaterial3D.new()
    base.albedo_color = [Color("#315544"),Color("#6098b4"),Color("#272d35")][theme]
    base.roughness = 0.75
    var accent := StandardMaterial3D.new()
    accent.albedo_color = [Color("#81b68b"),Color("#9de9fb"),Color("#f18d4b")][theme]
    accent.roughness = 0.31 if theme == 1 else 0.58
    accent.emission_enabled = theme > 0
    accent.emission = accent.albedo_color
    accent.emission_energy_multiplier = 0.55 if theme > 0 else 0.0
    var slope_mesh := SphereMesh.new()
    slope_mesh.radius = 1.0
    slope_mesh.height = 2.0
    slope_mesh.radial_segments = 12
    slope_mesh.rings = 6
    slope_mesh.material = base
    var pillar_mesh := CylinderMesh.new()
    pillar_mesh.top_radius = 0.0 if theme < 2 else 0.38
    pillar_mesh.bottom_radius = 0.82
    pillar_mesh.height = 3.8
    pillar_mesh.radial_segments = 5 if theme == 1 else (7 if theme == 2 else 9)
    pillar_mesh.material = accent
    var secondary := CylinderMesh.new()
    secondary.top_radius = 0.0 if theme != 2 else 0.32
    secondary.bottom_radius = 0.45
    secondary.height = 2.2
    secondary.radial_segments = 5 if theme == 1 else 7
    secondary.material = base if theme == 0 else accent
    var bases: Array[Transform3D] = []
    var spires: Array[Transform3D] = []
    var tops: Array[Transform3D] = []
    for section in range(SEGMENTS):
        var z := 8.0 - float(section)*LEN
        for side in [-1.0,1.0]:
            var jitter := sin(float(section)*2.83+side)*1.4
            var x: float = float(side)*(11.0 + float(section%3)*0.65) + stage.track_center_at(z)
            var floor_y := z*SLOPE
            var bank_basis := Basis().scaled(Vector3(3.7,1.6+0.3*(section%3),4.3))
            bases.append(Transform3D(bank_basis,Vector3(x,floor_y-1.7,z)))
            var high := 0.78+float(section%4)*0.11
            spires.append(Transform3D(
                Basis(Vector3.UP,float(section)*0.4).scaled(Vector3(high,high,high)),
                Vector3(x+side*0.5+jitter,floor_y+0.25+1.9*high,z-2.0)))
            if theme == 0:
                # Evergreen canopy above short trunk, preserving the race sightline.
                tops.append(Transform3D(Basis().scaled(Vector3(0.55,1.0,0.55)),
                    Vector3(x+side*0.5+jitter,floor_y+0.3,z-2.0)))
            elif theme == 1:
                tops.append(Transform3D(Basis(Vector3.UP,1.0).scaled(Vector3(0.53,0.8,0.53)),
                    Vector3(x+side*2.0,floor_y+0.9,z+2.8)))
            else:
                tops.append(Transform3D(Basis().scaled(Vector3(0.8,0.42,0.8)),
                    Vector3(x+side*0.5,floor_y+4.1,z-2.0)))
    _batch("RollingSideTerrain",slope_mesh,bases)
    _batch("SignatureWorldSpires",pillar_mesh,spires)
    _batch("WorldAccentForms",secondary,tops)

func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = mesh
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i,transforms[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = instances
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
