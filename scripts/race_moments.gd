extends RefCounted
## Local-only race direction: meaningful overtakes, final straight and photo
## finishes. Pure presentation, never applies impulses, changes score/league
## or trusts client racing data for authoritative progression.
const RaceFeedback = preload("res://scripts/race_feedback.gd")
const SAMPLE_PERIOD := 0.10
const PASS_MARGIN := 0.90
const MAX_CROSSING_STEP := 7.0
const PASS_LATERAL_LIMIT := 4.75
const PASS_VERTICAL_LIMIT := 1.45
const RIVAL_DISPLAY_RANGE := 12.0
const RIVAL_SWITCH_MARGIN := 0.7
const NOTIFICATION_COOLDOWN := 1.10
const PHOTO_FINISH_WINDOW := 0.48
# A genuine shoulder-to-shoulder contest is more than a one-frame overlap:
# two moving spheres must maintain comparable speed and elevation.
const SIDE_DUEL_Z_LIMIT := 1.40
const SIDE_DUEL_X_MIN := 0.78
const SIDE_DUEL_X_MAX := 2.35
const SIDE_DUEL_Y_LIMIT := 1.25
const SIDE_DUEL_MIN_SPEED := 8.0
const SIDE_DUEL_HOLD := 0.34
# One cheap same-deck proximity count piggybacks on the existing 10 Hz
# local race-direction scan, shared by camera, audio and the player locator.
const PACK_Z_RANGE := 9.0
const PACK_X_RANGE := 3.8
const PACK_Y_RANGE := 1.45
const PACK_MIN_SPEED := 3.0
const PACK_SATURATION := 4
const TURN_FULL_ANGLE := [0.025,0.056,0.059]
const OCCLUSION_RADIUS := 0.43
const EXIT_FEEDBACK_SECONDS := 0.60
const WOODWORKS_EXIT_LEAD_SECONDS := 0.58

var game: Node3D
var elapsed := 0.0
var sample_clock := 0.0
var message_at := -100.0
var ahead: Dictionary = {}
var previous_offsets: Dictionary = {}
var crossed_nearby: Dictionary = {}
var previously_passed: Dictionary = {}
var player_sample_z := 0.0
var sampled_once := false
var unique_overtakes := 0
var final_stretch_seen := false
var finish_seen := false
var local_speed := 0.0
var previous_boost := false
var closest_rival: RigidBody3D
var closest_rival_gap := 999.0
var closest_rival_name := ""
var closest_rival_ahead := false
var closest_rival_side := 0
var side_by_side_id := -1
var side_by_side_seconds := 0.0
var side_by_side_active := false
var side_by_side_events := 0
var duel_announced: Dictionary = {}
var nearby_pack_count := 0
var pack_pressure := 0.0
var turn_weight := 0.0
var merge_traffic := 0
var merge_rival: RigidBody3D
var occluded_hazard := Vector3.INF
var occluded_hazard_kind := ""
var occluded_shutter_mark := Vector3.INF
var occluded_passing_mark := Vector3.INF
var occluded_bank_mark := Vector3.INF
var occluded_opening_turbo := Vector3.INF
var occluded_fork_main := Vector3.INF
var occluded_fork_bridge := Vector3.INF
var glacier_exit_threat: Dictionary = {}
var glacier_gap_marked := false
var woodworks_return_threat: Dictionary = {}
var evasion_target := Vector3.INF
var exit_gate_z := INF
var exit_deadline := 0.0
var exit_low_speed := INF
var exit_last_speed := 0.0
var exit_rising_samples := 0
var exit_feedback_left := 0.0

func _clear_exit_sample() -> void:
    exit_gate_z = INF
    exit_deadline = 0.0
    exit_low_speed = INF
    exit_last_speed = 0.0
    exit_rising_samples = 0

func exit_speed_weight() -> float:
    return exit_feedback_left/EXIT_FEEDBACK_SECONDS

