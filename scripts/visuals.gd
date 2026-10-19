extends RefCounted
## Cached geometry for smooth rounded-edge wooden planks / painted plastic rails.
## A rounded-box mesh has smooth edge normals; the BoxShape3D remains exact for physics.
static var _cache: Dictionary = {}

static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
    var r: float = minf(radius, minf(size.x, minf(size.y, size.z)) * 0.48)
    var key := "%s:%0.3f" % [str(size), r]
    if _cache.has(key):
        return _cache[key]
    var half: Vector3 = size * 0.5
    var inner: Vector3 = half - Vector3.ONE * r
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for axis in range(3):
        var u := (axis + 1) % 3
        var v := (axis + 2) % 3
        for sign in [-1.0, 1.0]:
            var us := [-half[u], -inner[u], inner[u], half[u]]
            var vs := [-half[v], -inner[v], inner[v], half[v]]
            for yi in range(3):
                for xi in range(3):
                    var raw: Array[Vector3] = []
                    for yy in [yi, yi + 1]:
                        for xx in [xi, xi + 1]:
                            var p := Vector3.ZERO
                            p[axis] = half[axis] * sign
                            p[u] = us[xx]
                            p[v] = vs[yy]
                            raw.append(p)
                    _emit_quad(raw[0],raw[1],raw[3],raw[2],inner,vertices,normals,uvs,indices)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    _cache[key] = result
    return result

static func _emit_quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,inner: Vector3,
        vertices: PackedVector3Array,normals: PackedVector3Array,uvs: PackedVector2Array,
        indices: PackedInt32Array) -> void:
    var points := [a,b,c,d]
    var i0 := vertices.size()
    for p in points:
        var center: Vector3 = Vector3(clampf(p.x,-inner.x,inner.x),
            clampf(p.y,-inner.y,inner.y),clampf(p.z,-inner.z,inner.z))
        var delta: Vector3 = p-center
        var normal: Vector3 = delta.normalized()
        var radius: float = delta.length()
        var q: Vector3 = center + normal * minf(radius, minf(absf(p.x)+absf(p.y)+absf(p.z), radius))
        # The raw corner sits on the original box. Push it onto the rounded shell.
        var r: float = minf(minf(absf(p.x)-inner.x if absf(p.x)>inner.x else INF,
                         absf(p.y)-inner.y if absf(p.y)>inner.y else INF),
                      absf(p.z)-inner.z if absf(p.z)>inner.z else INF)
        if r != INF:
            q = center + normal * r
        vertices.append(q)
        normals.append(normal)
        uvs.append(Vector2(p.x+p.z*0.12,p.z))
    var forward := (vertices[i0+1]-vertices[i0]).cross(vertices[i0+3]-vertices[i0])
    if forward.dot(normals[i0]) > 0:
        indices.append_array(PackedInt32Array([i0,i0+1,i0+2,i0,i0+2,i0+3]))
    else:
        indices.append_array(PackedInt32Array([i0,i0+2,i0+1,i0,i0+3,i0+2]))
