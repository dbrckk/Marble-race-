extends SceneTree
## Visual regression reference for moving obstacles; run under xvfb on GLES.
func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.ui.root.visible = false
    game.camera.global_position = Vector3(8.8, 7.1, -4.0)
    game.camera.fov = 62.0
    game.camera.look_at(Vector3(0.0, game.height_at(-16.0) + 0.5, -16.0),Vector3.UP)
    for light in game.workshop_lamps:
        light.visible = absf(light.global_position.z + 16.0) < 25.0
    for i in range(10):
        await process_frame
    await RenderingServer.frame_post_draw
    var picture = root.get_viewport().get_texture().get_image()
    picture.save_png("user://detail-kinetic.png")
    print("DETAIL_CAPTURE_OK",picture.get_size())
    game.queue_free()
    await process_frame
    quit(0)
