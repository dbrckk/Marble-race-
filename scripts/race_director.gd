extends Node3D
## Lightweight arcade race director: collidable timed hazards and earned clean
## passes. Real marbles and server authority decide the results; graphics never
## infer hits. Deterministic phases vary by biome and rematch variation.
# Three physical gates remain; their placement varies by biome and layout.
# All offsets are bounded away from shortcut entry and exit portals.
const EVENT_Z := [-34.0,-118.0,-154.0]
const HAZARD_ART = preload("res://scripts/timed_obstacle_art.gd")
const VISUALS = preload("res://scripts/visuals.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")
const LAYOUT_OFFSETS := [[0.0,0.0,0.0],[-4.0,5.0,-4.0],[4.0,-5.0,4.0]]
const BIOME_OFFSETS := [[0.0,0.0,0.0],[2.0,-2.0,3.0],[-2.0,3.0,-2.0]]
const EVENT_NAMES := ["SWEEPING ARM","ICE SHUTTER","FORGE PISTON"]
const EVENT_COLORS := [Color("#edbe72"),Color("#a5ecf4"),Color("#ff9c63")]
const OPEN_COLOR := Color("#91f4cd")
const MOVING_COLOR := Color("#ffcf79")
const BLOCKED_COLOR := Color("#ff775d")
const HAZARD_LOOKAHEAD := 24.0
const BODY_WIDTH := 1.65
const BODY_HEIGHT := 0.82
const BODY_DEPTH := 0.76
const FORGE_EXIT_GATE := 1
const GLACIER_FIRST_SHUTTER := 0
const GLACIER_RETURN_GATE := 1
const WOODWORKS_RETURN_ARM := 1
const MARBLE_CLEARANCE := 0.39
const NEAR_MISS_IMPULSE := 2.05
# Risk/reward is measured from REAL bodies, not estimated player input.
# Only precise passes can start a short streak; all racers are eligible.
const CLEAN_LATERAL_MIN := 1.36
const CLEAN_LATERAL_MAX := 2.36
const PRECISION_THRESHOLD := 0.62
const PRECISION_CHAIN_WINDOW := 24.0
const PRECISION_MAX_CHAIN := 3
const PRECISION_FLASH_SECONDS := 0.56
const EVENT_LENGTH := 2.1
const SPEEDS := [5.8,4.65,5.25]
const PISTON_BLOCKING_EXTENSION := 0.43
const PISTON_WARNING_SECONDS := 2.20
const PISTON_PREPARE_PHASE := 0.78
const VERTICAL_DUTY := 0.47

var game: Node3D
var biome := 0
var variation := 0
var obstacles: Array[AnimatableBody3D] = []
var warning_rings: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
var forge_approach_paint: Array[MultiMeshInstance3D] = []
var awarded: Dictionary = {}
var clock := 0.0
var collisions_enabled := true
var precision_streak: Dictionary = {}
var last_precision_at: Dictionary = {}
var last_award_strength: Dictionary = {}
var last_award_grade: Dictionary = {}
var ring_flash_end: Array[float] = []
var ring_flash_strength: Array[float] = []
var flash_events := 0

