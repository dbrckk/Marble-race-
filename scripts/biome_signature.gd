extends Node3D
## Three unmistakable noncolliding landscape silhouettes plus ambient motion.
## Only 3 MultiMesh draws per biome, 12 static monuments + tiny mote batch.
## Everything stays off track. Economy mode retains only big landmarks.
const MOTE_SHADER = preload("res://shaders/biome_motes.gdshader")
const CORE_NAMES := ["TimberWindmills","GlacierCrystalSpires","ForgeChimneys"]
const DETAIL_NAMES := ["CopperWindmillBlades","FacetedIceBranches","HotForgeRings"]
const THEME_NAMES := ["WOODLAND MILL","FROST CRYSTALS","EMBER FURNACE"]
const COLORS := [
    Color("#d3a66c"),Color("#91e8fa"),Color("#ff9d58")]
const MOTES := [
    Color(0.82,1.0,0.66,0.61),Color(0.75,0.93,1.0,0.60),
    Color(1.0,0.55,0.27,0.63)]
const SLOPE := 0.085
const LANDMARK_SECTIONS := [1,4,7,10,13,16]

var biome := 0
var layout := 0
var hero: MultiMeshInstance3D
var details: MultiMeshInstance3D
var motes: MultiMeshInstance3D
var signs: Array[Label3D] = []
var quality := 1

