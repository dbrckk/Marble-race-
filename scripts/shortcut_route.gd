extends Node3D
## v1.16: real, collidable alternate race road with two side-rail portals.
## Each course has a different exterior branch. Physics and rewards are
## evaluated by the offline game or authoritative dedicated server only.
const ARCHITECTURE = preload("res://scripts/course_architecture.gd")
const TrackSurface = preload("res://scripts/track_surface.gd")
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const Racer = preload("res://scripts/marble.gd")
const ENTRY_SECTION := 5
const EXIT_SECTION := 9
const ENTRY_Z := -48.0
const ENTRY_PORTAL_Z := -52.0
const EXIT_Z := -104.0
const PORTAL_HALF_LENGTH := 2.0
const FORK_GUIDANCE_REACH := 32.0
const MERGE_GUIDANCE_REACH := 23.0
const MERGE_TRAFFIC_NEAR := EXIT_Z+10.0
const MERGE_TRAFFIC_FAR := EXIT_Z-2.0
const MERGE_CONFLICT_HORIZON := 1.15
const MERGE_CONFLICT_GAP := 0.55
const MAIN_MERGE_Z := [EXIT_Z+11.0,EXIT_Z+8.1,EXIT_Z+5.2,EXIT_Z+2.3]
const MAIN_MERGE_INK := Color("#a7f4ed")
const FORK_ARROW_LEAD := 14.5
const FORK_MARK_MIN_DISTANCE := 4.0
const GLACIER_RETURN_COLOR := Color("#ffda8c")
const FORGE_EDGE_COLOR := Color("#ffc86e")
const FORGE_MAIN_COLOR := Color("#b6f6ed")
const FORK_MAIN_COLOR := FORGE_MAIN_COLOR
const FORK_BRIDGE_COLOR := FORGE_EDGE_COLOR
const FORK_CHECK_END := ENTRY_PORTAL_Z-3.0
const FORK_REACTION := 0.10
const FORK_TRAFFIC_CLEARANCE := Racer.RADIUS*2.0+0.16
const RETURN_ARROW_Z := [-89.0,-93.0,-97.0,-100.0,-103.0]
const OUTER_START := -60.0
const OUTER_END := -92.0
const INNER_OFFSET := 4.90
const OUTER_OFFSET := 10.45
const WIDTH := 3.80
const SEGMENTS := 28
const REWARD_Z := -79.0
const REWARD_RADIUS := 2.15
# Each elevated route is a deliberate precision corridor: the outer edge
# catches sloppy lines, while the middle 2.8 metres stay unobstructed for AI.
const BRIDGE_POST_Z := [-65.0,-80.0,-90.0]
const FORGE_GATE_APPROACH := [
    [8.0,6.0,4.0,2.0,0.8],
    [13.2,10.6,8.0,5.4,2.8,0.8],
    [8.0,6.0,4.0,2.0,0.8]
]
const BRIDGE_ENTRY_X := 6.68
const FORGE_BRIDGE_EDGE_X := 6.35
const FORGE_GATE_TRAFFIC_SECONDS := 0.95
const FORGE_GATE_SETTLE_SECONDS := 0.48
const FORGE_GATE_EXIT_PAD := 1.25
const BRIDGE_POST_OFFSET := 1.76
const BRIDGE_POST_RADIUS := 0.22
const BRIDGE_POST_HEIGHT := 0.88
const BRIDGE_ARCH_HALF_SPAN := WIDTH*0.5+0.62
const ROLLING_SURFACE := &"bridge_rolling_surface"
# Three real crossing planes embedded in the existing physical bridge.
# Crossing in order, at speed and near the center of each pair of posts,
# earns a single bounded skill reward. No decorative trigger volumes.
const PRECISION_GATE_HALF_WIDTH := 1.03
const PRECISION_GATE_MIN_HEIGHT := 0.20
const PRECISION_GATE_MAX_HEIGHT := 2.45
const PRECISION_GATE_MIN_SPEED := 5.5
const PRECISION_GATE_MAX_STEP := 1.35
const PRECISION_BONUS_FORWARD := 2.35
const PRECISION_BONUS_LIFT := 0.20
# Only the entry portal, takeoff pads, reward and three precision gates
# can affect physics; the last skill gate is at z=-90 on each course.
# The other 120m of road never needs the curved bypass query at 60 Hz.
const EFFECT_WINDOW_NEAR := ENTRY_Z + 1.5
const EFFECT_WINDOW_FAR := -92.0
const JUMP_Z := [-71.0,-74.0,-86.0]
const ENTRY_WINDOW := 12.0
const MAX_BANK := 0.080
# Extra physical clearance above the main deck at the centre of each bypass.
# The entire bridge (not merely its visual mesh) follows this terrain profile.
const BRIDGE_RISE := [0.72,1.12,1.42]
const MAX_BRIDGE_GRADE := 0.30
const SIDES := [1,-1,1]
const TINTS := [Color("#f9bf79"),Color("#a3f5ff"),Color("#f89a6e")]

var stage: Node3D
var course_id := 0
var side := 1
var decks: Array[StaticBody3D] = []
var guards: Array[StaticBody3D] = []
var triggered: Dictionary = {}
var entered: Dictionary = {}
var jumped: Dictionary = {}
# Authoritative per-round progress; all three gate crossings must occur in
# physical order. Clients only receive presentation events.
var precision_progress: Dictionary = {}
var precision_last_z: Dictionary = {}
var precision_failed: Dictionary = {}
var precision_complete: Dictionary = {}
var launch_ramps: Array[StaticBody3D] = []
var precision_posts: Array[StaticBody3D] = []
var precision_post_positions: Array[Vector3] = []
var banked_segments := 0
var physical_distance := 0.0
var effect_candidates_last_tick := 0
var glacier_return_arrows: Array[Transform3D] = []
var main_merge_arrows: Array[Transform3D] = []
var fork_main_marks: Array[Vector3] = []
var fork_bridge_marks: Array[Vector3] = []
var route_arrows: MultiMesh
var paint_frames := 0

static func inside_effect_window(z: float) -> bool:
    return z <= EFFECT_WINDOW_NEAR and z >= EFFECT_WINDOW_FAR

static func side_for(track: int) -> int:
    return SIDES[clampi(track,0,2)]

