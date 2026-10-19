extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var stage = load("res://scenes/main.tscn").instantiate()
    root.add_child(stage)
    for i in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    var img = root.get_viewport().get_texture().get_image()
    img.save_png("user://marble-menu.png")
    stage.start_race("Aerodynamic")
    stage.countdown = 0.01
    for i in range(120):
        await process_frame
    await RenderingServer.frame_post_draw
    var img2 = root.get_viewport().get_texture().get_image()
    img2.save_png("user://marble-race.png")
    stage.queue_free()
    await process_frame
    print("VISUAL_CAPTURE_OK", img.get_size(), img2.get_size())
    quit(0)
