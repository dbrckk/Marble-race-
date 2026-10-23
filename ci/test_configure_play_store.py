"""Fail-closed tests for Android release-only monetization configuration."""
import tempfile
import unittest
from pathlib import Path
from configure_play_store import configure

APP = "ca-app-pub-1234567890123456~1234567890"
UNIT = "ca-app-pub-1234567890123456/9876543210"
ENDPOINT = "https://billing.example.com/verify"


class PlayConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "project.godot").write_text(
            "config_version=5\n\n[application]\nconfig/name=\"Marble Race\"\n",
            encoding="utf-8",
        )
        (self.root / "monetization_config.cfg").write_text(
            "[admob]\nrewarded_unit_id=\"\"\n\n"
            "[billing]\nverification_url=\"\"\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_godot_variant_strings_and_native_manifest_settings(self):
        configure(self.root, APP, UNIT, ENDPOINT)
        project = (self.root / "project.godot").read_text()
        cfg = (self.root / "monetization_config.cfg").read_text()
        self.assertIn('rewarded_unit_id="' + UNIT + '"', cfg)
        self.assertIn('verification_url="' + ENDPOINT + '"', cfg)
        self.assertIn('general/android/app_id="' + APP + '"', project)
        self.assertIn('general/android/enabled=true', project)
        self.assertIn('res://addons/admob/plugin.cfg', project)
        self.assertIn('res://addons/GodotGooglePlayBilling/plugin.cfg', project)
        self.assertIn('config/name="Marble Race"', project)

    def test_reject_test_id_and_invalid_urls(self):
        for unit in ("", "test-123", "ca-app-pub-3940256099942544/5224354917"):
            with self.assertRaises(ValueError):
                configure(self.root, APP, unit, ENDPOINT)
        for endpoint in ("http://bad.example.com/verify", "https://x/other",
                         "https://x/verify?debug=true", "https://x/verify#bad"):
            with self.assertRaises(ValueError):
                configure(self.root, APP, UNIT, endpoint)
        for app in ("", "ca-app-pub-123/456", "fake-id"):
            with self.assertRaises(ValueError):
                configure(self.root, app, UNIT, ENDPOINT)
        self.assertNotIn("[admob]", (self.root / "project.godot").read_text())

    def test_refuse_duplicate_project_configuration(self):
        configure(self.root, APP, UNIT, ENDPOINT)
        with self.assertRaises(ValueError):
            configure(self.root, APP, UNIT, ENDPOINT)


if __name__ == "__main__":
    unittest.main()
