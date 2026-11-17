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
const GLACIER_PASS_OFFSET := 1.75
const ZONE_MECHANICS = preload("res://scripts/course_mechanics.gd")

static func temperament(racer_id: int, track: int, variation: int) -> int:
    # Three predictable driving attitudes, redistributed per track/rematch:
    # 0 defensive, 1 balanced, 2 opportunistic. No random client input.
    return posmod(racer_id*7 + track*5 + variation*4,3)

static func _lane_occupancy(target_x: float, own: RigidBody3D,
    rivals: Array[RigidBody3D], sweep_crossings := false) -> float:
    var penalty := 0.0
    var origin := own.position
    var own_speed_z := own.linear_velocity.z
    for other in rivals:
        if other == own or not is_instance_valid(other) or (
            other.finished or other.eliminated):
            continue
        var other_at := other.position
        var behind := other_at.z-origin.z
        var dz := absf(behind)
        if dz > 5.5 or absf(other_at.y-origin.y) > TRAFFIC_HEIGHT:
            continue
        # A rival changing lanes is dangerous before its current sphere
        # overlaps the intended corridor. Predict only a short, bounded
        # window from authoritative velocity; no physics or RNG is added.
        var other_speed := other.linear_velocity
        var current_dx: float = absf(other_at.x-target_x)
        var predicted_x: float = other_at.x+clampf(
            other_speed.x,-5.0,5.0)*0.42
        var future_dx: float = absf(predicted_x-target_x)
        var dx: float = minf(current_dx,future_dx)
        if sweep_crossings:
            # A sideways rival can cross the line between both samples.
            var crossed_x := clampf(target_x,minf(other_at.x,predicted_x),
                maxf(other_at.x,predicted_x))
            dx = absf(crossed_x-target_x)
        if dx < 1.10:
            penalty += (1.10-dx)*2.4*(
                1.0-clampf(dz/5.5,0.0,1.0))
            # A faster racer approaching from behind has right of way.
            # Avoid cutting across their lane even if they are still
            # several metres back. Uses only existing velocity snapshots.
            var closing_speed := own_speed_z-other_speed.z
            if behind > 0.0 and closing_speed > 2.0:
                var time_to_contact: float = behind/closing_speed
                penalty += (1.10-dx)*clampf(
                    (1.5-time_to_contact)/1.5,0.0,1.0)*4.5
    return penalty

# A rival cutting laterally into the same narrow racing corridor deserves
# a measured evasive line. Read existing velocity snapshots only during the
# already throttled AI traffic scan; never change a player's input, velocity,
# body position, or checkpoint/finish state.
const DUEL_Z_WINDOW := 2.4
const DUEL_Y_WINDOW := 1.25
const DUEL_FUTURE_SECONDS := 0.38
const DUEL_SEPARATION := 1.02
const DUEL_YIELD := 1.35

