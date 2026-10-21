extends SceneTree
## Solo-only replay points and permanent lifetime milestones.
const Career = preload("res://scripts/career.gd")
const TEST_SAVE := "user://qa_league_lifetime.cfg"
const SCENE_SAVE := "user://qa_league_scene.cfg"

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    var c = Career.new()
    c.save_path = TEST_SAVE
    assert(c.league_points == 0 and c.league_name() == "ROOKIE")
    var no_finisher: Dictionary = c.award_league(0,1,false,3,true)
    assert(int(no_finisher["earned"]) == 0 and c.league_points == 0)
    no_finisher = c.award_league(0,0,true,3,true)
    assert(c.league_points == 0,"Impossible rank cannot generate replay points")
    no_finisher = c.award_league(3,1,true,3,true)
    assert(c.league_points == 0,"Unknown courses cannot generate replay points")
    var plain: Dictionary = c.award_league(0,40,true,0,false)
    assert(int(plain["earned"]) == 14)
    var excellent: Dictionary = c.award_league(0,1,true,20,true)
    assert(int(excellent["earned"]) == 63,
        "Near miss scoring must be capped to three real hazards")
    assert(c.league_clean_passes[0] == 3 and c.league_shortcuts[0] == 1)
    assert(c.league_runs[0] == 2 and c.league_races() == 2)
    assert(c.league_tier() == 0)
    var total_promotions := 0
    for round_index in range(80):
        var index: int = round_index % 3
        var earned: Dictionary = c.award_league(index,2,true,1,round_index%2==0)
        if bool(earned["promoted"]):
            total_promotions += 1
    assert(c.league_tier() == 4 and c.league_name() == "LEGEND")
    assert(total_promotions == 4,
        "Every tier should be earned once, not repeatedly triggered")
    assert(c.league_points > Career.LEAGUE_LIMITS[4])
    assert(c.league_next_goal() == Career.LEAGUE_LIMITS[4])
    assert(c.league_progress_label().contains("LEGEND"))
    var restored = Career.new()
    restored.save_path = TEST_SAVE
    restored.load_save()
    assert(restored.league_points == c.league_points)
    assert(restored.league_runs == c.league_runs)
    assert(restored.league_shortcuts == c.league_shortcuts)
    assert(restored.league_clean_passes == c.league_clean_passes)
    var legacy := ConfigFile.new()
    legacy.set_value("career","starts",2)
    legacy.set_value("career","finishes",1)
    legacy.set_value("career","best_0",9)
    assert(legacy.save(SCENE_SAVE) == OK)
    var upgraded = Career.new()
    upgraded.save_path = SCENE_SAVE
    upgraded.load_save()
    assert(upgraded.league_points == 0 and upgraded.league_races() == 0)
    assert(upgraded.unlocked == 2 and upgraded.track_best[0] == 9,
        "Old existing career data must survive added league fields")

    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = SCENE_SAVE
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = false
    game._end_race()
    assert(game.career.league_points == 0,"DNF must never award league reputation")
    game.return_to_menu()
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 48.0
    game.race_time = 48.0
    game.race_director.awarded["0:39"] = true
    game.shortcut_route.triggered[39] = true
    game._end_race()
    var now_points: int = game.career.league_points
    assert(now_points > 15 and int(game.last_result["league_earned"]) > 15)
    var summary: Label = game.ui.results_layer.find_child("Summary",true,false)
    assert(summary.text.contains("LEAGUE  ROOKIE"),
        "Solo result should explain league reputation earned")
    game._end_race()
    assert(game.career.league_points == now_points,
        "Re-entering results must not double-count a completed race")
    game.return_to_menu()
    game.net.role = "server"
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 32.0
    game._end_race()
    assert(game.career.league_points == now_points,
        "Multiplayer server cannot rewrite private solo league progress")
    game.net.role = "offline"
    game.return_to_menu()
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    print("LEAGUE_PROGRESS_PASS: 5 ranks, old saves, replay points, solo-only results")
    quit(0)