func setup(owner: Node3D, track: int, layout: int) -> void:
    game = owner
    biome = clampi(track,0,2)
    variation = posmod(layout,3)
    name = "ReactiveRaceDirector"
    var metal := StandardMaterial3D.new()
    metal.vertex_color_use_as_albedo = true
    metal.vertex_color_is_srgb = true
    metal.metallic = [0.12,0.24,0.54][biome]
    metal.roughness = [0.56,0.34,0.42][biome]
    var glow := StandardMaterial3D.new()
    glow.albedo_color = EVENT_COLORS[biome]
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.emission_enabled = true
    glow.emission = EVENT_COLORS[biome]
    glow.emission_energy_multiplier = 0.65
    var dimensions := Vector3(BODY_WIDTH,BODY_HEIGHT,BODY_DEPTH)
    var obstacle_meshes := HAZARD_ART.build(biome,dimensions)
    var floor_plate := BoxMesh.new()
    floor_plate.size = Vector3.ONE
    var floor_paint := StandardMaterial3D.new()
    floor_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    floor_paint.vertex_color_use_as_albedo = true
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color("#535b60")
    steel.metallic = 0.68
    steel.roughness = 0.32
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.88
    ring_mesh.outer_radius = 1.04
    ring_mesh.rings = 18
    ring_mesh.ring_segments = 7
    var piston_sockets: Array[Mesh] = []
    var piston_signals: Array[Mesh] = []
    if biome == 2:
        for side in [-1.0,1.0]:
            piston_sockets.append(_forge_piston_frame(floor_plate,false,side))
            piston_signals.append(_forge_piston_frame(floor_plate,true,side))
        steel.albedo_color = Color("#797d80")
        steel.metallic = 0.54
    for i in range(EVENT_Z.size()):
        var z: float = event_z(i)
        var side: float = side_at(i)
        var x: float = game.track_center_at(z)+side*(3.26 if biome == 2 else 3.22)
        var flank := int(side > 0.0)
        var body := AnimatableBody3D.new()
        body.name = "ReactiveHazard_%02d" % i
        body.sync_to_physics = true
        body.position = Vector3(x,game.height_at(z)+0.42,z)
        var contact := PhysicsMaterial.new()
        contact.friction = 0.30
        contact.bounce = 0.24 if biome == 2 else 0.12
        body.physics_material_override = contact
        var collider := CollisionShape3D.new()
        collider.name = "ActiveObstacleCollider"
        var shape := BoxShape3D.new()
        shape.size = dimensions
        collider.shape = shape
        body.add_child(collider)
        var art := MeshInstance3D.new()
        art.name = "TimedObstacleArt"
        art.mesh = obstacle_meshes[0]
        art.material_override = metal
        art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        body.add_child(art)
        var detail := MeshInstance3D.new()
        detail.name = ["SweepingArmCautionBands","IceShutterFrostInlays","PistonSteelCap"][biome]
        detail.mesh = obstacle_meshes[1]
        detail.material_override = metal
        detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        body.add_child(detail)
        if biome == 2:
            var socket := MeshInstance3D.new()
            socket.name = "PistonSocket_%02d" % i
            socket.mesh = piston_sockets[flank]
            socket.material_override = steel
            socket.transform = _forge_deck_frame(z,x)
            socket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(socket)
        add_child(body)
        obstacles.append(body)
        var marker := MeshInstance3D.new()
        marker.name = "WarningHalo_%02d" % i
        marker.mesh = piston_signals[flank] if biome == 2 else ring_mesh
        marker.material_override = glow.duplicate() if biome == 2 else glow
        if biome == 2:
            marker.transform = _forge_deck_frame(z,x)
        else:
            marker.position = Vector3(x,game.height_at(z)+0.10,z)
        marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(marker)
        warning_rings.append(marker)
        if biome == 2:
            _mark_forge_approach(i,x,side,floor_plate,floor_paint)
        else:
            _mark_gate_approach(i,floor_plate,floor_paint)
        var notice := Label3D.new()
        notice.name = "TimedHazardSign_%02d" % i
        notice.text = EVENT_NAMES[biome]
        notice.font_size = 30
        notice.pixel_size = 0.009
        notice.outline_size = 8
        notice.modulate = EVENT_COLORS[biome]
        notice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        notice.position = Vector3(x,game.height_at(z)+2.25,z)
        if biome == 2 and i == FORGE_EXIT_GATE:
            _forge_exit_telegraph(notice,z,side,steel)
        add_child(notice)
        signs.append(notice)
    ring_flash_end.resize(obstacles.size())
    ring_flash_strength.resize(obstacles.size())
    reset_round()

func _forge_piston_frame(unit: Mesh, illuminated: bool, shoulder: float) -> Mesh:
    # The deck brackets and shoulder beacon share a surface and phase.
    # The beacon is visible over the approach paint from the chase camera.
    var frame := SurfaceTool.new()
    for side in [-1.0,1.0]:
        var rail := Vector3(0.15,0.026,0.98) if illuminated else Vector3(0.21,0.052,1.21)
        var x := 1.12 if illuminated else 0.98
        frame.append_from(unit,0,Transform3D(Basis.from_scale(rail),Vector3(side*x,0.052,0)))
        for end in [-1.0,1.0]:
            var lug := Vector3(0.39,0.026,0.14) if illuminated else Vector3(0.48,0.048,0.23)
            var z := 0.47 if illuminated else 0.58
            frame.append_from(unit,0,Transform3D(Basis.from_scale(lug),
                Vector3(side*(x-0.12),0.052,end*z)))
    var post_x := shoulder*2.44
    if illuminated:
        frame.append_from(unit,0,Transform3D(Basis.from_scale(Vector3(0.31,0.34,0.19)),
            Vector3(post_x,0.83,0.0)))
    else:
        frame.append_from(unit,0,Transform3D(Basis.from_scale(Vector3(0.20,0.72,0.25)),
            Vector3(post_x,0.36,0.0)))
        frame.append_from(unit,0,Transform3D(Basis.from_scale(Vector3(0.44,0.46,0.26)),
            Vector3(post_x,0.84,-0.085)))
    return frame.commit()