static func opens_rail(section: int, rail_side: int, piece: int, track: int) -> bool:
    if rail_side != side_for(track):
        return false
    if track == 1 and section == EXIT_SECTION:
        # The ice bridge enters at the downhill end of this module.
        return piece == 0 or piece == 1
    return (section == ENTRY_SECTION or section == EXIT_SECTION) and piece == 1

func setup(owner: Node3D, track: int) -> void:
    stage = owner
    course_id = clampi(track,0,2)
    side = side_for(course_id)
    name = "PhysicalShortcutRoute"
    var deck_material := StandardMaterial3D.new()
    deck_material.albedo_color = [
        Color("#a57a49"), Color("#6cbbd4"), Color("#725655")][course_id]
    deck_material.roughness = [0.69,0.19,0.48][course_id]
    deck_material.metallic = 0.22
    var edge_material := StandardMaterial3D.new()
    edge_material.albedo_color = TINTS[course_id]
    edge_material.metallic = 0.46
    edge_material.roughness = 0.28
    edge_material.emission_enabled = true
    edge_material.emission = edge_material.albedo_color
    edge_material.emission_energy_multiplier = 0.46
    var deck_art: Array[Transform3D] = []
    var guard_art: Array[Transform3D] = []
    for i in range(SEGMENTS):
        var za: float = lerpf(ENTRY_Z,EXIT_Z,float(i)/float(SEGMENTS))
        var zb: float = lerpf(ENTRY_Z,EXIT_Z,float(i+1)/float(SEGMENTS))
        var pa := point_at(za)
        var pb := point_at(zb)
        var delta: Vector3 = pb-pa
        var horizontal := Vector2(delta.x,delta.z).length()
        var yaw := -atan2(delta.x,-delta.z)
        var pitch := atan2(delta.y,horizontal)
        var basis := Basis.from_euler(Vector3(pitch,yaw,0.0))
        # Real camber, not a shader fake: collision + rendering share banking.
        var bank := bank_at((za+zb)*0.5)
        basis = basis * Basis(Vector3.FORWARD,bank)
        if absf(bank) > 0.012:
            banked_segments += 1
        var middle := (pa+pb)*0.5
        var length := delta.length()+0.18
        physical_distance += horizontal
        var deck_size := Vector3(WIDTH,0.56,length)
        var deck := _solid("BypassDeck_%02d" % i,middle,basis,deck_size,
            0.12 if course_id == 1 else 0.74)
        deck.set_meta(ROLLING_SURFACE,true)
        decks.append(deck)
        deck_art.append(deck.transform.scaled_local(deck_size))
        # An outer rail also protects transitional branch sections; the
        # inner rail only closes once fully detached from the main deck.
        # Leave 5 metres on both ends unguarded for a wide steering portal.
        var between_z: float = middle.z
        if between_z > ENTRY_Z-5.0 or between_z < EXIT_Z+5.0:
            continue
        for rail_side in [-1,1]:
            if (between_z > OUTER_START or between_z < OUTER_END) and rail_side != side:
                continue
            var lateral: Vector3 = basis*Vector3.RIGHT
            var guard_pos := middle+lateral*float(rail_side)*(WIDTH*0.5-0.06)
            guard_pos.y += 0.61
            var size := Vector3(0.40,1.12,length+0.22)
            var guard := _solid("BypassGuard_%02d_%s" % [
                i,"L" if rail_side < 0 else "R"],guard_pos,basis,size,0.9)
            guards.append(guard)
            guard_art.append(guard.transform.scaled_local(size))
    _batch("BatchedBypassDeck",deck_art,deck_material)
    _batch("BatchedBypassGuards",guard_art,edge_material)
    _bridge_structure()
    _launch_ramps(deck_material)
    _bridge_precision_corridor(edge_material)
    _racing_line(edge_material)
    var signs: Array[Transform3D] = []
    var paint: Array[Transform3D] = []
    var colors: Array[Color] = []
    _fork_signage(signs,paint,colors)
    _return_markings(signs,paint,colors)
    var panel := StandardMaterial3D.new()
    panel.albedo_color = [Color("#493224"),Color("#21374f"),Color("#422b29")][course_id]
    panel.roughness = 0.52
    panel.metallic = 0.28
    _batch("RouteSignPlates",signs,panel)
    _arrow_batch("RouteDirectionArrows",paint,colors)
    reset_round()

func _physics_process(_delta: float) -> void:
    paint_frames += 1
    if paint_frames < 2:
        return
    set_physics_process(false)
    if stage.net.role != "server":
        _mark_main_merge_line()

func _mark_main_merge_line() -> void:
    var ignored: Array[RID] = []
    for marble in stage.racers:
        if is_instance_valid(marble):
            ignored.append(marble.get_rid())
    var slot := route_arrows.instance_count-MAIN_MERGE_Z.size()
    for z in MAIN_MERGE_Z:
        # Stay on the inside of the main deck. Move a mark around a real
        # peg or gate in the layout without painting through the obstacle.
        for lane in [1.72,1.10,2.38]:
            var x: float = stage.track_center_at(z)-side*lane
            var approximate := Vector3(x,stage.height_at(z),z)
            var ground: Dictionary = {}
            var clear := true
            for offset in [Vector3.ZERO,Vector3(-0.42,0,-0.57),Vector3(0.42,0,0.52)]:
                var ray := PhysicsRayQueryParameters3D.create(approximate+offset+Vector3.UP*1.65,
                    approximate+offset+Vector3.DOWN*0.50,1,ignored)
                var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(ray)
                var body: StaticBody3D = hit.get("collider") as StaticBody3D
                if body == null or not body.has_meta(TrackSurface.ROAD_FLOOR):
                    clear = false
                    break
                if offset == Vector3.ZERO:
                    ground = hit
            if not clear:
                continue
            var normal: Vector3 = ground["normal"]
            var tangent := Basis(Quaternion(Vector3.UP,normal))
            var pose := Transform3D(tangent.scaled_local(Vector3(0.60,1.0,0.77)),
                Vector3(ground["position"])+normal*0.050)
            route_arrows.set_instance_transform(slot,pose)
            route_arrows.set_instance_color(slot,MAIN_MERGE_INK)
            main_merge_arrows.append(pose)
            slot += 1
            break

