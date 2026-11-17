from pathlib import Path
import subprocess

reference = "c88768b238498ada0e98ed6b242c3c753c7b4815"
names = ("game", "marble", "ai_race_strategy", "race_director", "shortcut_route")
root = Path("tests/frame_pacing_baseline")
root.mkdir(parents=True, exist_ok=True)
for name in names:
    path = f"scripts/{name}.gd"
    data = subprocess.check_output(["git", "show", f"{reference}:{path}"], text=True)
    for dependency in names:
        data = data.replace(f"res://scripts/{dependency}.gd", f"res://tests/frame_pacing_baseline/{dependency}.gd")
    (root / f"{name}.gd").write_text(data)
main = Path("scenes/main.tscn").read_text()
assert main.count("res://scripts/game.gd") == 1
(root / "race.tscn").write_text(main.replace("res://scripts/game.gd", "res://tests/frame_pacing_baseline/game.gd"))
Path("tests/frame_pacing.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tests/android_cue_contrast_capture.gd" id="1"]
[node name="FramePacing" type="Node"]
script = ExtResource("1")
''')
project = Path("project.godot")
data = project.read_text()
assert data.count('run/main_scene="res://scenes/main.tscn"') == 1
project.write_text(data.replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://tests/frame_pacing.tscn"'))
