extends Node3D
## Rideable split-slope apexes and biome-specific elevated passage vaults.
## Eight real StaticBody3D ramps; all decorative arches are noncolliding
## GPU batches. The central lane remains clear for 40 physical racers.
## No impulses, speed cheats, animated collision or hidden client authority.
const BANK_SECTIONS := [2,7,12,15]
const VAULT_SECTIONS := [4,9,14]
const BANK_HALF_LENGTH := 2.44
const BANK_WIDTH := 3.1
const BANK_THICKNESS := 0.11
const BANK_PITCH := 0.065
const BANK_CANT := 0.055
const BANK_OFFSET := 2.85
const BANK_TOP_RISE := 0.20
const VAULT_CLEARANCE := 5.0
const VAULT_HALF_WIDTH := 7.75
const VAULT_RIB_OFFSETS := [-3.3,0.0,3.3]
# Three visibly different profiles: warm timber canopy, pointed Alpine ice
# passage and lower industrial foundry ribs. Silhouette, not just recolor.
const VAULT_PITCHES := [0.15,0.245,0.19]
const COLOR_BODIES := [
    Color("#98704e"),Color("#719ab0"),Color("#77504a")]
const COLOR_GLOWS := [
    Color("#e6bf7f"),Color("#a8efff"),Color("#ffad66")]

var game: Node3D
var biome := 0
var variation := 0
var banks: Array[StaticBody3D] = []
var bank_roots: Array[Vector3] = []
var bank_surfaces: MultiMeshInstance3D
var apex_inlays: MultiMeshInstance3D
var vault_posts: MultiMeshInstance3D
var vault_roofs: MultiMeshInstance3D
var vault_highlights: MultiMeshInstance3D
var canopy_panels: MultiMeshInstance3D
var canopy_trims: MultiMeshInstance3D
var arch_rib_count := 0
var vault_crest_points: Array[Vector3] = []
var quality := 1

static func bank_side(section: int, track: int, layout: int) -> float:
    return -1.0 if (section+clampi(track,0,2)+posmod(layout,3))%2 == 0 else 1.0

static func bank_z(section: int, layout: int) -> float:
    return 8.0-float(section)*12.0+[-0.55,0.0,0.55][posmod(layout,3)]

static func is_banked_section(section: int) -> bool:
    return section in BANK_SECTIONS

func _material(tint: Color, glow: float = 0.0) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = tint
    result.roughness = 0.48 if biome != 1 else 0.28
    result.metallic = 0.20 if biome == 0 else 0.43
    result.emission_enabled = glow > 0.0
    if glow > 0.0:
        result.emission = tint
        result.emission_energy_multiplier = glow
    return result

func _instanced(label: String, mesh: Mesh, material: Material,
        instances: Array[Transform3D]) -> MultiMeshInstance3D:
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = mesh
    batch.instance_count = instances.size()
    for index in range(instances.size()):
        batch.set_instance_transform(index,instances[index])
    var art := MultiMeshInstance3D.new()
    art.name = label
    art.multimesh = batch
    art.material_override = material
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(art)
    return art

func setup(owner: Node3D, track: int, layout: int) -> void:
    name = "SculptedRacePassages"
    game = owner
    biome = clampi(track,0,2)
    variation = posmod(layout,3)
    _banked_racing_apexes()
    _world_passage_vaults()
    set_quality(game.graphics_quality)