func bridge_lift_at(z: float) -> float:
    # Smoothly match the existing main deck at both portals. On Forge the
    # ridge has two shoulders, rather than the single Glacier crest.
    var progress: float = clampf((ENTRY_Z-z)/(ENTRY_Z-EXIT_Z),0.0,1.0)
    var envelope: float = pow(sin(progress*PI),2.0)
    var shape := 1.0
    if course_id == 2:
        shape = 0.77+0.23*cos(TAU*2.0*progress)
    return envelope*(0.36+BRIDGE_RISE[course_id]*shape)

func bridge_grade_at(z: float) -> float:
    # Launch geometry must align to the *real elevated deck*, not the lower
    # main-road slope. The twin samples share the physics path generator.
    return point_at(z+0.5).y-point_at(z-0.5).y

func _bridge_structure() -> void:
    # Twelve piers and six transverse braces keep two render batches.
    var supports: Array[Transform3D] = []
    var braces: Array[Transform3D] = []
    for index in range(4,SEGMENTS-3,4):
        var z: float = lerpf(ENTRY_Z,EXIT_Z,float(index)/float(SEGMENTS))
        var point: Vector3 = point_at(z)
        var baseline: float = stage.height_at(z)-2.10
        var top: float = point.y-0.24
        var height: float = maxf(1.0,top-baseline)
        var center_y: float = baseline+height*0.5
        for cross_side in [-1.0,1.0]:
            var support_x: float = point.x+cross_side*(WIDTH*0.5+0.38)
            supports.append(Transform3D(
                Basis().scaled(Vector3(0.68,height,0.67)),
                Vector3(support_x,center_y,z)))
        braces.append(Transform3D(
            Basis().scaled(Vector3(WIDTH+1.10,0.38,0.61)),
            point+Vector3(0.0,-0.50,0.0)))
    var paint := ARCHITECTURE.material(course_id)
    _batch("BatchedBypassBridgePylons",supports,paint,ARCHITECTURE.pier(course_id))
    _batch("BatchedBypassBridgeTrusses",braces,paint,ARCHITECTURE.truss(course_id))

func bank_at(z: float) -> float:
    if z > OUTER_START or z < OUTER_END:
        return 0.0
    # Curvature from three points. Suppress banking near all merges.
    var curvature: float = point_at(z-3.0).x-2.0*point_at(z).x+point_at(z+3.0).x
    var fade: float = sin(PI*clampf((OUTER_START-z)/(OUTER_START-OUTER_END),0.0,1.0))
    return clampf(curvature*2.6,-MAX_BANK,MAX_BANK)*fade

func _launch_ramps(material: Material) -> void:
    # Gentle optional air sections; low edges never wall off the narrow deck.
    var at_z: float = JUMP_Z[course_id]
    var at: Vector3 = point_at(at_z)
    var size := Vector3(2.30,0.18,2.65)
    # Local -Z points downhill. A small pitch climbs toward the lip.
    var basis := Basis(Vector3.RIGHT,-atan(bridge_grade_at(at_z))+0.18)
    var ramp := _solid("BypassLaunchRamp",at+Vector3.UP*0.38,basis,size,0.66)
    ramp.set_meta(ROLLING_SURFACE,true)
    launch_ramps.append(ramp)
    _batch("BatchedJumpTakeoff",[ramp.transform.scaled_local(size)],material)

func _bridge_precision_corridor(material: Material) -> void:
    # The six physical posts and three open decorative frames use one
    # batch each. The frame wings leave the chase camera's centre clear.
    var post_art: Array[Transform3D] = []
    var arch_art: Array[Transform3D] = []
    for station in range(BRIDGE_POST_Z.size()):
        var z: float = BRIDGE_POST_Z[station]
        var center: Vector3 = point_at(z)
        for flank in [-1.0,1.0]:
            var origin := center+Vector3(
                flank*BRIDGE_POST_OFFSET,BRIDGE_POST_HEIGHT*0.5+0.32,0.0)
            var post := _solid("BypassPrecisionPost_%d_%d" % [
                station,int(flank)],origin,Basis(),Vector3(
                    BRIDGE_POST_RADIUS*2.0,BRIDGE_POST_HEIGHT,
                    BRIDGE_POST_RADIUS*2.0),0.82)
            var bounce := post.physics_material_override
            bounce.bounce = 0.48
            precision_posts.append(post)
            precision_post_positions.append(origin)
            post_art.append(Transform3D(Basis().scaled(Vector3(
                BRIDGE_POST_RADIUS*2.0,BRIDGE_POST_HEIGHT,
                BRIDGE_POST_RADIUS*2.0)),origin))
        arch_art.append(Transform3D(Basis.IDENTITY,center))
    _batch("BypassPrecisionEdgePosts",post_art,material)
    _batch("BypassPrecisionPortalArches",arch_art,ARCHITECTURE.material(course_id),
        ARCHITECTURE.portal(course_id,BRIDGE_ARCH_HALF_SPAN))
    # Three lightweight, noncolliding deck stripes identify the EXACT
    # physical crossing planes. The existing trim material is reused.
    var marks: Array[Transform3D] = []
    for station in range(BRIDGE_POST_Z.size()):
        var z: float = BRIDGE_POST_Z[station]
        if course_id == 0 or (course_id == 2 and station < FORGE_GATE_APPROACH.size()):
            var pose := _deck_arrow(z,0.0)
            pose.origin.y -= 0.075
            marks.append(pose.scaled_local(Vector3(2.0*PRECISION_GATE_HALF_WIDTH,0.014,0.28)))
            if course_id == 0:
                for flank in [-1.0,1.0]:
                    var edge := pose.translated_local(Vector3(flank*PRECISION_GATE_HALF_WIDTH,0,0.74))
                    marks.append(edge.scaled_local(Vector3(0.11,0.014,1.38)))
            else:
                for distance: float in FORGE_GATE_APPROACH[station]:
                    # Set the height on the real banked deck at each stripe.
                    var approach := _deck_arrow(z+distance,0.0)
                    approach.origin.y -= 0.075
                    for flank in [-1.0,1.0]:
                        var edge := approach.translated_local(Vector3(flank*PRECISION_GATE_HALF_WIDTH,0,0))
                        marks.append(edge.scaled_local(Vector3(0.15,0.014,0.86)))
        else:
            marks.append(Transform3D(Basis().scaled(Vector3(2.07,0.013,0.23)),point_at(z)+Vector3.UP*0.324))
    _batch("BypassPrecisionSkillStripes",marks,material)

