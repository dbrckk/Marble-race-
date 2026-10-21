extends RefCounted
## Validated offline championship progress, kept separately from controls/graphics.
var save_path := "user://marble_career.cfg"
const TRACKS := ["WOODWORKS", "SWITCHBACK", "GAUNTLET"]
const TARGETS := [10, 8, 1]
## Nine permanently earned solo mastery stamps: per circuit, complete a
## valid race / earn a physical clean pass / succeed on the side shortcut.
## Unlocks are cumulative and cosmetic only: no gameplay/stat paywall.
const MASTERY_GOALS := ["FINISH RACE","CLEAN PASS","SHORTCUT"]
const STYLE_NAMES := ["COPPER","AZURE","SOLAR","AMETHYST","PRISM"]
const STYLE_THRESHOLDS := [0,2,4,6,9]
const ALL_MASTERY_BITS := 7
## Additional long-term solo career progression that keeps working after
## every one-off mastery stamp has been earned. Completely stat-neutral.
const LEAGUE_TIERS := ["ROOKIE","CHALLENGER","CONTENDER","ELITE","LEGEND"]
const LEAGUE_LIMITS := [0,120,320,700,1300]
const LEAGUE_SCORE_CAP := 2000000

var starts := 0
var finishes := 0
var victories := 0
var podiums := 0
var track_best: Array[int] = [0, 0, 0]
var track_time: Array[float] = [0.0, 0.0, 0.0]
var unlocked := 1
var stars: Array[int] = [0,0,0]
var mastery_flags: Array[int] = [0,0,0]
var selected_style := 0
var league_points := 0
var league_runs: Array[int] = [0,0,0]
var league_clean_passes: Array[int] = [0,0,0]
var league_shortcuts: Array[int] = [0,0,0]
## Four split records per circuit: 3 checkpoints plus the finish line.
## Flat typed array avoids nested Godot array serialization pitfalls.
const SECTORS_PER_TRACK := 4
var sector_best: Array[float] = [0.0,0.0,0.0,0.0, 0.0,0.0,0.0,0.0, 0.0,0.0,0.0,0.0]

func load_save() -> void:
    var file := ConfigFile.new()
    if file.load(save_path) != OK:
        return
    starts = maxi(0,int(file.get_value("career","starts",0)))
    finishes = clampi(int(file.get_value("career","finishes",0)),0,starts)
    victories = clampi(int(file.get_value("career","victories",0)),0,finishes)
    podiums = clampi(int(file.get_value("career","podiums",0)),0,finishes)
    for index in range(3):
        track_best[index] = clampi(int(file.get_value("career","best_%d" % index,0)),0,40)
        track_time[index] = maxf(0.0,float(file.get_value("career","time_%d" % index,0.0)))
        stars[index] = clampi(int(file.get_value("career","stars_%d" % index,0)),0,3)
        # Old pre-mastery saves contain no [mastery] section and remain valid.
        mastery_flags[index] = clampi(
            int(file.get_value("mastery","flags_%d" % index,0)),0,ALL_MASTERY_BITS)
        for sector in range(SECTORS_PER_TRACK):
            var saved := float(file.get_value("sectors","best_%d_%d" % [index,sector],0.0))
            sector_best[index*SECTORS_PER_TRACK+sector] = saved if is_finite(saved) and saved > 0.0 and saved < 600.0 else 0.0
    league_points = clampi(int(file.get_value("league","score",0)),0,LEAGUE_SCORE_CAP)
    for index in range(TRACKS.size()):
        league_runs[index] = clampi(int(file.get_value("league","runs_%d" % index,0)),0,1000000)
        league_clean_passes[index] = clampi(
            int(file.get_value("league","passes_%d" % index,0)),0,1000000)
        league_shortcuts[index] = clampi(
            int(file.get_value("league","shortcuts_%d" % index,0)),0,1000000)
    selected_style = clampi(int(file.get_value("mastery","style",0)),
        0,STYLE_NAMES.size()-1)
    if not is_style_unlocked(selected_style):
        selected_style = 0
    # Derive unlocks from completed results: saved data cannot lock a won track.
    unlocked = 1
    if track_best[0] > 0 and track_best[0] <= TARGETS[0]:
        unlocked = 2
    if unlocked == 2 and track_best[1] > 0 and track_best[1] <= TARGETS[1]:
        unlocked = 3

