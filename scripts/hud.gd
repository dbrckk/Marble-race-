extends CanvasLayer
## Native Godot touch UI. Full game remains playable offline and by keyboard.

const TOUCH_CONTROLS = preload("res://scripts/touch_controls.gd")
const FONT_HEAVY = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_REGULAR = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const TEXT := Color("#fff1dc")
const DIM := Color("#c8bbb0")
const ORANGE := Color("#ffb449")
const PANEL := Color(0.085, 0.09, 0.115, 0.93)
const CARD := Color(0.13, 0.14, 0.17, 0.97)
const PERKS := [
    ["Lead Core", "HEAVY & STEADY", "Extra mass to push through traffic."],
    ["Grip Tape", "STICK TO THE TRACK", "Grip the wood and hold your line."],
    ["Bounce Back", "BOUNCE BETTER", "Spring off posts with more energy."],
    ["Aerodynamic", "LOWER DRAG", "Carry more speed through the course."],
    ["Sticky Magnet", "PACK POWER", "Draw nearby rivals into your wake."],
    ["Head Start", "JUMP THE GUN", "Begin a few metres ahead of the pack."]
]

var game: Node3D
var root: Control
var menu_layer: Control
var perks_layer: Control
var hud_layer: Control
var results_layer: Control
var clock_label: Label
var place_label: Label
var remaining_label: Label
var leaderboard: Label
var boost_label: Label
var speed_label: Label
var fps_label: Label
var quality_button: Button
var fps_button: Button
var course_progress: ProgressBar
var boost_progress: ProgressBar
var checkpoint_label: Label
var toast_remaining := 0.0
var countdown_label: Label
var selected_name := ""
var select_buttons: Array[Button] = []
var selected_description: Label
var start_button: Button
var label_timer := 0.0
var touch_controls: Control
var sensitivity_button: Button
var hand_button: Button
var sensitivity_index := 1
var left_handed := false
const SENSITIVITIES := [0.70,1.0,1.35]

func attach_game(owner_game: Node3D) -> void:
    game = owner_game
    process_mode = Node.PROCESS_MODE_ALWAYS
    root = Control.new()
    root.name = "HUDRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    _build_menu()
    _build_perks()
    _build_race_hud()
    _build_results()
    _load_controls_config()

func _surface(bg: Color, border: Color = Color(1,1,1,0.09), radius: int = 12) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = bg
    style.set_corner_radius_all(radius)
    style.border_color = border
    style.set_border_width_all(1)
    style.content_margin_left = 13
    style.content_margin_right = 13
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _text(value: String, size: int = 21, color: Color = TEXT) -> Label:
    var label = Label.new()
    label.text = value
    label.add_theme_font_override("font", FONT_HEAVY if size >= 23 else FONT_REGULAR)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _action(value: String, fill: Color = Color("#343947"), font_color: Color = TEXT) -> Button:
    var button = Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 51)
    button.add_theme_font_override("font", FONT_HEAVY)
    button.add_theme_font_size_override("font_size", 23)
    button.add_theme_color_override("font_color", font_color)
    button.add_theme_color_override("font_hover_color", font_color)
    button.add_theme_stylebox_override("normal", _surface(fill))
    button.add_theme_stylebox_override("hover", _surface(fill.lightened(0.12)))
    button.add_theme_stylebox_override("pressed", _surface(fill.darkened(0.18)))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.pressed.connect(func(): game.audio.ui_click())
    return button

func _shade() -> ColorRect:
    var shade = ColorRect.new()
    shade.color = Color(0.035,0.025,0.030,0.60)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    return shade

func _column(gap: int = 12) -> VBoxContainer:
    var col = VBoxContainer.new()
    col.add_theme_constant_override("separation", gap)
    return col

func _panel() -> PanelContainer:
    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _surface(PANEL, Color(1,1,1,0.13), 18))
    return panel