func _racing_line(material: Material) -> void:
    var marks: Array[Transform3D] = []
    for index in range(15):
        var z: float = lerpf(ENTRY_Z-7.5,EXIT_Z+7.5,float(index)/14.0)
        var pos: Vector3 = point_at(z)+Vector3.UP*0.325
        var next: Vector3 = point_at(z-0.7)
        var tangent := atan2(next.x-pos.x,0.7)
        var scale_basis := Basis(Vector3.UP,tangent).scaled(Vector3(0.82,0.035,0.32))
        marks.append(Transform3D(scale_basis,pos))
    _batch("BypassNavigationChevrons",marks,material)

func _solid(label: String, origin: Vector3, basis: Basis, size: Vector3,
    friction: float) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = label
    body.transform = Transform3D(basis,origin)
    var contact := PhysicsMaterial.new()
    contact.friction = friction
    contact.bounce = 0.03
    body.physics_material_override = contact
    var collider := CollisionShape3D.new()
    collider.name = "PhysicalShape"
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)
    return body

func _batch(label: String, instances: Array[Transform3D],
        material: Material, geometry: Mesh = null) -> void:
    if instances.is_empty():
        return
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = BoxMesh.new() if geometry == null else geometry
    batch.instance_count = instances.size()
    for i in range(instances.size()):
        batch.set_instance_transform(i,instances[i])
    var rendering := MultiMeshInstance3D.new()
    rendering.name = label
    rendering.multimesh = batch
    rendering.material_override = material
    rendering.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(rendering)

func _fork_signage(signs: Array[Transform3D], paint: Array[Transform3D], colors: Array[Color]) -> void:
    var entry_z := ENTRY_PORTAL_Z+0.7
    var entry_x: float = point_at(entry_z).x+float(side)*1.65
    var title := "↖  BRIDGE" if side < 0 else "BRIDGE  ↗"
    _route_sign("ShortcutEntranceArrow",title,Vector3(
        entry_x,stage.height_at(entry_z)+2.08,entry_z),FORK_BRIDGE_COLOR,signs)

    # On Woodworks, paint the shared approaches between the obstacle rows.
    # Turn the amber arrow outward after clearing the right baffle at -43.75.
    var main_z := [-34.0,-43.5,-46.0] if course_id == 0 else [-36.0,-41.8,-47.3,-51.0]
    for z in main_z:
        _append_fork_arrow(paint,colors,_road_arrow(z,-float(side)*1.55,0.0),false)
    if course_id == 0:
        _append_fork_arrow(paint,colors,_road_arrow(-34.0,1.85,-0.18),true)
        _append_fork_arrow(paint,colors,_road_arrow(-46.0,4.0,-0.34),true)
    else:
        for i in range(4):
            var z := ENTRY_PORTAL_Z+FORK_ARROW_LEAD-float(i)*3.1
            var arrow := _road_arrow(z,float(side)*(1.7+float(i)*0.92),-float(side)*0.34)
            _append_fork_arrow(paint,colors,arrow,true)
    _append_fork_arrow(paint,colors,_deck_arrow(-51.0,0.0),true)
    paint.append(_deck_arrow(-56.7,0.0))
    colors.append(FORK_BRIDGE_COLOR)

func _append_fork_arrow(paint: Array[Transform3D], colors: Array[Color], arrow: Transform3D, bridge: bool) -> void:
    paint.append(arrow)
    colors.append(FORK_BRIDGE_COLOR if bridge else FORK_MAIN_COLOR)
    var marks := fork_bridge_marks if bridge else fork_main_marks
    marks.append(arrow.origin)

func fork_mark_ahead(z: float, speed: float, bridge: bool) -> Vector3:
    var reach := clampf(speed*0.70,7.0,13.0)
    var marks := fork_bridge_marks if bridge else fork_main_marks
    for i in range(marks.size()-1,-1,-1):
        var point := marks[i]
        var distance := z-point.z
        if distance > FORK_MARK_MIN_DISTANCE and distance <= reach:
            return point
    return Vector3.INF

func _return_markings(signs: Array[Transform3D], paint: Array[Transform3D],
        colors: Array[Color]) -> void:
    var tint := GLACIER_RETURN_COLOR
    var sign_z := EXIT_Z+3.1
    _route_sign("ShortcutMergeArrow","MERGE  ↗" if side < 0 else "↖  MERGE",
        point_at(sign_z)+Vector3(side*1.58,1.52,0.0),tint,signs)
    # Follow the deck from its straight portion to the return lip.
    var returns: Array[Transform3D] = []
    for i in range(RETURN_ARROW_Z.size()):
        var progress := float(i)/float(RETURN_ARROW_Z.size()-1)
        returns.append(_deck_arrow(RETURN_ARROW_Z[i],side*0.60*smoothstep(0.0,1.0,progress)))
    returns.append(_road_arrow(EXIT_Z-0.72,side*4.35,side*0.51))
    if course_id == 1:
        # Point to the dry corridor before the shutter, clear of the ice.
        returns.append(_road_arrow(EXIT_Z-3.57,side*2.65,side*0.51))
        returns.append(_road_arrow(EXIT_Z-6.42,side*1.05,side*0.51))
        glacier_return_arrows.assign(returns)
    for arrow in returns:
        paint.append(arrow)
        colors.append(tint)

func _arrow_batch(batch_name: String, paint: Array[Transform3D], colors: Array[Color]) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Arrow head plus shaft, facing downhill in local -Z.
    surface.add_triangle_fan(PackedVector3Array([
        Vector3(0,0,-0.85),Vector3(-0.64,0,0.07),Vector3(0.64,0,0.07)]))
    surface.add_triangle_fan(PackedVector3Array([
        Vector3(-0.22,0,0.07),Vector3(-0.22,0,0.74),
        Vector3(0.22,0,0.74),Vector3(0.22,0,0.07)]))
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo = true
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = surface.commit()
    batch.instance_count = paint.size()+MAIN_MERGE_Z.size()
    for i in range(paint.size()):
        batch.set_instance_transform(i,paint[i])
        batch.set_instance_color(i,colors[i])
    for i in range(paint.size(),batch.instance_count):
        batch.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),Vector3.ZERO))
    route_arrows = batch
    var marks := MultiMeshInstance3D.new()
    marks.name = batch_name
    marks.multimesh = batch
    marks.material_override = material
    marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marks)

