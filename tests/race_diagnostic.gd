extends SceneTree
const RACER = preload("res://scripts/marble.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(RACER.recovery_side(4.30,0) < 0.0,
        "First recovery should try the closest inward open line")
    assert(RACER.recovery_side(4.30,1) > 0.0,
        "Repeated failure must try the other side of the same slalom")
    assert(RACER.recovery_side(-4.30,1) < 0.0,
        "Alternate recovery must be symmetric on the other side")
    assert(RACER.recovery_side(6.15,1) < 0.0,
        "Never nudge a stranded marble outward through the physical rail")
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.start_race("Grip Tape")
    stage.countdown = 0.01
    for i in range(6600):
        await physics_frame
        if i%600==599:
            var active = 0
            var speed=0.0
            var forward=0.0
            for m in stage.racers:
                speed+=m.linear_velocity.length()
                forward+=m.global_position.z
                if not m.finished and not m.eliminated:
                    active+=1
            print("RACE_DIAGNOSTIC",i+1, "time",stage.race_time,"finished",stage.racer_finish_order.size(),
                "active",active,"avg_speed",speed/float(stage.MARBLE_COUNT),"avg_z",forward/float(stage.MARBLE_COUNT),
                "player",stage.player.global_position,"player_speed",stage.player.linear_velocity.length())
    assert(stage.racer_finish_order.size() >= 8, "Course should have finishers after 110 seconds")
    assert(stage.player.finished,
        "Unsteered player must finish: a wedged marble breaks the race loop")
    stage.return_to_menu()
    stage.career.unlocked = 3
    assert(stage.set_track(2))
    assert(await _clears_forge_wedge(stage),
        "A persistent Forge slalom and baffle wedge must release without teleporting")
    stage.queue_free()
    for n in range(4):
        await process_frame
    print("RACE_DIAGNOSTIC_PASS")
    quit(0)

func _clears_forge_wedge(stage: Node3D) -> bool:
    stage.start_race("Grip Tape")
    stage.countdown = 0.01
    for frame in range(8):
        await physics_frame
    for marble in stage.racers:
        if marble != stage.player:
            marble.freeze = true
    var player: RigidBody3D = stage.player
    # Reproduced at the contact point of SlalomBlock_11_03 and
    # AntiEdgeBaffle_11_R during the full Forge race.
    player.global_position = Vector3(2.91925,-11.020,-126.6997)
    player.linear_velocity = Vector3.ZERO
    player.angular_velocity = Vector3.ZERO
    var retried := false
    for frame in range(1350):
        await physics_frame
        retried = retried or player.recovery_count >= 5
        if player.position.z < -128.0:
            return retried and not player.eliminated
    return false