func _build_menu() -> void:
    menu_layer = Control.new()
    menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(menu_layer)
    var dark = ColorRect.new()
    dark.color = Color(0.025,0.015,0.025,0.16)
    dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_layer.add_child(dark)
    var panel = _panel()
    panel.anchor_left = 0.042
    panel.anchor_top = 0.14
    panel.anchor_right = 0.425
    panel.anchor_bottom = 0.87
    menu_layer.add_child(panel)
    var col = _column(13)
    panel.add_child(col)
    col.add_child(_text("THE TABLETOP ROYALE", 15, ORANGE))
    var title = _text("LOST\nMARBLES", 69, Color.WHITE)
    title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.65))
    col.add_child(title)
    col.add_child(_text("Forty glass marbles. One impossible wooden course. Every race is different.", 19, DIM))
    var space = Control.new()
    space.custom_minimum_size = Vector2(0,23)
    col.add_child(space)
    var quick = _action("QUICK PLAY  →", ORANGE, Color("#2a1b13"))
    quick.custom_minimum_size.y = 66
    quick.pressed.connect(show_perks)
    col.add_child(quick)
    var solo = _action("SOLO SHOW  /  PRACTICE", Color("#404650"))
    solo.pressed.connect(show_perks)
    col.add_child(solo)
    col.add_child(_text("40 RACERS   •   1 WINNER   •   PHYSICS FIRST", 14, DIM))
    col.add_child(_text("Drag left thumb to steer • Hold right thumb to boost", 14, DIM))
    col.add_child(_text("FULL COURSE  •  CAREER STATS SAVED", 13, Color("#9fabb1")))
    var career = _text("RACES %d   |   WINS %d   |   BEST RANK #%d" % [game.total_races,game.total_wins,game.personal_best_rank],14,DIM)
    career.name = "CareerStats"
    col.add_child(career)
    var sound = _action("SOUND: " + ("ON" if game.audio.enabled else "OFF"), Color("#292e39"))
    sound.custom_minimum_size.y = 37
    sound.pressed.connect(func():
        var active = game.audio.toggle_sound()
        sound.text = "SOUND: ON" if active else "SOUND: OFF"
    )
    col.add_child(sound)
    # Visual options stay outside the menu card to leave the launch actions readable.
    quality_button = _action("GRAPHICS: " + game.QUALITY_NAMES[game.graphics_quality],Color(0.13,0.18,0.22,0.86))
    quality_button.add_theme_font_size_override("font_size",17)
    quality_button.anchor_left = 0.76
    quality_button.anchor_right = 0.975
    quality_button.anchor_top = 0.755
    quality_button.anchor_bottom = 0.830
    quality_button.pressed.connect(func():
        game.set_graphics_quality((game.graphics_quality+1)%3)
        quality_button.text = "GRAPHICS: " + game.QUALITY_NAMES[game.graphics_quality]
    )
    menu_layer.add_child(quality_button)
    fps_button = _action("FPS DISPLAY: " + ("ON" if game.show_fps else "OFF"),Color(0.13,0.18,0.22,0.86))
    fps_button.add_theme_font_size_override("font_size",17)
    fps_button.anchor_left = 0.76
    fps_button.anchor_right = 0.975
    fps_button.anchor_top = 0.855
    fps_button.anchor_bottom = 0.925
    fps_button.pressed.connect(func():
        fps_button.text = "FPS DISPLAY: " + ("ON" if game.toggle_fps_overlay() else "OFF")
    )
    menu_layer.add_child(fps_button)
    sensitivity_button = _action("STEERING: NORMAL",Color(0.13,0.18,0.22,0.86))
    sensitivity_button.add_theme_font_size_override("font_size",16)
    sensitivity_button.anchor_left = 0.76
    sensitivity_button.anchor_right = 0.975
    sensitivity_button.anchor_top = 0.555
    sensitivity_button.anchor_bottom = 0.630
    sensitivity_button.pressed.connect(_sensitivity_pressed)
    menu_layer.add_child(sensitivity_button)
    hand_button = _action("LAYOUT: RIGHT-HAND",Color(0.13,0.18,0.22,0.86))
    hand_button.add_theme_font_size_override("font_size",16)
    hand_button.anchor_left = 0.76
    hand_button.anchor_right = 0.975
    hand_button.anchor_top = 0.655
    hand_button.anchor_bottom = 0.730
    hand_button.pressed.connect(_hand_pressed)
    menu_layer.add_child(hand_button)

