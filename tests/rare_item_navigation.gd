extends SceneTree
## Rare instant powerup HUD / map parity for all nine REAL course layouts.
## Only authoritative human pickup collection may hide an item.
const ITEMS = preload("res://scripts/race_items.gd")
const RACER = preload("res://scripts/marble.gd")

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
            assert(hud.briefing_notes.text.contains("DIAMONDS = RARE ITEMS"),
                "The map legend must explain what the pickup diamonds mean")
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
            assert(game.racers.size() == game.MARBLE_COUNT)
            var crystal_shapes: Array[Vector3] = []
            var next_z := INF
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
                var crystal := marker.get_node("EffectCrystal").mesh as SphereMesh
                var proportions := Vector3(crystal.radius,crystal.height,crystal.radial_segments)
                assert(not crystal_shapes.has(proportions),"Every effect has a distinct silhouette")
                crystal_shapes.append(proportions)
                assert(marker.position.z < next_z,"Pickup previews must follow course order")
                next_z = marker.position.z
            # A raised detour cannot reach the rare item on the physically
            # separated main road. Warning about it would mislead the player.
            var approach_z: float = ITEMS.placement_at(1,track,variation).z+3.0
            var bypass_position: Vector3 = game.shortcut_route.point_at(approach_z)
            assert(game.shortcut_route.shortcut_hint(bypass_position).get(
                "mode","") == "merge")
            assert(game.race_items.nearest_available(
                bypass_position,39,28.0).is_empty(),
                "Do not advertise a main-road collectible across the bridge gap")
            var main_position := Vector3(game.track_center_at(approach_z),
                game.height_at(approach_z)+0.80,approach_z)
            var reachable: Dictionary = game.race_items.nearest_available(
                main_position,39,28.0)
            assert(not reachable.is_empty() and int(reachable["index"]) == 1,
                "Remaining on the main road must preserve the real pickup cue")
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
            var preview_distance := 18
            if track == 0:
                assert(not game.woodworks_opening_cleared(human.global_position.z))
                hud.label_timer = 1.0
                hud.update_hud()
                assert(not label.visible,"The first obstacle takes priority over the diamond")
                preview_distance = 5
                human.global_position.z = first.z+float(preview_distance)
                assert(game.woodworks_opening_cleared(human.global_position.z))
            hud.label_timer = 1.0
            hud.update_hud()
            assert(label.visible and label.text.contains(ITEMS.label_at(0,track)),
                "An upcoming rare effect must have an actual Android HUD cue")
            assert(label.text.contains("%dm" % preview_distance))
            var badge: Panel = hud.driving_cue_backgrounds[label]
            assert(badge.visible and label.anchor_left > hud.hazard_label.anchor_right and
                label.anchor_top > hud.leaderboard.get_parent().anchor_bottom and
                label.anchor_bottom < hud.network_quality_label.get_parent().anchor_top,
                "A pickup preview keeps a fixed slot away from the steering and status rows")
            if track > 0:
                # Same physical item, with a preview that reaches farther as
                # forward speed increases. Keep the timed gate out of range.
                human.global_position.z = first.z+30.0
                human.linear_velocity = Vector3(0,0,-3)
                hud.label_timer = 1.0
                hud.update_hud()
                assert(not label.visible,"Slow racers should not see distant pickups")
                human.linear_velocity.z = -23.0
                hud.label_timer = 1.0
                hud.update_hud()
                assert(label.visible and label.text.contains("30m"),
                    "Fast racers need time to choose the pickup line")
                human.linear_velocity = Vector3.ZERO
                human.global_position.z = first.z+18.0
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
            if track > 0:
                await _verify_grounded_collection(game)
            _verify_online_layout(game,track,variation)
            game.return_to_menu()
            assert(not label.visible or not hud.hud_layer.visible)
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_item_route_preview.cfg"))
    print("RARE_ITEM_NAVIGATION_PASS: 36 map points, 24 grounded pickup lines, distinct crystals, speed-aware HUD and online parity")
    quit(0)

func _verify_grounded_collection(game: Node3D) -> void:
    game.race_items.reset_round()
    var excludes: Array[RID] = []
    for racer in game.racers:
        excludes.append(racer.get_rid())
    var ball := SphereShape3D.new()
    ball.radius = RACER.RADIUS
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = ball
    query.exclude = excludes
    var ray := PhysicsRayQueryParameters3D.new()
    ray.exclude = excludes
    await physics_frame
    await physics_frame
    var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    for item in game.race_items.items:
        for dz in [-1.0,0.0,1.0,1.5,2.0]:
            var probe: Vector3 = item.position+Vector3.BACK*dz
            probe.y = game.height_at(probe.z)
            ray.from = probe+Vector3.UP*1.8
            ray.to = probe-Vector3.UP*0.5
            var support := space.intersect_ray(ray)
            assert(not support.is_empty() and support.normal.y > 0.8 and
                support.position.y < probe.y+0.27,
                "A pickup approach must run along the real deck")
            query.transform = Transform3D(Basis.IDENTITY,
                support.position+Vector3.UP*(RACER.RADIUS+0.03))
            assert(space.intersect_shape(query,1).is_empty(),
                "A real obstacle blocks "+str(item.name)+" on "+game.track_title())
            if dz == 0.0:
                game.player.global_position = support.position+Vector3.UP*RACER.RADIUS
                game.race_items.tick(1.0/60.0,game.racers,game.net)
                assert(not item.visible,"A grounded marble must collect every item")

func _verify_online_layout(game: Node3D, track: int, layout: int) -> void:
    game.net.role = "client"
    game.race_items.reset_round()
    for i in range(ITEMS.ITEM_Z.size()):
        var online: Vector3 = game.race_items.items[i].position
        var expected_offset: float = ITEMS.ITEM_X[(i+track+layout)%ITEMS.ITEM_X.size()]
        assert(online.z == ITEMS.ITEM_Z[i])
        assert(is_equal_approx(online.x,game.track_center_at(online.z)+expected_offset),
            "Existing clients and the live server still share the original coordinates")
    game.net.role = "offline"