func _forge_deck_frame(z: float, x: float) -> Transform3D:
    var section_z: float = 8.0-roundf((8.0-z)/game.SEGMENT_LENGTH)*game.SEGMENT_LENGTH
    var pitch: float = -atan(game.track_grade_at(section_z))
    var y: float = game.height_at(section_z)-0.34+0.325/cos(pitch)-tan(pitch)*(z-section_z)
    return Transform3D(Basis(Vector3.RIGHT,pitch),Vector3(x,y,z))

func _mark_gate_approach(index: int, mesh: Mesh, paint: Material) -> void:
    # Mark the entry to the real hazard lane with three pairs of strips.
    # One colored mesh batch per gate, with no collisions or dynamic lights.
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = mesh
    batch.instance_count = 12
    var z: float = event_z(index)
    var side: float = side_at(index)
    for row in range(3):
        var at_z := approach_row_z(z,row,biome)
        var x: float = game.track_center_at(at_z)+side*3.22
        var y: float = game.height_at(at_z)+0.07
        var pitch: float = -atan(game.track_grade_at(at_z))
        for arm in range(2):
            var direction := -1.0 if arm == 0 else 1.0
            var tilt := Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,direction*0.39)
            var mark := Transform3D(tilt.scaled_local(Vector3(0.95,0.025,0.18)),
                Vector3(x+direction*0.39,y,at_z))
            var slot := row*4+arm*2
            batch.set_instance_transform(slot,mark.scaled_local(Vector3(1.11,0.8,1.9)))
            batch.set_instance_color(slot,Color("#15202b"))
            mark.origin.y += 0.019
            batch.set_instance_transform(slot+1,mark)
            batch.set_instance_color(slot+1,EVENT_COLORS[biome].lightened(0.20))
    var marks := MultiMeshInstance3D.new()
    marks.name = "GateApproachMarkings_%02d" % index
    marks.multimesh = batch
    marks.material_override = paint
    marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marks)

func _forge_exit_telegraph(notice: Label3D, z: float, side: float, steel: Material) -> void:
    # The shoulder sign and floor stripes point to the same physical lane.
    var sign_x: float = game.track_center_at(z)+side*5.68
    var sign_y: float = game.height_at(z)+1.91
    var plaque := MeshInstance3D.new()
    plaque.name = "ForgeExitPistonPlaque"
    plaque.mesh = VISUALS.rounded_box(Vector3(1.96,0.98,0.19),0.025)
    plaque.material_override = steel
    plaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    plaque.position = Vector3(sign_x,sign_y,z+0.65)
    add_child(plaque)
    notice.position = plaque.position+Vector3(0,0,0.106)
    notice.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    notice.pixel_size = 0.0085
    notice.font_size = 37
    notice.line_spacing = -4.0

func _mark_forge_approach(index: int, x: float, side: float,
        unit_mesh: Mesh, paint: Material) -> void:
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = unit_mesh
    batch.instance_count = 12
    for row in range(3):
        var at_z := approach_row_z(event_z(index),row,biome)
        var deck := _forge_deck_frame(at_z,x)
        batch.set_instance_transform(row*4,deck*Transform3D(
            Basis.from_scale(Vector3(2.58,0.018,0.61)),Vector3(0,0.052,0)))
        batch.set_instance_color(row*4,Color("#26212b"))
        for stripe in range(3):
            var angle := Basis(Vector3.UP,side*0.45)
            batch.set_instance_transform(row*4+stripe+1,deck*Transform3D(
                angle.scaled_local(Vector3(0.51,0.018,0.37)),
                Vector3((stripe-1)*0.75,0.069,0)))
    var marks := MultiMeshInstance3D.new()
    marks.name = "GateApproachMarkings_%02d" % index
    marks.multimesh = batch
    marks.material_override = paint
    marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marks)
    forge_approach_paint.append(marks)

