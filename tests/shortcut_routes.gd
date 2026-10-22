extends SceneTree
## Real branch regression: 3 playable exterior decks, entry/exit portals,
## physical world contact, human navigation and server-authoritative rewards.
const BypassScript = preload("res://scripts/shortcut_route.gd")
const AIPath = preload("res://scripts/ai_race_strategy.gd")
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
        var side: int = BypassScript.side_for(course)
        assert(road == game.board.get_node("PhysicalShortcutRoute"))
        assert(road.decks.size() == BypassScript.SEGMENTS,
            "The bypass needs solid deck colliders throughout")
        assert(road.guards.size() >= 20,
            "The exterior half of the shortcut must have solid rail guards")
        assert(road.launch_ramps.size() == 1,
            "Every optional branch must have a gentle physical takeoff ramp")
        assert(road.launch_ramps[0].get_node_or_null("PhysicalShape") is CollisionShape3D,
            "A jump must be a real physical contact surface")
        # On a steep 3D hill an uphill launch can be nearly horizontal in
        # world space while retaining the required 0.18-radian lip relative
        # to the physical racing surface. Test relative lift, not world tilt.
        var ramp_z: float = float(road.JUMP_Z[course])
        var relative_lip: float = road.launch_ramps[0].rotation.x+atan(
            game.track_grade_at(ramp_z))
        assert(absf(relative_lip-0.18) < 0.001,
            "Physical takeoff must rise by 0.18 radians relative to local terrain")
        assert(road.banked_segments > 0,
            "Every course bypass needs some actual physical banking")
        assert(road.physical_distance > BypassScript.ENTRY_Z-BypassScript.EXIT_Z,
            "The alternate road must physically diverge, not just paint arrows")
        assert(road.physical_distance < 75.0,
            "The side detour must not be an implausibly long route")
        assert(road.get_node_or_null("BatchedBypassDeck") is MultiMeshInstance3D)
        assert(road.get_node_or_null("BatchedBypassGuards") is MultiMeshInstance3D)
        assert(road.get_node_or_null("BatchedJumpTakeoff") is MultiMeshInstance3D)
        assert(road.get_node_or_null("BypassNavigationChevrons") is MultiMeshInstance3D)
        assert(road.get_node_or_null("ShortcutGatewayBeams") is MultiMeshInstance3D)
        assert(road.get_node_or_null("ShortcutEntranceArrow") is Label3D)
        assert(road.get_node_or_null("ShortcutMergeArrow") is Label3D)
        for section in range(18):
            var module: Node3D = game.board.get_node("Course_%02d" % section)
            var portal: int = int(module.get_meta("shortcut_portal",0))
            if section in [BypassScript.ENTRY_SECTION,BypassScript.EXIT_SECTION]:
                assert(portal == side,"Entrance and merger must be on same bypass side")
                assert(BypassScript.opens_rail(section,side,1,course))
            else:
                assert(portal == 0,"Only entrance and exit may open the main railing")
        # Shortcut-specialist AI must steer through the actual middle
        # physical portal, not fight the ordinary main-road recovery wall.
        var gate_z: float = BypassScript.ENTRY_Z-3.0
        var on_portal := Vector3(game.track_center_at(gate_z)+side*5.25,
            game.height_at(gate_z)+0.8,gate_z)
        assert(AIPath.inside_shortcut_gate(road,on_portal),
            "Only real physical entry portal should allow alternative AI lane")
        assert(not AIPath.inside_shortcut_gate(road,Vector3(
            game.track_center_at(gate_z),on_portal.y,gate_z)),
            "Normal AI racer at the centerline must still recover normally")
        assert(not AIPath.inside_shortcut_gate(road,Vector3(
            game.track_center_at(gate_z)-side*5.25,on_portal.y,gate_z)),
            "The opposite closed wall is not an allowed short-cut portal")
        assert(not AIPath.inside_shortcut_gate(road,Vector3(
            on_portal.x,on_portal.y,BypassScript.ENTRY_Z+6.0)),
            "The approach before the opening must keep collision recovery")
        assert(not AIPath.inside_shortcut_gate(road,Vector3(
            on_portal.x,on_portal.y,BypassScript.ENTRY_Z-BypassScript.ENTRY_WINDOW-1.0)),
            "Recovery relief must stop outside the fork area")
        var near_x: float = AIPath.bypass_target_x(road,
            BypassScript.ENTRY_Z+6.0)
        var enter_x: float = AIPath.bypass_target_x(road,
            BypassScript.ENTRY_Z-3.0)
        var approach_offset: float = float(side)*(
            near_x-game.track_center_at(BypassScript.ENTRY_Z+6.0))
        assert(approach_offset < 6.05 and approach_offset > 4.60,
            "Early approach must remain inside the physical rail opening")
        if course == 1:
            var ice_target: float = game.shortcut_route.point_at(
                BypassScript.OUTER_START).x
            var ice_now: float = game.track_center_at(
                BypassScript.OUTER_START)+float(side)*4.0
            assert(absf(AIPath.bypass_steering(ice_target,ice_now,0.0,true)) >
                absf(AIPath.bypass_steering(ice_target,ice_now,0.0,false)),
                "Glacier specialists need stronger controlled lateral grip")
        assert(float(side)*(enter_x-game.track_center_at(
            BypassScript.ENTRY_Z-3.0)) > 6.0,
            "A specialist must target outside the gate once it opens")
        assert(game.track_surface.rails.size() == 106,
            "Two real portals must remove exactly two solid rail parts")
        assert(game.track_surface.planks.size() == 180,
            "The original main course stays physically continuous")
        assert(game.race_items.items.size() == 4,
            "Rare human-only items must not be replaced by shortcut reward")
        var start: Vector3 = road.point_at(BypassScript.ENTRY_Z)
        var exit_point: Vector3 = road.point_at(BypassScript.EXIT_Z)
        var middle: Vector3 = road.point_at(BypassScript.REWARD_Z)
        assert(absf(start.x-game.track_center_at(start.z)-float(side)*4.9) < 0.01)
        assert(absf(exit_point.x-game.track_center_at(exit_point.z)-float(side)*4.9) < 0.01)
        assert(absf(middle.x-game.track_center_at(middle.z)) > 9.0,
            "The bypass must be outside the ordinary 6.8m boundary rail")
        var fork_hint: Dictionary = road.shortcut_hint(Vector3(
            game.track_center_at(-32.0),game.height_at(-32.0),-32.0))
        assert(fork_hint.get("mode","") == "fork" and
            fork_hint.get("distance",-1) == 16 and
            fork_hint.get("side","") == ("RIGHT" if side > 0 else "LEFT"),
            "Fork hint needs reliable direction and distance")
        var merge_hint: Dictionary = road.shortcut_hint(middle)
        assert(merge_hint.get("mode","") == "merge" and
            merge_hint.get("side","") == ("LEFT" if side > 0 else "RIGHT"),
            "Driving on the detour must warn about the correct merge")
        assert(road.shortcut_hint(Vector3(0,0,-115.0)).is_empty(),
            "Route cues disappear after the merge")
        assert(road.shortcut_hint(Vector3(
            game.track_center_at(-70.0),game.height_at(-70.0),-70.0)).is_empty(),
            "Main-track racers must never receive a false merge instruction")
        assert(absf(road.bank_at(-76.0)) <= BypassScript.MAX_BANK+0.001,
            "Bank angle must stay safe for Android marble physics")
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
        # Check the whole detached stretch, not only one attractive render spot.
        for sample in range(14):
            var z: float = lerpf(-62.0,-90.0,float(sample)/13.0)
            var road_point: Vector3 = road.point_at(z)
            var probe := PhysicsRayQueryParameters3D.create(
                road_point+Vector3.UP*2.6,road_point-Vector3.UP*2.6)
            var landed: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(probe)
            assert(not landed.is_empty(),"Every bypass segment needs real floor contact")
            var floor_hit: Object = landed.get("collider")
            assert(floor_hit is StaticBody3D and (
                str(floor_hit.name).begins_with("BypassDeck_") or
                str(floor_hit.name) == "BypassLaunchRamp"),
                "No gaps or unrelated obstacle colliders along the detour")
        game.start_race("Grip Tape")
        # A minority of AI should attempt the physical bypass, rather
        # than all 39 bots always following the same central racing line.
        var bypass_bots := 0
        for racer in game.racers:
            if racer.racer_id == 39:
                assert(not racer.wants_shortcut(),
                    "A human player must never receive AI steering")
            elif racer.wants_shortcut():
                bypass_bots += 1
        assert(bypass_bots >= 3 and bypass_bots <= 9,
            "Each course should have a few rival shortcut specialists")
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
        assert(road.triggered.is_empty(),
            "Teleporting to shortcut midpoint must never produce a reward")
        # The in-race touch HUD must make the fork noticeable in advance.
        player.global_position = Vector3(game.track_center_at(-32.0),
            game.height_at(-32.0)+0.78,-32.0)
        game.ui.label_timer = 0.5
        game.ui.update_hud()
        assert(game.ui.shortcut_label.visible and
            game.ui.shortcut_label.text.contains("SHORTCUT"),
            "Android players should see the upcoming turn-off clearly")
        # The engine grants bonuses only after physically entering the fork.
        var entrance: Vector3 = road.point_at(BypassScript.ENTRY_Z-8.0)
        player.global_position = entrance+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.entered.has(39),"Real route entry must register")
        var jump_spot: Vector3 = road.point_at(BypassScript.JUMP_Z[course])
        player.global_position = jump_spot+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.jumped.has(39),"Taking the optional ramp grants one safe launch")
        assert(game.ui.toast_remaining > 0.0,
            "A controlled launch must show immediate airtime feedback")
        road.tick(0.016,game.racers,game.net)
        assert(road.jumped.size() == 1,"Holding the launch pad cannot farm impulses")
        player.global_position = middle+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(39),
            "An admitted entrant gets exactly one finish-line dash")
        assert(game.ui.toast_remaining > 0.0,
            "The bypass must show its immediate racing reward")
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.size() == 1,"A bypass bonus cannot be farmed")
        road.reset_round()
        assert(road.triggered.is_empty() and road.entered.is_empty() and
            road.jumped.is_empty(),"Fresh races reset entry, ramp and dash")
        game.net.role = "server"
        game.net.match_running = true
        game.net.joined_slots = {2:39}
        player.network_controlled = true
        player.global_position = entrance+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        player.global_position = middle+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(39),"Authoritative server grants validated reward")
        # Remote user feedback is display only; it never applies physics.
        game.net.role = "client"
        game.net._course_event_notice("shortcut")
        game.net._course_event_notice("jump")
        assert(game.ui.toast_remaining > 0.0,
            "Online human receives both shortcut and launch notices")
        game.net.match_running = false
        game.net.role = "offline"
        game.net.joined_slots.clear()
        game.return_to_menu()
    print("SHORTCUT_ROUTES_PASS: three collidable, rewarded fork/merge alternatives")
    game.queue_free()
    await process_frame
    quit()
