extends Node
const OLD_RADAR := preload("res://tests/android_hud_baseline_radar.gd")
const PHASES := ["grid","real_opening","fast_opening"]
var game: Node3D
var hud: CanvasLayer
var legacy: Control
var panel: Control
var out := FileAccess.open("user://hud-profile.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    hud = game.ui
    assert(game.set_track(0))
    game.career.save_path = "user://hud-profile-qa.cfg"
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    assert(game.racers.size() == 40)
    await RenderingServer.frame_post_draw
    print("HUD_PROFILE_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    panel = hud.leaderboard.get_parent()
    legacy = OLD_RADAR.new()
    hud.hud_layer.add_child(legacy)
    hud.hud_layer.move_child(legacy,hud.race_radar.get_index())
    legacy.anchor_left = hud.race_radar.anchor_left
    legacy.anchor_right = hud.race_radar.anchor_right
    legacy.anchor_top = hud.race_radar.anchor_top
    legacy.anchor_bottom = hud.race_radar.anchor_bottom
    legacy.configure(game)
    legacy.hide()
    _freeze(true)
    await _compare("grid")
    _freeze(false)

    var art = game.board.find_child("OpeningObstacleArt",true,false)
    assert(is_instance_valid(art) and is_finite(art.entry_z))
    var deadline := Time.get_ticks_msec()+85000
    while Time.get_ticks_msec() < deadline and (game.race_state != "RACING" or
        game.player.position.z > art.entry_z-0.9):
        await RenderingServer.frame_post_draw
    assert(game.race_state == "RACING" and game.player.position.z <= art.entry_z-0.9)
    assert(not game.player.eliminated and game.player.linear_velocity.z < -3.0)
    _freeze(true)
    await _compare("real_opening")

    # Identical nearby pack and 79 km/h HUD for both render paths.
    for i in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[i]
        var z: float = art.entry_z-2.0+floorf(float(i)/8.0)*1.05-1.65
        var x: float = game.track_center_at(z)+(float(i%8)-3.5)*1.23
        if marble == game.player:
            z = art.entry_z-2.0
            x = game.track_center_at(z)-0.48
        marble.global_position = Vector3(x,game.height_at(z)+0.45,z)
        marble.linear_velocity = Vector3(0.0,0.0,-22.0)
    game.race_moments.local_speed = 22.0
    game.contact_shadows.update_shadows()
    game._update_camera(1.0,true)
    _check_touches()
    await _compare("fast_opening")
    print("HUD_PROFILE_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _freeze(paused: bool) -> void:
    game.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
    if paused and game.race_state == "RACING":
        for marble in game.racers:
            marble.freeze = true

func _check_touches() -> void:
    var pad: Control = hud.touch_controls
    var viewport: Vector2 = pad.get_viewport_rect().size
    pad.left_handed = false
    var steer_at := viewport*Vector2(0.18,0.81)
    var boost_at := viewport*Vector2(0.79,0.81)
    pad._finger_event(4,steer_at,true)
    pad._move_finger(4,steer_at+Vector2(90,0))
    pad._finger_event(5,boost_at,true)
    assert(game.steer_target > 0.25 and game.boosting and pad.boost_pressed)
    pad._finger_event(5,boost_at,false)
    assert(game.steer_target > 0.25 and not game.boosting)
    pad._finger_event(4,steer_at,false)
    assert(is_zero_approx(game.steer_target))
    print("HUD_PROFILE_TOUCH")

func _compare(phase: String) -> void:
    hud.label_timer = 1.0
    hud.update_hud()
    if phase != "grid":
        hud.show_race_moment("SLIPSTREAM!",0.72,1)
    hud.race_radar.sample(0.12)
    legacy.show()
    legacy.sample(0.12)
    legacy.hide()
    assert(hud.race_radar.last_count == 40 and legacy.last_count == 40)
    var cameras: Transform3D = game.camera.global_transform
    var names: Array = []
    for offset in range(2):
        var candidate := (PHASES.find(phase)+offset)%2 == 1
        hud.race_radar.visible = candidate
        legacy.visible = not candidate
        panel.anchor_bottom = 0.205 if candidate else 0.305
        panel.offset_bottom = 0.0
        for warm in range(4):
            await RenderingServer.frame_post_draw
        assert(game.camera.global_transform == cameras)
        if candidate:
            assert(hud.race_radar.opponent_dots.visible_instance_count == 39)
        assert(hud.leaderboard.get_global_rect().end.y <= panel.get_global_rect().end.y+0.01)
        var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
        var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        var rect := panel.get_global_rect()
        var dots: Rect2 = hud.race_radar.get_global_rect()
        var canvas: Vector2 = hud.hud_layer.size
        var target := Rect2(dots.position/canvas,dots.size/canvas)
        var row := {"phase":phase,"candidate":candidate,"draws":calls,"triangles":tris,
            "area":rect.size.x*rect.size.y,"speed":absf(game.player.linear_velocity.z)*3.6,
            "opponents":legacy.last_count-1,"radar_area":[target.position.x,target.position.y,target.size.x,target.size.y],
            "alert":hud.hazard_label.visible or hud.rare_item_label.visible,
            "board":hud.leaderboard.text}
        out.store_line(JSON.stringify(row))
        out.flush()
        print("HUD_PROFILE ",JSON.stringify(row))
        assert(get_viewport().get_texture().get_image().save_png(
            "user://hud-%s-%d.png" % [phase,int(candidate)]) == OK)
    panel.anchor_bottom = 0.205
    panel.offset_bottom = 0.0
    legacy.hide()
    hud.race_radar.show()
