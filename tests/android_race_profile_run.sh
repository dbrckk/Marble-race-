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
        if grep -Fq RACE_PROFILE_DEVICE capture/logcat.txt; then
            break 2
        fi
        if ! adb shell pidof "$package" >/dev/null; then break; fi
        sleep 2
    done
    kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
    cp capture/logcat.txt "capture/start-attempt-$launch.txt"
done
for attempt in $(seq 1 105); do
    if grep -Eq 'RACE_PROFILE_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/race-profile.jsonl >capture/race-profile.jsonl || true
adb exec-out run-as "$package" cat files/opening.png >capture/opening.png || true
grep -E 'RACE_PROFILE|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq RACE_PROFILE_PASS capture/measurements.txt
test "$(grep -c 'RACE_PROFILE_RUN ' capture/measurements.txt)" = 8
test -s capture/opening.png
python - <<'PY'
import json
from collections import Counter
from pathlib import Path

rows = [json.loads(line) for line in Path("capture/race-profile.jsonl").read_text().splitlines()]
assert len(rows) == 24
assert set(Counter((r["phase"], r["draw_3d"], r["skip_forecasts"]) for r in rows).values()) == {2}
for row in rows:
    assert len(row["ticks"]) >= 5 and len(row["frames"]) >= 3, row["run"]
    if row["phase"] != "grid":
        if row["skip_forecasts"]:
            assert max(tick[2] for tick in row["ticks"]) == 0
        else:
            assert max(tick[2] for tick in row["ticks"]) >= 35
print("24 windows include paired baseline and candidate runs with identical settings")
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
