extends RefCounted
## Validated offline championship progress, kept separately from controls/graphics.
var save_path := "user://marble_career.cfg"
const TRACKS := ["WOODWORKS", "SWITCHBACK", "GAUNTLET"]
const TARGETS := [10, 8, 1]

var starts := 0
var finishes := 0
var victories := 0
var podiums := 0
var track_best: Array[int] = [0, 0, 0]
var track_time: Array[float] = [0.0, 0.0, 0.0]
var unlocked := 1
var stars: Array[int] = [0,0,0]
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
        for sector in range(SECTORS_PER_TRACK):
            var saved := float(file.get_value("sectors","best_%d_%d" % [index,sector],0.0))
            sector_best[index*SECTORS_PER_TRACK+sector] = saved if is_finite(saved) and saved > 0.0 and saved < 600.0 else 0.0
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
        for sector in range(SECTORS_PER_TRACK):
            file.set_value("sectors","best_%d_%d" % [index,sector],sector_best[index*SECTORS_PER_TRACK+sector])
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
