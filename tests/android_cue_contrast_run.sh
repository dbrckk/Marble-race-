#!/usr/bin/env bash
set -euo pipefail

mkdir -p capture
adb shell wm size 360x640
adb shell wm density 160
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell getprop ro.build.version.sdk
adb shell dumpsys SurfaceFlinger | grep -i GLES | head -n 2 || true
adb install build/marble-race-qa.apk
package=com.dbrckk.marble_race
adb shell wm user-rotation lock 1
sleep 3
for launch in 1 2 3; do
    adb shell am force-stop "$package"
    adb logcat -c
    adb logcat -v brief >capture/logcat.txt &
    log_pid=$!
    trap 'kill "$log_pid" 2>/dev/null || true' EXIT
    adb shell am start -W -n "$package/com.godot.game.GodotApp"
    for second in $(seq 1 22); do
        if grep -Fq OPENING_BENCH_DEVICE capture/logcat.txt; then
            break 2
        fi
        if ! adb shell pidof "$package" >/dev/null; then break; fi
        sleep 2
    done
    kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
    cp capture/logcat.txt "capture/start-attempt-$launch.txt"
done
for attempt in $(seq 1 155); do
    if grep -Eq 'OPENING_BENCH_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/shadow-budget.jsonl >capture/shadow-budget.jsonl
for mode in balanced single36; do
    for pose in 15 44 64 76; do
        file="$mode-$pose.png"
        adb exec-out run-as "$package" cat "files/$file" >"capture/$file"
    done
done
grep -E 'OPENING_BENCH|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq OPENING_BENCH_PASS capture/measurements.txt
python - <<'PY'
from collections import Counter
from pathlib import Path
from statistics import median
import json

rows=[json.loads(l) for l in Path("capture/shadow-budget.jsonl").read_text().splitlines()]
assert len(rows)==4
assert Counter(x["mode"] for x in rows)=={"balanced":2,"single36":2}
for label in ("balanced","single36"):
    for frame in (15,44,64,76):
        assert Path(f"capture/{label}-{frame}.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
reference=[(f["stage"],f["z"]) for f in rows[0]["frames"]]
for row in rows:
    assert [(f["stage"],f["z"]) for f in row["frames"]]==reference
    assert set(f["stage"] for f in row["frames"]) >= {"grid","launch","obstacle"}
    print(row["trial"],row["mode"],len(row["frames"]),median(f["ms"] for f in row["frames"]))
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
