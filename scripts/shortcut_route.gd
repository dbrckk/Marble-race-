extends Node3D
## v1.16: real, collidable alternate race road with two side-rail portals.
## Each course has a different exterior branch. Physics and rewards are
## evaluated by the offline game or authoritative dedicated server only.
const ENTRY_SECTION := 5
const EXIT_SECTION := 9
const ENTRY_Z := -48.0
const ENTRY_PORTAL_Z := -52.0
const EXIT_Z := -104.0
const PORTAL_HALF_LENGTH := 2.0
const FORK_GUIDANCE_REACH := 32.0
const MERGE_GUIDANCE_REACH := 23.0
const GLACIER_RETURN_COLOR := Color("#ffda8c")
const FORGE_EDGE_COLOR := Color("#ffc86e")
const FORGE_MAIN_COLOR := Color("#b6f6ed")
const FORK_MAIN_COLOR := FORGE_MAIN_COLOR
const FORK_BRIDGE_COLOR := FORGE_EDGE_COLOR
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
const BRIDGE_POST_OFFSET := 1.76
const BRIDGE_POST_RADIUS := 0.22
const BRIDGE_POST_HEIGHT := 0.88
const BRIDGE_ARCH_HEIGHT := 3.15
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
        decks.append(deck)
        deck_art.append(Transform3D(basis.scaled(deck_size),middle))
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
            guard_art.append(Transform3D(basis.scaled(size),guard_pos))
    _batch("BatchedBypassDeck",deck_art,deck_material)
    _batch("BatchedBypassGuards",guard_art,edge_material)
    _bridge_structure(deck_material,edge_material)
    _launch_ramps(deck_material)
    _bridge_precision_corridor(edge_material)
    _racing_line(edge_material)
    var signs: Array[Transform3D] = []
    var paint: Array[Transform3D] = []
    var colors: Array[Color] = []
    _fork_signage(signs,paint,colors)
    if course_id == 2:
        _forge_return_markings(signs,paint,colors)
    elif course_id == 1:
        _glacier_return_markings()
    else:
        _woodworks_return_marking()
    var panel := StandardMaterial3D.new()
    panel.albedo_color = [Color("#493224"),Color("#21374f"),Color("#422b29")][course_id]
    panel.roughness = 0.52
    panel.metallic = 0.28
    _batch("RouteSignPlates",signs,panel)
    _arrow_batch("RouteDirectionArrows",paint,colors)
    reset_round()

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

func _bridge_structure(deck_color: Material, edge_color: Material) -> void:
    # Elevated paths need visible load-bearing structure. Ten pylons and
    # five transverse braces use two GPU batches; no additional physics
    # bodies, scripts, lights or dynamic shadows are created on Android.
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
                Basis().scaled(Vector3(0.38,height,0.40)),
                Vector3(support_x,center_y,z)))
        braces.append(Transform3D(
            Basis().scaled(Vector3(WIDTH+1.10,0.18,0.38)),
            point+Vector3(0.0,-0.57,0.0)))
    _batch("BatchedBypassBridgePylons",supports,deck_color)
    _batch("BatchedBypassBridgeTrusses",braces,edge_color)

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
    launch_ramps.append(ramp)
    _batch("BatchedJumpTakeoff",[Transform3D(basis.scaled(size),ramp.position)],material)
    var lip_mesh := BoxMesh.new()
    lip_mesh.size = Vector3(2.34,0.055,0.14)
    var strip := MeshInstance3D.new()
    strip.name = "TakeoffPaintedLip"
    strip.mesh = lip_mesh
    strip.material_override = material
    strip.position = at+Vector3.UP*0.60+Vector3(0.0,0.0,-1.08)
    strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(strip)