func save() -> int:
    var file := ConfigFile.new()
    file.set_value("career","starts",starts)
    file.set_value("career","finishes",finishes)
    file.set_value("career","victories",victories)
    file.set_value("career","podiums",podiums)
    for index in range(3):
        file.set_value("career","best_%d" % index,track_best[index])
        file.set_value("career","time_%d" % index,track_time[index])
        file.set_value("career","stars_%d" % index,stars[index])
        file.set_value("mastery","flags_%d" % index,
            clampi(mastery_flags[index],0,ALL_MASTERY_BITS))
        for sector in range(SECTORS_PER_TRACK):
            file.set_value("sectors","best_%d_%d" % [index,sector],sector_best[index*SECTORS_PER_TRACK+sector])
    file.set_value("mastery","style",selected_style)
    file.set_value("league","score",league_points)
    for index in range(TRACKS.size()):
        file.set_value("league","runs_%d" % index,league_runs[index])
        file.set_value("league","passes_%d" % index,league_clean_passes[index])
        file.set_value("league","shortcuts_%d" % index,league_shortcuts[index])
    return file.save(save_path)

func begin() -> void:
    starts += 1
    save()

func complete(index: int, place: int, time_seconds: float, finished: bool) -> Dictionary:
    var record := false
    var newly_unlocked := false
    if finished and place >= 1 and place <= 40:
        finishes += 1
        if place == 1: victories += 1
        if place <= 3: podiums += 1
        if track_best[index] == 0 or place < track_best[index]:
            track_best[index] = place
            record = true
        if track_time[index] == 0.0 or time_seconds < track_time[index]:
            track_time[index] = time_seconds
        var earned := 1
        if place <= 10: earned = 2
        if place <= 3: earned = 3
        stars[index] = maxi(stars[index],earned)
        if index == 0 and place <= TARGETS[0] and unlocked == 1:
            unlocked = 2
            newly_unlocked = true
        elif index == 1 and place <= TARGETS[1] and unlocked == 2:
            unlocked = 3
            newly_unlocked = true
    save()
    return {"record":record,"unlocked":newly_unlocked,"stars":stars[index],
        "best":track_best[index],"place":place,"finished":finished}


func track_mastery_count(index: int) -> int:
    if index < 0 or index >= TRACKS.size():
        return 0
    var mask: int = mastery_flags[index] & ALL_MASTERY_BITS
    return int(bool(mask & 1)) + int(bool(mask & 2)) + int(bool(mask & 4))

func mastery_count() -> int:
    var total := 0
    for track in range(TRACKS.size()):
        total += track_mastery_count(track)
    return total

func has_mastery(index: int, goal: int) -> bool:
    if index < 0 or index >= TRACKS.size() or goal < 0 or goal >= MASTERY_GOALS.size():
        return false
    return (mastery_flags[index] & (1 << goal)) != 0

func is_style_unlocked(style: int) -> bool:
    return style >= 0 and style < STYLE_NAMES.size() and (
        mastery_count() >= STYLE_THRESHOLDS[style])

func style_name() -> String:
    return STYLE_NAMES[selected_style]

func unlocked_style_count() -> int:
    var total := 0
    for i in range(STYLE_NAMES.size()):
        if is_style_unlocked(i):
            total += 1
    return total

func choose_style(style: int) -> bool:
    if not is_style_unlocked(style):
        return false
    if selected_style != style:
        selected_style = style
        save()
    return true

func cycle_style() -> int:
    # Unlock order is monotonic, but select via eligibility rather than
    # assuming a sequential progression. The first style is always free.
    for n in range(1,STYLE_NAMES.size()+1):
        var next: int = (selected_style+n)%STYLE_NAMES.size()
        if is_style_unlocked(next):
            choose_style(next)
            return selected_style
    return selected_style

func mastery_summary(index: int) -> String:
    if index < 0 or index >= TRACKS.size():
        return ""
    var parts: Array[String] = []
    for goal in range(MASTERY_GOALS.size()):
        parts.append(("%s " % MASTERY_GOALS[goal]) +
            ("✓" if has_mastery(index,goal) else "○"))
    return "  •  ".join(PackedStringArray(parts))

