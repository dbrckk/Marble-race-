extends MeshInstance3D
## Baked shells and ground paint for the first and last obstacle modules.
## Forge’s final module also paints local openings outside moving sweeps.
const Racer = preload("res://scripts/marble.gd")
const Visuals = preload("res://scripts/visuals.gd")
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const CourseMechanics = preload("res://scripts/course_mechanics.gd")
const ENTRY_DEPTH := 1.30
const ROAD_HALF_WIDTH := 6.38
const CLEARANCE := Racer.RADIUS+0.12
const ENTRY_LEAD := 1.35
const ENTRY_MARK_MIN_DISTANCE := 2.4
const ENTRY_REACTION_SECONDS := 0.10
const ENTRY_TRAFFIC_CLEARANCE := Racer.RADIUS*2.0+0.16
const LAYOUT_NAMES := ["SLALOM BLOCKS","PEG ROWS","POSTS & PADDLE"]
const FORGE_PASS_INK := Color("#b5ffe6")
const MARKING_OUTLINE := Color("#20252a")
const PALETTES := [
    [Color("#3d3029"),Color("#62472e"),Color("#ffbd5e"),Color("#b6ffdc")],
    [Color("#233848"),Color("#38566a"),Color("#ffc66e"),Color("#c4f9ff")],
    [Color("#322933"),Color("#5b3841"),Color("#ffae5e"),Color("#acffda")]
]
const PEG_SIDES := [12,8,10]
const PEG_SHOULDERS := [0.94,0.73,0.87]
var entry_gaps: Array[Vector2] = []
var layout_name := ""
var entry_z := 0.0
var clear_z := INF
var passing_marks: Array[Vector2] = []
var obstacle_count := 0
var peg_count := 0
var danger_footprints: Array[Rect2] = []
var spinner_radius := 0.0
var baffle_footprints: Array[Rect2] = []
var spinner_center := Vector2.ZERO

