extends SceneTree
## Real branch regression: 3 playable exterior decks, entry/exit portals,
## physical world contact, human navigation and server-authoritative rewards.
const BypassScript = preload("res://scripts/shortcut_route.gd")
const AIPath = preload("res://scripts/ai_race_strategy.gd")
const TrackSurface = preload("res://scripts/track_surface.gd")
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
            road.bridge_grade_at(ramp_z))
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
        assert(road.get_node_or_null("RouteSignPlates") is MultiMeshInstance3D)
        var arrows := road.get_node("RouteDirectionArrows") as MultiMeshInstance3D
        assert(arrows.multimesh.instance_count == [17,22,20][course] and
            arrows.multimesh.use_colors)
        assert(arrows.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
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
        var expected_rails := 105 if course == 1 else 106
        assert(game.track_surface.rails.size() == expected_rails,
            "Glacier needs a wider physical return portal")
        assert(BypassScript.opens_rail(BypassScript.EXIT_SECTION,side,0,course) == (course == 1))
        assert(not BypassScript.opens_rail(BypassScript.EXIT_SECTION,-side,0,course))
        assert(not BypassScript.opens_rail(BypassScript.EXIT_SECTION,side,2,course))
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
            fork_hint.get("distance",-1) == 20 and
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
        assert(_verify_fork_cues(game,side))
        # A minority of AI should attempt the physical bypass, rather
        # than all 29 bots always following the same central racing line.
        var bypass_bots := 0
        for racer in game.racers:
            if racer == game.player:
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
        var fork_word := "BRIDGE RIGHT" if side > 0 else "BRIDGE LEFT"
        assert(game.ui.shortcut_label.visible and
            game.ui.shortcut_label.text.contains(fork_word),
            "Android players should see the upcoming turn-off clearly")
        # The engine grants bonuses only after physically entering the fork.
        var entrance: Vector3 = road.point_at(BypassScript.ENTRY_Z-8.0)
        player.global_position = entrance+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.entered.has(player.racer_id),"Real route entry must register")
        var jump_spot: Vector3 = road.point_at(BypassScript.JUMP_Z[course])
        player.global_position = jump_spot+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.jumped.has(player.racer_id),"Taking the optional ramp grants one safe launch")
        assert(game.ui.toast_remaining > 0.0,
            "A controlled launch must show immediate airtime feedback")
        road.tick(0.016,game.racers,game.net)
        assert(road.jumped.size() == 1,"Holding the launch pad cannot farm impulses")
        player.global_position = middle+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(player.racer_id),
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
        game.net.joined_slots = {2:player.racer_id}
        player.network_controlled = true
        player.global_position = entrance+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        player.global_position = middle+Vector3.UP*0.75
        road.tick(0.016,game.racers,game.net)
        assert(road.triggered.has(player.racer_id),"Authoritative server grants validated reward")
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
        # Rebuild and read the live HUD on every variation of this physical fork.
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            assert(game.built_variation == layout and game.racers.size() == game.MARBLE_COUNT)
            for frame in range(4):
                await physics_frame
            assert(_verify_fork_cues(game,side))
            if course == 2:
                assert(_verify_forge_fork_traffic(game))
                assert(_verify_forge_first_gate(game))
                assert(_verify_forge_gate_traffic(game))
                assert(_verify_forge_second_gate(game))
            if not _verify_merge_cues(game,side):
                quit(1)
                return
            if course == 0 and not _verify_woodworks_return(game,layout):
                quit(1)
                return
            game.return_to_menu()
            await process_frame
    print("SHORTCUT_ROUTES_PASS: three collidable, rewarded fork/merge alternatives")
    print("MERGE_GUIDANCE_PASS: nine layouts, real inside-lane markings, opposing decks and alert clearance")
    print("FORGE_FORK_TRAFFIC_PASS: three layouts, both branches, cut-ins, stale snapshots and HUD handoff")
    print("FORGE_FIRST_GATE_PASS: three layouts, confirmed bridge, curve, real gate alignment and immediate handoff")
    print("FORGE_GATE_TRAFFIC_PASS: three layouts, stalled and crossing rivals, separate decks, replica motion and stale data")
    print("FORGE_SECOND_GATE_PASS: three layouts, occupied line, ramp takeoff, crossing forecasts and downstream piston handoff")
    print("WOODWORKS_RETURN_PASS: clear bridge lip, physical warnings, visible gaps and HUD handoff on three layouts")
    game.queue_free()
    await process_frame
    quit()