func _route_sign(label_name: String, message: String, at: Vector3, color: Color,
        plates: Array[Transform3D]) -> void:
    plates.append(Transform3D(Basis().scaled(Vector3(2.18,0.60,0.19)),at))
    plates.append(Transform3D(Basis().scaled(Vector3(0.17,1.43,0.24)),at-Vector3.UP*0.71))
    var title := Label3D.new()
    title.name = label_name
    title.text = message
    title.font_size = 44
    title.pixel_size = 0.010
    title.outline_size = 9
    title.modulate = color
    title.position = at+Vector3(0,0,0.104)
    add_child(title)

func _road_arrow(z: float, lateral: float, yaw: float) -> Transform3D:
    # Main-track collision planks are planar within each 12m module.
    var section_z: float = 8.0-roundf((8.0-z)/stage.SEGMENT_LENGTH)*stage.SEGMENT_LENGTH
    var pitch: float = -atan(stage.track_grade_at(section_z))
    var y: float = stage.height_at(section_z)-0.34+0.325/cos(pitch)-tan(pitch)*(z-section_z)
    var basis := Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,yaw)
    return Transform3D(basis,Vector3(stage.track_center_at(section_z)+lateral,y+0.040,z))

func _deck_arrow(z: float, steer_in: float) -> Transform3D:
    var index := clampi(int((ENTRY_Z-z)/(ENTRY_Z-EXIT_Z)*SEGMENTS),0,SEGMENTS-1)
    var deck := decks[index]
    var up := deck.basis.y
    var x := point_at(z).x-steer_in
    var y := deck.position.y+(0.28-up.x*(x-deck.position.x)-up.z*(z-deck.position.z))/up.y
    # Center samples sit on physical segment centers, clear of deck seams.
    return Transform3D(deck.basis*Basis(Vector3.UP,steer_in*0.94),
        Vector3(x,y+0.105,z))

func point_at(z: float) -> Vector3:
    if not is_instance_valid(stage):
        return Vector3.ZERO
    var offset := INNER_OFFSET
    if z > OUTER_START:
        var t: float = clampf((ENTRY_Z-z)/(ENTRY_Z-OUTER_START),0.0,1.0)
        offset = lerpf(INNER_OFFSET,OUTER_OFFSET,smoothstep(0.0,1.0,t))
    elif z >= OUTER_END:
        offset = OUTER_OFFSET
    else:
        var t: float = clampf((OUTER_END-z)/(OUTER_END-EXIT_Z),0.0,1.0)
        offset = lerpf(OUTER_OFFSET,INNER_OFFSET,smoothstep(0.0,1.0,t))
    var lift: float = bridge_lift_at(z)
    return Vector3(
        stage.track_center_at(z)+float(side)*offset,
        stage.height_at(z)-0.28+lift,z)

func recovery_center_at(location: Vector3, main_center := NAN) -> float:
    var main: float = stage.track_center_at(location.z) if is_nan(main_center) else main_center
    if location.z > ENTRY_Z+1.0 or location.z < EXIT_Z-1.0:
        return main
    var relative: float = float(side)*(location.x-main)
    # Never redirect marbles that chose to remain on the main course.
    if relative < 5.65:
        return main
    var alternate: float = point_at(location.z).x
    if absf(location.x-alternate) < WIDTH*0.5+1.3:
        return alternate
    return main

func on_separate_deck(location: Vector3) -> bool:
    # At either merge the roads are connected. Along the detached span,
    # nearby marbles on the two paths are distinct competitors.
    if location.z < OUTER_END or location.z > OUTER_START:
        return false
    var deck := point_at(location.z)
    return absf(location.x-deck.x) < WIDTH*0.5+0.65 and location.y >= deck.y-0.25

func merge_traffic_lane(at: Vector3) -> int:
    if not at.is_finite() or at.z > MERGE_TRAFFIC_NEAR or at.z < MERGE_TRAFFIC_FAR:
        return 0
    var lateral: float = side*(at.x-stage.track_center_at(at.z))
    if lateral >= 3.45 and at.z >= EXIT_Z-0.75:
        var deck := point_at(maxf(at.z,EXIT_Z))
        if absf(at.x-deck.x) <= WIDTH*0.5+0.30 and at.y-deck.y >= 0.22 and at.y-deck.y <= 1.55:
            return -1
    if lateral >= -3.6 and lateral <= 2.85 and absf(at.y-stage.height_at(at.z)-0.47) <= 0.85:
        return 1
    return 0

func merge_conflict_score(z: float, forward: float, rival_z: float, rival_forward: float) -> float:
    if not is_finite(z) or not is_finite(rival_z) or (
            not is_finite(forward) or forward < 3.0 or
            not is_finite(rival_forward) or rival_forward < 3.0 or
            z < EXIT_Z-1.0 or rival_z < EXIT_Z-1.0):
        return INF
    var own_eta := maxf(0.0,z-EXIT_Z)/forward
    var rival_eta := maxf(0.0,rival_z-EXIT_Z)/rival_forward
    if maxf(own_eta,rival_eta) > MERGE_CONFLICT_HORIZON or absf(own_eta-rival_eta) > MERGE_CONFLICT_GAP:
        return INF
    # Prioritise the pair's actual overlap at the join, not just the
    # earliest arrival. A rival that crosses much earlier is less urgent
    # than one reaching the same point at almost the same instant.
    return maxf(own_eta,rival_eta)+absf(own_eta-rival_eta)

