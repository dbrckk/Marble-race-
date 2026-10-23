#!/usr/bin/env bash
# Guardrails for the FIRST Google Play production AAB. No placeholder ads,
# missing consent SDK, debug signing, unverified consumables or target API35.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-.}"
say_no() { printf 'PLAY_PREFLIGHT_BLOCKED: %s\n' "$1" >&2; exit 1; }

grep -Fq 'name="Android Play"' export_presets.cfg ||
  say_no "No dedicated Google Play AAB export preset"
grep -Fq 'gradle_build/use_gradle_build=true' export_presets.cfg ||
  say_no "Android Play requires a Gradle AAB build"
grep -Fq 'gradle_build/export_format=1' export_presets.cfg ||
  say_no "Store releases must use AAB, not debug APK"
grep -Fq 'package/unique_name="com.dbrckk.marble_race"' export_presets.cfg ||
  say_no "The package identifier is not pinned"
test -d addons/admob || say_no "Poing Studios AdMob Godot addon is missing"
test -f addons/GodotGooglePlayBilling/BillingClient.gd ||
  say_no "First-party Play Billing addon is missing"
test -d android/build || say_no "Android Gradle build template not installed"

# Godot 4.5.1 ships with targetSdk 35. Google Play NEW apps from Aug 31 2026
# require 36. Patch the generated Gradle source, not engine/editor binaries.
config="$(find android/build -name config.gradle -print -quit)"
test -n "$config" && test -f "$config" ||
  say_no "Could not locate Godot Gradle config.gradle"
python3 - "$config" <<'PY'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
for key in ("compileSdk","targetSdk"):
    pattern=r"(?m)^(\s*"+key+r"\s*:\s*)\d+"
    if not re.search(pattern,s):
        raise SystemExit("PLAY_PREFLIGHT_BLOCKED: missing "+key+" in "+str(p))
    s=re.sub(pattern,lambda m:m.group(1)+"36",s,count=1)
p.write_text(s)
assert all(re.search(r"(?m)^\s*"+k+r"\s*:\s*36",s) for k in ("compileSdk","targetSdk"))
PY
test -d "${ANDROID_HOME:?}/platforms/android-36" ||
  say_no "Android SDK platform 36 not installed"
ad_unit="${MARBLE_ADMOB_REWARDED_UNIT_ID:-}"
verify_url="${MARBLE_PLAY_VERIFY_URL:-}"
[[ "$ad_unit" =~ ^ca-app-pub-[0-9]+/[0-9]+$ ]] ||
  say_no "Configure a real rewarded AdMob unit ID; no production test IDs"
[[ "$ad_unit" != "ca-app-pub-3940256099942544/5224354917" ]] ||
  say_no "Do not use Google's sample ad unit in a public release"
[[ "$verify_url" =~ ^https://[^[:space:]]+$ ]] ||
  say_no "Trusted production Google Play purchase verification API not configured"
[[ "${MARBLE_ADMOB_APP_ID:-}" =~ ^ca-app-pub-[0-9]+~[0-9]+$ ]] ||
  say_no "Expected a real AdMob application ID (with ~)"
[[ -n "${MARBLE_KEYSTORE_B64:-}" && -n "${MARBLE_KEY_ALIAS:-}" &&
   -n "${MARBLE_KEY_PASSWORD:-}" && -n "${MARBLE_CERT_SHA256:-}" ]] ||
  say_no "Pinned production Play signing key not configured"
# Godot ConfigFile needs quoted strings; the earlier configparser export
# emitted raw URLs, which could disable production SDK initialization.
# Enable the actual native export plugins and manifest app ID in this
# temporary CI workspace, never in the public debug builds.
python3 ci/configure_play_store.py
grep -Fq 'general/android/app_id="' project.godot ||
  say_no "AdMob manifest app ID was not injected"
grep -Fq 'verification_url="https://' monetization_config.cfg ||
  say_no "Google Play verifier was not quoted as a Godot string"
echo 'PLAY_PREFLIGHT_PASS: Gradle, SDK36, real opt-in ad, Play verify service and signing prerequisites present'
