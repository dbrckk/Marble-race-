extends Node3D
## Deterministic biome-specific racing hazards and optional racing-line bonuses.
## All physical changes run offline or on the dedicated server, never on clients.
## Unlike rare items, natural hazards and surface zones affect AI as well.
const ZONE_Z := [-22.0, -61.0, -98.0, -139.0, -168.0]
# Three authored lane patterns give rematches genuinely different choices.
# Layout zero preserves the existing course, while the other two change
# the physical zones and their race-line consequences, not just decoration.
const LANE_PATTERNS := [
    [-3.3,3.3,-3.3,3.3,-3.3],
    [3.3,-3.3,3.3,-3.3,3.3],
    [-3.3,-3.3,3.3,3.3,-3.3]
]
const TRACK_PATH = preload("res://scripts/track_path.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")
const TRACK_COLORS := [Color("#e6b56e"), Color("#8beaff"), Color("#ff8759")]
const ZONE_WIDTH := 3.4
const ZONE_LENGTH := 6.5
const ICE_SLAB_Y := 0.024
const ICE_SLAB_THICKNESS := 0.065
const ICE_PAINT_Y := ICE_SLAB_Y+ICE_SLAB_THICKNESS*0.5+0.020
const GRIP_MARK_OFFSETS := [13.0,10.2,7.4,4.6,1.8]
const ICE_SHUTTER_GAP := 12.0
const VENT_RADIUS_SQUARED := 2.45
const LAVA_CYCLE := 4.8
const LAVA_ACTIVE := 1.35
const VENT_WINDUP := 0.78
var game: Node3D
var track_id := 0
var variation := 0
var zones: Array[Node3D] = []
var active_marks: Array[MeshInstance3D] = []
var vent_rims: Array[MeshInstance3D] = []
var grip_mark_origins: Array[Vector3] = []
var ice_exit_shutters: Array[int] = []
var collected: Dictionary = {}
var last_burst: Dictionary = {}
var race_clock := 0.0
var zone_racers: Array[RigidBody3D] = []
var zone_samples := PackedVector3Array()

static func lane_offset(index: int, track: int, layout: int) -> float:
    if index < 0 or index >= ZONE_Z.size():
        return 0.0
    return float(LANE_PATTERNS[posmod(layout,3)][
        (index+clampi(track,0,2))%ZONE_Z.size()])

static func placement_at(index: int, track: int, layout: int) -> Vector3:
    if index < 0 or index >= ZONE_Z.size():
        return Vector3.ZERO
    var z: float = ZONE_Z[index]
    return Vector3(TRACK_PATH.center_at(z,track)+lane_offset(
        index,track,layout),TRACK_PATH.height_at(z,track)+0.035,z)

func setup(owner: Node3D, course_id: int, next_layout: int = 0) -> void:
    game = owner
    track_id = clampi(course_id,0,2)
    variation = posmod(next_layout,3)
    for i in range(ZONE_Z.size()):
        var zone := Node3D.new()
        var kind := _kind()
        zone.name = "%sZone_%02d" % [kind.capitalize(),i]
        zone.position = placement_at(i,track_id,variation)
        add_child(zone)
        zones.append(zone)
        if track_id == 2:
            _vent_visual(zone,i)
        else:
            _ribbon_visual(zone)
            if track_id == 1:
                _ice_collision(zone)
    if track_id == 1:
        _find_ice_exit_shutters()
        _ice_grip_guides()
    reset_round()

func _kind() -> String:
    return ["speed","ice","vent"][track_id]