func precision_gate_ahead(at: Vector3, velocity: Vector3) -> Dictionary:
    if course_id == 2:
        return _forge_precision_gate_ahead(at,velocity)
    if course_id != 0 or not at.is_finite() or not velocity.is_finite() or (
            -velocity.z < PRECISION_GATE_MIN_SPEED or at.z <= BRIDGE_POST_Z.back() or (
                at.z > BRIDGE_POST_Z[0]+13.5)):
        return {}
    var deck := point_at(at.z)
    var height := at.y-deck.y
    # Keep the second-gate landing cue available during a legitimate
    # launch arc; the old 1.85 m ceiling hid it at the jump apex.
    if height < 0.20 or height > 3.0 or absf(at.x-deck.x) > WIDTH*0.5+0.25 or (
            at.z > OUTER_START and side*(at.x-stage.track_center_at(at.z)) <= 6.68):
        return {}
    var speed := -velocity.z
    for i in range(BRIDGE_POST_Z.size()):
        var z: float = BRIDGE_POST_Z[i]
        var distance := at.z-z
        if distance <= 0.0:
            continue
        if distance > clampf(speed*0.9,5.5,13.5):
            break
        var eta := distance/speed
        var lateral := RaceFeedback.projected_lane_x(at.x,velocity.x,eta)-point_at(z).x
        var action := "HOLD CENTER"
        if absf(lateral) > PRECISION_GATE_HALF_WIDTH*0.80:
            action = "AIM LEFT" if lateral > 0.0 else "AIM RIGHT"
        # The physical takeoff is at JUMP_Z[course_id], before gate 2
        # on Woodworks (-71 m versus gate 2 at -80 m). Forecast the
        # gate while airborne, without promising lateral steering.
        if i == 1:
            var ramp_z: float = JUMP_Z[course_id]
            if at.z <= ramp_z and at.y > deck.y+Racer.RADIUS+0.35:
                # Crossing too high cannot earn the precision gate; avoid
                # falsely presenting an unreachable perfect landing.
                if height > PRECISION_GATE_MAX_HEIGHT:
                    action = "TOO HIGH"
                else:
                    action = "LAND CENTER" if absf(lateral) <= PRECISION_GATE_HALF_WIDTH*0.80 else "HOLD LINE"
            elif at.z > ramp_z and at.z-ramp_z <= 7.0 and action == "HOLD CENTER":
                action = "LINE UP JUMP"
        return {"number":i+1,"action":action,"distance":maxi(1,ceili(distance))}
    return {}

func _forge_precision_gate_ahead(at: Vector3, velocity: Vector3) -> Dictionary:
    var speed := -velocity.z
    if not at.is_finite() or not velocity.is_finite() or speed < PRECISION_GATE_MIN_SPEED or (
            at.z <= BRIDGE_POST_Z[FORGE_GATE_APPROACH.size()-1] or (
                at.z > ENTRY_PORTAL_Z+PORTAL_HALF_LENGTH)):
        return {}
    var deck := point_at(at.z)
    var height := at.y-deck.y
    if height < 0.24 or height > 1.35 or absf(at.x-deck.x) > WIDTH*0.5 or (
            side*(at.x-stage.track_center_at(at.z)) < FORGE_BRIDGE_EDGE_X):
        return {}
    var station := 0
    while at.z <= BRIDGE_POST_Z[station]:
        station += 1
    var gate_z: float = BRIDGE_POST_Z[station]
    # Look along the bend first. Extrapolating directly to the gate from
    # the portal would ask the player to steer through the outer rail.
    var distance := at.z-gate_z
    var look_time := minf(0.32,distance/speed)
    var look_z := maxf(gate_z,at.z-speed*look_time)
    var lateral := at.x+velocity.x*look_time-point_at(look_z).x
    var action := "FOLLOW CURVE" if at.z > OUTER_START else "HOLD CENTER"
    if absf(lateral) > PRECISION_GATE_HALF_WIDTH*0.72:
        action = "AIM LEFT" if lateral > 0.0 else "AIM RIGHT"
    var traffic := _forge_gate_traffic(at,velocity,at.x-deck.x,distance/speed)
    return {"number":station+1,"action":action if traffic.is_empty() else traffic,
        "distance":maxi(1,ceili(distance)),"traffic":not traffic.is_empty()}

func _forge_gate_traffic(at: Vector3, velocity: Vector3, offset: float, gate_eta: float) -> String:
    var speed := -velocity.z
    var horizon := minf(FORGE_GATE_TRAFFIC_SECONDS,gate_eta+FORGE_GATE_EXIT_PAD/speed)
    var end_z := at.z-speed*horizon
    var origins := PackedVector2Array()
    var motions := PackedVector2Array()
    var online: bool = stage.net.is_client()
    var unknown := false
    for rival in stage.racers:
        if not is_instance_valid(rival) or rival == stage.player or rival.finished or rival.eliminated:
            continue
        var pos: Vector3 = rival.global_position
        if not pos.is_finite() or pos.z < end_z-FORK_TRAFFIC_CLEARANCE or pos.z > at.z+9.0:
            continue
        var deck := point_at(pos.z)
        var across := pos.x-deck.x
        if absf(across) > WIDTH*0.5+0.15 or pos.y < deck.y+0.24 or pos.y > deck.y+1.35 or (
                pos.z > OUTER_START and side*(pos.x-stage.track_center_at(pos.z)) < FORGE_BRIDGE_EDGE_X):
            continue
        var motion: Vector3 = stage.net.replica_velocity(rival) if online else (
            Vector3.ZERO if rival.freeze else rival.linear_velocity)
        if not motion.is_finite():
            unknown = true
            continue
        origins.append(Vector2(across,pos.z))
        motions.append(Vector2(_bridge_lateral_speed(pos.z,motion),motion.z))
    if origins.is_empty():
        return "CHECK TRAFFIC" if unknown else ""

    # Compare in deck coordinates. A rival following the bend should not
    # appear to cut across the lane just because the bridge turns to the right.
    var settle := minf(gate_eta,FORGE_GATE_SETTLE_SECONDS)
    var reaction := minf(FORK_REACTION,settle*0.45)
    var drift := clampf(offset+_bridge_lateral_speed(at.z,velocity)*reaction,-WIDTH*0.5,WIDTH*0.5)
    var previous := Vector2(offset,at.z)
    var first := 0.0
    for segment in [Vector2(drift,reaction),Vector2(0.0,settle),Vector2(0.0,horizon)]:
        var next := Vector2(segment.x,at.z-speed*segment.y)
        if not RaceFeedback.traffic_span_clear(previous,next,first,segment.y,origins,motions,
                FORK_TRAFFIC_CLEARANCE):
            return "TRAFFIC  •  SAVE BOOST"
        previous = next
        first = segment.y
    return "CHECK TRAFFIC" if unknown else ""

