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

func _ready() -> void:
    _gold = _material(Color("#d4a86a"),0.26,0.65)
    _dark = _material(Color("#393b3c"),0.43,0.38)
    _wood = _material(Color("#7a5238"),0.68,0.0)
    _rail_accents()
    _modular_bracing()
    _flags_and_plates()

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func _decor_box(name_text: String, position: Vector3, size: Vector3, material: Material, tilt := false) -> MeshInstance3D:
    var piece := MeshInstance3D.new()
    piece.name = name_text
    var mesh := BoxMesh.new()
    mesh.size = size
    piece.mesh = mesh
    piece.material_override = material
    piece.position = position
    if tilt:
        piece.rotation.x = -atan(SLOPE)
    piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(piece)
    return piece

func _rail_accents() -> void:
    # One batch for all golden upper rail strips. They sit outside the contact surface.
    var metal := BoxMesh.new()
    metal.size = Vector3(0.08,0.055,LEN-0.07)
    metal.material = _gold
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = metal
    batch.instance_count = SEGMENTS*2
    var angle := Basis(Vector3.RIGHT,-atan(SLOPE))
    for section in range(SEGMENTS):
        var z := 8.0-float(section)*LEN
        for side in range(2):
            var pos := Vector3((-1.0 if side==0 else 1.0)*6.855,z*SLOPE+1.23,z)
            batch.set_instance_transform(section*2+side,Transform3D(angle,pos))
    var instance := MultiMeshInstance3D.new()
    instance.name = "GoldRailTopTrim_36Segments"
    instance.multimesh = batch
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _modular_bracing() -> void:
    # No extra geometry on the racing surface: all decoration is underneath / outside.
    for section in range(0,SEGMENTS,2):
        var z := 7.0 - section*LEN
        var y: float = z*SLOPE
        _decor_box("WalnutCrossBeam_%02d"%section,
            Vector3(0,y-1.6,z),Vector3(15.7,0.30,0.43),_wood)
        for side in [-1.0,1.0]:
            _decor_box("AngledCornerSupport_%d_%02d"%[int(side),section],
                Vector3(side*7.38,y-0.81,z),Vector3(0.19,1.6,0.36),_dark)
        # 5mm-like runners below the wood structure.
        _decor_box("UndersideGoldRivetRail_%02d"%section,
            Vector3(0,y-1.36,z),Vector3(14.9,0.045,0.13),_gold)
    for section in range(2,SEGMENTS,3):
        var z := 8.0 - section*LEN
        var y: float = z*SLOPE
        # Side module numbers add navigational texture at a distance.
        var label := Label3D.new()
        label.name = "SectionMarker_%02d" % section
        label.text = "%02d  /  %02d" % [section+1,SEGMENTS]
        label.font_size = 48
        label.pixel_size = 0.010
        label.modulate = Color("#f7deaf")
        label.outline_size = 5
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.position = Vector3(-7.84,y+1.82,z)
        add_child(label)

func _flags_and_plates() -> void:
    for i in range(3):
        var z: float = 8.0 - float([4,9,14][i])*LEN
        var y: float = z*SLOPE
        for side in [-1.0,1.0]:
            var x: float = side*7.45
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
            cloth.name = "AnimatedSilkPennant_%d" % i
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
        var y: float = z*SLOPE
        var color := COLORS[0] if n==0 else Color("#e7ca7e")
        var plate := _material(color,0.31,0.20)
        _decor_box("RaceLogoPlate",Vector3(0,y+2.95,z-0.03),
            Vector3(3.9,0.13,0.33),plate)
