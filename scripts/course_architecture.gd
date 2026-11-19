extends RefCounted
## Baked, reusable silhouettes for the elevated crossing and main-road vaults.
const VISUALS = preload("res://scripts/visuals.gd")
const PALETTES := [
    [Color("#a56b3c"),Color("#5d382a"),Color("#f1bf80")],
    [Color("#3f829e"),Color("#25526e"),Color("#b7f2f7")],
    [Color("#90848b"),Color("#655965"),Color("#f2aa75")]
]
static var _portals: Dictionary = {}
static var _piers: Dictionary = {}
static var _trusses: Dictionary = {}
static var _vault_ribs: Dictionary = {}
static var _canopy_bays: Dictionary = {}
static var _materials: Dictionary = {}

static func material(biome: int) -> StandardMaterial3D:
    if not _materials.has(biome):
        var paint := StandardMaterial3D.new()
        paint.vertex_color_use_as_albedo = true
        paint.vertex_color_is_srgb = true
        # Keep the sculpted piers consistent with the adjacent passage roofs:
        # timber stays matte, ice has a restrained clearcoat, and foundry
        # metal reflects as brushed alloy. No additional geometry or passes.
        paint.roughness = [0.69,0.28,0.43][biome]
        paint.metallic = [0.10,0.12,0.52][biome]
        if biome == 1:
            paint.clearcoat_enabled = true
            paint.clearcoat = 0.42
            paint.clearcoat_roughness = 0.16
        _materials[biome] = paint
    return _materials[biome]

static func portal(biome: int, half_span: float) -> ArrayMesh:
    var key := Vector2(biome,half_span)
    if _portals.has(key):
        return _portals[key]
    var surface := _surface()
    var palette: Array = PALETTES[biome]
    for side in [-1.0,1.0]:
        # Both wings stay outside the centreline even at camera height.
        var axis := Vector2(side,1.0)
        var offset := Vector2(side*half_span,0.32)
        match biome:
            0:
                _profile(surface,[-0.29,0, 0.32,0, 0.27,1.82, 0.05,2.97,
                    -0.72,3.43, -0.95,3.18, -0.37,2.67, -0.10,1.68],
                    axis,offset,0.0,0.48,palette[0])
                _profile(surface,[-0.18,1.66, -0.02,1.75, -0.25,2.70,
                    -0.83,3.22, -0.77,3.29, -0.17,2.80],
                    axis,offset,0.25,0.04,palette[1])
                _profile(surface,[-0.08,2.70, 0.15,2.79, 0.22,2.63, -0.04,2.54],
                    axis,offset,0.0,0.52,palette[2])
                # Exposed timber grain: a carved vertical inset and a
                # contrasting knee brace baked into the portal silhouette.
                _profile(surface,[-0.17,0.42, -0.09,0.42, -0.14,1.52,
                    -0.23,1.52],axis,offset,0.246,0.025,palette[1])
                _profile(surface,[-0.30,1.88, -0.17,1.94, -0.66,2.99,
                    -0.76,3.04],axis,offset,0.249,0.028,palette[2])
            1:
                _profile(surface,[-0.27,0, 0.37,0, 0.51,1.03, 0.24,2.49,
                    -0.53,3.83, -0.46,2.89, -0.24,1.82],
                    axis,offset,0.0,0.50,palette[0])
                _profile(surface,[0.20,0.03, 0.55,0.50, 0.78,1.75,
                    0.41,1.51, 0.05,0.75],axis,offset,-0.05,0.46,palette[1])
                _profile(surface,[-0.53,3.83, -0.46,2.89, -0.11,2.04,
                    -0.15,2.63],axis,offset,0.262,0.035,palette[2])
                # Faceted ice seams: opaque, vertex-painted frost facets.
                _profile(surface,[-0.23,0.62, -0.11,0.89, -0.16,1.63,
                    -0.30,1.40],axis,offset,0.254,0.026,palette[2])
                _profile(surface,[-0.39,2.58, -0.25,2.36, -0.48,3.34,
                    -0.56,3.48],axis,offset,0.259,0.024,palette[1])
            2:
                _profile(surface,[-0.34,0, 0.42,0, 0.38,1.99, 0.58,2.55,
                    0.57,3.10, 0.29,3.52, -0.83,3.52, -0.92,3.13,
                    -0.29,2.86, -0.18,2.05],axis,offset,0.0,0.68,palette[1])
                _profile(surface,[-0.88,3.15, -0.66,3.43, 0.48,3.43,
                    0.59,3.16, 0.28,2.97, -0.27,2.97],
                    axis,offset,0.03,0.76,palette[0])
                # Recessed alloy strut and a bright warning cap are baked
                # into the same vertex-colored portal mesh.
                _profile(surface,[-0.62,2.78, -0.52,2.84, 0.21,2.12,
                    0.11,2.04],axis,offset,0.39,0.035,palette[2])
                _profile(surface,[-0.80,3.44, 0.44,3.44, 0.39,3.51,
                    -0.76,3.51],axis,offset,0.415,0.03,palette[2])
                for row in range(3):
                    var y := 0.67+float(row)*0.32
                    _profile(surface,[0.05,y, 0.34,y+0.10, 0.34,y+0.19, 0.05,y+0.09],
                        axis,offset,0.35,0.035,palette[2])
        _profile(surface,[-0.32,-0.05, 0.42,-0.05, 0.31,0.13, -0.28,0.13],
            axis,offset,0.0,0.79,palette[1])
    surface.index()
    _portals[key] = surface.commit()
    return _portals[key]

