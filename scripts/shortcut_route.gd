extends Node3D
## v1.16: real, collidable alternate race road with two side-rail portals.
## Each course has a different exterior branch. Physics and rewards are
## evaluated by the offline game or authoritative dedicated server only.
const ENTRY_SECTION := 5
const EXIT_SECTION := 9
const ENTRY_Z := -48.0
const EXIT_Z := -104.0
const OUTER_START := -60.0
const OUTER_END := -92.0
const INNER_OFFSET := 4.90
const OUTER_OFFSET := 10.45
const WIDTH := 3.80
const SEGMENTS := 28
const REWARD_Z := -79.0
const REWARD_RADIUS := 2.15
const JUMP_Z := [-71.0,-74.0,-86.0]
const ENTRY_WINDOW := 12.0
const MAX_BANK := 0.080
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
var launch_ramps: Array[StaticBody3D] = []
var banked_segments := 0
var physical_distance := 0.0

static func side_for(track: int) -> int:
    return SIDES[clampi(track,0,2)]

static func opens_rail(section: int, rail_side: int, piece: int, track: int) -> bool:
    return (section == ENTRY_SECTION or section == EXIT_SECTION) and (
        rail_side == side_for(track) and piece == 1)

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
    _launch_ramps(deck_material)
    _racing_line(edge_material)
    _signage(edge_material)
    reset_round()

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
    var basis := Basis(Vector3.RIGHT,-atan(0.085)+0.18)
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

func _signage(color: Material) -> void:
    var entry := Label3D.new()
    entry.name = "ShortcutEntranceArrow"
    entry.text = "LEFT  /  SHORTCUT" if side < 0 else "RIGHT  /  SHORTCUT"
    entry.font_size = 48
    entry.pixel_size = 0.013
    entry.outline_size = 8
    entry.modulate = TINTS[course_id]
    entry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    entry.position = Vector3(
        stage.track_center_at(ENTRY_Z+4.5)+float(side)*4.7,
        stage.height_at(ENTRY_Z+4.5)+3.1,ENTRY_Z+4.5)
    add_child(entry)
    # Two readable overhead banners, visible before steering into a fork.
    var banner_marks: Array[Transform3D] = []
    for at_z in [ENTRY_Z+7.0,EXIT_Z+5.0]:
        var x: float = stage.track_center_at(at_z)+float(side)*4.1
        var y: float = stage.height_at(at_z)+3.55
        banner_marks.append(Transform3D(Basis().scaled(Vector3(4.8,0.18,0.26)),
            Vector3(x,y,at_z)))
    _batch("ShortcutGatewayBeams",banner_marks,color)
    var return_label := Label3D.new()
    return_label.name = "ShortcutMergeArrow"
    return_label.text = "MERGE  RIGHT" if side < 0 else "MERGE  LEFT"
    return_label.font_size = 39
    return_label.pixel_size = 0.013
    return_label.modulate = TINTS[course_id]
    return_label.outline_size = 8
    return_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    return_label.position = point_at(EXIT_Z+6.0)+Vector3.UP*3.4
    add_child(return_label)
    # Glowing stripes lead into the genuine physical fork.
    var boxes: Array[Transform3D] = []
    for i in range(4):
        var z: float = ENTRY_Z+5.4-float(i)*2.1
        var x: float = stage.track_center_at(z)+float(side)*(4.4+float(i)*0.62)
        var shape := Basis().scaled(Vector3(0.78,0.06,0.24))
        boxes.append(Transform3D(shape,Vector3(x,stage.height_at(z)+0.09,z)))
    _batch("EntranceGuideStripes",boxes,color)

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
    var progress: float = clampf((ENTRY_Z-z)/(ENTRY_Z-EXIT_Z),0.0,1.0)
    var lift := 0.36*pow(sin(progress*PI),2.0)
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

func shortcut_hint(location: Vector3) -> Dictionary:
    # HUD query; never changes gameplay state and requires no network traffic.
    var z: float = location.z
    if z <= ENTRY_Z+36.0 and z > ENTRY_Z:
        return {"mode":"fork","side":"LEFT" if side < 0 else "RIGHT",
            "distance":maxi(0,int(round(z-ENTRY_Z)))}
    if z <= ENTRY_Z and z >= EXIT_Z:
        var relative_x: float = float(side)*(location.x-stage.track_center_at(z))
        if relative_x > 5.65 and absf(location.x-point_at(z).x) < WIDTH*0.5+1.7:
            return {"mode":"merge","side":"RIGHT" if side < 0 else "LEFT",
                "distance":maxi(0,int(round(z-EXIT_Z)))}
    return {}

func reset_round() -> void:
    triggered.clear()
    entered.clear()
    jumped.clear()

func tick(_delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    # Never apply gameplay effects from a rendering-only client replica.
    if net.role == "client":
        return
    for marble in racers:
        if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
            continue
        var z: float = marble.global_position.z
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
