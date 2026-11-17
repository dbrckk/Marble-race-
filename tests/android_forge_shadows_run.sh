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
package=com.dbrckk.marble_race
adb shell wm user-rotation lock 1
sleep 3
for launch in 1 2 3; do
    adb shell am force-stop "$package"
    : > capture/logcat.txt
    adb shell am start -W -n "$package/com.godot.game.GodotApp"
    for second in $(seq 1 22); do
        if grep -Fq SHADOW_SWEEP_DEVICE capture/logcat.txt; then
            break 2
        fi
        if ! adb shell pidof "$package" >/dev/null; then break; fi
        sleep 2
    done
    cp capture/logcat.txt "capture/start-attempt-$launch.txt"
done
for attempt in $(seq 1 66); do
    if grep -Eq 'SHADOW_SWEEP_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
for pose in 0 2; do
    for mode in stock two47 two33 off; do
        file="shadow-$pose-$mode.png"
        adb exec-out run-as com.dbrckk.marble_race cat "files/$file" >"capture/$file" || true
    done
done
grep -E 'SHADOW_SWEEP|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt |
    tail -n 23 | tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq SHADOW_SWEEP_PASS capture/measurements.txt
test "$(grep -c 'SHADOW_SWEEP {' capture/measurements.txt)" = 8
for frame in capture/shadow-*.png; do test -s "$frame"; done
test "$shader_errors" = 0
