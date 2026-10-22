extends RefCounted
## Solo racecraft: earn a small, physical slipstream reward by following a
## moving opponent on the same 3D road. Never teleport, change opponent
## physics, or grant client-side multiplayer velocity/boost authority.
## Broad-phase checks are shared with a throttled 7Hz sampling cadence.
const SAMPLE_PERIOD := 0.14
const MIN_FORWARD_SPEED := 6.0
const LEADER_FORWARD_SPEED := 6.0
const MIN_GAP := 2.2
const MAX_GAP := 10.0
const MAX_LATERAL := 1.65
const MAX_VERTICAL := 1.30
const LOCK_SECONDS := 0.42
const RECOVERY_PER_SECOND := 0.095
const FORWARD_FORCE := 1.85

var sample_remaining := 0.0
var contact_seconds := 0.0
var strength := 0.0
var scanned_last := 0

func reset_round() -> void:
    sample_remaining = 0.0
    contact_seconds = 0.0
    strength = 0.0
    scanned_last = 0

static func draft_score(racer: RigidBody3D, rivals: Array[RigidBody3D]) -> float:
    if not is_instance_valid(racer) or racer.finished or racer.eliminated or (
        racer.freeze or racer.linear_velocity.z >= -MIN_FORWARD_SPEED):
        return 0.0
    var speed_factor: float = clampf(
        (-racer.linear_velocity.z-MIN_FORWARD_SPEED)/7.0,0.0,1.0)
    var best := 0.0
    for rival in rivals:
        if not is_instance_valid(rival) or rival == racer or (
            rival.finished or rival.eliminated or rival.freeze or
            rival.linear_velocity.z >= -LEADER_FORWARD_SPEED):
            continue
        # The road follows -Z. These constant-time checks reject almost all
        # of the 39 bodies before computing any smooth proximity falloff.
        var gap: float = racer.global_position.z-rival.global_position.z
        if gap <= MIN_GAP or gap >= MAX_GAP:
            continue
        var lateral: float = absf(racer.global_position.x-rival.global_position.x)
        var vertical: float = absf(racer.global_position.y-rival.global_position.y)
        if lateral >= MAX_LATERAL or vertical >= MAX_VERTICAL:
            continue
        var nose: float = smoothstep(MIN_GAP,4.0,gap)
        var tail: float = 1.0-smoothstep(7.2,MAX_GAP,gap)
        var lane: float = 1.0-smoothstep(0.3,MAX_LATERAL,lateral)
        var height: float = 1.0-smoothstep(0.65,MAX_VERTICAL,vertical)
        best = maxf(best,nose*tail*lane*height*speed_factor)
    return best

func tick(delta: float, racer: RigidBody3D,
        rivals: Array[RigidBody3D]) -> float:
    var seconds: float = clampf(delta,0.0,0.20)
    sample_remaining -= seconds
    if sample_remaining > 0.0:
        return strength
    sample_remaining = SAMPLE_PERIOD
    var candidate: float = draft_score(racer,rivals)
    scanned_last += 1
    if candidate > 0.35:
        contact_seconds = minf(1.25,contact_seconds+SAMPLE_PERIOD)
    else:
        contact_seconds = maxf(0.0,contact_seconds-2.0*SAMPLE_PERIOD)
    # A split-second overlap is not a free turbo. A sustained pursuit
    # charges smoothly and dissipates quickly after losing the lead marble.
    var lock: float = clampf((contact_seconds-LOCK_SECONDS)/0.36,0.0,1.0)
    strength = candidate*lock
    return strength
