extends SceneTree
## Four-sector race timing, persistence and anti-skip regression.
const Career = preload("res://scripts/career.gd")
func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var c := Career.new()
    c.save_path = "user://test_splits_v14.cfg"
    c.sector_best.fill(0.0)
    assert(c.record_sectors(0,[20.0,25.0,30.0,15.0]) == [true,true,true,true])
    assert(c.best_sector(0,0) == 20.0 and c.best_sector(1,0) == 0.0)
    assert(c.record_sectors(0,[22.0,24.0,30.0,17.0]) == [false,true,false,false])
    assert(c.record_sectors(0,[0.0,3.0,4.0,5.0]) == [false,false,false,false])
    assert(c.record_sectors(0,[NAN,2.0,3.0,4.0]) == [false,false,false,false])
    assert(c.record_sectors(0,[1.0,2.0,3.0]) == [false,false,false,false])
    assert(c.record_sectors(4,[5.0,5.0,5.0,5.0]) == [false,false,false,false])
    assert(c.record_sectors(2,[30.0,33.0,35.0,40.0]) == [true,true,true,true])
    var restored := Career.new()
    restored.save_path = c.save_path
    restored.load_save()
    assert(restored.best_sector(0,1) == 24.0 and restored.best_sector(2,3) == 40.0)
    assert(restored.best_sector(1,0) == 0.0)

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_live_splits_v14.cfg"
    game.career.sector_best.fill(0.0)
    game.start_race("Grip Tape")
    game.countdown = 0.01
    await process_frame
    for marble in game.racers:
        marble.freeze = true
    assert(game.race_state == "RACING")
    var z_targets := [-47.0,-107.0,-167.0]
    var times := [20.0,45.0,79.0]
    for k in range(3):
        var z: float = z_targets[k]
        game.player.position = Vector3(0.0,game.height_at(z)+0.65,z)
        game.race_time = times[k]
        game._process(0.016)
        assert(game.checkpoint_splits.size() == k+1,"Sector not captured")
        assert(game.last_checkpoint == k,"Sector number incorrect")
        assert(game.ui.checkpoint_label.text.contains("SECTOR %d" % (k+1)))
    game.player.finished = true
    game.player.finish_time = 98.0
    game._end_race()
    var result: Dictionary = game.last_result
    assert(result.get("sector_times",[]).size() == 4)
    assert(result.get("sector_records",[]) == [true,true,true,true])
    var splits: Array = result["sector_times"]
    assert(absf(float(splits[3])-19.0) < 0.05,"Finish sector must use actual finish time")
    assert(game.career.best_sector(0,3) > 18.9)
    var summary = game.ui.results_layer.find_child("Summary",true,false) as Label
    assert(summary.text.contains("SECTORS 1"),"Results screen missing split summary")

    var first_best: float = game.career.best_sector(0,0)
    game.return_to_menu()
    game.start_race("Grip Tape")
    game.countdown = 0.01
    await process_frame
    for marble in game.racers:
        marble.freeze = true
    # Jump over checkpoints; must not fabricate impossibly fast split PBs.
    game.player.position = Vector3(0.0,game.height_at(-168.0)+0.65,-168.0)
    game.race_time = 49.0
    game._process(0.016)
    assert(game.checkpoint_splits.is_empty(),"Skipped checkpoints must invalidate splits")
    game._end_race()
    assert(game.career.best_sector(0,0) == first_best,"DNF must retain previous record")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.career.save_path))
    print("SECTOR_TIMING_PASS: 4 timed sectors, finish split, PB persistence, skip/DNF protection")
    game.queue_free()
    for k in range(4):
        await process_frame
    quit(0)
