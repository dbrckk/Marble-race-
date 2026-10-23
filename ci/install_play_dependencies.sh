#!/usr/bin/env bash
# Pinned official Godot 4.5.1 Android store dependencies. Executed in an
# isolated CI workspace. No moving "latest" tags and no unverified ZIPs.
set -euo pipefail
cd "${GITHUB_WORKSPACE:-.}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

fetch_checked() {
  local url="$1" digest="$2" output="$3"
  curl --fail --location --retry 3 --silent --show-error "$url" -o "$output"
  printf '%s  %s\n' "$digest" "$output" | sha256sum --check --status || {
    echo "PLAY_SDK_BLOCKED: upstream archive checksum mismatch" >&2
    exit 1
  }
}

fetch_checked \
  "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip" \
  "8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f" \
  "$scratch/admob.zip"
fetch_checked \
  "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.5.1.zip" \
  "f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee" \
  "$scratch/admob-native.zip"
fetch_checked \
  "https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip" \
  "20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568" \
  "$scratch/billing.zip"

for kind in admob admob-native billing; do
  mkdir -p "$scratch/$kind"
  unzip -q "$scratch/$kind.zip" -d "$scratch/$kind"
done

ad_plugin="$(find "$scratch/admob" -type f -path '*/addons/admob/plugin.cfg' -print -quit)"
billing_script="$(find "$scratch/billing" -type f -path '*/GodotGooglePlayBilling/BillingClient.gd' -print -quit)"
if [[ -z "$ad_plugin" || -z "$billing_script" ]]; then
  echo "PLAY_SDK_BLOCKED: official SDK archive layouts changed" >&2
  exit 1
fi

mkdir -p addons
cp -a "$(dirname "$ad_plugin")" addons/
cp -a "$(dirname "$billing_script")" addons/

# Poing v5 uses the actual native ads export plugin from its official
# Android archive. A mere GDScript folder would pass import but never serve
# a rewarded video in an APK; reject it.
native_entry="$(find "$scratch/admob-native" -type f \
  -name 'poing_godot_admob_ads.gd' -print -quit)"
if [[ -n "$native_entry" ]]; then
  mkdir -p addons/admob/android/bin
  cp -a "$(dirname "$native_entry")" addons/admob/android/bin/
fi
test -f addons/admob/android/bin/ads/poing_godot_admob_ads.gd || {
  echo "PLAY_SDK_BLOCKED: Poing v5 native Android ads integration is missing" >&2
  exit 1
}
find addons/admob/android/bin/ads -type f -name '*.aar' -print -quit | grep -q . || {
  echo "PLAY_SDK_BLOCKED: Native AdMob Android AAR missing" >&2
  exit 1
}
find addons/GodotGooglePlayBilling -type f -name '*.aar' -print -quit | grep -q . || {
  echo "PLAY_SDK_BLOCKED: Native Google Play Billing Android AAR missing" >&2
  exit 1
}
echo "PLAY_SDK_DEPENDENCIES_READY: pinned AdMob v5.1.0, Billing 3.3.0, native Android AAR"
