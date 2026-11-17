extends Control
## Two independently tracked multitouch zones; safe when fingers lift out of order.
## INPUT handled in _input rather than _gui_input so other UI controls remain usable.
signal direction_changed(value: float)
signal boost_changed(pressed: bool)
const LEFT_REGION := 0.48
const BOOST_REGION_START := 0.54
const BOOST_REGION_END := 0.94
var joystick_finger := -1
var boost_finger := -1
var joystick_origin := Vector2.ZERO
var joystick_tip := Vector2.ZERO
var steer := 0.0
var boost_pressed := false
var sensitivity := 1.0
var left_handed := false
var enabled := true
var boost_percent := 100
var boost_active := false
var tap_sound: AudioStreamPlayer
var game: Node3D

func configure(parent_game: Node3D) -> void:
    game = parent_game
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process_input(true)

func _controls_allowed() -> bool:
    return enabled and is_visible_in_tree() and is_instance_valid(game) and game.race_state in ["RACING","COUNTDOWN"] and not get_tree().paused

func _joystick_side(x: float) -> bool:
    return x > (1.0 - LEFT_REGION) if left_handed else x < LEFT_REGION

func _boost_side(x: float) -> bool:
    return x < 1.0 - BOOST_REGION_START and x > 1.0 - BOOST_REGION_END if left_handed else x > BOOST_REGION_START and x < BOOST_REGION_END

func _input(event: InputEvent) -> void:
    if not _controls_allowed():
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        _finger_event(touch.index,touch.position,touch.pressed)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        _move_finger(drag.index,drag.position)
    elif event is InputEventMouseButton and not OS.has_feature("mobile"):
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_LEFT:
            _finger_event(1000,mouse.position,mouse.pressed)
    elif event is InputEventMouseMotion and joystick_finger == 1000:
        _move_finger(1000,(event as InputEventMouseMotion).position)

func _finger_event(id: int, at: Vector2, pressed: bool) -> void:
    if not pressed:
        if id == joystick_finger:
            joystick_finger = -1
            _set_steer(0.0)
        if id == boost_finger:
            boost_finger = -1
            _set_boost(false)
        queue_redraw()
        return
    var v := at / get_viewport_rect().size
    if v.y < 0.55:
        return
    if _joystick_side(v.x) and joystick_finger == -1:
        joystick_finger = id
        joystick_origin = at
        joystick_tip = at
        _set_steer(0.0)
    elif _boost_side(v.x) and v.y >= 0.69 and boost_finger == -1:
        boost_finger = id
        _set_boost(true)
    queue_redraw()

func _move_finger(id: int, at: Vector2) -> void:
    if id == joystick_finger:
        var radius := steering_radius()
        joystick_tip = joystick_origin + Vector2(clampf(at.x-joystick_origin.x,-radius,radius),0)
        var normalized := (joystick_tip.x-joystick_origin.x)/radius
        var deadzone := 0.10
        var magnitude := maxf(0,absf(normalized)-deadzone)/(1.0-deadzone)
        _set_steer(signf(normalized)*clampf(pow(magnitude,1.20)*sensitivity,0.0,1.0))
        queue_redraw()

func _set_steer(value: float) -> void:
    steer = clampf(value,-1.0,1.0)
    direction_changed.emit(steer)

func _set_boost(pressed: bool) -> void:
    if boost_pressed == pressed:
        return
    boost_pressed = pressed
    boost_changed.emit(pressed)

func release_all() -> void:
    joystick_finger = -1
    boost_finger = -1
    _set_steer(0.0)
    _set_boost(false)
    queue_redraw()

func steering_radius() -> float:
    return clampf(size.y*0.14,66.0,120.0)

func boost_center_fraction() -> float:
    return 0.20 if left_handed else 0.79

func set_boost_state(charge: float, active: bool) -> void:
    var percent := roundi(clampf(charge,0.0,1.0)*100.0)
    if percent == boost_percent and active == boost_active:
        return
    boost_percent = percent
    boost_active = active
    queue_redraw()

func _draw() -> void:
    if not _controls_allowed():
        return
    var scale := maxf(0.7,minf(size.x/1280.0,size.y/720.0))
    var has_steering_finger := joystick_finger >= 0
    var idle_center := Vector2(size.x*(0.79 if left_handed else 0.19),size.y*0.81)
    var base := joystick_origin if has_steering_finger else idle_center
    var radius := steering_radius()
    draw_circle(base,radius,Color(0.06,0.10,0.15,0.30))
    draw_arc(base,radius,0,TAU,52,Color(0.73,0.86,0.96,0.63),2.5*scale,true)
    var rail := Vector2(radius*0.78,0)
    draw_line(base-rail,base+rail,Color(0.75,0.88,0.95,0.42),2.0*scale,true)
    var knob := joystick_tip if has_steering_finger else base
    if has_steering_finger:
        draw_line(base,knob,Color("#a3e7ef"),3.0*scale,true)
    var knob_radius := 28.0*scale
    draw_circle(knob,knob_radius,Color(0.82,0.94,0.99,0.56 if has_steering_finger else 0.24))
    draw_arc(knob,knob_radius,0,TAU,36,Color("#e3f7ff"),2.0*scale,true)
    _draw_boost(Vector2(size.x*boost_center_fraction(),size.y*0.81),scale)

func _draw_boost(center: Vector2, scale: float) -> void:
    var radius := clampf(size.y*0.11,56.0,89.0)*scale
    var tint := Color("#ffd68d") if boost_percent > 3 else Color("#ff9c89")
    var fill := Color(0.08,0.10,0.15,0.76)
    if boost_active:
        fill = Color(0.49,0.28,0.12,0.93)
        draw_arc(center,radius+6.0*scale,0,TAU,48,Color("#ffe8b5"),2.0*scale,true)
    draw_circle(center,radius,fill)
    draw_arc(center,radius,0,TAU,48,Color(0.92,0.88,0.83,0.34),3.0*scale,true)
    if boost_percent > 0:
        draw_arc(center,radius,-PI*0.5,-PI*0.5+TAU*boost_percent/100.0,48,
            tint,5.0*scale,true)
    var title := "RECHARGE" if boost_percent <= 3 and not boost_active else "BOOST"
    _draw_centered_text(center,title,-4.0*scale,roundi(20.0*scale),Color("#fcf8ec"))
    _draw_centered_text(center,"%d%%" % boost_percent,22.0*scale,roundi(19.0*scale),tint)

func _draw_centered_text(center: Vector2, value: String, baseline: float,
        font_size: int, tint: Color) -> void:
    var font := ThemeDB.fallback_font
    var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    draw_string(font,center+Vector2(-width*0.5,baseline),value,
        HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)
