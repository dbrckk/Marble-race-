extends RefCounted
## Local-only race direction: meaningful overtakes, final straight and photo
## finishes. Pure presentation, never applies impulses, changes score/league
## or trusts client racing data for authoritative progression.
const SAMPLE_PERIOD := 0.10
const PASS_MARGIN := 0.90
const MAX_CROSSING_STEP := 7.0
const PASS_LATERAL_LIMIT := 4.75
const PASS_VERTICAL_LIMIT := 2.5
const NOTIFICATION_COOLDOWN := 1.10
const FINAL_STRETCH_Z := -158.0
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
# local race-direction scan. Its only consumers are camera and audio.
const PACK_Z_RANGE := 9.0
const PACK_X_RANGE := 3.8
const PACK_Y_RANGE := 1.45
const PACK_MIN_SPEED := 3.0
const PACK_SATURATION := 4

var game: Node3D
var elapsed := 0.0
var sample_clock := 0.0
var message_at := -100.0
var ahead: Dictionary = {}
var previous_gap: Dictionary = {}
var previous_rival_z: Dictionary = {}
var previously_passed: Dictionary = {}
var player_sample_z := 0.0
var sampled_once := false
var unique_overtakes := 0
var final_stretch_seen := false
var finish_seen := false
var local_speed := 0.0
var previous_boost := false
var closest_rival_gap := 999.0
var closest_rival_name := ""
var closest_rival_ahead := false
var side_by_side_id := -1
var side_by_side_seconds := 0.0
var side_by_side_active := false
var side_by_side_events := 0
var duel_announced: Dictionary = {}
var nearby_pack_count := 0
var pack_pressure := 0.0

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
    previous_gap.clear()
    previous_rival_z.clear()
    previously_passed.clear()
    sampled_once = false
    player_sample_z = 0.0
    unique_overtakes = 0
    final_stretch_seen = false
    finish_seen = false
    local_speed = 0.0
    previous_boost = false
    closest_rival_gap = 999.0
    closest_rival_name = ""
    closest_rival_ahead = false
    side_by_side_id = -1
    side_by_side_seconds = 0.0
    side_by_side_active = false
    side_by_side_events = 0
    duel_announced.clear()
    nearby_pack_count = 0
    pack_pressure = 0.0

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
    if quality <= 0:
        return 0.0
    var pace: float = clampf((speed-12.0)/14.0,0.0,1.0)
    if turbo:
        pace = maxf(0.40,pace)
    return pace*0.19 if quality == 2 else pace*0.10

static func genuine_overtake(old_gap: float, new_gap: float, lateral: float,
    vertical: float, player_delta_z: float, relative_step: float,
    rival_teleported: bool) -> bool:
    # z decreases as marbles advance. Opponent ahead means gap < 0,
    # and a physically overtaken rival has gap > 0 after crossing.
    return old_gap < PASS_MARGIN and new_gap > PASS_MARGIN and (
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
    sample_clock += maxf(0.0,delta)
    if game.boosting and not previous_boost and game.boost_energy > 0.0:
        # Boost has its own SFX. Do not double-trigger the start cue.
        game.ui.show_race_moment("TURBO",0.65)
    previous_boost = game.boosting
    if not final_stretch_seen and game.player.global_position.z < FINAL_STRETCH_Z:
        final_stretch_seen = true
        if elapsed-message_at > NOTIFICATION_COOLDOWN:
            message_at = elapsed
            game.ui.show_race_moment("FINAL STRAIGHT",1.4)
            game.audio.race_moment("final_stretch")
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
        previous_gap.clear()
        previous_rival_z.clear()
        closest_rival_gap = 999.0
        closest_rival_name = ""
        side_by_side_id = -1
        side_by_side_seconds = 0.0
        side_by_side_active = false
        nearby_pack_count = 0
        pack_pressure = 0.0
        sampled_once = false
        return
    sampled_once = true
    var passes_now := 0
    var pack_count := 0
    var own_forward: float = -game.player.linear_velocity.z
    var closest_duel_id := -1
    var closest_duel_gap := INF
    closest_rival_gap = 999.0
    closest_rival_name = ""
    closest_rival_ahead = false
    for marble in game.racers:
        if not is_instance_valid(marble) or marble == game.player or (
            marble.finished or marble.eliminated):
            continue
        var id: int = marble.racer_id
        var opponent: Vector3 = marble.global_position
        var gap: float = opponent.z-p.z
        if genuine_pack_rival(gap,opponent.x-p.x,opponent.y-p.y,
                own_forward,-marble.linear_velocity.z):
            pack_count += 1
        if genuine_side_duel(gap,opponent.x-p.x,opponent.y-p.y,
                -game.player.linear_velocity.z,-marble.linear_velocity.z):
            if absf(gap) < closest_duel_gap:
                closest_duel_gap = absf(gap)
                closest_duel_id = id
        # Real longitudinal distance only; a distant side lane or an
        # upper bridge must never masquerade as a nearby duel.
        if absf(opponent.x-p.x) < PASS_LATERAL_LIMIT and (
            absf(opponent.y-p.y) < PASS_VERTICAL_LIMIT) and (
            absf(gap) < closest_rival_gap):
            closest_rival_gap = absf(gap)
            closest_rival_name = marble.display_name
            closest_rival_ahead = gap < 0.0
        var old_gap: float = float(previous_gap.get(id,gap))
        var was_ahead: bool = bool(ahead.get(id,gap < -PASS_MARGIN))
        var rival_step: float = opponent.z-float(previous_rival_z.get(id,opponent.z))
        var rival_teleported: bool = absf(rival_step) > maxf(8.0,interval*45.0)
        if gap < -PASS_MARGIN:
            ahead[id] = true
        elif gap > PASS_MARGIN:
            ahead[id] = false
            var is_clean_pass: bool = was_ahead and genuine_overtake(
                old_gap,gap,opponent.x-p.x,opponent.y-p.y,player_step,
                gap-old_gap,rival_teleported)
            if is_clean_pass and not previously_passed.has(id):
                previously_passed[id] = true
                unique_overtakes += 1
                passes_now += 1
        previous_gap[id] = gap
        previous_rival_z[id] = opponent.z
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
    # Celebration is a client-side sound and visual cue only. It cannot
    # grant turbo, change race ranking, or issue trusted network messages.
    # Real overtakes and the final sprint have higher notification priority.
    if side_by_side_active and passes_now == 0 and not (
        duel_announced.has(side_by_side_id)) and (
        elapsed-message_at >= NOTIFICATION_COOLDOWN):
        duel_announced[side_by_side_id] = true
        side_by_side_events += 1
        message_at = elapsed
        game.ui.show_race_moment("SIDE BY SIDE!",0.85)
        game.audio.race_moment("duel")
    if passes_now > 0 and elapsed-message_at >= NOTIFICATION_COOLDOWN:
        message_at = elapsed
        game.ui.show_race_moment(
            "DOUBLE PASS!" if passes_now >= 2 else "CLEAN OVERTAKE!",1.1)
        game.audio.race_moment("overtake")

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
    game.ui.show_race_moment(label,1.4)
    if photo_finish:
        game.audio.race_moment("photo_finish")
