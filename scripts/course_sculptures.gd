extends Node3D
## Rideable split-slope apexes and biome-specific elevated passage vaults.
## Eight real StaticBody3D ramps; all decorative arches are noncolliding
## GPU batches. The central lane remains clear for 40 physical racers.
## No impulses, speed cheats, animated collision or hidden client authority.
const BANK_SECTIONS := [2,7,12,15]
const VAULT_SECTIONS := [4,9,14]
const GLACIER_RETURN_SECTOR := 1
const GLACIER_RETURN_VAULT := VAULT_SECTIONS[GLACIER_RETURN_SECTOR]
const BANK_HALF_LENGTH := 2.44
const BANK_WIDTH := 3.1
const BANK_THICKNESS := 0.11
const BANK_PITCH := 0.065
const BANK_CANT := 0.055
const BANK_OFFSET := 2.85
const BANK_TOP_RISE := 0.20
# A spare collision-layer bit identifies ONLY true rideable apexes for a
# bounded physics ray. Marbles still collide normally on the original bit 1.
const BANK_PROBE_LAYER := 4
const APEX_MIN_FORWARD_SPEED := 7.5
const APEX_FORWARD_IMPULSE := 1.10
const APEX_LIFT_IMPULSE := 0.34
const APEX_TOUCH_MIN := 0.27
const APEX_TOUCH_MAX := 0.67
const APEX_Z_WINDOW := 1.75
const APEX_LANE_WINDOW := 1.18
const APEX_FLASH_SECONDS := 0.65
const VAULT_CLEARANCE := 5.0
const VAULT_HALF_WIDTH := 7.75
const VAULT_RIB_OFFSETS := [-3.3,0.0,3.3]
# Three visibly different profiles: warm timber canopy, pointed Alpine ice
# passage and open industrial foundry ribs.
const VAULT_PITCHES := [0.15,0.245,0.36]
const FORGE_RIB_OFFSET := 6.70
const FORGE_RIB_LENGTH := 2.80
const FORGE_CANOPY_OFFSET := 6.55
const FORGE_CANOPY_WIDTH := 2.50
const FORGE_LIGHT_OFFSET := 5.54
const FORGE_LIGHT_WIDTH := 0.72
const EDGE_SECTOR_POST_OFFSET := 6.67
const EDGE_SECTOR_SIGN_HEIGHT := 2.38
const EDGE_SECTOR_BEACON_HEIGHT := 2.97
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
# Keep the CPU transforms for the batched roof bounds checked in headless QA.
var vault_rib_roots: Array[Transform3D] = []
# CPU-side source positions: MultiMesh GPU readback is unavailable in
# headless CI and may return identity transforms on mobile backends.
var canopy_roots: Array[Transform3D] = []
var quality := 1
var earned_apex: Dictionary = {}
var last_ray_queries := 0
var validated_apex_hits := 0
var apex_inlay_roots: Array[Transform3D] = []
var apex_flash: Array[float] = []

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
    apex_flash.resize(BANK_SECTIONS.size())
    reset_round()
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
            # Only apex road collision shares this extra probe bit. The
            # original marble contact layer/mask stay unchanged.
            body.collision_layer = 1 | BANK_PROBE_LAYER
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
    apex_inlay_roots = inlays.duplicate()

