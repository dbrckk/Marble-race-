#!/usr/bin/env bash
set -euo pipefail

mkdir -p capture
adb shell wm size 540x960
adb shell wm density 240
adb shell wm size
adb shell getprop ro.build.version.sdk
adb install build/marble-race-qa.apk
adb logcat -c
adb logcat -v brief > capture/logcat.txt &
log_pid=$!
trap 'kill "$log_pid" 2>/dev/null || true' EXIT
adb shell monkey -p com.dbrckk.marble_race -c android.intent.category.LAUNCHER 1

for attempt in $(seq 1 103); do
    if grep -Eq 'MARBLE_BENCH_(COMPLETE|FAILURE)|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    if [[ "$attempt" = 14 ]] && ! grep -Fq MARBLE_BENCH_DEVICE capture/logcat.txt; then
        echo 'The capture script never started.'
        break
    fi
    sleep 5
done

adb exec-out screencap -p > capture/results.png || true
grep -E 'MARBLE_BENCH_|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt |
    tail -n 30 | tee capture/measurements.txt
grep -Fq MARBLE_BENCH_COMPLETE capture/measurements.txt
test "$(grep -c 'MARBLE_BENCH_REPORT ' capture/measurements.txt)" = 2
