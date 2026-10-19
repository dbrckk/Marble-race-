extends SceneTree

func _initialize() -> void:
    call_deferred("_check")

func _count_nodes(node: Node) -> int:
    var count := 1
    for child in node.get_children():
        count += _count_nodes(child)
    return count

func _check() -> void:
    var race: Node3D = load("res://scenes/main.tscn").instantiate()
    root.add_child(race)
    await process_frame
    race.start_race("Aerodynamic")
    race.countdown = 0.01
    for i in range(50):
        await process_frame
    await RenderingServer.frame_post_draw
    var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    print("PERFORMANCE_SNAPSHOT: nodes=%d draw_calls=%d objects=%d primitives=%d physics_bodies=%d fps=%d" % [
        _count_nodes(race),calls,objects,primitives,
        int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),Engine.get_frames_per_second()])
    var image := root.get_viewport().get_texture().get_image()
    image.save_png("user://perf_v10.png")
    race.queue_free()
    await process_frame
    quit(0)