func _world_passage_vaults() -> void:
    var pillars: Array[Transform3D] = []
    var highlights: Array[Transform3D] = []
    var trim_transforms: Array[Transform3D] = []
    var forge := biome == 2
    var roof_pitch: float = VAULT_PITCHES[biome]
    # The Glacier return opens both lanes under one passage. The exterior
    # glacier rib sits farther out on the bridge side than on the main road.
    for section in VAULT_SECTIONS:
        var glacier_return: bool = biome == 1 and section == GLACIER_RETURN_VAULT
        # Keep the chase-camera corridor open at every sector. Glacier's
        # return also extends its outer wing past the detached ice deck.
        var open_junction: bool = not forge and not glacier_return
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
                var basis := Basis(Vector3.FORWARD,side*roof_pitch)
                var outboard_x := FORGE_CANOPY_OFFSET if forge else 5.55
                var rib_x := FORGE_RIB_OFFSET if forge else VAULT_HALF_WIDTH*0.56
                var y := floor_y+VAULT_CLEARANCE+0.57
                if glacier_return:
                    outboard_x = _glacier_return_rib_offset(side)
                    basis = basis.scaled_local(Vector3(0.64,1.0,1.0))
                    y = floor_y+VAULT_CLEARANCE+0.32
                elif open_junction:
                    outboard_x = FORGE_CANOPY_OFFSET
                    basis = basis.scaled_local(Vector3(0.70,1.0,1.0))
                    y -= tan(roof_pitch)*(outboard_x-FORGE_RIB_OFFSET)
                elif forge:
                    y -= tan(roof_pitch)*(outboard_x-rib_x)
                else:
                    y += sin(roof_pitch)*(outboard_x-rib_x)
                var canopy_point := Vector3(
                    center_x+side*outboard_x,y,z)
                canopy_roots.append(Transform3D(basis,canopy_point))
                var trim_offset := (FORGE_CANOPY_WIDTH*0.5-0.08)*cos(roof_pitch) if forge else 1.40
                if glacier_return:
                    trim_offset = 0.83
                elif open_junction:
                    trim_offset = 0.96
                trim_transforms.append(Transform3D(basis.orthonormalized(),Vector3(
                    center_x+side*(outboard_x-trim_offset),
                    y+0.055+(tan(roof_pitch)*trim_offset if forge or glacier_return or open_junction else 0.0),z)))
        for rib in VAULT_RIB_OFFSETS:
            var z: float = centre_z+float(rib)
            var center_x: float = game.track_center_at(z)
            var floor_y: float = game.height_at(z)
            arch_rib_count += 1
            var rib_x := FORGE_RIB_OFFSET if forge else VAULT_HALF_WIDTH*0.56
            var rib_y := floor_y+VAULT_CLEARANCE+0.57
            var crest_x := FORGE_LIGHT_OFFSET if forge else 0.0
            var crest_y := rib_y+(tan(roof_pitch)*(rib_x-crest_x) if forge else (
                sin(roof_pitch)*VAULT_HALF_WIDTH*0.5))
            if glacier_return:
                rib_y = floor_y+VAULT_CLEARANCE+0.32
                crest_x = _glacier_return_rib_offset(1.0)-0.64
                crest_y = rib_y+tan(roof_pitch)*0.64
            elif open_junction:
                crest_x = FORGE_LIGHT_OFFSET
                crest_y = rib_y+tan(roof_pitch)*(FORGE_RIB_OFFSET-crest_x)
            vault_crest_points.append(Vector3(center_x+crest_x,crest_y,z))
            for side in [-1.0,1.0]:
                var post_x := VAULT_HALF_WIDTH
                var flank_rib_x := rib_x
                var roof_basis := Basis(Vector3.FORWARD,side*roof_pitch)
                var roof_scale := Vector3.ONE
                var support_height := VAULT_CLEARANCE
                if glacier_return:
                    flank_rib_x = _glacier_return_rib_offset(side)
                    roof_scale.x = 0.30
                    post_x = flank_rib_x+0.90
                    support_height = rib_y-floor_y-tan(roof_pitch)*0.90
                    highlights.append(Transform3D(roof_basis.scaled_local(Vector3(0.58,1.0,1.0)),
                        Vector3(center_x+side*(flank_rib_x-0.64),crest_y+0.14,z)))
                elif forge:
                    support_height += 0.57-tan(roof_pitch)*(post_x-rib_x)
                    highlights.append(Transform3D(roof_basis,
                        Vector3(center_x+side*crest_x,crest_y+0.14,z)))
                elif open_junction:
                    flank_rib_x = FORGE_RIB_OFFSET
                    roof_scale.x = 0.32
                    support_height += 0.57-tan(roof_pitch)*(post_x-flank_rib_x)
                    highlights.append(Transform3D(roof_basis.scaled_local(Vector3(0.48,1.0,1.0)),
                        Vector3(center_x+side*crest_x,crest_y+0.14,z)))
                var origin := Vector3(center_x+side*flank_rib_x,rib_y,z)
                vault_rib_roots.append(Transform3D(roof_basis.scaled_local(roof_scale),origin))
                pillars.append(Transform3D(Basis().scaled(
                    Vector3(1.0,support_height/VAULT_CLEARANCE,1.0)),
                    Vector3(center_x+side*post_x,
                    floor_y+support_height*0.5,z)))
            if not forge and not glacier_return and not open_junction:
                highlights.append(Transform3D(Basis(),
                    Vector3(center_x,crest_y+0.08,z)))
    var column_mesh := BoxMesh.new()
    column_mesh.size = Vector3(0.43,VAULT_CLEARANCE,0.62)
    vault_posts = _instanced("NineGatewayPillarPairs",column_mesh,
        _material(COLOR_BODIES[biome].darkened(0.16)),pillars)
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(FORGE_RIB_LENGTH if forge else VAULT_HALF_WIDTH+0.29,0.34,0.62)
    vault_roofs = _instanced("NineSculptedGatewayRidges",roof_mesh,
        _material(COLOR_BODIES[biome].lightened(0.27)),vault_rib_roots)
    var neon := BoxMesh.new()
    neon.size = Vector3(FORGE_LIGHT_WIDTH if forge else 1.4,0.08,0.74)
    vault_highlights = _instanced("NineGatewayCrestLights",neon,
        _material(COLOR_GLOWS[biome],1.15),highlights)
    # 12 reused meshes in ONE GPU batch instead of separate tunnel roofs.
    # Timber slats, ice overhangs and metallic foundry awnings share the
    # identical safe geometry, but differ in material roughness/metallic.
    var canopy_mesh := BoxMesh.new()
    canopy_mesh.size = Vector3(FORGE_CANOPY_WIDTH if forge else 2.90,0.10,3.00)
    canopy_panels = _instanced("TwelveOpenSkyCanopyBays",canopy_mesh,
        _material(COLOR_BODIES[biome].lightened(
            0.28 if biome == 1 else 0.12)),canopy_roots)
    var line_mesh := BoxMesh.new()
    line_mesh.size = Vector3(0.09,0.035,3.08)
    canopy_trims = _instanced("TwelveCanopyLuminousGuides",line_mesh,
        _material(COLOR_GLOWS[biome],0.42),trim_transforms)

