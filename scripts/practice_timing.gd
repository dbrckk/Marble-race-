extends RefCounted
## In-memory timing for the last solo run on the same layout and perk.
## Passage boundaries are fixed on both routes by downhill Z.
const ShortcutRoute = preload("res://scripts/shortcut_route.gd")
const PASSAGES := 4
const PASSAGE_LOSS_COLOR := Color("#ff9584")
const MAX_SAMPLE_SECONDS := 0.25
const MAX_SAMPLE_SPEED := 36.0
const MIN_LOSS_CENTISECONDS := 2

var boundaries := PackedFloat64Array()
var crossings := PackedFloat64Array()
var previous_position := Vector3.ZERO
var previous_time := 0.0

func begin(position: Vector3, checkpoints: Array, finish_z: float) -> void:
    boundaries = PackedFloat64Array([position.z])
    for checkpoint in checkpoints:
        boundaries.append(float(checkpoint))
    boundaries.append(finish_z)
    crossings.resize((boundaries.size()-1)*(PASSAGES-1))
    crossings.fill(NAN)
    previous_position = position
    previous_time = 0.0

func sample(stage: Node3D, position: Vector3, clock: float) -> void:
    var start := previous_position
    var start_time := previous_time
    previous_position = position
    previous_time = clock
    var elapsed := clock-start_time
    var forward := start.z-position.z
    if forward <= 0.0 or elapsed <= 0.0 or elapsed > MAX_SAMPLE_SECONDS or (
            start.distance_to(position) > maxf(0.85,elapsed*MAX_SAMPLE_SPEED)):
        return
    for sector in boundaries.size()-1:
        var entry := boundaries[sector]
        var exit := boundaries[sector+1]
        if start.z < exit or position.z > entry:
            continue
        for part in range(1,PASSAGES):
            var index := sector*(PASSAGES-1)+part-1
            var plane := lerpf(entry,exit,float(part)/PASSAGES)
            if is_finite(crossings[index]) or start.z < plane or position.z >= plane:
                continue
            var fraction := (start.z-plane)/forward
            if _over_racing_surface(stage,start.lerp(position,fraction)):
                crossings[index] = lerpf(start_time,clock,fraction)

static func _over_racing_surface(stage: Node3D, at: Vector3) -> bool:
    var height: float = stage.height_at(at.z)
    if absf(at.x-stage.track_center_at(at.z)) <= stage.FINISH_HALF_WIDTH+0.12 and (
            at.y >= height-0.30 and at.y <= height+stage.FINISH_AIR_CLEARANCE):
        return true
    if not is_instance_valid(stage.shortcut_route) or at.z > ShortcutRoute.ENTRY_Z or at.z < ShortcutRoute.EXIT_Z:
        return false
    var bridge: Vector3 = stage.shortcut_route.point_at(at.z)
    return absf(at.x-bridge.x) <= ShortcutRoute.WIDTH*0.5+0.12 and (
        at.y >= bridge.y and at.y <= bridge.y+stage.FINISH_AIR_CLEARANCE)

func durations(sector: int, start_time: float, finish_time: float) -> PackedFloat64Array:
    var times := PackedFloat64Array()
    if sector < 0 or sector+1 >= boundaries.size():
        return times
    for part in PASSAGES:
        var split := finish_time if part == PASSAGES-1 else crossings[sector*(PASSAGES-1)+part]
        if not is_finite(split) or split <= start_time or split > finish_time:
            return PackedFloat64Array()
        times.append(split-start_time)
        start_time = split
    return times

static func target_comparison(number: int, previous: PackedFloat64Array,
        current: PackedFloat64Array) -> Dictionary:
    if number < 1 or number > PASSAGES or previous.size() != PASSAGES or current.size() != PASSAGES:
        return {}
    var before := previous[number-1]
    var after := current[number-1]
    if not is_finite(before) or not is_finite(after) or before <= 0.0 or after <= 0.0:
        return {}
    return {"number":number,"previous":before,"current":after}

func worst_loss(sector: int, previous: PackedFloat64Array, current: PackedFloat64Array) -> Dictionary:
    if previous.size() != PASSAGES or current.size() != PASSAGES:
        return {}
    var worst := -1
    var loss := MIN_LOSS_CENTISECONDS-1
    for part in PASSAGES:
        var gap := roundi((current[part]-previous[part])*100.0)
        if gap > loss:
            worst = part
            loss = gap
    if worst < 0:
        return {}
    return {"number":worst+1,"loss":float(loss)/100.0,
        "span":passage_span(Vector2(boundaries[sector],boundaries[sector+1]),worst+1)}

static func passage_span(bounds: Vector2, number: int) -> Vector2:
    if number < 1 or number > PASSAGES:
        return Vector2.ZERO
    return Vector2(lerpf(bounds.x,bounds.y,float(number-1)/PASSAGES),
        lerpf(bounds.x,bounds.y,float(number)/PASSAGES))
