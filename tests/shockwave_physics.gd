extends SceneTree
## True human-only rare Shockwave: falloff, no cross-deck hits, compact
## client/offline FX and deterministic 3x3 Android layout coverage.
const ITEMS = preload("res://scripts/race_items.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Pure 3D physics constraints first: a nearer rival takes the stronger
    # lateral push; a bridge competitor or distant marble is untouched.
    var close: Vector3 = ITEMS.pulse_impulse(Vector3(0.85,0.0,0.0))
    var medium: Vector3 = ITEMS.pulse_impulse(Vector3(2.15,0.0,0.0))
    var edge: Vector3 = ITEMS.pulse_impulse(Vector3(3.85,0.0,0.0))
    assert(close.x > medium.x and medium.x > edge.x and edge.x > 0.0,
        "A shockwave must decrease in physical strength with true distance")
    assert(close.y > medium.y and medium.y > edge.y)
    assert(ITEMS.pulse_impulse(Vector3(0.1,0.0,0.0)) == Vector3.ZERO,
        "Coincident bodies may not cause a divide-by-zero radial blast")
    assert(ITEMS.pulse_impulse(Vector3(ITEMS.PULSE_RANGE,0.0,0.0)) ==
        Vector3.ZERO,"Beyond the rendered ring is beyond the physics reach")
    assert(ITEMS.pulse_impulse(Vector3(0.8,3.0,0.0)) == Vector3.ZERO,
        "An elevated shortcut must not receive a shockwave through its floor")
    assert(ITEMS.pulse_impulse(Vector3(NAN,0.0,0.0)) == Vector3.ZERO,
        "Invalid replicated snapshots cannot corrupt physics")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_shockwave_physics.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var real_hits := 0
    for track in range(3):
        game.return_to_menu()
        assert(game.set_track(track))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout and game.racers.size() == 40)
            var items: Node3D = game.race_items
            assert(items.pulse_ring != null and items.pulse_ring.mesh is TorusMesh)
            assert(items.pulse_ring.get_child_count() == 0,
                "The wave uses one render node, not extra physics or particles")
            assert(items.pulse_ring.cast_shadow ==
                GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
            assert(items.confirmed_pulses == 0 and items.pulse_remaining == 0.0)
            var pulse_index := -1
            for index in range(ITEMS.ITEM_Z.size()):
                if ITEMS.kind_at(index,track) == "pulse":
                    pulse_index = index
            assert(pulse_index >= 0,
                "Each of the three worlds must carry a genuine rare shockwave")
            var powerup: Node3D = items.items[pulse_index]
            var human: RigidBody3D = game.player
            var near_ai: RigidBody3D = game.racers[0]
            var far_ai: RigidBody3D = game.racers[1]
            var bridge_ai: RigidBody3D = game.racers[2]
            for marble in game.racers:
                marble.freeze = true
            # Unfreeze targets after the countdown to observe real physics.
            # Position all other frozen rivals away from this deliberate event.
            var origin: Vector3 = powerup.global_position
            var inward: float = -signf(
                ITEMS.lane_offset(pulse_index,track,layout))
            human.global_position = origin
            near_ai.global_position = origin+Vector3(inward*1.30,0.0,0.0)
            far_ai.global_position = origin+Vector3(0.0,0.0,6.0)
            bridge_ai.global_position = origin+Vector3(inward*0.85,3.2,0.0)
            human.linear_velocity = Vector3.ZERO
            near_ai.linear_velocity = Vector3.ZERO
            far_ai.linear_velocity = Vector3.ZERO
            bridge_ai.linear_velocity = Vector3.ZERO
            human.freeze = false
            near_ai.freeze = false
            far_ai.freeze = false
            bridge_ai.freeze = false
            items.tick(1.0/60.0,game.racers,game.net)
            var key: String = "%d:%d" % [pulse_index,human.racer_id]
            assert(items.used.has(key) and not powerup.visible,
                "A human must collect the shockwave immediately on contact")
            assert(items.confirmed_pulses == 1 and items.pulse_remaining > 0.0,
                "Only a confirmed human pickup can start a local shockwave")
            assert(items.pulse_ring.visible == (game.graphics_quality > 0))
            assert(items.pulse_ring.material_override == items.pulse_material,
                "Effect has its own reusable unlit material")
            await physics_frame
            await physics_frame
            await physics_frame
            assert(near_ai.linear_velocity.x*inward > 0.20,
                "A near rival must receive an actual Godot outward impulse")
            assert(absf(far_ai.linear_velocity.x) < 0.07,
                "A competitor outside the real wave cannot be pushed sideways")
            assert(absf(bridge_ai.linear_velocity.x) < 0.07,
                "A raised-deck rival cannot be knocked through solid floors")
            real_hits += 1
            game.set_graphics_quality(0)
            assert(not items.pulse_ring.visible,
                "Economy must disable cosmetic wave rendering, never physics")
            game.set_graphics_quality(1)
            assert(items.pulse_ring.visible,
                "Restoring balanced while a wave is active shows the current effect")
            items._process(ITEMS.PULSE_VISUAL_DURATION)
            assert(items.pulse_remaining == 0.0 and not items.pulse_ring.visible,
                "One shockwave must finish cleanly with no endless GPU work")
            items.reset_round()
            assert(items.confirmed_pulses == 0 and items.used.is_empty(),
                "Replay must clear both reward state and the optional visual")
            # Dedicated-server client presentation is verified separately:
            # a replicated server event may show FX, never apply local forces.
            game.net.role = "client"
            game.net.match_running = true
            items.mark_local_pickup(pulse_index)
            assert(items.confirmed_pulses == 1 and
                not items.items[pulse_index].visible and items.pulse_ring.visible,
                "A server-confirmed remote pickup renders only its own FX")
            var vel_before: Vector3 = near_ai.linear_velocity
            items.tick(1.0/60.0,game.racers,game.net)
            assert(near_ai.linear_velocity.is_equal_approx(vel_before),
                "Client rendering cannot re-apply authoritative shockwave physics")
            game.net.role = "offline"
            game.net.match_running = false
            game.return_to_menu()
    assert(real_hits == 9)
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_shockwave_physics.cfg"))
    print("SHOCKWAVE_PHYSICS_PASS: 9 real human pickups, bounded falloff, same-deck hits, client FX, Android budget")
    quit(0)
