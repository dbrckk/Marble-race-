extends SceneTree
## Permanent 3x3 circuit skill badges. Only actual finished offline runs may
## record grades earned by physics on genuine synchronized moving hazards.
## Old save files and career transfer remain valid after adding medals.
const CAREER = preload("res://scripts/career.gd")
const SAVE := "user://qa_precision_medals.cfg"
const SCENE_SAVE := "user://qa_precision_scene.cfg"

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    var progress = CAREER.new()
    progress.save_path = SAVE
    assert(progress.precision_medal(0) == "UNRANKED")
    assert(progress.precision_medal(-1) == "UNRANKED")
    assert(progress.precision_best == [0,0,0])
    assert(int(progress.award_precision(0,3,false)["best"]) == 0)
    assert(int(progress.award_precision(-1,3,true)["best"]) == 0)
    assert(int(progress.award_precision(0,4,true)["best"]) == 0)
    assert(int(progress.award_precision(0,-1,true)["best"]) == 0)
    assert(progress.precision_total == 0,
        "DNF, invalid gate count or fake circuit cannot mint career badges")
    var bronze: Dictionary = progress.award_precision(0,1,true)
    assert(bronze["new_record"] and bronze["medal"] == "BRONZE")
    assert(progress.precision_total == 1 and
        progress.precision_best == [1,0,0])
    var silver: Dictionary = progress.award_precision(0,2,true)
    assert(silver["new_record"] and silver["medal"] == "SILVER")
    var bronze_repeat: Dictionary = progress.award_precision(0,1,true)
    assert(not bronze_repeat["new_record"] and
        progress.precision_best[0] == 2)
    var gold: Dictionary = progress.award_precision(0,3,true)
    assert(gold["new_record"] and gold["medal"] == "GOLD" and
        progress.precision_perfect_runs == 1)
    progress.award_precision(1,2,true)
    progress.award_precision(2,1,true)
    assert(progress.precision_best == [3,2,1] and
        progress.precision_total == 10)
    # Normal replay reputation is unchanged; every real precision gate
    # adds +6 purely cosmetic REP without buying rank or gameplay speed.
    var ordinary: Dictionary = progress.award_league(0,10,true,3,false)
    var skilled: Dictionary = progress.award_league(0,10,true,3,false,3)
    assert(int(skilled["earned"])-int(ordinary["earned"]) ==
        CAREER.PRECISION_REP_PER_GATE*3)
    assert(int(progress.award_league(0,10,true,3,false,500)["earned"]) ==
        int(skilled["earned"]),
        "Even a malformed caller cannot mint more than three gate bonuses")
    assert(int(progress.award_league(0,10,false,3,false,3)["earned"]) == 0)
    var restored = CAREER.new()
    restored.save_path = SAVE
    restored.load_save()
    assert(restored.precision_best == [3,2,1] and
        restored.precision_total == progress.precision_total and
        restored.precision_perfect_runs == 1,
        "Android restart preserves genuine gold/silver/bronze records")
    var legacy := ConfigFile.new()
    legacy.set_value("career","starts",2)
    legacy.set_value("career","finishes",1)
    legacy.set_value("career","best_0",9)
    assert(legacy.save(SCENE_SAVE) == OK)
    var old_save = CAREER.new()
    old_save.save_path = SCENE_SAVE
    old_save.load_save()
    assert(old_save.precision_best == [0,0,0] and old_save.unlocked == 2,
        "Existing players' progress must migrate without losing their old unlocks")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = SCENE_SAVE
    game.career.precision_best = [0,0,0]
    game.career.precision_total = 0
    game.career.precision_perfect_runs = 0
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    game.ui.show_menu()
    assert(game.ui.career_label.text.contains("PRECISION"),
        "The main menu must explain lifetime precision progress")
    game.ui.show_perks()
    assert(game.ui.mastery_label.text.contains("PRECISION MEDAL: UNRANKED"),
        "The real prerace screen must show the next mastery goal")
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = false
    game.race_director.awarded["0:39"] = true
    game.race_director.last_award_grade["0:39"] = 0.90
    game._end_race()
    assert(game.career.precision_best[0] == 0 and
        game.career.precision_total == 0,
        "A DNF never creates permanent records, even after a real gate pass")
    game.return_to_menu()
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 56.0
    game.race_time = 56.0
    game.race_director.awarded["0:39"] = true
    game.race_director.awarded["1:39"] = true
    game.race_director.awarded["2:39"] = true
    game.race_director.last_award_grade["0:39"] = 0.91
    game.race_director.last_award_grade["1:39"] = 0.83
    game.race_director.last_award_grade["2:39"] = 0.32
    var counted: int = game.race_director.precision_pass_count(39)
    assert(counted == 2,
        "Only real physically awarded gates above the threshold count")
    game._end_race()
    assert(game.last_result["precision_passes"] == 2 and
        game.last_result["precision_medal"] == "SILVER" and
        game.last_result["precision_new_record"])
    assert(game.career.precision_best == [2,0,0] and
        game.career.precision_total == 2)
    assert(int(game.last_result["league_earned"]) >= 12,
        "Completed precision passes grant earned solo-only league REP")
    var summary: Label = game.ui.results_layer.find_child(
        "Summary",true,false) as Label
    assert(summary.text.contains("PRECISION  2/3") and
        summary.text.contains("SILVER") and
        summary.text.contains("NEW MEDAL"),
        "The results screen must clearly explain a new persistent skill medal")
    game._end_race()
    assert(game.career.precision_total == 2,
        "Reopening results cannot grant a second medal or extra lifetime total")
    game.return_to_menu()
    game.net.role = "server"
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 43.0
    game.race_director.awarded["0:39"] = true
    game.race_director.last_award_grade["0:39"] = 0.99
    game._end_race()
    assert(game.career.precision_best == [2,0,0] and
        game.career.precision_total == 2,
        "Neither online client nor dedicated server can mint solo medals")
    game.net.role = "offline"
    game.return_to_menu()
    game.queue_free()
    for i in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    print("PRECISION_MEDALS_PASS: 9 medal goals, Android persistence, offline-only skill, REP cap, UI, results and replay")
    quit(0)