func sample_obstacle_exit(z: float, speed: float, hazard_z: float, grounded: bool, turbo: bool,
        woodworks_arm_z := INF) -> void:
    if not grounded or turbo or not is_finite(speed) or speed < 5.0:
        _clear_exit_sample()
        exit_feedback_left = 0.0
        return
    if is_finite(exit_gate_z) and elapsed >= exit_deadline:
        _clear_exit_sample()
    # An obstacle farther down the next section must not interrupt the
    # recovered pace while there's still time to drive a clear line.
    if z < woodworks_arm_z-1.15 and z > woodworks_arm_z-9.0 and (
            hazard_z < woodworks_arm_z-8.5 and z-hazard_z > speed*WOODWORKS_EXIT_LEAD_SECONDS):
        hazard_z = INF
    var ahead := z-hazard_z
    if is_finite(hazard_z) and ahead >= 0.0 and ahead < 10.5:
        exit_feedback_left = 0.0
        # Carry the slower speed through a nearby second obstacle so the
        # cue lands after the sequence has actually cleared.
        if not is_finite(exit_gate_z) or (hazard_z < exit_gate_z and exit_gate_z-hazard_z <= 8.5):
            exit_gate_z = hazard_z
            exit_deadline = elapsed+1.85
            exit_low_speed = minf(exit_low_speed,speed)
            exit_rising_samples = 0
        if hazard_z < exit_gate_z-8.5:
            _clear_exit_sample()
            return
    if not is_finite(exit_gate_z):
        return
    exit_low_speed = minf(exit_low_speed,speed)
    if z < exit_gate_z-1.15 and speed >= exit_last_speed+0.14:
        exit_rising_samples += 1
    else:
        exit_rising_samples = 0
    exit_last_speed = speed
    if exit_rising_samples >= 2 and speed >= 10.0 and speed-exit_low_speed >= 1.10:
        exit_feedback_left = EXIT_FEEDBACK_SECONDS
        _clear_exit_sample()

static func covers_hazard(eye: Vector3, hazard: Vector3, rival: Vector3) -> bool:
    var sight := hazard-eye
    var depth := sight.length_squared()
    if depth <= 0.001:
        return false
    var along := (rival-eye).dot(sight)/depth
    return along > 0.0 and along < 1.0 and (
        (eye+sight*along).distance_squared_to(rival) <= OCCLUSION_RADIUS*OCCLUSION_RADIUS)

static func genuine_pack_rival(gap_z: float, side_gap: float,
        height_gap: float, own_speed: float, rival_speed: float) -> bool:
    # Never use screen-space overlap: a marble on the elevated bypass or
    # stopped behind a wall is not part of the same rolling competition.
    return is_finite(gap_z) and is_finite(side_gap) and (
        is_finite(height_gap) and is_finite(own_speed) and
        is_finite(rival_speed) and absf(gap_z) <= PACK_Z_RANGE and
        absf(side_gap) <= PACK_X_RANGE and
        absf(height_gap) <= PACK_Y_RANGE and
        own_speed >= PACK_MIN_SPEED and rival_speed >= PACK_MIN_SPEED)

static func pack_intensity(rivals: int) -> float:
    return clampf(float(maxi(0,rivals))/float(PACK_SATURATION),0.0,1.0)

func configure(owner: Node3D) -> void:
    game = owner
    reset_round()

func reset_round() -> void:
    elapsed = 0.0
    sample_clock = 0.0
    message_at = -100.0
    ahead.clear()
    previous_offsets.clear()
    crossed_nearby.clear()
    previously_passed.clear()
    sampled_once = false
    player_sample_z = 0.0
    unique_overtakes = 0
    final_stretch_seen = false
    finish_seen = false
    local_speed = 0.0
    previous_boost = false
    _set_closest_rival(null,Vector3.ZERO)
    side_by_side_id = -1
    side_by_side_seconds = 0.0
    side_by_side_active = false
    side_by_side_events = 0
    duel_announced.clear()
    nearby_pack_count = 0
    pack_pressure = 0.0
    turn_weight = 0.0
    merge_traffic = 0
    merge_rival = null
    occluded_hazard = Vector3.INF
    occluded_hazard_kind = ""
    occluded_shutter_mark = Vector3.INF
    occluded_passing_mark = Vector3.INF
    occluded_bank_mark = Vector3.INF
    occluded_opening_turbo = Vector3.INF
    occluded_fork_main = Vector3.INF
    occluded_fork_bridge = Vector3.INF
    glacier_exit_threat.clear()
    glacier_gap_marked = false
    woodworks_return_threat.clear()
    evasion_target = Vector3.INF
    _clear_exit_sample()
    exit_feedback_left = 0.0

