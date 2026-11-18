extends Node3D
## One batch of painted takeoff and landing marks on the racing surfaces.
const ShortcutRoute = preload("res://scripts/shortcut_route.gd")
const Feedback = preload("res://scripts/race_feedback.gd")
const TrackSurface = preload("res://scripts/track_surface.gd")
const Sculptures = preload("res://scripts/course_sculptures.gd")
const LANDING_OFFSETS := [2.8,4.4,6.0,1.6]
const SHUTTER_MARK_OFFSETS := [1.35,2.95,4.55,6.15,7.75,9.35]
const SHUTTER_INK := Color("#ffdf99")
const SHUTTER_MARK_MIN_DISTANCE := 3.2
const BANK_MARK_MIN_DISTANCE := 3.2
const TAKEOFF_INK := [Color("#ffd084"),Color("#ffe098"),Color("#ffd187")]
const LANDING_INK := [Color("#c5ffba"),Color("#a9faff"),Color("#aaf5e4")]
const BACKING := Color("#25282b")

var game: Node3D
var ramps: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var shutter_marks: Array[Vector3] = []
var final_bank_marks: Array[Vector3] = []
var paint: MultiMeshInstance3D
var physics_frames := 0
var baked := false

func add_ramp(body: StaticBody3D, size: Vector3, bridge := false) -> void:
    ramps.append({"body":body,"size":size,"bridge":bridge})

func _physics_process(_delta: float) -> void:
    # Let all floor colliders reach the physics space before reading them.
    physics_frames += 1
    if physics_frames < 2:
        return
    set_physics_process(false)
    if game.net.role != "server":
        _bake()

func _bake() -> void:
    var ignored: Array[RID] = []
    for marble in game.racers:
        if is_instance_valid(marble):
            ignored.append(marble.get_rid())
    var marks: Array[Transform3D] = []
    var inks: Array[Color] = []
    for ramp in ramps:
        var body: StaticBody3D = ramp["body"]
        var size: Vector3 = ramp["size"]
        var bridge: bool = ramp["bridge"]
        var lip: Vector3 = body.to_global(Vector3(0.0,size.y*0.5,-size.z*0.5))
        var top: Basis = body.global_basis
        var warm: Color = TAKEOFF_INK[game.selected_track]
        var cool: Color = LANDING_INK[game.selected_track]
        # Broken threshold and two forward chevrons glazed onto the ramp.
        for side in [-1.0,1.0]:
            var threshold := lip+top*Vector3(side*size.x*0.27,0.027,0.16)
            _stroke(marks,inks,threshold,top,Vector2(size.x*0.39,0.19),warm)
            for row in [0.65,1.22]:
                var chevron := lip+top*Vector3(side*0.18,0.027,row)
                var diagonal := top*Basis(Vector3.UP,side*0.64)
                _stroke(marks,inks,chevron,diagonal,Vector2(0.14,0.42),warm)

        var half_width := minf(1.10,size.x*0.40)
        var lane_offset: float = lip.x-game.shortcut_route.point_at(lip.z).x if bridge else 0.0
        for offset in LANDING_OFFSETS:
            var z: float = lip.z-offset
            var deck: Vector3 = game.shortcut_route.point_at(z) if bridge else Vector3(lip.x,game.height_at(z),z)
            var center := Vector3(deck.x+lane_offset,deck.y+(0.28 if bridge else 0.0),z)
            var middle := _floor(center,bridge,ignored)
            if middle.is_empty():
                continue
            var left := _floor(center-Vector3.RIGHT*half_width,bridge,ignored)
            var right := _floor(center+Vector3.RIGHT*half_width,bridge,ignored)
            if left.is_empty() or right.is_empty():
                continue
            windows.append({"lip":lip,"landing":middle["position"],"half_width":size.x*0.5,"bridge":bridge})
            for contact in [left,right]:
                var normal: Vector3 = contact["normal"]
                var ground: Vector3 = contact["position"]+normal*0.028
                var plane := Basis(Quaternion(Vector3.UP,normal))
                var inward := 1.0 if contact == left else -1.0
                _stroke(marks,inks,ground,plane,Vector2(0.16,0.72),cool)
                _stroke(marks,inks,ground+plane*Vector3(inward*0.19,0.0,-0.26),
                    plane,Vector2(0.45,0.15),cool)
            break
    if game.selected_track == 1:
        _paint_shutter_center(marks,inks,ignored)
    if game.selected_track <= 1:
        _paint_final_bank(marks,inks,ignored)
    _make_batch(marks,inks)
    baked = true

