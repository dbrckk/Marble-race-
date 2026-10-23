#!/usr/bin/env bash
# CI-only Android Play AAB compilation proof. NEVER publish the AAB produced
# here: it is signed with a newly generated THROWAWAY key and contains
# deliberately NON-WORKING test config identifiers.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-.}"
: "${RUNNER_TEMP:?}"
: "${JAVA_HOME:?}"
: "${ANDROID_HOME:?}"
GODOT_BIN="${GODOT_BIN:-$PWD/Godot_v4.5.1-stable_linux.x86_64}"
temp_key="$RUNNER_TEMP/marble-NOT-FOR-RELEASE.jks"
trap 'rm -f "$temp_key" build/marble-race-play.aab build/play-release-info.txt' EXIT

"$JAVA_HOME/bin/keytool" -genkeypair -noprompt -keystore "$temp_key" \
  -alias throwaway -keyalg RSA -keysize 2048 -validity 2 \
  -storepass ci_only_not_for_upload -keypass ci_only_not_for_upload \
  -dname 'CN=NOT FOR RELEASE,OU=CI,O=Marble Race,C=FR' >/dev/null 2>&1

export MARBLE_KEYSTORE_B64="$(base64 -w0 "$temp_key")"
export MARBLE_KEY_ALIAS="throwaway"
export MARBLE_KEY_PASSWORD="ci_only_not_for_upload"
export MARBLE_CERT_SHA256="$("$JAVA_HOME/bin/keytool" -list -v \
  -keystore "$temp_key" -alias throwaway \
  -storepass ci_only_not_for_upload | sed -n \
  's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -1)"
# These values have the shape of valid production settings, but are NOT
# registered AdMob units or an operational purchase verification service.
export MARBLE_ADMOB_APP_ID="ca-app-pub-1234567890123456~1234567890"
export MARBLE_ADMOB_REWARDED_UNIT_ID="ca-app-pub-1234567890123456/9876543210"
export MARBLE_PLAY_VERIFY_URL="https://not-a-real-purchase-server.invalid/verify"
export GODOT_BIN
bash ci/build_play_release.sh
test -s build/marble-race-play.aab
# The temporary certificate and bundle are both deleted by trap, and no
# artifact is uploaded. A real release requires the owner's permanent key.
echo "PLAY_AAB_DRY_RUN_PASS: real Gradle AAB compiled and verified with disposable CI key; NOT publishable"