func upcoming_lane(at: Vector3, velocity: Vector3, downstream_limit: float) -> Dictionary:
    if track_id == 0 or not at.is_finite() or not velocity.is_finite():
        return {}
    var speed := maxf(2.0,-velocity.z)
    var reach := clampf(speed*1.6,12.0,27.0)
    var half_depth: float = sqrt(VENT_RADIUS_SQUARED) if track_id == 2 else ZONE_LENGTH*0.5
    for index in range(zones.size()):
        var center := zones[index].global_position
        # Use the leading edge for the display and the center for lateral drift.
        var distance := at.z-center.z
        var entry := maxf(0.0,distance-half_depth)
        if center.z > downstream_limit or distance < -half_depth or entry > reach:
            continue
        var lane_x := FEEDBACK.projected_lane_x(at.x,velocity.x,maxf(0.0,distance)/speed)
        var left := lane_offset(index,track_id,variation) < 0.0
        var hint := {"index":index, "side":"LEFT" if left else "RIGHT",
            "other":"RIGHT" if left else "LEFT", "distance":ceili(entry), "eta":entry/speed}
        if track_id == 1:
            var entry_x := FEEDBACK.projected_lane_x(at.x,velocity.x,entry/speed)
            hint["on_line"] = minf(entry_x,lane_x) < center.x+ZONE_WIDTH*0.5 and (
                maxf(entry_x,lane_x) > center.x-ZONE_WIDTH*0.5)
            hint["on_ice"] = entry <= 0.0 and absf(at.x-center.x) < ZONE_WIDTH*0.5 and (
                absf(at.y-center.y) <= 1.7)
            var shutter := ice_exit_shutters[index]
            hint["exit_shutter"] = shutter
            hint["grip_center"] = shutter >= 0 and game.race_director.side_at(shutter) == (
                -signf(lane_offset(index,track_id,variation)))
        else:
            var clock: float = game.race_time if game.net.role == "client" else race_clock
            var lateral := absf(lane_x-center.x)
            var crossing: float = sqrt(maxf(0.0,VENT_RADIUS_SQUARED-lateral*lateral))
            hint["active"] = _vent_crossing_active(index,clock,speed,distance,half_depth)
            hint["on_line"] = crossing > 0.0 and distance >= -crossing and (
                _vent_crossing_active(index,clock,speed,distance,crossing))
            if hint["on_line"]:
                hint["contact_eta"] = maxf(0.0,distance-crossing)/speed
        return hint
    return {}

func _vent_crossing_active(index: int, clock: float, speed: float,
        distance: float, half_depth: float) -> bool:
    var enter := maxf(0.0,(distance-half_depth)/speed)
    var leave := maxf(enter,(distance+half_depth)/speed)
    var phase := fposmod(clock+enter+float(index)*1.19,LAVA_CYCLE)
    return phase < LAVA_ACTIVE or leave-enter >= LAVA_CYCLE-phase

func _ribbon_visual(zone: Node3D) -> void:
    var art := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(ZONE_WIDTH,0.055,ZONE_LENGTH)
    art.mesh = mesh
    art.rotation.x = -atan(game.track_grade_at(zone.position.z))
    art.position.y = 0.035
    if track_id == 1:
        art.name = "GlacierIceSurface"
        mesh.size.y = 0.014
        art.position.y = ICE_SLAB_Y+ICE_SLAB_THICKNESS*0.5
    var material := StandardMaterial3D.new()
    material.albedo_color = TRACK_COLORS[track_id]
    material.metallic = 0.25
    material.roughness = 0.22 if track_id == 1 else 0.52
    material.emission_enabled = true
    material.emission = TRACK_COLORS[track_id]
    material.emission_energy_multiplier = 0.32
    if track_id == 1:
        material.albedo_color = Color("#388ab3")
        material.emission = Color("#7ddaff")
    art.material_override = material
    art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(art)
    if track_id == 1:
        _ice_markings(zone,art.rotation.x)
        return
    for stripe in range(3):
        var stripe_art := MeshInstance3D.new()
        var line := BoxMesh.new()
        line.size = Vector3(ZONE_WIDTH-0.55,0.025,0.18)
        stripe_art.mesh = line
        stripe_art.position = Vector3(0.0,0.09,2.15-float(stripe)*2.12)
        stripe_art.rotation.x = -atan(game.track_grade_at(zone.position.z+stripe_art.position.z))
        var detail := StandardMaterial3D.new()
        detail.albedo_color = Color("#fff2b6")
        detail.emission_enabled = true
        detail.emission = detail.albedo_color
        detail.emission_energy_multiplier = 0.28
        stripe_art.material_override = detail
        stripe_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        zone.add_child(stripe_art)

