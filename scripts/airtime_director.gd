extends Node3D
## Real local marble flight and touchdown direction. This class is PURELY
## presentation: no velocity, position, score, purchases or server messages
## are written by it. One physics floor ray at ~20 Hz for only the local
## human, using an exclusion list built once per race (39 other marbles).
## No lights, postprocess, skeletal animations or per-marble VFX.
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const SHORTCUT = preload("res://scripts/shortcut_route.gd")
const SCULPTURE = preload("res://scripts/course_sculptures.gd")

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
const BRIDGE_PULSE_LIFETIME := 0.36
const GRIP_RETURN := 2
const BANK_EXIT := 3
const ICE_ENTRY := 4
const ICE_ENTRY_SECONDS := 0.42
const ICE_DRIFT_HOLD := 0.15
const LANDING_CONTROL := 1
const CONTROL_RETURN_SECONDS := 0.38
const RETURN_WINDOW := 0.36
const GLACIER_ICE_FRICTION := 0.15
const BRIDGE_TINTS := [
    Color("#ffc872"),Color("#a1f3ff"),Color("#ffa46e")
]
const TRACK_TINTS := [
    Color("#f5c48e"),Color("#98eaff"),Color("#ffa988")
]
enum Surface { OTHER, ROAD, BRIDGE }
enum Grip { UNKNOWN, DRY, ICE }

var game: Node3D
var ripple: MultiMeshInstance3D
var ripple_age: Array[float] = []
var ripple_position: Array[Vector3] = []
var ripple_normal: Array[Vector3] = []
var ripple_transition: Array[int] = []
var ripple_head := 0
var quality := 1
var ignored_rids: Array[RID] = []
var probe_clock := 0.0
var physics_probes := 0
var airborne := false
var course_grounded := false
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
var rolling_surface := Surface.OTHER
var pending_surface := Surface.OTHER
var bridge_grounded := false
var glacier_grip := Grip.UNKNOWN
var pending_grip := Grip.UNKNOWN
var ice_touching := false
var ice_skid := 0.0
var ice_slide_seen := false
var ice_entry_armed := false
var ice_entry_seconds := 0.0
var ice_drift_side := 0
var ice_drift_pending := 0
var ice_drift_hold := 0.0
var landing_pending := 0.0
var landing_pending_grade := ""
var pending_bank_exit := NAN
var last_contact_on_bank := false
var secure_contacts := 0
var control_return_seconds := 0.0
var jump_preview: Dictionary = {}

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
        ripple_normal.append(Vector3.UP)
        ripple_transition.append(0)
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
    course_grounded = false
    lost_contact = 0.0
    flight_time = 0.0
    peak_clearance = 0.0
    descent_speed = 0.0
    has_position = false
    probe_clock = 0.0
    _clear_rolling_surface()
    _clear_ice_feedback()
    landing_pending = 0.0
    landing_pending_grade = ""
    pending_bank_exit = NAN
    last_contact_on_bank = false
    secure_contacts = 0
    control_return_seconds = 0.0
    jump_preview.clear()

func _clear_rolling_surface() -> void:
    rolling_surface = Surface.OTHER
    pending_surface = Surface.OTHER
    bridge_grounded = false

func _clear_ice_feedback() -> void:
    glacier_grip = Grip.UNKNOWN
    pending_grip = Grip.UNKNOWN
    ice_touching = false
    ice_skid = 0.0
    ice_slide_seen = false
    ice_entry_armed = false
    ice_entry_seconds = 0.0
    _clear_ice_drift()

func reset_round() -> void:
    clear_motion()
    # A rematch must start the pooled ripples at the first instance again.
    # This also prevents frame and test ordering from affecting which slot
    # shows the next real touchdown.
    ripple_head = 0
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
        ripple_transition[i] = 0
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
        position: Vector3, velocity: Vector3, record_landing := true) -> Dictionary:
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
                if record_landing:
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
    var collider: StaticBody3D = hit["collider"]
    var material := collider.physics_material_override
    return {
        "touching":separation >= CONTACT_MIN and separation <= CONTACT_MAX,
        "clearance":maxf(0.0,separation-RADIUS),
        "ground":ground,
        "normal":hit["normal"],
        "bank_exit":collider.get_meta(SCULPTURE.BANK_EXIT_Z,NAN),
        "bridge":collider.has_meta(SHORTCUT.ROLLING_SURFACE),
        "ice":game.selected_track == 1 and material != null and material.friction <= GLACIER_ICE_FRICTION
    }