func _verify_forge_fork_traffic(game: Node3D) -> bool:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var player: RigidBody3D = game.player
    var main_rival: RigidBody3D = game.racers[0]
    var bridge_rival: RigidBody3D = game.racers[1]
    for rival in game.racers:
        if rival != player:
            rival.global_position = Vector3(80.0,0.0,20.0)
            rival.freeze = true
    game.airtime.reset_round()
    player.freeze = false
    var z := BypassScript.ENTRY_PORTAL_Z+9.0
    var x: float = game.track_center_at(z)+2.8
    var fork_z := BypassScript.ENTRY_PORTAL_Z-0.2
    var bridge: Vector3 = road.point_at(fork_z)+Vector3.UP*0.67
    var main := Vector3(x+0.8,game.height_at(fork_z)+0.43,fork_z)
    player.global_position = Vector3(x,game.height_at(z)+0.43,z)
    player.linear_velocity = Vector3(2.0,0.0,-12.0)
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text.contains("MAIN TRACK") and
        hud.shortcut_label.text.contains("BRIDGE RIGHT"))

    bridge_rival.global_position = bridge
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.visible and hud.shortcut_label.text == "↑ MAIN TRACK  /  BRIDGE BUSY")
    main_rival.global_position = main
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text == "BOTH BUSY  •  SAVE BOOST")
    bridge_rival.global_position.y += 4.0
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text == "MAIN BUSY  /  BRIDGE RIGHT ↗",
        "A rival above the rolling surface must not mark the bridge as occupied")
    if game.built_variation == 1:
        game.race_moments.reset_round()
        game.race_moments.tick(0.12)
        hud.label_timer = 0.25
        hud.update_hud()
        assert(hud.timed_gate_backdrop.visible and hud.timed_gate_label.text.contains("HAMMER SWEEP"))
        assert(hud.shortcut_label.text == "MAIN BUSY",
            "Show fork traffic without a second steering instruction before the hammer")
        game.race_moments.reset_round()
    player.linear_velocity = Vector3(2.0,0.0,-23.0)
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text == "MAIN BUSY  •  SAVE BOOST",
        "A late crossing stays out of the advice when speed removes steering time")
    player.linear_velocity.z = -12.0

    # A rival starts away from the path and moves into it at arrival.
    main_rival.global_position = Vector3(80.0,0.0,20.0)
    var start_z := fork_z+5.0
    bridge_rival.global_position = Vector3(bridge.x-2.4,game.height_at(start_z)+0.43,start_z)
    bridge_rival.freeze = false
    bridge_rival.linear_velocity = Vector3(6.0,0.0,-6.5)
    assert(road.forge_fork_advice(player.global_position,player.linear_velocity).get("text","").contains("BRIDGE BUSY"))
    bridge_rival.linear_velocity.x = -6.0
    assert(road.forge_fork_advice(player.global_position,player.linear_velocity).is_empty())

    game.net.role = "client"
    game.net.match_running = true
    var packet := PackedFloat32Array()
    var approach := player.global_position
    var speed := player.linear_velocity
    var cut_in := Vector3(6.0,0.0,-6.5)
    for racer in game.racers:
        var at: Vector3 = racer.global_position
        var motion := speed if racer == player else (cut_in if racer == bridge_rival else Vector3.ZERO)
        at -= motion*0.10
        packet.append_array(PackedFloat32Array([at.x,at.y,at.z,0,0,0,1,0,0]))
    game.net._receive_snapshot(packet,1.0,PackedFloat32Array())
    var stride: int = game.net.FLOATS_PER_RACER
    for offset in [0,2]:
        packet[player.racer_id*stride+offset] += speed[offset]*0.10
        packet[bridge_rival.racer_id*stride+offset] += cut_in[offset]*0.10
    game.net._receive_snapshot(packet,1.1,PackedFloat32Array())
    player.global_position = approach
    bridge_rival.global_position += cut_in*0.10
    assert(road.forge_fork_advice(approach,game.net.replica_velocity(player)).get(
        "text","").contains("BRIDGE BUSY"),"Forecast the replicated cut-in using its server velocity")
    game.net.snapshot_age_seconds = game.net.PRESENTATION_MAX_AGE+0.01
    assert(road.forge_fork_advice(player.global_position,player.linear_velocity).is_empty())
    game.net.role = "offline"
    game.net.match_running = false
    game.net._clear_snapshots()
    player.global_position.z = BypassScript.ENTRY_PORTAL_Z-2.1
    hud.label_timer = 0.25
    hud.update_hud()
    assert(not hud.shortcut_label.visible and not hud.bridge_approach_active)
    bridge_rival.freeze = true
    return true

