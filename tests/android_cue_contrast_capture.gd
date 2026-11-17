extends Node

var game: Node3D
var hud: CanvasLayer
var output := FileAccess.open("user://cue-contrast.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    hud = game.ui
    assert(game.set_track(0))
    game.career.save_path = "user://pickup-layout-qa.cfg"
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    await RenderingServer.frame_post_draw
    print("CUE_CONTRAST_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    game.process_mode = Node.PROCESS_MODE_DISABLED
    game.race_state = "RACING"
    game.show_fps = false
    for marble in game.racers:
        marble.freeze = true
    hud.countdown_label.get_parent().hide()
    var pickup: Node3D = game.race_items.items[0]
    var z := pickup.global_position.z+12.65
    var speed := 23.0
    var centre: float = game.track_center_at(z)
    game.race_time = (5.0-z)/speed
    game.race_director.animate(game.race_time)
    var gate_eta: float = (z-game.race_director.event_z(0))/speed
    var threat_x := INF
    for step in range(-16,17):
        var x := centre+float(step)*0.24
        if game.race_director.threatens_line(0,game.race_time,gate_eta,x,0.0):
            threat_x = x
            break
    assert(is_finite(threat_x))
    await _pose("opening",centre,z,speed,false)
    await _pose("pickup",threat_x,z,speed,true)
    print("CUE_CONTRAST_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _pose(pose: String, x: float, z: float, speed: float, danger: bool) -> void:
    game.player.global_position = Vector3(x,game.height_at(z)+0.73,z)
    game.player.linear_velocity = Vector3(0,0,-speed)
    game._update_camera(0.1,true)
    hud.label_timer = 1.0
    hud.update_hud()
    var cue: Label = hud.rare_item_label
    var background: Panel = hud.driving_cue_backgrounds[cue]
    var candidate_anchors := Vector4(cue.anchor_left,cue.anchor_top,cue.anchor_right,cue.anchor_bottom)
    assert(cue.visible and background.visible)
    var original: Rect2 = background.get_global_rect()
    assert(original.position.x >= hud.hud_layer.size.x*0.735)
    assert(original.end.y < hud.hud_layer.size.y*0.2701)
    assert(hud.hazard_label.visible and hud.timed_gate_label.visible)
    assert(hud.timed_gate_label.text.contains("DODGE!") == danger)
    assert(hud.timed_gate_backdrop.visible == danger)
    var message := cue.text
    var steering: String = hud.timed_gate_label.text
    var camera: Transform3D = game.camera.global_transform
    for candidate in [false,true]:
        var anchors := candidate_anchors if candidate else Vector4(0.285,0.357,0.715,0.396)
        cue.set_anchor_and_offset(SIDE_LEFT,0.0,0.0)
        cue.set_anchor_and_offset(SIDE_TOP,0.0,0.0)
        cue.set_anchor_and_offset(SIDE_RIGHT,anchors.z,0.0)
        cue.set_anchor_and_offset(SIDE_BOTTOM,anchors.w,0.0)
        cue.set_anchor_and_offset(SIDE_LEFT,anchors.x,0.0)
        cue.set_anchor_and_offset(SIDE_TOP,anchors.y,0.0)
        hud._refresh_driving_cue_background(cue)
        for warm in range(4):
            await RenderingServer.frame_post_draw
        assert(game.camera.global_transform==camera and cue.text==message and hud.timed_gate_label.text==steering)
        var rect := background.get_global_rect()
        var view_size: Vector2 = hud.hud_layer.size
        var font := cue.get_theme_font("font")
        var font_size := cue.get_theme_font_size("font_size")
        var text_width := font.get_string_size(cue.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
        assert(text_width+12.0 <= rect.size.x)
        if candidate:
            assert(rect.position.x/view_size.x >= 0.735 and rect.end.x/view_size.x <= 0.9851)
            assert(not rect.intersects(hud.leaderboard.get_parent().get_global_rect()))
            var status_panel: Control = hud.network_quality_label.get_parent()
            assert(rect.end.y < hud.hud_layer.size.y*status_panel.anchor_top)
            assert(not rect.intersects(hud.timed_gate_label.get_global_rect()))
        var row := {"pose":pose,"candidate":candidate,"message":message,"steering":steering,
            "panel":[rect.position.x/view_size.x,rect.position.y/view_size.y,
                rect.size.x/view_size.x,rect.size.y/view_size.y],
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
        output.store_line(JSON.stringify(row))
        output.flush()
        print("CUE_CONTRAST ",JSON.stringify(row))
        assert(get_viewport().get_texture().get_image().save_png(
            "user://cue-%s-%d.png" % [pose,int(candidate)]) == OK)
