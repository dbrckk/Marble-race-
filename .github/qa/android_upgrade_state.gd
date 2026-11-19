extends Node
# This autoload is added only to the two APKs built by the emulator workflow.
const FINISH_TIME := 45.25
const PERK := "Grip Tape"

func _ready() -> void:
    await get_tree().process_frame
    if get_tree().current_scene == null:
        await get_tree().scene_changed
    _run()

func _run() -> void:
    var game: Node3D = get_tree().current_scene
    var seed := OS.has_feature("android_upgrade_seed") or "--seed" in OS.get_cmdline_user_args()
    if seed:
        if not _seed(game):
            _finish("seed",false)
            return
        _finish("seed",true)
        return
    if OS.has_feature("android_upgrade_verify") or "--verify" in OS.get_cmdline_user_args():
        _finish("verify",_verify(game))

func _seed(game: Node3D) -> bool:
    if game.career.finishes != 0 or FileAccess.file_exists(game.best_ghost.save_path):
        push_error("The first APK requires fresh emulator app data")
        return false
    game.career.starts = 1
    var result: Dictionary = game.career.complete(0,1,FINISH_TIME,true)
    if not result.get("record",false) or not FileAccess.file_exists(game.career.save_path):
        push_error("Could not persist a first career result")
        return false
    game.best_ghost.begin(0,0,PERK,true)
    for i in range(452):
        var z := -float(i)*0.45
        game.best_ghost.tick(float(i)*0.101,
            Vector3(game.track_center_at(z),game.height_at(z)+0.39,z),0)
    if not game.best_ghost.finish(FINISH_TIME,true,PackedFloat64Array([10.0,21.0,33.0])):
        push_error("Could not persist a personal best ghost")
        return false
    game.set_graphics_quality(0)
    game.toggle_fps_overlay()
    game.ui._hand_pressed()
    return true

func _verify(game: Node3D) -> bool:
    if (game.career.finishes != 1 or game.career.victories != 1 or
            game.career.unlocked != 2 or game.career.track_best[0] != 1 or
            not is_equal_approx(game.career.track_time[0],FINISH_TIME)):
        push_error("Updated game did not load the saved career, unlock or personal best")
        return false
    game.best_ghost.begin(0,0,PERK,true)
    if (not game.best_ghost.replay_available or game.best_ghost.replay_samples.size() < 400 or
            not is_equal_approx(game.best_ghost.best_time,FINISH_TIME) or
            not is_equal_approx(game.best_ghost.crossing_delta(1,22.0),1.0)):
        push_error("Updated game did not load the ghost and its checkpoint data")
        return false
    if game.graphics_setting != 0 or not game.show_fps or not game.ui.touch_controls.left_handed:
        push_error("Updated game did not load the video and touch settings")
        return false
    return true

func _finish(phase: String, passed: bool) -> void:
    var proof := FileAccess.open("user://android-upgrade-%s.txt" % phase,FileAccess.WRITE)
    if proof == null:
        push_error("Could not write Android upgrade test result")
        get_tree().quit(1)
        return
    proof.store_string("pass" if passed else "fail")
    proof.close()
    print("ANDROID_UPGRADE_STATE_",phase.to_upper(),"_", "PASS" if passed else "FAIL")
    if not OS.has_feature("android"):
        get_tree().quit(0 if passed else 1)