static func _glacier_return_rib_offset(side: float) -> float:
    return 13.5 if side < 0.0 else VAULT_HALF_WIDTH

# The reward is earned ONLY by touching the already-existing bank mesh
# at racing speed. The authoritative server/offline physics world performs
# the sole ray query; a multiplayer client cannot forge an apex impulse.
static func valid_apex_contact(forward_speed: float,
        surface_clearance: float, lateral: float) -> bool:
    return is_finite(forward_speed) and is_finite(surface_clearance) and (
        is_finite(lateral) and forward_speed >= APEX_MIN_FORWARD_SPEED and
        surface_clearance >= APEX_TOUCH_MIN and
        surface_clearance <= APEX_TOUCH_MAX and
        absf(lateral) <= APEX_LANE_WINDOW)

func tick(racers: Array[RigidBody3D], net: Node) -> void:
    last_ray_queries = 0
    if net.role == "client":
        return
    for marble in racers:
        if not is_instance_valid(marble) or marble.finished or (
                marble.eliminated or marble.freeze):
            continue
        var position: Vector3 = marble.global_position
        if not position.is_finite() or (
                marble.linear_velocity.z > -APEX_MIN_FORWARD_SPEED):
            continue
        for index in range(BANK_SECTIONS.size()):
            var z: float = bank_z(BANK_SECTIONS[index],variation)
            if absf(position.z-z) > APEX_Z_WINDOW:
                continue
            var key: String = "%d:%d" % [index,marble.racer_id]
            if earned_apex.has(key):
                continue
            var x: float = game.track_center_at(position.z)+(
                bank_side(BANK_SECTIONS[index],biome,variation)*BANK_OFFSET)
            if absf(position.x-x) > APEX_LANE_WINDOW:
                continue
            # Cheap geometric height rejection before querying physics.
            if position.y < game.height_at(position.z)+0.20 or (
                    position.y > game.height_at(position.z)+1.1):
                continue
            var query := PhysicsRayQueryParameters3D.create(
                position+Vector3(0.0,0.08,0.0),
                position-Vector3(0.0,0.9,0.0),BANK_PROBE_LAYER)
            last_ray_queries += 1
            var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
            if hit.is_empty() or not banks.has(hit.get("collider")):
                continue
            var clearance: float = position.y-(
                hit["position"] as Vector3).y
            if not valid_apex_contact(
                    -marble.linear_velocity.z,clearance,position.x-x):
                continue
            earned_apex[key] = true
            validated_apex_hits += 1
            marble.apply_central_impulse(Vector3(
                0.0,APEX_LIFT_IMPULSE,-APEX_FORWARD_IMPULSE)*marble.mass)
            if net.role == "offline" and marble.is_player:
                flash_local_apex(position.z)
            if net.role == "server":
                if marble.network_controlled and (
                        net.joined_slots.values().has(marble.racer_id)):
                    net.notify_course_event(marble.racer_id,"apex")
            elif net.role == "offline" and marble.is_player:
                game.audio.course_event("apex")
                game.ui.show_course_event("apex")
            # One verified bank is enough; a marble cannot touch two at once.
            break

