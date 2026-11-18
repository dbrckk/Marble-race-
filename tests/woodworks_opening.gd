extends SceneTree
## The first solo run uses the normal HUD, inputs, pickups and replay path.
const ITEMS = preload("res://scripts/race_items.gd")
const ROUTE = preload("res://scripts/shortcut_route.gd")
const MARBLE = preload("res://scripts/marble.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_woodworks_opening.cfg"
    game.career.finishes = 0
    game.set_process(false)
    game.set_physics_process(false)
    var hud = game.ui
    hud.woodworks_guide_seen = false
    assert(hud.woodworks_guide_label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(hud.woodworks_guide_label.get_parent().mouse_filter == Control.MOUSE_FILTER_IGNORE)
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40 and hud.woodworks_guide_active)
    assert(not hud.woodworks_guide_label.is_visible_in_tree(), "Countdown stays clear")
    game.race_state = "RACING"
    game.player.freeze = false
    game.race_time = 15.0
    _refresh(game)
    assert(hud.woodworks_guide_label.is_visible_in_tree(),"Steering stays visible after the old timeout")
    assert(hud.woodworks_guide_label.text.contains("STEER"))
    var pad = hud.touch_controls
    pad.left_handed = false
    var screen: Vector2 = pad.get_viewport_rect().size
    var joystick := screen*Vector2(0.16,0.81)
    var boost := screen*Vector2(0.79,0.81)
    pad._finger_event(1,joystick,true)
    pad._move_finger(1,joystick+Vector2(78,0))
    game._physics_process(1.0/60.0)
    game._physics_process(1.0/60.0)
    _refresh(game)
    assert(game.steer > 0.22 and hud.woodworks_guide_label.text.contains("BOOST"))
    pad._finger_event(2,boost,true)
    assert(game.boosting and pad.joystick_finger == 1)
    game._physics_process(1.0/60.0)
    pad.release_all()
    _refresh(game)
    assert(hud.woodworks_boosted,"A boost applied between HUD refreshes is remembered")

    var pickup: Node3D = game.race_items.items[0]
    game.player.global_position = pickup.global_position+Vector3.BACK*12.0
    game.race_time = 35.0
    _refresh(game)
    assert(hud.rare_item_label.visible and hud.rare_item_label.text.contains("TURBO DIAMOND"))
    var pickup_background: Panel = hud.driving_cue_backgrounds[hud.rare_item_label]
    assert(pickup_background.visible and pickup_background.size.x > 0.0 and
        pickup_background.show_behind_parent and pickup_background.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The pickup cue stays legible without blocking touch input")
    assert(hud.woodworks_guide_label.text.contains("ACTIVATE") and hud.woodworks_guide_label.is_visible_in_tree())
    game.player.global_position = pickup.global_position
    game.race_items.tick(1.0/60.0,game.racers,game.net)
    assert(not pickup.visible and hud.checkpoint_label.text.contains("INSTANT TURBO"))

    var z := ROUTE.ENTRY_PORTAL_Z+2.0
    game.player.global_position = Vector3(game.track_center_at(z),game.height_at(z)+0.4,z)
    _refresh(game)
    assert(hud.shortcut_label.text.contains("MAIN TRACK") and
        hud.shortcut_label.text.contains("BRIDGE RIGHT NOW"))
    assert(hud.woodworks_guide_label.text.contains("AMBER") and hud.woodworks_guide_label.is_visible_in_tree())
    assert(hud.woodworks_guide_active, "Keep the choice visible through the entrance")
    var bridge: Vector3 = game.shortcut_route.point_at(-72.0)
    game.player.global_position = bridge+Vector3.UP
    _refresh(game)
    assert(hud.bridge_approach_active and not hud.shortcut_label.visible and not hud.hazard_label.visible)
    assert(not hud.woodworks_guide_active and hud.woodworks_guide_seen)
    var settings := ConfigFile.new()
    assert(settings.load("user://marble_settings.cfg") == OK)
    assert(settings.get_value("controls","woodworks_guide_seen",false))

    game._end_race()
    assert(hud.replay_button_ref.is_visible_in_tree() and not hud.replay_button_ref.disabled)
    hud.replay_button_ref.pressed.emit()
    assert(game.race_state == "COUNTDOWN" and game.built_variation == 0)
    assert(not hud.woodworks_guide_active and not hud.checkpoint_label.visible)
    game._end_race()
    hud.next_layout_button.pressed.emit()
    assert(game.race_state == "COUNTDOWN" and game.built_variation == 1)

    # Starting a multiplayer round can reuse the already-built solo scene.
    # Its pickups must revert even when _make_course is not called.
    var prior_board: Node3D = game.board
    game.race_variation = game.built_variation
    game.net.role = "client"
    game.start_race("Grip Tape")
    assert(game.board == prior_board and not hud.woodworks_guide_active)
    for i in range(game.race_items.items.size()):
        var online: Vector3 = ITEMS.placement_at(i,0,game.built_variation,false)
        assert(online.z == ITEMS.ITEM_Z[i])
        assert(game.race_items.items[i].position.is_equal_approx(online))
    game.net.role = "offline"
    game.race_variation = game.built_variation
    game.start_race("Grip Tape")
    assert(game.board == prior_board)
    assert(game.race_items.items[0].position.is_equal_approx(
        ITEMS.placement_at(0,0,game.built_variation)))

    _verify_main_track(game)
    await _verify_pickup_approaches(game)
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_woodworks_opening.cfg"))
    print("WOODWORKS_OPENING_PASS: controls, pickup handoff, occluded fork arrows, bridge camera, persistence, replay, network parity")
    quit()

func _refresh(game: Node3D) -> void:
    game.ui.label_timer = 1.0
    game.ui.update_hud()

func _verify_main_track(game: Node3D) -> void:
    var hud = game.ui
    hud.woodworks_guide_seen = false
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.freeze = false
    game.change_boost(true)
    game._physics_process(1.0/60.0)
    game.change_boost(false)
    _refresh(game)
    assert(hud.woodworks_guide_label.text.contains("STEER"),"Boosting first still leaves the steering step")
    game.change_steer(1.0)
    game._physics_process(1.0/60.0)
    game._physics_process(1.0/60.0)
    game.change_steer(0.0)
    var z := ROUTE.ENTRY_PORTAL_Z
    game.player.position = Vector3(game.track_center_at(z),game.height_at(z)+0.4,z)
    _refresh(game)
    assert(game.race_items.items[0].visible and hud.woodworks_guide_label.text.contains("AMBER"),
        "A missed diamond must hand off to the fork")
    assert(hud.woodworks_guide_active and not hud.woodworks_guide_seen)
    z -= ROUTE.PORTAL_HALF_LENGTH+1.0
    game.player.position = Vector3(game.track_center_at(z),game.height_at(z)+0.4,z)
    _refresh(game)
    assert(hud.woodworks_guide_seen and not hud.woodworks_guide_active,
        "Taking the main road completes the guide too")

func _verify_pickup_approaches(game: Node3D) -> void:
    var marble := SphereShape3D.new()
    marble.radius = MARBLE.RADIUS
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = marble
    for layout in range(3):
        game.race_variation = layout
        game.ui.woodworks_guide_seen = false
        game.start_race("Grip Tape")
        var exclude: Array[RID] = []
        for racer in game.racers:
            exclude.append(racer.get_rid())
        query.exclude = exclude
        await physics_frame
        await physics_frame
        var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
        for item in game.race_items.items:
            for dz in [-1.0,0.0,1.0]:
                var probe: Vector3 = item.position+Vector3.BACK*dz
                probe.y = game.height_at(probe.z)+0.51
                query.transform = Transform3D(Basis.IDENTITY,probe)
                assert(space.intersect_shape(query,1).is_empty(),
                    "Woodworks layout %d: a collider blocks the line through %s" % [layout,item.name])
        _verify_opening_in_pack(game)
        _verify_fork_handoff(game)

func _verify_opening_in_pack(game: Node3D) -> void:
    var art: MeshInstance3D = game.opening_obstacle_art
    var pickup: Node3D = game.race_items.items[0]
    var player: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    var hud: CanvasLayer = game.ui
    var locator: Control = hud.player_locator
    var velocity := Vector3(0,0,-16.0)
    var gap: Vector2 = art.entry_gaps[0]
    var gap_x := art.global_position.x+(gap.x+gap.y)*0.5
    game.race_state = "RACING"
    game.cam_mode = 0
    hud.record_woodworks_controls(1.0,true)
    game.airtime.reset_round()
    game.race_moments.reset_round()
    for racer in game.racers:
        if racer != player:
            racer.global_position = Vector3(80,0,20)
    for seek_turbo in [false,true]:
        var x := pickup.global_position.x if seek_turbo else gap_x
        var target_z: float = pickup.global_position.z if seek_turbo else art.entry_z
        var z := target_z+5.0
        var at := Vector3(x,game.height_at(z)+0.43,z)
        player.global_position = at
        player.linear_velocity = velocity
        game.race_moments.reset_round()
        game._update_camera(0.12,true)
        if not seek_turbo:
            var opening_height: float = game.camera.global_position.y
            game.opening_obstacle_art = null
            game._update_camera(0.12,true)
            assert(opening_height > game.camera.global_position.y)
            game.opening_obstacle_art = art
            game._update_camera(0.12,true)
        var target := Vector3(x,game.height_at(target_z)+0.39,target_z)
        if not seek_turbo:
            target = art.entry_mark_ahead(game,at,velocity)
        assert(target.is_finite())
        var eye: Vector3 = game.camera.global_position
        var block := eye.lerp(target,(target.z+0.35-eye.z)/(target.z-eye.z))
        block.y = game.height_at(block.z)+MARBLE.RADIUS
        rival.global_position = block
        game.race_moments.tick(0.12)
        _refresh(game)
        if seek_turbo:
            assert(hud.rare_item_label.visible and locator.turbo_center.is_finite())
            assert(hud.woodworks_guide_label.text.contains("ACTIVATE"))
        else:
            assert(not hud.rare_item_label.visible and locator.evasion_center.is_finite())
            assert(hud.woodworks_guide_label.text.contains("MINT CHEVRONS"))
        rival.global_position.x += 2.8
        game.race_moments.tick(0.12)
        _refresh(game)
        assert(not locator.turbo_center.is_finite() and not locator.evasion_center.is_finite())
    game.race_moments.reset_round()

func _verify_fork_handoff(game: Node3D) -> void:
    var road: Node3D = game.shortcut_route
    var pickup: Node3D = game.race_items.items[0]
    var player: RigidBody3D = game.player
    var hud: CanvasLayer = game.ui
    var locator: Control = hud.player_locator
    var pickup_pose := pickup.global_position+Vector3.BACK*1.2
    player.global_position = pickup_pose
    player.linear_velocity = Vector3(0,0,-23.0)
    _refresh(game)
    assert(hud.rare_item_label.visible and not hud.shortcut_label.visible,
        "A reachable diamond keeps the last fraction of a second before the fork prompt")
    player.global_position.x = game.track_center_at(pickup_pose.z)-3.0*signf(
        pickup_pose.x-game.track_center_at(pickup_pose.z))
    _refresh(game)
    assert(hud.shortcut_label.visible and not hud.rare_item_label.visible and pickup.visible,
        "The fork gets the HUD when a fast racer chooses to skip the diamond")
    player.global_position = pickup_pose
    game.race_items.tick(1.0/60.0,game.racers,game.net)
    _refresh(game)
    assert(not pickup.visible and not hud.rare_item_label.visible and hud.shortcut_label.visible)
    assert(hud.woodworks_guide_label.text.contains("AMBER"))

    var z := ROUTE.ENTRY_PORTAL_Z+21.0
    player.global_position = Vector3(game.track_center_at(z),game.height_at(z)+0.43,z)
    player.linear_velocity = Vector3(0,0,-23.0)
    game.race_moments.reset_round()
    game._update_camera(0.12,true)
    var marks: Array[Vector3] = [road.fork_mark_ahead(z,23.0,false),road.fork_mark_ahead(z,23.0,true)]
    var eye: Vector3 = game.camera.global_position
    for i in range(2):
        var mark := marks[i]
        assert(mark.is_finite())
        var rival: RigidBody3D = game.racers[i]
        rival.global_position = eye.lerp(mark,(mark.z+0.85-eye.z)/(mark.z-eye.z))
        rival.linear_velocity = player.linear_velocity
    game.race_moments.tick(0.12)
    _refresh(game)
    assert(locator.fork_main_center.is_finite() and locator.fork_bridge_center.is_finite())
    assert(locator.fork_main_center.x+32.0 < locator.fork_bridge_center.x)
    game.racers[0].global_position.x -= 2.8
    game.race_moments.tick(0.12)
    _refresh(game)
    assert(not locator.fork_main_center.is_finite() and locator.fork_bridge_center.is_finite(),
        "Leave visible main paint untouched when only the bridge is masked")

    player.global_position = road.point_at(-68.0)+Vector3.UP*0.58
    game.camera_shake = 0.0
    game.race_moments.tick(0.12)
    game._update_camera(0.12,true)
    _refresh(game)
    assert(hud.bridge_approach_active and not locator.fork_main_center.is_finite() and (
        not locator.fork_bridge_center.is_finite()))
    var bridge_lookahead: Vector3 = game.camera_lookahead
    var art: MeshInstance3D = game.opening_obstacle_art
    game.opening_obstacle_art = null
    game._update_camera(0.12,true)
    assert(bridge_lookahead.x > game.camera_lookahead.x+0.7)
    game.cam_mode = 1
    game._update_camera(0.12,true)
    var manual: Transform3D = game.camera.global_transform
    game.opening_obstacle_art = art
    game._update_camera(0.12,true)
    assert(game.camera.global_transform.is_equal_approx(manual))
    game.cam_mode = 0
