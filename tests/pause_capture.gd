extends SceneTree
func _initialize() -> void:
    call_deferred("_capture")
func _capture() -> void:
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    for n in range(12):
        await process_frame
    stage.start_race("Grip Tape")
    stage.countdown = 0.01
    for n in range(55):
        await process_frame
    stage.ui.pause_race()
    for n in range(8):
        await process_frame
    await RenderingServer.frame_post_draw
    var shot = root.get_viewport().get_texture().get_image()
    var status = shot.save_png("user://marble-pause-v15.png")
    print("PAUSE_CAPTURE_OK ",shot.get_size()," status=",status)
    stage.ui.resume_race()
    stage.queue_free()
    for n in range(3):
        await process_frame
    quit(0)