func complete_mastery(index: int, finished: bool,
    clean_passes: int, shortcut_completed: bool) -> Dictionary:
    # Caller is trusted solo finish logic only. Client/server results are
    # explicitly excluded at the game layer, and a DNF never grants stamps.
    var result: Dictionary = {"new_goals":[],"new_styles":[],
        "count":mastery_count(),"track_count":track_mastery_count(index)}
    if index < 0 or index >= TRACKS.size() or not finished:
        return result
    var previous_total: int = mastery_count()
    var earn: int = 1
    if clean_passes >= 1:
        earn |= 2
    if shortcut_completed:
        earn |= 4
    var before: int = mastery_flags[index]
    var delta: int = earn & (~before)
    if delta == 0:
        return result
    mastery_flags[index] = (before | earn) & ALL_MASTERY_BITS
    var new_goals: Array[String] = []
    for goal in range(MASTERY_GOALS.size()):
        if (delta & (1 << goal)) != 0:
            new_goals.append(MASTERY_GOALS[goal])
    var new_total: int = mastery_count()
    var new_styles: Array[String] = []
    for style in range(1,STYLE_NAMES.size()):
        var threshold: int = STYLE_THRESHOLDS[style]
        if previous_total < threshold and new_total >= threshold:
            new_styles.append(STYLE_NAMES[style])
    result["new_goals"] = new_goals
    result["new_styles"] = new_styles
    result["count"] = new_total
    result["track_count"] = track_mastery_count(index)
    save()
    return result


func league_tier() -> int:
    var tier := 0
    for i in range(LEAGUE_LIMITS.size()):
        if league_points >= LEAGUE_LIMITS[i]:
            tier = i
    return tier

func league_name() -> String:
    return LEAGUE_TIERS[league_tier()]

func league_next_goal() -> int:
    var current: int = league_tier()
    return LEAGUE_LIMITS[current+1] if current+1 < LEAGUE_LIMITS.size() else LEAGUE_LIMITS[current]

func league_progress_label() -> String:
    if league_tier() == LEAGUE_TIERS.size()-1:
        return "LEGEND  •  %d REP  •  TOP LICENSE" % league_points
    return "%s  •  %d / %d REP" % [
        league_name(),league_points,league_next_goal()]

func league_races() -> int:
    var sum := 0
    for amount in league_runs:
        sum += amount
    return sum

func award_league(index: int, place: int, finished: bool,
    clean_passes: int, completed_shortcut: bool) -> Dictionary:
    # The game calls this exactly once during trusted offline result finalization.
    # No client-supplied rank, claim IDs or network RPCs can reach this path.
    var result: Dictionary = {
        "earned":0,"previous":league_name(),"tier":league_name(),
        "promoted":false,"score":league_points,"next":league_next_goal()}
    if not finished or index < 0 or index >= TRACKS.size() or (
        place < 1 or place > 40):
        return result
    var placement: int = 25 if place == 1 else (
        18 if place <= 3 else (
        12 if place <= 10 else (7 if place <= 20 else 4)))
    var clean: int = clampi(clean_passes,0,3)
    var points: int = 10+placement+clean*5+(8 if completed_shortcut else 0)
    if clean == 3 and completed_shortcut:
        points += 5
    var old_tier: int = league_tier()
    league_points = mini(LEAGUE_SCORE_CAP,league_points+points)
    league_runs[index] = mini(1000000,league_runs[index]+1)
    league_clean_passes[index] = mini(1000000,league_clean_passes[index]+clean)
    if completed_shortcut:
        league_shortcuts[index] = mini(1000000,league_shortcuts[index]+1)
    result["earned"] = points
    result["tier"] = league_name()
    result["promoted"] = league_tier() > old_tier
    result["score"] = league_points
    result["next"] = league_next_goal()
    save()
    return result

func best_sector(index: int, sector: int) -> float:
    if index < 0 or index >= TRACKS.size() or sector < 0 or sector >= SECTORS_PER_TRACK:
        return 0.0
    return sector_best[index*SECTORS_PER_TRACK+sector]

func record_sectors(index: int, splits: Array[float]) -> Array[bool]:
    # Only completed races call this function. Reject invalid/missing sector data;
    # a malformed input must never poison the player's permanent records.
    var improved: Array[bool] = [false,false,false,false]
    if index < 0 or index >= TRACKS.size() or splits.size() != SECTORS_PER_TRACK:
        return improved
    for split in splits:
        if not is_finite(split) or split <= 0.0 or split >= 600.0:
            return improved
    for sector in range(SECTORS_PER_TRACK):
        var position := index*SECTORS_PER_TRACK + sector
        var prev := sector_best[position]
        if prev == 0.0 or splits[sector] < prev:
            sector_best[position] = splits[sector]
            improved[sector] = true
    if improved.has(true):
        save()
    return improved

func is_unlocked(index: int) -> bool:
    return index >= 0 and index < unlocked

func next_locked_requirement() -> String:
    if unlocked == 1:
        return "Finish TOP 10 on WOODWORKS to unlock SWITCHBACK."
    if unlocked == 2:
        return "Finish TOP 8 on SWITCHBACK to unlock GAUNTLET."
    return "All three circuits unlocked."