func _ice_markings(zone: Node3D, pitch: float) -> void:
    # This entire batch shares the physical slab's X/Z bounds and slope.
    var ink := StandardMaterial3D.new()
    ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ink.vertex_color_use_as_albedo = true
    var strip := BoxMesh.new()
    strip.size = Vector3.ONE
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = strip
    batch.instance_count = 12
    for edge in range(2):
        var side := -1.0 if edge == 0 else 1.0
        batch.set_instance_transform(edge,Transform3D(
            Basis().scaled(Vector3(0.16,0.016,ZONE_LENGTH)),
            Vector3(side*(ZONE_WIDTH*0.5-0.08),0.0,0.0)))
        batch.set_instance_color(edge,Color("#ccf7ff"))
        batch.set_instance_transform(edge+2,Transform3D(
            Basis().scaled(Vector3(ZONE_WIDTH-0.32,0.016,0.21)),
            Vector3(0.0,0.0,side*(ZONE_LENGTH*0.5-0.105))))
        batch.set_instance_color(edge+2,Color("#ccf7ff"))
    for row in range(4):
        var z := 2.42-float(row)*1.61
        for edge in range(2):
            var side := -1.0 if edge == 0 else 1.0
            var slot := 4+row*2+edge
            var angle := Basis(Vector3.UP,side*0.71)
            batch.set_instance_transform(slot,Transform3D(
                angle.scaled_local(Vector3(1.68,0.015,0.14)),
                Vector3(side*0.63,0.002,z+0.18)))
            batch.set_instance_color(slot,Color("#123951"))
    var marks := MultiMeshInstance3D.new()
    marks.name = "IceLaneEdgesAndChevrons"
    marks.multimesh = batch
    marks.material_override = ink
    marks.position.y = ICE_PAINT_Y
    marks.rotation.x = pitch
    marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(marks)

func _find_ice_exit_shutters() -> void:
    var director: Node3D = game.race_director
    for zone in zones:
        var exit_z := zone.position.z-ZONE_LENGTH*0.5
        var next_gate: Dictionary = director.event_ahead(exit_z,INF,ICE_SHUTTER_GAP)
        ice_exit_shutters.append(int(next_gate.get("index",-1)))

func _ice_grip_guides() -> void:
    # Twin painted arms on the regular road, running into the clear side.
    # Both the black backing and amber paint share one static GPU batch.
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = BoxMesh.new()
    batch.instance_count = zones.size()*GRIP_MARK_OFFSETS.size()*4
    var slot := 0
    for index in range(zones.size()):
        var zone := zones[index]
        var dry_side := -signf(lane_offset(index,track_id,variation))
        var shutter := ice_exit_shutters[index]
        var grip_center: bool = shutter >= 0 and game.race_director.side_at(shutter) == dry_side
        for row in range(GRIP_MARK_OFFSETS.size()):
            var z: float = zone.position.z+GRIP_MARK_OFFSETS[row]
            var section_z: float = 8.0-roundf((8.0-z)/game.SEGMENT_LENGTH)*game.SEGMENT_LENGTH
            var seam_z := section_z+(6.0 if z > section_z else -6.0)
            var pitch := -atan(game.track_grade_at(section_z))
            var y: float = game.height_at(section_z)-0.34+0.325/cos(pitch)-tan(pitch)*(z-section_z)
            if absf(z-seam_z) < 1.4:
                var seam_pitch := -atan(game.track_grade_at(seam_z))
                var seam_y: float = game.height_at(seam_z)-0.34+0.33/cos(seam_pitch)-tan(seam_pitch)*(z-seam_z)
                if seam_y > y:
                    pitch = seam_pitch
                    y = seam_y
            var progress := float(row)/float(GRIP_MARK_OFFSETS.size()-1)
            var end_offset := 0.50 if grip_center else 3.10
            var x: float = game.track_center_at(section_z)+dry_side*lerpf(1.95,end_offset,progress)
            var center := Vector3(x,y+0.055,z)
            grip_mark_origins.append(center)
            var road_basis := Basis(Vector3.RIGHT,pitch)
            for flank in [-1.0,1.0]:
                var pose := road_basis*Basis(Vector3.UP,flank*0.58)
                var at := center+Vector3(flank*0.47,0.0,0.0)
                batch.set_instance_transform(slot,Transform3D(
                    pose.scaled_local(Vector3(1.25,0.022,0.34)),at))
                batch.set_instance_color(slot,Color("#192632"))
                batch.set_instance_transform(slot+1,Transform3D(
                    pose.scaled_local(Vector3(1.08,0.015,0.185)),at+Vector3.UP*0.022))
                batch.set_instance_color(slot+1,Color("#ffda8c"))
                slot += 2
    var paint := StandardMaterial3D.new()
    paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    paint.vertex_color_use_as_albedo = true
    var guides := MultiMeshInstance3D.new()
    guides.name = "GlacierGripApproach"
    guides.multimesh = batch
    guides.material_override = paint
    guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(guides)