func setup(stage: Node3D, track: int, variation: int) -> void:
    name = "TrackSignatureLandmarks"
    biome = clampi(track,0,2)
    layout = posmod(variation,3)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = [
        Color("#6e5134"),Color("#8bc6d9"),Color("#38383c")][biome]
    dark.roughness = 0.77 if biome == 0 else 0.37
    dark.metallic = 0.12 if biome < 2 else 0.54
    var accent := StandardMaterial3D.new()
    accent.albedo_color = COLORS[biome]
    accent.roughness = 0.40
    accent.metallic = 0.19 if biome < 2 else 0.42
    accent.emission_enabled = true
    accent.emission = COLORS[biome]
    accent.emission_energy_multiplier = [0.14,0.64,1.04][biome]
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = [0.55,0.0,0.63][biome]
    core_mesh.bottom_radius = [0.73,0.86,0.85][biome]
    core_mesh.height = [4.6,5.8,5.0][biome]
    core_mesh.radial_segments = [10,5,9][biome]
    var detail_mesh: Mesh
    if biome == 0:
        var rotor := BoxMesh.new()
        rotor.size = Vector3(0.42,3.4,0.23)
        detail_mesh = rotor
    elif biome == 1:
        var shard := CylinderMesh.new()
        shard.top_radius = 0.0
        shard.bottom_radius = 0.36
        shard.height = 2.9
        shard.radial_segments = 5
        detail_mesh = shard
    else:
        var collar := TorusMesh.new()
        collar.inner_radius = 0.64
        collar.outer_radius = 0.83
        collar.rings = 14
        collar.ring_segments = 7
        detail_mesh = collar
    var core_at: Array[Transform3D] = []
    var detail_at: Array[Transform3D] = []
    var h: float = core_mesh.height
    for section in LANDMARK_SECTIONS:
        var index: int = LANDMARK_SECTIONS.find(section)
        var z: float = 8.0-float(section)*12.0
        for side in [-1.0,1.0]:
            var site_z: float = z+float(layout-1)*1.4
            var x: float = stage.track_center_at(site_z)+side*(
                14.4+float((index+layout)%3)*0.8)
            var ground: float = stage.height_at(site_z)
            var origin := Vector3(x,ground+h*0.5-0.35,site_z)
            core_at.append(Transform3D(
                Basis(Vector3.UP,float(section)*0.21+side*0.19),origin))
            if biome == 0:
                # Cross-shaped wooden windmill mechanism, high and to
                # the side of the course to preserve clean sightlines.
                for blade in range(2):
                    var blade_basis := Basis(Vector3.FORWARD,
                        float(index+layout)*0.41+float(blade)*PI*0.5)
                    detail_at.append(Transform3D(blade_basis,
                        Vector3(x,ground+h-0.18,site_z+0.65)))
            elif biome == 1:
                # Several outward-leaning icy spurs break up the otherwise
                # regular crystalline tower silhouette.
                for spur in range(3):
                    var lean := (-0.40+float(spur)*0.39)*side
                    var tilt := Basis(Vector3.FORWARD,lean)
                    detail_at.append(Transform3D(
                        tilt.scaled(Vector3(0.92,1.0+float(spur)*0.13,0.92)),
                        Vector3(x+float(spur-1)*0.82,
                        ground+1.15+float(spur%2)*0.56,site_z)))
            else:
                # Real 3D glowing metal collars around each furnace
                # stack; always outside physics and gameplay.
                for collar_index in range(2):
                    detail_at.append(Transform3D(Basis(),
                        Vector3(x,ground+2.0+float(collar_index)*2.15,site_z)))
            if index % 2 == 0:
                var sign := Label3D.new()
                sign.name = "WorldMarker_%02d_%s" % [
                    section,"L" if side < 0 else "R"]
                sign.text = THEME_NAMES[biome]
                sign.font_size = 33
                sign.pixel_size = 0.010
                sign.outline_size = 7
                sign.modulate = COLORS[biome]
                sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                sign.position = Vector3(x,ground+h+1.55,site_z)
                add_child(sign)
                signs.append(sign)
    hero = _batch(CORE_NAMES[biome],core_mesh,dark,core_at)
    details = _batch(DETAIL_NAMES[biome],detail_mesh,accent,detail_at)
    var mote_mesh := SphereMesh.new()
    mote_mesh.radius = 0.065 if biome != 1 else 0.045
    mote_mesh.height = mote_mesh.radius*2.0
    mote_mesh.radial_segments = 6
    mote_mesh.rings = 3
    var motes_at: Array[Transform3D] = []
    # 72 instanced sparkles, located off the live racing corridor.
    for section in range(18):
        for side in [-1.0,1.0]:
            for particle in range(2):
                var z: float = 6.0-float(section)*12.0-float(particle)*2.6
                var drift_x: float = float((section+particle+layout)%3)*0.52
                var x: float = stage.track_center_at(z)+side*(8.45+drift_x)
                var y: float = stage.height_at(z)+1.65+(
                    float((section+particle*3)%5)*0.42)
                motes_at.append(Transform3D(Basis(),
                    Vector3(x,y,z)))
    var motes_material := ShaderMaterial.new()
    motes_material.shader = MOTE_SHADER
    motes_material.set_shader_parameter("mote_color",MOTES[biome])
    motes_material.set_shader_parameter("drift_speed",[0.65,0.34,1.45][biome])
    motes_material.set_shader_parameter("drift_span",[0.28,0.37,0.48][biome])
    motes = _batch("InstancedAmbientMotes",mote_mesh,motes_material,motes_at)
    set_quality(stage.graphics_quality)

func _batch(label: String, geometry: Mesh, shader: Material,
    poses: Array[Transform3D]) -> MultiMeshInstance3D:
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = geometry
    batch.instance_count = poses.size()
    for i in range(poses.size()):
        batch.set_instance_transform(i,poses[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = batch
    node.material_override = shader
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node

func set_quality(next_quality: int) -> void:
    quality = clampi(next_quality,0,2)
    # Tall biome silhouettes remain on ECONOMY, while subtle embellishment
    # and additive particles drop out first on slower phones.
    if is_instance_valid(hero):
        hero.visible = true
    if is_instance_valid(details):
        details.visible = quality >= 1
    if is_instance_valid(motes):
        motes.visible = quality >= 1
    for sign in signs:
        if is_instance_valid(sign):
            sign.visible = quality >= 1
