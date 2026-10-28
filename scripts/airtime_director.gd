extends Node3D
## Real local marble flight and touchdown direction. This class is PURELY
## presentation: no velocity, position, score, purchases or server messages
## are written by it. One physics floor ray at ~20 Hz for only the local
## human, using an exclusion list built once per race (39 other marbles).
## No lights, postprocess, skeletal animations or per-marble VFX.
const RaceFeedback = preload("res://scripts/race_feedback.gd")

const SAMPLE_PERIOD := 0.050
const RADIUS := 0.39
const CONTACT_MIN := 0.19
const CONTACT_MAX := 0.54
const TAKEOFF_GRACE := 0.125
const MIN_FLIGHT := 0.28
const MIN_LIFT := 0.155
const MAX_FLIGHT := 3.4
const MIN_LANDING_FORWARD := 4.0
const MAX_SAMPLE_STEP := 0.24
const PULSE_LIFETIME := 0.74
const RIPPLE_POOL := 3
const TRACK_TINTS := [
    Color("#f5c48e"),Color("#98eaff"),Color("#ffa988")
]

var game: Node3D
var ripple: MultiMeshInstance3D
var ripple_age: Array[float] = []
var ripple_position: Array[Vector3] = []
var ripple_head := 0
var quality := 1
var ignored_rids: Array[RID] = []
var probe_clock := 0.0
var physics_probes := 0
var airborne := false
var armed := false
var lost_contact := 0.0
var flight_time := 0.0
var peak_clearance := 0.0
var descent_speed := 0.0
var last_ground: Vector3 = Vector3.ZERO
var last_position: Vector3 = Vector3.ZERO
var has_position := false
var takeoff_position: Vector3 = Vector3.ZERO
var landing_count := 0
var longest_airtime := 0.0
var total_airtime := 0.0
var perfect_landings := 0

func _ready() -> void:
    var loop := TorusMesh.new()
    loop.inner_radius = 0.41
    loop.outer_radius = 0.54
    loop.rings = 28
    loop.ring_segments = 6
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.vertex_color_use_as_albedo = true
    material.albedo_color = Color.WHITE
    material.emission_enabled = true
    material.emission = Color("#93e7ff")
    material.emission_energy_multiplier = 0.38
    var geometry := MultiMesh.new()
    geometry.transform_format = MultiMesh.TRANSFORM_3D
    geometry.use_colors = true
    geometry.mesh = loop
    geometry.instance_count = RIPPLE_POOL
    ripple = MultiMeshInstance3D.new()
    ripple.name = "TrueTouchdownRipples_OneDrawBatch"
    ripple.multimesh = geometry
    ripple.material_override = material
    ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ripple)
    for i in range(RIPPLE_POOL):
        ripple_age.append(0.0)
        ripple_position.append(Vector3.ZERO)
        _hide_ripple(i)

func configure(owner: Node3D) -> void:
    game = owner
    set_quality(owner.graphics_quality)

func set_quality(value: int) -> void:
    quality = clampi(value,0,2)
    if is_instance_valid(ripple):
        ripple.visible = quality > 0

func _hide_ripple(index: int) -> void:
    if not is_instance_valid(ripple):
        return
    ripple.multimesh.set_instance_transform(index,
        Transform3D(Basis().scaled(Vector3.ZERO),ripple_position[index]))
    ripple.multimesh.set_instance_color(index,Color.TRANSPARENT)

func clear_motion() -> void:
    armed = false
    airborne = false
    lost_contact = 0.0
    flight_time = 0.0
    peak_clearance = 0.0
    descent_speed = 0.0
    has_position = false
    probe_clock = 0.0

func reset_round() -> void:
    clear_motion()
    physics_probes = 0
    landing_count = 0
    longest_airtime = 0.0
    total_airtime = 0.0
    perfect_landings = 0
    ignored_rids.clear()
    if is_instance_valid(game):
        for marble in game.racers:
            if is_instance_valid(marble):
                ignored_rids.append(marble.get_rid())
    for i in range(RIPPLE_POOL):
        ripple_age[i] = 0.0
        _hide_ripple(i)

static func landing_grade(seconds: float, lift: float,
        forward_speed: float, downward_speed: float) -> String:
    if not is_finite(seconds) or not is_finite(lift) or (
            not is_finite(forward_speed) or not is_finite(downward_speed)):
        return ""
    if seconds < MIN_FLIGHT or seconds > MAX_FLIGHT or lift < MIN_LIFT or (
            forward_speed < MIN_LANDING_FORWARD):
        return ""
    if seconds >= 0.74 and lift >= 0.34:
        return "BIG AIR"
    if seconds >= 0.38 and forward_speed >= 8.0 and (
            downward_speed <= 4.4):
        return "PERFECT LANDING"
    return "TOUCHDOWN"

