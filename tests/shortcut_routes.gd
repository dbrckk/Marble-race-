extends SceneTree
## Real branch regression: 3 playable exterior decks, entry/exit portals,
## physical world contact, human navigation and server-authoritative rewards.
const Shortcut = preload("res://scripts/shortcut_route.gd")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_shortcut_routes_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    for course in range(3):
        assert(game.set_track(course),"Unlocked course should be selectable")
        var road: Node3D = game.shortcut_route
        var side: int = Shortcut.side_for(course)
        assert(road == game.board.get_node("PhysicalShortcutRoute"))
        assert(road.decks.size() == Shortcut.SEGMENTS,
            "The bypass needs solid deck colliders throughout")
        assert(road.guards.size() >= 20,
            "The exterior half of the shortcut must have solid rail guards")
        assert(road.physical_distance > Shortcut.ENTRY_Z-Shortcut.EXIT_Z,
            "The alternate road must physically diverge, not just paint arrows")
        assert(road.physical_distance < 75.0,
            "The side detour must not be an implausibly long route")
        assert(road.get_node_or_null("BatchedBypassDeck") is MultiMeshInstance3D)
        assert(road.get_node_or_null("BatchedBypassGuards") is MultiMeshInstance3D)
        for section in range(18):
            var module: Node3D = game.board.get_node("Course_%02d" % section)
            var portal: int = int(module.get_meta("shortcut_portal",0))
            if section in [Shortcut.ENTRY_SECTION,Shortcut.EXIT_SECTION]:
                assert(portal == side,"Entrance and merger must be on same bypass side")
                assert(Shortcut.opens_rail(section,side,1,course))
            else:
                assert(portal == 0,"Only entrance and exit may open the main railing")
        assert(game.track_surface.rails.size() == 106,
            "Two real portals must remove exactly two solid rail parts")
        assert(game.track_surface.planks.size() == 180,
            "The original main course stays physically continuous")
        assert(game.race_items.items.size() == 4,
            "Rare human-only items must not be replaced by shortcut reward")
        var start: Vector3 = road.point_at(Shortcut.ENTRY_Z)
        var exit_point: Vector3 = road.point_at(Shortcut.EXIT_Z)
        var middle: Vector3 = road.point_at(Shortcut.REWARD_Z)
        assert(absf(start.x-game.track_center_at(start.z)-float(side)*4.9) < 0.01)
        assert(absf(exit_point.x-game.track_center_at(exit_point.z)-float(side)*4.9) < 0.01)
        assert(absf(middle.x-game.track_center_at(middle.z)) > 9.0,
            "The bypass must be outside the ordinary 6.8m boundary rail")
        assert(absf(road.recovery_center_at(middle)-middle.x) < 0.01,
            "Recovery must follow the detached alternate road")
        assert(absf(road.recovery_center_at(Vector3(
            game.track_center_at(middle.z),middle.y,middle.z))-
            game.track_center_at(middle.z)) < 0.01,
            "Ordinary marbles must still recover toward the main track")
        for deck in road.decks:
            assert(deck is StaticBody3D and deck.get_node_or_null("PhysicalShape") != null,
                "Bypass road must be physically collidable, not decorative only")
            assert(deck.physics_material_override.friction <= 0.75)
        await physics_frame
        var ray := PhysicsRayQueryParameters3D.create(
            middle+Vector3.UP*2.4,middle-Vector3.UP*2.4)
        var contact: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
        assert(not contact.is_empty(),"A falling marble must land on shortcut deck")
        var contact_body: Object = contact.get("collider")
        assert(contact_body is StaticBody3D and str(contact_body.name).begins_with("BypassDeck_"),
            "The exterior bridge must be the first physical surface under a racer")
        game.start_race("Grip Tape")
        game.race_state = "RACING"
        var player: RigidBody3D = game.player
        player.freeze = false
        player.global_position = middle+Vector3.UP*0.75
        # Rendering clients must never grant locally forged shortcuts.
        game.net.role = "client"
        game.net.match_running = true
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.is_empty(),"No client-side physics reward allowed")
        game.net.role = "offline"
        game.net.match_running = false
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(39),
            "The real human racer should get exactly one route dash")
        assert(game.ui.toast_remaining > 0.0,
            "The bypass must show its immediate racing reward")
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.size() == 1,"A bypass bonus cannot be farmed")
        road.reset_round()
        assert(road.triggered.is_empty(),"Fresh races restore shortcut eligibility")
        game.net.role = "server"
        game.net.match_running = true
        game.net.joined_slots = {2:39}
        player.network_controlled = true
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(39),"Authoritative server must award route bonus")
        # Remote user feedback is display only; it never applies physics.
        game.net.role = "client"
        game.net._course_event_notice("shortcut")
        assert(game.ui.toast_remaining > 0.0,
            "Online human receives the shortcut notice")
        game.net.match_running = false
        game.net.role = "offline"
        game.net.joined_slots.clear()
        game.return_to_menu()
    print("SHORTCUT_ROUTES_PASS: three collidable, rewarded fork/merge alternatives")
    game.queue_free()
    await process_frame
    quit()
