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
        if grep -Fq HUD_PROFILE_DEVICE capture/logcat.txt; then
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
    if grep -Eq 'HUD_PROFILE_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/hud-profile.jsonl >capture/hud-profile.jsonl || true
for phase in grid real_opening fast_opening; do
    for mode in 0 1; do
        file="hud-$phase-$mode.png"
        adb exec-out run-as "$package" cat "files/$file" >"capture/$file" || true
    done
done
grep -E 'HUD_PROFILE|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq HUD_PROFILE_PASS capture/measurements.txt
grep -Fq HUD_PROFILE_TOUCH capture/measurements.txt
python - <<'PY'
from collections import defaultdict
from pathlib import Path
import json

root=Path("capture")
rows=[json.loads(line) for line in (root/"hud-profile.jsonl").read_text().splitlines()]
assert len(rows)==6
views=defaultdict(dict)
for r in rows:
    views[r["phase"]][r["candidate"]]=r
    file=root/("hud-%s-%d.png" % (r["phase"],int(r["candidate"])))
    assert file.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
assert len(views)==3
for phase,pair in views.items():
    a,b=pair[False],pair[True]
    assert a["draws"]-b["draws"]>=35,pair
    assert a["board"]==b["board"] and a["opponents"]==b["opponents"]==39
    assert a["alert"]==b["alert"] and a["speed"]==b["speed"]
    assert b["area"]<a["area"]*0.75,pair
    print(phase,a["draws"],"->",b["draws"],"area",a["area"],"->",b["area"])
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
