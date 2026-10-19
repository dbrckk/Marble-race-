extends Control
## Two independently tracked multitouch zones; safe when fingers lift out of order.
## INPUT handled in _input rather than _gui_input so other UI controls remain usable.
signal direction_changed(value: float)
signal boost_changed(pressed: bool)
const LEFT_REGION := 0.55
const BOOST_REGION_START := 0.59
const BOOST_REGION_END := 0.87
var joystick_finger := -1
var boost_finger := -1
var joystick_origin := Vector2.ZERO
var joystick_tip := Vector2.ZERO
var steer := 0.0
var boost_pressed := false
var sensitivity := 1.0
var left_handed := false
var enabled := true
var radius := 75.0
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
    if v.y < 0.48:
        return
    if _joystick_side(v.x) and joystick_finger == -1:
        joystick_finger = id
        joystick_origin = at
        joystick_tip = at
        _set_steer(0.0)
    elif _boost_side(v.x) and v.y < 0.89 and boost_finger == -1:
        boost_finger = id
        _set_boost(true)
    queue_redraw()

func _move_finger(id: int, at: Vector2) -> void:
    if id == joystick_finger:
        radius = clampf(get_viewport_rect().size.y*0.115,55.0,104.0)
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

func _draw() -> void:
    if not _controls_allowed():
        return
    var w := size.x
    var h := size.y
    var cx := w* (0.81 if left_handed else 0.19)
    var center := Vector2(cx,h*0.80)
    var scale := maxf(0.7,minf(w/1280.0,h/720.0))
    var r := 80.0*scale
    var base := joystick_origin if joystick_finger >= 0 else center
    draw_circle(base,r,Color(0.07,0.12,0.17,0.32))
    draw_arc(base,r,0,TAU,64,Color(0.90,0.93,0.95,0.55),3.0*scale)
    var knob := joystick_tip if joystick_finger >= 0 else base
    draw_circle(knob,33.0*scale,Color(0.82,0.94,0.99,0.65 if joystick_finger>=0 else 0.34))
    draw_arc(knob,33.0*scale,0,TAU,40,Color.WHITE,2.5*scale)
    var bx := w*(0.19 if left_handed else 0.71)
    var bcenter := Vector2(bx,h*0.80)
    draw_circle(bcenter,65.0*scale,Color(1.0,0.63,0.20,0.82 if boost_pressed else 0.36))
    draw_arc(bcenter,65.0*scale,0,TAU,48,Color(1.0,0.83,0.47,0.92),4.0*scale)
