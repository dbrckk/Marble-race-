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
        if grep -Fq SURFACE_PROFILE_DEVICE capture/logcat.txt; then
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
    if grep -Eq 'SURFACE_PROFILE_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
adb exec-out run-as "$package" cat files/surface-profile.jsonl >capture/surface-profile.jsonl || true
for mode in legacy mips; do
    adb exec-out run-as "$package" cat "files/grid-$mode.png" >"capture/grid-$mode.png" || true
    for frame in $(seq -w 0 13); do
        for offset in 0 1; do
            file="pass-$mode-$frame-$offset.png"
            adb exec-out run-as "$package" cat "files/$file" >"capture/$file" || true
        done
    done
done
grep -E 'SURFACE_PROFILE|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq SURFACE_PROFILE_PASS capture/measurements.txt
python - <<'PY'
from collections import Counter
from pathlib import Path
import json

root = Path("capture")
rows = [json.loads(line) for line in (root/"surface-profile.jsonl").read_text().splitlines()]
assert Counter(r["kind"] for r in rows) == {"timing":8,"texture":3}
assert {r["name"] for r in rows if r["kind"]=="texture"} == {"oak_albedo","oak_normal","micro_texture"}
for r in rows:
    if r["kind"]=="texture":
        assert r["bytes_base"] < r["bytes_mips"]
timed = [r for r in rows if r["kind"]=="timing"]
assert len({(r["mode"],r["block"]) for r in timed}) == 8
assert len({(r["draws"],r["triangles"]) for r in timed})==1,timed
frames = list(root.glob("pass-*.png"))+list(root.glob("grid-*.png"))
assert len(frames) == 58
assert all(p.read_bytes().startswith(b"\x89PNG\r\n\x1a\n") for p in frames)
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