func build(section: Node3D, game: Node3D, floor_z: float, section_index: int, layout: int) -> void:
    layout_name = LAYOUT_NAMES[layout]
    var palette: Array = PALETTES[game.selected_track]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var first_edge := -INF
    for body in section.get_children():
        if not body is StaticBody3D or body.get_child_count() != 1:
            continue
        var marker := body.get_child(0) as CollisionShape3D
        if marker == null:
            continue
        if marker.shape is CylinderShape3D:
            var peg := marker.shape as CylinderShape3D
            _peg(surface,body.transform,peg,palette,game.selected_track)
            peg_count += 1
        elif marker.shape is BoxShape3D and (body.name.begins_with("AntiEdgeBaffle") or (
                body.name.begins_with("GatePost") or body.name.begins_with("SlalomBlock"))):
            var shape := marker.shape as BoxShape3D
            _block(surface,body.transform,shape.size,palette)
        else:
            continue
        obstacle_count += 1
        var footprint := _footprint(marker)
        danger_footprints.append(footprint)
        clear_z = minf(clear_z,footprint.position.y-CLEARANCE)
        if body.name.begins_with("AntiEdgeBaffle"):
            baffle_footprints.append(footprint)
        first_edge = maxf(first_edge,footprint.end.y)
        # A dark apron separates the amber warning from bright floor seams.
        var center := Vector2(footprint.get_center().x,footprint.end.y+0.22)
        var half_width := Vector2(footprint.size.x*0.5,0)
        _marked_strip(surface,game,floor_z,center-half_width,center+half_width,0.28,palette[2])
        if footprint.size.x > 1.0:
            var far_edge := center+Vector2(0,0.36)
            _ground_strip(surface,game,floor_z,far_edge-half_width*0.78,
                far_edge+half_width*0.78,0.11,MARKING_OUTLINE)

    var spinner := section.get_node_or_null("KineticPaddle_%02d" % section_index) as AnimatableBody3D
    if spinner != null:
        spinner_radius = _sweep_radius(spinner)
        spinner_center = Vector2(spinner.position.x,spinner.position.z)
        clear_z = minf(clear_z,spinner_center.y-spinner_radius-CLEARANCE)
        # Intersect the circular sweep with the approach band, not its full
        # square bounds. The rest is marked by the dashed ring further in.
        var depth := maxf(0.0,first_edge-ENTRY_DEPTH-spinner_center.y)
        if section_index == 1 and depth < spinner_radius:
            var width := sqrt(spinner_radius*spinner_radius-depth*depth)
            danger_footprints.append(Rect2(spinner_center+Vector2(-width,depth),
                Vector2(width*2.0,spinner_radius-depth)))
        _sweep_arcs(surface,game,floor_z,spinner_center,spinner_radius,palette[2])
    entry_z = first_edge+ENTRY_LEAD
    if section_index == 1:
        var hammer := section.get_node_or_null("SwingHammer_01") as AnimatableBody3D
        if is_instance_valid(hammer):
            # The swing rotates about Z, leaving the rear face at this depth.
            var hit := hammer.get_child(0) as CollisionShape3D
            clear_z = minf(clear_z,_footprint(hit).position.y-CLEARANCE)
    if game.selected_track == 2 and section_index == game.FINAL_OBSTACLE_SECTION:
        _forge_passing_marks(surface,section,game,floor_z,section_index)
    if section_index == 1:
        entry_gaps = _entry_gaps(danger_footprints,first_edge)
    for gap in entry_gaps:
        var midpoint := (gap.x+gap.y)*0.5
        var width := minf(0.68,(gap.y-gap.x)*0.51)
        for flank in [-1.0,1.0]:
            var tail := Vector2(midpoint+flank*width,entry_z+0.43)
            var nose := Vector2(midpoint,entry_z-0.24)
            _marked_strip(surface,game,floor_z,tail,nose,0.23,palette[3])
            _marked_strip(surface,game,floor_z,
                tail+Vector2(0.0,0.64),nose+Vector2(0.0,0.64),0.16,palette[3])
    surface.index()
    mesh = surface.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.vertex_color_is_srgb = true
    material.roughness = 0.57
    material.emission_enabled = true
    material.emission = Color("#232121")
    material.emission_energy_multiplier = 0.24
    material_override = material
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _forge_passing_marks(surface: SurfaceTool, section: Node3D, game: Node3D,
        floor_z: float, section_index: int) -> void:
    var obstructions := danger_footprints.duplicate()
    var last_vent := CourseMechanics.ZONE_Z.size()-1
    var vent := CourseMechanics.placement_at(last_vent,2,game.built_variation)
    var vent_radius := sqrt(CourseMechanics.VENT_RADIUS_SQUARED)
    obstructions.append(Rect2(vent.x-section.global_position.x-vent_radius,
        vent.z-vent_radius,2.0*vent_radius,2.0*vent_radius))
    var ramp := section.get_node_or_null("RideableCrest_%02d" % section_index)
    if ramp != null:
        obstructions.append(_footprint(ramp.get_child(0) as CollisionShape3D))
    var hammer := section.get_node_or_null("SwingHammer_%02d" % section_index) as AnimatableBody3D
    if hammer != null:
        var hit := hammer.get_child(0) as CollisionShape3D
        var size: Vector3 = (hit.shape as BoxShape3D).size
        var radius := Vector2(size.x*0.5,absf(hit.position.y)+size.y*0.5).length()
        var footprint := Rect2(hammer.position.x-radius,hammer.position.z-size.z*0.5,2.0*radius,size.z)
        obstructions.append(footprint)
        clear_z = minf(clear_z,footprint.position.y-CLEARANCE)
    for offset: float in [4.85,1.65,-1.55,-4.65]:
        var z := floor_z+offset
        var near := z+0.52
        var far := z-2.1
        var blocked: Array[Vector2] = []
        for footprint in obstructions:
            if footprint.end.y+CLEARANCE >= far and footprint.position.y-CLEARANCE <= near:
                blocked.append(Vector2(footprint.position.x-CLEARANCE,footprint.end.x+CLEARANCE))
        if spinner_radius > 0.0:
            var depth := clampf(spinner_center.y,far-CLEARANCE,near+CLEARANCE)-spinner_center.y
            if absf(depth) < spinner_radius:
                var width := sqrt(spinner_radius*spinner_radius-depth*depth)+CLEARANCE
                blocked.append(Vector2(spinner_center.x-width,spinner_center.x+width))
        var gaps := _open_intervals(blocked)
        for side in [-1.0,1.0]:
            var best := Vector2.INF
            var best_x := INF
            var error := INF
            for gap in gaps:
                var inset := minf(0.33,(gap.y-gap.x)*0.45)
                var x := clampf(side*2.0,gap.x+inset,gap.y-inset)
                if x*side > 0.18 and absf(x-side*2.0) < error:
                    best = gap
                    best_x = x
                    error = absf(x-side*2.0)
            if not best.is_finite():
                continue
            var mark := Vector2(best_x,z)
            var half_width := clampf(minf(best_x-best.x,best.y-best_x)+0.12,0.32,0.60)
            for flank in [-1.0,1.0]:
                _marked_strip(surface,game,floor_z,mark+Vector2(flank*half_width,0.42),
                    mark-Vector2(0,0.30),0.24,FORGE_PASS_INK)
            passing_marks.append(mark)