func _paint_final_bank(marks: Array[Transform3D], inks: Array[Color], ignored: Array[RID]) -> void:
    # These four stripes lie on the actual two tilted halves of the bank.
    # The brighter edge faces the main track where the lanes come together.
    var banks: Array[StaticBody3D] = game.course_sculptures.banks
    for body: StaticBody3D in banks.slice(-2):
        var shape := body.get_node("SculptedApexCollision") as CollisionShape3D
        var extent: Vector3 = (shape.shape as BoxShape3D).size*0.5
        var inside := -signf(body.global_position.x-game.track_center_at(body.global_position.z))
        for edge: float in [-1.0,1.0]:
            var point := body.to_global(Vector3(edge*(extent.x-0.18),extent.y+0.027,0.0))
            if game.selected_track == 0:
                # The wooden blocks can cover part of either slope. Only
                # paint where the bank is the first surface under the mark.
                var open := true
                for offset: float in [-0.85,0.0,0.85]:
                    var sample := point+body.global_basis.z*offset
                    var ray := PhysicsRayQueryParameters3D.create(sample+Vector3.UP*1.75,
                        sample-Vector3.UP*0.10,1,ignored)
                    var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
                    if hit.get("collider") != body:
                        open = false
                        break
                if not open:
                    continue
            _stroke(marks,inks,point,body.global_basis,Vector2(0.19,extent.z*1.70),
                LANDING_INK[game.selected_track] if edge == inside else SHUTTER_INK)
            final_bank_marks.append(point)

func woodworks_bank_mark_ahead(at: Vector3, velocity: Vector3) -> Vector3:
    var speed := -velocity.z
    if game.selected_track != 0 or final_bank_marks.is_empty() or speed < 8.0 or not at.is_finite() or not velocity.is_finite():
        return Vector3.INF
    var bank: Vector3 = game.course_sculptures.bank_roots.back()
    var reach := clampf(speed*0.63,6.0,14.0)
    if at.z < bank.z+Sculptures.BANK_HALF_LENGTH or at.z > bank.z+reach+Sculptures.BANK_HALF_LENGTH:
        return Vector3.INF
    var aim := Feedback.projected_lane_x(at.x,velocity.x,(at.z-bank.z)/speed)
    if absf(aim-bank.x) > Sculptures.BANK_WIDTH*0.5+0.38:
        return Vector3.INF
    var best := Vector3.INF
    var best_distance := INF
    for point in final_bank_marks:
        var distance := at.z-point.z
        if distance > BANK_MARK_MIN_DISTANCE and distance <= reach and distance < best_distance:
            best = point
            best_distance = distance
    return best

func _paint_shutter_center(marks: Array[Transform3D], inks: Array[Color],
        ignored: Array[RID]) -> void:
    var director: Node3D = game.race_director
    var gate_z: float = director.event_z(director.GLACIER_FIRST_SHUTTER)
    # Repeat the mark in gaps between real obstacles. Bake onto dry planks
    # using the same collision query and draw batch as the ramp markings.
    for offset: float in SHUTTER_MARK_OFFSETS:
        var z := gate_z+offset
        var center := Vector3(game.track_center_at(z),game.height_at(z),z)
        var tip := _floor(center+Vector3(0,0,-0.50),false,ignored)
        var left := _floor(center+Vector3(-0.96,0,0.47),false,ignored)
        var right := _floor(center+Vector3(0.96,0,0.47),false,ignored)
        var middle := _floor(center,false,ignored)
        if tip.is_empty() or left.is_empty() or right.is_empty() or middle.is_empty():
            continue
        var point: Vector3 = middle["position"]
        var plane := Basis(Quaternion(Vector3.UP,middle["normal"]))
        shutter_marks.append(point)
        for side in [-1.0,1.0]:
            var arm := plane*Basis(Vector3.UP,-side*0.72)
            var position := point+plane*Vector3(side*0.40,0.026,0.0)
            _stroke(marks,inks,position,arm,Vector2(1.05,0.37),SHUTTER_INK)
        if shutter_marks.size() >= 3:
            break

