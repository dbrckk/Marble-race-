extends Node3D
## GPU-instanced track art independent of the physical track colliders.
const LEN := 12.0
const SLOPE := 0.085
const PLANK := Vector3(1.315, 0.65, LEN + 0.08)
const RAIL := Vector3(0.57, 1.26, 4.04)
const GROOVE := Vector3(0.018, 0.012, 5.0)
const ROAD_FLOOR := &"race_road_floor"
const Visuals = preload("res://scripts/visuals.gd")
# Half-width and height from foot to cap. The upright beside a marble spans
# the full collision width. Only the plinth, shoulder and crown recede.
const RAIL_PROFILES := [
    [Vector2(0.21,-0.63), Vector2(0.285,-0.54), Vector2(0.285,-0.27),
     Vector2(0.255,-0.23), Vector2(0.285,-0.18), Vector2(0.285,0.37),
     Vector2(0.27,0.56), Vector2(0.205,0.63)],
    [Vector2(0.22,-0.63), Vector2(0.285,-0.47), Vector2(0.285,-0.25),
     Vector2(0.23,-0.20), Vector2(0.285,-0.13), Vector2(0.285,0.31),
     Vector2(0.235,0.50), Vector2(0.125,0.63)],
    [Vector2(0.23,-0.63), Vector2(0.285,-0.56), Vector2(0.285,-0.29),
     Vector2(0.24,-0.24), Vector2(0.285,-0.17), Vector2(0.285,0.38),
     Vector2(0.23,0.46), Vector2(0.23,0.63)]
]
# Plinth, base, recessed inlay, lower bevel, panel, shoulder, crown and top.
const RAIL_COLORS := [
    [Color("#57392c"), Color("#875740"), Color("#3a2923"), Color("#a4724e"),
     Color("#986044"), Color("#68412d"), Color("#d4a76b"), Color("#e4c38c")],
    [Color("#253e58"), Color("#365573"), Color("#152e48"), Color("#74bacb"),
     Color("#4d859f"), Color("#76bdcc"), Color("#c0e8ed"), Color("#e1f4f3")],
    [Color("#302629"), Color("#534347"), Color("#271c22"), Color("#9b4f3a"),
     Color("#61515a"), Color("#342a31"), Color("#ab654c"), Color("#d58a65")]
]
static var _rail_meshes: Dictionary = {}
static var _rail_materials: Dictionary = {}

var planks: Array[Dictionary] = []
var rails: Array[Transform3D] = []
var grooves: Array[Transform3D] = []
var batches: Array[MultiMeshInstance3D] = []
var original_mesh_count := 0

func _basis(grade: float) -> Basis:
    return Basis(Vector3.RIGHT,-atan(grade))

func register_plank(at: Vector3, material_index: int, grade: float = SLOPE) -> void:
    planks.append({"at":at, "material":material_index, "grade":grade})
    original_mesh_count += 1

func register_rail(at: Vector3, grade: float = SLOPE) -> void:
    rails.append(Transform3D(_basis(grade),at))
    original_mesh_count += 1

func register_groove(at: Vector3, grade: float = SLOPE) -> void:
    grooves.append(Transform3D(_basis(grade),at))
    original_mesh_count += 1

func _batch(label_text: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
    if transforms.is_empty():
        return
    var geometry := MultiMesh.new()
    geometry.transform_format = MultiMesh.TRANSFORM_3D
    geometry.mesh = mesh
    geometry.instance_count = transforms.size()
    for i in range(transforms.size()):
        geometry.set_instance_transform(i,transforms[i])
    var art := MultiMeshInstance3D.new()
    art.name = label_text
    art.multimesh = geometry
    art.material_override = material
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(art)
    batches.append(art)

func _build_group(items: Array[Dictionary], materials: Array, mesh: Mesh, prefix: String) -> void:
    for index in range(materials.size()):
        var transforms: Array[Transform3D] = []
        for item in items:
            if int(item["material"]) == index:
                transforms.append(Transform3D(_basis(float(item["grade"])),item["at"]))
        _batch("%s_%02d" % [prefix,index],mesh,materials[index],transforms)

static func _rail_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        d: Vector3, color: Color) -> void:
    var normal := (c-a).cross(b-a).normalized()
    for position in [a,b,c,a,c,d]:
        surface.set_normal(normal)
        surface.set_color(color)
        surface.add_vertex(position)

static func _rail_mesh(biome: int) -> ArrayMesh:
    if _rail_meshes.has(biome):
        return _rail_meshes[biome]
    var profile: Array = RAIL_PROFILES[biome]
    var colors: Array = RAIL_COLORS[biome]
    var half_length := RAIL.z * 0.5
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in range(profile.size()-1):
        var lower: Vector2 = profile[index]
        var upper: Vector2 = profile[index+1]
        var near_lower := Vector3(lower.x,lower.y,half_length)
        var near_upper := Vector3(upper.x,upper.y,half_length)
        var far_lower := Vector3(lower.x,lower.y,-half_length)
        var far_upper := Vector3(upper.x,upper.y,-half_length)
        var mirror := Vector3(-1.0,1.0,1.0)
        _rail_quad(surface,near_lower,near_upper,far_upper,far_lower,colors[index])
        _rail_quad(surface,far_lower*mirror,far_upper*mirror,
            near_upper*mirror,near_lower*mirror,colors[index])
        _rail_quad(surface,near_lower,near_lower*mirror,
            near_upper*mirror,near_upper,colors[index].darkened(0.16))
        _rail_quad(surface,far_lower*mirror,far_lower,
            far_upper,far_upper*mirror,colors[index].darkened(0.16))
    var foot: Vector2 = profile.front()
    var crown: Vector2 = profile.back()
    _rail_quad(surface,Vector3(-foot.x,foot.y,-half_length),Vector3(-foot.x,foot.y,half_length),
        Vector3(foot.x,foot.y,half_length),Vector3(foot.x,foot.y,-half_length),colors[0])
    _rail_quad(surface,Vector3(-crown.x,crown.y,half_length),Vector3(-crown.x,crown.y,-half_length),
        Vector3(crown.x,crown.y,-half_length),Vector3(crown.x,crown.y,half_length),colors.back())
    surface.index()
    _rail_meshes[biome] = surface.commit()
    return _rail_meshes[biome]

static func _rail_material(biome: int) -> StandardMaterial3D:
    if not _rail_materials.has(biome):
        var finish := StandardMaterial3D.new()
        finish.vertex_color_use_as_albedo = true
        finish.vertex_color_is_srgb = true
        finish.roughness = [0.54,0.27,0.36][biome]
        finish.metallic = [0.12,0.10,0.42][biome]
        _rail_materials[biome] = finish
    return _rail_materials[biome]

func finish(wood_materials: Array, biome: int, groove_material: Material) -> void:
    var plank_mesh := Visuals.rounded_box(PLANK,0.078)
    var groove_mesh := Visuals.rounded_box(GROOVE,0.00144)
    _build_group(planks,wood_materials,plank_mesh,"OakPlank")
    _batch("ProfiledSafetyRails",_rail_mesh(biome),_rail_material(biome),rails)
    _batch("GrooveInlays",groove_mesh,groove_material,grooves)

func set_detail_quality(quality: int) -> void:
    # Keep the main track visible in every preset, suppress only small etchings.
    var detail := get_node_or_null("GrooveInlays")
    if is_instance_valid(detail):
        detail.visible = quality > 0

func get_batch_count() -> int:
    return batches.size()
