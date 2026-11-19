extends RefCounted
## The four collectible meshes and their matching screen glyphs.
const DARK := Color("#101927")
const CASE := Color("#283750")
const PROFILES := [
    [Vector2(0,-0.73),Vector2(0.59,-0.10),Vector2(0.59,0.11),Vector2(0,0.73),Vector2(-0.59,0.11),Vector2(-0.59,-0.10)],
    [Vector2(0,-0.86),Vector2(0.46,-0.19),Vector2(0.46,0.37),Vector2(0.25,0.60),Vector2(-0.25,0.60),Vector2(-0.46,0.37),Vector2(-0.46,-0.19)],
    [Vector2(-0.46,-0.50),Vector2(0.46,-0.50),Vector2(0.74,-0.25),Vector2(0.74,0.25),Vector2(0.46,0.50),Vector2(-0.46,0.50),Vector2(-0.74,0.25),Vector2(-0.74,-0.25)],
    [Vector2(-0.55,-0.57),Vector2(0.55,-0.57),Vector2(0.70,-0.22),Vector2(0.57,0.27),Vector2(0,0.65),Vector2(-0.57,0.27),Vector2(-0.70,-0.22)]
]
const SYMBOLS := [
    [Vector2(0.14,-0.92),Vector2(-0.63,0.14),Vector2(-0.12,0.14),Vector2(-0.26,0.93),Vector2(0.64,-0.22),Vector2(0.12,-0.22)],
    [Vector2(0,-0.87),Vector2(0.79,-0.04),Vector2(0.30,-0.04),Vector2(0.30,0.73),Vector2(-0.30,0.73),Vector2(-0.30,-0.04),Vector2(-0.79,-0.04)],
    [Vector2(-1,0.05),Vector2(-0.53,0.05),Vector2(-0.24,-0.67),Vector2(0.23,0.27),Vector2(0.45,-0.12),Vector2(1,-0.12),Vector2(1,0.15),Vector2(0.64,0.15),Vector2(0.19,0.79),Vector2(-0.23,-0.05),Vector2(-0.37,0.31),Vector2(-1,0.31)],
    [Vector2(-0.85,-0.63),Vector2(-0.59,-0.83),Vector2(0,-0.13),Vector2(0.59,-0.83),Vector2(0.85,-0.63),Vector2(0,0.51)]
]
static var cached_meshes: Dictionary = {}

static func glyph(effect: int) -> PackedVector2Array:
    return PackedVector2Array(SYMBOLS[effect])

static func build(effect: int, tint: Color) -> ArrayMesh:
    var key := Vector2i(effect,tint.to_rgba32())
    if cached_meshes.has(key):
        return cached_meshes[key]
    var mesh := SurfaceTool.new()
    mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    var profile := PackedVector2Array(PROFILES[effect])
    var lens := _scaled(profile,0.69)
    var rim := _scaled(profile,0.84)
    var shell := _scaled(profile,0.98)
    _band(mesh,shell,-0.19,shell,0.19,CASE,DARK)
    for side in [-1.0,1.0]:
        _band(mesh,shell,side*0.19,rim,side*0.29,tint.darkened(0.43),tint.darkened(0.63))
        _band(mesh,rim,side*0.29,lens,side*0.32,tint.lightened(0.32),tint.darkened(0.22))
        _panel(mesh,lens,side*0.32,tint.darkened(0.09),true)
        var mark := glyph(effect)
        var width: float = [0.24,0.27,0.38,0.33][effect]
        for i in mark.size():
            mark[i] *= Vector2(width,0.32)
            if side < 0.0:
                mark[i].x = -mark[i].x
        _panel(mesh,mark,side*0.333,DARK,false)
    var result := mesh.commit()
    cached_meshes[key] = result
    return result

static func _scaled(points: PackedVector2Array, scale: float) -> PackedVector2Array:
    var result := points.duplicate()
    for i in result.size():
        result[i] *= scale
    return result

static func _vertex(point: Vector2, depth: float) -> Vector3:
    return Vector3(point.x,-point.y,depth)

static func _band(mesh: SurfaceTool, from: PackedVector2Array, a: float,
        to: PackedVector2Array, b: float, light: Color, shade: Color) -> void:
    for i in from.size():
        var next := (i+1)%from.size()
        var front := _vertex(from[i],a)
        var edge := _vertex(from[next],a)
        var lip := _vertex(to[i],b)
        var corner := _vertex(to[next],b)
        var tint := light.lerp(shade,float(i%4)/3.0)
        _triangle(mesh,front,edge,lip,tint)
        _triangle(mesh,edge,corner,lip,tint.darkened(0.08))

static func _panel(mesh: SurfaceTool, points: PackedVector2Array, depth: float, tint: Color, faceted: bool) -> void:
    if faceted:
        for i in points.size():
            var color := tint.lerp(Color.WHITE,0.09*float(i%4)).darkened(0.10*float(i%2))
            _triangle(mesh,Vector3(0,0,depth),_vertex(points[i],depth),
                _vertex(points[(i+1)%points.size()],depth),color)
        return
    var triangles := Geometry2D.triangulate_polygon(points)
    for i in range(0,triangles.size(),3):
        _triangle(mesh,_vertex(points[triangles[i]],depth),_vertex(points[triangles[i+1]],depth),
            _vertex(points[triangles[i+2]],depth),tint)

static func _triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    for point: Vector3 in [a,b,c]:
        mesh.set_color(tint)
        mesh.add_vertex(point)
