extends MeshInstance3D
## Baked obstacle shells and ground paint for the first module. Entry
## chevrons mark gaps at the entrance, outside the paddle's full sweep.
const Racer = preload("res://scripts/marble.gd")
const Visuals = preload("res://scripts/visuals.gd")
const ENTRY_DEPTH := 1.30
const ROAD_HALF_WIDTH := 6.38
const CLEARANCE := Racer.RADIUS+0.12
const ENTRY_LEAD := 1.35
const PALETTES := [
    [Color("#684934"),Color("#b17b44"),Color("#ffca78"),Color("#cef3ce")],
    [Color("#234c66"),Color("#4c9bb4"),Color("#ffc978"),Color("#bafaff")],
    [Color("#3d343d"),Color("#995746"),Color("#ffad65"),Color("#b6f4da")]
]
const PEG_SIDES := [12,8,10]
const PEG_SHOULDERS := [0.94,0.73,0.87]
var entry_gaps: Array[Vector2] = []
var entry_z := 0.0
var obstacle_count := 0
var peg_count := 0
var danger_footprints: Array[Rect2] = []
var spinner_radius := 0.0

func build(section: Node3D, game: Node3D, floor_z: float) -> void:
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
        first_edge = maxf(first_edge,footprint.end.y)
        # A band in front of each footprint stays visible as marbles approach it.
        var marking_z := footprint.end.y+0.065
        _ground(surface,game,floor_z,Vector2(footprint.get_center().x,marking_z+0.09),
            Vector2(footprint.size.x,0.26),palette[2])
        if footprint.size.x > 1.0:
            _ground(surface,game,floor_z,Vector2(footprint.get_center().x,marking_z+0.42),
                Vector2(footprint.size.x*0.78,0.11),palette[2])

    var spinner := section.get_node_or_null("KineticPaddle_01") as AnimatableBody3D
    if spinner != null:
        spinner_radius = _sweep_radius(spinner)
        var center := Vector2(spinner.position.x,spinner.position.z)
        # Intersect the circular sweep with the approach band, not its full
        # square bounds. The rest is marked by the dashed ring further in.
        var depth := maxf(0.0,first_edge-ENTRY_DEPTH-center.y)
        if depth < spinner_radius:
            var width := sqrt(spinner_radius*spinner_radius-depth*depth)
            danger_footprints.append(Rect2(center+Vector2(-width,depth),
                Vector2(width*2.0,spinner_radius-depth)))
        _sweep_arcs(surface,game,floor_z,center,spinner_radius,palette[2])
    entry_z = first_edge+ENTRY_LEAD
    entry_gaps = _entry_gaps(danger_footprints,first_edge)
    for gap in entry_gaps:
        var midpoint := (gap.x+gap.y)*0.5
        var width := minf(0.68,(gap.y-gap.x)*0.51)
        for flank in [-1.0,1.0]:
            var tail := Vector2(midpoint+flank*width,entry_z+0.43)
            var nose := Vector2(midpoint,entry_z-0.24)
            _ground_strip(surface,game,floor_z,tail,nose,0.19,palette[3])
            _ground_strip(surface,game,floor_z,
                tail+Vector2(0.0,0.52),nose+Vector2(0.0,0.52),0.14,palette[3])
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

static func _ground(surface: SurfaceTool, game: Node3D, floor_z: float,
        center: Vector2, size: Vector2, tint: Color) -> void:
    _ground_strip(surface,game,floor_z,center-Vector2(size.x*0.5,0.0),
        center+Vector2(size.x*0.5,0.0),size.y,tint)

static func _ground_strip(surface: SurfaceTool, game: Node3D, floor_z: float,
        start: Vector2, end: Vector2, width: float, tint: Color) -> void:
    var direction := (end-start).normalized()
    var half := Vector2(-direction.y,direction.x)*width*0.5
    _quad(surface,Transform3D.IDENTITY,_ground_point(game,floor_z,start-half),
        _ground_point(game,floor_z,end-half),_ground_point(game,floor_z,end+half),
        _ground_point(game,floor_z,start+half),tint)

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
        _ground_strip(surface,game,floor_z,
            hub+Vector2.from_angle(angle)*radius,
            hub+Vector2.from_angle(angle+0.34)*radius,0.105,tint)

static func _quad(surface: SurfaceTool, pose: Transform3D, a: Vector3,
        b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
    var normal := pose.basis*(c-a).cross(b-a).normalized()
    for point in [a,b,c,a,c,d]:
        surface.set_color(tint)
        surface.set_normal(normal)
        surface.add_vertex(pose*point)