func passing_mark_ahead(game: Node3D, at: Vector3, velocity: Vector3) -> Vector3:
    var speed := -velocity.z
    if not at.is_finite() or not velocity.is_finite() or speed < 8.0 or (
            at.z > entry_z+13.0 or at.z < clear_z):
        return Vector3.INF
    var best := Vector3.INF
    var cost := INF
    var reach := minf(13.0,speed*0.74)
    for mark in passing_marks:
        var distance := at.z-mark.y
        if distance < 3.2 or distance > reach:
            continue
        var x := mark.x+global_position.x
        var lateral := absf(x-RaceFeedback.projected_lane_x(at.x,velocity.x,distance/speed))
        if lateral <= 2.4 and distance+2.0*lateral < cost:
            best = Vector3(x,game.height_at(mark.y)+0.10,mark.y)
            cost = distance+2.0*lateral
    return best

func entry_mark_ahead(game: Node3D, at: Vector3, velocity: Vector3) -> Vector3:
    var speed := -velocity.z
    var distance := at.z-entry_z
    if not at.is_finite() or not velocity.is_finite() or speed < 4.0 or (
            distance <= 3.2 or distance > clampf(speed*1.3,7.0,14.0)):
        return Vector3.INF
    var aim := RaceFeedback.projected_lane_x(at.x,velocity.x,distance/speed)
    var best := Vector3.INF
    var cost := minf(2.15,0.65+4.2*distance/speed)
    for gap in entry_gaps:
        var x := global_position.x+(gap.x+gap.y)*0.5
        var lateral := absf(x-aim)
        if lateral <= cost:
            best = Vector3(x,game.height_at(entry_z)+0.10,entry_z)
            cost = lateral
    return best

func pack_entry_eta(at: Vector3, velocity: Vector3) -> float:
    var distance := at.z-entry_z
    var speed := -velocity.z
    if not at.is_finite() or not velocity.is_finite() or speed < 4.0 or (
            absf(at.x-global_position.x) > ROAD_HALF_WIDTH or
            distance <= maxf(ENTRY_MARK_MIN_DISTANCE,speed*(ENTRY_REACTION_SECONDS+0.07)) or
            distance > minf(13.0,speed*0.92)):
        return INF
    return distance/speed