func _bridge_lateral_speed(z: float, velocity: Vector3) -> float:
    var slope := point_at(z+0.5).x-point_at(z-0.5).x
    return velocity.x-slope*velocity.z

func shortcut_hint(location: Vector3, continuing_merge := false) -> Dictionary:
    # Retain bridge context on the overlapping deck only for a racer
    # already seen on the exterior approach.
    var z: float = location.z
    var fork_end := ENTRY_PORTAL_Z-PORTAL_HALF_LENGTH
    if z <= ENTRY_Z and z >= EXIT_Z:
        var relative_x: float = float(side)*(location.x-stage.track_center_at(z))
        var following_bridge_exit: bool = continuing_merge and (
            z <= OUTER_END and relative_x >= 3.35)
        var bridge_threshold := BRIDGE_ENTRY_X if z > OUTER_START else 5.65
        if course_id == 2 and continuing_merge and z <= ENTRY_PORTAL_Z and z > OUTER_START:
            # Keep the just-confirmed bridge cue across the edge of the shared deck.
            bridge_threshold = FORGE_BRIDGE_EDGE_X
        if relative_x > bridge_threshold or following_bridge_exit:
            var deck := point_at(z)
            if absf(location.x-deck.x) < WIDTH*0.5+1.7 and location.y >= deck.y-0.25:
                return {"mode":"merge","side":"RIGHT" if side < 0 else "LEFT",
                    "distance":maxi(0,int(round(z-EXIT_Z)))}
    if z <= ENTRY_PORTAL_Z+FORK_GUIDANCE_REACH and z > fork_end:
        return {"mode":"fork","side":"LEFT" if side < 0 else "RIGHT",
            "distance":maxi(0,int(round(z-ENTRY_PORTAL_Z)))}
    return {}

func forge_fork_advice(at: Vector3, velocity: Vector3) -> Dictionary:
    var speed := -velocity.z
    if course_id != 2 or not at.is_finite() or not velocity.is_finite() or (
            speed < 5.0 or stage.airtime.airborne or (
                absf(at.y-stage.height_at(at.z)-Racer.RADIUS) > 0.65)):
        return {}
    var eta := (at.z-ENTRY_PORTAL_Z)/speed
    if eta < 0.24 or eta > 1.05 or at.z > ENTRY_PORTAL_Z+14.0:
        return {}
    var origins := PackedVector2Array()
    var motions := PackedVector2Array()
    var online: bool = stage.net.is_client()
    for rival in stage.racers:
        if not is_instance_valid(rival) or rival == stage.player or rival.finished or rival.eliminated:
            continue
        var pos: Vector3 = rival.global_position
        if pos.z < FORK_CHECK_END-1.0 or pos.z > at.z+8.0 or (
                absf(pos.x-stage.track_center_at(pos.z)) > 12.0 or
                absf(pos.y-stage.height_at(pos.z)-Racer.RADIUS) > 0.95):
            continue
        var motion: Vector3 = stage.net.replica_velocity(rival) if online else (
            Vector3.ZERO if rival.freeze else rival.linear_velocity)
        if not motion.is_finite():
            return {}
        origins.append(Vector2(pos.x,pos.z))
        motions.append(Vector2(motion.x,motion.z))
    if origins.is_empty():
        return {}

    # Compare traffic over the length of the opening. The bridge reference
    # follows the narrow deck. The main reference follows the player's line.
    var first_z := minf(at.z,ENTRY_PORTAL_Z+2.8)
    var first_time := (at.z-first_z)/speed
    var end_time := (at.z-FORK_CHECK_END)/speed
    var main_x: float = stage.track_center_at(ENTRY_PORTAL_Z)
    var drift := RaceFeedback.projected_lane_x(at.x,velocity.x,eta)
    var main_aligned := absf(drift-main_x) <= 4.8
    var duration := eta-FORK_REACTION
    var edge := float(side)*(point_at(ENTRY_PORTAL_Z).x-main_x)-WIDTH*0.25
    var accel := Racer.human_steering_force(1.0,velocity.z,velocity.x,course_id)*0.72
    var outside_reach := float(side)*(at.x+velocity.x*eta-main_x)+0.5*accel*duration*duration
    var bridge_in_reach := outside_reach >= edge
    var main_busy := _forge_fork_traffic(at,velocity,first_time,end_time,false,origins,motions)
    var bridge_busy := _forge_fork_traffic(at,velocity,first_time,end_time,true,origins,motions)
    if not main_busy and not bridge_busy:
        return {}
    var traffic := "BOTH BUSY" if main_busy and bridge_busy else (
        "MAIN BUSY" if main_busy else "BRIDGE BUSY")
    var text := traffic+"  •  SAVE BOOST"
    var tint := FORK_BRIDGE_COLOR
    if bridge_busy and not main_busy and main_aligned:
        text = "↑ MAIN TRACK  /  "+traffic
        tint = FORK_MAIN_COLOR
    elif main_busy and not bridge_busy and bridge_in_reach:
        text = traffic+"  /  BRIDGE RIGHT ↗"
    return {"text":text,"traffic":traffic,"tint":tint}

func _forge_fork_traffic(at: Vector3, velocity: Vector3, first: float, last: float,
        bridge: bool, origins: PackedVector2Array, motions: PackedVector2Array) -> bool:
    var previous := Vector2.ZERO
    var previous_time := first
    # Split the bridge curve and the capped lateral drift into short spans
    # so cutting across the entrance between samples still counts.
    var clearance := FORK_TRAFFIC_CLEARANCE+(0.48 if bridge else 0.0)
    for step in range(7):
        var t := lerpf(first,last,float(step)/6.0)
        var z := at.z+velocity.z*t
        var center: float = stage.track_center_at(z)
        var x := clampf(RaceFeedback.projected_lane_x(at.x,velocity.x,t),center-4.8,center+4.8)
        if bridge:
            x = point_at(z).x
        var next := Vector2(x,z)
        if step > 0 and not RaceFeedback.traffic_span_clear(previous,next,previous_time,t,
                origins,motions,clearance):
            return true
        previous = next
        previous_time = t
    return false

