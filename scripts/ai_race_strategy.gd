extends RefCounted
## Lightweight deterministic line planning; never writes transforms.
## Used only for server/offline AI, never on human-controlled marbles.
const LOOKAHEAD_METERS := 22.0
const BYPASS_LOOKAHEAD := 5.8
const EARLY_LANE_OFFSET := 5.15
const BYPASS_LATERAL_FORCE := 18.0
const TRAFFIC_SCAN_PERIOD := 0.34
const TRAFFIC_AHEAD := 8.0
const TRAFFIC_WIDTH := 1.25
const TRAFFIC_HEIGHT := 1.45
const TRAFFIC_SAFE_LANE := 3.15

static func temperament(racer_id: int, track: int, variation: int) -> int:
    # Three predictable driving attitudes, redistributed per track/rematch:
    # 0 defensive, 1 balanced, 2 opportunistic. No random client input.
    return posmod(racer_id*7 + track*5 + variation*4,3)

static func _lane_occupancy(target_x: float, own: RigidBody3D,
    rivals: Array[RigidBody3D]) -> float:
    var penalty := 0.0
    for other in rivals:
        if other == own or not is_instance_valid(other) or (
            other.finished or other.eliminated):
            continue
        var dz: float = absf(other.position.z-own.position.z)
        var dy: float = absf(other.position.y-own.position.y)
        if dz > 5.5 or dy > TRAFFIC_HEIGHT:
            continue
        # A rival changing lanes is dangerous before its current sphere
        # overlaps the intended corridor. Predict only a short, bounded
        # window from authoritative velocity; no physics or RNG is added.
        var current_dx: float = absf(other.position.x-target_x)
        var predicted_x: float = other.position.x+clampf(
            other.linear_velocity.x,-5.0,5.0)*0.42
        var future_dx: float = absf(predicted_x-target_x)
        var dx: float = minf(current_dx,future_dx)
        if dx < 1.10:
            penalty += (1.10-dx)*2.4*(
                1.0-clampf(dz/5.5,0.0,1.0))
            # A faster racer approaching from behind has right of way.
            # Avoid cutting across their lane even if they are still
            # several metres back. Uses only existing velocity snapshots.
            var behind: float = other.position.z-own.position.z
            var closing_speed: float = own.linear_velocity.z-other.linear_velocity.z
            if behind > 0.0 and closing_speed > 2.0:
                var time_to_contact: float = behind/closing_speed
                penalty += (1.10-dx)*clampf(
                    (1.5-time_to_contact)/1.5,0.0,1.0)*4.5
    return penalty

