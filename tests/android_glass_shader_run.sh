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
        if grep -Fq GLASS_PAIR_DEVICE capture/logcat.txt; then
            break 2
        fi
        if ! adb shell pidof "$package" >/dev/null; then break; fi
        sleep 2
    done
    kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true
    cp capture/logcat.txt "capture/start-attempt-$launch.txt"
done
for attempt in $(seq 1 66); do
    if grep -Eq 'GLASS_PAIR_PASS|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if ! adb shell pidof "$package" >/dev/null; then break; fi
    sleep 5
done
adb exec-out screencap -p >capture/results.png || true
for label in plain-0 plain-1 premium-0 premium-1 premium-2; do
    for revision in 0 1; do
        file="$label-$revision.png"
        adb exec-out run-as "$package" cat "files/$file" >"capture/$file"
        test -s "capture/$file"
    done
    cmp "capture/$label-0.png" "capture/$label-1.png"
    echo "PIXEL_MATCH $label"
done
grep -E 'GLASS_PAIR|SCRIPT ERROR|FATAL EXCEPTION|Shader compilation' capture/logcat.txt |
    tail -n 23 | tee capture/measurements.txt
shader_errors="$(grep -Ec 'GL_MAX_FRAGMENT_UNIFORM_VECTORS|ShaderGLES3: Program linking failed' capture/logcat.txt || true)"
echo "GLES shader link diagnostics: $shader_errors"
grep -Fq GLASS_PAIR_PASS capture/measurements.txt
test "$(grep -c 'GLASS_PAIR {' capture/measurements.txt)" = 12
if grep -Eq 'SCRIPT ERROR|FATAL EXCEPTION|Shader compilation failed' capture/logcat.txt; then exit 1; fi
test "$shader_errors" = 0
