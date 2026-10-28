extends SceneTree
## Four physical banked-apex rewards across nine real course builds.
## Only the actual bank collider can grant the small impulse; both AI and
## human marbles use the exact same server-owned physics and no GPU readback.
const SCULPT = preload("res://scripts/course_sculptures.gd")
const RACER = preload("res://scripts/marble.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    assert(not SCULPT.valid_apex_contact(16.0,1.6,0.0),
        "A marble flying above the raised deck is not an apex contact")
    assert(not SCULPT.valid_apex_contact(16.0,0.39,2.6),
        "Skipping the real bank lane cannot earn the reward")
    assert(not SCULPT.valid_apex_contact(1.0,0.39,0.0))
    assert(not SCULPT.valid_apex_contact(NAN,0.39,0.0))
    assert(SCULPT.valid_apex_contact(12.0,RACER.RADIUS,0.0))

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_authoritative_apex.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var verified := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.racers.size() == 40 and game.built_variation == layout)
            var feature: Node3D = game.course_sculptures
            var human: RigidBody3D = game.player
            var ai: RigidBody3D = game.racers[0]
            human.freeze = false
            ai.freeze = false
            var latest_apex_contact := Vector3.ZERO
            for i in range(4):
                var bank: StaticBody3D = feature.banks[i*2]
                assert(bank.collision_layer & SCULPT.BANK_PROBE_LAYER != 0,
                    "Apex must remain distinguishable from regular road physics")
                assert(bank.collision_layer & 1 != 0,
                    "Apex still has the original marble contact channel")
                var z: float = bank.global_position.z
                var x: float = bank.global_position.x
                var hit_origin := Vector3(x,bank.global_position.y+0.7,z)
                var ray := PhysicsRayQueryParameters3D.create(
                    hit_origin,hit_origin+Vector3.DOWN*1.3,
                    SCULPT.BANK_PROBE_LAYER)
                await physics_frame
                var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
                assert(hit.get("collider") == bank,
                    "The actual bank physics surface must be queryable on a dedicated mask")
                var surface: Vector3 = hit["position"]
                # Position the real marble one RADIUS above the actual
                # measured physics surface (not an invented visual height).
                var contact := Vector3(x,surface.y+RACER.RADIUS,z)
                latest_apex_contact = contact
                human.global_position = contact
                human.linear_velocity = Vector3(0.0,0.0,-14.0)
                var before_velocity: Vector3 = human.linear_velocity
                var before_position: Vector3 = human.global_position
                var count: int = feature.apex_pass_count(human.racer_id)
                # A remote client copy must NEVER apply any local boosts.
                game.net.role = "client"
                game.net.match_running = true
                feature.tick(game.racers,game.net)
                assert(feature.apex_pass_count(human.racer_id) == count and
                    human.linear_velocity.is_equal_approx(before_velocity),
                    "Client-replicated position cannot counterfeit apex speed")
                game.net.role = "offline"
                game.net.match_running = false
                # Wide/slow/airborne approaches all fail, even inside Z band.
                human.global_position.x += 2.8
                feature.tick(game.racers,game.net)
                assert(feature.apex_pass_count(human.racer_id) == count)
                human.global_position = contact+Vector3(0.0,2.0,0.0)
                feature.tick(game.racers,game.net)
                assert(feature.apex_pass_count(human.racer_id) == count)
                human.global_position = contact
                human.linear_velocity = Vector3(0.0,0.0,-2.0)
                feature.tick(game.racers,game.net)
                assert(feature.apex_pass_count(human.racer_id) == count)
                human.linear_velocity = before_velocity
                feature.tick(game.racers,game.net)
                assert(feature.apex_pass_count(human.racer_id) == count+1,
                    "Only true high-speed contact earns a banked skill boost")
                assert(feature.last_ray_queries <= 2,
                    "The Android physics detector needs only nearby bank rays")
                assert(human.global_position.is_equal_approx(before_position),
                    "A physics reward may apply an impulse, never teleport")
                assert(feature.apex_flash[i] > 0.0 and
                    game.ui.checkpoint_label.text.contains("BANKED APEX"),
                    "An earned human apex needs immediate visual and audio cues")
                var previous: int = feature.validated_apex_hits
                feature.tick(game.racers,game.net)
                assert(feature.validated_apex_hits == previous,
                    "Staying on the same bank must never farm repeated rewards")
                feature.advance_visuals(0.10)
                assert(feature.apex_flash[i] < SCULPT.APEX_FLASH_SECONDS,
                    "The already-batched mobile crest glow must fade with time")
                verified += 1
            assert(feature.apex_pass_count(human.racer_id) == 4)
            # AI receives the exact same physics reward when it genuinely
            # touches a bank; steering and monetization cannot change this.
            var ai_bank: StaticBody3D = feature.banks[0]
            var query_start := ai_bank.global_position+Vector3.UP*0.7
            var query := PhysicsRayQueryParameters3D.create(
                query_start,query_start+Vector3.DOWN*1.3,
                SCULPT.BANK_PROBE_LAYER)
            var result: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
            assert(result.get("collider") == ai_bank)
            ai.global_position = Vector3(
                ai_bank.global_position.x,
                (result["position"] as Vector3).y+RACER.RADIUS,
                ai_bank.global_position.z)
            ai.linear_velocity = Vector3(0.0,0.0,-14.0)
            feature.tick(game.racers,game.net)
            assert(feature.apex_pass_count(ai.racer_id) == 1,
                "The physical reward must be fair for human and AI racers")
            var saved_velocity: Vector3 = ai.linear_velocity
            feature.reset_round()
            assert(feature.apex_pass_count(human.racer_id) == 0 and
                feature.apex_pass_count(ai.racer_id) == 0 and
                feature.validated_apex_hits == 0,
                "Rematches reset every bank skill, glow and anti-farming state")
            # Server notification is presentation only on a remote client.
            game.net.role = "client"
            game.net.match_running = true
            human.global_position = latest_apex_contact
            var frozen_velocity: Vector3 = human.linear_velocity
            game.net._course_event_notice("apex")
            assert(human.linear_velocity.is_equal_approx(frozen_velocity) and
                feature.apex_pass_count(human.racer_id) == 0,
                "Signed online callout must never apply an impulse on client")
            game.net.role = "offline"
            game.net.match_running = false
            game.return_to_menu()
    assert(verified == 36,
        "Each of four physically raised banks needs testing on nine layouts")
    game.queue_free()
    for n in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_authoritative_apex.cfg"))
    print("APEX_REWARDS_PASS: 36 physically probed bank rewards, 9 layouts, AI fairness, zero client impulses and mobile glow")
    quit(0)
