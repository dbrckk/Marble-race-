extends RefCounted
## Opt-in, allocation-bounded Android diagnostics. Nothing is uploaded.
## Displayed only when the user enables the existing FPS overlay.
const HISTORY_FRAMES := 120
const REPORT_PERIOD := 1.0
const MAX_VALID_FRAME_SECONDS := 0.25
const PHASE_NAMES := ["START","MID-RACE","FINAL SECTOR"]
const FRAME_BUCKET_LIMIT_MS := 250
const LAUNCH_SECONDS := 5.0
const GRID_SECONDS := 1.15
const FIRST_OBSTACLE_HALF_LENGTH := 4.0
const BRIDGE_RETURN_HALF_LENGTH := 8.0
const FOCUS_NAMES := ["FIRST 5s","BRIDGE RETURN ±8 m","GRID LAST 1.15s","FIRST OBSTACLE ±4 m",
    "GAUNTLET BRIDGE JUMP"]
enum Focus { LAUNCH, BRIDGE_RETURN, GRID, FIRST_OBSTACLE, FORGE_BRIDGE_JUMP, NONE }

class PhaseSamples:
    var durations := PackedInt32Array()
    var frames := 0
    var slow_frames := 0
    var monitor_samples := 0
    var physics_sum := 0.0
    var draw_sum := 0

    func _init() -> void:
        durations.resize(FRAME_BUCKET_LIMIT_MS+1)

    func add_frame(delta: float) -> void:
        var milliseconds := delta*1000.0
        durations[ceili(minf(milliseconds,FRAME_BUCKET_LIMIT_MS))] += 1
        frames += 1
        slow_frames += int(milliseconds > 1000.0/30.0)

    func add_monitors(physics_ms: float, draw_calls: int) -> void:
        monitor_samples += 1
        physics_sum += physics_ms
        draw_sum += draw_calls

    func summary() -> String:
        if frames == 0:
            return "NO SAMPLES"
        var target := ceili(frames*0.95)
        var seen := 0
        var p95 := FRAME_BUCKET_LIMIT_MS
        for bucket in range(1,durations.size()):
            seen += durations[bucket]
            if seen >= target:
                p95 = bucket
                break
        return "%d frames | P95 %d%s ms | >33.3 ms %.1f%% | PHYS %s | DRAW %s" % [
            frames,p95,"+" if p95 == FRAME_BUCKET_LIMIT_MS else "",
            100.0*slow_frames/frames,
            "%.1f ms" % (physics_sum/monitor_samples) if monitor_samples > 0 else "—",
            "%.0f" % (float(draw_sum)/monitor_samples) if monitor_samples > 0 else "—"]

var frame_ms := PackedFloat32Array()
var cursor := 0
var elapsed := 0.0
var sample_count := 0
var report: Dictionary = {}
var phases: Array[PhaseSamples] = []
var focus_windows: Array[PhaseSamples] = []
var previous_frame_us := -1
var current_phase := 0
var current_focus := Focus.NONE
var current_course_focus := Focus.NONE

func reset() -> void:
    frame_ms.clear()
    cursor = 0
    elapsed = 0.0
    sample_count = 0
    report.clear()
    phases.clear()
    focus_windows.clear()
    current_phase = 0
    current_focus = Focus.NONE
    current_course_focus = Focus.NONE
    suspend()

func suspend() -> void:
    previous_frame_us = -1

static func focus_at(race_time: float, z: float, bridge_exit_z: float) -> Focus:
    if race_time < LAUNCH_SECONDS:
        return Focus.LAUNCH
    if absf(z-bridge_exit_z) <= BRIDGE_RETURN_HALF_LENGTH:
        return Focus.BRIDGE_RETURN
    return Focus.NONE

static func near_first_obstacle(z: float, entry_z: float) -> bool:
    return absf(z-entry_z) <= FIRST_OBSTACLE_HALF_LENGTH