func route_guidance_text(hint: Dictionary, z: float, forward_speed: float) -> String:
    var distance := int(hint["distance"])
    var at_fork: bool = hint["mode"] == "fork"
    var portal_z := ENTRY_PORTAL_Z if at_fork else EXIT_Z
    var timing := "  /  %.1fs" % (maxf(0.0,z-portal_z)/forward_speed) if forward_speed >= 9.0 else ""
    if at_fork:
        var direction: String = hint["side"]
        var immediate := z <= ENTRY_PORTAL_Z+PORTAL_HALF_LENGTH
        var turn := " NOW" if immediate else ""
        var choices := "↖ BRIDGE LEFT%s  /  MAIN TRACK ↑" % turn if direction == "LEFT" else (
            "↑ MAIN TRACK  /  BRIDGE RIGHT%s ↗" % turn)
        if immediate:
            return choices
        return "%s  •  %dm%s" % [choices,distance,timing]
    if distance > MERGE_GUIDANCE_REACH:
        return ""
    var direction: String = hint["side"]
    if z <= EXIT_Z+PORTAL_HALF_LENGTH:
        return "MERGE RIGHT NOW  ↗" if direction == "RIGHT" else "↖  MERGE LEFT NOW"
    return "MERGE %s  •  %dm%s" % [direction,distance,timing]

func reset_round() -> void:
    triggered.clear()
    entered.clear()
    jumped.clear()
    precision_progress.clear()
    precision_last_z.clear()
    precision_failed.clear()
    precision_complete.clear()

func bridge_gate_count(racer_id: int) -> int:
    return clampi(int(precision_progress.get(racer_id,0)),
        0,BRIDGE_POST_Z.size())

static func valid_precision_line(horizontal: float, vertical: float,
        forward_speed: float, step: float) -> bool:
    return is_finite(horizontal) and is_finite(vertical) and (
        is_finite(forward_speed) and is_finite(step) and
        absf(horizontal) <= PRECISION_GATE_HALF_WIDTH and
        vertical >= PRECISION_GATE_MIN_HEIGHT and
        vertical <= PRECISION_GATE_MAX_HEIGHT and
        forward_speed >= PRECISION_GATE_MIN_SPEED and
        step > 0.0 and step <= PRECISION_GATE_MAX_STEP)

func _precision_tick(marble: RigidBody3D, at: Vector3,
        delta: float, net: Node) -> void:
    # One O(1) state update for a *real entrant* only, no extra raycasts
    # or 30-marble per-frame gate search. The authority alone can pay out.
    var id: int = marble.racer_id
    var previous_z: float = float(precision_last_z.get(id,at.z))
    precision_last_z[id] = at.z
    if not entered.has(id) or precision_failed.has(id) or (
            precision_complete.has(id)):
        return
    var next_gate: int = bridge_gate_count(id)
    if next_gate >= BRIDGE_POST_Z.size():
        return
    var target_z: float = float(BRIDGE_POST_Z[next_gate])
    if at.z > target_z or previous_z <= target_z:
        return
    var forward_speed: float = -marble.linear_velocity.z
    var step: float = previous_z-at.z
    # Reject teleport/recovery jumps even if the final coordinates happen
    # to land perfectly on a marker. Ordinary 60Hz physical steps are short.
    var bounded: bool = step <= maxf(0.65,forward_speed*maxf(
        0.016,delta)*2.2)
    var line: Vector3 = point_at(target_z)
    if not bounded or not valid_precision_line(
            at.x-line.x,at.y-line.y,forward_speed,step):
        precision_failed[id] = true
        return
    var score: int = next_gate+1
    precision_progress[id] = score
    if score == BRIDGE_POST_Z.size():
        precision_complete[id] = true
        # Small earned force only, identical for AI, local human and
        # network-controlled player. No score/velocity originates on clients.
        marble.apply_central_impulse(Vector3(
            0.0,PRECISION_BONUS_LIFT,-PRECISION_BONUS_FORWARD)*marble.mass)
        _feedback(marble,net,"bridge_perfect")
    else:
        _feedback(marble,net,"bridge_gate_%d" % score)

func tick(delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    # Never apply gameplay effects from a rendering-only client replica.
    effect_candidates_last_tick = 0
    if net.role == "client":
        return
    var jump_z: float = JUMP_Z[course_id]
    for marble in racers:
        if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
            continue
        var at: Vector3 = marble.global_position
        var z := at.z
        # Outside this interval, no marble can earn a bridge interaction.
        if not inside_effect_window(z):
            continue
        effect_candidates_last_tick += 1
        var id: int = marble.racer_id
        if not entered.has(id):
            if z > ENTRY_Z+1.5 or z < ENTRY_Z-ENTRY_WINDOW:
                continue
            # Check the outside of the actual railing before sampling the deck.
            if not (float(side)*(at.x-stage.track_center_at(z)) > 6.68):
                continue
            var entry_point := point_at(z)
            if not (absf(at.x-entry_point.x) < WIDTH*0.5+1.1 and
                    absf(at.y-entry_point.y) < 2.3):
                continue
            entered[id] = true
        _precision_tick(marble,at,delta,net)
        var launch_due := not jumped.has(id) and absf(z-jump_z) <= 1.5
        var reward_due := not triggered.has(id) and absf(z-REWARD_Z) < 2.25
        if not launch_due and not reward_due:
            continue
        var point := point_at(z)
        var horizontal_error := absf(at.x-point.x)
        var vertical_error := absf(at.y-point.y)
        if launch_due and horizontal_error < 1.38 and vertical_error < 1.65:
            jumped[id] = true
            marble.apply_central_impulse(Vector3(0.0,2.15,-1.65)*marble.mass)
            _feedback(marble,net,"jump")
        if reward_due and not (horizontal_error > REWARD_RADIUS or vertical_error > 1.55):
            triggered[id] = true
            # Reward a verified fork entry and the actual line down the deck.
            marble.apply_central_impulse(Vector3(0.0,0.32,-4.25)*marble.mass)
            _feedback(marble,net,"shortcut")

func _feedback(marble: RigidBody3D, net: Node, kind: String) -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,kind)
    elif net.role == "offline" and marble.is_player:
        stage.audio.course_event(kind)
        stage.ui.show_course_event(kind)
