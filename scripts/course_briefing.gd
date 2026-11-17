extends Control
## Circuit schematic used in the briefing and solo results.
## All paths come from the same TrackPath / physical ShortcutRoute used by
## racing marbles. No fake physics, textures, downloads or extra cameras.
signal sector_selected(index: int)

const TRACK_PATH = preload("res://scripts/track_path.gd")
const SHORTCUT = preload("res://scripts/shortcut_route.gd")
const DIRECTOR = preload("res://scripts/race_director.gd")
const KICKERS = preload("res://scripts/arcade_bumpers.gd")
const RARE_ITEMS = preload("res://scripts/race_items.gd")
const ZONES = preload("res://scripts/course_mechanics.gd")
const START_Z := 12.0
const TRACK_COLORS := [
    Color("#dfb77c"), Color("#9be4f1"), Color("#f4a079")]
const SIDE_COLORS := [
    Color("#ecd6a5"), Color("#9be7ff"), Color("#f7b188")]
const BACKGROUND := Color(0.065,0.088,0.12,0.95)
const SECTOR_ACCENT := Color("#ffc18d")
const RELIEF_TOP_RATIO := 0.752

var stage: Node3D
var course := 0
var variation := 0
var drawn_sections := 0
var focused_sector := -1
var allow_sector_selection := false
var finish_z: float

func _ready() -> void:
    name = "PhysicalCourseBriefingMap"
    custom_minimum_size = Vector2(0,178)
    mouse_filter = Control.MOUSE_FILTER_STOP if allow_sector_selection else Control.MOUSE_FILTER_IGNORE
    clip_contents = true

func configure(owner: Node3D, track: int, next_variation: int) -> void:
    stage = owner
    course = clampi(track,0,2)
    variation = posmod(next_variation,3)
    finish_z = stage.FINISH_Z
    focused_sector = -1
    queue_redraw()