static func pier(biome: int) -> ArrayMesh:
    if _piers.has(biome):
        return _piers[biome]
    var surface := _surface()
    var palette: Array = PALETTES[biome]
    match biome:
        0:
            _profile(surface,[-0.50,-0.50, 0.50,-0.50, 0.24,-0.10, 0.43,0.50,
                -0.43,0.50, -0.24,-0.10],Vector2.ONE,Vector2.ZERO,0.0,0.72,palette[0])
            _profile(surface,[-0.41,0.32, 0.41,0.32, 0.45,0.37, -0.45,0.37],
                Vector2.ONE,Vector2.ZERO,0.0,0.85,palette[2])
            _profile(surface,[-0.31,-0.34, -0.23,-0.34, 0.27,0.19,
                0.18,0.19],Vector2.ONE,Vector2.ZERO,0.376,0.026,palette[1])
        1:
            _profile(surface,[-0.34,-0.50, 0.31,-0.50, 0.50,-0.16, 0.29,0.50,
                -0.36,0.50, -0.50,0.19],Vector2.ONE,Vector2.ZERO,0.0,0.83,palette[0])
            _profile(surface,[-0.36,0.50, 0.29,0.50, 0.04,0.25, -0.27,0.17],
                Vector2.ONE,Vector2.ZERO,0.414,0.035,palette[2])
            _profile(surface,[-0.29,-0.23, -0.16,-0.15, 0.11,0.34,
                0.02,0.26],Vector2.ONE,Vector2.ZERO,0.44,0.025,palette[2])
        2:
            for side in [-1.0,1.0]:
                _profile(surface,[0.11,-0.50, 0.50,-0.50, 0.39,0.50, 0.10,0.50],
                    Vector2(side,1.0),Vector2.ZERO,0.0,0.78,palette[0])
            _profile(surface,[-0.48,-0.42, -0.28,-0.46, 0.45,0.29, 0.43,0.39],
                Vector2.ONE,Vector2.ZERO,0.0,0.54,palette[2])
            _profile(surface,[-0.35,-0.31, -0.25,-0.31, 0.32,0.32,
                0.23,0.32],Vector2.ONE,Vector2.ZERO,0.406,0.025,palette[1])
    surface.index()
    _piers[biome] = surface.commit()
    return _piers[biome]

static func truss(biome: int) -> ArrayMesh:
    if _trusses.has(biome):
        return _trusses[biome]
    var surface := _surface()
    var palette: Array = PALETTES[biome]
    match biome:
        0:
            _profile(surface,[-0.50,0.50, 0.50,0.50, 0.45,0.08, 0.34,-0.10,
                0.12,-0.41, -0.12,-0.41, -0.34,-0.10, -0.45,0.08],
                Vector2.ONE,Vector2.ZERO,0.0,0.83,palette[0])
            _profile(surface,[-0.34,0.29, -0.27,0.34, 0.27,-0.25,
                0.19,-0.30],Vector2.ONE,Vector2.ZERO,0.43,0.024,palette[2])
        1:
            _profile(surface,[-0.50,0.49, 0.50,0.49, 0.37,0.03, 0.17,-0.24,
                0.02,-0.50, -0.20,-0.18, -0.36,-0.29],
                Vector2.ONE,Vector2.ZERO,0.0,0.91,palette[0])
            _profile(surface,[-0.34,0.30, -0.22,0.31, 0.12,-0.21,
                0.03,-0.27],Vector2.ONE,Vector2.ZERO,0.47,0.023,palette[2])
        2:
            _profile(surface,[-0.50,0.50, 0.50,0.50, 0.50,0.16, 0.31,-0.12,
                0.31,0.04, -0.31,0.04, -0.31,-0.12, -0.50,0.16],
                Vector2.ONE,Vector2.ZERO,0.0,0.96,palette[0])
            _profile(surface,[-0.39,0.10, -0.33,0.20, 0.39,-0.42, 0.34,-0.50],
                Vector2.ONE,Vector2.ZERO,0.0,0.70,palette[2])
            _profile(surface,[-0.43,0.31, 0.43,0.31, 0.43,0.38,
                -0.43,0.38],Vector2.ONE,Vector2.ZERO,0.37,0.024,palette[2])
    surface.index()
    _trusses[biome] = surface.commit()
    return _trusses[biome]