func _verify_forge_first_gate(game: Node3D) -> bool:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var player: RigidBody3D = game.player
    var z := -55.0
    var at: Vector3 = road.point_at(z)+Vector3.UP*0.67
    var velocity := Vector3(0,0,-12.0)
    var main := Vector3(game.track_center_at(z),game.height_at(z)+0.43,z)
    _refresh_bridge_hud(hud,player,main,velocity)
    assert(not hud.bridge_approach_active and not hud.shortcut_label.visible)

    velocity.x = (road.point_at(z-12.0*0.32).x-at.x)/0.32
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.bridge_approach_active and hud.shortcut_label.visible and
        hud.shortcut_label.text == "GATE 1 / 3  •  FOLLOW CURVE  •  10m")
    var edge_z := -53.5
    var edge := Vector3(game.track_center_at(edge_z)+6.5,road.point_at(edge_z).y+0.67,edge_z)
    _refresh_bridge_hud(hud,player,edge,velocity)
    assert(hud.bridge_approach_active and hud.shortcut_label.text.contains("GATE 1 / 3"),
        "A confirmed bridge line keeps its guidance over the shared edge")
    _refresh_bridge_hud(hud,player,at,Vector3(0,0,-12.0))
    assert(hud.shortcut_label.text.contains("AIM RIGHT"),
        "A marble coasting straight on the bend must follow the deck outward")

    var gate_z: float = BypassScript.BRIDGE_POST_Z[0]
    var approach: Vector3 = road.point_at(gate_z+2.2)+Vector3.UP*0.67
    velocity.x = 0.0
    for offset: float in [0.0,-1.2,1.2]:
        var lane := approach+Vector3.RIGHT*offset
        _refresh_bridge_hud(hud,player,lane,velocity)
        var action := "HOLD CENTER" if offset == 0.0 else ("AIM RIGHT" if offset < 0.0 else "AIM LEFT")
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains(action))
        assert(player.global_position.is_equal_approx(lane) and player.linear_velocity.is_equal_approx(velocity),
            "Guide text must leave the racer in control")
    _refresh_bridge_hud(hud,player,approach+Vector3.UP*2.5,velocity)
    assert(not hud.shortcut_label.visible)
    game.net.role = "client"
    game.net.match_running = true
    _refresh_bridge_hud(hud,player,approach,velocity)
    assert(not hud.shortcut_label.visible,"A missing network velocity cannot establish gate alignment")
    game.net.match_running = false
    game.net.role = "offline"
    _refresh_bridge_hud(hud,player,road.point_at(gate_z-0.35)+Vector3.UP*0.67,velocity)
    assert(hud.bridge_approach_active and hud.shortcut_label.visible and
        hud.shortcut_label.text.contains("GATE 2 / 3"),
        "Hand off to the second gate as soon as the player crosses the first")
    return true