func approach_turn_weight(z: float, forward: float, on_bridge: bool) -> float:
    if not is_finite(forward) or forward < 6.0:
        return 0.0
    var step := clampf(forward*0.45,3.5,9.0)
    var road: Node3D = game.shortcut_route
    if on_bridge:
        step = minf(step,(z-road.EXIT_Z)*0.5)
        if step < 2.0:
            return 0.0
    var current: float = road.point_at(z).x if on_bridge else game.track_center_at(z)
    var middle: float = road.point_at(z-step).x if on_bridge else game.track_center_at(z-step)
    var ahead_x: float = road.point_at(z-step*2.0).x if on_bridge else game.track_center_at(z-step*2.0)
    # A constant heading produces no cue, even when the road points
    # diagonally across the board. Woodworks has wider, gentler bends.
    var angle := absf(atan2(ahead_x-middle,step)-atan2(middle-current,step))
    var full_turn: float = 0.20 if on_bridge else TURN_FULL_ANGLE[game.selected_track]
    return smoothstep(0.006,full_turn,angle)*smoothstep(6.0,13.0,forward)

static func genuine_side_duel(gap_z: float, lateral: float,
    vertical: float, own_forward: float, rival_forward: float) -> bool:
    return absf(gap_z) <= SIDE_DUEL_Z_LIMIT and (
        absf(lateral) >= SIDE_DUEL_X_MIN and
        absf(lateral) <= SIDE_DUEL_X_MAX and
        absf(vertical) <= SIDE_DUEL_Y_LIMIT and
        own_forward >= SIDE_DUEL_MIN_SPEED and
        rival_forward >= SIDE_DUEL_MIN_SPEED and
        absf(own_forward-rival_forward) <= 7.0)

static func edge_intensity(speed: float, turbo: bool, quality: int) -> float:
    if quality <= 0 or not is_finite(speed):
        return 0.0
    var pace := smoothstep(11.0,24.0,speed)
    if turbo:
        pace = maxf(0.40,pace)
    return pace*0.195 if quality == 2 else pace*0.13

static func genuine_overtake(old_gap: float, new_gap: float, lateral: float,
    vertical: float, player_delta_z: float, relative_step: float,
    rival_teleported: bool, margin := PASS_MARGIN) -> bool:
    # z decreases as marbles advance. Opponent ahead means gap < 0,
    # and a physically overtaken rival has gap > 0 after crossing.
    return old_gap <= margin and new_gap > margin and (
        absf(lateral) <= PASS_LATERAL_LIMIT and
        absf(vertical) <= PASS_VERTICAL_LIMIT and
        player_delta_z < 0.15 and
        relative_step >= 0.0 and relative_step <= MAX_CROSSING_STEP and
        not rival_teleported)