func focus_sector(index: int) -> void:
    focused_sector = index
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if not allow_sector_selection or not is_instance_valid(stage):
        return
    var pointer: bool = event is InputEventScreenTouch or (
        event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
    if not pointer or not event.is_pressed() or event.position.y >= size.y*RELIEF_TOP_RATIO:
        return
    var sector := 0
    for checkpoint in stage.CHECKPOINT_Z:
        if event.position.x < project(checkpoint,0.0).x:
            break
        sector += 1
    if sector != focused_sector:
        sector_selected.emit(sector)
    accept_event()

func sector_bounds() -> Vector2:
    var exit: float = finish_z if focused_sector == stage.CHECKPOINT_Z.size() else (
        stage.sector_entry_z(focused_sector+1))
    return Vector2(stage.sector_entry_z(focused_sector),exit)

static func hazard_side(track: int, next_variation: int, index: int) -> int:
    if index < 0 or index >= DIRECTOR.EVENT_Z.size():
        return 0
    return -1 if (index+clampi(track,0,2)+posmod(next_variation,3))%2 == 0 else 1

func hazard_side_at(index: int) -> int:
    return hazard_side(course,variation,index)

func hazard_z_at(index: int) -> float:
    return DIRECTOR.event_z_for(course,variation,index)

func kicker_marker(station: int, side: int) -> Vector2:
    var solo: bool = not is_instance_valid(stage) or not stage.net.is_active()
    var position: Vector3 = KICKERS.placement_at(station,side,course,variation,solo)
    return project(position.z,position.x)

func item_marker(index: int) -> Vector2:
    # Exactly the same absolute world-space placement as the collectible
    # mesh and its 3D pickup check in every one of the nine race layouts.
    var solo: bool = not is_instance_valid(stage) or not stage.net.is_active()
    var position: Vector3 = RARE_ITEMS.placement_at(index,course,variation,solo)
    return project(position.z,position.x)

func zone_marker(index: int) -> Vector2:
    # The briefing and the actual contact-zone geometry use one pure
    # placement function. It forecasts NEXT layout even while a previous
    # built race still exists in the scene.
    var position: Vector3 = ZONES.placement_at(index,course,variation)
    return project(position.z,position.x)

func describe() -> String:
    var side: String = "RIGHT" if SHORTCUT.side_for(course) > 0 else "LEFT"
    var hazard: String = DIRECTOR.EVENT_NAMES[course]
    var theme: String = ["WOODLAND • FAST ROLLING","GLACIER • ICY CORNERS",
        "FORGE • HOT AIR VENTS"][course]
    return "%s   •   %s   •   %s SHORTCUT   •   RAISED BRIDGE" % [theme,hazard,side]

func project(world_z: float, world_x: float) -> Vector2:
    # Main racing lane and bypass are drawn with shared absolute world X.
    var progress: float = clampf((START_Z-world_z)/(START_Z-finish_z),0.0,1.0)
    return Vector2(lerpf(19.0,maxf(20.0,size.x-19.0),progress),
        size.y*0.35-world_x*3.3)

func relief_point(world_z: float) -> Vector2:
    # Show changes in elevation relative to the continuous 8.5% baseline:
    # absolute altitude would hide the interesting local crests and dips.
    var deviation: float = TRACK_PATH.height_at(world_z,course)-(
        world_z*TRACK_PATH.BASE_SLOPE)
    return Vector2(project(world_z,0.0).x,
        size.y*0.855-deviation*size.y*0.074)

func shortcut_relief_point(world_z: float) -> Vector2:
    # The lower graph shows the actual top of the optional bridge beside
    # the original course, not an arbitrary painted rollercoaster curve.
    var altitude: float = TRACK_PATH.height_at(world_z,course)
    if is_instance_valid(stage) and is_instance_valid(stage.shortcut_route):
        altitude = stage.shortcut_route.point_at(world_z).y+0.28
    var deviation: float = altitude-world_z*TRACK_PATH.BASE_SLOPE
    return Vector2(project(world_z,0.0).x,
        size.y*0.855-deviation*size.y*0.074)

func shortcut_point(world_z: float) -> Vector2:
    if is_instance_valid(stage) and is_instance_valid(stage.shortcut_route):
        return project(world_z,stage.shortcut_route.point_at(world_z).x)
    var travel: float = clampf(
        (SHORTCUT.ENTRY_Z-world_z)/(SHORTCUT.ENTRY_Z-SHORTCUT.EXIT_Z),
        0.0,1.0)
    var x: float = TRACK_PATH.center_at(world_z,course)+float(
        SHORTCUT.side_for(course))*sin(PI*travel)*SHORTCUT.OUTER_OFFSET
    return project(world_z,x)

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if not is_instance_valid(stage) or w < 70.0 or h < 50.0:
        return
    var full := Rect2(Vector2(1,1),Vector2(w-2,h-2))
    var chart_top := h*RELIEF_TOP_RATIO
    draw_rect(full,BACKGROUND,true)
    draw_rect(full,Color(0.50,0.67,0.70,0.30),false,1.0)
    var sector_span := Vector2.ZERO
    if focused_sector >= 0:
        var bounds := sector_bounds()
        sector_span = Vector2(project(bounds.x,0.0).x,project(bounds.y,0.0).x)
        draw_rect(Rect2(sector_span.x,24.0,sector_span.y-sector_span.x,chart_top-25.0),
            Color(SECTOR_ACCENT,0.19))
    if allow_sector_selection:
        for checkpoint in stage.CHECKPOINT_Z:
            var x := project(checkpoint,0.0).x
            draw_line(Vector2(x,24.0),Vector2(x,chart_top),Color(0.65,0.77,0.80,0.31),1.0)
    var main := PackedVector2Array()
    var detour := PackedVector2Array()
    drawn_sections = 0
    for i in range(65):
        var z: float = lerpf(START_Z,finish_z,float(i)/64.0)
        main.append(project(z,TRACK_PATH.center_at(z,course)))
        drawn_sections += 1
    for i in range(33):
        var z: float = lerpf(SHORTCUT.ENTRY_Z,SHORTCUT.EXIT_Z,float(i)/32.0)
        detour.append(shortcut_point(z))
    # Schematic underlays: the exterior route is intentionally presented as
    # a separate road rather than a fictional teleporting shortcut icon.
    var accent: Color = TRACK_COLORS[course]
    draw_polyline(main,Color(0.02,0.025,0.04,1.0),17.0,true)
    draw_polyline(main,accent.darkened(0.30),13.0,true)
    draw_polyline(main,accent.lightened(0.20),1.3,true)
    draw_polyline(detour,Color(0.01,0.025,0.04,1.0),10.0,true)
    draw_polyline(detour,SIDE_COLORS[course],6.0,true)
    for checkpoint in stage.CHECKPOINT_Z:
        var dot: Vector2 = project(checkpoint,TRACK_PATH.center_at(checkpoint,course))
        draw_circle(dot,3.4,Color("#e5f4eb"))
    for index in range(DIRECTOR.EVENT_Z.size()):
        var hazard_z: float = hazard_z_at(index)
        var world_x: float = TRACK_PATH.center_at(hazard_z,course)+(
            float(hazard_side_at(index))*3.22)
        var marker: Vector2 = project(hazard_z,world_x)
        draw_circle(marker,6.0,Color(0.15,0.03,0.03,0.9))
        draw_circle(marker,4.0,Color("#ff6d62"))
        draw_circle(marker,1.5,Color("#fff0db"))
    # Two springy edge posts at each of three real racing seam stations.
    # Gold/cyan/coral rings are different from the red timed-hazard markers.
    for station in range(KICKERS.STATION_Z.size()):
        for side in KICKERS.SIDES:
            var point: Vector2 = kicker_marker(station,side)
            draw_circle(point,4.2,Color(0.03,0.07,0.10,0.94))
            draw_circle(point,2.8,KICKERS.COLORS[course])
    # Five physically effective strips, ice patches or Forge vents.
    # Small filled markers distinguish them from red moving gates and
    # the diamond-shaped human-only items without adding a HUD overlay.
    for index in range(ZONES.ZONE_Z.size()):
        var position: Vector2 = zone_marker(index)
        draw_circle(position,3.4,Color(0.02,0.03,0.05,0.96))
        draw_circle(position,2.2,ZONES.TRACK_COLORS[course])
    # Four rare, instant HUMAN-only powerups. The diamond shape is distinct
    # from circular kinetic hazards and bumper posts even on small screens.
    for index in range(RARE_ITEMS.ITEM_Z.size()):
        var position: Vector2 = item_marker(index)
        var color: Color = RARE_ITEMS.COLORS[(index+course)%RARE_ITEMS.COLORS.size()]
        draw_circle(position,6.0,Color(0.015,0.025,0.04,0.97))
        draw_colored_polygon(PackedVector2Array([
            position+Vector2(0.0,-4.8),position+Vector2(4.8,0.0),
            position+Vector2(0.0,4.8),position+Vector2(-4.8,0.0)]),color)
        # Color-independent item names at a phone-safe small-map scale.
        draw_string(get_theme_default_font(),position+Vector2(7.0,3.0),
            RARE_ITEMS.label_at(index,course),
            HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#e5f1e9"))
    draw_circle(main[0],6.0,Color("#9bebcf"))
    draw_circle(main[main.size()-1],6.0,Color("#ffde85"))
    if focused_sector >= 0:
        _draw_sector_marker(sector_span.x,"ENTRY")
        _draw_sector_marker(sector_span.y,"EXIT")
    # A separate real terrain profile makes the biome's physical hills
    # visible before choosing a perk. This never changes race mechanics.
    draw_rect(Rect2(1.0,chart_top,w-2.0,h-chart_top-1.0),
        Color(0.035,0.055,0.074,0.94),true)
    draw_line(Vector2(19.0,h*0.855),Vector2(w-19.0,h*0.855),
        Color(0.53,0.67,0.72,0.42),1.0)
    var relief := PackedVector2Array()
    for i in range(65):
        var z: float = lerpf(START_Z,finish_z,float(i)/64.0)
        relief.append(relief_point(z))
    draw_polyline(relief,accent.lightened(0.28),2.2,true)
    var raised_bridge := PackedVector2Array()
    for i in range(33):
        var z: float = lerpf(SHORTCUT.ENTRY_Z,SHORTCUT.EXIT_Z,float(i)/32.0)
        raised_bridge.append(shortcut_relief_point(z))
    draw_polyline(raised_bridge,SIDE_COLORS[course],2.2,true)
    draw_string(get_theme_default_font(),Vector2(9.0,h-5.0),
        "PHYSICAL TERRAIN  •  RELIEF FROM BASE GRADE",
        HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.69,0.83,0.85,0.84))

func _draw_sector_marker(x: float, caption: String) -> void:
    var font := get_theme_default_font()
    var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
    var label_x := clampf(x-width*0.5,8.0,size.x-width-8.0)
    draw_string(font,Vector2(label_x,20.0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,SECTOR_ACCENT)
    draw_dashed_line(Vector2(x,25.0),Vector2(x,size.y*RELIEF_TOP_RATIO-2.0),SECTOR_ACCENT,2.0,6.0)
