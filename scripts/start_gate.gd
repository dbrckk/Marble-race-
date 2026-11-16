extends Node3D
## Two open-sided starting towers with baked trim and six instanced lamps.
## The signal follows the existing countdown and has no authority over it.
const TRACK_Z := 2.25
const TOWER_X := 6.1
const READY := Color("#ffc481")
const GO := Color("#8bf3c5")
const DARK_LAMP := Color("#534550")
const SHELLS := [
    [Color("#925932"),Color("#e0b171"),Color("#493022"),Color("#754427")],
    [Color("#4f8da6"),Color("#c0f1f5"),Color("#213c59"),Color("#76bdd2")],
    [Color("#67525a"),Color("#d78c65"),Color("#30232e"),Color("#9b4b37")]
]
static var _frames: Dictionary = {}
static var _lamp_mesh: Mesh
static var _frame_material: StandardMaterial3D
static var _lamp_material: StandardMaterial3D

var lamps: MultiMesh
var signal_stage := -2

func setup(biome: int) -> void:
    if _frame_material == null:
        _frame_material = _colored_material()
        _frame_material.roughness = 0.46
        _frame_material.metallic = 0.22
        _lamp_material = _colored_material()
        _lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        var lens := CylinderMesh.new()
        lens.radial_segments = 8
        lens.rings = 0
        lens.height = 0.045
        lens.bottom_radius = 0.138
        lens.top_radius = 0.115
        _lamp_mesh = lens
    var towers := MeshInstance3D.new()
    towers.name = "StartTowers"
    towers.mesh = _frame(biome)
    towers.material_override = _frame_material
    towers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(towers)

    lamps = MultiMesh.new()
    lamps.transform_format = MultiMesh.TRANSFORM_3D
    lamps.use_colors = true
    lamps.mesh = _lamp_mesh
    lamps.instance_count = 6
    for i in range(lamps.instance_count):
        var side := -1.0 if i < 3 else 1.0
        var pose := Transform3D(Basis(Vector3.RIGHT,PI*0.5),
            Vector3(side*TOWER_X,3.17-float(i%3)*0.34,0.38))
        lamps.set_instance_transform(i,pose)
    var signals := MultiMeshInstance3D.new()
    signals.name = "SignalLamps"
    signals.multimesh = lamps
    signals.material_override = _lamp_material
    signals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(signals)
    set_signal(-1)

func set_signal(stage: int) -> void:
    if signal_stage == stage:
        return
    signal_stage = stage
    for i in range(lamps.instance_count):
        var color := DARK_LAMP
        if stage == 0:
            color = GO
        elif i%3 < stage:
            color = READY
        lamps.set_instance_color(i,color)

static func _colored_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.vertex_color_is_srgb = true
    return material