func _verify_forge_gate_traffic(game: Node3D) -> bool:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var player: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    var gate_z: float = BypassScript.BRIDGE_POST_Z[0]
    var at: Vector3 = road.point_at(gate_z+4.0)+Vector3.UP*0.67
    var velocity := Vector3(0,0,-12.0)
    var stopped: Vector3 = road.point_at(gate_z-0.65)+Vector3.UP*0.67
    rival.freeze = true
    rival.global_position = stopped
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("TRAFFIC  •  SAVE BOOST"),
        "A stopped marble just beyond the posts still occupies the scoring line")
    assert(hud.shortcut_label.get_theme_color("font_color") == hud.TIME_LOSS)
    var outside := at+Vector3.RIGHT*1.10
    _refresh_bridge_hud(hud,player,outside,velocity)
    assert(hud.shortcut_label.text.contains("SAVE BOOST") and not hud.shortcut_label.text.contains("AIM"),
        "Do not ask the player to steer toward the occupied center")

    rival.global_position = stopped+Vector3.UP*2.5
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.text.contains("HOLD CENTER"))
    rival.global_position = Vector3(game.track_center_at(stopped.z),game.height_at(stopped.z)+0.43,stopped.z)
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.text.contains("HOLD CENTER"),"Traffic on the main road stays out of the forecast")
    rival.global_position = stopped
    rival.freeze = false
    rival.linear_velocity = Vector3(0,0,-17.0)
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.text.contains("HOLD CENTER"),"A faster rival opening the gap should not warn")

    var cut_z := gate_z+1.1
    var cutting: Vector3 = road.point_at(cut_z)+Vector3(1.45,0.67,0)
    var cut_velocity := Vector3(-4.7,0,-5.0)
    rival.global_position = cutting
    rival.linear_velocity = cut_velocity
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.text.contains("TRAFFIC  •  SAVE BOOST"),"Catch the lateral cut into the gate")
    rival.linear_velocity.x = 0.0
    _refresh_bridge_hud(hud,player,at,velocity)
    assert(hud.shortcut_label.text.contains("HOLD CENTER"),"A rival staying outside the line leaves it readable")

    game.net.role = "client"
    game.net.match_running = true
    var packet := PackedFloat32Array()
    for racer in game.racers:
        var pos: Vector3 = racer.global_position
        var motion := velocity if racer == player else (cut_velocity if racer == rival else Vector3.ZERO)
        pos -= motion*0.10
        packet.append_array(PackedFloat32Array([pos.x,pos.y,pos.z,0,0,0,1,0,0]))
    game.net._receive_snapshot(packet,1.0,PackedFloat32Array())
    var stride: int = game.net.FLOATS_PER_RACER
    for offset in [0,2]:
        packet[player.racer_id*stride+offset] += velocity[offset]*0.10
        packet[rival.racer_id*stride+offset] += cut_velocity[offset]*0.10
    game.net._receive_snapshot(packet,1.1,PackedFloat32Array())
    rival.global_position = cutting
    _refresh_bridge_hud(hud,player,at,Vector3.ZERO)
    assert(hud.shortcut_label.text.contains("TRAFFIC  •  SAVE BOOST"),"Use server-replica motion")
    game.net.snapshot_velocities[rival.racer_id] = Vector3.INF
    _refresh_bridge_hud(hud,player,at,Vector3.ZERO)
    assert(hud.shortcut_label.text.contains("CHECK TRAFFIC"),"Uncertain rival motion must withhold aiming advice")
    game.net.snapshot_age_seconds = game.net.PRESENTATION_MAX_AGE+0.01
    _refresh_bridge_hud(hud,player,at,Vector3.ZERO)
    assert(not hud.shortcut_label.visible)
    game.net.role = "offline"
    game.net.match_running = false
    game.net._clear_snapshots()
    rival.freeze = true
    rival.global_position = stopped
    var past_first: Vector3 = road.point_at(gate_z-0.35)+Vector3.UP*0.67
    _refresh_bridge_hud(hud,player,past_first,velocity)
    assert(hud.shortcut_label.text.contains("GATE 2 / 3") and
        hud.shortcut_label.text.contains("SAVE BOOST"),"Road traffic can still block the next gate's approach")
    rival.global_position = Vector3(80.0,0.0,20.0)
    _refresh_bridge_hud(hud,player,past_first,velocity)
    assert(hud.shortcut_label.text.contains("HOLD CENTER") and not hud.shortcut_label.text.contains("SAVE BOOST"))
    return true

