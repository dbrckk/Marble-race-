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
    print("WOODWORKS_OPENING_PASS: untimed controls, brief boost, real and skipped pickup, both routes, persistence, replay, network parity")
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