static func traffic_lane(own: RigidBody3D, rivals: Array[RigidBody3D],
    center_x: float, preferred_offset: float, temperament_id: int) -> float:
    # Called at most 3x/s per AI, *only* by the authoritative simulator.
    # Compare two physical side corridors before choosing an overtaking line.
    # Do not apply any impulses or manipulate positions/finishing times here.
    var preferred: float = clampf(preferred_offset,
        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    var desired_x: float = center_x+preferred
    var leader: RigidBody3D = null
    var nearest_gap := INF
    for other in rivals:
        if other == own or not is_instance_valid(other) or (
            other.finished or other.eliminated):
            continue
        var ahead: float = own.position.z-other.position.z
        if ahead < 0.65 or ahead > TRAFFIC_AHEAD:
            continue
        if absf(other.position.y-own.position.y) > TRAFFIC_HEIGHT or (
            absf(other.position.x-desired_x) > TRAFFIC_WIDTH):
            continue
        # A faster marble approaching from behind is not an obstruction.
        var speed_gain: float = other.linear_velocity.z-own.linear_velocity.z
        if speed_gain < 0.4 and ahead > 2.5:
            continue
        if ahead < nearest_gap:
            leader = other
            nearest_gap = ahead
    if leader == null:
        return preferred
    # Keep both choices inside the physical rail margins: close-to-wall
    # candidates are penalized even if their projected path looks empty.
    var lead_offset: float = leader.position.x-center_x
    var left: float = clampf(lead_offset-1.55,-TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    var right: float = clampf(lead_offset+1.55,-TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    var cautious: float = [1.0,0.65,0.38][clampi(temperament_id,0,2)]
    var left_cost: float = absf(left-preferred)*cautious+(
        absf(left)/TRAFFIC_SAFE_LANE)*0.45+(
        _lane_occupancy(center_x+left,own,rivals))
    var right_cost: float = absf(right-preferred)*cautious+(
        absf(right)/TRAFFIC_SAFE_LANE)*0.45+(
        _lane_occupancy(center_x+right,own,rivals))
    # The stable tie-break lets traffic patterns vary with AI personality
    # without RNG state or per-frame unpredictable lane flips.
    var choose_left: bool = left_cost < right_cost if (
        absf(left_cost-right_cost) > 0.01) else own.racer_id%2 == 0
    return left if choose_left else right



# The timed gate moves during a marble's approach. Evaluate where the *real
# collidable body* will be at arrival, rather than dodging its current mesh.
# Return the preferred offset unchanged when the line remains safe. This is
# used only by server/offline AI after the shortcut merges; players always
# keep full manual steering authority.
const GATE_LOOKAHEAD := 20.0
# Maintain the avoidance line through the collider's full longitudinal
# footprint. Otherwise a bot snaps back to its original lane at 1m and
# clips the moving gate precisely as its marble reaches the obstacle.
const GATE_MIN_DISTANCE := -1.25
const GATE_CLEARANCE := 1.80
const GATE_ESCAPE_CLEARANCE := 2.35

static func timed_gate_safe_lane(director: Node3D, own_z: float,
    own_speed_z: float, elapsed: float, preferred_offset: float) -> float:
    var preferred: float = clampf(preferred_offset,
        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    if not is_instance_valid(director) or not is_instance_valid(director.game):
        return preferred
    for index in range(director.obstacles.size()):
        var gate_z: float = director.event_z(index)
        var distance: float = own_z-gate_z
        if distance < GATE_MIN_DISTANCE or distance > GATE_LOOKAHEAD:
            continue
        var speed: float = clampf(-own_speed_z,6.0,24.0)
        var arrive_at: float = elapsed+distance/speed
        # An inactive piston is below the deck and does not block passage.
        # Evaluate its predicted rise, not whether it happens to be up now.
        if director.biome == 2 and not director.piston_up(index,arrive_at):
            # This gate is buried at arrival, but a second gate farther
            # down the road may still be active. Do not stop the scan.
            continue
        var next_position: Vector3 = director.position_at(index,arrive_at)
        var track_center: float = director.game.track_center_at(gate_z)
        var obstacle_offset: float = next_position.x-track_center
        if absf(preferred-obstacle_offset) >= GATE_CLEARANCE:
            return preferred
        # Passing on the interior side of a timed gate leaves the outer
        # shoulder free, avoids the physical edge shutters and respects rails.
        var safe_offset: float = obstacle_offset-signf(obstacle_offset)*(
            GATE_ESCAPE_CLEARANCE)
        return clampf(safe_offset,-TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    return preferred


static func pursue_bypass(z: float, entered: bool, entry_z: float,
    exit_z: float, entry_window: float) -> bool:
    if z >= entry_z+LOOKAHEAD_METERS or z <= exit_z-4.0:
        return false
    # Once the entry portal is behind a bot that did not make the fork,
    # abandon the impossible road instead of hitting the outer railing.
    return entered or z >= entry_z-entry_window+1.0

static func bypass_target_x(road: Node3D, z: float) -> float:
    var aim_z: float = maxf(road.EXIT_Z,z-BYPASS_LOOKAHEAD)
    if z > road.ENTRY_Z+4.0:
        # Get into position inside the rails, rather than aiming through a
        # closed barrier before the opening appears.
        # On Glacier's low-grip approach, build lane commitment earlier,
        # but stay under the actual 6.16 m interior rail clearance.
        var approach_offset: float = EARLY_LANE_OFFSET+(
            0.60 if road.course_id == 1 else 0.0)
        return road.stage.track_center_at(aim_z)+float(road.side)*approach_offset
    return road.point_at(aim_z).x

static func inside_shortcut_gate(road: Node3D, position: Vector3) -> bool:
    # The center rail has a genuine opening in section 5, and this is
    # the only place a shortcut bot may temporarily pass the usual 4.7m
    # inward-recovery threshold. The solid world still decides movement.
    if position.z > road.ENTRY_Z+5.0 or position.z < road.ENTRY_Z-road.ENTRY_WINDOW:
        return false
    var relative: float = float(road.side)*(
        position.x-road.stage.track_center_at(position.z))
    return relative > 3.20 and relative < 9.20

static func bypass_steering(target_x: float, current_x: float,
    side_velocity: float, on_ice: bool = false) -> float:
    # A deterministic racing-line skill, never position manipulation.
    # Glacier specialists need human-like steering strength to counter
    # reduced grip and make the very short *real* opening in time.
    var displacement: float = target_x-current_x
    var gain: float = 5.0 if on_ice else 3.25
    var damping: float = 0.85 if on_ice else 1.05
    var force_limit: float = 27.0 if on_ice else BYPASS_LATERAL_FORCE
    return clampf(displacement*gain-side_velocity*damping,
        -force_limit,force_limit)

static func baffle_dodge(position: Vector3, center_x: float) -> float:
    # Physical outer shutters begin around relative |x|=3.8. A modest
    # inward force when approaching one prevents repeated rail pinning.
    # O(1) by exploiting the repeatable 12m module grid.
    var relative_x: float = position.x-center_x
    if absf(relative_x) < 3.1:
        return 0.0
    var nearest_section: int = clampi(
        int(round((8.0-position.z)/12.0)),1,14)
    var strongest := 0.0
    for section in range(maxi(1,nearest_section-1),mini(15,nearest_section+2)):
        var section_z: float = 8.0-float(section)*12.0
        var shutter_z: float = section_z + (3.75 if relative_x < 0.0 else -3.75)
        var distance: float = position.z-shutter_z
        if distance >= 0.0 and distance <= 9.0:
            strongest = maxf(strongest,1.0-distance/9.0)
    return -signf(relative_x)*7.5*strongest
