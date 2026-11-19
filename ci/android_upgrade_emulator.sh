#!/usr/bin/env bash
# Verify a real Android PackageManager update, not just matching APK metadata.
set -euo pipefail
mode="${1:?usage: android_upgrade_emulator.sh preflight|install}"
pkg=com.dbrckk.marble_race
a=build/upgrade-a.apk
b=build/upgrade-b.apk
tools="$ANDROID_HOME/build-tools/35.0.0"
test -s "$a" && test -s "$b"
identity() {
  local apk="$1" badging code cert
  "$tools/apksigner" verify --verbose "$apk" >/dev/null
  badging="$("$tools/aapt" dump badging "$apk" | grep -m1 '^package:')"
  [[ "$badging" == *"name='$pkg'"* ]] || { echo "Wrong package: $badging" >&2; return 1; }
  code="$(sed -n "s/.*versionCode='\([0-9][0-9]*\)'.*/\1/p" <<< "$badging")"
  cert="$("$tools/apksigner" verify --print-certs "$apk" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n1)"
  [[ "$code" =~ ^[0-9]+$ && "$cert" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  printf '%s %s\n' "$code" "$cert"
}
read -r code_a cert_a < <(identity "$a")
read -r code_b cert_b < <(identity "$b")
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
adb wait-for-device
adb shell getprop sys.boot_completed | grep -q 1
# A real Android installation and launch; run-as only works for debuggable builds.
adb install "$a"
adb shell am start -n "$pkg/org.godotengine.godot.GodotApp" || adb shell monkey -p "$pkg" 1
sleep 5
adb shell run-as "$pkg" sh -c 'mkdir -p files; printf "career-byte-proof-v1\n" > files/marble_upgrade_career_probe; printf "ghost-byte-proof-v1\n" > files/marble_upgrade_ghost_probe; printf "prefs-byte-proof-v1\n" > files/marble_upgrade_prefs_probe'
before="$(adb shell run-as "$pkg" sh -c 'sha256sum files/marble_upgrade_*_probe' | tr -d '\r')"
[[ "$(wc -l <<< "$before")" == 3 ]] || exit 1
adb install -r "$b"
after="$(adb shell run-as "$pkg" sh -c 'sha256sum files/marble_upgrade_*_probe' | tr -d '\r')"
[[ "$before" == "$after" ]] || { echo "Android private app files changed after update" >&2; exit 1; }
actual="$(adb shell dumpsys package "$pkg" | sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' | head -n1)"
[[ "$actual" == "$code_b" ]] || { echo "Updated version missing: $actual" >&2; exit 1; }
adb shell am force-stop "$pkg"
adb shell monkey -p "$pkg" 1
sleep 5
again="$(adb shell run-as "$pkg" sh -c 'sha256sum files/marble_upgrade_*_probe' | tr -d '\r')"
[[ "$again" == "$before" ]] || { echo "Private data lost after relaunch" >&2; exit 1; }
echo "ANDROID_UPGRADE_EMULATOR_PASS: PackageManager installed higher version; three private data probes survived upgrade and relaunch"
echo "NOTE: This verifies OS-level preservation, not game-level career/ghost deserialization."
