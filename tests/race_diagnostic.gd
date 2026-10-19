extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
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
                "active",active,"avg_speed",speed/40.0,"avg_z",forward/40.0,
                "player",stage.player.global_position,"player_speed",stage.player.linear_velocity.length())
    assert(stage.racer_finish_order.size() >= 8, "Course should have finishers after 110 seconds")
    assert(stage.player.finished,
        "Unsteered player must finish: a wedged marble breaks the race loop")
    stage.queue_free()
    for n in range(4):
        await process_frame
    print("RACE_DIAGNOSTIC_PASS")
    quit(0)