static func precision_grade(lateral: float, forward_speed: float) -> float:
    if not is_finite(lateral) or not is_finite(forward_speed) or (
        lateral < CLEAN_LATERAL_MIN or lateral > CLEAN_LATERAL_MAX or
        forward_speed < 0.85):
        return 0.0
    var proximity: float = clampf((CLEAN_LATERAL_MAX-lateral)/(
        CLEAN_LATERAL_MAX-CLEAN_LATERAL_MIN),0.0,1.0)
    var pace: float = clampf((forward_speed-4.0)/9.0,0.0,1.0)
    return proximity*pace

static func earned_impulse(grade: float, streak: int) -> float:
    # Preserve the proven 2.05m/s baseline for ordinary clean passes.
    # Precision adds up to 0.50m/s, and a legitimate three-gate streak
    # at most another 0.28m/s: no reduction to normal AI progression.
    return NEAR_MISS_IMPULSE+0.50*clampf(grade,0.0,1.0)+(
        0.14*float(clampi(streak,1,PRECISION_MAX_CHAIN)-1))

func flash_local_near_miss(z: float, strength: float = 1.0) -> bool:
    # Called for a real local/offline award or a signed server event only.
    # A delayed RPC outside the gate footprint never lights a wrong ring.
    if not is_finite(z) or not is_finite(strength):
        return false
    for i in range(obstacles.size()):
        if absf(z-event_z(i)) <= EVENT_LENGTH+0.6:
            ring_flash_end[i] = clock+PRECISION_FLASH_SECONDS
            ring_flash_strength[i] = clampf(strength,0.35,1.0)
            flash_events += 1
            return true
    return false

static func event_z_for(track: int, layout: int, index: int) -> float:
    return EVENT_Z[index]+LAYOUT_OFFSETS[posmod(layout,3)][index]+(
        BIOME_OFFSETS[clampi(track,0,2)][index])

static func approach_row_z(z: float, row: int, track: int) -> float:
    return z+(1.52+1.51*row if track == 2 else 2.0+0.95*row)

func event_z(index: int) -> float:
    return event_z_for(biome,variation,index)

func side_at(index: int) -> float:
    return -1.0 if (index+biome+variation)%2 == 0 else 1.0

func period() -> float:
    return SPEEDS[biome]

func phase_at(index: int, elapsed: float) -> float:
    var seconds := period()
    return fposmod(elapsed+float(index)*1.71+float(variation)*1.29,seconds)/seconds

func piston_extension(index: int, elapsed: float) -> float:
    if biome != 2:
        return 1.0
    return _piston_extension_at_phase(phase_at(index,elapsed))

static func _piston_extension_at_phase(phase: float) -> float:
    if phase < 0.10:
        return smoothstep(0.0,0.10,phase)
    if phase < 0.34:
        return 1.0
    if phase < VERTICAL_DUTY:
        return 1.0-smoothstep(0.34,VERTICAL_DUTY,phase)
    return 0.0

func piston_up(index: int, elapsed: float) -> bool:
    return piston_extension(index,elapsed) > PISTON_BLOCKING_EXTENSION

func position_at(index: int, elapsed: float) -> Vector3:
    var phase := phase_at(index,elapsed)
    var extension := _piston_extension_at_phase(phase) if biome == 2 else 1.0
    return _gate_position(index,phase,extension)

func _gate_position(index: int, phase: float, extension: float) -> Vector3:
    var z: float = event_z(index)
    var center: float = game.track_center_at(z)
    var x := _gate_x(index,center,phase)
    var height: float = game.height_at(z)
    if biome == 2:
        # Fully buried below the track when inactive. The circular warning
        # stays visible so competitors understand the timing of the piston.
        return Vector3(x,height-1.08+1.48*extension,z)
    return Vector3(x,height+0.42,z)

func _gate_x(index: int, center: float, phase: float) -> float:
    var side: float = side_at(index)
    if biome == 2:
        return center+side*3.26
    var radius: float = 0.85 if biome == 0 else 1.12
    return center+side*(3.22+radius*sin(phase*TAU))

