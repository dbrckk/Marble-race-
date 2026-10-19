extends Node3D
## Static track rendering optimized into 12 GPU batches, independently of the
## physical track colliders. Same source materials/meshes as the original course.
const LEN := 12.0
const SLOPE := 0.085
const PLANK := Vector3(1.315, 0.65, LEN + 0.08)
const RAIL := Vector3(0.57, 1.26, 4.04)
const GROOVE := Vector3(0.018, 0.012, 5.0)
const Visuals = preload("res://scripts/visuals.gd")

var planks: Array[Dictionary] = []
var rails: Array[Dictionary] = []
var grooves: Array[Transform3D] = []
var batches: Array[MultiMeshInstance3D] = []
var original_mesh_count := 0

func _basis() -> Basis:
    return Basis(Vector3.RIGHT, -atan(SLOPE))

func register_plank(at: Vector3, material_index: int) -> void:
    planks.append({"at":at, "material":material_index})
    original_mesh_count += 1

func register_rail(at: Vector3, material_index: int) -> void:
    rails.append({"at":at, "material":material_index})
    original_mesh_count += 1

func register_groove(at: Vector3) -> void:
    grooves.append(Transform3D(_basis(),at))
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
    var basis := _basis()
    for index in range(materials.size()):
        var transforms: Array[Transform3D] = []
        for item in items:
            if int(item["material"]) == index:
                transforms.append(Transform3D(basis,item["at"]))
        _batch("%s_%02d" % [prefix,index],mesh,materials[index],transforms)

func finish(wood_materials: Array, rail_materials: Array, groove_material: Material) -> void:
    var plank_mesh := Visuals.rounded_box(PLANK,0.078)
    var rail_mesh := Visuals.rounded_box(RAIL,0.0684)
    var groove_mesh := Visuals.rounded_box(GROOVE,0.00144)
    _build_group(planks,wood_materials,plank_mesh,"OakPlank")
    _build_group(rails,rail_materials,rail_mesh,"PaintedSafetyRail")
    _batch("GrooveInlays",groove_mesh,groove_material,grooves)

func set_detail_quality(quality: int) -> void:
    # Keep the main track visible in every preset, suppress only small etchings.
    var detail := get_node_or_null("GrooveInlays")
    if is_instance_valid(detail):
        detail.visible = quality > 0

func get_batch_count() -> int:
    return batches.size()
