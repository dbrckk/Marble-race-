extends CanvasLayer
## Native Godot touch UI. Full game remains playable offline and by keyboard.

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
var countdown_label: Label
var selected_name := ""
var select_buttons: Array[Button] = []
var selected_description: Label
var start_button: Button
var label_timer := 0.0
var left_pressed := false
var right_pressed := false

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
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _action(value: String, fill: Color = Color("#343947"), font_color: Color = TEXT) -> Button:
    var button = Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 51)
    button.add_theme_font_size_override("font_size", 20)
    button.add_theme_color_override("font_color", font_color)
    button.add_theme_color_override("font_hover_color", font_color)
    button.add_theme_stylebox_override("normal", _surface(fill))
    button.add_theme_stylebox_override("hover", _surface(fill.lightened(0.12)))
    button.add_theme_stylebox_override("pressed", _surface(fill.darkened(0.18)))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
    col.add_child(_text("Android / offline / no account", 13, Color("#9fabb1")))

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

func _build_race_hud() -> void:
    hud_layer = Control.new()
    hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(hud_layer)

    clock_label = _small_panel_text("00:00.00", 23, Rect2(0.016,0.025,0.155,0.081))
    place_label = _small_panel_text("40th", 22, Rect2(0.016,0.115,0.155,0.082))
    remaining_label = _small_panel_text("0 / 40 FINISHED", 19, Rect2(0.355,0.02,0.290,0.080), HORIZONTAL_ALIGNMENT_CENTER)
    leaderboard = _small_panel_text("LEADERBOARD", 16, Rect2(0.79,0.025,0.195,0.39))
    countdown_label = _text("3", 86, ORANGE)
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    countdown_label.anchor_left = 0.35
    countdown_label.anchor_right = 0.65
    countdown_label.anchor_top = 0.27
    countdown_label.anchor_bottom = 0.59
    hud_layer.add_child(countdown_label)

    # Overlay controls support press-and-hold and keyboard in parallel.
    var ctrl_row = HBoxContainer.new()
    ctrl_row.anchor_left = 0.02
    ctrl_row.anchor_right = 0.53
    ctrl_row.anchor_top = 0.862
    ctrl_row.anchor_bottom = 0.985
    ctrl_row.add_theme_constant_override("separation", 14)
    hud_layer.add_child(ctrl_row)
    var left = _action("◀ LEFT", Color(0.17,0.20,0.25,0.81))
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.button_down.connect(func():
        left_pressed = true
        _steer_buttons()
    )
    left.button_up.connect(func():
        left_pressed = false
        _steer_buttons()
    )
    ctrl_row.add_child(left)
    var right = _action("RIGHT ▶", Color(0.17,0.20,0.25,0.81))
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.button_down.connect(func():
        right_pressed = true
        _steer_buttons()
    )
    right.button_up.connect(func():
        right_pressed = false
        _steer_buttons()
    )
    ctrl_row.add_child(right)
    var boost = _action("BOOST  ⚡", ORANGE, Color("#292015"))
    boost.custom_minimum_size.x = 130
    boost.button_down.connect(func(): game.change_boost(true))
    boost.button_up.connect(func(): game.change_boost(false))
    ctrl_row.add_child(boost)

    boost_label = _text("BOOST 100%", 14, ORANGE)
    boost_label.anchor_left = 0.54
    boost_label.anchor_right = 0.72
    boost_label.anchor_top = 0.91
    boost_label.anchor_bottom = 0.975
    hud_layer.add_child(boost_label)
    var cam_button = _action("CAMERA", Color("#353944"))
    cam_button.anchor_left = 0.73
    cam_button.anchor_right = 0.85
    cam_button.anchor_top = 0.895
    cam_button.anchor_bottom = 0.975
    cam_button.pressed.connect(func(): game.cycle_camera())
    hud_layer.add_child(cam_button)
    var pause_button = _action("Ⅱ", Color("#353944"))
    pause_button.anchor_left = 0.89
    pause_button.anchor_right = 0.975
    pause_button.anchor_top = 0.895
    pause_button.anchor_bottom = 0.975
    pause_button.pressed.connect(_toggle_pause)
    hud_layer.add_child(pause_button)

func _steer_buttons() -> void:
    if game:
        game.change_steer(float(int(right_pressed) - int(left_pressed)))

func _toggle_pause() -> void:
    if game.race_state != "RACING":
        return
    get_tree().paused = not get_tree().paused
    if get_tree().paused:
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
    menu_layer.visible = false
    perks_layer.visible = false
    hud_layer.visible = false
    results_layer.visible = false

func show_menu() -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    menu_layer.visible = true

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
    var ranking = game.get_rankings()
    var table = "POSITION\n"
    for i in range(min(7,ranking.size())):
        var r = ranking[i]
        table += "%02d  %s%s\n" % [i+1, r.display_name, "  ★" if r.is_player else ""]
    if place > 7:
        table += "…\n%02d  YOU  ★" % place
    leaderboard.text = table

func show_results(place: int, time: float, ranking: Array) -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    results_layer.visible = true
    var summary = results_layer.find_child("Summary", true, false) as Label
    var leaders = ""
    for i in range(min(5, ranking.size())):
        leaders += "%s  %s\n" % [str(i+1).pad_zeros(2), ranking[i].display_name]
    if summary:
        summary.text = "YOUR POSITION\n#%d / 40\n\nTIME  %.2fs\n\nTOP MARBLES\n%s" % [place, time, leaders]
