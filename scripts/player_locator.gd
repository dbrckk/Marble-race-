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
const PISTON_ACCENT := Color("#ff9d78")
const VENT_ACCENT := Color("#ffe49f")
const FORGE_MARKER_SCALE := 1.25
const FORGE_MARKER_BOUNDS := Rect2(-17.0,-17.0,34.0,41.0)
const ICE_ACCENT := Color("#9ce7ff")
const ICE_IMPACT_ACCENT := Color("#ffb2b9")
const Air = preload("res://scripts/airtime_director.gd")
const JumpGuides = preload("res://scripts/jump_guides.gd")
const ShortcutRoute = preload("res://scripts/shortcut_route.gd")
const EVASION_ACCENT := Color("#9bf4e5")
const TURBO_ACCENT := Color("#63efff")
const MERGE_ACCENT := Color("#ffd383")

var game: Node3D
var screen_center := Vector2.ZERO
var screen_radius := 0.0
var bracket_strength := 0.0
var badge_text := "YOU"
var badge_width := 58.0
var badge := StyleBoxFlat.new()
var bracket_mesh: ArrayMesh
var hazard_center := Vector2.INF
var hazard_kind := ""
var evasion_center := Vector2.INF
var evasion_tint := EVASION_ACCENT
var ice_arrow_center := Vector2.INF
var ice_arrow_axis := Vector2.ZERO
var ice_impact_center := Vector2.INF
var turbo_center := Vector2.INF
var fork_main_center := Vector2.INF
var fork_bridge_center := Vector2.INF
var merge_rival_center := Vector2.INF
var bank_center := Vector2.INF

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
    hazard_kind = ""
    evasion_center = Vector2.INF
    ice_arrow_center = Vector2.INF
    ice_impact_center = Vector2.INF
    turbo_center = Vector2.INF
    fork_main_center = Vector2.INF
    fork_bridge_center = Vector2.INF
    merge_rival_center = Vector2.INF
    bank_center = Vector2.INF
    badge_text = "YOU"
    if not game.net.is_active() and game.career.league_tier() >= 1:
        badge_text += "  •  "+game.career.league_name()
    badge_width = maxf(58.0,FONT.get_string_size(badge_text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x+18.0)
    hide()

func refresh(delta: float) -> void:
    hazard_center = Vector2.INF
    hazard_kind = ""
    evasion_center = Vector2.INF
    evasion_tint = EVASION_ACCENT
    ice_arrow_center = Vector2.INF
    ice_impact_center = Vector2.INF
    turbo_center = Vector2.INF
    fork_main_center = Vector2.INF
    fork_bridge_center = Vector2.INF
    merge_rival_center = Vector2.INF
    bank_center = Vector2.INF
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
    var freshness: bool = not game.net.is_client() or game.net.local_replica_velocity().is_finite()
    var safe_gutter := Rect2(Vector2(17.0,17.0),size-Vector2(34.0,34.0))
    if game.race_state == "RACING" and game.airtime.ice_impact_seconds > 0.0:
        var impact := projected+Vector2(0.0,screen_radius+15.0)
        if safe_gutter.has_point(impact):
            ice_impact_center = impact
    if game.race_state == "RACING" and freshness and game.airtime.ice_drift_side != 0:
        var toward := camera.unproject_position(center+Vector3.RIGHT*game.airtime.ice_drift_side)
        var screen_axis := (toward-projected).normalized()
        var arrow := projected+screen_axis*(screen_radius+16.0)
        if screen_axis.is_finite() and not screen_axis.is_zero_approx() and safe_gutter.has_point(arrow):
            ice_arrow_center = arrow
            ice_arrow_axis = screen_axis
    if game.race_state == "RACING" and game.cam_mode == 0 and moments != null:
        var obstacle: Vector3 = moments.occluded_hazard
        var safe := Rect2(Vector2(size.x*0.14,size.y*0.23),Vector2(size.x*0.72,size.y*0.52))
        if obstacle.is_finite() and center.z-obstacle.z > 0.7 and not camera.is_position_behind(obstacle) and (
                freshness):
            var point := camera.unproject_position(obstacle)
            var pointer := point-Vector2(0.0,21.0)
            var kind: String = moments.occluded_hazard_kind
            if not kind.is_empty():
                var marker_rect := Rect2(pointer+FORGE_MARKER_BOUNDS.position,FORGE_MARKER_BOUNDS.size)
                var badge_clearance := _badge_rect().grow(5.0)
                if marker_rect.intersects(badge_clearance):
                    pointer.y = badge_clearance.position.y-FORGE_MARKER_BOUNDS.end.y
            if safe.has_point(pointer) and pointer.distance_to(screen_center) > screen_radius+19.0:
                hazard_center = pointer
                hazard_kind = kind
        var lane: Vector3 = moments.evasion_target
        var is_shutter_mark: bool = not lane.is_finite() and moments.occluded_shutter_mark.is_finite()
        var is_passing_mark: bool = not lane.is_finite() and moments.occluded_passing_mark.is_finite()
        if is_shutter_mark:
            lane = moments.occluded_shutter_mark
        elif is_passing_mark:
            lane = moments.occluded_passing_mark
        var exit_gap: bool = moments.glacier_gap_marked or not moments.woodworks_return_threat.is_empty()
        var separation := 2.6 if exit_gap else 3.7
        if is_shutter_mark:
            separation = JumpGuides.SHUTTER_MARK_MIN_DISTANCE
        elif is_passing_mark:
            separation = 3.2
        if freshness and lane.is_finite() and center.z-lane.z > separation and not camera.is_position_behind(lane):
            var pointer := camera.unproject_position(lane)
            if is_shutter_mark or is_passing_mark:
                pointer.y -= 12.0
            if is_passing_mark:
                var badge_clearance := _badge_rect().grow(5.0)
                if Rect2(pointer-Vector2(17,12),Vector2(34,26)).intersects(badge_clearance):
                    pointer.y = badge_clearance.position.y-14.0
            if safe.has_point(pointer) and pointer.distance_to(screen_center) > screen_radius+26.0 and (
                    not hazard_center.is_finite() or pointer.distance_to(hazard_center) > 29.0):
                evasion_center = pointer
                if is_shutter_mark:
                    evasion_tint = JumpGuides.SHUTTER_INK
        if freshness and not hazard_center.is_finite() and not evasion_center.is_finite():
            bank_center = _project_road_mark(camera,center.z,moments.occluded_bank_mark,safe,JumpGuides.BANK_MARK_MIN_DISTANCE)
        var turbo: Vector3 = moments.occluded_opening_turbo
        if freshness and turbo.is_finite() and center.z-turbo.z > 2.3 and (
                is_instance_valid(game.race_items) and game.race_items.items[0].visible and (
                    not camera.is_position_behind(turbo) and not hazard_center.is_finite() and (
                        not evasion_center.is_finite()))):
            var pointer := camera.unproject_position(turbo)-Vector2(0.0,28.0)
            var badge_clearance := _badge_rect().grow(5.0)
            if Rect2(pointer-Vector2(15,15),Vector2(30,33)).intersects(badge_clearance):
                pointer.y = badge_clearance.position.y-18.0
            if safe.has_point(pointer) and pointer.distance_to(screen_center) > screen_radius+23.0:
                turbo_center = pointer
        if freshness and not turbo_center.is_finite():
            fork_bridge_center = _project_road_mark(camera,center.z,moments.occluded_fork_bridge,safe)
            fork_main_center = _project_road_mark(camera,center.z,moments.occluded_fork_main,safe)
            if fork_bridge_center.is_finite() and fork_main_center.is_finite() and (
                    fork_main_center.distance_to(fork_bridge_center) < 32.0):
                fork_main_center = Vector2.INF
        if freshness and game.selected_track == 0 and moments.merge_traffic != 0:
            var rival: RigidBody3D = moments.merge_rival
            var road: Node3D = game.shortcut_route
            if is_instance_valid(rival) and not rival.finished and not rival.eliminated and (
                    road.merge_traffic_lane(center) == moments.merge_traffic and (
                        road.merge_traffic_lane(rival.global_position) == -moments.merge_traffic)):
                var target := rival.global_position+Vector3.UP*0.74
                if not camera.is_position_behind(target):
                    var pin := camera.unproject_position(target)
                    if safe.has_point(pin) and not _badge_rect().grow(14.0).has_point(pin) and (
                            pin.distance_to(screen_center) > screen_radius+21.0 and (
                                pin.distance_to(hazard_center) > 35.0 and pin.distance_to(evasion_center) > 35.0)):
                        merge_rival_center = pin
    var raised: bool = game.race_state == "COUNTDOWN" or game.race_time < GRID_HANDOFF or (
        moments != null and (moments.nearby_pack_count >= 2 or moments.closest_rival_gap <= 1.6))
    bracket_strength = move_toward(bracket_strength,1.0 if raised else 0.0,maxf(0.0,delta)*7.0)
    show()
    queue_redraw()

func _project_road_mark(camera: Camera3D, z: float, target: Vector3, safe: Rect2,
        min_distance := ShortcutRoute.FORK_MARK_MIN_DISTANCE) -> Vector2:
    if not target.is_finite() or z-target.z <= min_distance or (
            camera.is_position_behind(target)):
        return Vector2.INF
    var pointer := camera.unproject_position(target)-Vector2(0.0,15.0)
    var badge_clearance := _badge_rect().grow(5.0)
    if Rect2(pointer-Vector2(16,15),Vector2(32,30)).intersects(badge_clearance):
        pointer.y = badge_clearance.position.y-16.0
    if not safe.has_point(pointer) or pointer.distance_to(screen_center) <= screen_radius+24.0 or (
            pointer.distance_squared_to(hazard_center) < 38.0*38.0 or (
                pointer.distance_squared_to(evasion_center) < 35.0*35.0)):
        return Vector2.INF
    return pointer

func _draw() -> void:
    if ice_impact_center.is_finite():
        var p := ice_impact_center
        var fade: float = clampf(game.airtime.ice_impact_seconds/(Air.ICE_IMPACT_SECONDS*0.55),0.0,1.0)
        var spark := PackedVector2Array([p+Vector2(-12,3),p+Vector2(-5,-5),
            p+Vector2(1,4),p+Vector2(8,-6),p+Vector2(13,1)])
        draw_polyline(spark,Color(INK,fade),7.0,true)
        draw_polyline(spark,Color(ICE_IMPACT_ACCENT,fade),3.5,true)
    if ice_arrow_center.is_finite():
        var axis := ice_arrow_axis
        var cross := axis.orthogonal()
        var tip := ice_arrow_center+axis*8.0
        var heel := ice_arrow_center-axis*4.0
        var chevron := PackedVector2Array([heel+cross*7.0,tip,heel-cross*7.0])
        draw_polyline(chevron,INK,6.0,true)
        draw_polyline(chevron,ICE_ACCENT,3.0,true)
    if evasion_center.is_finite():
        var h := evasion_center
        var upper := PackedVector2Array([h+Vector2(-13,2),h+Vector2(0,-8),h+Vector2(13,2)])
        var lower := PackedVector2Array([h+Vector2(-10,11),h+Vector2(0,3),h+Vector2(10,11)])
        draw_polyline(upper,INK,7.0,true)
        draw_polyline(lower,INK,6.0,true)
        draw_polyline(upper,evasion_tint,3.5,true)
        draw_polyline(lower,evasion_tint,2.7,true)
    if hazard_center.is_finite():
        _draw_hazard_marker()
    if turbo_center.is_finite():
        draw_set_transform(turbo_center)
        draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(14,0),Vector2(0,17),Vector2(-14,0)]),INK)
        draw_colored_polygon(PackedVector2Array([Vector2(0,-12),Vector2(11,0),Vector2(0,13),Vector2(-11,0)]),TURBO_ACCENT)
        draw_colored_polygon(PackedVector2Array([Vector2(2,-8),Vector2(-5,1),Vector2(-1,1),
            Vector2(-3,8),Vector2(5,-2),Vector2(1,-2)]),INK)
        draw_set_transform(Vector2.ZERO)
    if fork_main_center.is_finite():
        _draw_fork_arrow(fork_main_center,Vector2.UP,ShortcutRoute.FORK_MAIN_COLOR)
    if fork_bridge_center.is_finite():
        _draw_fork_arrow(fork_bridge_center,Vector2(0.59,-0.81),ShortcutRoute.FORK_BRIDGE_COLOR)
    if bank_center.is_finite():
        var crest := PackedVector2Array([bank_center+Vector2(-13,6),bank_center+Vector2(-6,-4),
            bank_center+Vector2(6,-4),bank_center+Vector2(13,6)])
        draw_polyline(crest,INK,8.0,true)
        draw_polyline(crest,JumpGuides.SHUTTER_INK,3.5,true)
    if merge_rival_center.is_finite():
        var point := merge_rival_center
        var left := PackedVector2Array([point+Vector2(-6,-8),point+Vector2(-13,-8),
            point+Vector2(-13,8),point+Vector2(-6,8)])
        var right := PackedVector2Array([point+Vector2(6,-8),point+Vector2(13,-8),
            point+Vector2(13,8),point+Vector2(6,8)])
        draw_polyline(left,INK,7.0,true)
        draw_polyline(right,INK,7.0,true)
        draw_polyline(left,MERGE_ACCENT,3.5,true)
        draw_polyline(right,MERGE_ACCENT,3.5,true)
    var label_rect := _badge_rect()
    var pointer := Vector2(clampf(screen_center.x,label_rect.position.x+7.0,label_rect.end.x-7.0),label_rect.end.y)
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