func blocking_lane_offset_at(index: int, elapsed: float, gate_z: float) -> float:
    var phase := phase_at(index,elapsed)
    if biome == 2 and _piston_extension_at_phase(phase) <= PISTON_BLOCKING_EXTENSION:
        return INF
    var center: float = game.track_center_at(gate_z)
    # Match the collider's Vector3 component precision at clearance boundaries.
    var world_x := Vector2(_gate_x(index,center,phase),0.0).x
    return world_x-center

# The phone HUD uses the real collider trajectory, not just its biome phase.
# A gate that blocks the far outside lane must not warn someone safely on
# the centre line. The 0.40s lateral extrapolation is intentionally bounded:
# it accounts for ongoing drift without pretending to predict future taps.
const LANE_THREAT_RADIUS := BODY_WIDTH*0.5+0.39+0.18

func threatens_line(index: int, elapsed: float, eta: float,
        current_x: float, lateral_speed: float) -> bool:
    if index < 0 or index >= obstacles.size() or (
        not is_finite(elapsed) or not is_finite(eta) or
        not is_finite(current_x) or not is_finite(lateral_speed) or eta < 0.0):
        return false
    var arrival: float = elapsed+eta
    if biome == 2 and not piston_up(index,arrival):
        return false
    var obstacle_x: float = position_at(index,arrival).x
    var future_x: float = FEEDBACK.projected_lane_x(current_x,lateral_speed,eta)
    return absf(future_x-obstacle_x) < LANE_THREAT_RADIUS

func glacier_shutter_threatens_crossing(index: int, eta: float, forward_speed: float,
        current_x: float, lateral_speed: float) -> bool:
    # A slower sphere stays in the collider's longitudinal footprint
    # longer. Predict up to twice the time from its nose to its center.
    var half_window := (BODY_DEPTH*0.5+MARBLE_CLEARANCE)/maxf(2.0,forward_speed)
    var first := maxf(0.0,eta-half_window)
    var last := maxf(0.0,eta+half_window)
    var previous_gap := INF
    for sample in range(3):
        var t := lerpf(first,last,float(sample)*0.5)
        var gap := FEEDBACK.projected_lane_x(current_x,lateral_speed,t)-(
            position_at(index,clock+t).x)
        if absf(gap) < LANE_THREAT_RADIUS or (previous_gap != INF and gap*previous_gap < 0.0):
            return true
        previous_gap = gap
    return false

func woodworks_arm_contact_eta(eta: float, speed: float, world_x: float, lateral_speed: float) -> float:
    if biome != 0 or speed < 2.0 or not is_finite(speed) or not is_finite(eta) or (
            not is_finite(world_x) or not is_finite(lateral_speed)):
        return INF
    var half_window := (BODY_DEPTH*0.5+MARBLE_CLEARANCE)/speed
    var first := maxf(0.0,eta-half_window)
    var last := eta+half_window
    if last < first:
        return INF
    var previous := INF
    var previous_t := first
    for sample in range(5):
        var t := lerpf(first,last,float(sample)*0.25)
        var gap := FEEDBACK.projected_lane_x(world_x,lateral_speed,t)-position_at(WOODWORKS_RETURN_ARM,clock+t).x
        if is_finite(previous) and absf(previous) >= LANE_THREAT_RADIUS and (
                absf(gap) < LANE_THREAT_RADIUS or previous*gap < 0.0):
            return lerpf(previous_t,t,(previous-signf(previous)*LANE_THREAT_RADIUS)/(previous-gap))
        if absf(gap) < LANE_THREAT_RADIUS:
            return t
        previous = gap
        previous_t = t
    return INF

func forge_exit_blocks_during_crossing(eta: float, speed: float) -> bool:
    return is_finite(forge_piston_contact_eta(FORGE_EXIT_GATE,eta,speed))