func _ice_collision(zone: Node3D) -> void:
    # A very shallow, low-friction physical slab; no tall edge blocking 40 racers.
    var surface := StaticBody3D.new()
    surface.name = "LowFrictionIce"
    surface.rotation.x = -atan(game.track_grade_at(zone.position.z))
    surface.position.y = ICE_SLAB_Y
    var friction := PhysicsMaterial.new()
    friction.friction = 0.04
    friction.rough = false
    friction.bounce = 0.02
    surface.physics_material_override = friction
    var hit := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(ZONE_WIDTH,ICE_SLAB_THICKNESS,ZONE_LENGTH)
    hit.shape = shape
    surface.add_child(hit)
    zone.add_child(surface)

func _vent_visual(zone: Node3D, index: int) -> void:
    var rim := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.outer_radius = sqrt(VENT_RADIUS_SQUARED)
    torus.inner_radius = torus.outer_radius-0.12
    torus.rings = 24
    torus.ring_segments = 8
    rim.mesh = torus
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color("#4b4045")
    metal.metallic = 0.72
    metal.roughness = 0.38
    var rim_material := StandardMaterial3D.new()
    rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rim_material.albedo_color = Color("#46545c")
    rim.material_override = rim_material
    rim.rotation.x = -atan(game.track_grade_at(zone.position.z))
    rim.position.y = 0.095
    rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(rim)
    vent_rims.append(rim)
    var grate := CylinderMesh.new()
    grate.top_radius = sqrt(VENT_RADIUS_SQUARED)
    grate.bottom_radius = grate.top_radius
    grate.height = 0.055
    grate.radial_segments = 24
    var surround := MeshInstance3D.new()
    surround.name = "VentFootprint"
    surround.mesh = grate
    surround.material_override = metal
    surround.rotation.x = -atan(game.track_grade_at(zone.position.z))
    surround.position.y = 0.045
    surround.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    zone.add_child(surround)
    var flame := MeshInstance3D.new()
    flame.name = "FlameWarning"
    var plume := SphereMesh.new()
    plume.radius = 0.75
    plume.height = 1.1
    plume.radial_segments = 10
    plume.rings = 4
    flame.mesh = plume
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

func vent_charge(index: int, seconds: float) -> float:
    # A visible half-second windup makes a real eruption avoidable by skill,
    # without granting immunity or moving its actual physical hit window.
    if index < 0 or index >= ZONE_Z.size() or seconds < 0.0:
        return 0.0
    var phase: float = fposmod(seconds+float(index)*1.19,LAVA_CYCLE)
    if phase < LAVA_ACTIVE:
        return 1.0
    return smoothstep(LAVA_CYCLE-VENT_WINDUP,LAVA_CYCLE,phase)

