#!/usr/bin/env bash
set -euo pipefail
mode="${1:?usage: android_upgrade_emulator.sh preflight|install}"
pkg=com.dbrckk.marble_race
base_apk=build/upgrade-a.apk
updated_apk=build/upgrade-b.apk
tools="$ANDROID_HOME/build-tools/35.0.0"

identity() {
  local apk="$1" badging code cert
  "$tools/apksigner" verify --verbose "$apk" >/dev/null
  badging="$("$tools/aapt" dump badging "$apk" | sed -n '/^package:/p')"
  [[ "$badging" == *"name='$pkg'"* ]] || { echo "Wrong package: $badging" >&2; return 1; }
  code="$(sed -n "s/.*versionCode='\([0-9][0-9]*\)'.*/\1/p" <<< "$badging")"
  cert="$("$tools/apksigner" verify --print-certs "$apk" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')"
  [[ "$code" =~ ^[0-9]+$ && "$cert" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  printf '%s %s\n' "$code" "$cert"
}

test -s "$base_apk" && test -s "$updated_apk"
read -r code_a cert_a < <(identity "$base_apk")
read -r code_b cert_b < <(identity "$updated_apk")
[[ "$cert_a" == "$cert_b" && "$code_b" -gt "$code_a" ]] || {
  echo "Upgrade blocked: certificates differ or version does not increase" >&2
  exit 1
}
printf 'Package: %s\nA code: %s\nB code: %s\nCert SHA256: %s\n' "$pkg" "$code_a" "$code_b" "$cert_a" | tee build/upgrade-identity.txt
if [[ "$mode" == preflight ]]; then
  echo "ANDROID_UPGRADE_PREFLIGHT_PASS: same certificate, ascending version, same package"
  exit 0
fi
[[ "$mode" == install ]] || exit 2

capture_failure() {
  local result=$?
  if (( result != 0 )); then
    {
      adb shell "run-as $pkg ls -l files" || true
      adb shell dumpsys activity exit-info "$pkg" || true
      adb logcat -d -b main -b system -b crash || true
    } > build/android-upgrade-logcat.txt 2>&1
  fi
}
trap capture_failure EXIT

wait_for_game() {
  local phase="$1" apk="$2" proof activity attempts=120 attempt
  activity="$("$tools/aapt" dump badging "$apk" | sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p")"
  [[ -n "$activity" ]] || { echo "No launcher activity in $apk" >&2; return 1; }
  adb shell am start -n "$pkg/$activity"
  for ((attempt=0; attempt<attempts; attempt++)); do
    proof="$(adb shell "run-as $pkg cat files/android-upgrade-$phase.txt" 2>/dev/null | tr -d '\r' || true)"
    case "$proof" in
      pass) echo "Game confirmed the $phase phase"; return 0 ;;
      fail) echo "Game reported a failure during $phase" >&2; return 1 ;;
    esac
    sleep 1
  done
  echo "No game result for $phase after $attempts attempts" >&2
  return 1
}

save_digests() {
  adb shell "run-as $pkg sh -c 'sha256sum files/marble_career.cfg files/marble_ghosts.cfg files/marble_settings.cfg'" | tr -d '\r'
}

# Keep graphics work low when the Android system runs in software.
adb shell wm size 720x1280
adb shell wm density 240
adb logcat -G 4M || true
adb logcat -c
adb install --no-incremental "$base_apk"
wait_for_game seed "$base_apk"
adb shell am force-stop "$pkg"
before="$(save_digests)"
if (( $(wc -l <<< "$before") != 3 )); then
  echo "Expected three save-file digests after running the first APK" >&2
  exit 1
fi

adb install --no-incremental -r "$updated_apk"
actual="$(adb shell dumpsys package "$pkg" | sed -n "s/^[[:space:]]*versionCode=\([0-9][0-9]*\)[[:space:]].*/\1/p" | tr -d '\r')"
[[ "$actual" == "$code_b" ]] || { echo "Unexpected installed version: $actual" >&2; exit 1; }
[[ "$(save_digests)" == "$before" ]] || { echo "Saved files changed during installation" >&2; exit 1; }

wait_for_game verify "$updated_apk"
[[ "$(save_digests)" == "$before" ]] || { echo "Saved files changed on relaunch" >&2; exit 1; }
echo "ANDROID_UPGRADE_EMULATOR_PASS: the updated game loaded the career, ghost and settings"
