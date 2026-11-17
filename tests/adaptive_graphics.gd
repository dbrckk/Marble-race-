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
    game.career.unlocked = 3
    assert(game.set_track(2))
    var key_light: DirectionalLight3D = game.primary_light
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and
        is_equal_approx(key_light.directional_shadow_max_distance,33.0) and
        is_equal_approx(key_light.directional_shadow_split_1,0.30),
        "Forge Balanced keeps two shadow cascades close to the driving view")
    game.start_race("Grip Tape")
    assert(key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
    game.return_to_menu()
    game.set_graphics_quality(2)
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and
        is_equal_approx(key_light.directional_shadow_max_distance,72.0),
        "Ultra restores its longer shadow range on Forge")
    game.set_graphics_quality(0)
    assert(not key_light.shadow_enabled)
    game.set_graphics_quality(3)
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
    assert(game.set_track(1))
    assert(key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and
        is_equal_approx(key_light.directional_shadow_max_distance,47.0) and
        is_equal_approx(key_light.directional_shadow_split_1,0.10),
        "Changing tracks restores the other courses' Balanced shadow setup")
    print("ADAPTIVE_GRAPHICS_PASS: saved setting, stable hysteresis, 30fps recovery and profile/track shadows")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)
