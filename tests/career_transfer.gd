extends SceneTree
## Android-safe career transfer: no uninstall or separate desktop needed.
## Includes existing medals, league progress, mastery and best sectors.
const Career = preload("res://scripts/career.gd")
const Transfer = preload("res://scripts/career_transfer.gd")
const EXPORT_PATH := "user://qa_portable_export.cfg"
const RESTORE_PATH := "user://qa_portable_restored.cfg"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for path in [EXPORT_PATH,RESTORE_PATH,RESTORE_PATH+".before_import"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var original = Career.new()
    original.save_path = EXPORT_PATH
    original.starts = 14
    original.finishes = 11
    original.victories = 2
    original.podiums = 4
    original.track_best[0] = 3
    original.track_time[0] = 57.22
    original.stars[0] = 3
    original.mastery_flags[0] = 7
    original.mastery_flags[1] = 3
    original.selected_style = 2
    original.sector_best[0] = 10.25
    original.sector_best[1] = 12.15
    original.league_points = 453
    original.league_runs[0] = 11
    original.league_clean_passes[0] = 7
    original.league_shortcuts[0] = 4
    var data: Dictionary = Transfer.export_career(original)
    assert(bool(data["ok"]),"Existing career must export without any user account")
    var code: String = str(data["code"])
    assert(code.begins_with("MARBLE-CAREER-V1."), "Portable code must be versioned")
    assert(code.length() < Transfer.MAX_CODE_LENGTH)
    var preview: Dictionary = Transfer.preview_code(code)
    assert(bool(preview["ok"]) and int(preview["starts"]) == 14)
    assert(int(preview["finishes"]) == 11 and int(preview["mastery"]) == 5)
    assert(int(preview["league"]) == 453)

    var corrupted: String = code.substr(0,20)+"0"+code.substr(21)
    assert(not bool(Transfer.preview_code(corrupted)["ok"]),
        "A modified checksum must never overwrite a real career")
    assert(not bool(Transfer.preview_code("garbage")["ok"]))
    assert(not bool(Transfer.preview_code("X".repeat(Transfer.MAX_CODE_LENGTH+1))["ok"]),
        "Huge clipboard inputs must be bounded")
    var fresh = Career.new()
    fresh.save_path = RESTORE_PATH
    fresh.starts = 3
    fresh.finishes = 2
    fresh.track_best[0] = 9
    assert(fresh.save() == OK)
    var response: Dictionary = Transfer.restore_career(fresh,code)
    assert(bool(response["ok"]),"Portable career code must restore safely")
    assert(fresh.starts == 14 and fresh.finishes == 11)
    assert(fresh.victories == 2 and fresh.podiums == 4)
    assert(fresh.mastery_count() == 5 and fresh.selected_style == 2)
    assert(fresh.league_points == 453 and fresh.league_clean_passes[0] == 7)
    assert(fresh.sector_best[1] == 12.15 and fresh.track_best[0] == 3)
    var old = Career.new()
    old.save_path = RESTORE_PATH+".before_import"
    old.load_save()
    assert(old.starts == 3 and old.finishes == 2 and old.track_best[0] == 9,
        "Import must preserve one rollback copy of the preceding save")
    var after_restart = Career.new()
    after_restart.save_path = RESTORE_PATH
    after_restart.load_save()
    assert(after_restart.track_best == fresh.track_best and
        after_restart.mastery_flags == fresh.mastery_flags and
        after_restart.league_points == fresh.league_points,
        "Restored progress must survive a full game restart")
    # Invalid-but-checksummed config is still rejected before any disk write.
    var impossible := ConfigFile.new()
    impossible.set_value("career","starts",1)
    impossible.set_value("career","finishes",15)
    impossible.set_value("career","victories",0)
    impossible.set_value("career","podiums",0)
    var raw: String = impossible.encode_to_text()
    var forged: String = "MARBLE-CAREER-V1.%s.%s" % [
        raw.sha256_text(),Marshalls.utf8_to_base64(raw)]
    assert(not bool(Transfer.preview_code(forged)["ok"]),
        "Checksum alone must not validate impossible career statistics")
    assert(not bool(Transfer.restore_career(fresh,forged)["ok"]))
    assert(fresh.starts == 14, "Invalid import must leave live career unchanged")

    # Full Android-style visual UI: preview -> confirm -> refresh the menu;
    # clipboard actions are intentionally skipped in headless CI.
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = RESTORE_PATH
    game.career.starts = 1
    game.career.finishes = 0
    assert(game.career.save() == OK)
    game.ui.show_backup_dialog()
    assert(game.ui.backup_layer.visible and not game.ui.menu_layer.visible)
    assert(game.ui.backup_confirm_button.disabled,
        "A backup must be previewed before the destructive restore button enables")
    game.ui.backup_input.text = "not-a-career"
    game.ui._check_backup_code()
    assert(game.ui.backup_confirm_button.disabled,
        "Corrupted manual paste cannot enable restore")
    game.ui.backup_input.text = code
    game.ui._check_backup_code()
    assert(not game.ui.backup_confirm_button.disabled)
    assert(game.ui.backup_status.text.contains("14 RACES"),
        "Display backup provenance before user explicitly confirms overwrite")
    game.ui._confirm_restore_backup()
    assert(game.ui.backup_confirm_button.disabled)
    assert(game.career.starts == 14 and game.career.league_points == 453)
    game.ui.show_menu()
    assert(game.ui.menu_layer.visible and not game.ui.backup_layer.visible,
        "Career transfer must return to native Android menu")
    game.queue_free()
    for i in range(3):
        await process_frame
    for path in [EXPORT_PATH,RESTORE_PATH,RESTORE_PATH+".before_import"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("CAREER_TRANSFER_PASS: integrity, legacy data, atomic restore, Android UI and rollback")
    quit(0)
