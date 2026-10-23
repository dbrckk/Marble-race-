extends SceneTree
## All 9 biome-rematch layouts: opponents read real physical reward/risk
## positions, predict Forge's arrival cycle and steer via forces only.
## The player remains manually controlled; no AI position writes or cheats.
const STRATEGY = preload("res://scripts/ai_race_strategy.gd")
const ZONES = preload("res://scripts/course_mechanics.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_biome_ai_choices.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    assert(STRATEGY.ZONE_LOOKAHEAD <= 14.0,
        "40 AI cannot scan distant unrelated surface hazards")
    var approaches := 0
    var cooled_vents := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout)
            var mechanics: Node3D = game.course_mechanics
            assert(mechanics.track_id == biome and mechanics.variation == layout)
            assert(mechanics.zones.size() == 5)
            # The central station is far from timed gates and no ordinary
            # bot should be pulled onto the detached elevated shortcut.
            var index := 2
            var zone: Node3D = mechanics.zones[index]
            var z: float = zone.position.z+8.0
            var side: float = signf(ZONES.lane_offset(index,biome,layout))
            assert(absf(side) == 1.0)
            assert(absf(zone.global_position.x-game.track_center_at(
                zone.position.z)-side*3.3) < 0.001)
            var temperament := 2 if biome == 0 else 0
            var preferred: float = side*(1.4 if biome == 0 else 2.65)
            var expected: float = preferred
            var start_clock := 0.0
            if biome == 2:
                var active_found := false
                var quiet_found := false
                var quiet_clock := 0.0
                for sample in range(200):
                    var t: float = float(sample)*0.05
                    if mechanics.vent_active(index,t+8.0/12.0):
                        if not active_found:
                            start_clock = t
                            active_found = true
                    elif not quiet_found:
                        quiet_clock = t
                        quiet_found = true
                assert(active_found and quiet_found,
                    "Forge needs genuinely different arrival phases")
                mechanics.race_clock = quiet_clock
                assert(is_equal_approx(STRATEGY.biome_zone_safe_lane(
                    mechanics,z,-12.0,preferred,0),preferred),
                    "No bot should avoid a vent that is cool at ARRIVAL")
                cooled_vents += 1
                mechanics.race_clock = start_clock
            expected = STRATEGY.biome_zone_safe_lane(
                mechanics,z,-12.0,preferred,temperament)
            assert(absf(expected) <= STRATEGY.TRAFFIC_SAFE_LANE)
            assert((expected-preferred)*side > (
                0.4 if biome == 0 else -0.4),
                "Biomes must create a real route choice, not decorative hints")
            if biome == 0:
                assert((expected-preferred)*side > 0.8,
                    "Woodland opportunists should chase a genuine speed strip")
                assert(is_equal_approx(STRATEGY.biome_zone_safe_lane(
                    mechanics,z,-12.0,preferred,0),preferred),
                    "Cautious Wood opponents retain their existing race line")
            else:
                assert((expected-preferred)*side < -0.8,
                    "Glacier/Forge safe line must turn away from slippery or hot lane")
                if biome == 1:
                    assert(is_equal_approx(STRATEGY.biome_zone_safe_lane(
                        mechanics,z,-12.0,preferred,2),preferred),
                        "Risk-taking Glacier opponents can still race over ice")
            assert(is_equal_approx(STRATEGY.biome_zone_safe_lane(
                mechanics,zone.position.z+25.0,-12.0,preferred,
                temperament),preferred),
                "No swerving toward or away from zones outside lookahead")
            assert(is_equal_approx(STRATEGY.biome_zone_safe_lane(
                mechanics,zone.position.z-6.0,-12.0,preferred,
                temperament),preferred),
                "Passed zones must not pull AI back into obstacles")
            var bot: RigidBody3D = null
            for candidate in game.racers:
                if not candidate.is_player and not candidate.wants_shortcut() and (
                    STRATEGY.temperament(candidate.racer_id,biome,layout) == temperament):
                    bot = candidate
                    break
            assert(is_instance_valid(bot),
                "Every course requires a real ordinary AI of this temperament")
            bot.freeze = false
            bot.sleeping = false
            bot.global_position = Vector3(
                game.track_center_at(z)+preferred,
                game.height_at(z)+0.85,z)
            bot.linear_velocity = Vector3(0,0,-12)
            bot.angular_velocity = Vector3.ZERO
            bot.ai_lane_goal = preferred
            bot.ai_lane_timer = 2.0
            bot.ai_traffic_timer = 0.0
            var before: Vector3 = bot.global_position
            var human_before: Vector3 = game.player.global_position
            bot.drive(1.0/60.0,start_clock,0.0,false)
            assert(bot.global_position.is_equal_approx(before),
                "Biomes must never teleport opponents onto reward or safety lanes")
            assert(game.player.global_position.is_equal_approx(human_before),
                "AI route planning cannot move the human player's marble")
            await physics_frame
            await physics_frame
            await physics_frame
            var lateral: float = bot.linear_velocity.x*side
            if lateral <= (0.02 if biome == 0 else -999.0) and biome == 0:
                print("ZONE_AI_DEBUG wood ",layout," offset=",expected,
                    " speed=",bot.linear_velocity," position=",bot.global_position)
            if biome == 0:
                assert(lateral > 0.02,"Woodland reward search must steer outward")
            else:
                assert(lateral < -0.02,
                    "Real Glacier/Forge AI must begin steering inward toward safety")
            approaches += 1
            game.return_to_menu()
    assert(approaches == 9 and cooled_vents == 3)
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_biome_ai_choices.cfg"))
    print("BIOME_AI_CHOICES_PASS: 9 variants, physical steering, speed rewards, ice tactics, forecast vent escape and no human cheats")
    quit(0)