func forge_piston_contact_eta(index: int, eta: float, speed: float,
        world_x := NAN, lateral_speed := 0.0) -> float:
    if biome != 2 or index < 0 or index >= obstacles.size() or speed < 2.0 or (
            not is_finite(eta) or not is_finite(speed) or is_inf(world_x) or not is_finite(lateral_speed)):
        return INF
    var half_window := (BODY_DEPTH*0.5+MARBLE_CLEARANCE)/speed
    var first := maxf(0.0,eta-half_window)
    var last := eta+half_window
    if is_finite(world_x):
        var gap := world_x-position_at(index,clock).x
        var drift := clampf(lateral_speed,-5.0,5.0)
        if is_zero_approx(drift):
            if absf(gap) >= LANE_THREAT_RADIUS:
                return INF
        else:
            # The usual forecast follows drift for 0.4 s, then holds its lane.
            var a := (-LANE_THREAT_RADIUS-gap)/drift
            var b := (LANE_THREAT_RADIUS-gap)/drift
            var lane_entry := minf(a,b)
            var lane_exit := maxf(a,b)
            if lane_entry >= 0.40:
                return INF
            first = maxf(first,lane_entry)
            if lane_exit < 0.40:
                last = minf(last,lane_exit)
    if last < first:
        return INF
    if piston_up(index,clock+first):
        return first
    # Invert the same smoothstep that raises the physical piston, so an
    # opening or closing window is timed from the blocking threshold.
    var rise := 0.10*(0.5-sin(asin(1.0-2.0*PISTON_BLOCKING_EXTENSION)/3.0))
    var begins := first+fposmod(rise-phase_at(index,clock+first),1.0)*period()
    return begins if begins <= last else INF

# Physical timing cues share the deterministic clock of the collider.
static func hazard_phase_cue(track: int, extension: float,
        lateral_speed: float) -> String:
    if track == 2:
        if extension < 0.15:
            return "OPEN"
        if extension < 0.57:
            # A retracting piston is FALLING, not RISING. A false upward
            # cue during the safe window would teach the wrong dodge.
            return "FALLING" if lateral_speed < -0.001 else "RISING"
        return "BLOCKED"
    return "SWEEP LEFT" if lateral_speed < -0.05 else (
        "SWEEP RIGHT" if lateral_speed > 0.05 else "REVERSING")

func animate(elapsed: float) -> void:
    clock = maxf(0.0,elapsed)
    for i in range(obstacles.size()):
        var phase := phase_at(i,clock)
        var extension := _piston_extension_at_phase(phase) if biome == 2 else 1.0
        var point := _gate_position(i,phase,extension)
        obstacles[i].position = point
        var tint: Color = EVENT_COLORS[biome]
        var earned_flash := 0.0
        if clock < ring_flash_end[i]:
            earned_flash = ring_flash_strength[i]*(
                ring_flash_end[i]-clock)/PRECISION_FLASH_SECONDS
        var motion: float
        var preparing := false
        if biome == 2:
            preparing = phase > PISTON_PREPARE_PHASE or (phase < 0.10 and extension < 0.15)
            motion = piston_extension(i,clock+0.08)-extension
            if extension > PISTON_BLOCKING_EXTENSION:
                tint = BLOCKED_COLOR
            elif preparing or extension >= 0.15:
                tint = MOVING_COLOR
            else:
                tint = OPEN_COLOR
            var signal_material := warning_rings[i].material_override as StandardMaterial3D
            var signal_tint := tint.lerp(Color.WHITE,0.50*earned_flash)
            if signal_material.albedo_color != signal_tint:
                signal_material.albedo_color = signal_tint
                signal_material.emission = signal_tint
            if signs[i].modulate != tint:
                var markings := forge_approach_paint[i].multimesh
                for row in range(3):
                    for stripe in range(1,4):
                        markings.set_instance_color(row*4+stripe,tint)
        else:
            warning_rings[i].position = Vector3(point.x,
                game.height_at(event_z(i))+0.10,event_z(i))
            warning_rings[i].scale = Vector3.ONE*(
                1.10+0.13*sin(clock*TAU/period()+float(i)*1.7)+0.48*earned_flash)
            motion = (position_at(i,clock+0.08).x-point.x)/0.08
        var cue := "GET READY" if preparing else hazard_phase_cue(biome,extension,motion)
        var separator := "\n" if biome == 2 and i == FORGE_EXIT_GATE else " / "
        var sign_text: String = EVENT_NAMES[biome]+separator+cue
        if signs[i].text != sign_text:
            signs[i].text = sign_text
        if signs[i].modulate != tint:
            signs[i].modulate = tint

