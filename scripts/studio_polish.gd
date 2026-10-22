extends Node3D
## v1.6: photographic-track visual language, GPU-instanced and collision-free.
## Pale lane guides and pre-obstacle warnings are rendering hints only.
const SLOPE := 0.085
const COLORS := [
    Color("#eac48f"), Color("#8ddad4"), Color("#f4a798")
]
var quality := 1
var guide_nodes: Array[GeometryInstance3D] = []

func _ready() -> void:
    var stage := get_parent().get_parent()
    var tint: Color = COLORS[clampi(int(stage.selected_track),0,2)]
    _lane_lights(tint)
    _checkpoint_stripes(tint)
    _warning_stripes(stage,tint)
    set_quality(stage.graphics_quality)

func _batch(name_text: String, size: Vector3, positions: Array[Vector3],
    color: Color, emission: float) -> MultiMeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.34
    mat.metallic = 0.20
    mat.emission_enabled = emission > 0.0
    mat.emission = color
    mat.emission_energy_multiplier = emission
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = shape
    multi.instance_count = positions.size()
    var stage := get_parent().get_parent() as Node3D
    for i in range(positions.size()):
        # Marking orientation follows the same physical rolling slope.
        var basis := Basis(Vector3.RIGHT,-atan(
            stage.track_grade_at(positions[i].z)))
        multi.set_instance_transform(i,Transform3D(basis,positions[i]))
    var node := MultiMeshInstance3D.new()
    node.name = name_text
    node.multimesh = multi
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    guide_nodes.append(node)
    return node

func _track_center(z: float) -> float:
    var stage := get_parent().get_parent() as Node3D
    return stage.track_center_at(z) if is_instance_valid(stage) else 0.0

func _height(z: float) -> float:
    return (get_parent().get_parent() as Node3D).height_at(z)

func _lane_lights(tint: Color) -> void:
    # 80 narrow, intermittent inlaid brass markers at the safe central corridor.
    var points: Array[Vector3] = []
    for i in range(40):
        var z := 7.0-float(i)*4.8
        for side in [-1.0,1.0]:
            points.append(Vector3(side*3.95+_track_center(z),_height(z)+0.035,z))
    _batch("GuideStitch_80",Vector3(0.05,0.018,1.54),
        points,tint.darkened(0.19),0.13)

func _checkpoint_stripes(tint: Color) -> void:
    var points: Array[Vector3] = []
    for z in [-46.0,-106.0,-166.0]:
        points.append(Vector3(_track_center(z),_height(z)+0.05,z))
    _batch("PrecisionSplitStripe_3",Vector3(10.8,0.02,0.17),
        points,tint,0.37)

func _warning_stripes(stage: Node3D, tint: Color) -> void:
    var points: Array[Vector3] = []
    for warning in stage.hazard_beacons:
        var z: float = float(warning["z"])+2.6
        var x := -5.18 if warning["side"] == "LEFT" else 5.18
        for i in range(3):
            var ahead := z+float(i)*0.48
            points.append(Vector3(x+_track_center(ahead),_height(ahead)+0.052,ahead))
    _batch("WarningTactileApproach_84",Vector3(1.22,0.018,0.16),
        points,tint.lightened(0.2),0.24)

func set_quality(value: int) -> void:
    quality = clampi(value,0,2)
    # Keep checkpoint stripes always. No decorative marking costs in economy.
    for node in guide_nodes:
        if node.name == "PrecisionSplitStripe_3":
            node.visible = true
        else:
            node.visible = quality >= 1
