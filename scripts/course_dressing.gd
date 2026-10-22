extends Node3D
## Offline-designed dressing layer for v0.7. Everything here is decorative: no colliders.
## Shared material/MultiMesh reduces draw calls on low-power GLES Android devices.

const FLAG_SHADER = preload("res://shaders/race_flag.gdshader")
const SLOPE := 0.085
const SEGMENTS := 18
const LEN := 12.0
const COLORS := [Color("#d95b55"),Color("#f1bc5c"),Color("#59b6ab"),Color("#8299cf")]
var _gold: StandardMaterial3D
var _dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _flag_materials: Array[ShaderMaterial] = []
# Keep exact original box positions, dimensions and shared materials while
# combining the small *static* ornaments into distance-cullable GPU batches.
var static_boxes: Array[Dictionary] = []
var static_batches: Array[MultiMeshInstance3D] = []

func _ready() -> void:
    _gold = _material(Color("#d4a86a"),0.26,0.65)
    _dark = _material(Color("#393b3c"),0.43,0.38)
    _wood = _material(Color("#7a5238"),0.68,0.0)
    _rail_accents()
    _modular_bracing()
    _flags_and_plates()
    _batch_static_boxes()

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func _decor_box(name_text: String, position: Vector3, size: Vector3,
    material: Material, tilt := false) -> void:
    # Legacy geometry was one MeshInstance3D per box, including rail bracing
    # and flags. Record an identical transform; never make 44 draw objects.
    static_boxes.append({
        "label":name_text, "position":position, "size":size,
        "material":material, "tilt":tilt
    })

func _batch_static_boxes() -> void:
    # Three ~72m chunks preserve frustum/distance culling. One huge multimesh
    # over the whole 216m course would defeat the camera's distance clipping.
    var groups: Dictionary = {}
    var ordered_keys: Array[String] = []
    var unit_cube := BoxMesh.new()
    unit_cube.size = Vector3.ONE
    for box in static_boxes:
        var material: Material = box["material"]
        var location: Vector3 = box["position"]
        var section: int = clampi(int(floor((8.0-location.z)/72.0)),0,2)
        var key: String = "%d:%d" % [material.get_instance_id(),section]
        if not groups.has(key):
            groups[key] = {"material":material,"transforms":[]}
            ordered_keys.append(key)
        var axis := Basis(Vector3.RIGHT,-atan(_grade(location.z))) if bool(box["tilt"]) else Basis()
        var basis: Basis = axis.scaled(box["size"])
        var entries: Array = groups[key]["transforms"]
        entries.append(Transform3D(basis,location))
    for key in ordered_keys:
        var group: Dictionary = groups[key]
        var transforms: Array = group["transforms"]
        var mesh := MultiMesh.new()
        mesh.transform_format = MultiMesh.TRANSFORM_3D
        mesh.mesh = unit_cube
        mesh.instance_count = transforms.size()
        for i in range(transforms.size()):
            mesh.set_instance_transform(i,transforms[i])
        var batch := MultiMeshInstance3D.new()
        batch.name = "StaticDecorBatch_%02d" % static_batches.size()
        batch.multimesh = mesh
        batch.material_override = group["material"]
        batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(batch)
        static_batches.append(batch)

func static_batch_instance_count() -> int:
    var total := 0
    for batch in static_batches:
        total += batch.multimesh.instance_count
    return total

func _center(z: float) -> float:
    var stage := get_parent().get_parent() as Node3D
    return stage.track_center_at(z) if is_instance_valid(stage) else 0.0

func _height(z: float) -> float:
    var stage := get_parent().get_parent() as Node3D
    return stage.height_at(z)

func _grade(z: float) -> float:
    var stage := get_parent().get_parent() as Node3D
    return stage.track_grade_at(z)