# Pure state transition used by both a real physics probe and deterministic
# regression tests. A short road seam is not a flight, a distant bridge is
# not a touchdown, and a teleport explicitly cancels the old flight.
func sample_motion(dt: float, touching: bool, clearance: float,
        position: Vector3, velocity: Vector3) -> Dictionary:
    if dt <= 0.0 or dt > MAX_SAMPLE_STEP or not is_finite(dt) or (
            not is_finite(clearance) or not position.is_finite() or
            not velocity.is_finite()):
        clear_motion()
        return {}
    if has_position and position.distance_to(last_position) > (
            maxf(3.4,velocity.length()*dt*2.7+1.5)):
        clear_motion()
        last_position = position
        has_position = true
        return {}
    last_position = position
    has_position = true
    if touching:
        var finished_air: float = flight_time
        var finished_lift: float = peak_clearance
        var finished_descent: float = maxf(descent_speed,-velocity.y)
        var result: Dictionary = {}
        if airborne:
            var grade: String = landing_grade(
                finished_air,finished_lift,-velocity.z,finished_descent)
            if grade != "":
                landing_count += 1
                longest_airtime = maxf(longest_airtime,finished_air)
                total_airtime += finished_air
                if grade == "PERFECT LANDING":
                    perfect_landings += 1
                result = {
                    "grade":grade,"seconds":finished_air,
                    "forward":-velocity.z,"impact":finished_descent,
                    "position":position
                }
        armed = true
        airborne = false
        lost_contact = 0.0
        flight_time = 0.0
        peak_clearance = 0.0
        descent_speed = 0.0
        last_ground = position
        return result
    if not armed:
        return {}
    lost_contact += dt
    peak_clearance = maxf(peak_clearance,maxf(0.0,clearance))
    descent_speed = maxf(descent_speed,maxf(0.0,-velocity.y))
    if not airborne and lost_contact >= TAKEOFF_GRACE and (
            peak_clearance >= MIN_LIFT or velocity.y > 0.45):
        airborne = true
        flight_time = lost_contact
        takeoff_position = last_ground
    elif airborne:
        flight_time += dt
    if flight_time > MAX_FLIGHT:
        # A marble tumbling off the circuit does not earn imaginary airtime.
        clear_motion()
    return {}

func probe_floor(marble: RigidBody3D) -> Dictionary:
    if not is_instance_valid(game) or not is_instance_valid(marble):
        return {}
    var start: Vector3 = marble.global_position+Vector3.UP*0.12
    var query := PhysicsRayQueryParameters3D.create(
        start,start+Vector3.DOWN*3.2,1)
    query.exclude = ignored_rids
    physics_probes += 1
    var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(
        query)
    if hit.is_empty() or not (hit.get("collider") is StaticBody3D) or (
            (hit["normal"] as Vector3).y < 0.55):
        return {"touching":false,"clearance":maxf(0.0,
            marble.global_position.y-game.height_at(marble.global_position.z)-RADIUS)}
    var ground: Vector3 = hit["position"]
    var separation: float = marble.global_position.y-ground.y
    return {
        "touching":separation >= CONTACT_MIN and separation <= CONTACT_MAX,
        "clearance":maxf(0.0,separation-RADIUS),
        "ground":ground
    }

func tick_physics(delta: float) -> void:
    if not is_instance_valid(game) or game.race_state != "RACING" or (
            not is_instance_valid(game.player) or
            game.player.freeze or game.player.finished or
            game.player.eliminated or game.net.role == "server"):
        return
    probe_clock += delta
    if probe_clock < SAMPLE_PERIOD:
        return
    var dt: float = probe_clock
    probe_clock = 0.0
    var hit: Dictionary = probe_floor(game.player)
    if hit.is_empty():
        return
    var event: Dictionary = sample_motion(
        dt,bool(hit["touching"]),float(hit["clearance"]),
        game.player.global_position,game.player.linear_velocity)
    if not event.is_empty():
        var ground_point: Vector3 = hit.get(
            "ground",game.player.global_position-Vector3.UP*RADIUS)
        _show_landing(event,ground_point)

func camera_weight() -> float:
    if not airborne:
        return 0.0
    return clampf((flight_time-TAKEOFF_GRACE)/0.26,0.0,1.0)

func _show_landing(event: Dictionary, ground_point: Vector3) -> void:
    # Ground location comes from the actual static road ray, not the shader
    # or a duplicated approximation of the shortcut elevation.
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    var grade: String = event["grade"]
    var seconds: float = event["seconds"]
    game.ui.show_race_moment("%s  •  %.2fs" % [grade,seconds],
        1.35 if grade == "BIG AIR" else 1.1)
    game.audio.touchdown(grade,float(event["impact"]))
    game.camera_shake = minf(0.105,maxf(game.camera_shake,
        0.042 if grade != "BIG AIR" else 0.075))
    if quality > 0:
        _emit_ripple(ground_point,grade)

func _emit_ripple(ground_point: Vector3, grade: String) -> void:
    var index: int = ripple_head
    ripple_head = (ripple_head+1)%RIPPLE_POOL
    ripple_age[index] = PULSE_LIFETIME
    ripple_position[index] = ground_point+Vector3.UP*0.065
    if grade == "BIG AIR":
        ripple_age[index] = PULSE_LIFETIME*1.15
    _animate_ripple(index)

func _animate_ripple(index: int) -> void:
    var ratio: float = clampf(
        ripple_age[index]/(PULSE_LIFETIME*1.15),0.0,1.0)
    var progress: float = 1.0-ratio
    var radius: float = 0.75+progress*(2.4 if quality == 2 else 1.7)
    var pose := Transform3D(
        Basis().scaled(Vector3(radius,1.0,radius)),ripple_position[index])
    ripple.multimesh.set_instance_transform(index,pose)
    var tint: Color = TRACK_TINTS[
        clampi(game.selected_track,0,TRACK_TINTS.size()-1)]
    tint.a = 0.72*ratio*ratio
    ripple.multimesh.set_instance_color(index,tint)

func advance_visuals(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    for i in range(RIPPLE_POOL):
        if ripple_age[i] <= 0.0:
            continue
        ripple_age[i] = maxf(0.0,ripple_age[i]-delta)
        if ripple_age[i] == 0.0:
            _hide_ripple(i)
        elif quality > 0:
            _animate_ripple(i)