func pack_entry_guidance(game: Node3D, at: Vector3, velocity: Vector3,
        eta: float, rivals: Array[RigidBody3D]) -> Dictionary:
    if rivals.is_empty():
        return {}
    var rival_positions := PackedVector2Array()
    var rival_velocities := PackedVector2Array()
    for rival in rivals:
        var motion: Vector3 = rival.linear_velocity
        if game.net.is_client():
            motion = game.net.replica_velocity(rival)
        elif rival.freeze:
            motion = Vector3.ZERO
        if not motion.is_finite():
            return {}
        rival_positions.append(Vector2(rival.global_position.x,rival.global_position.z))
        rival_velocities.append(Vector2(motion.x,motion.z))
    var settling_time := eta-ENTRY_REACTION_SECONDS
    var reaction_x := at.x+velocity.x*ENTRY_REACTION_SECONDS
    var accel_limit := Racer.human_steering_force(1.0,velocity.z,velocity.x,game.selected_track)*0.72
    # The cubic joins measured drift to zero lateral speed at the paint.
    # Intersect the two endpoint acceleration bounds to find reachable x.
    var budget := accel_limit*settling_time*settling_time
    var lateral_run := velocity.x*settling_time
    var limit_left := reaction_x+(maxf(4.0*lateral_run,2.0*lateral_run)-budget)/6.0
    var limit_right := reaction_x+(minf(4.0*lateral_run,2.0*lateral_run)+budget)/6.0
    # The last segment reaches beyond the first collider band. The same
    # entry_gaps exclude the paddle's sweep wherever it intersects that band.
    var exit_time := eta+(ENTRY_LEAD+ENTRY_DEPTH)/-velocity.z
    var drift := RaceFeedback.projected_lane_x(at.x,velocity.x,eta)
    var best := Vector3.INF
    var score := INF
    var blocked := false
    for gap in entry_gaps:
        var left := maxf(global_position.x+gap.x+0.10,limit_left)
        var right := minf(global_position.x+gap.y-0.10,limit_right)
        if left > right:
            continue
        var straight := clampf(drift,left,right)
        for x: float in [straight,(left+right)*0.5,left,right]:
            var cost := absf(x-drift)
            if cost >= score:
                continue
            if _entry_traffic_blocks(at,velocity,settling_time,x-reaction_x,exit_time,rival_positions,rival_velocities):
                blocked = true
                continue
            best = Vector3(x,game.height_at(entry_z)+0.10,entry_z)
            score = cost
    return {"target":best,"blocked":blocked and not best.is_finite()} if best.is_finite() or blocked else {}

func _entry_traffic_blocks(at: Vector3, velocity: Vector3, settling_time: float,
        displacement: float, exit_time: float,
        rival_positions: PackedVector2Array, rival_velocities: PackedVector2Array) -> bool:
    var start_x := at.x+velocity.x*ENTRY_REACTION_SECONDS
    var last_at := Vector2(at.x,at.z)
    var last_t := 0.0
    for step in range(6):
        var u := minf(1.0,float(step)*0.25)
        var t := ENTRY_REACTION_SECONDS+settling_time*u if step < 5 else exit_time
        var x := start_x+displacement*u*u*(3.0-2.0*u)+velocity.x*settling_time*u*(1.0-u)*(1.0-u)
        var next_at := Vector2(x,at.z+velocity.z*t)
        for i in range(rival_positions.size()):
            var origin := rival_positions[i]
            var speed := rival_velocities[i]
            var before := last_at-Vector2(RaceFeedback.projected_lane_x(origin.x,speed.x,last_t),
                origin.y+speed.y*last_t)
            var after := next_at-Vector2(RaceFeedback.projected_lane_x(origin.x,speed.x,t),
                origin.y+speed.y*t)
            var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,before,after)
            if nearest.length_squared() < ENTRY_TRAFFIC_CLEARANCE*ENTRY_TRAFFIC_CLEARANCE:
                return true
        last_at = next_at
        last_t = t
    return false

