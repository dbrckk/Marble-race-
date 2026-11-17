from pathlib import Path

scene = Path("scenes/main.tscn")
text = scene.read_text().replace("load_steps=2", "load_steps=3", 1)
resource = '[ext_resource type="Script" path="res://tests/android_race_profile_capture.gd" id="2"]'
text = text.replace('[node name="MarbleRace"', resource + '\n\n[node name="MarbleRace"', 1)
text += '\n[node name="RaceProfileQA" type="Node" parent="."]\nscript = ExtResource("2")\n'
scene.write_text(text)
game = Path("scripts/game.gd")
text = game.read_text()
anchor = "func _physics_process(delta: float) -> void:\n"
assert text.count(anchor) == 1
text = text.replace(anchor, """var qa_tick: Callable
var qa_bot_us := 0
var qa_skip_unused_forecasts := false
var qa_bot_forecasts := 0

func _physics_process(delta: float) -> void:
    qa_bot_us = 0
    qa_bot_forecasts = 0
    var started := Time.get_ticks_usec()
    _qa_physics_body(delta)
    if qa_tick.is_valid():
        qa_tick.call(Time.get_ticks_usec()-started,qa_bot_us,qa_bot_forecasts)

func _qa_physics_body(delta: float) -> void:
""")
anchor = "        m.drive(delta,race_time,axis,turbo)\n"
assert text.count(anchor) == 1
text = text.replace(anchor, """        if m.is_player or m.network_controlled:
            m.drive(delta,race_time,axis,turbo)
        else:
            var started := Time.get_ticks_usec()
            m.drive(delta,race_time,axis,turbo)
            qa_bot_us += Time.get_ticks_usec()-started
""")
game.write_text(text)

marble = Path("scripts/marble.gd")
text = marble.read_text()
source = """            var next_hazard: Dictionary = course_owner.upcoming_hazard(position.z)
            var hazard_near: bool = not next_hazard.is_empty() and (
                float(next_hazard.get("distance",999.0)) < 3.5)
"""
assert text.count(source) == 1
text = text.replace(source, """            var next_hazard: Dictionary = {}
            if not course_owner.qa_skip_unused_forecasts:
                course_owner.qa_bot_forecasts += 1
                next_hazard = course_owner.upcoming_hazard(position.z)
""")
source = """                absf(ai_lane_goal) < 1.9) and not hazard_near
            if traffic_safe:
"""
assert text.count(source) == 1
text = text.replace(source, """                absf(ai_lane_goal) < 1.9)
            if traffic_safe:
                if course_owner.qa_skip_unused_forecasts:
                    course_owner.qa_bot_forecasts += 1
                    next_hazard = course_owner.upcoming_hazard(position.z)
                traffic_safe = not (
                    not next_hazard.is_empty() and float(next_hazard.get("distance",999.0)) < 3.5)
            if traffic_safe:
""")
marble.write_text(text)
