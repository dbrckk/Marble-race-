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
# Three original silhouettes with near/mid/far depth. World dressing is
# 100% static and NON-COLLIDING, even along the elevated shortcut.
const RIDGE_STATIONS := [1,4,7,10,13,16]
const FAR_SHOULDER := 28.0
const NEAR_SHOULDER := 17.8
const GLOW_SHOULDER := 19.5
var depth_ridges: MultiMeshInstance3D
var near_forms: MultiMeshInstance3D
var accent_lights: MultiMeshInstance3D
var distant_positions: Array[Vector3] = []
var near_positions: Array[Vector3] = []
var glow_positions: Array[Vector3] = []
var visual_quality := 1

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
            var floor_y: float = stage.height_at(z)
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
    _landscape_depth(theme,stage)
    set_quality(stage.graphics_quality)

func _landscape_depth(theme: int, stage: Node3D) -> void:
    # Avoid a flat 2D skybox: 12 large geological silhouettes create real
    # camera parallax, 36 biome-specific props create a middle distance and
    # 36 tiny lit accents outline the world without realtime light sources.
    # Every position remains 5m+ outside the furthest bypass guard rail.
    var far_color := StandardMaterial3D.new()
    far_color.albedo_color = [
        Color("#244333"),Color("#426e82"),Color("#302e36")][theme]
    far_color.roughness = [0.96,0.44,0.78][theme]
    far_color.metallic = [0.0,0.12,0.24][theme]
    var far_mesh: Mesh
    if theme == 1:
        var ice_peak := CylinderMesh.new()
        ice_peak.top_radius = 0.0
        ice_peak.bottom_radius = 1.0
        ice_peak.height = 2.0
        ice_peak.radial_segments = 5
        far_mesh = ice_peak
    elif theme == 2:
        var forge_tower := BoxMesh.new()
        forge_tower.size = Vector3.ONE
        far_mesh = forge_tower
    else:
        var hills := SphereMesh.new()
        hills.radius = 1.0
        hills.height = 2.0
        hills.radial_segments = 12
        hills.rings = 6
        far_mesh = hills
    var far_transforms: Array[Transform3D] = []
    var variation: int = posmod(int(stage.built_variation),3)
    for section in RIDGE_STATIONS:
        for side in [-1.0,1.0]:
            var z: float = 8.0-float(section)*LEN+float(variation-1)*3.3
            var x: float = stage.track_center_at(z)+side*(
                FAR_SHOULDER+float(section%3)*2.3)
            var ground: float = stage.height_at(z)
            var height: float = [6.9,11.5,9.6][theme]+float(section%4)*1.15
            var location := Vector3(x,ground+height*0.28-2.6,z)
            distant_positions.append(location)
            var dimensions := Vector3(
                [7.6,3.9,4.6][theme],height*0.53,
                [9.3,4.8,6.7][theme])
            far_transforms.append(Transform3D(
                Basis(Vector3.UP,float(section)*0.37).scaled(dimensions),
                location))
    depth_ridges = _batch("BiomesDepthLandscape_12",far_mesh,
        far_transforms)
    depth_ridges.material_override = far_color

    var prop_mesh := CylinderMesh.new()
    prop_mesh.top_radius = [0.03,0.0,0.57][theme]
    prop_mesh.bottom_radius = [1.15,0.87,0.92][theme]
    prop_mesh.height = [3.8,5.2,5.1][theme]
    prop_mesh.radial_segments = [7,5,9][theme]
    var prop_material := StandardMaterial3D.new()
    prop_material.albedo_color = [
        Color("#416f4c"),Color("#8ecddd"),Color("#6b4b42")][theme]
    prop_material.metallic = [0.0,0.17,0.69][theme]
    prop_material.roughness = [0.82,0.24,0.43][theme]
    var near_transforms: Array[Transform3D] = []
    for section in range(SEGMENTS):
        var z: float = 8.0-float(section)*LEN+float(variation-1)*1.8
        for side in [-1.0,1.0]:
            var x: float = stage.track_center_at(z)+side*(
                NEAR_SHOULDER+float((section+variation)%4)*0.84)
            var ground: float = stage.height_at(z)
            var y: float = ground+[1.65,2.15,1.98][theme]
            var place := Vector3(x,y,z)
            near_positions.append(place)
            near_transforms.append(Transform3D(
                Basis(Vector3.UP,float(section)*0.29+side*0.30).scaled(
                    Vector3(0.72+float(section%3)*0.18,
                        0.82+float(section%4)*0.16,0.75)),
                place))
    near_forms = _batch("BiomeSpecificForeground_36",prop_mesh,
        near_transforms)
    near_forms.material_override = prop_material

    var accent := BoxMesh.new()
    accent.size = Vector3.ONE
    var glass := StandardMaterial3D.new()
    glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glass.albedo_color = [Color("#f2d09e"),
        Color("#a6eaff"),Color("#ffab5c")][theme]
    glass.emission_enabled = true
    glass.emission = glass.albedo_color
    glass.emission_energy_multiplier = [0.30,0.58,1.02][theme]
    var glow_transforms: Array[Transform3D] = []
    for section in range(SEGMENTS):
        var z: float = 8.0-float(section)*LEN+float(variation-1)*1.8
        for side in [-1.0,1.0]:
            var x: float = stage.track_center_at(z)+side*(
                GLOW_SHOULDER+float(section%3)*0.85)
            var y: float = stage.height_at(z)+[2.9,3.8,3.3][theme]
            var place := Vector3(x,y,z)
            glow_positions.append(place)
            var dimensions := Vector3(
                [0.23,0.22,0.47][theme],
                [0.11,0.31,0.27][theme],0.17)
            glow_transforms.append(Transform3D(Basis().scaled(
                dimensions),place))
    accent_lights = _batch("BiomeAccentGlints_36",accent,glow_transforms)
    accent_lights.material_override = glass

func set_quality(quality: int) -> void:
    visual_quality = clampi(quality,0,2)
    # Physical route and original primary silhouettes stay on all tiers.
    # On a slow Android phone, discard the small distant glints first.
    if is_instance_valid(depth_ridges):
        depth_ridges.visible = visual_quality >= 1
    if is_instance_valid(near_forms):
        near_forms.visible = true
    if is_instance_valid(accent_lights):
        accent_lights.visible = visual_quality >= 2

func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
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
    return node
