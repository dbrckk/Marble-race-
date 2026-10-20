extends SceneTree
const GHOST = preload("res://scripts/best_ghost.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var node = GHOST.new()
    root.add_child(node)
    await process_frame
    # Use a uniquely named "perk" so the test does not mutate an actual player's best.
    var perk := "QA_LOCAL_GHOST_%s" % "marble"
    var identifier := node.storage_key(2,2,perk)
    assert(identifier == node.storage_key(2,2,perk))
    assert(identifier != node.storage_key(2,1,perk))
    assert(identifier != node.storage_key(1,2,perk))
    assert(identifier != node.storage_key(2,2,"Other"),"Ghost must respect perk")
    var file := ConfigFile.new()
    file.load(node.SAVE_PATH)
    if file.has_section(identifier):
        file.erase_section(identifier)
        file.save(node.SAVE_PATH)
    node.begin(2,2,perk,true)
    assert(not node.replay_available,"Fresh course has no ghost")
    for i in range(85):
        node.tick(float(i)*0.1,Vector3(0.0,1.0,-float(i)*1.5),1)
    assert(not node.visible and node.recording.size() >= 80)
    assert(not node.finish(8.4,false),"DNF must never write a ghost")
    assert(node.finish(8.4,true),"Valid finish should save a ghost")
    assert(not node.finish(9.0,true),"Slower time should not overwrite a record")
    node.begin(2,2,perk,true)
    assert(node.replay_available and is_equal_approx(node.best_time,8.4))
    node.tick(2.0,Vector3(0,1,-31),1)
    assert(node.visible,"Ghost mesh should be visible on balanced graphics")
    assert(node.gap_text(Vector3(0,1,-35)).contains("YOU AHEAD"))
    node.tick(3.0,Vector3(0,1,-40),0)
    assert(not node.visible,"Economy mode must avoid drawing the ghost")
    node.begin(2,1,perk,true)
    assert(not node.replay_available,"Different variation must never share ghost")
    node.begin(2,2,perk,false)
    assert(not node.replay_available and not node.visible,"Online mode has no ghost")
    # The test must clean only its isolated data, not actual player records.
    file.load(node.SAVE_PATH)
    if file.has_section(identifier):
        file.erase_section(identifier)
        file.save(node.SAVE_PATH)
    print("PERSONAL_GHOST_PASS: record/save/load, DNF, best-only, perk/layout isolation, mobile quality, online safety")
    node.queue_free()
    for i in range(3):
        await process_frame
    quit(0)
