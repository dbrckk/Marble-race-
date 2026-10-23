"""Configure the Google Play AAB only in a temporary signed release workspace.

Godot ConfigFile values MUST be valid Variant strings, not raw INI values:
the old configparser output wrote unquoted URLs and disabled real monetization.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import re


def configure(root: Path, app_id: str, rewarded_id: str, verify_url: str) -> None:
    if not re.fullmatch(r"ca-app-pub-[0-9]+~[0-9]+", app_id):
        raise ValueError("Expected a real AdMob application ID (with ~)")
    if not re.fullmatch(r"ca-app-pub-[0-9]+/[0-9]+", rewarded_id) or (
        rewarded_id == "ca-app-pub-3940256099942544/5224354917"
    ):
        raise ValueError("Expected a non-demo rewarded video ID (with /)")
    if not re.fullmatch(r"https://[^\s]+", verify_url):
        raise ValueError("Purchase verification requires a production HTTPS URL")
    if "?" in verify_url or "#" in verify_url or not verify_url.endswith("/verify"):
        raise ValueError("Purchase verification URL must end with /verify")

    cfg = root / "monetization_config.cfg"
    cfg.write_text(
        "; Generated in the private CI release workspace. Not source-controlled.\n"
        "[admob]\nrewarded_unit_id=" + json.dumps(rewarded_id) +
        "\n\n[billing]\nverification_url=" + json.dumps(verify_url) + "\n",
        encoding="utf-8",
    )
    project = root / "project.godot"
    current = project.read_text(encoding="utf-8")
    if "\n[admob]\n" in current or "\n[editor_plugins]\n" in current:
        raise ValueError("Project already has explicit store plugin settings")
    # The Poing v5 export plugin reads this exact ProjectSettings property
    # to generate AndroidManifest com.google.android.gms.ads.APPLICATION_ID.
    current += (
        "\n[admob]\ngeneral/android/enabled=true\n"
        "general/android/app_id=" + json.dumps(app_id) +
        "\n\n[editor_plugins]\nenabled=PackedStringArray("
        '"res://addons/admob/plugin.cfg", '
        '"res://addons/GodotGooglePlayBilling/plugin.cfg")\n'
    )
    project.write_text(current, encoding="utf-8")


if __name__ == "__main__":
    configure(
        Path(os.environ.get("GITHUB_WORKSPACE", ".")).resolve(),
        os.environ["MARBLE_ADMOB_APP_ID"],
        os.environ["MARBLE_ADMOB_REWARDED_UNIT_ID"],
        os.environ["MARBLE_PLAY_VERIFY_URL"],
    )
    print("MARBLE_STORE_CONFIG_PASS: valid Godot strings, AdMob manifest ID, HTTPS verifier")