func _is_main_road(ground: Vector3) -> bool:
    return absf(ground.x-game.track_center_at(ground.z)) < 6.6 and (
        absf(ground.y-game.height_at(ground.z)) < 0.38)

func sample_rolling_surface(hit: Dictionary, position: Vector3) -> int:
    if not _near_bridge(position.z):
        _clear_rolling_surface()
        return 0
    var surface := Surface.OTHER
    if hit.get("touching",false):
        if hit.get("bridge",false):
            surface = Surface.BRIDGE
        elif _is_main_road(hit["ground"]):
            surface = Surface.ROAD
    bridge_grounded = surface == Surface.BRIDGE and rolling_surface == Surface.BRIDGE
    # A seam, hop or single ray on the other deck must not switch materials.
    if surface == Surface.OTHER or surface != pending_surface:
        pending_surface = surface
        return 0
    var previous := rolling_surface
    rolling_surface = surface
    bridge_grounded = surface == Surface.BRIDGE
    if previous == Surface.OTHER or previous == surface:
        return 0
    return 1 if bridge_grounded else -1

func _near_bridge(z: float) -> bool:
    return z <= SHORTCUT.ENTRY_Z+5.0 and z >= SHORTCUT.EXIT_Z-7.0

func sample_ice_contact(hit: Dictionary, position: Vector3, velocity: Vector3, delta: float) -> int:
    var grip := Grip.UNKNOWN
    if hit.get("touching",false):
        if hit.get("ice",false):
            grip = Grip.ICE
        elif hit.get("bridge",false) or _is_main_road(hit["ground"]):
            grip = Grip.DRY
    var change := 0
    if grip != Grip.UNKNOWN and grip == pending_grip and grip != glacier_grip:
        if grip == Grip.ICE and ice_entry_armed and -velocity.z >= 6.0:
            change = ICE_ENTRY
        elif grip == Grip.DRY and glacier_grip == Grip.ICE and ice_slide_seen and -velocity.z >= 3.0:
            change = GRIP_RETURN
        glacier_grip = grip
        if grip == Grip.DRY:
            ice_slide_seen = false
    if grip != Grip.ICE:
        ice_entry_armed = grip == Grip.DRY and glacier_grip == Grip.DRY
        ice_entry_seconds = 0.0
    elif glacier_grip == Grip.ICE:
        ice_entry_armed = false
    pending_grip = grip
    ice_touching = grip == Grip.ICE and glacier_grip == Grip.ICE
    ice_skid = 0.0
    if ice_touching:
        var slope: float
        if hit.get("bridge",false):
            slope = game.shortcut_route.point_at(position.z+0.5).x-game.shortcut_route.point_at(position.z-0.5).x
        else:
            slope = game.track_center_at(position.z+0.5)-game.track_center_at(position.z-0.5)
        var sideways := velocity.x-slope*velocity.z
        ice_skid = smoothstep(0.55,3.4,absf(sideways))*smoothstep(3.0,9.0,-velocity.z)
        ice_slide_seen = ice_slide_seen or ice_skid >= 0.12
        _sample_ice_drift(sideways,-velocity.z,delta)
    else:
        _clear_ice_drift()
    return change

func _sample_ice_drift(sideways: float, forward: float, delta: float) -> void:
    var side := int(signf(sideways))
    # Once shown, allow a little speed loss before dropping a same-side arrow.
    if side == ice_drift_side and side != 0 and absf(sideways) >= 0.80 and forward >= 5.0:
        return
    ice_drift_side = 0
    if absf(sideways) < 1.25 or forward < 6.0:
        _clear_ice_drift()
        return
    if side != ice_drift_pending:
        ice_drift_pending = side
        ice_drift_hold = 0.0
    ice_drift_hold += delta
    if ice_drift_hold >= ICE_DRIFT_HOLD:
        ice_drift_side = side

