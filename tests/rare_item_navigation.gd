extends SceneTree
## Rare instant powerup HUD / map parity for all nine REAL course layouts.
## Only authoritative human pickup collection may hide an item.
const ITEMS = preload("res://scripts/race_items.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_item_route_preview.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var hud = game.ui
    var label: Label = hud.rare_item_label
    assert(is_instance_valid(label) and label.name == "UpcomingHumanPowerup")
    assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(not label.visible,"Menu cannot present an item as a live pickup")
    for track in range(3):
        assert(game.set_track(track))
        for variation in range(3):
            game.race_variation = variation
            hud.show_perks()
            var map = hud.course_briefing
            assert(map.course == track and map.variation == variation)
            assert(hud.course_strategy_label.text.contains("DIAMONDS"))
            for i in range(ITEMS.ITEM_Z.size()):
                var at: Vector3 = ITEMS.placement_at(i,track,variation)
                assert(absf(at.y-game.height_at(at.z)-1.05) < 0.0001)
                assert(absf(at.x-game.track_center_at(at.z)) <= 2.81)
                assert(map.item_marker(i).distance_to(
                    map.project(at.z,at.x)) < 0.0001,
                    "Overview must use exact real collectible X/Z for every layout")
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == variation)
            assert(game.race_items.items.size() == 4)
            assert(game.racers.size() == 40)
            for i in range(ITEMS.ITEM_Z.size()):
                var marker: Node3D = game.race_items.items[i]
                var expected: Vector3 = ITEMS.placement_at(i,track,variation)
                assert(marker.position.distance_to(expected) < 0.001,
                    "The displayed item location must be the physical pickup origin")
                var title: Label3D = marker.get_node_or_null(
                    "ImmediateEffectLabel") as Label3D
                assert(is_instance_valid(title) and
                    title.text == ITEMS.label_at(i,track))
                assert(ITEMS.kind_at(i,track) in ITEMS.ITEM_KINDS)
            # Actual next item, not one from the previous variation or a bot.
            var first: Vector3 = ITEMS.placement_at(0,track,variation)
            var human: RigidBody3D = game.player
            var ai: RigidBody3D = game.racers[0]
            human.global_position = first+Vector3(0.0,0.0,18.0)
            ai.global_position = first
            var hint: Dictionary = game.race_items.nearest_available(
                human.global_position,human.racer_id)
            assert(not hint.is_empty() and int(hint["index"]) == 0)
            assert(absf(float(hint["distance"])-18.0) < 0.001)
            assert(str(hint["label"]) == ITEMS.label_at(0,track))
            assert(str(hint["side"]) == (
                "LEFT" if ITEMS.lane_offset(0,track,variation) < 0.0 else "RIGHT"))
            hud.label_timer = 1.0
            hud.update_hud()
            assert(label.visible and label.text.contains(ITEMS.label_at(0,track)),
                "An upcoming rare effect must have an actual Android HUD cue")
            assert(label.text.contains("18m"))
            game.race_items.tick(0.016,game.racers,game.net)
            assert(game.race_items.used.is_empty(),
                "AI contact must not collect or erase a human-only pickup")
            human.global_position = game.race_items.items[0].global_position
            game.race_items.tick(0.016,game.racers,game.net)
            assert(game.race_items.used.has("0:39"))
            assert(not game.race_items.items[0].visible)
            assert(game.race_items.nearest_available(
                human.global_position,human.racer_id).is_empty(),
                "Collected solo item cannot be offered a second time")
            hud.label_timer = 1.0
            hud.update_hud()
            assert(not label.visible,
                "Immediately hide the prompt after authentic collection")
            game.return_to_menu()
            assert(not label.visible or not hud.hud_layer.visible)
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_item_route_preview.cfg"))
    print("RARE_ITEM_NAVIGATION_PASS: 9 real layouts, 36 exact map points, human-only effects, touch HUD")
    quit(0)