func approach_warning(position_at: Vector3, velocity: Vector3, reach_seconds: float) -> Dictionary:
    var local := to_local(position_at)
    var speed := maxf(2.0,-velocity.z)
    var nearest := reach_seconds
    var message := ""
    for footprint in baffle_footprints:
        if local.z < footprint.position.y-Racer.RADIUS:
            continue
        var eta := maxf(0.0,local.z-footprint.end.y-Racer.RADIUS)/speed
        if eta > nearest:
            continue
        var x := RaceFeedback.projected_lane_x(local.x,velocity.x,eta)
        if x >= footprint.position.x-Racer.RADIUS and x <= footprint.end.x+Racer.RADIUS:
            nearest = eta
            message = "BAFFLE LEFT  •  MOVE INWARD" if footprint.get_center().x < 0.0 else (
                "BAFFLE RIGHT  •  MOVE INWARD")
    var sweep := spinner_radius+Racer.RADIUS
    if spinner_radius > 0.0 and local.z >= spinner_center.y-sweep:
        var distance := local.z-spinner_center.y
        var x := RaceFeedback.projected_lane_x(local.x,velocity.x,maxf(0.0,distance)/speed)
        var lateral := x-spinner_center.x
        var half_depth := sqrt(maxf(0.0,sweep*sweep-lateral*lateral))
        var eta := maxf(0.0,distance-half_depth)/speed
        if half_depth > 0.0 and distance >= -half_depth and eta < nearest:
            nearest = eta
            message = "PADDLE SWEEP  •  WATCH THE ARM"
    return {} if message.is_empty() else {"text":message,"eta":nearest}

func _footprint(marker: CollisionShape3D) -> Rect2:
    var body := marker.get_parent() as Node3D
    var pose := body.transform*marker.transform
    var bounds: AABB = marker.shape.get_debug_mesh().get_aabb()
    var projected: AABB = pose*bounds
    return Rect2(Vector2(projected.position.x,projected.position.z),
        Vector2(projected.size.x,projected.size.z))

static func _entry_gaps(footprints: Array[Rect2], first_edge: float) -> Array[Vector2]:
    var occupied: Array[Vector2] = []
    for footprint in footprints:
        if footprint.end.y >= first_edge-ENTRY_DEPTH:
            occupied.append(Vector2(footprint.position.x-CLEARANCE,footprint.end.x+CLEARANCE))
    return _open_intervals(occupied)

static func _open_intervals(occupied: Array[Vector2]) -> Array[Vector2]:
    occupied.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x < b.x)
    var gaps: Array[Vector2] = []
    var cursor := -ROAD_HALF_WIDTH+CLEARANCE
    var limit := ROAD_HALF_WIDTH-CLEARANCE
    for barrier in occupied:
        var edge := minf(barrier.x,limit)
        if edge-cursor >= 0.48:
            gaps.append(Vector2(cursor,edge))
        cursor = maxf(cursor,barrier.y)
    if limit-cursor >= 0.48:
        gaps.append(Vector2(cursor,limit))
    return gaps

static func _block(surface: SurfaceTool, pose: Transform3D, size: Vector3, palette: Array) -> void:
    var bevel: float = minf(0.085,size.y*0.13)
    _mesh_with_paint(surface,Visuals.rounded_box(size,bevel),pose,palette[0])
    # Reflective cap and broken hazard bands read from above and head-on.
    var top := size.y*0.5
    var front := size.z*0.5
    var band := BoxMesh.new()
    band.size = Vector3(size.x*0.79,0.052,size.z*0.64)
    _mesh_with_paint(surface,band,pose.translated_local(Vector3(0.0,top+0.010,0.0)),palette[1])
    for index in range(3):
        var x := (float(index)-1.0)*size.x*0.26
        var width := size.x*0.12
        var low := top-size.y*0.33
        var high := top-size.y*0.12
        _quad(surface,pose,Vector3(x-width,low,front+0.008),
            Vector3(x-width*0.23,high,front+0.008),
            Vector3(x+width,high,front+0.008),
            Vector3(x+width*0.23,low,front+0.008),palette[2])
        # Keep the inlay visible from the chase camera above the pack.
        var y := top+0.040
        _quad(surface,pose,Vector3(x-width,y,front*0.58),
            Vector3(x-width*0.23,y,front*0.20),
            Vector3(x+width*0.23,y,front*0.20),
            Vector3(x+width,y,front*0.58),palette[2])