func _process(_delta: float) -> void:
    if track_id != 2 or not is_instance_valid(game):
        return
    # The offline and dedicated-server effect uses race_clock at physics
    # frequency. Rendering it from a different process clock could show
    # a safe vent while the authoritative impulse is already active.
    # Online clients remain visual-only and follow their local race timer.
    var t: float = -10.0
    if game.race_state == "RACING":
        t = game.race_time if game.net.role == "client" else race_clock
    for i in range(active_marks.size()):
        var flame := active_marks[i]
        if not is_instance_valid(flame):
            continue
        var intensity: float = vent_charge(i,t)
        var active: bool = t >= 0.0 and vent_active(i,t)
        var rim_material := vent_rims[i].material_override as StandardMaterial3D
        rim_material.albedo_color = Color("#ff7549") if active else (
            Color("#46545c").lerp(Color("#ffd278"),intensity))
        flame.visible = intensity > 0.02
        if not flame.visible:
            continue
        if active:
            flame.position.y = 0.56
            flame.scale = Vector3(1.0,0.75+0.25*sin(t*14.0+i),1.0)
        else:
            # A small growing ember clearly telegraphs the next launch.
            # Same existing cone mesh/material, zero extra Android draws.
            flame.position.y = 0.18+0.38*intensity
            flame.scale = Vector3(0.45+0.48*intensity,
                0.12+0.60*intensity,0.45+0.48*intensity)

func tick(delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    race_clock += delta
    if track_id == 2:
        _tick_vents(racers, net)
        return
    # Surface impulses and continuous grip only change velocity. Sample each
    # eligible racer once and keep the original zone and racer ordering.
    zone_samples.resize(racers.size())
    for marble in racers:
        if is_instance_valid(marble) and not marble.finished and not marble.eliminated and not marble.freeze:
            zone_samples[zone_racers.size()] = marble.global_position
            zone_racers.append(marble)
    var ice := track_id == 1
    for i in range(zones.size()):
        var zone := zones[i]
        if not is_instance_valid(zone):
            continue
        var center := zone.global_position
        var side := signf(lane_offset(i, track_id, variation))
        for racer_index in range(zone_racers.size()):
            var at := zone_samples[racer_index]
            if absf(at.z-center.z) >= ZONE_LENGTH*0.5:
                continue
            var offset := at-center
            if absf(offset.y) > 1.7 or not (absf(offset.x) < ZONE_WIDTH*0.5):
                continue
            var marble := zone_racers[racer_index]
            if ice:
                marble.apply_central_force(Vector3(side*2.3,0.0,0.0)*marble.mass)
            var key := "%d:%d" % [i,marble.racer_id]
            if collected.has(key):
                continue
            collected[key] = true
            if ice:
                marble.apply_central_impulse(Vector3(side*1.2,0.05,-0.4)*marble.mass)
                _feedback(marble,net,"ice")
            else:
                marble.apply_central_impulse(Vector3(0.0,0.15,-4.6)*marble.mass)
                _feedback(marble,net,"speed")
    zone_racers.clear()

func _tick_vents(racers: Array[RigidBody3D], net: Node) -> void:
    # Most Forge ticks have only one active vent, so skip the batch snapshot.
    var depth := sqrt(VENT_RADIUS_SQUARED)
    for i in range(zones.size()):
        var zone := zones[i]
        if not is_instance_valid(zone) or not vent_active(i,race_clock):
            continue
        var center := zone.global_position
        var side := signf(lane_offset(i, track_id, variation))
        for marble in racers:
            if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
                continue
            var at := marble.global_position
            if absf(at.z-center.z) >= depth:
                continue
            var offset := at-center
            if absf(offset.y) > 1.7 or not (
                offset.x*offset.x+offset.z*offset.z < VENT_RADIUS_SQUARED):
                continue
            var key := "%d:%d" % [i,marble.racer_id]
            if race_clock-float(last_burst.get(key,-100.0)) < LAVA_CYCLE-0.3:
                continue
            last_burst[key] = race_clock
            marble.apply_central_impulse(Vector3(side*1.35,1.05,1.75)*marble.mass)
            _feedback(marble,net,"vent")

func _feedback(marble: RigidBody3D, net: Node, kind: String) -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,kind)
    elif net.role == "offline" and marble.is_player:
        game.audio.course_event(kind)
        game.ui.show_course_event(kind)
