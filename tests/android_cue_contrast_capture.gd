extends Node

const ROUTE = preload("res://scripts/shortcut_route.gd")
var game: Node3D
var hud: CanvasLayer
var output := FileAccess.open("user://cue-contrast.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game = get_parent()
    hud = game.ui
    game.career.save_path = "user://bridge-guidance-qa.cfg"
    game.career.unlocked = 3
    game.set_graphics_quality(1)
    game.set_process(false)
    game.set_physics_process(false)
    await RenderingServer.frame_post_draw
    print("CUE_CONTRAST_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    await _capture(1,"glacier")
    game.return_to_menu()
    await _capture(2,"forge")
    print("CUE_CONTRAST_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _capture(track: int, pose: String) -> void:
    assert(game.set_track(track))
    game.start_race("Grip Tape")
    game.race_state = "RACING"
    for marble in game.racers:
        marble.freeze = true
    hud.countdown_label.get_parent().hide()
    var speed := 23.0
    var director: Node3D = game.race_director
    var z := ROUTE.EXIT_Z+(1.1 if track==1 else 4.0)
    if track==1:
        game.player.global_position = game.shortcut_route.point_at(ROUTE.EXIT_Z+16.0)+Vector3.UP*0.73
        game.player.linear_velocity = Vector3(0,0,-speed)
        hud.label_timer = 1.0
        hud.update_hud()
        assert(hud.bridge_approach_active)
        director.animate(5.0)
    else:
        var eta: float = (z-director.event_z(director.FORGE_EXIT_GATE))/speed
        var clock := -1.0
        for step in range(260):
            var t := float(step)*0.02
            director.animate(t)
            if director.forge_exit_blocks_during_crossing(eta,speed):
                clock = t
                break
        assert(clock>=0.0)
    var racer: RigidBody3D = game.player
    var rival: RigidBody3D = game.racers[0]
    racer.global_position = game.shortcut_route.point_at(z)+Vector3.UP*0.73
    racer.linear_velocity = Vector3(0,0,-speed)
    rival.global_position = racer.global_position+Vector3(1.4,0,-0.85)
    rival.linear_velocity = racer.linear_velocity
    for tick in range(6):
        game.race_moments.tick(0.12)
    assert(game.race_moments.closest_rival==rival)
    assert(game.race_moments.side_by_side_active)
    game._update_camera(0.1,true)
    hud.label_timer = 1.0
    hud.update_hud()
    assert(hud.bridge_approach_active and hud.timed_gate_label.visible and hud.timed_gate_backdrop.visible)
    assert(hud.rival_marker.visible and not hud.duel_label.visible)
    assert(hud.shortcut_label.visible==(track==2))
    var new_text: String = hud.timed_gate_label.text
    assert(new_text.contains("THEN AIM CENTER") if track==1 else new_text.contains("AFTER BRIDGE"))
    var merge: String = "MERGE RIGHT" if track==1 else hud.shortcut_label.text
    var old_text := "MERGE RIGHT  •  AIM CENTER  •  "+new_text.get_slice("  •  ",2) if track==1 else new_text
    var stable_camera: Transform3D = game.camera.global_transform
    var marker_pos: Vector3 = hud.rival_marker.global_position
    for candidate in [false,true]:
        hud.duel_label.visible = not candidate
        hud.timed_gate_label.text = new_text if candidate else old_text
        for warm in range(4):
            await RenderingServer.frame_post_draw
        assert(game.camera.global_transform==stable_camera and hud.rival_marker.global_position==marker_pos)
        var label: Label = hud.timed_gate_label
        var required := label.get_theme_font("font").get_string_size(label.text,
            HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
        assert(required+12.0<=label.size.x and label.get_line_count()==1)
        var rect: Rect2 = hud.timed_gate_backdrop.get_global_rect()
        var screen: Vector2 = hud.hud_layer.size
        var row := {"pose":pose,"candidate":candidate,"message":merge,"merge":merge,
            "steering":label.text,"marker":hud.rival_marker.visible,"danger":hud.timed_gate_backdrop.visible,
            "rival_text":hud.duel_label.text if hud.duel_label.visible else "",
            "panel":[rect.position.x/screen.x,rect.position.y/screen.y,rect.size.x/screen.x,rect.size.y/screen.y],
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
        output.store_line(JSON.stringify(row))
        output.flush()
        print("CUE_CONTRAST ",JSON.stringify(row))
        assert(get_viewport().get_texture().get_image().save_png(
            "user://cue-%s-%d.png" % [pose,int(candidate)])==OK)
    z = ROUTE.EXIT_Z-1.0
    racer.global_position = Vector3(game.track_center_at(z),game.height_at(z)+0.73,z)
    rival.global_position = racer.global_position+Vector3(1.4,0,-0.85)
    hud.label_timer = 1.0
    hud.update_hud()
    assert(not hud.bridge_approach_active and hud.rival_marker.visible and hud.duel_label.visible)