func _clear_ice_drift() -> void:
    ice_drift_side = 0
    ice_drift_pending = 0
    ice_drift_hold = 0.0

func ice_entry_weight() -> float:
    return ice_entry_seconds/ICE_ENTRY_SECONDS

func sample_control_contact(delta: float, hit: Dictionary, position: Vector3,
        velocity: Vector3) -> int:
    landing_pending = maxf(0.0,landing_pending-delta)
    if is_finite(pending_bank_exit) and position.z < pending_bank_exit-6.0:
        pending_bank_exit = NAN
    var bank_exit := float(hit.get("bank_exit",NAN))
    var touching := bool(hit.get("touching",false))
    var on_bank := touching and is_finite(bank_exit)
    if on_bank != last_contact_on_bank:
        secure_contacts = 0
        last_contact_on_bank = on_bank
    if on_bank and velocity.z <= -MIN_LANDING_FORWARD:
        pending_bank_exit = bank_exit
    var road_contact: bool = touching and (on_bank or hit.get("bridge",false) or _is_main_road(hit["ground"]))
    if not road_contact or velocity.z > -MIN_LANDING_FORWARD or (
            absf(velocity.x) > maxf(2.4,-velocity.z*0.42)):
        secure_contacts = 0
        return 0
    secure_contacts = mini(2,secure_contacts+1)
    if secure_contacts < 2:
        return 0
    if landing_pending > 0.0:
        landing_pending = 0.0
        control_return_seconds = CONTROL_RETURN_SECONDS
        if not on_bank:
            pending_bank_exit = NAN
        return LANDING_CONTROL
    if not on_bank and is_finite(pending_bank_exit):
        var exited := position.z <= pending_bank_exit+0.4
        pending_bank_exit = NAN
        if exited:
            control_return_seconds = CONTROL_RETURN_SECONDS
            return BANK_EXIT
    return 0

func control_weight() -> float:
    return control_return_seconds/CONTROL_RETURN_SECONDS

func tick_physics(delta: float) -> void:
    if not is_instance_valid(game) or game.race_state != "RACING" or (
            not is_instance_valid(game.player) or
            game.player.finished or
            game.player.eliminated or game.net.role == "server"):
        return
    var position: Vector3 = game.player.global_position
    var replica: bool = game.net.is_client()
    var glacier: bool = game.selected_track == 1
    var velocity: Vector3 = game.player.linear_velocity
    if replica:
        velocity = game.net.local_replica_velocity()
        if not velocity.is_finite():
            clear_motion()
            return
    elif game.player.freeze:
        return
    probe_clock += delta
    if probe_clock < SAMPLE_PERIOD:
        return
    var dt: float = probe_clock
    probe_clock = 0.0
    var hit: Dictionary = probe_floor(game.player)
    if hit.is_empty():
        course_grounded = false
        return
    course_grounded = bool(hit["touching"]) and (
        hit.get("bridge",false) or is_finite(hit.get("bank_exit",NAN)) or _is_main_road(hit["ground"]))
    var event := sample_motion(dt,bool(hit["touching"]),float(hit["clearance"]),position,velocity,not replica)
    if game.cam_mode == 0 and (hit["touching"] or airborne):
        var bridge: bool = hit.get("bridge",false) or (
            airborne and game.shortcut_route.on_separate_deck(position))
        jump_preview = game.jump_guides.preview(position,velocity,bridge,airborne)
    else:
        jump_preview.clear()
    var transition := sample_rolling_surface(hit,position)
    var ice_transition := sample_ice_contact(hit,position,velocity,dt) if glacier else 0
    if not event.is_empty():
        _show_landing(event,not replica)
    var control := sample_control_contact(dt,hit,position,velocity)
    if control != 0:
        if control == BANK_EXIT:
            game.audio.play_bank_exit()
        if quality > 0:
            var grade := landing_pending_grade if control == LANDING_CONTROL else ""
            _emit_ripple(hit["ground"],grade,BANK_EXIT if control == BANK_EXIT else 0,hit["normal"])
    elif ice_transition != 0 and event.is_empty():
        if ice_transition == ICE_ENTRY:
            ice_entry_seconds = ICE_ENTRY_SECONDS
            game.audio.play_ice_entry()
        else:
            game.audio.play_grip_return()
        if quality > 0:
            _emit_ripple(hit["ground"],"",ice_transition,hit["normal"])
    elif transition != 0 and quality > 0 and event.is_empty() and (
            Vector2(velocity.x,velocity.z).length_squared() >= 9.0):
        _emit_ripple(hit["ground"],"",transition,hit["normal"])

