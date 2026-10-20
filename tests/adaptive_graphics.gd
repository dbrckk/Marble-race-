extends SceneTree
## AUTO graphics respects setting persistence and hysteresis, without mocks.
func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_graphics_quality(3)
    assert(game.graphics_setting == 3 and game.graphics_quality == 1,
        "AUTO should start from balanced, not expensive Ultra")
    assert(game.graphics_mode_label() == "AUTO (BALANCED)")
    var prefs := ConfigFile.new()
    assert(prefs.load("user://marble_settings.cfg") == OK)
    assert(int(prefs.get_value("video","quality",-1)) == 3,
        "AUTO preference must survive restart")
    for i in range(11):
        game._auto_quality_sample(24.0,1.0)
    assert(game.graphics_quality == 1, "Auto downgraded too early")
    game._auto_quality_sample(24.0,1.0)
    assert(game.graphics_quality == 0, "Sustained low FPS should downgrade")
    assert(game.graphics_mode_label() == "AUTO (ECONOMY)")
    for i in range(27):
        game._auto_quality_sample(58.0,1.0)
    assert(game.graphics_quality == 0, "Do not upgrade before 28s")
    game._auto_quality_sample(58.0,1.0)
    assert(game.graphics_quality == 1, "Recovered sustained FPS should upgrade")
    assert(game.graphics_setting == 3, "Auto must not overwrite saved mode")
    for i in range(65):
        game._auto_quality_sample(60.0,1.0)
    assert(game.graphics_quality == 1, "Auto should cap at Balanced")
    game._auto_quality_sample(22.0,8.0)
    game._auto_quality_sample(48.0,1.0)
    game._auto_quality_sample(22.0,5.0)
    assert(game.graphics_quality == 1, "Borderline FPS must reset the downgrade countdown")
    game.set_graphics_quality(2)
    game._auto_quality_sample(12.0,99.0)
    assert(game.graphics_quality == 2, "Manual profile must never be modified")
    game.set_graphics_quality(1)
    print("ADAPTIVE_GRAPHICS_PASS: saved setting, stable hysteresis, 30fps recovery and manual override")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
