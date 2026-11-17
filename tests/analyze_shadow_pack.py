"""Verify paired renderer timing samples and summarize per-window P95."""
from collections import Counter
from math import ceil, isfinite
from pathlib import Path
from statistics import median
import json
import sys

tracks = ("Woodworks", "Glacier", "Forge")
windows = {"grid": 34, "merge": 41}
rows = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
assert len(rows) == 12
assert {(row["track"], row["trial"]) for row in rows} == {
    (track, trial) for track in range(3) for trial in range(4)
}

def p95(values):
    return sorted(values)[ceil(len(values) * 0.95) - 1]

result = []
for track, name in enumerate(tracks):
    trials = sorted((row for row in rows if row["track"] == track), key=lambda row: row["trial"])
    expected = ["current", "old", "old", "current"] if track % 2 else ["old", "current", "current", "old"]
    assert [row["mode"] for row in trials] == expected
    assert Counter(row["mode"] for row in trials) == {"old": 2, "current": 2}
    for phase, count in windows.items():
        reference = trials[0]["sections"][phase]
        assert len(reference) == count
        assert min(f["z"] for f in reference) == max(f["z"] for f in reference) if phase == "grid" else (
            abs(reference[0]["z"] + 96) < 0.001 and abs(reference[-1]["z"] + 112) < 0.001)
        timing = {"old": [], "current": []}
        draw_calls = {"old": [], "current": []}
        for row in trials:
            samples = row["sections"][phase]
            assert len(samples) == count
            assert [(f["pose"], f["z"]) for f in samples] == [
                (f["pose"], f["z"]) for f in reference
            ], (track, phase, row["trial"], "mismatched camera or path")
            assert all(isfinite(f["ms"]) and f["ms"] > 0 and f["draws"] > 0 for f in samples)
            timing[row["mode"]].append(p95([f["ms"] for f in samples]))
            draw_calls[row["mode"]].append(median(f["draws"] for f in samples))
        old, current = median(timing["old"]), median(timing["current"])
        draw_old, draw_current = median(draw_calls["old"]), median(draw_calls["current"])
        change = 100 * (current / old - 1)
        result.append({"track": name, "window": phase, "old_ms": old,
            "current_ms": current, "change_pct": change, "old_draws": draw_old,
            "current_draws": draw_current, "trial_p95": timing})
        print(f"{name:10} {phase:5} | P95 {old:6.1f} → {current:6.1f} ms ({change:+.1f}%)"
              f" | Draws {draw_old:.1f} → {draw_current:.1f} | trials {timing}")
if len(sys.argv) > 2:
    Path(sys.argv[2]).write_text(json.dumps(result, indent=2) + "\n")
