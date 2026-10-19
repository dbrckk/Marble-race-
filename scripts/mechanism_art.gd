extends RefCounted
## Decorative clockwork meshes that follow the actual AnimatableBody3D colliders.
## The meshes have no physics shapes: no additional contacts or mobile GPU shadow maps.

static func _cylinder(radius: float, height: float, material: Material, name_text: String) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name_text
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = 24
    mi.mesh = shape
    mi.material_override = material
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi

static func _box(size: Vector3, material: Material, name_text: String) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.name = name_text
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = material
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi

static func stripe_arm(spoke: Node3D, size: Vector3, ink: Material) -> void:
    # Black molded warning inlays travel exactly with the actual motor arm.
    for side in [-1.0,1.0]:
        for j in range(3):
            var mark := _box(Vector3(0.16,0.014,size.z*0.84),ink,"InlaidHazardStripe")
            mark.position = Vector3(side*(size.x*0.5 - 0.55 - j*0.28),size.y*0.5+0.007,0.0)
            mark.rotation.y = 0.36
            spoke.add_child(mark)

static func decorate_spinner(pivot: Node3D, track: Node3D, brass: Material, graphite: Material) -> void:
    # Static bearing at floor level, under a moving brass spindle.
    var base := _cylinder(0.59,0.22,graphite,"MotorMount")
    base.position = pivot.position + Vector3(0,-0.60,0)
    track.add_child(base)
    var plinth := _cylinder(0.49,0.18,brass,"BearingBezel")
    plinth.position.y = -0.47
    pivot.add_child(plinth)
    var spindle := _cylinder(0.17,1.45,graphite,"SteelDriveShaft")
    spindle.position.y = 0.02
    pivot.add_child(spindle)
    var boss := _cylinder(0.50,0.17,brass,"PolishedCenterCap")
    boss.position.y = 0.39
    pivot.add_child(boss)
    var pin := _cylinder(0.26,0.035,graphite,"CenterBadge")
    pin.position.y = 0.49
    pivot.add_child(pin)
    for side in [-1.0,1.0]:
        var end := _cylinder(0.18,0.39,brass,"RoundedPaddleEnd")
        end.rotation.x = PI * 0.5
        end.position = Vector3(side*3.46,0,0)
        pivot.add_child(end)

static func decorate_hammer(hinge: Node3D, track: Node3D, brass: Material, graphite: Material) -> void:
    # Visible wall-mounted oscillating joint, arm and screws.
    var mount := _cylinder(0.47,0.33,graphite,"PendulumFloorBearing")
    mount.position = hinge.position + Vector3(0,-0.81,0)
    track.add_child(mount)
    var shaft := _cylinder(0.15,0.98,brass,"PendulumConnectingRod")
    shaft.position.y = -0.20
    hinge.add_child(shaft)
    var ring := _cylinder(0.37,0.17,graphite,"OscillatorAxis")
    ring.rotation.x = PI*0.5
    ring.position = Vector3(0,0,0.36)
    hinge.add_child(ring)
    var brass_cap := _cylinder(0.27,0.20,brass,"OscillatorCenterCap")
    brass_cap.rotation.x = PI*0.5
    brass_cap.position = Vector3(0,0,0.48)
    hinge.add_child(brass_cap)
    for side in [-1.0,1.0]:
        var bumper := _box(Vector3(0.24,0.62,0.75),graphite,"SoftHammerTip")
        bumper.position = Vector3(side*1.05,-0.45,0)
        hinge.add_child(bumper)
