extends Node3D
## Lightweight arcade race director: collidable timed hazards and earned clean
## passes. Real marbles and server authority decide the results; graphics never
## infer hits. Deterministic phases vary by biome and rematch variation.
# Three physical gates remain; their placement varies by biome and layout.
# All offsets are bounded away from shortcut entry and exit portals.
const EVENT_Z := [-34.0,-118.0,-154.0]
const LAYOUT_OFFSETS := [[0.0,0.0,0.0],[-4.0,5.0,-4.0],[4.0,-5.0,4.0]]
const BIOME_OFFSETS := [[0.0,0.0,0.0],[2.0,-2.0,3.0],[-2.0,3.0,-2.0]]
const EVENT_NAMES := ["SWEEPING ARM","ICE SHUTTER","FORGE PISTON"]
const EVENT_COLORS := [Color("#edbe72"),Color("#a5ecf4"),Color("#ff9c63")]
const BODY_WIDTH := 1.65
const BODY_HEIGHT := 0.82
const BODY_DEPTH := 0.76
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
const VERTICAL_CYCLE := 5.25
const VERTICAL_DUTY := 0.47

var game: Node3D
var biome := 0
var variation := 0
var obstacles: Array[AnimatableBody3D] = []
var warning_rings: Array[MeshInstance3D] = []
var signs: Array[Label3D] = []
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
    metal.albedo_color = EVENT_COLORS[biome].darkened(0.23)
    metal.metallic = 0.48
    metal.roughness = 0.29
    var glow := StandardMaterial3D.new()
    glow.albedo_color = EVENT_COLORS[biome]
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.emission_enabled = true
    glow.emission = EVENT_COLORS[biome]
    glow.emission_energy_multiplier = 0.65
    var mesh := BoxMesh.new()
    mesh.size = Vector3(BODY_WIDTH,BODY_HEIGHT,BODY_DEPTH)
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.88
    ring_mesh.outer_radius = 1.04
    ring_mesh.rings = 18
    ring_mesh.ring_segments = 7
    for i in range(EVENT_Z.size()):
        var z: float = event_z(i)
        var side: float = side_at(i)
        var x: float = game.track_center_at(z)+side*3.22
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
        shape.size = Vector3(BODY_WIDTH,BODY_HEIGHT,BODY_DEPTH)
        collider.shape = shape
        body.add_child(collider)
        var art := MeshInstance3D.new()
        art.name = "TimedObstacleArt"
        art.mesh = mesh
        art.material_override = metal
        art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        body.add_child(art)
        add_child(body)
        obstacles.append(body)
        var marker := MeshInstance3D.new()
        marker.name = "WarningHalo_%02d" % i
        marker.mesh = ring_mesh
        marker.material_override = glow
        marker.position = Vector3(x,game.height_at(z)+0.10,z)
        marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(marker)
        warning_rings.append(marker)
        var notice := Label3D.new()
        notice.name = "TimedHazardSign_%02d" % i
        notice.text = EVENT_NAMES[biome]
        notice.font_size = 30
        notice.pixel_size = 0.009
        notice.outline_size = 8
        notice.modulate = EVENT_COLORS[biome]
        notice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        notice.position = Vector3(x,game.height_at(z)+2.25,z)
        add_child(notice)
        signs.append(notice)
    ring_flash_end.resize(obstacles.size())
    ring_flash_strength.resize(obstacles.size())
    reset_round()

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

func event_z(index: int) -> float:
    return event_z_for(biome,variation,index)

func side_at(index: int) -> float:
    return -1.0 if (index+biome+variation)%2 == 0 else 1.0

func period() -> float:
    return SPEEDS[biome]

func phase_at(index: int, elapsed: float) -> float:
    return fposmod(elapsed+float(index)*1.71+float(variation)*1.29,period())/period()

func piston_extension(index: int, elapsed: float) -> float:
    if biome != 2:
        return 1.0
    var phase: float = phase_at(index,elapsed)
    if phase < 0.10:
        return smoothstep(0.0,0.10,phase)
    if phase < 0.34:
        return 1.0
    if phase < VERTICAL_DUTY:
        return 1.0-smoothstep(0.34,VERTICAL_DUTY,phase)
    return 0.0

func piston_up(index: int, elapsed: float) -> bool:
    return piston_extension(index,elapsed) > 0.43