func tick(delta: float) -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    if game.race_state != "RACING" or game.player.finished or game.player.eliminated:
        return
    elapsed += maxf(0.0,delta)
    exit_feedback_left = maxf(0.0,exit_feedback_left-delta)
    sample_clock += maxf(0.0,delta)
    if game.boosting and not previous_boost and game.boost_energy > 0.0:
        # Boost has its own SFX. Do not double-trigger the start cue.
        game.ui.show_race_moment("TURBO",0.65)
    previous_boost = game.boosting
    if sample_clock < SAMPLE_PERIOD:
        return
    var interval: float = sample_clock
    sample_clock = 0.0
    var p: Vector3 = game.player.global_position
    if sampled_once:
        local_speed = clampf((player_sample_z-p.z)/maxf(0.01,interval),
            0.0,35.0)
    else:
        local_speed = maxf(0.0,-game.player.linear_velocity.z)
    var player_step: float = p.z-player_sample_z if sampled_once else 0.0
    var player_teleported: bool = sampled_once and (
        absf(player_step) > maxf(8.0,interval*45.0))
    player_sample_z = p.z
    if player_teleported:
        # A recovery to the previous checkpoint is NOT a dramatic overtake.
        ahead.clear()
        previous_offsets.clear()
        crossed_nearby.clear()
        game.ui.clear_overtake_feedback()
        _set_closest_rival(null,Vector3.ZERO)
        side_by_side_id = -1
        side_by_side_seconds = 0.0
        side_by_side_active = false
        nearby_pack_count = 0
        pack_pressure = 0.0
        turn_weight = 0.0
        merge_traffic = 0
        merge_rival = null
        occluded_hazard = Vector3.INF
        occluded_hazard_kind = ""
        occluded_shutter_mark = Vector3.INF
        occluded_passing_mark = Vector3.INF
        occluded_bank_mark = Vector3.INF
        occluded_opening_turbo = Vector3.INF
        occluded_fork_main = Vector3.INF
        occluded_fork_bridge = Vector3.INF
        glacier_exit_threat.clear()
        glacier_gap_marked = false
        woodworks_return_threat.clear()
        evasion_target = Vector3.INF
        _clear_exit_sample()
        exit_feedback_left = 0.0
        sampled_once = false
    if not final_stretch_seen and p.z < game.final_straight_z and p.z > game.FINISH_Z and (
            elapsed-message_at > NOTIFICATION_COOLDOWN and
            p.y >= game.height_at(p.z)-0.3 and
            absf(p.x-game.track_center_at(p.z)) <= 6.75):
        final_stretch_seen = true
        message_at = elapsed
        game.ui.show_race_moment("FINAL STRAIGHT",1.4,1)
        game.audio.race_moment("final_stretch")
    if player_teleported:
        return
    sampled_once = true
    var passes_now := 0
    var passed_name := ""
    var pack_count := 0
    var own_forward: float = -game.player.linear_velocity.z
    var best_rival: RigidBody3D
    var best_offset := Vector3.ZERO
    var best_score := INF
    var closest_duel_id := -1
    var closest_duel_gap := INF
    var duel_rival: RigidBody3D
    var duel_offset := Vector3.ZERO
    var local_race: bool = not game.net.is_active()
    var road: Node3D = game.shortcut_route
    var player_on_bridge: bool = is_instance_valid(road) and road.on_separate_deck(p)
    var merge_lane := 0
    var merge_distance := 0.0
    var merge_score := INF
    merge_traffic = 0
    merge_rival = null
    occluded_hazard = Vector3.INF
    occluded_hazard_kind = ""
    occluded_shutter_mark = Vector3.INF
    occluded_passing_mark = Vector3.INF
    occluded_bank_mark = Vector3.INF
    occluded_opening_turbo = Vector3.INF
    occluded_fork_main = Vector3.INF
    occluded_fork_bridge = Vector3.INF
    glacier_exit_threat.clear()
    glacier_gap_marked = false
    woodworks_return_threat.clear()
    evasion_target = Vector3.INF
    var candidate := Vector3.INF
    var candidate_kind := ""
    var road_mark := Vector3.INF
    var bank_mark := Vector3.INF
    var turbo_mark := Vector3.INF
    var fork_main := Vector3.INF
    var fork_bridge := Vector3.INF
    var arm_gap_eta := INF
    var eyes := Vector3.ZERO
    if game.net.role != "server":
        var preview_velocity: Vector3 = game.player.linear_velocity
        if game.net.is_client():
            preview_velocity = game.net.local_replica_velocity()
        var preview_speed := -preview_velocity.z if preview_velocity.is_finite() else 0.0
        var bridge_contact: bool = is_instance_valid(road) and is_instance_valid(game.airtime) and (
            game.airtime.rolling_surface == game.AirtimeDirector.Surface.BRIDGE)
        turn_weight = approach_turn_weight(p.z,preview_speed,bridge_contact)
        if preview_speed >= 3.0 and is_instance_valid(road):
            merge_lane = road.merge_traffic_lane(p)
            merge_distance = clampf(preview_speed*0.30,3.2,6.0)
        var next_hazard: Vector3 = game.pack_hazard_ahead(p,preview_velocity)
        glacier_exit_threat = game.glacier_exit_threat(p,preview_velocity)
        woodworks_return_threat = game.woodworks_return_threat(p,preview_velocity)
        if not glacier_exit_threat.is_empty() and (
                not next_hazard.is_finite() or (
                    next_hazard.z < game.glacier_first_shutter_z and next_hazard.z < glacier_exit_threat["entry_z"])):
            next_hazard = glacier_exit_threat["position"]
        if not woodworks_return_threat.is_empty():
            next_hazard = woodworks_return_threat["position"]
        var driving: bool = game.net.is_client() or not game.player.freeze
        var woodworks_arm_z: float = game.race_director.event_z(game.race_director.WOODWORKS_RETURN_ARM) if (
            game.selected_track == 0) else INF
        sample_obstacle_exit(p.z,preview_speed,next_hazard.z,driving and (
            game.airtime.course_grounded and not game.airtime.airborne),game.boosting,woodworks_arm_z)
        if game.cam_mode == 0 and is_instance_valid(game.camera):
            candidate = next_hazard
            var bridge_merge: bool = game.selected_track == 2 and is_instance_valid(road) and (
                road.shortcut_hint(p,bridge_contact or merge_lane < 0 or game.ui.bridge_approach_active).get("mode","") == "merge")
            var forge_threat: Dictionary = game.forge_merge_threat(p,preview_velocity,bridge_merge)
            if not forge_threat.is_empty():
                candidate = forge_threat["position"]
                candidate_kind = forge_threat["kind"]
            if not glacier_exit_threat.is_empty() and candidate == glacier_exit_threat["position"]:
                evasion_target = game.glacier_exit_lane(p,preview_velocity,glacier_exit_threat)
                glacier_gap_marked = evasion_target.is_finite()
            elif not woodworks_return_threat.is_empty():
                candidate_kind = "BRIDGE RETURN"
                evasion_target = game.woodworks_return_lane(p,preview_velocity,woodworks_return_threat)
            elif candidate_kind.is_empty() or (candidate_kind == "PISTON" and not bridge_merge):
                evasion_target = game.evasion_lane(p,preview_velocity,candidate)
                if game.selected_track == 0 and absf(candidate.z-game.race_director.event_z(
                        game.race_director.WOODWORKS_RETURN_ARM)) < 0.08:
                    candidate_kind = "SWEEPING ARM"
                    if evasion_target.is_finite():
                        arm_gap_eta = (p.z-evasion_target.z)/preview_speed
            eyes = game.camera.global_position
            if game.selected_track == 0 and is_instance_valid(game.opening_obstacle_art) and (
                    not game.airtime.airborne and absf(p.y-game.height_at(p.z)-0.39) <= 0.55):
                if not evasion_target.is_finite():
                    road_mark = game.opening_obstacle_art.entry_mark_ahead(game,p,preview_velocity)
                    if not road_mark.is_finite():
                        bank_mark = game.jump_guides.woodworks_bank_mark_ahead(p,preview_velocity)
                        if candidate.is_finite() and candidate.z >= bank_mark.z:
                            bank_mark = Vector3.INF
                var past_opening_turbo := true
                if game.woodworks_opening_cleared(p.z) and preview_speed >= 5.0 and (
                        is_instance_valid(game.race_items) and not game.race_items.items.is_empty()):
                    var pickup: Node3D = game.race_items.items[0]
                    var position: Vector3 = pickup.global_position
                    var distance := p.z-position.z
                    past_opening_turbo = not pickup.visible or distance <= 0.0
                    if pickup.visible and distance > 2.3 and distance <= 15.0 and (
                            not candidate.is_finite() or candidate.z < position.z):
                        var aim := RaceFeedback.projected_lane_x(p.x,preview_velocity.x,distance/preview_speed)
                        if absf(aim-position.x) < 0.8+3.8*distance/preview_speed:
                            turbo_mark = Vector3(position.x,game.height_at(position.z)+0.39,position.z)
                if past_opening_turbo and preview_speed >= 7.0 and is_instance_valid(road) and not bridge_contact and (
                        p.z > road.ENTRY_PORTAL_Z and p.z < road.ENTRY_PORTAL_Z+30.0 and (
                            road.shortcut_hint(p).get("mode","") == "fork")):
                    fork_main = road.fork_mark_ahead(p.z,preview_speed,false)
                    fork_bridge = road.fork_mark_ahead(p.z,preview_speed,true)
            elif game.selected_track == 1 and preview_speed >= 5.0 and not player_on_bridge and (
                    absf(p.y-game.height_at(p.z)-0.39) <= 0.50 and not evasion_target.is_finite()):
                road_mark = game.jump_guides.shutter_mark_ahead(p.z)
            elif game.selected_track == 2 and is_instance_valid(game.final_obstacle_art) and (
                    not evasion_target.is_finite() and not game.airtime.airborne and (
                        absf(p.y-game.height_at(p.z)-0.39) <= 0.55)):
                road_mark = game.final_obstacle_art.passing_mark_ahead(game,p,preview_velocity)
    for marble in game.racers:
        if not is_instance_valid(marble) or marble == game.player:
            continue
        var id: int = marble.racer_id
        if marble.finished or marble.eliminated:
            ahead.erase(id)
            crossed_nearby.erase(id)
            previous_offsets.erase(id)
            continue
        var opponent: Vector3 = marble.global_position
        var offset := opponent-p
        var gap := offset.z
        var nearby := absf(gap) <= RIVAL_DISPLAY_RANGE
        var same_route: bool = nearby and (not is_instance_valid(road) or (
            player_on_bridge == road.on_separate_deck(opponent)))
        # At Forge’s join, either deck can put a marble across the camera ray.
        if candidate.is_finite() and gap < -0.20 and opponent.z > candidate.z+0.15 and (
                (same_route or not candidate_kind.is_empty()) and covers_hazard(eyes,candidate,opponent)):
            occluded_hazard = candidate
            occluded_hazard_kind = candidate_kind
            candidate = Vector3.INF
        # A marble peeling off toward either road can hide paint on the other.
        if gap < -0.20:
            if fork_main.is_finite() and covers_hazard(eyes,fork_main,opponent):
                occluded_fork_main = fork_main
                fork_main = Vector3.INF
            if fork_bridge.is_finite() and covers_hazard(eyes,fork_bridge,opponent):
                occluded_fork_bridge = fork_bridge
                fork_bridge = Vector3.INF
        if not nearby:
            ahead.erase(id)
            crossed_nearby.erase(id)
            previous_offsets.erase(id)
            continue
        if merge_lane != 0 and absf(offset.y) <= 1.5 and (not local_race or not marble.freeze):
            var score := INF
            if game.selected_track == 0 and local_race:
                score = road.merge_conflict_score(p.z,own_forward,opponent.z,-marble.linear_velocity.z)
            elif merge_traffic == 0 and absf(gap) <= merge_distance:
                score = absf(gap)
            if score < merge_score and road.merge_traffic_lane(opponent) == -merge_lane:
                merge_score = score
                merge_traffic = merge_lane
                merge_rival = marble
        if same_route:
            if bank_mark.is_finite() and gap < -0.20 and covers_hazard(eyes,bank_mark,opponent):
                occluded_bank_mark = bank_mark
                bank_mark = Vector3.INF
            if is_finite(arm_gap_eta) and evasion_target.is_finite():
                var rival_speed: Vector3 = marble.linear_velocity if local_race and not marble.freeze else Vector3.ZERO
                var rival_z := opponent.z+minf(0.0,rival_speed.z)*arm_gap_eta
                var rival_x := RaceFeedback.projected_lane_x(opponent.x,rival_speed.x,arm_gap_eta)
                if absf(rival_z-evasion_target.z) < 1.35 and absf(rival_x-evasion_target.x) < 1.0 and (
                        absf(offset.y) < 1.4):
                    evasion_target = Vector3.INF
            if road_mark.is_finite() and gap < -0.20 and opponent.z >= road_mark.z-0.40 and (
                    covers_hazard(eyes,road_mark,opponent)):
                if game.selected_track == 1:
                    occluded_shutter_mark = road_mark
                else:
                    occluded_passing_mark = road_mark
                road_mark = Vector3.INF
            if turbo_mark.is_finite() and gap < -0.20 and opponent.z >= turbo_mark.z-0.40 and (
                    covers_hazard(eyes,turbo_mark,opponent)):
                occluded_opening_turbo = turbo_mark
                turbo_mark = Vector3.INF
            var rival_forward: float = -marble.linear_velocity.z
            if genuine_pack_rival(gap,offset.x,offset.y,own_forward,rival_forward):
                pack_count += 1
            if genuine_side_duel(gap,offset.x,offset.y,own_forward,rival_forward):
                # Keep an established duel while it is still valid. Changing
                # rivals on a fraction of a meter would restart its hold timer.
                var duel_score := -1.0 if id == side_by_side_id else absf(gap)
                if duel_score < closest_duel_gap:
                    closest_duel_gap = duel_score
                    closest_duel_id = id
                    duel_rival = marble
                    duel_offset = offset
            if absf(offset.x) <= PASS_LATERAL_LIMIT and absf(offset.y) <= PACK_Y_RANGE:
                var score := absf(gap)+absf(offset.x)*0.26
                if marble == closest_rival:
                    score -= RIVAL_SWITCH_MARGIN
                if score < best_score:
                    best_score = score
                    best_rival = marble
                    best_offset = offset
        if local_race and _track_pass(id,offset,same_route,player_step,interval):
            passes_now += 1
            passed_name = marble.display_name
    _set_closest_rival(best_rival,best_offset)
    nearby_pack_count = pack_count
    pack_pressure = pack_intensity(pack_count)
    if closest_duel_id < 0:
        side_by_side_id = -1
        side_by_side_seconds = 0.0
    elif closest_duel_id != side_by_side_id:
        side_by_side_id = closest_duel_id
        side_by_side_seconds = 0.0
    else:
        side_by_side_seconds += interval
    side_by_side_active = side_by_side_id >= 0 and (
        side_by_side_seconds >= SIDE_DUEL_HOLD)
    if side_by_side_active:
        _set_closest_rival(duel_rival,duel_offset)
    # Celebration is a client-side sound and visual cue only. It cannot
    # grant turbo, change race ranking, or issue trusted network messages.
    # Real overtakes and the final sprint have higher notification priority.
    if side_by_side_active and passes_now == 0 and not (
        duel_announced.has(side_by_side_id)) and (
        elapsed-message_at >= NOTIFICATION_COOLDOWN):
        duel_announced[side_by_side_id] = true
        side_by_side_events += 1
        message_at = elapsed
        game.audio.race_moment("duel")
    if passes_now > 0:
        game.ui.show_overtake(passes_now,passed_name)
        if elapsed-message_at >= NOTIFICATION_COOLDOWN:
            message_at = elapsed
            game.audio.race_moment("overtake")

