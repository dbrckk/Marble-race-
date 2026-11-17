extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage=load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    await process_frame
    stage.career.save_path="user://opening-trace-qa.cfg"
    stage.show_fps=false
    stage.audio.enabled=false
    stage.race_variation=0
    stage.set_graphics_quality(1)
    seed(48042)
    stage.start_race("Grip Tape")
    var art: MeshInstance3D=stage.board.find_child("OpeningObstacleArt",true,false)
    var output:=FileAccess.open("user://opening-trace.bin",FileAccess.WRITE)
    var frames := 0
    for i in range(480):
        await process_frame
        var z: float=stage.player.global_position.z
        var phase := -1
        if stage.race_state=="COUNTDOWN" and stage.countdown<=1.15:
            phase=0
        elif stage.race_state=="RACING":
            phase=2 if absf(z-art.entry_z)<=4.0 else (1 if stage.race_time<=0.60 else 3)
            if z<art.entry_z-4.0:
                break
        if phase<0 or i%2!=0:
            continue
        output.store_float(float(phase))
        output.store_float(stage.race_time if phase>0 else -stage.countdown)
        output.store_float(stage.steer)
        var transform: Transform3D = stage.camera.global_transform
        var q := transform.basis.get_rotation_quaternion()
        var origin := transform.origin
        for v in [origin.x,origin.y,origin.z,q.x,q.y,q.z,q.w,stage.camera.fov]:
            output.store_float(v)
        for marble in stage.racers:
            transform=marble.global_transform
            q=transform.basis.get_rotation_quaternion()
            origin=transform.origin
            var v: Vector3 = marble.linear_velocity
            for data in [origin.x,origin.y,origin.z,q.x,q.y,q.z,q.w,v.x,v.y,v.z]:
                output.store_float(data)
        frames+=1
    output.flush()
    print("TRACE_PASS ",frames," bytes ",output.get_position())
    assert(frames>=65 and output.get_position()==frames*411*4)
    quit()
