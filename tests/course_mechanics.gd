extends SceneTree
## Regression: each biome has a different gameplay loop and authoritative effects.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_course_mechanics_career.cfg"
    game.career.unlocked = 3
    # This test drives the zones explicitly; no free-running physics simulation.
    game.set_physics_process(false)
    game.set_process(false)
    var counts: Array[PackedInt32Array] = []
    for track in range(3):
        assert(game.set_track(track),"All three courses must be selectable")
        var mechanic: Node3D = game.course_mechanics
        assert(is_instance_valid(mechanic))
        assert(mechanic.track_id == track)
        assert(mechanic.zones.size() == 5,"Each course needs five intentional zone decisions")
        var distribution := PackedInt32Array([0,0,0])
        for section in range(1,15):
            distribution[game._obstacle_layout(section)] += 1
        counts.append(distribution)
        assert(distribution[0] > 0 and distribution[1] > 0 and distribution[2] > 0,
            "Every course must mix navigable obstacles")
        game.start_race("Grip Tape")
        game.race_state = "RACING"
        var player: RigidBody3D = game.player
        var ai: RigidBody3D = game.racers[0]
        player.freeze = false
        ai.freeze = false
        var zone: Node3D = mechanic.zones[0]
        player.global_position = zone.global_position + Vector3(0,0.75,0)
        ai.global_position = zone.global_position + Vector3(0.15,0.75,0)
        if track == 0:
            assert(mechanic._kind() == "speed")
            mechanic.tick(0.016,game.racers,game.net)
            assert(mechanic.collected.has("0:39") and mechanic.collected.has("0:0"),
                "Speed lines apply to both human and AI racers")
            assert(game.ui.toast_remaining > 0.0,
                "The local player must receive a speed-line notification")
            var previous := mechanic.collected.size()
            mechanic.tick(0.016,game.racers,game.net)
            assert(mechanic.collected.size() == previous,
                "A speed line may not be farmed by standing on it")
        elif track == 1:
            assert(mechanic._kind() == "ice")
            var ice := zone.get_node_or_null("LowFrictionIce") as StaticBody3D
            assert(ice != null and ice.physics_material_override.friction < 0.1,
                "Glacier course needs physical low-friction ice")
            mechanic.tick(0.016,game.racers,game.net)
            assert(mechanic.collected.has("0:39") and mechanic.collected.has("0:0"),
                "Both human and AI can enter an ice drift")
        else:
            assert(mechanic._kind() == "vent")
            assert(mechanic.active_marks.size() == 5)
            assert(mechanic.vent_active(0,0.1) and not mechanic.vent_active(0,2.0))
            mechanic.tick(0.016,game.racers,game.net)
            assert(mechanic.last_burst.has("0:39") and mechanic.last_burst.has("0:0"),
                "Timed eruption must affect real physical marbles")
            var previous_time: float = float(mechanic.last_burst["0:39"])
            mechanic.tick(0.016,game.racers,game.net)
            assert(is_equal_approx(float(mechanic.last_burst["0:39"]),previous_time),
                "Vent effect requires anti-spam cooldown")
            mechanic.race_clock = 4.8
            mechanic.tick(0.016,game.racers,game.net)
            assert(float(mechanic.last_burst["0:39"]) > previous_time,
                "Vents must be repeatable on later eruption cycles")
            # The course event RPC is display-only: no client-authoritative physics.
            game.net.role = "client"
            game.net.match_running = true
            game.net._course_event_notice("vent")
            assert(game.ui.toast_remaining > 0.0,
                "Client must receive its reliable course event feedback")
            game.net.role = "offline"
            game.net.match_running = false
        game.return_to_menu()
    assert(counts[0] != counts[1] and counts[1] != counts[2],
        "The three circuits must use different obstacle distributions")
    print("COURSE_MECHANICS_PASS:",counts)
    game.queue_free()
    await process_frame
    quit()