func _set_closest_rival(rival: RigidBody3D, offset: Vector3) -> void:
    closest_rival = rival
    closest_rival_gap = absf(offset.z) if is_instance_valid(rival) else 999.0
    closest_rival_name = rival.display_name if is_instance_valid(rival) else ""
    closest_rival_ahead = offset.z < 0.0
    closest_rival_side = int(signf(offset.x)) if absf(offset.x) >= 0.85 else 0

func _track_pass(id: int, offset: Vector3, same_route: bool,
        player_step: float, interval: float) -> bool:
    if previously_passed.has(id):
        return false
    var old: Vector3 = previous_offsets.get(id,offset)
    previous_offsets[id] = offset
    var step := offset.z-old.z
    var discontinuity := absf(player_step+step) > maxf(8.0,interval*45.0)
    if not same_route or discontinuity:
        ahead.erase(id)
        crossed_nearby.erase(id)
        return false
    if offset.z < -PASS_MARGIN:
        ahead[id] = true
        crossed_nearby.erase(id)
    if offset.z <= 0.0:
        crossed_nearby.erase(id)
        return false
    if old.z <= 0.0 and offset.z > 0.0 and ahead.has(id):
        # Use separation at the crossing, even when the marbles take
        # several HUD samples to move a full margin apart.
        var crossing := old.lerp(offset,-old.z/step)
        if genuine_overtake(old.z,offset.z,crossing.x,crossing.y,player_step,step,false,0.0):
            crossed_nearby[id] = true
    if offset.z <= PASS_MARGIN:
        return false
    ahead.erase(id)
    var passed := crossed_nearby.erase(id)
    if passed:
        previously_passed[id] = true
        unique_overtakes += 1
        previous_offsets.erase(id)
    return passed

func on_finish() -> void:
    if finish_seen or not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    if not game.player.finished:
        return
    finish_seen = true
    var photo_finish := false
    for rival in game.racers:
        if not is_instance_valid(rival) or rival == game.player:
            continue
        if rival.finished and absf(rival.finish_time-game.player.finish_time) < PHOTO_FINISH_WINDOW:
            photo_finish = true
            break
        if not rival.finished and absf(rival.global_position.z-game.FINISH_Z) < 1.8:
            photo_finish = true
            break
    var label: String = "PHOTO FINISH!" if photo_finish else (
        "PODIUM FINISH!" if game.player_rank() <= 3 else "FINISH LINE!")
    game.ui.show_race_moment(label,1.4,3)
    if photo_finish:
        game.audio.race_moment("photo_finish")
