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
        sampled_once = false
        return
    sampled_once = true
    var passes_now := 0
    for marble in game.racers:
        if not is_instance_valid(marble) or marble == game.player or (
            marble.finished or marble.eliminated):
            continue
        var id: int = marble.racer_id
        var opponent: Vector3 = marble.global_position
        var gap: float = opponent.z-p.z
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