func _verify_forge_second_gate(game: Node3D) -> bool:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var player: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    var second: float = BypassScript.BRIDGE_POST_Z[1]
    var first: float = BypassScript.BRIDGE_POST_Z[0]
    var after_first: Vector3 = road.point_at(first)+Vector3.UP*0.67
    var velocity := Vector3(0,0,-12.0)
    var racer_id: int = player.racer_id
    road.precision_failed[racer_id] = true
    _refresh_bridge_hud(hud,player,after_first,velocity)
    assert(hud.shortcut_label.text == "GATE 2 / 3  •  HOLD CENTER  •  15m",
        "The next physical gate stays readable even when the precision streak was missed")
    assert(road.bridge_gate_count(racer_id) == 0 and road.precision_failed.has(racer_id))
    road.precision_failed.erase(racer_id)

    var approach: Vector3 = road.point_at(second+4.0)+Vector3.UP*0.67
    _refresh_bridge_hud(hud,player,approach+Vector3.RIGHT*1.2,velocity)
    assert(hud.shortcut_label.text.contains("AIM LEFT"))
    _refresh_bridge_hud(hud,player,approach-Vector3.RIGHT*1.2,velocity)
    assert(hud.shortcut_label.text.contains("AIM RIGHT"))
    rival.global_position = road.point_at(second-0.5)+Vector3.UP*0.67
    _refresh_bridge_hud(hud,player,approach,velocity)
    assert(hud.shortcut_label.text.contains("GATE 2 / 3  •  TRAFFIC  •  SAVE BOOST"))
    rival.global_position = Vector3(game.track_center_at(second),game.height_at(second)+0.43,second)
    _refresh_bridge_hud(hud,player,approach,velocity)
    assert(hud.shortcut_label.text.contains("GATE 2 / 3  •  HOLD CENTER"))
    rival.global_position = Vector3(80.0,0.0,20.0)

    var director: Node3D = game.race_director
    var exit_gate: int = director.FORGE_EXIT_GATE
    var fast := Vector3(0,0,-23.0)
    var near_gate: Vector3 = road.point_at(second+0.25)+Vector3.UP*0.67
    var after_gate: Vector3 = road.point_at(second-5.0)+Vector3.UP*0.67
    var return_eta: float = (near_gate.z-director.event_z(exit_gate))/-fast.z
    var found_phase := false
    for sample in range(40):
        director.animate(director.period()*float(sample)/40.0)
        if director.forge_exit_blocks_during_crossing(return_eta,-fast.z):
            found_phase = true
            break
    assert(found_phase,"The return piston has a closed phase during this preview")
    _refresh_bridge_hud(hud,player,near_gate,fast)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 2 / 3"))
    assert(not hud.timed_gate_label.visible and not hud.timed_gate_backdrop.visible,
        "The piston downstream of the bridge cannot displace the active second gate")
    _refresh_bridge_hud(hud,player,road.point_at(second-0.35)+Vector3.UP*0.67,fast)
    assert(hud.bridge_approach_active and not hud.shortcut_label.text.contains("GATE 2 / 3"))
    _refresh_bridge_hud(hud,player,after_gate,fast)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3  •  LINE UP JUMP"),
        "After the second portico, the third gate previews the physical ramp")
    var third: float = BypassScript.BRIDGE_POST_Z[2]
    _refresh_bridge_hud(hud,player,road.point_at(third+3.0)+Vector3.UP*0.67,velocity)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3"))
    rival.global_position = road.point_at(third-0.4)+Vector3.UP*0.67
    _refresh_bridge_hud(hud,player,road.point_at(third+3.0)+Vector3.UP*0.67,velocity)
    assert(hud.shortcut_label.text.contains("TRAFFIC  •  SAVE BOOST"),
        "Third-gate steering must yield to a rival in the crossing corridor")
    rival.global_position = Vector3(80.0,0.0,20.0)
    var air_z := third+0.9
    var gate_center: Vector3 = road.point_at(third)
    var aligned := Vector3(gate_center.x,gate_center.y+1.7,air_z)
    _refresh_bridge_hud(hud,player,aligned,velocity)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3  •  LAND CENTER"))
    _refresh_bridge_hud(hud,player,aligned+Vector3.RIGHT*1.2,velocity)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3  •  WATCH LANDING"))
    var high := aligned+Vector3.UP*1.05
    _refresh_bridge_hud(hud,player,high,velocity)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3  •  TOO HIGH"))
    _refresh_bridge_hud(hud,player,high,velocity+Vector3.DOWN*6.0)
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 3 / 3  •  LAND CENTER"),
        "Evaluate height at the gate instead of warning on current jump height alone")
    var under_bridge := Vector3(game.track_center_at(air_z),game.height_at(air_z)+0.67,air_z)
    _refresh_bridge_hud(hud,player,under_bridge,velocity)
    assert(not hud.shortcut_label.visible)
    _refresh_bridge_hud(hud,player,road.point_at(third-0.5)+Vector3.UP*0.67,fast)
    assert(not hud.shortcut_label.text.contains("GATE 3 / 3") and hud.timed_gate_label.visible,
        "The exit piston forecast resumes immediately after the final portico")
    return true

func _refresh_bridge_hud(hud: CanvasLayer, player: RigidBody3D, at: Vector3, velocity: Vector3) -> void:
    player.global_position = at
    player.linear_velocity = velocity
    hud.label_timer = 0.25
    hud.update_hud()

