#!/usr/bin/env bash
set -euo pipefail

mkdir -p capture
adb shell wm size 540x960
adb shell wm density 240
# Equivalent to accepting Android's first-run full-screen tutorial on the test device.
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell getprop ro.build.version.sdk
adb install build/marble-race-qa.apk
adb logcat -c
adb logcat -v brief > capture/logcat.txt &
log_pid=$!
trap 'kill "$log_pid" 2>/dev/null || true' EXIT
adb shell monkey -p com.dbrckk.marble_race -c android.intent.category.LAUNCHER 1

tap=''
for attempt in $(seq 1 45); do
    tap="$(sed -nE 's/.*MARBLE_CLIPBOARD_READY ([0-9]+) ([0-9]+).*/\1 \2/p' capture/logcat.txt | tail -1)"
    if [[ -n "$tap" ]] || grep -Eq 'MARBLE_CLIPBOARD_FAILURE|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
        break
    fi
    sleep 2
done
if [[ -n "$tap" ]]; then
    read -r x y <<< "$tap"
    adb shell input tap "$x" "$y"
    for attempt in $(seq 1 21); do
        if grep -Eq 'MARBLE_CLIPBOARD_(PASS|FAILURE)|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt; then
            break
        fi
        sleep 2
    done
fi
adb exec-out screencap -p > capture/results.png || true
grep -E 'MARBLE_CLIPBOARD_|SCRIPT ERROR|FATAL EXCEPTION' capture/logcat.txt |
    tail -n 30 | tee capture/clipboard-test.txt
grep -Fq MARBLE_CLIPBOARD_PASS capture/clipboard-test.txt