func reset_round() -> void:
    awarded.clear()
    precision_streak.clear()
    last_precision_at.clear()
    last_award_strength.clear()
    last_award_grade.clear()
    flash_events = 0
    for i in range(ring_flash_end.size()):
        ring_flash_end[i] = 0.0
        ring_flash_strength[i] = 0.0
    animate(0.0)

func event_ahead(z: float, downstream_limit := INF, reach := HAZARD_LOOKAHEAD) -> Dictionary:
    var nearest: float = reach
    var result: Dictionary = {}
    for i in range(EVENT_Z.size()):
        var gate_z: float = event_z(i)
        var distance := z-gate_z
        if gate_z > downstream_limit or distance <= 0.0 or distance >= nearest:
            continue
        nearest = distance
        result = {"distance":maxi(0,int(round(distance))),
            "side":"LEFT" if side_at(i) < 0 else "RIGHT",
            "kind":EVENT_NAMES[biome],
            "index":i, "z":gate_z,
            "active":piston_up(i,clock),
            "phase":phase_at(i,clock)}
    return result

func tick(racers: Array[RigidBody3D], net: Node) -> void:
    if net.role == "client" or not collisions_enabled:
        return
    for i in range(obstacles.size()):
        var event: AnimatableBody3D = obstacles[i]
        if biome == 2 and not piston_up(i,clock):
            continue
        # Compute hazard world transform only once per tick. Reject marbles
        # outside its narrow physical timing gate before making string keys,
        # hashing dictionaries or checking lateral/y clearance.
        var event_position: Vector3 = event.global_position
        for marble in racers:
            if not is_instance_valid(marble) or marble.finished or marble.eliminated or marble.freeze:
                continue
            var position: Vector3 = marble.global_position
            var dz: float = position.z-event_position.z
            if dz > -0.35 or dz < -EVENT_LENGTH:
                continue
            var lateral: float = absf(position.x-event_position.x)
            if lateral < 1.36 or lateral > 2.36 or absf(position.y-event_position.y) > 1.6:
                continue
            if marble.linear_velocity.z > -0.85:
                continue
            var key: String = "%d:%d" % [i,marble.racer_id]
            if awarded.has(key):
                continue
            awarded[key] = true
            var grade: float = precision_grade(lateral,-marble.linear_velocity.z)
            var precise: bool = grade >= PRECISION_THRESHOLD
            var streak := 1
            if precise:
                var previous: float = float(last_precision_at.get(
                    marble.racer_id,-100.0))
                if clock >= previous and clock-previous <= PRECISION_CHAIN_WINDOW:
                    streak = mini(PRECISION_MAX_CHAIN,
                        int(precision_streak.get(marble.racer_id,0))+1)
                precision_streak[marble.racer_id] = streak
                last_precision_at[marble.racer_id] = clock
            else:
                precision_streak.erase(marble.racer_id)
                last_precision_at.erase(marble.racer_id)
            var earned: float = earned_impulse(grade,streak)
            last_award_strength[key] = earned
            last_award_grade[key] = grade
            marble.apply_central_impulse(
                Vector3(0.0,0.10,-earned)*marble.mass)
            if net.role == "offline" and marble.is_player:
                flash_local_near_miss(position.z,grade)
            var cue := "near_miss_chain" if precise and streak >= 2 else (
                "near_miss_precision" if precise else "near_miss")
            _feedback(marble,net,cue)

func clean_pass_count(racer_id: int) -> int:
    var total := 0
    for index in range(EVENT_Z.size()):
        if awarded.has("%d:%d" % [index,racer_id]):
            total += 1
    return total

func precision_pass_count(racer_id: int) -> int:
    # Only authenticated/authoritative physics can populate these keys.
    # The lifetime career asks for the player's real gate events after
    # the actual finish, never a HUD score or network message.
    var total := 0
    for index in range(EVENT_Z.size()):
        var key := "%d:%d" % [index,racer_id]
        if awarded.has(key) and float(last_award_grade.get(key,0.0)) >= (
            PRECISION_THRESHOLD):
            total += 1
    return total

func _feedback(marble: RigidBody3D, net: Node, kind: String = "near_miss") -> void:
    if net.role == "server":
        if marble.network_controlled and net.joined_slots.values().has(marble.racer_id):
            net.notify_course_event(marble.racer_id,kind)
    elif net.role == "offline" and marble.is_player:
        game.audio.course_event(kind)
        game.ui.show_course_event(kind)