func shutter_mark_ahead(z: float) -> Vector3:
    if shutter_marks.is_empty() or z > shutter_marks.back().z+11.0:
        return Vector3.INF
    # Prefer the first genuinely upcoming mark. When the player is almost
    # on top of it, use the next one farther down the track.
    for index in range(shutter_marks.size()-1,-1,-1):
        var point := shutter_marks[index]
        if z-point.z > SHUTTER_MARK_MIN_DISTANCE:
            return point
    return Vector3.INF

func _floor(at: Vector3, bridge: bool, ignored: Array[RID]) -> Dictionary:
    var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.75,at+Vector3.DOWN*0.55,1,ignored)
    var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
    var floor_body: StaticBody3D = hit.get("collider") as StaticBody3D
    if floor_body == null or (hit["normal"] as Vector3).y < 0.80:
        return {}
    if bridge:
        if not floor_body.has_meta(ShortcutRoute.ROLLING_SURFACE) or floor_body in game.shortcut_route.launch_ramps:
            return {}
    elif not floor_body.has_meta(TrackSurface.ROAD_FLOOR):
        return {}
    return hit

func _stroke(marks: Array[Transform3D], inks: Array[Color], at: Vector3,
        plane: Basis, size: Vector2, ink: Color) -> void:
    marks.append(Transform3D(plane.scaled_local(Vector3(size.x+0.08,1.0,size.y+0.08)),at))
    inks.append(BACKING)
    marks.append(Transform3D(plane.scaled_local(Vector3(size.x,1.0,size.y)),at+plane.y*0.005))
    inks.append(ink)

func _make_batch(marks: Array[Transform3D], inks: Array[Color]) -> void:
    var tile := PlaneMesh.new()
    tile.size = Vector2.ONE
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = tile
    batch.instance_count = marks.size()
    for i in range(marks.size()):
        batch.set_instance_transform(i,marks[i])
        batch.set_instance_color(i,inks[i])
    paint = MultiMeshInstance3D.new()
    paint.name = "PaintedRampGuides"
    paint.multimesh = batch
    paint.material_override = material
    paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(paint)

func preview(position: Vector3, velocity: Vector3, bridge: bool, in_air: bool) -> Dictionary:
    var forward := -velocity.z
    if not position.is_finite() or not velocity.is_finite() or forward < 5.5:
        return {}
    var reach := clampf(forward*1.1,7.0,24.0)
    var best_distance := reach
    var result: Dictionary = {}
    for window in windows:
        if window["bridge"] != bridge:
            continue
        var lip: Vector3 = window["lip"]
        var landing: Vector3 = window["landing"]
        var distance := position.z-lip.z
        if distance >= best_distance or (distance < -0.55 and (
                not in_air or position.z < landing.z+0.7)):
            continue
        var aim: float = Feedback.projected_lane_x(position.x,velocity.x,maxf(0.0,distance)/forward)
        var lane_error := absf(aim-(landing.x if distance < 0.0 else lip.x))
        var half_width: float = window["half_width"]
        var alignment := 1.0-smoothstep(half_width*0.55,half_width+0.20,lane_error)
        var ramp_weight := 1.0-smoothstep(1.0,reach,distance)
        if distance < 0.0:
            ramp_weight *= smoothstep(landing.z+0.7,lip.z,position.z)
        if alignment <= 0.0 or ramp_weight <= 0.0:
            continue
        result = {"landing":landing,"weight":ramp_weight*alignment}
        best_distance = distance
    return result