func position_at(index: int, elapsed: float) -> Vector3:
    var z: float = event_z(index)
    var center: float = game.track_center_at(z)
    var side: float = side_at(index)
    var phase: float = phase_at(index,elapsed)
    if biome == 2:
        # Fully buried below the track when inactive. The circular warning
        # stays visible so competitors understand the timing of the piston.
        return Vector3(center+side*3.26,
            game.height_at(z)-1.08+1.48*piston_extension(index,elapsed),z)
    var radius: float = 0.85 if biome == 0 else 1.12
    return Vector3(center+side*(3.22+radius*sin(phase*TAU)),
        game.height_at(z)+0.42,z)

# The phone HUD uses the real collider trajectory, not just its biome phase.
# A gate that blocks the far outside lane must not warn someone safely on
# the centre line. The 0.40s lateral extrapolation is intentionally bounded:
# it accounts for ongoing drift without pretending to predict future taps.
const LANE_THREAT_RADIUS := BODY_WIDTH*0.5+0.39+0.18
const LANE_DRIFT_PREVIEW := 0.40

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
    var future_x: float = current_x+clampf(lateral_speed,-5.0,5.0)*(
        minf(eta,LANE_DRIFT_PREVIEW))
    return absf(future_x-obstacle_x) < LANE_THREAT_RADIUS

# Readable physical timing cues use the SAME deterministic clock as the
# collider and AI predictor. No new nodes, lights, materials or draw calls.
static func hazard_phase_cue(track: int, extension: float,
        lateral_speed: float) -> String:
    if track == 2:
        if extension < 0.15:
            return "OPEN"
        if extension < 0.57:
            return "RISING"
        return "BLOCKED"
    return "SWEEP LEFT" if lateral_speed < -0.05 else (
        "SWEEP RIGHT" if lateral_speed > 0.05 else "REVERSING")

func animate(elapsed: float) -> void:
    clock = maxf(0.0,elapsed)
    for i in range(obstacles.size()):
        var point: Vector3 = position_at(i,clock)
        obstacles[i].position = point
        warning_rings[i].position = Vector3(point.x,
            game.height_at(event_z(i))+0.10,event_z(i))
        var rising: bool = piston_up(i,clock)
        # Cheap, readable telegraph without realtime lights/shadows.
        var earned_flash := 0.0
        if clock < ring_flash_end[i]:
            earned_flash = ring_flash_strength[i]*(
                ring_flash_end[i]-clock)/PRECISION_FLASH_SECONDS
        # The existing three mobile rings briefly bloom after an actually
        # earned precision pass. No new meshes, lights, materials or drawcalls.
        warning_rings[i].scale = Vector3.ONE*(
            1.10+0.13*sin(clock*TAU/period()+float(i)*1.7)+
            0.48*earned_flash)
        warning_rings[i].visible = biome != 2 or rising or (
            phase_at(i,clock) > 0.78) or earned_flash > 0.0
        # Three existing world-space signs become a timing lesson rather
        # than a static name: players can time the opening at a glance.
        var lateral_speed: float = 0.0
        if biome != 2:
            lateral_speed = (position_at(i,clock+0.08).x-point.x)/0.08
        var cue: String = hazard_phase_cue(
            biome,piston_extension(i,clock),lateral_speed)
        var sign_text: String = EVENT_NAMES[biome]+" / "+cue
        if signs[i].text != sign_text:
            signs[i].text = sign_text
        signs[i].modulate.a = 0.86 if rising else 0.35
        signs[i].modulate = EVENT_COLORS[biome].lerp(
            Color("#b7f5cb"),0.36 if cue == "OPEN" else 0.0)
        signs[i].modulate.a = 0.86 if rising else 0.47

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

func event_ahead(z: float) -> Dictionary:
    var nearest: float = 24.0
    var result: Dictionary = {}
    for i in range(EVENT_Z.size()):
        var distance: float = z-event_z(i)
        if distance <= 0.0 or distance >= nearest:
            continue
        nearest = distance
        result = {"distance":maxi(0,int(round(distance))),
            "side":"LEFT" if side_at(i) < 0 else "RIGHT",
            "kind":EVENT_NAMES[biome],
            "index":i, "z":event_z(i),
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
