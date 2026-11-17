from pathlib import Path

scene = Path("scenes/main.tscn")
text = scene.read_text()
assert text.count("load_steps=2") == 1
text = text.replace("load_steps=2", "load_steps=3", 1)
resource = '[ext_resource type="Script" path="res://tests/android_hud_profile_capture.gd" id="2"]'
text = text.replace('[node name="MarbleRace"', resource + '\n\n[node name="MarbleRace"', 1)
text += '\n[node name="HudProfileQA" type="Node" parent="."]\nscript = ExtResource("2")\n'
scene.write_text(text)