static func _peg(surface: SurfaceTool, pose: Transform3D, shape: CylinderShape3D,
        palette: Array, biome: int) -> void:
    var shell := CylinderMesh.new()
    shell.radial_segments = PEG_SIDES[biome]
    shell.rings = 0
    shell.top_radius = shape.radius*PEG_SHOULDERS[biome]
    shell.bottom_radius = shape.radius
    shell.height = shape.height
    _mesh_with_paint(surface,shell,pose,palette[0])
    var collar := CylinderMesh.new()
    collar.radial_segments = PEG_SIDES[biome]
    collar.rings = 0
    collar.top_radius = shell.top_radius
    collar.bottom_radius = shape.radius*1.02
    collar.height = 0.16
    _mesh_with_paint(surface,collar,
        pose.translated_local(Vector3.UP*(shape.height*0.5-0.06)),palette[2])
    _mesh_with_paint(surface,collar,pose.translated_local(
        Vector3.DOWN*(shape.height*0.5-0.12)),palette[1])

static func _mesh_with_paint(surface: SurfaceTool, source: Mesh,
        pose: Transform3D, paint: Color) -> void:
    var arrays := source.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for index in indices:
        surface.set_color(paint)
        surface.set_normal(pose.basis*normals[index])
        surface.add_vertex(pose*vertices[index])

static func _ground_point(game: Node3D, floor_z: float, point: Vector2) -> Vector3:
    # Project onto the same tilted plank plane as the module physics.
    # Max also clears the overlapping seam at the top of this section.
    var height: float = game.height_at(floor_z)+(point.y-floor_z)*game.track_grade_at(floor_z)
    return Vector3(point.x,maxf(height,game.height_at(point.y))+0.072,point.y)

static func _marked_strip(surface: SurfaceTool, game: Node3D, floor_z: float,
        start: Vector2, end: Vector2, width: float, tint: Color) -> void:
    _ground_strip(surface,game,floor_z,start,end,width+0.15,MARKING_OUTLINE)
    _ground_strip(surface,game,floor_z,start,end,width,tint,0.012)

static func _ground_strip(surface: SurfaceTool, game: Node3D, floor_z: float,
        start: Vector2, end: Vector2, width: float, tint: Color, lift := 0.0) -> void:
    var direction := (end-start).normalized()
    var half := Vector2(-direction.y,direction.x)*width*0.5
    var offset := Vector3.UP*lift
    _quad(surface,Transform3D.IDENTITY,_ground_point(game,floor_z,start-half)+offset,
        _ground_point(game,floor_z,end-half)+offset,_ground_point(game,floor_z,end+half)+offset,
        _ground_point(game,floor_z,start+half)+offset,tint)

static func _sweep_radius(spinner: AnimatableBody3D) -> float:
    var radius := 0.0
    for child in spinner.get_children():
        if child is CollisionShape3D and child.shape is BoxShape3D:
            radius = maxf(radius,Vector2(child.shape.size.x,child.shape.size.z).length()*0.5)
    return radius

static func _sweep_arcs(surface: SurfaceTool, game: Node3D, floor_z: float,
        hub: Vector2, radius: float, tint: Color) -> void:
    for index in range(12):
        var angle := TAU*float(index)/12.0
        _marked_strip(surface,game,floor_z,
            hub+Vector2.from_angle(angle)*radius,
            hub+Vector2.from_angle(angle+0.34)*radius,0.12,tint)

static func _quad(surface: SurfaceTool, pose: Transform3D, a: Vector3,
        b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
    var normal := pose.basis*(c-a).cross(b-a).normalized()
    for point in [a,b,c,a,c,d]:
        surface.set_color(tint)
        surface.set_normal(normal)
        surface.add_vertex(pose*point)