static func side_duel_safe_lane(own: RigidBody3D,
    rivals: Array[RigidBody3D], preferred_offset: float,
    center_x: float) -> float:
    var preferred: float = clampf(preferred_offset,
        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    if not is_instance_valid(own):
        return preferred
    var origin := own.position
    var own_speed_x := own.linear_velocity.x
    for other in rivals:
        if not is_instance_valid(other) or other == own or (
            other.finished or other.eliminated or other.freeze):
            continue
        var other_at := other.position
        var dz := absf(other_at.z-origin.z)
        if dz > DUEL_Z_WINDOW or absf(other_at.y-origin.y) > DUEL_Y_WINDOW:
            continue
        var dx: float = other_at.x-origin.x
        if absf(dx) < 0.72 or absf(dx) > 2.75:
            continue
        var relative_x_speed: float = other.linear_velocity.x-own_speed_x
        # If lateral separation will not close, a harmless parallel duel
        # cannot make the bot suddenly weave or obstruct the human.
        if relative_x_speed*signf(dx) > -0.45:
            continue
        var projected_dx: float = dx+clampf(relative_x_speed,-6.0,6.0)*(
            DUEL_FUTURE_SECONDS)
        if absf(projected_dx) >= DUEL_SEPARATION or (
            signf(projected_dx) != signf(dx)):
            continue
        var alternative: float = clampf(preferred-signf(dx)*DUEL_YIELD,
            -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
        # Only yield if the rival is closer to the proposed lane than the
        # old lane, and the change actually opens useful physical space.
        var current_gap: float = absf(other_at.x-(center_x+preferred))
        var improved_gap: float = absf(other_at.x-(center_x+alternative))
        if improved_gap >= current_gap+0.45 and (
            absf(alternative-preferred) >= 0.55):
            return alternative
    return preferred

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
    var origin := own.position
    var own_speed_z := own.linear_velocity.z
    for other in rivals:
        if other == own or not is_instance_valid(other) or (
            other.finished or other.eliminated):
            continue
        var other_at := other.position
        var ahead := origin.z-other_at.z
        if ahead < 0.65 or ahead > TRAFFIC_AHEAD:
            continue
        if absf(other_at.y-origin.y) > TRAFFIC_HEIGHT or (
            absf(other_at.x-desired_x) > TRAFFIC_WIDTH):
            continue
        # A faster marble approaching from behind is not an obstruction.
        var speed_gain: float = other.linear_velocity.z-own_speed_z
        if speed_gain < 0.4 and ahead > 2.5:
            continue
        if ahead < nearest_gap:
            leader = other
            nearest_gap = ahead
    if leader == null:
        return side_duel_safe_lane(own,rivals,preferred,center_x)
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



# All three biomes have meaningful racing-line zones: earn genuine speed on
# Woodland, preserve grip on Glacier and avoid a Forge eruption at ARRIVAL.
# Five static stations are read from the actual built layout, not an invented
# map or an extra per-racer physics query. Only authoritative AI uses this.
const ZONE_LOOKAHEAD := 14.0
const ZONE_MIN_DISTANCE := -0.8
const ZONE_AVOID_MARGIN := 0.58

static func biome_zone_safe_lane(mechanics: Node3D, own_z: float,
    speed_z: float, preferred_offset: float, temperament_id: int) -> float:
    var preferred: float = clampf(preferred_offset,
        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    if not is_instance_valid(mechanics) or not is_instance_valid(mechanics.game):
        return preferred
    var course: int = mechanics.track_id
    if (course == 0 and temperament_id != 2) or (course == 1 and temperament_id != 0):
        return preferred

    var zones: Array[Node3D] = mechanics.zones
    for index in range(zones.size()):
        # The physical zones are built at these fixed Z positions in this order.
        var dz: float = own_z-ZONE_MECHANICS.ZONE_Z[index]
        if dz > ZONE_LOOKAHEAD:
            break
        if dz < ZONE_MIN_DISTANCE or not is_instance_valid(zones[index]):
            continue

        var offset: float = ZONE_MECHANICS.lane_offset(index,course,mechanics.variation)
        var clearance: float = absf(preferred-offset)
        match course:
            0:
                # Opportunists must still touch the strip to earn its impulse.
                if dz >= 2.0 and clearance < 2.8:
                    return clampf(offset-signf(offset)*0.63,
                        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
            1:
                var margin := ZONE_MECHANICS.ZONE_WIDTH*0.5+ZONE_AVOID_MARGIN
                if clearance < margin:
                    return clampf(offset-signf(offset)*margin,
                        -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
            2:
                if clearance < 1.95:
                    # Use the authoritative eruption phase at predicted arrival.
                    var speed := clampf(-speed_z,6.0,24.0)
                    var eta := maxf(0.0,dz)/speed
                    if mechanics.vent_active(index,mechanics.race_clock+eta):
                        return clampf(offset-signf(offset)*2.55,
                            -TRAFFIC_SAFE_LANE,TRAFFIC_SAFE_LANE)
    return preferred


# The returning deck is already close to track height before the rider is
# in the bot's lane. Forecast when those paths first come within one lane.
static func glacier_merge_drive(own: RigidBody3D, rivals: Array[RigidBody3D],
        route: Node3D, drive_force: float) -> float:
    var entries: Dictionary = route.entered
    var bridge_side: float = route.side
    var exit_z: float = route.EXIT_Z
    var origin := own.position
    var velocity := own.linear_velocity
    var speed := -velocity.z
    # Racers are indexed by slot in the authoritative race roster.
    for slot: int in entries:
        if slot < 0 or slot >= rivals.size():
            continue
        var other := rivals[slot]
        if not is_instance_valid(other) or other.freeze or other.finished or other.eliminated or (
                not other.is_player and not other.network_controlled):
            continue
        var other_at := other.position
        if other_at.z > exit_z+2.0 or absf(other_at.y-origin.y) > TRAFFIC_HEIGHT:
            continue
        var lateral_gap := (other_at.x-origin.x)*bridge_side
        var other_velocity := other.linear_velocity
        var inward_speed := (velocity.x-other_velocity.x)*bridge_side
        if lateral_gap <= 0.0 or inward_speed < 1.6:
            continue
        var time_to_merge := maxf(0.0,(lateral_gap-1.0)/inward_speed)
        if time_to_merge > 0.48:
            continue
        var gap := origin.z-other_at.z
        var other_speed := -other_velocity.z
        var closing := speed-other_speed
        var merge_gap := gap-closing*time_to_merge
        # Do not brake a bot that will already be through the crossing.
        if gap <= 0.65 or closing <= 0.75 or merge_gap < -0.70 or merge_gap > 2.4:
            continue
        # Leave room as the second line converges, with a bounded force.
        var safe_speed := maxf(1.0,other_speed+(gap-2.0)/maxf(0.24,time_to_merge))
        drive_force = minf(drive_force,maxf(-22.0,(safe_speed-speed)*10.0))
    return drive_force

# A late cut-in can leave a passing bot alongside the bridge rider.
# Detect closing paths before the ordinary lane occupancy scan runs again.
static func glacier_pass_cut_in(own: RigidBody3D, rivals: Array[RigidBody3D],
        entries: Dictionary, target_x: float) -> RigidBody3D:
    var origin := own.position
    for slot: int in entries:
        if slot < 0 or slot >= rivals.size():
            continue
        var rider := rivals[slot]
        if not is_instance_valid(rider) or rider == own or rider.freeze or rider.finished or (
                rider.eliminated or (not rider.is_player and not rider.network_controlled)):
            continue
        var rider_at := rider.position
        var lateral := rider_at.x-target_x
        var inward_speed := -signf(lateral)*rider.linear_velocity.x
        var gap: float = origin.z-rider_at.z
        if gap < -0.9 or gap > 5.0 or absf(rider_at.y-origin.y) > TRAFFIC_HEIGHT:
            continue
        if absf(lateral) > 0.7 and inward_speed >= 1.0 and absf(lateral)-inward_speed*0.42 < 0.85:
            return rider
    return null


# Track the nearest same-level rival in the bot's current line. The
# caller scans at the ordinary traffic cadence and keeps the body reference
# so closing distance and relative speed can be checked every physics tick.
static func glacier_return_leader(own: RigidBody3D, rivals: Array[RigidBody3D],
        return_x := INF) -> RigidBody3D:
    var nearest: RigidBody3D
    var nearest_gap := 10.0
    var origin := own.position
    for other in rivals:
        if other == own or not is_instance_valid(other) or (
            other.finished or other.eliminated or other.freeze):
            continue
        var other_at := other.position
        var ahead := origin.z-other_at.z
        if ahead > 0.0 and ahead < nearest_gap and _glacier_lane_contains(origin,other_at,return_x):
            nearest_gap = ahead
            nearest = other
    return nearest

static func glacier_leader_in_line(own: RigidBody3D, other: RigidBody3D,
        return_x := INF) -> bool:
    if other == own or other.finished or other.eliminated or other.freeze:
        return false
    var origin := own.position
    var other_at := other.position
    return origin.z-other_at.z > 0.0 and _glacier_lane_contains(origin,other_at,return_x)

static func _glacier_lane_contains(origin: Vector3, other_at: Vector3, return_x: float) -> bool:
    var line_x := origin.x
    if is_finite(return_x):
        line_x = clampf(other_at.x,minf(line_x,return_x),maxf(line_x,return_x))
    return absf(other_at.y-origin.y) <= TRAFFIC_HEIGHT and absf(other_at.x-line_x) < 1.15

static func glacier_return_pass_is_clear(own: RigidBody3D, rivals: Array[RigidBody3D],
        leader: RigidBody3D, center_x: float, shutter_side: float,
        passing: bool, resuming: bool) -> bool:
    var target_x := center_x-shutter_side*GLACIER_PASS_OFFSET
    if not passing and (not is_instance_valid(leader) or
            absf(leader.position.x-target_x) < 1.30):
        return false
    if not passing:
        var closing_speed: float = leader.linear_velocity.z-own.linear_velocity.z
        if resuming:
            # A trailing bot stays in line while the bot it is following
            # moves out. The committed bot can finish its lane change.
            if leader.glacier_pass_remaining > 0.0:
                return false
            # A bot matching its leader's speed has already slowed down.
            # A short gap still makes a pass worthwhile once the line opens.
            if own.position.z-leader.position.z > 2.8 or closing_speed < -1.0:
                return false
        elif closing_speed < 5.0:
            return false
    return _lane_occupancy(target_x,own,rivals,passing) < 0.72

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
    var speed: float = clampf(-own_speed_z,6.0,24.0)
    for index in range(director.obstacles.size()):
        var gate_z: float = director.event_z(index)
        var distance: float = own_z-gate_z
        if distance < GATE_MIN_DISTANCE or distance > GATE_LOOKAHEAD:
            continue
        var arrive_at: float = elapsed+distance/speed
        var obstacle_offset: float = director.blocking_lane_offset_at(index,arrive_at,gate_z)
        if obstacle_offset == INF or absf(preferred-obstacle_offset) >= GATE_CLEARANCE:
            # This timed collider will not intersect the chosen line.
            # Other upcoming colliders may still need avoidance.
            continue
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