func _build_perks() -> void:
    perks_layer = Control.new()
    perks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(perks_layer)
    perks_layer.add_child(_shade())
    var panel = _panel()
    panel.anchor_left = 0.125
    panel.anchor_top = 0.055
    panel.anchor_right = 0.875
    panel.anchor_bottom = 0.945
    perks_layer.add_child(panel)
    var col = _column(12)
    panel.add_child(col)
    var header = _text("PICK YOUR PERK", 39)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(header)
    var sub = _text("Choose a power before the race. Physics decides the rest.", 17, DIM)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(sub)
    var grid = GridContainer.new()
    grid.columns = 3
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    col.add_child(grid)
    for info in PERKS:
        var item = _action(info[0].to_upper() + "\n\n" + info[1], CARD)
        item.custom_minimum_size = Vector2(232, 123)
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        item.add_theme_font_size_override("font_size", 16)
        item.pressed.connect(_choose_perk.bind(info[0]))
        grid.add_child(item)
        select_buttons.append(item)
    selected_description = _text("Select one of the six perks.", 17, DIM)
    selected_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(selected_description)
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 13)
    col.add_child(row)
    var back = _action("← BACK", Color("#404650"))
    back.custom_minimum_size.x = 180
    back.pressed.connect(show_menu)
    row.add_child(back)
    start_button = _action("START RACE  →", ORANGE, Color("#2a1b13"))
    start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_button.disabled = true
    start_button.pressed.connect(func(): game.start_race(selected_name))
    row.add_child(start_button)

func _choose_perk(value: String) -> void:
    selected_name = value
    for i in range(PERKS.size()):
        var active = PERKS[i][0] == value
        select_buttons[i].add_theme_stylebox_override("normal", _surface(Color("#795329") if active else CARD, ORANGE if active else Color(1,1,1,0.08), 12))
    for p in PERKS:
        if p[0] == value:
            selected_description.text = value.to_upper() + "  —  " + p[2]
    start_button.disabled = false

