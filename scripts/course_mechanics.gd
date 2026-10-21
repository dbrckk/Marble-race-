extends Node3D
## Deterministic biome-specific racing hazards and optional racing-line bonuses.
## All physical changes run offline or on the dedicated server, never on clients.
## Unlike rare items, natural hazards and surface zones affect AI as well.
const ZONE_Z := [-22.0, -61.0, -98.0, -139.0, -168.0]
const ZONE_X := [-3.3, 3.3, -3.3, 3.3, -3.3]
const TRACK_COLORS := [Color("#e6b56e"), Color("#8beaff"), Color("#ff8759")]
const ZONE_WIDTH := 3.4
const ZONE_LENGTH := 6.5
const LAVA_CYCLE := 4.8
const LAVA_ACTIVE := 1.35
var game: Node3D
var track_id := 0
var zones: Array[Node3D] = []
var active_marks: Array[MeshInstance3D] = []
var collected: Dictionary = {}
var last_burst: Dictionary = {}
var race_clock := 0.0

func setup(owner: Node3D, course_id: int) -> void:
    game = owner
    track_id = clampi(course_id,0,2)
    for i in range(ZONE_Z.size()):
        var zone := Node3D.new()
        var kind := _kind()
        zone.name = "%sZone_%02d" % [kind.capitalize(),i]
        var z: float = ZONE_Z[i]
        var x: float = ZONE_X[(i+track_id)%ZONE_X.size()]
        zone.position = Vector3(x+game.track_center_at(z),game.height_at(z)+0.035,z)
        add_child(zone)
        zones.append(zone)
        if track_id == 2:
            _vent_visual(zone,i)
        else:
            _ribbon_visual(zone,i)
            if track_id == 1:
                _ice_collision(zone)
    reset_round()

func _kind() -> String:
    return ["speed","ice","vent"][track_id]

func _ribbon_visual(zone: Node3D, index: int) -> void:
    var art := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(ZONE_WIDTH,0.055,ZONE_LENGTH)
    art.mesh = mesh
    art.rotation.x = -atan(0.085)
    art.position.y = 0.035
    var material := StandardMaterial3D.new()
    material.albedo_color = TRACK_COLORS[track_id]
    material.metallic = 0.25
    material.roughness = 0.22 if track_id == 1 else 0.52
    material.emission_enabled = true
    material.emission = TRACK_COLORS[track_id]
    material.emission_energy_multiplier = 0.32
    art.material_override = material
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(art)
    for stripe in range(3):
        var stripe_art := MeshInstance3D.new()
        var line := BoxMesh.new()
        line.size = Vector3(ZONE_WIDTH-0.55,0.025,0.18)
        stripe_art.mesh = line
        stripe_art.position = Vector3(0.0,0.09,2.15-float(stripe)*2.12)
        stripe_art.rotation.x = -atan(0.085)
        var detail := StandardMaterial3D.new()
        detail.albedo_color = Color("#f5faf0") if track_id == 1 else Color("#fff2b6")
        detail.emission_enabled = true
        detail.emission = detail.albedo_color
        detail.emission_energy_multiplier = 0.28
        stripe_art.material_override = detail
        stripe_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        zone.add_child(stripe_art)

func _ice_collision(zone: Node3D) -> void:
    # A very shallow, low-friction physical slab; no tall edge blocking 40 racers.
    var surface := StaticBody3D.new()
    surface.name = "LowFrictionIce"
    surface.rotation.x = -atan(0.085)
    surface.position.y = 0.024
    var friction := PhysicsMaterial.new()
    friction.friction = 0.04
    friction.rough = false
    friction.bounce = 0.02
    surface.physics_material_override = friction
    var hit := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(ZONE_WIDTH,0.065,ZONE_LENGTH)
    hit.shape = shape
    surface.add_child(hit)
    zone.add_child(surface)

func _vent_visual(zone: Node3D, index: int) -> void:
    var rim := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 1.0
    torus.outer_radius = 1.22
    torus.rings = 24
    torus.ring_segments = 8
    rim.mesh = torus
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("#4b4045")
    metal.metallic = 0.72
    metal.roughness = 0.38
    rim.material_override = metal
    rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(rim)
    var flame := MeshInstance3D.new()
    flame.name = "FlameWarning"
    var cone := CylinderMesh.new()
    cone.top_radius = 0.12
    cone.bottom_radius = 0.82
    cone.height = 1.1
    cone.radial_segments = 9
    flame.mesh = cone
    flame.position.y = 0.56
    var molten := StandardMaterial3D.new()
    molten.albedo_color = Color("#ff9752")
    molten.emission_enabled = true
    molten.emission = Color("#ff612c")
    molten.emission_energy_multiplier = 2.0
    flame.material_override = molten
    flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    flame.visible = false
    zone.add_child(flame)
    active_marks.append(flame)

func reset_round() -> void:
    collected.clear()
    last_burst.clear()
    race_clock = 0.0

func vent_active(index: int, seconds: float) -> bool:
    return fposmod(seconds+float(index)*1.19,LAVA_CYCLE) < LAVA_ACTIVE

func _process(_delta: float) -> void:
    if track_id != 2 or not is_instance_valid(game):
        return
    var t: float = game.race_time if game.race_state == "RACING" else -10.0
    for i in range(active_marks.size()):
        var flame := active_marks[i]
        if not is_instance_valid(flame):
            continue
        flame.visible = t >= 0.0 and vent_active(i,t)
        if flame.visible:
            flame.scale = Vector3(1.0,0.75+0.25*sin(t*14.0+i),1.0)

func tick(delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    race_clock += delta
    for i in range(zones.size()):
        var zone := zones[i]
        if not is_instance_valid(zone):
            continue
        if track_id == 2 and not vent_active(i,race_clock):
            continue
        for marble in racers:
            if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
                continue
            var offset: Vector3 = marble.global_position-zone.global_position
            if absf(offset.y) > 1.7:
                continue
            var within := absf(offset.x) < ZONE_WIDTH*0.5 and absf(offset.z) < ZONE_LENGTH*0.5
            if track_id == 2:
                within = Vector2(offset.x,offset.z).length_squared() < 2.45
            if not within:
                continue
            var key := "%d:%d" % [i,marble.racer_id]
            if track_id == 1:
                # Continuous, bounded lateral drift in an icy lane. This is
                # recoverable by player steering and also applies to bots.
                marble.apply_central_force(Vector3(signf(zone.position.x)*2.3,0.0,0.0)*marble.mass)
            elif track_id == 2:
                if race_clock-float(last_burst.get(key,-100.0)) < LAVA_CYCLE-0.3:
                    continue
                last_burst[key] = race_clock
                marble.apply_central_impulse(Vector3(
                    signf(zone.position.x)*1.35,1.05,1.75)*marble.mass)
                _feedback(marble,net,"vent")
                continue
            if collected.has(key):
                continue
            collected[key] = true
            if track_id == 0:
                marble.apply_central_impulse(Vector3(0.0,0.15,-4.6)*marble.mass)
                _feedback(marble,net,"speed")
            else:
                marble.apply_central_impulse(Vector3(signf(zone.position.x)*1.2,0.05,-0.4)*marble.mass)
                _feedback(marble,net,"ice")

func _feedback(marble: RigidBody3D, net: Node, kind: String) -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,kind)
    elif net.role == "offline" and marble.is_player:
        game.audio.course_event(kind)
        game.ui.show_course_event(kind)
