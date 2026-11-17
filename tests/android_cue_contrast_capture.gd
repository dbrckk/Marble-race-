extends Node

const BASIC_FONT := preload("res://assets/fonts/Rajdhani-Medium.ttf")
var game: Node3D
var hud: CanvasLayer
var bright: ColorRect
var output := FileAccess.open("user://cue-contrast.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    hud = game.ui
    assert(game.set_track(0))
    game.career.save_path = "user://cue-contrast-qa.cfg"
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    await RenderingServer.frame_post_draw
    print("CUE_CONTRAST_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    var area = game.board.find_child("OpeningObstacleArt",true,false)
    var limit := Time.get_ticks_msec()+80000
    while Time.get_ticks_msec()<limit and (game.race_state!="RACING" or game.player.position.z>area.entry_z-0.9):
        await RenderingServer.frame_post_draw
    assert(game.race_state=="RACING" and game.player.position.z<=area.entry_z-0.9)
    game.process_mode = Node.PROCESS_MODE_DISABLED
    for marble in game.racers:
        marble.freeze = true
    _update_hud()
    assert(hud.hazard_label.visible)
    await _comparison("opening",hud.hazard_label)

    bright = ColorRect.new()
    bright.color = Color("#fff4d7")
    bright.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bright.anchor_left = 0.22
    bright.anchor_right = 0.78
    bright.anchor_top = 0.15
    bright.anchor_bottom = 0.205
    hud.hud_layer.add_child(bright)
    hud.hud_layer.move_child(bright,0)
    await _comparison("bright",hud.hazard_label)
    bright.hide()

    var pickup: Node3D = game.race_items.items[0]
    game.player.global_position = pickup.global_position+Vector3.BACK*12.0
    game.player.linear_velocity = Vector3(0,0,-22)
    game._update_camera(0.1,true)
    _update_hud()
    assert(hud.rare_item_label.visible)
    await _comparison("pickup",hud.rare_item_label)
    print("CUE_CONTRAST_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _update_hud() -> void:
    hud.label_timer = 1.0
    hud.update_hud()

func _comparison(pose: String, cue: Label) -> void:
    assert(cue.visible and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    var background: Panel = hud.driving_cue_backgrounds[cue]
    assert(background.visible and background.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    var text: String = cue.text
    var font := cue.get_theme_font("font")
    var font_size := cue.get_theme_font_size("font_size")
    var camera: Transform3D = game.camera.global_transform
    var original_alignment := cue.vertical_alignment
    for candidate in [false,true]:
        if candidate:
            for label: Label in hud.driving_cue_backgrounds:
                hud._refresh_driving_cue_background(label)
            cue.add_theme_font_override("font",font)
            cue.add_theme_font_size_override("font_size",font_size)
            cue.add_theme_constant_override("outline_size",2)
            cue.add_theme_color_override("font_outline_color",Color("#10151e"))
            cue.vertical_alignment = original_alignment
        else:
            for label: Label in hud.driving_cue_backgrounds:
                hud.driving_cue_backgrounds[label].hide()
            cue.add_theme_font_override("font",BASIC_FONT)
            if cue==hud.hazard_label:
                cue.add_theme_font_size_override("font_size",17)
                cue.vertical_alignment = VERTICAL_ALIGNMENT_TOP
            cue.add_theme_constant_override("outline_size",5)
            cue.add_theme_color_override("font_outline_color",Color("#121820"))
        for warm in range(4):
            await RenderingServer.frame_post_draw
        assert(game.camera.global_transform==camera and cue.text==text)
        var rect := background.get_global_rect()
        var view_size: Vector2 = hud.hud_layer.size
        var row := {"pose":pose,"candidate":candidate,"message":text,
            "foreground":cue.get_theme_color("font_color").to_html(false),
            "panel":[rect.position.x/view_size.x,rect.position.y/view_size.y,
                rect.size.x/view_size.x,rect.size.y/view_size.y],
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
        if candidate:
            assert(background.visible and rect.size.x<=cue.size.x+0.1 and rect.size.y<=cue.size.y+0.1)
        output.store_line(JSON.stringify(row))
        output.flush()
        print("CUE_CONTRAST ",JSON.stringify(row))
        assert(get_viewport().get_texture().get_image().save_png(
            "user://cue-%s-%d.png" % [pose,int(candidate)]) == OK)
