extends Control
## Real-world circuit briefing, drawn only while choosing a solo perk.
## All paths come from the same TrackPath / physical ShortcutRoute used by
## racing marbles. No fake physics, textures, downloads or extra cameras.
const TRACK_PATH = preload("res://scripts/track_path.gd")
const SHORTCUT = preload("res://scripts/shortcut_route.gd")
const DIRECTOR = preload("res://scripts/race_director.gd")
const START_Z := 12.0
const FINISH_Z := -185.0
const TRACK_COLORS := [
    Color("#dfb77c"), Color("#9be4f1"), Color("#f4a079")]
const SIDE_COLORS := [
    Color("#ecd6a5"), Color("#9be7ff"), Color("#f7b188")]
const BACKGROUND := Color(0.065,0.088,0.12,0.95)

var stage: Node3D
var course := 0
var variation := 0
var drawn_sections := 0

func _ready() -> void:
    name = "PhysicalCourseBriefingMap"
    custom_minimum_size = Vector2(0,178)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true

func configure(owner: Node3D, track: int, next_variation: int) -> void:
    stage = owner
    course = clampi(track,0,2)
    variation = posmod(next_variation,3)
    queue_redraw()

static func hazard_side(track: int, next_variation: int, index: int) -> int:
    if index < 0 or index >= DIRECTOR.EVENT_Z.size():
        return 0
    return -1 if (index+clampi(track,0,2)+posmod(next_variation,3))%2 == 0 else 1

func hazard_side_at(index: int) -> int:
    return hazard_side(course,variation,index)

func hazard_z_at(index: int) -> float:
    return DIRECTOR.event_z_for(course,variation,index)

func describe() -> String:
    var side: String = "RIGHT" if SHORTCUT.side_for(course) > 0 else "LEFT"
    var hazard: String = DIRECTOR.EVENT_NAMES[course]
    var theme: String = ["WOODLAND • FAST ROLLING","GLACIER • ICY CORNERS",
        "FORGE • HOT AIR VENTS"][course]
    return "%s   •   %s   •   %s SHORTCUT" % [theme,hazard,side]

func project(world_z: float, world_x: float) -> Vector2:
    # Main racing lane and bypass are drawn with shared absolute world X.
    var progress: float = clampf((START_Z-world_z)/(START_Z-FINISH_Z),0.0,1.0)
    return Vector2(lerpf(19.0,maxf(20.0,size.x-19.0),progress),
        size.y*0.35-world_x*3.3)

func relief_point(world_z: float) -> Vector2:
    # Show changes in elevation relative to the continuous 8.5% baseline:
    # absolute altitude would hide the interesting local crests and dips.
    var deviation: float = TRACK_PATH.height_at(world_z,course)-(
        world_z*TRACK_PATH.BASE_SLOPE)
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
    if w < 70.0 or h < 50.0:
        return
    var full := Rect2(Vector2(1,1),Vector2(w-2,h-2))
    draw_rect(full,BACKGROUND,true)
    draw_rect(full,Color(0.50,0.67,0.70,0.30),false,1.0)
    var main := PackedVector2Array()
    var detour := PackedVector2Array()
    drawn_sections = 0
    for i in range(65):
        var z: float = lerpf(START_Z,FINISH_Z,float(i)/64.0)
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
    for checkpoint in [-46.0,-106.0,-166.0]:
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
    draw_circle(main[0],6.0,Color("#9bebcf"))
    draw_circle(main[main.size()-1],6.0,Color("#ffde85"))
    # A separate real terrain profile makes the biome's physical hills
    # visible before choosing a perk. This never changes race mechanics.
    var chart_top: float = h*0.752
    draw_rect(Rect2(1.0,chart_top,w-2.0,h-chart_top-1.0),
        Color(0.035,0.055,0.074,0.94),true)
    draw_line(Vector2(19.0,h*0.855),Vector2(w-19.0,h*0.855),
        Color(0.53,0.67,0.72,0.42),1.0)
    var relief := PackedVector2Array()
    for i in range(65):
        var z: float = lerpf(START_Z,FINISH_Z,float(i)/64.0)
        relief.append(relief_point(z))
    draw_polyline(relief,accent.lightened(0.28),2.2,true)
    draw_string(get_theme_default_font(),Vector2(9.0,h-5.0),
        "PHYSICAL TERRAIN  •  RELIEF FROM BASE GRADE",
        HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.69,0.83,0.85,0.84))
