extends Control
## A local, screen-space locator above the physical player. The badge
## stays readable when the marble rotates or disappears behind rivals.
const Racer = preload("res://scripts/marble.gd")
const FONT = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const INK := Color("#111722")
const ACCENT := Color("#fff1b2")
const FONT_SIZE := 23
const BADGE_HEIGHT := 27.0
const GRID_HANDOFF := 0.5
const HAZARD_ACCENT := Color("#ffc57e")

var game: Node3D
var screen_center := Vector2.ZERO
var screen_radius := 0.0
var bracket_strength := 0.0
var badge_text := "YOU"
var badge_width := 58.0
var badge := StyleBoxFlat.new()
var bracket_mesh: ArrayMesh
var hazard_center := Vector2.INF
var evasion_center := Vector2.INF

func configure(stage: Node3D) -> void:
    game = stage
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    badge.bg_color = Color(INK,0.95)
    badge.border_color = Color(ACCENT,0.88)
    badge.set_border_width_all(1)
    badge.set_corner_radius_all(7)
    bracket_mesh = _make_brackets()
    hide()

func begin_round() -> void:
    bracket_strength = 0.0
    hazard_center = Vector2.INF
    evasion_center = Vector2.INF
    badge_text = "YOU"
    if not game.net.is_active() and game.career.league_tier() >= 1:
        badge_text += "  •  "+game.career.league_name()
    badge_width = maxf(58.0,FONT.get_string_size(badge_text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x+18.0)
    hide()

func refresh(delta: float) -> void:
    hazard_center = Vector2.INF
    evasion_center = Vector2.INF
    var marble: RigidBody3D = game.player
    var camera: Camera3D = game.camera
    if game.net.role == "server" or not is_instance_valid(marble) or not is_instance_valid(camera) or (
            marble.finished or marble.eliminated or (
                game.race_state != "COUNTDOWN" and game.race_state != "RACING")):
        hide()
        return
    var center := marble.global_position
    if camera.is_position_behind(center):
        hide()
        return
    var projected := camera.unproject_position(center)
    if not projected.is_finite() or not Rect2(Vector2.ZERO,size).has_point(projected):
        hide()
        return

    screen_center = projected
    var edge := camera.unproject_position(center+camera.global_basis.x*Racer.RADIUS)
    screen_radius = clampf(projected.distance_to(edge),4.0,80.0)
    var moments: RefCounted = game.race_moments
    if game.race_state == "RACING" and game.cam_mode == 0 and moments != null:
        var obstacle: Vector3 = moments.occluded_hazard
        var safe := Rect2(Vector2(size.x*0.14,size.y*0.23),Vector2(size.x*0.72,size.y*0.52))
        var fresh: bool = not game.net.is_client() or game.net.local_replica_velocity().is_finite()
        if obstacle.is_finite() and center.z-obstacle.z > 0.7 and not camera.is_position_behind(obstacle) and (
                fresh):
            var point := camera.unproject_position(obstacle)
            var pointer := point-Vector2(0.0,21.0)
            if safe.has_point(pointer) and pointer.distance_to(screen_center) > screen_radius+19.0:
                hazard_center = pointer
        var lane: Vector3 = moments.evasion_target
        if fresh and lane.is_finite() and center.z-lane.z > 3.7 and not camera.is_position_behind(lane):
            var pointer := camera.unproject_position(lane)
            if safe.has_point(pointer) and pointer.distance_to(screen_center) > screen_radius+26.0 and (
                    not hazard_center.is_finite() or pointer.distance_to(hazard_center) > 29.0):
                evasion_center = pointer
    var raised: bool = game.race_state == "COUNTDOWN" or game.race_time < GRID_HANDOFF or (
        moments != null and (moments.nearby_pack_count >= 2 or moments.closest_rival_gap <= 1.6))
    bracket_strength = move_toward(bracket_strength,1.0 if raised else 0.0,maxf(0.0,delta)*7.0)
    show()
    queue_redraw()

func _draw() -> void:
    if evasion_center.is_finite():
        var h := evasion_center
        var upper := PackedVector2Array([h+Vector2(-13,2),h+Vector2(0,-8),h+Vector2(13,2)])
        var lower := PackedVector2Array([h+Vector2(-10,11),h+Vector2(0,3),h+Vector2(10,11)])
        draw_polyline(upper,INK,7.0,true)
        draw_polyline(lower,INK,6.0,true)
        draw_polyline(upper,Color("#9bf4e5"),3.5,true)
        draw_polyline(lower,Color("#9bf4e5"),2.7,true)
    if hazard_center.is_finite():
        var h := hazard_center
        draw_colored_polygon(PackedVector2Array([h+Vector2(0,-13),h+Vector2(13,0),
            h+Vector2(0,19),h+Vector2(-13,0)]),INK)
        draw_colored_polygon(PackedVector2Array([h+Vector2(0,-10),h+Vector2(10,0),
            h+Vector2(0,15),h+Vector2(-10,0)]),HAZARD_ACCENT)
        draw_line(h+Vector2(0,-5),h+Vector2(0,1),INK,2.2,true)
        draw_circle(h+Vector2(0,5),1.3,INK)
    var y := maxf(4.0,screen_center.y-screen_radius-BADGE_HEIGHT-12.0)
    var x := clampf(screen_center.x-badge_width*0.5,4.0,maxf(4.0,size.x-badge_width-4.0))
    var label_rect := Rect2(Vector2(x,y),Vector2(badge_width,BADGE_HEIGHT))
    var pointer := Vector2(clampf(screen_center.x,x+7.0,x+badge_width-7.0),label_rect.end.y)
    if pointer.y < screen_center.y-screen_radius:
        draw_colored_polygon(PackedVector2Array([pointer+Vector2(-6.0,-1.0),
            pointer+Vector2(6.0,-1.0),pointer+Vector2(0.0,7.0)]),INK)
        draw_colored_polygon(PackedVector2Array([pointer+Vector2(-3.2,0.0),
            pointer+Vector2(3.2,0.0),pointer+Vector2(0.0,4.8)]),ACCENT)
    draw_style_box(badge,label_rect)
    var baseline := (BADGE_HEIGHT+FONT.get_ascent(FONT_SIZE)-FONT.get_descent(FONT_SIZE))*0.5
    draw_string(FONT,label_rect.position+Vector2(0.0,baseline),badge_text,
        HORIZONTAL_ALIGNMENT_CENTER,badge_width,FONT_SIZE,ACCENT)

    if bracket_strength > 0.0:
        var scale := Vector2.ONE*(screen_radius+5.0)
        draw_mesh(bracket_mesh,null,Transform2D(0.0,scale,0.0,screen_center),
            Color(1.0,1.0,1.0,bracket_strength))

static func _make_brackets() -> ArrayMesh:
    # One canvas batch for both bands, with a feathered dark outline.
    var radii := PackedFloat32Array([0.80,0.84,0.92,0.95,1.05,1.08,1.16,1.20])
    var colors := [Color(INK,0.0),INK,INK,ACCENT,ACCENT,INK,INK,Color(INK,0.0)]
    var points := PackedVector2Array()
    var tints := PackedColorArray()
    var indices := PackedInt32Array()
    const STEPS := 12
    for side: float in [0.0,PI]:
        var base := points.size()
        for step in STEPS+1:
            var axis := Vector2.from_angle(side+lerpf(-0.52,0.52,float(step)/STEPS))
            for band in radii.size():
                points.append(axis*radii[band])
                tints.append(colors[band])
                if step < STEPS and band < radii.size()-1:
                    var vertex := base+step*radii.size()+band
                    var next := vertex+radii.size()
                    indices.append_array(PackedInt32Array([
                        vertex,next,vertex+1,next,next+1,vertex+1]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points
    arrays[Mesh.ARRAY_COLOR] = tints
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh
