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
adb exec-out run-as "$package" cat files/shadow-motion.jsonl >capture/shadow-motion.jsonl
adb exec-out run-as "$package" tar -c -f - -C files . >capture/frames.tar
grep -E 'OPENING_BENCH|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq OPENING_BENCH_PASS capture/measurements.txt
python - <<'PY'
from pathlib import Path
import itertools
import json
import tarfile

root=Path("capture")
rows=[json.loads(l) for l in (root/"shadow-motion.jsonl").read_text().splitlines()]
assert len(rows)==36
expected=set(itertools.product(range(3),range(3),("baseline","double","single","unshadowed")))
assert {(r["layout"],r["section"],r["mode"]) for r in rows}==expected
with tarfile.open(root/"frames.tar") as archive:
    pngs={Path(member.name).name:member for member in archive.getmembers() if member.isfile() and member.name.endswith(".png")}
    assert len(pngs)==432
    for layout,section,mode in expected:
        for frame in range(12):
            member=pngs[f"l{layout}-s{section}-{mode}-{frame:02d}.png"]
            assert archive.extractfile(member).read(8)==b"\x89PNG\r\n\x1a\n"
assert all(len(r["draw_calls"])==12 for r in rows)
print("Validated 432 frames across nine matched camera paths")
PY
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
