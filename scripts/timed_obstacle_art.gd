extends RefCounted
## Shared render meshes only. Each silhouette fits the director's real
## collision envelope, and both visible layers move with the physics body.
const GRAPHITE := Color("#242730")
const AMBER := Color("#ffd17a")
const ICE := Color("#a9edff")
const STEEL := Color("#aabcc6")
static var mesh_cache: Dictionary = {}

static func build(biome: int, dimensions: Vector3) -> Array[ArrayMesh]:
    var key := Vector4(biome,dimensions.x,dimensions.y,dimensions.z)
    if mesh_cache.has(key):
        return mesh_cache[key]
    var shell := SurfaceTool.new()
    var details := SurfaceTool.new()
    shell.begin(Mesh.PRIMITIVE_TRIANGLES)
    details.begin(Mesh.PRIMITIVE_TRIANGLES)
    var unit := BoxMesh.new()
    unit.size = Vector3.ONE
    match biome:
        0:
            _timber(shell,details,unit,dimensions)
        1:
            _glacier(shell,details,unit,dimensions)
        2:
            _forge(shell,details,unit,dimensions)
    var result: Array[ArrayMesh] = [shell.commit(),details.commit()]
    mesh_cache[key] = result
    return result

static func _timber(shell: SurfaceTool, details: SurfaceTool, unit: Mesh, size: Vector3) -> void:
    var profile := _chamfered_footprint(0.13,0.20)
    _shell(shell,profile,[Vector2(-0.48,0.90),Vector2(-0.37,1.0),
        Vector2(0.30,1.0),Vector2(0.43,0.93)],size,
        [Color("#4a2a21"),Color("#945131"),Color("#c98043"),Color("#bf7c45")])
    # End ferrules wrap the front, rear and top of the timber.
    for side in [-1.0,1.0]:
        _box(details,unit,size,Vector3(side*0.374,0.16,0),Vector3(0.10,0.57,0.95),GRAPHITE)
        _box(details,unit,size,Vector3(side*0.374,0.456,0),Vector3(0.075,0.035,0.74),AMBER)
    for n in [-1.0,0.0,1.0]:
        _box(details,unit,size,Vector3(n*0.15,0.447,0),Vector3(0.042,0.024,0.76),
            AMBER,0.44)
    _box(details,unit,size,Vector3(0,-0.10,0.504),Vector3(0.59,0.07,0.018),Color("#edb06a"))

static func _glacier(shell: SurfaceTool, details: SurfaceTool, unit: Mesh, size: Vector3) -> void:
    var profile := _chamfered_footprint(0.21,0.24)
    _shell(shell,profile,[Vector2(-0.48,0.86),Vector2(-0.32,1.0),
        Vector2(-0.04,1.0),Vector2(0.24,0.91),Vector2(0.48,0.69)],size,
        [Color("#1b354f"),Color("#295977"),Color("#4289a0"),Color("#62bfd0"),Color("#87d5e6")])
    # The narrow crown and twin frost veins read differently from the arm's flat straps.
    _box(details,unit,size,Vector3(0,-0.17,0.498),Vector3(0.54,0.095,0.020),GRAPHITE)
    for side in [-1.0,1.0]:
        _box(details,unit,size,Vector3(side*0.145,0.486,0),Vector3(0.048,0.022,0.39),ICE,side*0.58)
    _box(details,unit,size,Vector3(0,0.49,0.02),Vector3(0.073,0.024,0.114),Color("#ecffff"),PI*0.25)

static func _forge(shell: SurfaceTool, details: SurfaceTool, unit: Mesh, size: Vector3) -> void:
    var profile := _chamfered_footprint(0.10,0.15)
    _shell(shell,profile,[Vector2(-0.48,0.68),Vector2(-0.27,0.74),
        Vector2(0.22,0.82),Vector2(0.28,1.0),Vector2(0.44,0.97)],size,
        [GRAPHITE,Color("#644139"),Color("#ad613d"),Color("#393d44"),Color("#474d53")])
    for side in [-1.0,1.0]:
        _box(details,unit,size,Vector3(side*0.32,0.479,0),Vector3(0.16,0.067,0.65),STEEL)
    for n in [-1.0,0.0,1.0]:
        _box(details,unit,size,Vector3(n*0.113,0.478,0),Vector3(0.062,0.066,0.53),Color("#fb9c63"))
    _box(details,unit,size,Vector3(0,0.25,0.496),Vector3(0.70,0.085,0.019),STEEL)

static func _chamfered_footprint(cut_x: float, cut_z: float) -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-0.50,0.50-cut_z),Vector2(-0.50+cut_x,0.50),
        Vector2(0.50-cut_x,0.50),Vector2(0.50,0.50-cut_z),
        Vector2(0.50,-0.50+cut_z),Vector2(0.50-cut_x,-0.50),
        Vector2(-0.50+cut_x,-0.50),Vector2(-0.50,-0.50+cut_z)])

static func _shell(surface: SurfaceTool, profile: PackedVector2Array, levels: Array[Vector2],
        size: Vector3, tints: Array[Color]) -> void:
    var bottom := _ring(profile,levels[0],size)
    for i in range(1,bottom.size()-1):
        _triangle(surface,bottom[0],bottom[i],bottom[i+1],tints[0])
    for band in range(1,levels.size()):
        var top := _ring(profile,levels[band],size)
        for i in profile.size():
            var next := (i+1)%profile.size()
            var tint := tints[band-1] if i%2 == 1 else tints[band-1].lightened(0.08)
            _triangle(surface,bottom[i],top[i],top[next],tint)
            _triangle(surface,bottom[i],top[next],bottom[next],tint)
        bottom = top
    for i in range(1,bottom.size()-1):
        _triangle(surface,bottom[0],bottom[i+1],bottom[i],tints[-1])

static func _ring(profile: PackedVector2Array, level: Vector2, size: Vector3) -> PackedVector3Array:
    var points := PackedVector3Array()
    for point in profile:
        points.append(Vector3(point.x*level.y,level.x,point.y*level.y)*size)
    return points

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    var normal := (c-a).cross(b-a).normalized()
    for point: Vector3 in [a,b,c]:
        surface.set_normal(normal)
        surface.set_color(tint)
        surface.add_vertex(point)

static func _box(surface: SurfaceTool, unit: Mesh, size: Vector3, offset: Vector3,
        extent: Vector3, tint: Color, yaw := 0.0) -> void:
    var turn := Basis(Vector3.UP,yaw)
    var scale := Basis.from_scale(size)
    var basis := scale*turn.scaled_local(extent)
    var normal_basis := basis.inverse().transposed()
    var parts := unit.surface_get_arrays(0)
    var vertices: PackedVector3Array = parts[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = parts[Mesh.ARRAY_NORMAL]
    for vertex: int in parts[Mesh.ARRAY_INDEX]:
        surface.set_normal((normal_basis*normals[vertex]).normalized())
        surface.set_color(tint)
        surface.add_vertex(basis*vertices[vertex]+offset*size)
