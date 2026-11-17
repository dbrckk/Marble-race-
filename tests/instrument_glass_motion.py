from pathlib import Path

project = Path("project.godot")
text = project.read_text()
old = 'run/main_scene="res://scenes/main.tscn"'
assert text.count(old) == 1
project.write_text(text.replace(old, 'run/main_scene="res://scenes/android_glass_motion.tscn"'))
Path("scenes/android_glass_motion.tscn").write_text(
    '[gd_scene load_steps=2 format=3]\n\n'
    '[ext_resource type="Script" path="res://tests/android_glass_motion_capture.gd" id="1"]\n\n'
    '[node name="GlassMotionQA" type="Node"]\nscript = ExtResource("1")\n')
