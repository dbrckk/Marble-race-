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
        human.global_position = pickup.global_position
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.size() == 1,"Local human must instantly collect")
        assert(not pickup.visible,"Collected solo pickup must disappear")
        assert(game.ui.toast_remaining > 0.0,"Local pickup must show clear feedback")
        game.race_items.tick(0.016,game.racers,game.net)
        assert(game.race_items.used.size() == 1,"Pickup must be single-use per human")
        # Emulate the authenticated dedicated-server slot: AI cannot collect,
        # accepted remote-controlled human can. Never trust a client-side flag.
        game.net.role = "server"
        game.net.joined_slots = {2:39}
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
        game.net._rare_item_notice(1,"spring")
        assert(not game.race_items.items[1].visible,
            "Online recipient must see its already-claimed pickup disappear")
        assert(game.ui.toast_remaining > 0.0,
            "Online recipient must see instant item feedback")
        game.net.match_running = false
        game.net.role = "offline"
        game.net.joined_slots.clear()
        game.return_to_menu()
    print("ARCADE_ITEMS_AND_WORLDS_PASS:")
    game.queue_free()
    await process_frame
    quit()
