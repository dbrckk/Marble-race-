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
        if grep -Fq WOOD_SHADOW_DEVICE capture/logcat.txt; then
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
    if grep -Eq 'WOOD_SHADOW_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/woodworks-shadows.jsonl >capture/woodworks-shadows.jsonl || true
for layout in 0 1 2; do
    for pose in grid opening; do
        for mode in 0 1; do
            file="shadow-$layout-$pose-$mode.png"
            adb exec-out run-as "$package" cat "files/$file" >"capture/$file" || true
        done
    done
done
grep -E 'WOOD_SHADOW|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq WOOD_SHADOW_PASS capture/measurements.txt
test "$(grep -c 'WOOD_SHADOW_LAYOUT ' capture/measurements.txt)" = 3
python - <<'PY'
from collections import defaultdict
from pathlib import Path
import json

rows = [json.loads(x) for x in Path("capture/woodworks-shadows.jsonl").read_text().splitlines()]
pairs = defaultdict(dict)
assert len(rows) == 12
for r in rows:
    pairs[(r["layout"],r["phase"])][r["candidate"]] = r
    capture = Path("capture/shadow-%d-%s-%d.png" % (r["layout"],r["phase"],r["candidate"]))
    assert capture.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
assert len(pairs) == 6
for key, pair in pairs.items():
    assert len(pair) == 2 and pair[True]["draws"] < pair[False]["draws"], pair
    assert pair[True]["z"] == pair[False]["z"]
    assert pair[True]["signal"] == pair[False]["signal"]
    print(key, pair[False]["draws"], "->", pair[True]["draws"])
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
