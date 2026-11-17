extends Node

const RACER = preload("res://scripts/marble.gd")
const FEEDBACK = preload("res://scripts/race_feedback.gd")
var game: Node3D
var hud: CanvasLayer
var art: MeshInstance3D
var output := FileAccess.open("user://cue-contrast.jsonl",FileAccess.WRITE)

func _ready() -> void:
    _run.call_deferred()

func _run() -> void:
    game=get_parent()
    hud=game.ui
    assert(game.set_track(0))
    game.career.save_path="user://chase-framing-qa.cfg"
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    game.set_process(false)
    game.set_physics_process(false)
    game.race_state="RACING"
    for marble in game.racers:
        marble.freeze=true
    hud.countdown_label.get_parent().hide()
    await RenderingServer.frame_post_draw
    print("CUE_CONTRAST_DEVICE ",RenderingServer.get_current_rendering_driver_name())
    art=game.board.find_child("OpeningObstacleArt",true,false)
    await _capture("pack")
    await _capture("jump")
    print("CUE_CONTRAST_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()

func _capture(pose: String) -> void:
    var crowded := pose=="pack"
    var z: float=art.entry_z+(11.5-4.0*0.95 if crowded else 6.25)
    var racer: RigidBody3D=game.player
    var velocity:=Vector3(0,0,-23)
    racer.global_position=Vector3(game.track_center_at(z),
        game.height_at(z)+(0.52 if crowded else 2.92),z)
    racer.linear_velocity=velocity
    var item: Node3D=game.race_items.items[0]
    var blockers: Array[Vector3]=[]
    for i in range(39):
        var marble: RigidBody3D=game.racers[i]
        var mz: float=z-1.05-float(i/5)*1.10 if crowded else z+4.0+float(i/5)*1.10
        var mx: float=racer.global_position.x+float(i%5-2)*1.24+sin(float(i/5)*1.7+4.0*0.47)*0.58
        marble.global_position=Vector3(mx,game.height_at(mz)+0.48,mz)
        marble.linear_velocity=velocity
        blockers.append(marble.global_position)
    game.race_moments.reset_round()
    for tick in range(5):
        game.race_moments.tick(0.12)
    assert(not crowded or game.race_moments.nearby_pack_count>=4)
    var pressure: float=game.race_moments.pack_pressure
    game.airtime.airborne=not crowded
    game.airtime.flight_time=0.34
    game.race_time=1.40
    hud.label_timer=1.0
    hud.update_hud()
    var message: String=hud.rare_item_label.text if hud.rare_item_label.visible else hud.hazard_label.text
    assert(not message.is_empty())
    var player_pos:=racer.global_position
    var landing_z := z-14.0
    var landing:=Vector3(game.track_center_at(landing_z),game.height_at(landing_z)+0.40,landing_z)
    for candidate in [false,true]:
        game.race_moments.pack_pressure=pressure if candidate else 0.0
        for update in range(120):
            game._update_camera(1.0/60.0,update==0)
        if not candidate and not crowded:
            var focus: Vector3=game.camera_lookahead
            assert(focus.y > game.height_at(focus.z)+FEEDBACK.TERRAIN_LOOK_CLEARANCE+0.02)
            focus.y+=0.91*game.airtime.camera_weight()
            game.camera.look_at(focus,Vector3.UP)
            var bend: float = game.track_center_at(z-12.0)-game.track_center_at(z+5.0)
            game.camera.rotate_object_local(Vector3.FORWARD,FEEDBACK.camera_roll(0.0,23.0,bend,0))
        for warm in range(4):
            await RenderingServer.frame_post_draw
        assert(racer.global_position==player_pos and racer.linear_velocity==velocity)
        var blocked := 0
        for gap: Vector2 in art.entry_gaps:
            var at: Vector3=art.to_global(Vector3((gap.x+gap.y)*0.5,0,art.entry_z+0.09))
            at.y=game.height_at(at.z)+0.08
            blocked+=int(_blocked(at,blockers))
        var screen: Vector2=get_viewport().get_visible_rect().size
        var row := {"pose":pose,"candidate":candidate,"message":message,"blocked":blocked,
            "item_blocked":_blocked(item.global_position,blockers),
            "landing_y":game.camera.unproject_position(landing).y/screen.y,
            "player_y":game.camera.unproject_position(player_pos).y/screen.y,
            "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
        output.store_line(JSON.stringify(row))
        output.flush()
        print("CUE_CONTRAST ",JSON.stringify(row))
        assert(get_viewport().get_texture().get_image().save_png(
            "user://cue-%s-%d.png" % [pose,int(candidate)])==OK)
    game.race_moments.pack_pressure=pressure

func _blocked(target: Vector3,blockers: Array[Vector3]) -> bool:
    var origin: Vector3=game.camera.global_position
    var direction:=target-origin
    for c in blockers:
        var t: float=direction.dot(c-origin)/direction.length_squared()
        if t>0.0 and t<1.0 and (origin+direction*t).distance_squared_to(c)<RACER.RADIUS*RACER.RADIUS:
            return true
    return false