func _verify_fork_cues(game: Node3D, side: int) -> bool:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    game.race_state = "RACING"
    var marble: RigidBody3D = game.player
    marble.linear_velocity = Vector3(0,0,-23)
    var z: float = BypassScript.ENTRY_PORTAL_Z+30.0
    marble.global_position = Vector3(game.track_center_at(z),game.height_at(z)+0.6,z)
    hud.label_timer = 0.25
    hud.update_hud()
    var direction := "RIGHT" if side > 0 else "LEFT"
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("BRIDGE "+direction) and
        hud.shortcut_label.text.contains("MAIN TRACK") and
        hud.shortcut_label.text.contains("1.3s"),
        "Fast fork guidance shows time and side before the rail opens")
    z = BypassScript.ENTRY_PORTAL_Z+1.4
    marble.global_position.z = z
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text.contains("BRIDGE "+direction+" NOW"))
    marble.global_position = Vector3(game.track_center_at(z)+side*6.1,
        game.height_at(z)+0.6,z)
    assert(road.shortcut_hint(marble.global_position).get("mode") == "fork",
        "A marble beside the rail is still making its entry choice")
    var after_entry := BypassScript.ENTRY_PORTAL_Z-2.1
    marble.global_position = Vector3(game.track_center_at(after_entry)+side*6.1,
        game.height_at(after_entry)+0.6,after_entry)
    assert(road.shortcut_hint(marble.global_position).is_empty())
    z = BypassScript.EXIT_Z+1.5
    var return_point: Vector3 = road.point_at(z)+Vector3.UP*0.7
    assert(road.shortcut_hint(return_point).is_empty(),
        "Ambiguous shared deck cannot create a merge instruction by itself")
    marble.global_position = road.point_at(BypassScript.EXIT_Z+28.0)+Vector3.UP*0.7
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.bridge_approach_active)
    if game.selected_track == 0:
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 2 / 3"))
        _verify_woodworks_gates(game)
    elif game.selected_track == 2:
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("GATE 2 / 3"))
    else:
        assert(not hud.shortcut_label.visible,
            "The detached deck is recognized before the merge direction is needed")
    marble.global_position = return_point
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.bridge_approach_active,"A confirmed bridge racer keeps the route at the lip")
    if game.selected_track == 1:
        assert(hud.timed_gate_label.visible and not hud.shortcut_label.visible and (
            hud.timed_gate_label.text.contains("AIM CENTER") or
            hud.timed_gate_label.text.contains("MERGE RIGHT NOW")))
    else:
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("MERGE LEFT NOW"))
    marble.global_position.z = BypassScript.EXIT_Z-0.3
    hud.label_timer = 0.25
    hud.update_hud()
    assert(not hud.bridge_approach_active and not hud.shortcut_label.visible)
    hud.show_race_ui()
    assert(not hud.bridge_approach_active)
    return true