func camera_weight() -> float:
    if not airborne:
        return 0.0
    return clampf((flight_time-TAKEOFF_GRACE)/0.26,0.0,1.0)

func _show_landing(event: Dictionary, announce := true) -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    var grade: String = event["grade"]
    var seconds: float = event["seconds"]
    if announce:
        game.ui.show_race_moment("%s  •  %.2fs" % [grade,seconds],
            1.35 if grade == "BIG AIR" else 1.1)
    game.audio.touchdown(grade,float(event["impact"]))
    landing_pending = RETURN_WINDOW
    landing_pending_grade = grade
    secure_contacts = 0
    game.camera_shake = minf(0.105,maxf(game.camera_shake,
        0.075 if grade == "BIG AIR" else 0.042))

func _emit_ripple(ground_point: Vector3, grade: String, transition := 0,
        normal := Vector3.UP) -> void:
    var index: int = ripple_head
    ripple_head = (ripple_head+1)%RIPPLE_POOL
    ripple_transition[index] = transition
    ripple_age[index] = BRIDGE_PULSE_LIFETIME if transition != 0 else PULSE_LIFETIME
    ripple_normal[index] = normal
    ripple_position[index] = ground_point+normal*0.065
    if grade == "BIG AIR":
        ripple_age[index] = PULSE_LIFETIME*1.15
    _animate_ripple(index)

func _animate_ripple(index: int) -> void:
    var transition: int = ripple_transition[index]
    var lifetime := BRIDGE_PULSE_LIFETIME if transition != 0 else PULSE_LIFETIME*1.15
    var ratio: float = clampf(
        ripple_age[index]/lifetime,0.0,1.0)
    var progress: float = 1.0-ratio
    var radius: float = 0.75+progress*(2.4 if quality == 2 else 1.7)
    if transition != 0:
        radius = 0.77+progress*0.94
    var floor_plane := Basis(Quaternion(Vector3.UP,ripple_normal[index]))
    var pose := Transform3D(floor_plane.scaled_local(Vector3(radius,1.0,radius)),ripple_position[index])
    ripple.multimesh.set_instance_transform(index,pose)
    var biome := clampi(game.selected_track,0,TRACK_TINTS.size()-1)
    var tint: Color = BRIDGE_TINTS[biome] if transition == 1 else TRACK_TINTS[biome]
    if transition == GRIP_RETURN:
        tint = Color("#ffe3a8")
    elif transition == BANK_EXIT:
        tint = BRIDGE_TINTS[biome].lightened(0.28)
    elif transition == ICE_ENTRY:
        tint = Color("#36bcf1")
    tint.a = (0.89 if transition != 0 else 0.72)*ratio*ratio
    ripple.multimesh.set_instance_color(index,tint)

func advance_visuals(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    control_return_seconds = maxf(0.0,control_return_seconds-delta)
    ice_entry_seconds = maxf(0.0,ice_entry_seconds-delta)
    for i in range(RIPPLE_POOL):
        if ripple_age[i] <= 0.0:
            continue
        ripple_age[i] = maxf(0.0,ripple_age[i]-delta)
        if ripple_age[i] == 0.0:
            _hide_ripple(i)
        elif quality > 0:
            _animate_ripple(i)