func _bridge_precision_corridor(material: Material) -> void:
    # A single shared GPU batch depicts all six physical edge posts.
    # Three portal arches use the same batch, with no per-frame updates,
    # extra lights or shadows. They make the elevated road readable from
    # the chase camera while preserving a safe central racing lane.
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
            # Arch columns are noncolliding silhouettes, outside the
            # physical narrow deck and high above any realistic marble jump.
            arch_art.append(Transform3D(Basis().scaled(
                Vector3(0.18,BRIDGE_ARCH_HEIGHT,0.22)),
                center+Vector3(flank*(WIDTH*0.5+0.62),
                    BRIDGE_ARCH_HEIGHT*0.5+0.32,0.0)))
        var glacier_exit := course_id == 1 and station == BRIDGE_POST_Z.size()-1
        if course_id == 2 or glacier_exit:
            for flank in [-1.0,1.0]:
                var cap := Basis(Vector3.FORWARD,-flank*0.20)
                arch_art.append(Transform3D(cap.scaled_local(Vector3(1.36,0.19,0.24)),
                    center+Vector3(flank*(WIDTH*0.5+0.18),BRIDGE_ARCH_HEIGHT+0.42,0)))
        else:
            arch_art.append(Transform3D(Basis().scaled(Vector3(
                WIDTH+1.55,0.19,0.24)),
                center+Vector3(0.0,BRIDGE_ARCH_HEIGHT+0.32,0.0)))
    _batch("BypassPrecisionEdgePosts",post_art,material)
    _batch("BypassPrecisionPortalArches",arch_art,material)
    # Three lightweight, noncolliding deck stripes identify the EXACT
    # physical crossing planes. The existing trim material is reused.
    var marks: Array[Transform3D] = []
    for station in range(BRIDGE_POST_Z.size()):
        var center: Vector3 = point_at(BRIDGE_POST_Z[station])
        marks.append(Transform3D(
            Basis().scaled(Vector3(2.07,0.013,0.23)),
            center+Vector3.UP*0.324))
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
    material: Material) -> void:
    if instances.is_empty():
        return
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = mesh
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

    # The first arrows split visibly on the main deck. The last two sit
    # on the actual banked bridge surface, after the side rail opens.
    for z in [-36.0,-41.8,-47.3,-51.0]:
        paint.append(_road_arrow(z,-float(side)*1.55,0.0))
        colors.append(FORK_MAIN_COLOR)
    for i in range(4):
        var z := ENTRY_PORTAL_Z+14.5-float(i)*3.1
        paint.append(_road_arrow(z,float(side)*(1.7+float(i)*0.92),-float(side)*0.34))
        colors.append(FORK_BRIDGE_COLOR)
    for z in [-51.0,-56.7]:
        paint.append(_deck_arrow(z,0.0))
        colors.append(FORK_BRIDGE_COLOR)

func _woodworks_return_marking() -> void:
    var return_label := Label3D.new()
    return_label.name = "ShortcutMergeArrow"
    return_label.text = "MERGE  LEFT"
    return_label.font_size = 39
    return_label.pixel_size = 0.013
    return_label.modulate = TINTS[course_id]
    return_label.outline_size = 8
    return_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    return_label.position = point_at(EXIT_Z+6.0)+Vector3.UP*3.4
    add_child(return_label)

func _forge_return_markings(signs: Array[Transform3D], paint: Array[Transform3D],
        colors: Array[Color]) -> void:
    var exit_z := EXIT_Z+2.4
    var bridge_end := point_at(exit_z)
    _route_sign("ShortcutMergeArrow","↖  MERGE",bridge_end+Vector3(1.72,1.48,0),
        FORGE_MAIN_COLOR,signs)
    # Merge arrows share the entrance batches and follow the banked deck plane.
    var merge_rows := [-89.0,-93.0,-97.0,-99.0,-103.0]
    for i in range(merge_rows.size()):
        var return_bias := smoothstep(0.0,float(merge_rows.size()-1),float(i))*0.60
        paint.append(_deck_arrow(merge_rows[i],return_bias))
        colors.append(FORGE_MAIN_COLOR)
    paint.append(_road_arrow(EXIT_Z-0.65,4.35,0.52))
    colors.append(FORGE_MAIN_COLOR)


func _glacier_return_markings() -> void:
    var signs: Array[Transform3D] = []
    var sign_z := EXIT_Z+3.1
    _route_sign("ShortcutMergeArrow","MERGE  ↗",
        point_at(sign_z)+Vector3(-1.47,1.44,0.0),GLACIER_RETURN_COLOR,signs)
    var panel := StandardMaterial3D.new()
    panel.albedo_color = Color("#192f4a")
    panel.roughness = 0.46
    _batch("GlacierReturnSign",signs,panel)

    var colors: Array[Color] = []
    var approach := [-89.0,-93.0,-97.0,-99.0,-103.0]
    for i in range(approach.size()):
        var progress := float(i)/float(approach.size()-1)
        glacier_return_arrows.append(_deck_arrow(approach[i],-0.60*smoothstep(0.0,1.0,progress)))
        colors.append(GLACIER_RETURN_COLOR)
    # Lead from the lip to the wider center corridor. The ice slab beside
    # the bridge ends before the ramp rejoins the main road.
    for i in range(3):
        var z := EXIT_Z-0.72-float(i)*2.85
        glacier_return_arrows.append(_road_arrow(z,[-4.35,-2.65,-1.05][i],-0.51))
        colors.append(GLACIER_RETURN_COLOR)
    _arrow_batch("GlacierReturnArrows",glacier_return_arrows,colors)

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
    batch.instance_count = paint.size()
    for i in range(paint.size()):
        batch.set_instance_transform(i,paint[i])
        batch.set_instance_color(i,colors[i])
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