func _verify_merge_cues(game: Node3D, side: int) -> bool:
    var road: Node3D = game.shortcut_route
    assert(road.main_merge_arrows.size() >= 3)
    var previous := INF
    for arrow: Transform3D in road.main_merge_arrows:
        var at := arrow.origin
        var lateral: float = side*(at.x-game.track_center_at(at.z))
        assert(at.z < previous and lateral <= -1.0 and lateral >= -2.5)
        assert(absf(at.y-game.height_at(at.z)) < 0.25)
        previous = at.z
    var player: RigidBody3D = game.player
    var other: RigidBody3D = game.racers[0]
    var z := BypassScript.EXIT_Z+8.0
    var bridge: Vector3 = road.point_at(z)+Vector3.UP*0.65
    var main := Vector3(game.track_center_at(z)-side*1.3,game.height_at(z)+0.44,z)
    player.global_position = main
    player.freeze = false
    player.linear_velocity = Vector3(0,0,-16)
    other.global_position = bridge
    other.freeze = false
    other.linear_velocity = Vector3(0,0,-16)
    var moments: RefCounted = game.race_moments
    moments.reset_round()
    moments.tick(0.1)
    assert(moments.merge_traffic == 1)
    var hud: CanvasLayer = game.ui
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("BRIDGE TRAFFIC"))
    player.global_position = bridge
    other.global_position = main
    moments.reset_round()
    moments.tick(0.1)
    assert(moments.merge_traffic == -1)
    hud.label_timer = 0.25
    hud.update_hud()
    if not hud.timed_gate_backdrop.visible:
        assert(hud.shortcut_label.text.contains("MAIN TRAFFIC  •  SAVE BOOST"),
            "An occupied bridge return must discourage boosting into the main lane")
    other.global_position.y += 3.0
    moments.tick(0.1)
    assert(moments.merge_traffic == 0,"A marble falling below or flying above the junction is not merge traffic")
    if game.selected_track == 0:
        z = BypassScript.EXIT_Z+3.0
        player.global_position = Vector3(game.track_center_at(z)-1.3,game.height_at(z)+0.44,z)
        player.linear_velocity.z = -8.0
        other.global_position = road.point_at(BypassScript.EXIT_Z+9.5)+Vector3.UP*0.65
        other.linear_velocity.z = -24.0
        moments.reset_round()
        moments.tick(0.12)
        assert(moments.merge_traffic == 1 and moments.merge_rival == other,
            "Predict crossing time when a fast outside rival is still 6.5m behind")
        game._update_camera(0.12,true)
        hud.label_timer = 0.25
        hud.update_hud()
        assert(hud.shortcut_label.text.contains("BRIDGE TRAFFIC RIGHT"))
        other.linear_velocity.z = -4.0
        moments.tick(0.12)
        hud.label_timer = 0.25
        hud.update_hud()
        hud.player_locator.refresh(1.0/30.0) # Sample the cleared merge cue deterministically.
        assert(moments.merge_traffic == 0 and not is_instance_valid(moments.merge_rival) and (
            not hud.player_locator.merge_rival_center.is_finite()),
            "The same rival no longer reaches the merge within the player's window")
    # A dense two-road convergence must choose the rival whose arrival is
    # closest to the player's, not whichever happens to be last in the array.
    # A third slow rival outside the local conflict window must not inflate
    # the pack cue (including when it is visible in the duel radar).
    var second: RigidBody3D = game.racers[1]
    var slow: RigidBody3D = game.racers[2]
    for racer in game.racers:
        if racer == player:
            continue
        racer.freeze = true
        racer.global_position = Vector3(80.0,0.0,20.0)
    for racer in [other,second,slow]:
        racer.freeze = false
    var crossing_z: float = BypassScript.EXIT_Z+4.0
    player.global_position = Vector3(game.track_center_at(crossing_z)-side*1.3,
        game.height_at(crossing_z)+0.44,crossing_z)
    player.linear_velocity = Vector3(0,0,-12.0)
    other.global_position = road.point_at(BypassScript.EXIT_Z+6.0)+Vector3.UP*0.65
    other.linear_velocity = Vector3(0,0,-18.0)
    second.global_position = road.point_at(BypassScript.EXIT_Z+7.0)+Vector3.UP*0.65
    second.linear_velocity = Vector3(0,0,-20.0)
    slow.global_position = road.point_at(BypassScript.EXIT_Z+9.0)+Vector3.UP*0.65
    slow.linear_velocity = Vector3(0,0,-4.0)
    moments.reset_round()
    moments.tick(0.12)
    assert(moments.merge_traffic == 1 and moments.merge_threat_count == 2 and
        moments.merge_rival == other,
        "Two bridge arrivals are counted, with the closest crossing highlighted")
    hud.label_timer = 0.25
    hud.update_hud()
    if not hud.timed_gate_backdrop.visible and not hud.final_danger_active:
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("BRIDGE PACK"),
            "A multiple-rival merge needs a compact pack warning")
    other.global_position.y += 3.5
    moments.tick(0.12)
    assert(moments.merge_threat_count == 1 and moments.merge_rival == second,
        "A rival above the bridge cannot remain the highlighted threat")
    second.global_position.y += 3.5
    moments.tick(0.12)
    assert(moments.merge_traffic == 0 and moments.merge_threat_count == 0 and (
            moments.merge_rival == null),
        "Clear the pack cue as soon as both crossing lanes are free")

    # Reverse the junction: the human arrives on the bridge and two main-road
    # rivals occupy the return. The instruction must remain on the correct side.
    player.global_position = road.point_at(crossing_z)+Vector3.UP*0.65
    other.global_position = Vector3(game.track_center_at(BypassScript.EXIT_Z+6.0)-side*1.3,
        game.height_at(BypassScript.EXIT_Z+6.0)+0.44,BypassScript.EXIT_Z+6.0)
    second.global_position = Vector3(game.track_center_at(BypassScript.EXIT_Z+7.0)-side*1.3,
        game.height_at(BypassScript.EXIT_Z+7.0)+0.44,BypassScript.EXIT_Z+7.0)
    slow.global_position.y += 4.0
    moments.reset_round()
    moments.tick(0.12)
    assert(moments.merge_traffic == -1 and moments.merge_threat_count == 2 and
        moments.merge_rival == other,
        "The same two arrivals must be detected from the bridge side")
    hud.label_timer = 0.25
    hud.update_hud()
    if not hud.timed_gate_backdrop.visible and not hud.final_danger_active:
        assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains(
            "MAIN PACK  •  SAVE BOOST"),
            "A packed main lane must override the ordinary accelerate-through-merge cue")
    return true