func _banked_racing_apexes() -> void:
    var art_transforms: Array[Transform3D] = []
    var inlays: Array[Transform3D] = []
    var shape := BoxShape3D.new()
    shape.size = Vector3(BANK_WIDTH,BANK_THICKNESS,BANK_HALF_LENGTH)
    # Same render geometry as the real collider; no mesh/physics mismatch.
    var top := BoxMesh.new()
    top.size = shape.size
    for section in BANK_SECTIONS:
        var z: float = bank_z(section,variation)
        var side: float = bank_side(section,biome,variation)
        var center_x: float = game.track_center_at(z)+side*BANK_OFFSET
        bank_roots.append(Vector3(center_x,game.height_at(z),z))
        var friction := PhysicsMaterial.new()
        friction.friction = [0.92,0.72,0.86][biome]
        friction.bounce = 0.04
        # Both halves incline UP towards a gentle centre crest and DOWN
        # again; the leading edge is 0.04m above the existing road.
        # Roll and steering remain Godot native, never force-modified.
        for half in range(2):
            var toward_start: float = 1.0 if half == 0 else -1.0
            var center_z: float = z+toward_start*BANK_HALF_LENGTH*0.5
            var body := StaticBody3D.new()
            body.name = "PhysicalApex_%02d_%d" % [section,half]
            body.position = Vector3(
                game.track_center_at(center_z)+side*BANK_OFFSET,
                game.height_at(center_z)+0.065,center_z)
            body.rotation = Vector3(
                -atan(game.track_grade_at(center_z))+(
                    BANK_PITCH if half == 0 else -BANK_PITCH),
                0.0,-side*BANK_CANT)
            body.physics_material_override = friction
            var collider := CollisionShape3D.new()
            collider.name = "SculptedApexCollision"
            collider.shape = shape
            body.add_child(collider)
            add_child(body)
            banks.append(body)
            art_transforms.append(body.global_transform)
        # A subtle bright seam over the middle crest helps players read
        # the slope; this is an overlay, never a separate blocking body.
        var inlay_basis := Basis(Vector3.RIGHT,-atan(game.track_grade_at(z)))
        inlays.append(Transform3D(inlay_basis,
            Vector3(center_x,game.height_at(z)+BANK_TOP_RISE+0.015,z)))
    bank_surfaces = _instanced("RideableBankedApex_8",top,
        _material(COLOR_BODIES[biome].lightened(0.16)),art_transforms)
    var lip := BoxMesh.new()
    lip.size = Vector3(BANK_WIDTH-0.3,0.014,0.13)
    apex_inlays = _instanced("ApexCrestInlays_4",lip,
        _material(COLOR_GLOWS[biome],0.54),inlays)

