extends RefCounted
## Lightweight deterministic line planning; never writes transforms.
## Used only for server/offline AI, never on human-controlled marbles.
const LOOKAHEAD_METERS := 22.0
const BYPASS_LOOKAHEAD := 5.8
const EARLY_LANE_OFFSET := 5.15
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
