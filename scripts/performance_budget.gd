extends RefCounted
## Opt-in, allocation-bounded Android diagnostics. Nothing is uploaded.
## Displayed only when the user enables the existing FPS overlay.
const HISTORY_FRAMES := 120
const REPORT_PERIOD := 1.0
const MAX_VALID_FRAME_SECONDS := 0.25

var frame_ms := PackedFloat32Array()
var cursor := 0
var elapsed := 0.0
var sample_count := 0
var report: Dictionary = {}

func reset() -> void:
    frame_ms.clear()
    cursor = 0
    elapsed = 0.0
    sample_count = 0
    report.clear()

static func percentile_95(values: PackedFloat32Array) -> float:
    if values.is_empty():
        return 0.0
    var ordered := values.duplicate()
    ordered.sort()
    var index: int = clampi(ceili(float(ordered.size())*0.95)-1,0,ordered.size()-1)
    return ordered[index]

func tick(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0 or delta > MAX_VALID_FRAME_SECONDS:
        # Ignore resume/background spikes; do not mislabel a paused device
        # as a slow simulation or poison the first second after unpausing.
        return
    if frame_ms.size() < HISTORY_FRAMES:
        frame_ms.append(delta*1000.0)
    else:
        frame_ms[cursor] = delta*1000.0
    cursor = (cursor+1)%HISTORY_FRAMES
    sample_count += 1
    elapsed += delta
    if elapsed < REPORT_PERIOD:
        return
    elapsed = fmod(elapsed,REPORT_PERIOD)
    # Godot returns TIME_* in seconds. This monitor sampling runs ~1 Hz.
    # Certain monitors are 0 or delayed in release/headless builds: this
    # is an on-device diagnostic, not a CI phone-performance claim.
    report = {
        "fps": Engine.get_frames_per_second(),
        "p95_ms": percentile_95(frame_ms),
        "process_ms": maxf(0.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0),
        "physics_ms": maxf(0.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0),
        "draw_calls": maxi(0,int(Performance.get_monitor(
            Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
        "frames": frame_ms.size()
    }

func compact_text() -> String:
    if report.is_empty():
        return "SAMPLING FRAMES..."
    return "P95 %.1fms   PHYS %.1fms   DRAW %d" % [
        float(report["p95_ms"]),float(report["physics_ms"]),
        int(report["draw_calls"])]