func _world_passage_vaults() -> void:
    var pillars: Array[Transform3D] = []
    var roof_segments: Array[Transform3D] = []
    var highlights: Array[Transform3D] = []
    var canopy_transforms: Array[Transform3D] = []
    var trim_transforms: Array[Transform3D] = []
    # The arch spans the full live course with 5m overhead clearance,
    # and its supports sit outside the guardrail and beyond main racing.
    # They remain noncolliding so a shortcut never hits a decorative post.
    for section in VAULT_SECTIONS:
        var centre_z: float = bank_z(section,variation)
        # Two partial overhead bays between each set of three landmark
        # ribs. Open central skylight and clear 5m headroom keep the ball
        # visible; cosmetic panels NEVER intersect the driveable course.
        for bay in range(VAULT_RIB_OFFSETS.size()-1):
            var z: float = centre_z+(
                float(VAULT_RIB_OFFSETS[bay])+
                float(VAULT_RIB_OFFSETS[bay+1]))*0.5
            var center_x: float = game.track_center_at(z)
            var floor_y: float = game.height_at(z)
            for side in [-1.0,1.0]:
                var roof_pitch: float = side*VAULT_PITCHES[biome]
                var basis := Basis(Vector3.FORWARD,roof_pitch)
                # The panel hugs only the OUTER half of the existing roof;
                # the camera and rising marbles still see through the middle.
                var outboard_x: float = 5.55
                var shift: float = outboard_x-VAULT_HALF_WIDTH*0.56
                var y: float = floor_y+VAULT_CLEARANCE+0.57+(
                    sin(roof_pitch)*side*shift)
                canopy_transforms.append(Transform3D(basis,Vector3(
                    center_x+side*outboard_x,y,z)))
                trim_transforms.append(Transform3D(basis,Vector3(
                    center_x+side*(outboard_x-1.40),y+0.055,z)))
        for rib in VAULT_RIB_OFFSETS:
            var z: float = centre_z+float(rib)
            var center_x: float = game.track_center_at(z)
            var floor_y: float = game.height_at(z)
            arch_rib_count += 1
            for side in [-1.0,1.0]:
                # Each sloping roof half makes a triangular mountain/pass
                # silhouette instead of a flat overhead bar.
                var origin := Vector3(
                    center_x+side*VAULT_HALF_WIDTH*0.56,
                    floor_y+VAULT_CLEARANCE+0.57,z)
                # Pitch outward-downward: both halves rise toward the
                # centre, forming a real Alpine/timber ridge, never a V.
                var pitch: float = float(side)*VAULT_PITCHES[biome]
                var roof_basis := Basis(Vector3.FORWARD,pitch)
                roof_segments.append(Transform3D(roof_basis,origin))
                pillars.append(Transform3D(Basis(),
                    Vector3(center_x+side*VAULT_HALF_WIDTH,
                    floor_y+VAULT_CLEARANCE*0.5,z)))
            var crest_height: float = floor_y+VAULT_CLEARANCE+0.57+(
                sin(VAULT_PITCHES[biome])*VAULT_HALF_WIDTH*0.5)
            var ridge := Vector3(center_x,crest_height,z)
            vault_crest_points.append(ridge)
            highlights.append(Transform3D(Basis(),
                ridge+Vector3(0.0,0.08,0.0)))
    var column_mesh := BoxMesh.new()
    column_mesh.size = Vector3(0.43,VAULT_CLEARANCE,0.62)
    vault_posts = _instanced("NineGatewayPillarPairs",column_mesh,
        _material(COLOR_BODIES[biome].darkened(0.16)),pillars)
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(VAULT_HALF_WIDTH+0.29,0.34,0.62)
    vault_roofs = _instanced("NineSculptedGatewayRidges",roof_mesh,
        _material(COLOR_BODIES[biome].lightened(0.27)),roof_segments)
    var neon := BoxMesh.new()
    neon.size = Vector3(1.4,0.08,0.74)
    vault_highlights = _instanced("NineGatewayCrestLights",neon,
        _material(COLOR_GLOWS[biome],1.15),highlights)
    # 12 reused meshes in ONE GPU batch instead of separate tunnel roofs.
    # Timber slats, ice overhangs and metallic foundry awnings share the
    # identical safe geometry, but differ in material roughness/metallic.
    var canopy_mesh := BoxMesh.new()
    canopy_mesh.size = Vector3(2.90,0.10,3.00)
    canopy_panels = _instanced("TwelveOpenSkyCanopyBays",canopy_mesh,
        _material(COLOR_BODIES[biome].lightened(
            0.28 if biome == 1 else 0.12)),canopy_transforms)
    var line_mesh := BoxMesh.new()
    line_mesh.size = Vector3(0.09,0.035,3.08)
    canopy_trims = _instanced("TwelveCanopyLuminousGuides",line_mesh,
        _material(COLOR_GLOWS[biome],0.42),trim_transforms)

func set_quality(value: int) -> void:
    quality = clampi(value,0,2)
    # All real 3D bank colliders and their paint remain in ECONOMY.
    # Small glow inlays and gateway accents are optional, not gameplay.
    if is_instance_valid(bank_surfaces):
        bank_surfaces.visible = true
    if is_instance_valid(vault_posts):
        vault_posts.visible = true
    if is_instance_valid(vault_roofs):
        vault_roofs.visible = true
    if is_instance_valid(apex_inlays):
        apex_inlays.visible = quality >= 1
    if is_instance_valid(vault_highlights):
        vault_highlights.visible = quality >= 1
    if is_instance_valid(canopy_panels):
        canopy_panels.visible = quality >= 1
    if is_instance_valid(canopy_trims):
        canopy_trims.visible = quality >= 2
