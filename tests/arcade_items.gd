extends SceneTree
## End-to-end scene regression for human-only arcade pickups and themed courses.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_arcade_items.cfg"
    game.career.unlocked = 3
    for track in range(3):
        assert(game.set_track(track),"Course selection must succeed")
        assert(game.race_items.items.size() == 4,"Each race needs exactly four sparse pickups")
        assert(game.board.get_node_or_null("World_"+[
            "WOODLAND_WORKSHOP","GLACIER_PASS","EMBER_FORGE"][track]) != null,
            "A distinct biome must be instanced for every course")
        var crest_count := 0
        for section in game.board.get_children():
            for child in section.get_children():
                if child.name.begins_with("RideableCrest_"):
                    crest_count += 1
        assert(crest_count == (1 if track == 0 else 3),
            "Each track must have a distinct physical relief budget")
        game.start_race("Grip Tape")
        game.race_items.reset_round()
        var pickup: Node3D = game.race_items.items[0]
        var ai: RigidBody3D = game.racers[0]
        var human: RigidBody3D = game.player
        ai.global_position = pickup.global_position
        human.global_position = Vector3(0.0,game.height_at(10.0)+0.7,10.0)
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.is_empty(),"AI may not collect rare items")
        assert(game.race_items.activation_remaining == 0.0 and not game.race_items.pulse_ring.visible)
        human.global_position = pickup.global_position
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.size() == 1,"Local human must instantly collect")
        assert(not pickup.visible,"Collected solo pickup must disappear")
        assert(game.ui.toast_remaining > 0.0,"Local pickup must show clear feedback")
        var local_kind: String = game.race_items.kind_at(0,track)
        if local_kind != "pulse":
            var visual: MeshInstance3D = game.race_items.activation_mesh
            assert(visual.visible and game.race_items.activation_kind == local_kind and (
                visual.mesh.get_surface_count() == 1 and visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
            var origin := visual.global_position
            human.global_position += Vector3(0.45,0.0,-4.0)
            game.race_items._process(0.10)
            if local_kind == "turbo":
                assert(visual.global_position.distance_to(human.global_position) < 0.2)
            else:
                assert(visual.global_position.y > origin.y+0.2 and is_equal_approx(visual.global_position.z,origin.z))
            game.set_graphics_quality(0)
            assert(not visual.visible)
            game.set_graphics_quality(1)
            assert(visual.visible)
            game.race_items._process(game.race_items.ACTIVATION_DURATION)
            assert(not visual.visible)
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.size() == 1,"Pickup must be single-use per human")
        # Emulate the authenticated dedicated-server slot: AI cannot collect,
        # accepted remote-controlled human can. Never trust a client-side flag.
        game.net.role = "server"
        game.net.joined_slots = {2:human.racer_id}
        human.network_controlled = true
        game.race_items.reset_round()
        assert(game.race_items.used.is_empty())
        ai.global_position = game.race_items.items[1].global_position
        human.global_position = Vector3(0,game.height_at(10)+1,10)
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.is_empty(),"Dedicated server must reject AI collection")
        human.global_position = game.race_items.items[1].global_position
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.size() == 1,"Dedicated server must apply human pickup")
        assert(game.race_items.items[1].visible,
            "Online items remain claimable independently by other human peers")
        # A server-authored notification hides only the client's own pickup
        # and surfaces audio/HUD confirmation without running client physics.
        game.net.role = "client"
        game.net.match_running = true
        game.race_state = "RACING"
        game.race_items.reset_round()
        var effect: String = game.race_items.kind_at(1,track)
        game.net._rare_item_notice(1,"invalid")
        assert(game.race_items.items[1].visible)
        game.net._rare_item_notice(1,"pulse" if effect != "pulse" else "turbo")
        assert(game.race_items.items[1].visible)
        game.net._rare_item_notice(1,effect)
        assert(not game.race_items.items[1].visible,
            "Online recipient must see its already-claimed pickup disappear")
        assert(game.ui.toast_remaining > 0.0,
            "Online recipient must see instant item feedback")
        assert(game.race_items.pulse_remaining > 0.0 if effect == "pulse" else (
            game.race_items.activation_kind == effect and game.race_items.activation_mesh.visible))
        if effect == "stabilizer":
            human.global_position += Vector3(0.8,0.0,-4.0)
            game.set_graphics_quality(0)
            game.race_items._process(0.10)
            assert(game.race_items.active_speed_item() == 3 and not game.race_items.activation_mesh.visible)
            game.set_graphics_quality(1)
            assert(game.race_items.activation_mesh.global_position.distance_to(human.global_position) < 0.2)
        var sound_channel: int = game.audio.current_channel
        var effect_progress: float = game.race_items.pulse_remaining if effect == "pulse" else game.race_items.activation_remaining
        game.net._rare_item_notice(1,effect)
        assert(game.audio.current_channel == sound_channel)
        assert(effect_progress == (game.race_items.pulse_remaining if effect == "pulse" else game.race_items.activation_remaining))
        game.net.match_running = false
        game.net.role = "offline"
        game.net.joined_slots.clear()
        game.return_to_menu()
        assert(not game.race_items.activation_mesh.visible and not game.race_items.pulse_ring.visible)
        assert(game.race_items.active_speed_item() == -1)
    print("ARCADE_ITEMS_AND_WORLDS_PASS:")
    game.queue_free()
    await process_frame
    quit()
