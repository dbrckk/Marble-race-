#!/usr/bin/env bash
# Release APKs are reproducibly identified by ONE pinned Android signing cert.
# Never generate a release keystore on the runner: it would break upgrades.
# No secrets or keystore bytes are emitted to logs or stored in artifacts.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-.}"
: "${GITHUB_OUTPUT:?Run through GitHub Actions}"
: "${RUNNER_TEMP:?GitHub runner temp directory required}"
: "${ANDROID_HOME:?Android SDK missing}"
: "${JAVA_HOME:?Java 17 missing}"

store="${MARBLE_KEYSTORE_B64:-}"
alias="${MARBLE_KEY_ALIAS:-}"
password="${MARBLE_KEY_PASSWORD:-}"
expected="${MARBLE_CERT_SHA256:-}"
if [[ -z "$store" && -z "$alias" && -z "$password" && -z "$expected" ]]; then
  echo "configured=false" >> "$GITHUB_OUTPUT"
  echo "::notice::Stable signing not configured. Debug APK is available; it is NOT an update-safe APK."
  exit 0
fi
if [[ -z "$store" || -z "$alias" || -z "$password" || -z "$expected" ]]; then
  echo "::error::Incomplete stable signing. Set all three GitHub secrets and the pinned SHA-256 repository variable."
  exit 1
fi
normalize() { printf '%s' "$1" | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]'; }
expected="$(normalize "$expected")"
if [[ ! "$expected" =~ ^[0-9A-F]{64}$ ]]; then
  echo "::error::Pinned Android release certificate must be a 64-digit SHA-256 hex digest."
  exit 1
fi
keystore="$RUNNER_TEMP/marble-stable-release.jks"
umask 077
if ! printf '%s' "$store" | base64 --decode > "$keystore"; then
  echo "::error::Invalid base64-encoded signing keystore."
  exit 1
fi
unset store MARBLE_KEYSTORE_B64
actual="$("$JAVA_HOME/bin/keytool" -list -v -keystore "$keystore" \
  -alias "$alias" -storepass "$password" |
  sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n 1)"
actual="$(normalize "$actual")"
if [[ "$actual" != "$expected" ]]; then
  echo "::error::RELEASE CERTIFICATE CHANGED. Refusing to sign an incompatible update."
  exit 1
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$alias"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$password"
mkdir -p build
./Godot_v4.5.1-stable_linux.x86_64 --headless --path . \
  --export-release Android build/marble-race-stable.apk
test -s build/marble-race-stable.apk
report="$("$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose \
  --print-certs build/marble-race-stable.apk)"
printf '%s\n' "$report" | grep -Fq "Verified using v2 scheme (APK Signature Scheme v2): true"
signed="$(printf '%s\n' "$report" |
  sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n 1)"
signed="$(normalize "$signed")"
if [[ "$signed" != "$expected" ]]; then
  echo "::error::Release APK signer mismatches pinned fingerprint."
  exit 1
fi
"$ANDROID_HOME/build-tools/35.0.0/aapt" dump badging build/marble-race-stable.apk > "$RUNNER_TEMP/release-badging.txt"
grep -Fq "package: name='com.dbrckk.marble_race'" "$RUNNER_TEMP/release-badging.txt"
version="$(sed -n 's|^version/name="\(.*\)"|\1|p' export_presets.cfg | head -n 1)"
code="$(sed -n 's|^version/code=\([0-9]*\)|\1|p' export_presets.cfg | head -n 1)"
grep -Fq "versionCode='$code'" "$RUNNER_TEMP/release-badging.txt"
cat > build/release-update-info.txt <<EOF
Marble Race STABLE Android APK
Version: $version (code $code)
Package: com.dbrckk.marble_race
Signing certificate SHA-256: $expected
Git revision: ${GITHUB_SHA:-unknown}
This fingerprint MUST remain the same for future in-place APK upgrades.
A different or debug certificate cannot replace this APK in place.
EOF
echo "configured=true" >> "$GITHUB_OUTPUT"
echo "::notice::Signed release APK verified against pinned SHA-256 fingerprint. Version $version, code $code."
# Remove the secret-bearing file before uploaded outputs; the runner is ephemeral.
rm -f "$keystore"
