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
        if grep -Fq WOOD_DETAIL_DEVICE capture/logcat.txt; then
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
    if grep -Eq 'WOOD_DETAIL_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/wood-detail.jsonl >capture/wood-detail.jsonl || true
for pose in grid grazing first_module sector_two; do
    for mode in stock no_normal no_filaments depth; do
        if [[ "$pose" == grazing && "$mode" != stock && "$mode" != depth ]]; then continue; fi
        file="wood-$pose-$mode.png"
        adb exec-out run-as "$package" cat "files/$file" >"capture/$file" || true
    done
done
grep -E 'WOOD_DETAIL|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq WOOD_DETAIL_PASS capture/measurements.txt
python - <<'PY'
from collections import Counter,defaultdict
from pathlib import Path
import json

root=Path("capture")
rows=[json.loads(line) for line in (root/"wood-detail.jsonl").read_text().splitlines()]
assert len(rows)==32
assert set(Counter((r["pose"],r["mode"]) for r in rows).values())=={2}
views=defaultdict(set)
for r in rows:
    views[r["pose"]].add((r["draws"],r["triangles"]))
assert len(views)==4 and all(len(v)==1 for v in views.values()),views
frames=list(root.glob("wood-*.png"))
assert len(frames)==14
assert all(p.read_bytes().startswith(b"\x89PNG\r\n\x1a\n") for p in frames)
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
