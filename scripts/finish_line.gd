extends MeshInstance3D
## The timing stripe and two lateral landmarks share one render surface.
const Visuals = preload("res://scripts/visuals.gd")
const SIDE_OFFSET := 6.45
const WOODWORKS_SIGN_Y := 3.23
const PALETTES := [
    [Color("#815338"),Color("#c28650"),Color("#f2c172")],
    [Color("#2a536d"),Color("#54a2c5"),Color("#a4eff7")],
    [Color("#40323e"),Color("#915141"),Color("#ffae70")]
]
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

func setup(biome: int, grade: float) -> void:
    if not _meshes.has(biome):
        _meshes[biome] = _build(biome)
    mesh = _meshes[biome]
    if _material == null:
        _material = StandardMaterial3D.new()
        _material.vertex_color_use_as_albedo = true
        _material.vertex_color_is_srgb = true
        _material.roughness = 0.48
        _material.metallic = 0.19
    material_override = _material
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    rotation.x = -atan(grade)
    for side in [-1.0,1.0]:
        var sign := Label3D.new()
        sign.text = "FINISH"
        sign.font_size = 52
        sign.pixel_size = 0.012 if biome == 1 else 0.015
        sign.outline_size = 7
        sign.position = Vector3(side*SIDE_OFFSET,[WOODWORKS_SIGN_Y,2.42,3.45][biome],0.41)
        sign.modulate = Color("#fff2da")
        add_child(sign)

static func _build(biome: int) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var palette: Array = PALETTES[biome]
    var tile_depth := 0.52 if biome == 0 else 0.38
    for row in range(2):
        var z := (float(row)-0.5)*tile_depth
        for tile in range(12):
            var x := (float(tile)-5.5)*1.06
            var tint := Color("#f7edd5") if (tile+row)%2 == 0 else Color("#212833")
            _box(surface,Vector3(x,0.043,z),Vector3(1.06,0.036,tile_depth),tint)
    for side in [-1.0,1.0]:
        var x: float = side*SIDE_OFFSET
        _box(surface,Vector3(x,0.18,0.0),Vector3(0.91,0.36,0.84),palette[0])
        var sign_y := WOODWORKS_SIGN_Y if biome == 0 else 2.43
        _box(surface,Vector3(x,sign_y,0.02),Vector3(1.58,0.66,0.65),palette[0])
        _box(surface,Vector3(x,sign_y+0.39,0.02),Vector3(1.48,0.13,0.63),palette[2])
        match biome:
            0:
                _box(surface,Vector3(x,1.66,0),Vector3(0.48,2.97,0.55),palette[1])
                _box(surface,Vector3(x+side*0.22,1.47,0),Vector3(0.28,2.29,0.42),palette[0],-side*0.21)
                for y in [0.52,1.52,2.55]:
                    _box(surface,Vector3(x,y,0.0),Vector3(0.60,0.12,0.61),palette[2])
                for tile in range(6):
                    var tint := Color("#f8e4b5") if tile%2 == 0 else Color("#2a2020")
                    _box(surface,Vector3(x+(float(tile)-2.5)*0.22,3.78,0.20),Vector3(0.22,0.20,0.13),tint)
            1:
                _box(surface,Vector3(x,1.23,0),Vector3(0.54,2.11,0.60),palette[1],side*0.10)
                _box(surface,Vector3(x+side*0.30,1.65,-0.08),Vector3(0.32,2.80,0.46),palette[2],-side*0.22)
                _box(surface,Vector3(x-side*0.28,1.13,0.16),Vector3(0.20,1.86,0.35),palette[1],side*0.28)
            2:
                _box(surface,Vector3(x,1.21,0),Vector3(0.56,2.13,0.60),palette[1])
                _box(surface,Vector3(x+side*0.38,1.07,0),Vector3(0.29,1.67,0.52),palette[0],-side*0.27)
                for y in [0.73,1.00,1.27,1.54,1.81]:
                    _box(surface,Vector3(x,y,0.33),Vector3(0.38,0.10,0.06),palette[2],0.16)
                _box(surface,Vector3(x,3.07,0.0),Vector3(0.53,0.82,0.52),palette[1])
                _box(surface,Vector3(x,3.45,0.01),Vector3(1.58,0.70,0.65),palette[0])
                _box(surface,Vector3(x,3.86,0.02),Vector3(1.51,0.15,0.63),palette[2])
                for tile in range(6):
                    var stripe := Color("#ffe5a9") if tile%2 == 0 else Color("#2c2531")
                    _box(surface,Vector3(x+(float(tile)-2.5)*0.22,4.05,0.27),Vector3(0.22,0.27,0.20),stripe)
    surface.index()
    return surface.commit()

static func _box(surface: SurfaceTool, at: Vector3, size: Vector3, tint: Color,
        angle := 0.0) -> void:
    var source: Mesh
    if size.y < 0.15:
        var box := BoxMesh.new()
        box.size = size
        source = box
    else:
        source = Visuals.rounded_box(size,0.065)
    var arrays := source.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    var axis := Basis(Vector3.BACK,angle)
    for index in indices:
        surface.set_color(tint)
        surface.set_normal(axis*normals[index])
        surface.add_vertex(at+axis*vertices[index])