static func _frame(biome: int) -> ArrayMesh:
    if _frames.has(biome):
        return _frames[biome]
    var palette: Array = SHELLS[biome]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0,1.0]:
        # x values are outward from the lane for both towers.
        _extrude(surface,[-0.32,0.03, 0.61,0.03, 0.48,0.30, -0.27,0.30],
            side,0.0,0.68,palette[2])
        match biome:
            0:
                # Laminated bent timber, brass collars and inlaid diagonal grain.
                _extrude(surface,[-0.24,0.28, 0.44,0.28, 0.37,2.96, 0.10,3.76,
                        -0.22,3.78, -0.36,3.35, -0.12,2.55],
                    side,0.0,0.54,palette[0])
                _extrude(surface,[0.23,0.31, 0.51,0.31, 0.40,1.61, 0.17,2.14],
                    side,0.20,0.26,palette[3])
                _extrude(surface,[-0.28,0.38, 0.47,0.38, 0.46,0.49, -0.27,0.49],
                    side,0.0,0.60,palette[1])
                _extrude(surface,[-0.32,3.43, 0.20,3.43, 0.13,3.67, -0.22,3.67],
                    side,0.07,0.56,palette[1])
            1:
                # Faceted ice fins rising towards the lane.
                _extrude(surface,[-0.29,0.26, 0.33,0.26, 0.52,1.47, 0.23,2.97,
                        -0.29,4.10, -0.43,3.26, -0.34,1.76],
                    side,0.0,0.65,palette[0])
                _extrude(surface,[0.07,0.32, 0.57,0.37, 0.86,1.16, 0.64,2.22,
                        0.25,1.70],side,0.12,0.39,palette[3])
                _extrude(surface,[-0.36,3.30, -0.29,4.10, 0.23,2.97, -0.10,3.40],
                    side,0.08,0.53,palette[1])
                _extrude(surface,[-0.21,0.48, -0.08,0.56, 0.11,1.63, -0.04,2.03],
                    side,0.325,0.045,palette[1])
            2:
                # Buttressed furnace steel with open recesses between ribs.
                _extrude(surface,[-0.25,0.27, 0.39,0.27, 0.35,2.87, 0.23,3.76,
                        -0.26,3.76, -0.41,3.42, -0.26,2.43],
                    side,0.0,0.55,palette[0])
                _extrude(surface,[0.12,0.37, 0.71,0.37, 0.66,1.50, 0.31,2.32],
                    side,0.10,0.62,palette[2])
                for row in range(4):
                    var y := 0.64+float(row)*0.19
                    _extrude(surface,[0.34,y, 0.63,y+0.05, 0.62,y+0.13, 0.33,y+0.08],
                        side,0.41,0.06,palette[3])
                _extrude(surface,[-0.35,3.43, 0.27,3.43, 0.23,3.65, -0.26,3.65],
                    side,0.04,0.65,palette[1])
        _extrude(surface,[-0.19,2.31, 0.19,2.31, 0.23,2.46, 0.23,3.27,
                0.14,3.45, -0.14,3.45, -0.23,3.27, -0.23,2.46],
            side,0.33,0.074,palette[2])
    surface.index()
    _frames[biome] = surface.commit()
    return _frames[biome]

static func _extrude(surface: SurfaceTool, points: Array, side: float,
        z: float, thickness: float, paint: Color) -> void:
    var outline := PackedVector2Array()
    for i in range(0,points.size(),2):
        outline.append(Vector2(side*(TOWER_X+float(points[i])),float(points[i+1])))
    if Geometry2D.is_polygon_clockwise(outline):
        outline.reverse()
    var front := z+thickness*0.5
    var back := z-thickness*0.5
    var indices := Geometry2D.triangulate_polygon(outline)
    for i in range(0,indices.size(),3):
        var a := outline[indices[i]]
        var b := outline[indices[i+1]]
        var c := outline[indices[i+2]]
        _triangle(surface,Vector3(a.x,a.y,front),Vector3(c.x,c.y,front),
            Vector3(b.x,b.y,front),Vector3.BACK,paint)
        _triangle(surface,Vector3(a.x,a.y,back),Vector3(b.x,b.y,back),
            Vector3(c.x,c.y,back),Vector3.FORWARD,paint.darkened(0.11))
    for i in range(outline.size()):
        var a := outline[i]
        var b := outline[(i+1)%outline.size()]
        var normal := Vector3(b.y-a.y,a.x-b.x,0.0).normalized()
        var edge := paint.lerp(Color.WHITE,0.06) if normal.y > 0.15 else paint.darkened(0.18)
        _triangle(surface,Vector3(a.x,a.y,front),Vector3(b.x,b.y,front),
            Vector3(b.x,b.y,back),normal,edge)
        _triangle(surface,Vector3(a.x,a.y,front),Vector3(b.x,b.y,back),
            Vector3(a.x,a.y,back),normal,edge)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, normal: Vector3, paint: Color) -> void:
    for vertex in [a,b,c]:
        surface.set_color(paint)
        surface.set_normal(normal)
        surface.add_vertex(vertex)
