extends SceneTree
## v1.20 real moving barriers and earned near-miss rewards.
const Director = preload("res://scripts/race_director.gd")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_race_director_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    for course in range(3):
        assert(game.set_track(course))
        var director: Node3D = game.race_director
        assert(director == game.board.get_node("ReactiveRaceDirector"),
            "Timed course events must be part of the live world")
        assert(director.biome == course)
        assert(director.obstacles.size() == 3 and
            director.warning_rings.size() == 3 and director.signs.size() == 3,
            "Three distinctly timed obstacles and visible telegraphs per race")
        for i in range(3):
            var body: AnimatableBody3D = director.obstacles[i]
            assert(body.sync_to_physics, "Moving walls must use real physics sync")
            var collider := body.get_node_or_null("ActiveObstacleCollider") as CollisionShape3D
            assert(is_instance_valid(collider) and collider.shape is BoxShape3D,
                "Timed obstacles must have nonzero physical collision geometry")
            var shape := collider.shape as BoxShape3D
            assert(shape.size.x > 1.5 and shape.size.x < 2.2)
            assert(absf(body.position.x-game.track_center_at(body.position.z)) <= 5.2,
                "Hazard must remain inside the driveable corridor")
            assert(body.position.z == Director.EVENT_Z[i],
                "Hazard location must follow deterministic section seam")
            assert(director.signs[i] is Label3D,
                "Obstacles must give enough readable warning on Android")
        var notice: Dictionary = director.event_ahead(Director.EVENT_Z[0]+18.0)
        assert(not notice.is_empty() and int(notice["distance"]) == 18,
            "Race director should warn in advance of a real hazard")
        assert(game.upcoming_hazard(Director.EVENT_Z[0]+11.0).has("side"),
            "The existing HUD lookahead must include dynamic gates")
        director.animate(0.35)
        if course < 2:
            var pos_before: Vector3 = director.obstacles[0].position
            director.animate(2.65)
            var pos_after: Vector3 = director.obstacles[0].position
            assert(absf(pos_before.x-pos_after.x) >= 0.5,
                "Mechanical and icy sweepers must visibly move inside the lane")
            assert(absf(pos_before.y-pos_after.y) < 0.01,
                "Sweeping arms should not tunnel vertically through marbles")
        else:
            assert(not director.piston_up(0,0.0),
                "Pistons must start buried to telegraph their movement")
            assert(director.piston_up(0,1.0),
                "Forge piston needs a true active collision phase")
            var low_y: float = director.position_at(0,0.0).y
            var high_y: float = director.position_at(0,1.0).y
            assert(high_y-low_y > 1.1,
                "Forge pistons must rise physically rather than playing a fake animation")
            assert(not director.piston_up(0,3.0),
                "Forge pistons must also retract for safe passage")
        game.start_race("Grip Tape")
        game.race_state = "RACING"
        director = game.race_director
        var player: RigidBody3D = game.player
        var bot: RigidBody3D = game.racers[0]
        player.freeze = false
        bot.freeze = false
        director.animate(1.0)
        var position_now: Vector3 = director.obstacles[0].global_position
        player.global_position = position_now+Vector3(1.75,0.75,-1.0)
        bot.global_position = position_now+Vector3(-1.71,0.65,-1.2)
        player.linear_velocity = Vector3(0,0,-9)
        bot.linear_velocity = Vector3(0,0,-8)
        # Only the offline authority may issue the skill reward.
        game.net.role = "client"
        game.net.match_running = true
        director.tick(game.racers,game.net)
        assert(director.awarded.is_empty(),"Client cannot forge physics rewards")
        game.net.role = "offline"
        game.net.match_running = false
        director.tick(game.racers,game.net)
        assert(director.awarded.has("0:39") and director.awarded.has("0:0"),
            "Human and AI earn a genuine close pass with identical physics")
        assert(game.ui.toast_remaining > 0,
            "Human clean passing requires immediate feedback")
        var count: int = director.awarded.size()
        director.tick(game.racers,game.net)
        assert(director.awarded.size() == count,
            "Remaining beside a moving wall must not farm near misses")
        director.reset_round()
        assert(director.awarded.is_empty(),"Rematches restore earned event eligibility")
        director.animate(1.0)
        player.global_position = director.obstacles[0].global_position+Vector3(0,0.75,-1.0)
        player.linear_velocity = Vector3(0,0,-9)
        director.tick(game.racers,game.net)
        assert(not director.awarded.has("0:39"),
            "Direct hit at the middle of an obstacle is not a clean pass")
        player.global_position = director.obstacles[0].global_position+Vector3(1.75,0.75,-1.0)
        player.linear_velocity = Vector3(0,0,1.5)
        director.tick(game.racers,game.net)
        assert(not director.awarded.has("0:39"),
            "Backward movement cannot farm the proximity reward")
        # Same notification path for authenticated remote human users.
        game.net.role = "client"
        game.net.match_running = true
        game.net._course_event_notice("near_miss")
        assert(game.ui.toast_remaining > 0.0,
            "Online clean pass must have reliable SFX/HUD")
        game.net.role = "offline"
        game.net.match_running = false
        game.return_to_menu()
    print("RACE_DIRECTOR_PASS: 3 timed physical obstacles/course, authority, near-miss and telegraph")
    game.queue_free()
    await process_frame
    quit()