func _draw_fork_arrow(at: Vector2, axis: Vector2, tint: Color) -> void:
    var cross := axis.orthogonal()*8.0
    var tip := at+axis*9.0
    var neck := at+axis
    var tail := at-axis*9.0
    var head := PackedVector2Array([neck-cross,tip,neck+cross])
    draw_polyline(head,INK,8.0,true)
    draw_line(tail,tip,INK,8.0,true)
    draw_polyline(head,tint,3.5,true)
    draw_line(tail,tip,tint,3.5,true)

func _badge_rect() -> Rect2:
    var y := maxf(4.0,screen_center.y-screen_radius-BADGE_HEIGHT-12.0)
    var x := clampf(screen_center.x-badge_width*0.5,4.0,maxf(4.0,size.x-badge_width-4.0))
    return Rect2(x,y,badge_width,BADGE_HEIGHT)

func _draw_hazard_marker() -> void:
    var tint := HAZARD_ACCENT
    if hazard_kind == "PISTON":
        tint = PISTON_ACCENT
    elif hazard_kind == "VENT":
        tint = VENT_ACCENT
    var scale := Vector2.ONE if hazard_kind.is_empty() else Vector2.ONE*FORGE_MARKER_SCALE
    draw_set_transform(hazard_center,0.0,scale)
    draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(13,0),Vector2(0,19),Vector2(-13,0)]),INK)
    draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(10,0),Vector2(0,15),Vector2(-10,0)]),tint)
    if hazard_kind == "PISTON":
        draw_rect(Rect2(-5,-3,10,4),INK)
        draw_line(Vector2(0,1),Vector2(0,6),INK,2.8,true)
    elif hazard_kind == "VENT":
        for x in [-2.5,2.5]:
            var p := Vector2(x,0.0)
            draw_polyline(PackedVector2Array([p+Vector2(-0.8,5.0),p+Vector2(0.9,1.8),
                p+Vector2(-0.9,-0.3),p+Vector2(0.5,-3.3)]),INK,1.8,true)
    elif hazard_kind == "SWEEPING ARM":
        draw_line(Vector2(-6,1),Vector2(6,1),INK,2.2,true)
        draw_polyline(PackedVector2Array([Vector2(-2,-3),Vector2(-6,1),Vector2(-2,5)]),INK,2.2,true)
        draw_polyline(PackedVector2Array([Vector2(2,-3),Vector2(6,1),Vector2(2,5)]),INK,2.2,true)
    else:
        draw_line(Vector2(0,-5),Vector2(0,1),INK,2.2,true)
        draw_circle(Vector2(0,5),1.3,INK)
    draw_set_transform(Vector2.ZERO)

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