func recovery_center_at(location: Vector3) -> float:
    var main: float = stage.track_center_at(location.z)
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

func shortcut_hint(location: Vector3, continuing_merge := false) -> Dictionary:
    # Retain bridge context on the overlapping deck only for a racer
    # already seen on the exterior approach.
    var z: float = location.z
    var fork_end := ENTRY_PORTAL_Z-PORTAL_HALF_LENGTH
    if z <= ENTRY_Z and z >= EXIT_Z:
        var relative_x: float = float(side)*(location.x-stage.track_center_at(z))
        var following_bridge_exit: bool = course_id != 0 and continuing_merge and (
            z <= OUTER_END and relative_x >= 3.35)
        var bridge_threshold := 6.68 if z > OUTER_START else 5.65
        if relative_x > bridge_threshold or following_bridge_exit:
            var deck := point_at(z)
            if absf(location.x-deck.x) < WIDTH*0.5+1.7 and location.y >= deck.y-0.25:
                return {"mode":"merge","side":"RIGHT" if side < 0 else "LEFT",
                    "distance":maxi(0,int(round(z-EXIT_Z)))}
    if z <= ENTRY_PORTAL_Z+FORK_GUIDANCE_REACH and z > fork_end:
        return {"mode":"fork","side":"LEFT" if side < 0 else "RIGHT",
            "distance":maxi(0,int(round(z-ENTRY_PORTAL_Z)))}
    return {}

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

func _precision_tick(marble: RigidBody3D, delta: float,
        net: Node) -> void:
    # One O(1) state update for a *real entrant* only, no extra raycasts
    # or 40-marble per-frame gate search. The authority alone can pay out.
    var id: int = marble.racer_id
    var at: Vector3 = marble.global_position
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

func tick(_delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    # Never apply gameplay effects from a rendering-only client replica.
    effect_candidates_last_tick = 0
    if net.role == "client":
        return
    for marble in racers:
        if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
            continue
        var z: float = marble.global_position.z
        # Broad phase is conservative: every physics interaction remains in
        # the covered interval on each of the three tracks. Outside it, no
        # marble can earn an entry, ramp impulse or shortcut reward.
        if not inside_effect_window(z):
            continue
        effect_candidates_last_tick += 1
        var point := point_at(z)
        var horizontal_error: float = absf(marble.global_position.x-point.x)
        var vertical_error: float = absf(marble.global_position.y-point.y)
        # Check the *outside* of the physical railing, not merely the
        # adjacent main-road shoulder. This is also a truthful race metric.
        var outside_portal: bool = float(side)*(
            marble.global_position.x-stage.track_center_at(z)) > 6.68
        if z <= ENTRY_Z+1.5 and z >= ENTRY_Z-ENTRY_WINDOW and outside_portal and (
            horizontal_error < WIDTH*0.5+1.1 and vertical_error < 2.3):
            entered[marble.racer_id] = true
        if not entered.has(marble.racer_id):
            continue
        _precision_tick(marble,_delta,net)
        var jump_z: float = JUMP_Z[course_id]
        if not jumped.has(marble.racer_id) and absf(z-jump_z) <= 1.5 and (
            horizontal_error < 1.38 and vertical_error < 1.65):
            jumped[marble.racer_id] = true
            marble.apply_central_impulse(Vector3(0.0,2.15,-1.65)*marble.mass)
            _feedback(marble,net,"jump")
        if triggered.has(marble.racer_id) or absf(z-REWARD_Z) >= 2.25:
            continue
        if horizontal_error > REWARD_RADIUS or vertical_error > 1.55:
            continue
        triggered[marble.racer_id] = true
        # The side route is longer, with risk at its launch pad. Reward earned
        # by actually entering the fork, not by spawning on the midpoint.
        marble.apply_central_impulse(Vector3(0.0,0.32,-4.25)*marble.mass)
        _feedback(marble,net,"shortcut")

func _feedback(marble: RigidBody3D, net: Node, kind: String) -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,kind)
    elif net.role == "offline" and marble.is_player:
        stage.audio.course_event(kind)
        stage.ui.show_course_event(kind)