func record_frame(now_us: int, phase: int, focus: Focus = Focus.NONE,
        course_focus: Focus = Focus.NONE) -> void:
    if phases.is_empty():
        for i in PHASE_NAMES.size():
            phases.append(PhaseSamples.new())
        for i in FOCUS_NAMES.size():
            focus_windows.append(PhaseSamples.new())
    var before := previous_frame_us
    previous_frame_us = now_us
    if before >= 0 and now_us > before:
        var seconds := float(now_us-before)/1000000.0
        var monitor_updated := tick(minf(seconds,MAX_VALID_FRAME_SECONDS))
        if current_phase >= 0:
            var samples := phases[current_phase]
            samples.add_frame(seconds)
            if monitor_updated:
                samples.add_monitors(float(report["physics_ms"]),int(report["draw_calls"]))
        if current_focus != Focus.NONE:
            _record_window(current_focus,seconds,monitor_updated)
        if current_course_focus != Focus.NONE:
            _record_window(current_course_focus,seconds,monitor_updated)
    # Countdown adds to the grid observation, outside official race timing.
    current_phase = -1 if phase < 0 else maxi(current_phase,mini(phase,PHASE_NAMES.size()-1))
    current_focus = focus
    current_course_focus = course_focus

func _record_window(focus: Focus, seconds: float, monitor_updated: bool) -> void:
    var window := focus_windows[focus]
    window.add_frame(seconds)
    if monitor_updated:
        window.add_monitors(float(report["physics_ms"]),int(report["draw_calls"]))
    elif window.monitor_samples == 0:
        # A fast crossing can be shorter than the one-second monitor interval.
        window.add_monitors(_physics_ms(),_draw_calls())

func race_summary(include_forge_jump := false) -> String:
    var any_frames := false
    for samples in phases:
        if samples.frames > 0:
            any_frames = true
            break
    if not any_frames:
        return ""
    var lines := PackedStringArray()
    for i in PHASE_NAMES.size():
        lines.append("%s | %s" % [PHASE_NAMES[i],phases[i].summary()])
    for i in FOCUS_NAMES.size():
        if i == Focus.FORGE_BRIDGE_JUMP and not include_forge_jump:
            continue
        lines.append("%s | %s" % [FOCUS_NAMES[i],focus_windows[i].summary()])
    return "\n".join(lines)

static func _physics_ms() -> float:
    return maxf(0.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)

static func _draw_calls() -> int:
    return maxi(0,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

static func slow_frame_fraction(values: PackedFloat32Array,
    threshold_ms: float = 33.333) -> float:
    if values.is_empty():
        return 0.0
    var slow := 0
    for frame in values:
        if frame > threshold_ms:
            slow += 1
    return float(slow)/float(values.size())

static func percentile_95(values: PackedFloat32Array) -> float:
    if values.is_empty():
        return 0.0
    var ordered := values.duplicate()
    ordered.sort()
    var index: int = clampi(ceili(float(ordered.size())*0.95)-1,0,ordered.size()-1)
    return ordered[index]

func tick(delta: float) -> bool:
    if not is_finite(delta) or delta <= 0.0 or delta > MAX_VALID_FRAME_SECONDS:
        # Ignore resume/background spikes; do not mislabel a paused device
        # as a slow simulation or poison the first second after unpausing.
        return false
    if frame_ms.size() < HISTORY_FRAMES:
        frame_ms.append(delta*1000.0)
    else:
        frame_ms[cursor] = delta*1000.0
    cursor = (cursor+1)%HISTORY_FRAMES
    sample_count += 1
    elapsed += delta
    if elapsed < REPORT_PERIOD:
        return false
    elapsed = fmod(elapsed,REPORT_PERIOD)
    # Godot returns TIME_* in seconds. This monitor sampling runs ~1 Hz.
    # Certain monitors are 0 or delayed in release/headless builds: this
    # is an on-device diagnostic, not a CI phone-performance claim.
    report = {
        "fps": Engine.get_frames_per_second(),
        "p95_ms": percentile_95(frame_ms),
        "slow_pct": slow_frame_fraction(frame_ms)*100.0,
        "process_ms": maxf(0.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0),
        "physics_ms": _physics_ms(),
        "draw_calls": _draw_calls(),
        "frames": frame_ms.size()
    }
    return true

func compact_text() -> String:
    if report.is_empty():
        return "SAMPLING FRAMES..."
    return "P95 %.1fms   SLOW %.0f%%   PHYS %.1fms   DRAW %d" % [
        float(report["p95_ms"]),float(report["slow_pct"]),
        float(report["physics_ms"]),int(report["draw_calls"])]