func _rail_accents() -> void:
    # One batch for all golden upper rail strips. They sit outside the contact surface.
    var metal := BoxMesh.new()
    metal.size = Vector3(0.08,0.055,LEN-0.07)
    metal.material = _gold
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = metal
    batch.instance_count = SEGMENTS*2
    for section in range(SEGMENTS):
        var z := 8.0-float(section)*LEN
        var angle := Basis(Vector3.RIGHT,-atan(_grade(z)))
        for side in range(2):
            var pos := Vector3((-1.0 if side==0 else 1.0)*6.855+_center(z),_height(z)+1.23,z)
            # Suppress decorative rail trim at the real fork / merger.
            var portal_side: int = -1 if side == 0 else 1
            var guide: Basis = angle
            if section in [5,9] and portal_side == [1,-1,1][clampi(int(get_parent().get_parent().selected_track),0,2)]:
                guide = Basis().scaled(Vector3.ZERO)
            batch.set_instance_transform(section*2+side,Transform3D(guide,pos))
    var instance := MultiMeshInstance3D.new()
    instance.name = "GoldRailTopTrim_36Segments"
    instance.multimesh = batch
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _modular_bracing() -> void:
    # No extra geometry on the racing surface: all decoration is underneath / outside.
    for section in range(0,SEGMENTS,2):
        var z := 7.0 - section*LEN
        var y: float = _height(z)
        _decor_box("WalnutCrossBeam_%02d"%section,
            Vector3(_center(z),y-1.6,z),Vector3(15.7,0.30,0.43),_wood)
        for side in [-1.0,1.0]:
            _decor_box("AngledCornerSupport_%d_%02d"%[int(side),section],
                Vector3(side*7.38+_center(z),y-0.81,z),Vector3(0.19,1.6,0.36),_dark)
        # 5mm-like runners below the wood structure.
        _decor_box("UndersideGoldRivetRail_%02d"%section,
            Vector3(_center(z),y-1.36,z),Vector3(14.9,0.045,0.13),_gold)
    for section in range(2,SEGMENTS,3):
        var z := 8.0 - section*LEN
        var y: float = _height(z)
        # Side module numbers add navigational texture at a distance.
        var label := Label3D.new()
        label.name = "SectionMarker_%02d" % section
        label.text = "%02d  /  %02d" % [section+1,SEGMENTS]
        label.font_size = 48
        label.pixel_size = 0.010
        label.modulate = Color("#f7deaf")
        label.outline_size = 5
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.position = Vector3(-7.84+_center(z),y+1.82,z)
        add_child(label)

func _flags_and_plates() -> void:
    for i in range(3):
        var z: float = 8.0 - float([4,9,14][i])*LEN
        var y: float = _height(z)
        for side in [-1.0,1.0]:
            var x: float = side*7.45+_center(z)
            _decor_box("FlagStaff",Vector3(x,y+2.82,z),
                Vector3(0.063,3.0,0.072),_dark)
            var pin := MeshInstance3D.new()
            var globe := SphereMesh.new()
            globe.radius = 0.115
            globe.height = 0.23
            globe.radial_segments = 12
            globe.rings = 5
            pin.mesh = globe
            pin.position = Vector3(x,y+4.38,z)
            pin.material_override = _gold
            pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(pin)
            var cloth := MeshInstance3D.new()
            cloth.name = "AnimatedSilkPennant_%d_%s" % [i, "L" if side < 0.0 else "R"]
            var cloth_plane := PlaneMesh.new()
            cloth_plane.size = Vector2(1.16,0.68)
            cloth_plane.subdivide_width = 12
            cloth_plane.subdivide_depth = 6
            cloth.mesh = cloth_plane
            var mat := ShaderMaterial.new()
            mat.shader = FLAG_SHADER
            mat.set_shader_parameter("cloth_color",COLORS[(i+(0 if side>0 else 2))%COLORS.size()])
            mat.set_shader_parameter("phase_offset",float(i)*1.29+side*0.6)
            cloth.material_override = mat
            cloth.position = Vector3(x+side*0.61,y+3.73,z)
            cloth.rotation.x = -PI*0.5
            if side<0.0:
                cloth.rotation.y = PI
            cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(cloth)
            _flag_materials.append(mat)
    # Distinct lacquer plate on start and finish; keeps tracks readable from camera.
    for n in range(2):
        var z := 2.25 if n==0 else -195.1
        var y: float = _height(z)
        var color := COLORS[0] if n==0 else Color("#e7ca7e")
        var plate := _material(color,0.31,0.20)
        _decor_box("RaceLogoPlate",Vector3(_center(z),y+2.95,z-0.03),
            Vector3(3.9,0.13,0.33),plate)
