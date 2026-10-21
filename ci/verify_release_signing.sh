#!/usr/bin/env bash
# End-to-end Android RELEASE signing smoke test using an ephemeral CI-only key.
# A successful debug export alone does not establish release signing works.
# The temporary key never leaves RUNNER_TEMP and is never a distribution key.
set -euo pipefail
: "${RUNNER_TEMP:?}"
: "${ANDROID_HOME:?}"
: "${JAVA_HOME:?}"
: "${GITHUB_WORKSPACE:?}"
cd "$GITHUB_WORKSPACE"

testdir="$(mktemp -d "$RUNNER_TEMP/marble-release-smoke.XXXXXX")"
cleanup() {
  rm -rf "$testdir"
  rm -f build/marble-race-stable.apk build/release-update-info.txt
}
trap cleanup EXIT

alias_name="marble_ci_ephemeral"
password="TestMarbleCI42"
keystore="$testdir/smoke.jks"
"$JAVA_HOME/bin/keytool" -genkeypair -noprompt \
  -keystore "$keystore" -alias "$alias_name" \
  -keyalg RSA -keysize 2048 -validity 2 \
  -storepass "$password" -keypass "$password" \
  -dname "CN=One-Time CI Test,O=Marble Race,C=FR" >/dev/null 2>&1
test -s "$keystore"

fingerprint="$("$JAVA_HOME/bin/keytool" -list -v \
  -keystore "$keystore" -alias "$alias_name" -storepass "$password" |
  sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n 1)"
fingerprint="$(printf '%s' "$fingerprint" | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
[[ "$fingerprint" =~ ^[0-9A-F]{64}$ ]]

export MARBLE_KEYSTORE_B64="$(base64 -w 0 "$keystore")"
export MARBLE_KEY_ALIAS="$alias_name"
export MARBLE_KEY_PASSWORD="$password"
export GITHUB_OUTPUT="$testdir/output"
touch "$GITHUB_OUTPUT"

# Supplying valid signing material with an unexpected pinned fingerprint must
# be refused BEFORE compiling, even though all other settings are present.
if MARBLE_CERT_SHA256="$(printf '0%.0s' {1..64})" \
   bash ci/sign_android_release.sh >"$testdir/wrong-certificate.log" 2>&1; then
  echo "::error::Release signing accepted an incorrect pinned certificate."
  exit 1
fi
test ! -e build/marble-race-stable.apk
! grep -Fq "configured=true" "$GITHUB_OUTPUT"

# Exercise the exact same signing path used by real (optional) secrets.
export MARBLE_CERT_SHA256="$fingerprint"
bash ci/sign_android_release.sh >"$testdir/export.log" 2>&1 || {
  # Reproduce nonsecret Godot diagnostics without printing the environment.
  grep -E "ERROR|error|failed|Failed|template|keystore|signature" \
    "$testdir/export.log" | tail -n 28 || true
  echo "::error::Ephemeral release signing and export failed."
  exit 1
}
grep -Fq "configured=true" "$GITHUB_OUTPUT"
test -s build/marble-race-stable.apk
test -s build/release-update-info.txt
grep -Fq "Package: com.dbrckk.marble_race" build/release-update-info.txt
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify \
  --verbose build/marble-race-stable.apk >/dev/null
echo "ANDROID_STABLE_SIGNING_SMOKE_PASS: complete temporary-key release export, pin and APK verification"