func _verify_woodworks_gates(game: Node3D) -> void:
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var player: RigidBody3D = game.player
    for i in range(BypassScript.BRIDGE_POST_Z.size()):
        var z: float = BypassScript.BRIDGE_POST_Z[i]+5.0
        player.global_position = road.point_at(z)+Vector3.UP*0.65
        hud.label_timer = 0.25
        hud.update_hud()
        assert(hud.shortcut_label.text.contains("GATE %d / 3" % (i+1)))
        assert(hud.shortcut_label.text.contains("HOLD CENTER"))
    player.global_position.x += 1.20
    hud.label_timer = 0.25
    hud.update_hud()
    assert(hud.shortcut_label.text.contains("AIM LEFT"))
    player.global_position.y += 3.5
    hud.label_timer = 0.25
    hud.update_hud()
    assert(not hud.shortcut_label.visible or not hud.shortcut_label.text.contains("GATE"))

func _verify_woodworks_return(game: Node3D, layout: int) -> bool:
    var road: Node3D = game.shortcut_route
    var player: RigidBody3D = game.player
    var hud: CanvasLayer = game.ui
    var locator: Control = hud.player_locator
    var rival: RigidBody3D = game.racers[0]
    var ball := SphereShape3D.new()
    ball.radius = 0.39
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = ball
    var ignored: Array[RID] = []
    for racer in game.racers:
        if racer != player:
            racer.global_position = Vector3(90,0,20)
        ignored.append(racer.get_rid())
    query.exclude = ignored
    var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    for dz: float in [1.5,1.0,0.5,0.0,-0.4,-0.8,-1.3,-1.9,-2.4]:
        var at: Vector3 = road.point_at(road.EXIT_Z+dz)+Vector3.UP*0.65
        at.x -= maxf(0.0,-dz)*0.16
        query.transform = Transform3D(Basis.IDENTITY,at)
        for hit in space.intersect_shape(query):
            var body: Object = hit["collider"]
            assert(body.has_meta(BypassScript.ROLLING_SURFACE) or body.has_meta(TrackSurface.ROAD_FLOOR),
                "Layout %d: %s blocks the center of the physical bridge lip" % [layout,body.name])

    game.cam_mode = 0
    game.airtime.reset_round()
    player.global_position = road.point_at(road.EXIT_Z+2.4)+Vector3.UP*0.62
    player.linear_velocity = Vector3(-5,0,-19)
    game.race_moments.reset_round()
    game._update_camera(0.12,true)
    game.race_moments.tick(0.12)
    hud.bridge_approach_active = true
    hud.label_timer = 1.0
    hud.update_hud()
    assert(hud.shortcut_label.visible and hud.shortcut_label.text.contains("MERGE LEFT"))
    assert(hud.timed_gate_label.visible and hud.timed_gate_label.text.contains("AFTER MERGE"))
    assert(not game.race_moments.evasion_target.is_finite(),"Complete the merge before following a gap")

    var z := -104.05
    var x: float = [-3.15148,-1.06710,1.35209][layout]
    player.global_position = Vector3(x,game.height_at(z)+0.43,z)
    player.linear_velocity = Vector3(0,0,-8)
    game.race_moments.reset_round()
    game._update_camera(0.12,true)
    var threat: Dictionary = game.woodworks_return_threat(player.global_position,player.linear_velocity)
    assert(not threat.is_empty())
    var target: Vector3 = threat["position"]
    var eye: Vector3 = game.camera.global_position
    rival.global_position = eye.lerp(target,(target.z+0.22-eye.z)/(target.z-eye.z))
    rival.global_position.y = game.height_at(rival.global_position.z)+0.42
    game.race_moments.tick(0.12)
    hud.label_timer = 1.0
    hud.update_hud()
    assert(locator.hazard_center.is_finite() and locator.evasion_center.is_finite())
    assert(hud.timed_gate_label.text.contains("GAP LEFT") and not hud.shortcut_label.visible)
    rival.global_position.x += 2.8
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(not locator.hazard_center.is_finite(),"Remove the overlay when the obstacle is visible again")
    return true
