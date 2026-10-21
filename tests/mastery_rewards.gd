extends SceneTree
## Permanent, fairly-earned solo mastery + visual-only prize regression.
const Career = preload("res://scripts/career.gd")
const TEST_SAVE := "user://qa_marblerace_mastery.cfg"
const SCENE_SAVE := "user://qa_marblerace_mastery_scene.cfg"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    var c = Career.new()
    c.save_path = TEST_SAVE
    assert(c.mastery_count() == 0)
    assert(c.unlocked_style_count() == 1)
    assert(c.style_name() == "COPPER")
    assert(not c.choose_style(1), "Locked rewards must not be selectable")
    var empty: Dictionary = c.complete_mastery(0,false,3,true)
    assert(empty["new_goals"].is_empty() and c.mastery_count() == 0,
        "DNF cannot award any permanent skill challenge")
    empty = c.complete_mastery(-1,true,3,true)
    assert(c.mastery_count() == 0,"Invalid track may not grant mastery")
    var earned: Dictionary = c.complete_mastery(0,true,0,false)
    assert(c.mastery_flags == [1,0,0] and earned["new_goals"].size() == 1,
        "First legitimate finish grants only the finish stamp")
    earned = c.complete_mastery(0,true,1,false)
    assert(c.mastery_flags[0] == 3 and c.mastery_count() == 2,
        "Physical clean pass unlocks the second mastery goal")
    assert(earned["new_styles"].has("AZURE"),
        "Two permanent stamps must unlock the Azure visual")
    assert(c.choose_style(1) and c.selected_style == 1)
    assert(not c.choose_style(2),"Solar marble needs four real stamps")
    earned = c.complete_mastery(0,true,2,true)
    assert(c.mastery_flags[0] == 7 and c.track_mastery_count(0) == 3,
        "A completed physical bypass awards the third track stamp")
    assert(earned["new_goals"] == ["SHORTCUT"])
    assert(c.mastery_count() == 3)
    earned = c.complete_mastery(0,true,3,true)
    assert(earned["new_goals"].is_empty() and earned["new_styles"].is_empty(),
        "Repeating an earned skill must not farm duplicate rewards")
    earned = c.complete_mastery(1,true,3,false)
    assert(c.mastery_count() == 5 and earned["new_styles"].has("SOLAR"))
    earned = c.complete_mastery(2,true,0,false)
    assert(c.mastery_count() == 6 and earned["new_styles"].has("AMETHYST"))
    assert(not c.is_style_unlocked(4))
    earned = c.complete_mastery(1,true,0,true)
    assert(c.mastery_count() == 7)
    earned = c.complete_mastery(2,true,2,true)
    assert(c.mastery_count() == 9 and earned["new_styles"].has("PRISM"))
    assert(c.unlocked_style_count() == 5)
    assert(c.choose_style(4))
    assert(c.cycle_style() == 0 and c.cycle_style() == 1,
        "Style cycling wraps the accessible prize list")
    assert(c.choose_style(4))
    var restored = Career.new()
    restored.save_path = TEST_SAVE
    restored.load_save()
    assert(restored.mastery_flags == [7,7,7] and restored.mastery_count() == 9,
        "All nine permanent stamps survive a relaunch")
    assert(restored.selected_style == 4 and restored.style_name() == "PRISM",
        "Unlocked player cosmetic must survive a relaunch")
    # Corrupt/fabricated style IDs and old saves are both handled safely:
    # nonexistent [mastery] keys default to zero, and a still-locked
    # visual never survives a config load.
    var legacy := ConfigFile.new()
    legacy.set_value("career","starts",2)
    legacy.set_value("career","finishes",1)
    legacy.set_value("career","best_0",9)
    legacy.set_value("mastery","style",4)
    assert(legacy.save(SCENE_SAVE) == OK)
    var migrated = Career.new()
    migrated.save_path = SCENE_SAVE
    migrated.load_save()
    assert(migrated.track_best[0] == 9 and migrated.unlocked == 2,
        "Old career unlocking must remain backward compatible")
    assert(migrated.mastery_count() == 0 and migrated.selected_style == 0,
        "A forged cosmetic selection must not bypass mastery thresholds")

    # Full scene integration: only solo completed races can persist stamps.
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = SCENE_SAVE
    game.career.mastery_flags = [0,0,0]
    game.career.selected_style = 0
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = false
    game._end_race()
    assert(game.career.mastery_count() == 0,
        "A solo timeout must never produce a mastery unlock")
    game.return_to_menu()
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 52.0
    game.race_time = 52.0
    game.race_director.awarded["0:39"] = true
    game.shortcut_route.triggered[39] = true
    game._end_race()
    assert(game.career.mastery_flags[0] == 7,
        "Completed solo race must read true course skill detectors")
    assert(game.last_result["mastery_new"].size() == 3)
    assert(game.last_result["mastery_styles"].has("AZURE"))
    assert(game.ui.results_layer.find_child("Summary",true,false).text.contains(
        "MASTERY  3/3"),"The real solo results menu must show earned skill goals")
    game.return_to_menu()
    assert(game.career.choose_style(1))
    game.start_race("Grip Tape")
    assert(game.player.glass_material.get_shader_parameter("base_color") ==
        game.player.PLAYER_STYLE_BASE[1],
        "Unlocked style is rendered on the actual local marble")
    assert(is_equal_approx(game.player.mass,0.73),
        "A cosmetic marble must never change its mass or race physics")
    game.return_to_menu()
    # No on-server room transition or authoritative online result is
    # permitted to mutate the solo career even if a network slot finishes.
    var before_online: int = game.career.mastery_count()
    game.net.role = "server"
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    game.player.finished = true
    game.player.finish_time = 35.0
    game.race_director.awarded["1:39"] = true
    game._end_race()
    assert(game.career.mastery_count() == before_online,
        "Network session may not mint permanent solo stamps")
    game.net.role = "offline"
    game.return_to_menu()
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_SAVE))
    print("MASTERY_REWARDS_PASS: 9 persisted goals, 5 skins, offline-only physics and UI")
    quit(0)