func _small_panel_text(initial: String, size: int, anchor: Rect2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var panel = _panel()
    panel.anchor_left = anchor.position.x
    panel.anchor_top = anchor.position.y
    panel.anchor_right = anchor.end.x
    panel.anchor_bottom = anchor.end.y
    hud_layer.add_child(panel)
    var label = _text(initial, size)
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    panel.add_child(label)
    return label

func _progress_bar(fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 0.0
    bar.show_percentage = false
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color("#19212b")
    bg.set_corner_radius_all(6)
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.set_corner_radius_all(6)
    bar.add_theme_stylebox_override("background",bg)
    bar.add_theme_stylebox_override("fill",fill)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return bar

func _build_race_hud() -> void:
    hud_layer = Control.new()
    hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(hud_layer)

    clock_label = _small_panel_text("00:00.00", 23, Rect2(0.016,0.025,0.155,0.081))
    place_label = _small_panel_text("40th", 22, Rect2(0.016,0.115,0.155,0.082))
    speed_label = _small_panel_text("00  SPEED", 17, Rect2(0.016,0.21,0.155,0.066))
    remaining_label = _small_panel_text("0 / 40 FINISHED", 19, Rect2(0.355,0.02,0.290,0.080), HORIZONTAL_ALIGNMENT_CENTER)
    leaderboard = _small_panel_text("LEADERBOARD", 16, Rect2(0.835,0.025,0.150,0.33))
    fps_label = _small_panel_text("FPS --",16,Rect2(0.865,0.39,0.119,0.060))
    fps_label.get_parent().visible = game.show_fps
    course_progress = _progress_bar(Color("#e9ac5d"))
    course_progress.name = "CourseProgress"
    course_progress.anchor_left = 0.355
    course_progress.anchor_right = 0.645
    course_progress.anchor_top = 0.109
    course_progress.anchor_bottom = 0.134
    hud_layer.add_child(course_progress)
    boost_progress = _progress_bar(Color("#91e6e6"))
    boost_progress.name = "BoostCharge"
    boost_progress.anchor_left = 0.665
    boost_progress.anchor_right = 0.915
    boost_progress.anchor_top = 0.637
    boost_progress.anchor_bottom = 0.660
    hud_layer.add_child(boost_progress)
    countdown_label = _text("3", 86, ORANGE)
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    countdown_label.anchor_left = 0.35
    countdown_label.anchor_right = 0.65
    countdown_label.anchor_top = 0.27
    countdown_label.anchor_bottom = 0.59
    hud_layer.add_child(countdown_label)
    checkpoint_label = _text("", 42, ORANGE)
    checkpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    checkpoint_label.anchor_left = 0.25
    checkpoint_label.anchor_right = 0.75
    checkpoint_label.anchor_top = 0.30
    checkpoint_label.anchor_bottom = 0.42
    checkpoint_label.visible = false
    hud_layer.add_child(checkpoint_label)

    # Floating left joystick + independent right-side boost. Full screen touch
    # pointer IDs protect against releases of unrelated fingers.
    touch_controls = TOUCH_CONTROLS.new()
    touch_controls.name = "MultitouchJoystickAndBoost"
    hud_layer.add_child(touch_controls)
    touch_controls.configure(game)
    touch_controls.direction_changed.connect(func(v: float): game.change_steer(v))
    touch_controls.boost_changed.connect(func(v: bool): game.change_boost(v))
    boost_label = _text("BOOST 100%", 16, ORANGE)
    boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boost_label.anchor_left = 0.665
    boost_label.anchor_right = 0.915
    boost_label.anchor_top = 0.603
    boost_label.anchor_bottom = 0.636
    hud_layer.add_child(boost_label)
    var build_label := _text("CONTROLS v0.11  /  ANALOG",13,Color("#c7d4db"))
    build_label.anchor_left = 0.31
    build_label.anchor_right = 0.65
    build_label.anchor_top = 0.931
    build_label.anchor_bottom = 0.972
    build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_layer.add_child(build_label)
    var cam_button = _action("CAMERA", Color("#353944"))
    cam_button.anchor_left = 0.790
    cam_button.anchor_right = 0.900
    cam_button.anchor_top = 0.525
    cam_button.anchor_bottom = 0.600
    cam_button.pressed.connect(func(): game.cycle_camera())
    hud_layer.add_child(cam_button)
    var pause_button = _action("Ⅱ", Color("#353944"))
    pause_button.anchor_left = 0.920
    pause_button.anchor_right = 0.982
    pause_button.anchor_top = 0.525
    pause_button.anchor_bottom = 0.600
    pause_button.pressed.connect(_toggle_pause)
    hud_layer.add_child(pause_button)

func _load_controls_config() -> void:
    var settings := ConfigFile.new()
    if settings.load("user://marble_settings.cfg") == OK:
        sensitivity_index = clampi(int(settings.get_value("controls","sensitivity",1)),0,2)
        left_handed = bool(settings.get_value("controls","left_handed",false))
    touch_controls.sensitivity = SENSITIVITIES[sensitivity_index]
    touch_controls.left_handed = left_handed
    sensitivity_button.text = "STEERING: " + ["SOFT","NORMAL","SHARP"][sensitivity_index]
    hand_button.text = "LAYOUT: LEFT-HAND" if left_handed else "LAYOUT: RIGHT-HAND"

func _save_controls_config() -> void:
    var settings := ConfigFile.new()
    settings.load("user://marble_settings.cfg")
    settings.set_value("controls","sensitivity",sensitivity_index)
    settings.set_value("controls","left_handed",left_handed)
    settings.save("user://marble_settings.cfg")

func _sensitivity_pressed() -> void:
    sensitivity_index = (sensitivity_index+1)%3
    touch_controls.sensitivity = SENSITIVITIES[sensitivity_index]
    sensitivity_button.text = "STEERING: " + ["SOFT","NORMAL","SHARP"][sensitivity_index]
    _save_controls_config()

func _hand_pressed() -> void:
    left_handed = not left_handed
    touch_controls.release_all()
    touch_controls.left_handed = left_handed
    hand_button.text = "LAYOUT: LEFT-HAND" if left_handed else "LAYOUT: RIGHT-HAND"
    _save_controls_config()

func _toggle_pause() -> void:
    if game.race_state != "RACING":
        return
    get_tree().paused = not get_tree().paused
    if get_tree().paused:
        touch_controls.release_all()
        countdown_label.text = "PAUSED"
        countdown_label.visible = true
    else:
        countdown_label.visible = false

func _build_results() -> void:
    results_layer = Control.new()
    results_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(results_layer)
    results_layer.add_child(_shade())
    var panel = _panel()
    panel.anchor_left = 0.23
    panel.anchor_right = 0.77
    panel.anchor_top = 0.12
    panel.anchor_bottom = 0.89
    results_layer.add_child(panel)
    var col = _column(17)
    panel.add_child(col)
    var title = _text("RACE COMPLETE", 40, ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    var summary = _text("", 22)
    summary.name = "Summary"
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(summary)
    var replay = _action("RACE AGAIN", ORANGE, Color("#251b0d"))
    replay.pressed.connect(func(): game.restart_race())
    col.add_child(replay)
    var change = _action("CHANGE PERK", Color("#343b47"))
    change.pressed.connect(show_perks)
    col.add_child(change)
    var menu = _action("MAIN MENU", Color("#343b47"))
    menu.pressed.connect(func(): game.return_to_menu())
    col.add_child(menu)

func _hide_all() -> void:
    if is_instance_valid(touch_controls):
        touch_controls.release_all()
    menu_layer.visible = false
    perks_layer.visible = false
    hud_layer.visible = false
    results_layer.visible = false

func show_menu() -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    menu_layer.visible = true
    var stats := menu_layer.find_child("CareerStats",true,false) as Label
    if stats:
        stats.text = "RACES %d   |   WINS %d   |   BEST RANK #%d" % [game.total_races,game.total_wins,game.personal_best_rank]

func show_perks() -> void:
    _hide_all()
    perks_layer.visible = true

func show_race_ui() -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    hud_layer.visible = true

func show_countdown(value: String) -> void:
    countdown_label.text = value
    countdown_label.visible = true

func hide_countdown() -> void:
    countdown_label.visible = false

func update_hud() -> void:
    if toast_remaining > 0.0:
        toast_remaining -= get_process_delta_time()
        checkpoint_label.visible = toast_remaining > 0.0
        checkpoint_label.modulate.a = minf(1.0, toast_remaining * 1.7)
    label_timer += get_process_delta_time()
    if label_timer < 0.11:
        return
    label_timer = 0.0
    if not is_instance_valid(game.player):
        return
    var seconds = int(game.race_time)
    var centi = int((game.race_time - float(seconds)) * 100.0)
    clock_label.text = "%02d:%02d.%02d" % [seconds / 60, seconds % 60, centi]
    var place = game.player_rank()
    place_label.text = "#%d / 40" % place
    remaining_label.text = "%d / 40 FINISHED" % game.racer_finish_order.size()
    boost_label.text = "BOOST %d%%" % int(game.boost_energy * 100.0)
    speed_label.text = "%02d  SPEED" % int(game.player.linear_velocity.length() * 3.6)
    if game.show_fps:
        var measured := Engine.get_frames_per_second()
        fps_label.text = "FPS %d" % measured
        fps_label.add_theme_color_override("font_color",
            Color("#ffb7a5") if measured < 30 else Color("#d4f8e3"))
    course_progress.value = clampf((-game.player.global_position.z/absf(game.FINISH_Z))*100.0,0.0,100.0)
    boost_progress.value = game.boost_energy*100.0
    var ranking = game.get_rankings()
    var table = "POSITION\n"
    for i in range(min(7,ranking.size())):
        var r = ranking[i]
        table += "%02d  %s%s\n" % [i+1, r.display_name, "  ★" if r.is_player else ""]
    if place > 5:
        table += "…\n%02d  YOU  ★" % place
    leaderboard.text = table

func show_checkpoint(number: int) -> void:
    checkpoint_label.text = "CHECKPOINT %d / 3" % number
    checkpoint_label.modulate.a = 1.0
    checkpoint_label.visible = true
    toast_remaining = 1.55

func show_results(place: int, time: float, ranking: Array) -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    results_layer.visible = true
    var summary = results_layer.find_child("Summary", true, false) as Label
    var leaders = "CAREER  %d RACES  /  %d WINS
BEST FINISH  %s

" % [game.total_races,game.total_wins,("%.2fs" % game.best_finish_time if game.best_finish_time > 0.0 else "--")]
    for i in range(min(5, ranking.size())):
        leaders += "%s  %s\n" % [str(i+1).pad_zeros(2), ranking[i].display_name]
    if summary:
        summary.text = "YOUR POSITION\n#%d / 40\n\nTIME  %.2fs\n\nTOP MARBLES\n%s" % [place, time, leaders]