func apex_pass_count(racer_id: int) -> int:
    var result := 0
    for i in range(BANK_SECTIONS.size()):
        if earned_apex.has("%d:%d" % [i,racer_id]):
            result += 1
    return result

func flash_local_apex(z: float) -> bool:
    if not is_finite(z):
        return false
    for i in range(BANK_SECTIONS.size()):
        if absf(z-bank_z(BANK_SECTIONS[i],variation)) <= (
                APEX_Z_WINDOW+0.55):
            apex_flash[i] = APEX_FLASH_SECONDS
            return true
    return false

func advance_visuals(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    for i in range(apex_flash.size()):
        if apex_flash[i] <= 0.0:
            continue
        apex_flash[i] = maxf(0.0,apex_flash[i]-delta)
        if quality == 0 or not is_instance_valid(apex_inlays):
            continue
        var pulse: float = apex_flash[i]/APEX_FLASH_SECONDS
        var original: Transform3D = apex_inlay_roots[i]
        apex_inlays.multimesh.set_instance_transform(i,Transform3D(
            original.basis.scaled(Vector3(1.0+0.42*pulse,1.0,
                1.0+0.42*pulse)),original.origin))

func reset_round() -> void:
    earned_apex.clear()
    validated_apex_hits = 0
    last_ray_queries = 0
    for i in range(apex_flash.size()):
        apex_flash[i] = 0.0
        if is_instance_valid(apex_inlays):
            apex_inlays.multimesh.set_instance_transform(
                i,apex_inlay_roots[i])

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
        if quality >= 1:
            for i in range(apex_flash.size()):
                var original: Transform3D = apex_inlay_roots[i]
                var pulse: float = apex_flash[i]/APEX_FLASH_SECONDS
                apex_inlays.multimesh.set_instance_transform(i,Transform3D(
                    original.basis.scaled(Vector3(1.0+0.42*pulse,1.0,
                        1.0+0.42*pulse)),original.origin))
    if is_instance_valid(vault_highlights):
        vault_highlights.visible = quality >= 1
    if is_instance_valid(canopy_panels):
        canopy_panels.visible = quality >= 1
    if is_instance_valid(canopy_trims):
        canopy_trims.visible = quality >= 2
