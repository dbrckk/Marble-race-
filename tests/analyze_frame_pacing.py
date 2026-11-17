"""Validate equal simulated time and summarize wall-clock frame intervals."""
import json
import math
from pathlib import Path
from statistics import median
import sys

tracks = ("Woodworks", "Glacier", "Forge")
windows = ("grid", "merge")
rows = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
assert len(rows) == 12
assert {(row["track"], row["trial"]) for row in rows} == {
    (track, trial) for track in range(3) for trial in range(4)
}

def p95(values):
    return sorted(values)[math.ceil(len(values) * 0.95) - 1]

report = []
for track, name in enumerate(tracks):
    trials = sorted((row for row in rows if row["track"] == track), key=lambda row: row["trial"])
    expected_order = ("current", "reference", "reference", "current") if track % 2 else (
        "reference", "current", "current", "reference")
    assert tuple(row["mode"] for row in trials) == expected_order
    for phase in windows:
        reference = trials[0]["sections"][phase]
        modes = {mode: [] for mode in ("reference", "current")}
        max_deviation = 0.0
        for trial in trials:
            frames = trial["sections"][phase]
            assert len(frames) == 28
            assert all(f["steps"] == 2 for f in frames), (track, phase, [f["steps"] for f in frames])
            assert all(math.isfinite(f["ms"]) and f["ms"] > 0 and f["draws"] > 0 for f in frames)
            assert abs(frames[-1]["race_time"] - reference[-1]["race_time"]) < 0.0001
            max_deviation = max(max_deviation, max(abs(a["z"] - b["z"]) for a, b in zip(frames, reference)))
            modes[trial["mode"]].append({
                "p95": p95([f["ms"] for f in frames]),
                "median": median(f["ms"] for f in frames),
                "draws": median(f["draws"] for f in frames),
            })
        assert max_deviation < 0.25, (track, phase, max_deviation)
        assert reference[0]["race_time"] == 0 and reference[-1]["race_time"] > 0.2 if phase == "grid" else (
            reference[0]["z"] > -104 and reference[-1]["z"] < -104 and reference[-1]["race_time"] > 11.8
        ), (track, phase, reference[0], reference[-1])
        old, new = [median(row["p95"] for row in trials) for trials in modes.values()]
        report.append({
            "track": name, "phase": phase, "p95_reference_ms": old, "p95_current_ms": new,
            "delta_pct": (new / old - 1) * 100, "max_player_z_delta_m": max_deviation, "trials": modes,
        })
        print(f"{name:10} {phase:5} | P95 {old:6.1f} → {new:6.1f} ms ({(new / old - 1) * 100:+.1f}%)"
              f" | z deviation ≤ {max_deviation:.3f} m | trials {modes}")
if len(sys.argv) > 2:
    Path(sys.argv[2]).write_text(json.dumps(report, indent=2) + "\n")
