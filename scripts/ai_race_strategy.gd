extends RefCounted
## Lightweight deterministic line planning; never writes transforms.
## Used only for server/offline AI, never on human-controlled marbles.
const LOOKAHEAD_METERS := 22.0
const BYPASS_LOOKAHEAD := 4.2
const EARLY_LANE_OFFSET := 4.85
const BYPASS_LATERAL_FORCE := 18.0

static func pursue_bypass(z: float, entered: bool, entry_z: float,
    exit_z: float, entry_window: float) -> bool:
    if z >= entry_z+LOOKAHEAD_METERS or z <= exit_z-4.0:
        return false
    # Once the entry portal is behind a bot that did not make the fork,
    # abandon the impossible road instead of hitting the outer railing.
    return entered or z >= entry_z-entry_window+1.0

static func bypass_target_x(road: Node3D, z: float) -> float:
    var aim_z: float = maxf(road.EXIT_Z,z-BYPASS_LOOKAHEAD)
    if z > road.ENTRY_Z+0.5:
        # Get into position inside the rails, rather than aiming through a
        # closed barrier before the opening appears.
        return road.stage.track_center_at(aim_z)+float(road.side)*EARLY_LANE_OFFSET
    return road.point_at(aim_z).x

static func bypass_steering(target_x: float, current_x: float,
    side_velocity: float) -> float:
    var displacement: float = target_x-current_x
    return clampf(displacement*3.25-side_velocity*1.05,
        -BYPASS_LATERAL_FORCE,BYPASS_LATERAL_FORCE)

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
