#!/usr/bin/env bash
# Build a real Google Play app bundle ONLY when native SDKs, UMP, verified
# billing backend, API36 and PINNED release certificate are all configured.
# No debug fallback or ephemeral signing key can silently reach Play Console.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-.}"
bash ci/play_release_preflight.sh
: "${JAVA_HOME:?Java SDK missing}"
: "${ANDROID_HOME:?Android SDK missing}"
mkdir -p build
keystore="$(mktemp "${RUNNER_TEMP:-/tmp}/marble-play.XXXXXXXX.jks")"
chmod 600 "$keystore"
trap 'rm -f "$keystore"' EXIT
printf '%s' "$MARBLE_KEYSTORE_B64" | base64 --decode > "$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$MARBLE_KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$MARBLE_KEY_PASSWORD"
expected="$(printf '%s' "$MARBLE_CERT_SHA256" | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
[[ "$expected" =~ ^[0-9A-F]{64}$ ]] || { echo 'Invalid release SHA256'; exit 1; }
actual="$("$JAVA_HOME/bin/keytool" -list -v -keystore "$keystore" \
  -alias "$MARBLE_KEY_ALIAS" -storepass "$MARBLE_KEY_PASSWORD" |
  sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n1 |
  tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
[[ "$actual" == "$expected" ]] || { echo 'Play signing fingerprint mismatch'; exit 1; }
GODOT_BIN="${GODOT_BIN:-./Godot_v4.5.1-stable_linux.x86_64}"
"$GODOT_BIN" --headless --path . --export-release "Android Play" \
  build/marble-race-play.aab
test -s build/marble-race-play.aab
"$JAVA_HOME/bin/jarsigner" -verify -strict build/marble-race-play.aab
"$JAVA_HOME/bin/keytool" -printcert -jarfile build/marble-race-play.aab |
  grep -Fq "SHA256: "
cat > build/play-release-info.txt <<EOF
MARBLE RACE — Google Play internal-track candidate (not published automatically)
Package: com.dbrckk.marble_race
Version: 1.0.0 (code 100)
AAB: marble-race-play.aab
Signing certificate SHA-256: $expected
Git revision: ${GITHUB_SHA:-unknown}
Real-world AdMob reward, consent form and Google Play purchase tests
must pass on the Play internal track before public rollout.
EOF
echo "PLAY_AAB_SIGNED: verified pinned certificate, API36 preflight and archive signature"
