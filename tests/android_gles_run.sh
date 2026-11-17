#!/usr/bin/env bash
set -euo pipefail

mkdir -p capture
adb shell wm size 360x640
adb shell wm density 160
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell getprop ro.build.version.sdk
adb shell dumpsys SurfaceFlinger | grep -i GLES | head -n 2 || true
adb install build/marble-race-qa.apk
adb logcat -c
adb logcat -v brief >capture/logcat.txt &
log_pid=$!
trap 'kill "$log_pid" 2>/dev/null || true' EXIT
adb shell monkey -p com.dbrckk.marble_race -c android.intent.category.LAUNCHER 1

for attempt in $(seq 1 112); do
    if grep -Eq 'MARBLE_GLES_(PASS|FAILURE)|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if [[ "$attempt" = 17 ]] && ! grep -Fq MARBLE_GLES_DEVICE capture/logcat.txt; then
        break
    fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
for phase in balanced-launch balanced-merge economy-launch economy-merge; do
    if adb shell run-as com.dbrckk.marble_race test -f "files/marble-gles-$phase.png"; then
        adb exec-out run-as com.dbrckk.marble_race cat "files/marble-gles-$phase.png" >"capture/$phase.png"
    fi
done
grep -E 'MARBLE_GLES_|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt |
    tail -n 30 | tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq MARBLE_GLES_PASS capture/measurements.txt
test "$(grep -c 'MARBLE_GLES_FRAME ' capture/measurements.txt)" = 4
test "$shader_errors" = 0
