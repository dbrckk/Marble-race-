extends SceneTree
## Real-scene regression for visually identical but dramatically cheaper
## workshop rail bracing, flag staffs and race plates on Android.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var dressing: Node3D = game.board.get_node_or_null(
        "ModularBrassAndSilkDressing")
    assert(is_instance_valid(dressing),"Course dressing is missing")
    assert(dressing.static_boxes.size() == 44,
        "Keep all 36 structural boxes, 6 flag staffs and 2 start/finish plates")
    assert(dressing.static_batch_instance_count() == 44,
        "All original decorative boxes must remain present in GPU batches")
    assert(dressing.static_batches.size() <= 12 and (
        dressing.static_batches.size() < dressing.static_boxes.size()/3),
        "Static dressing needs far fewer draw objects than legacy ornaments")
    for batch in dressing.static_batches:
        assert(batch is MultiMeshInstance3D and batch.multimesh != null,
            "Batches must be GPU-instanced rather than separate MeshInstance3D nodes")
        assert(batch.multimesh.instance_count > 0)
        assert(batch.material_override != null,
            "Per-material render groups must retain original brass/wood paint")
        assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
            "Decoration cannot create expensive per-item shadow maps")
    for box in dressing.static_boxes:
        var position: Vector3 = box["position"]
        var dimensions: Vector3 = box["size"]
        assert(dimensions.x > 0.0 and dimensions.y > 0.0 and dimensions.z > 0.0)
        assert(position.is_finite(),"Every original dressing position must remain finite")
    # Decoration is intentionally absent in Economy and returns in Balanced.
    # Ramps, guards and marble physics remain independent from its visibility.
    game.set_graphics_quality(0)
    assert(not dressing.visible,"Economy must cull decorative instances")
    game.set_graphics_quality(1)
    assert(dressing.visible,"Balanced must keep the full decorative presentation")
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40,
        "Static decoration optimization may not drop any physical racers")
    assert(dressing.static_batch_instance_count() == 44)
    game.return_to_menu()
    game.queue_free()
    for i in range(3):
        await process_frame
    print("STATIC_DRESSING_BATCH_PASS: 44 identical pieces, material batches, culling, graphics presets, 40 racers")
    quit(0)