static func vault_rib(biome: int, width: float) -> ArrayMesh:
    var key := Vector2(biome,width)
    if _vault_ribs.has(key):
        return _vault_ribs[key]
    var surface := _surface()
    var scale := Vector2(width,0.34)
    match biome:
        0:
            # Deep timber beam with bevels at the exposed ends and a copper strap.
            _profile(surface,[-0.50,-0.19, -0.40,-0.45, 0.40,-0.45, 0.50,-0.19,
                0.50,0.25, 0.44,0.46, -0.44,0.46, -0.50,0.25],
                scale,Vector2.ZERO,0.0,0.56,Color.WHITE)
            for end in [-0.32,0.32]:
                _profile(surface,[-0.045,-0.50, 0.045,-0.50, 0.045,0.50, -0.045,0.50],
                    scale,Vector2(end*width,0.0),0.0,0.62,Color("#dfb381"))
        1:
            # The shorter prismatic face under the ridge catches light from the lane.
            _profile(surface,[-0.50,0.18, -0.28,-0.50, 0.28,-0.50, 0.50,0.18,
                0.36,0.38, -0.36,0.38],
                scale,Vector2.ZERO,0.0,0.62,Color("#badbe9"))
            _profile(surface,[-0.43,0.20, -0.18,0.50, 0.18,0.50, 0.43,0.20],
                scale,Vector2.ZERO,0.0,0.44,Color.WHITE)
        2:
            # An exposed web between two flanges gives the steel rib a recessed edge.
            _profile(surface,[-0.47,-0.50, 0.47,-0.50, 0.50,-0.24, -0.50,-0.24],
                scale,Vector2.ZERO,0.0,0.62,Color("#b1a19b"))
            _profile(surface,[-0.44,-0.24, 0.44,-0.24, 0.44,0.23, -0.44,0.23],
                scale,Vector2.ZERO,0.0,0.32,Color("#a79992"))
            _profile(surface,[-0.50,0.23, 0.50,0.23, 0.47,0.50, -0.47,0.50],
                scale,Vector2.ZERO,0.0,0.62,Color.WHITE)
    surface.index()
    _vault_ribs[key] = surface.commit()
    return _vault_ribs[key]

static func canopy_bay(biome: int, width: float) -> ArrayMesh:
    var key := Vector2(biome,width)
    if _canopy_bays.has(key):
        return _canopy_bays[key]
    var surface := _surface()
    var scale := Vector2(width,0.10)
    match biome:
        0:
            # Three longitudinal planks expose two narrow seams to the sky.
            var plank_scale := Vector2(width*0.31,0.10)
            var finishes := [Color("#e5c8a9"),Color.WHITE,Color("#e5c8a9")]
            for plank in range(finishes.size()):
                _profile(surface,[-0.50,-0.32, -0.43,-0.50, 0.43,-0.50, 0.50,-0.32,
                    0.50,0.32, 0.43,0.50, -0.43,0.50, -0.50,0.32],
                    plank_scale,Vector2(float(plank-1)*width*0.345,0.0),
                    0.0,3.0,finishes[plank])
        1:
            _profile(surface,[-0.50,-0.12, -0.29,-0.50, 0.18,-0.37, 0.50,-0.08,
                0.40,0.10, 0.10,0.50, -0.20,0.36, -0.43,0.11],
                scale,Vector2.ZERO,0.0,3.0,Color("#dfedf5"))
        2:
            # Folded steel with three stiffening channels along the span of each bay.
            _profile(surface,[-0.50,-0.50, 0.50,-0.50, 0.50,-0.14,
                0.39,-0.14, 0.34,0.50, 0.26,0.50, 0.21,-0.14,
                0.09,-0.14, 0.04,0.50, -0.04,0.50, -0.09,-0.14,
                -0.21,-0.14, -0.26,0.50, -0.34,0.50, -0.39,-0.14, -0.50,-0.14],
                scale,Vector2.ZERO,0.0,3.0,Color.WHITE)
    surface.index()
    _canopy_bays[key] = surface.commit()
    return _canopy_bays[key]

static func _surface() -> SurfaceTool:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    return surface

static func _profile(surface: SurfaceTool, points: Array, axis: Vector2, offset: Vector2,
        z: float, thickness: float, paint: Color) -> void:
    var outline := PackedVector2Array()
    for i in range(0,points.size(),2):
        outline.append(offset+Vector2(points[i],points[i+1])*axis)
    VISUALS.append_extruded_profile(surface,outline,z,thickness,paint)
