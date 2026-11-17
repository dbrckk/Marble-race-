extends CanvasLayer
## Native Godot touch UI. Full game remains playable offline and by keyboard.

const TOUCH_CONTROLS = preload("res://scripts/touch_controls.gd")
const CAREER_TRANSFER = preload("res://scripts/career_transfer.gd")
const RACE_MOMENTS = preload("res://scripts/race_moments.gd")
const COURSE_BRIEFING = preload("res://scripts/course_briefing.gd")
const PROGRESS_RADAR = preload("res://scripts/race_progress_radar.gd")
const RARE_ITEMS = preload("res://scripts/race_items.gd")
const SHORTCUT_ROUTE = preload("res://scripts/shortcut_route.gd")
const VENT_WARNING_SECONDS := 1.55
const FINAL_OBSTACLE_WARNING_SECONDS := 1.40
const SURFACE_CUE_TOP := 0.402
const SURFACE_CUE_BOTTOM := 0.449
const PISTON_WARNING_SECONDS := 2.20
const FONT_HEAVY = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_REGULAR = preload("res://assets/fonts/Rajdhani-Medium.ttf")
const TEXT := Color("#fff1dc")
const DIM := Color("#c8bbb0")
const ORANGE := Color("#ffb449")
const PANEL := Color(0.085, 0.09, 0.115, 0.93)
const CARD := Color(0.13, 0.14, 0.17, 0.97)
const TIME_GAIN := Color("#a7f4d3")
const TIME_LOSS := Color("#ffc18d")
const VISIBLE_TIME_GAP := 0.005
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
const PREMIUM_COLLECTION = preload("res://scripts/temporary_skins.gd")
var menu_layer: Control
var skin_shop_layer: Control
var skin_shop_status: Label
var skin_shop_notice: Label
var skin_ad_button: Button
var skin_purchase_button: Button
var perks_layer: Control
var hud_layer: Control
var results_layer: Control
var pause_layer: Control
var pause_details: Label
var pause_resume_button: Button
var pause_progress: ProgressBar
var pause_obstacle_hint: Label
var lan_layer: Control
var lan_address: LineEdit
var lan_invite: LineEdit
var lan_status: Label
var lan_start_button: Button
var lan_leave_button: Button
var pause_button_ref: Button
var replay_button_ref: Button
var next_layout_button: Button
var result_overview: Label
var results_scroll: ScrollContainer
var results_card: PanelContainer
var sector_results: VBoxContainer
var sector_result_header: Label
var sector_result_row: HBoxContainer
var sector_result_times: Array[Label] = []
var sector_result_gaps: Array[Label] = []
var sector_result_hint: Button
var sector_retry_comparison: Label
var slowest_sector := -1
var sector_map_panel: PanelContainer
var sector_map_title: Label
var sector_map_boundaries: Label
var sector_map_back: Button
var sector_map: Control
var online_leave_layer: Control
var online_stay_button: Button
var clock_label: Label
var place_label: Label
var remaining_label: Label
var leaderboard: Label
var boost_label: Label
var speed_label: Label
var fps_label: Label
var performance_label: Label
var network_quality_label: Label
var ghost_label: Label
var duel_label: Label
var rival_marker: Label3D
var quality_button: Button
var fps_button: Button
var course_progress: ProgressBar
var race_radar: Control
var boost_progress: ProgressBar
var checkpoint_label: Label
var practice_sector_label: Label
var practice_entry_pending := false
var practice_hint_ready := false
var hazard_label: Label
var timed_gate_label: Label
var timed_gate_backdrop: Panel
var rare_item_label: Label
var biome_lane_label: Label
var shortcut_label: Label
var driving_cue_backgrounds: Dictionary[Label,Panel] = {}
var bridge_approach_active := false
var woodworks_guide_label: Label
var woodworks_guide_seen := false
var woodworks_guide_active := false
var woodworks_steered := false
var woodworks_boosted := false
var position_feedback: Label
var race_moment_label: Label
var race_notification_backdrop: Panel
var speed_stripes: Array[ColorRect] = []
var moment_remaining := 0.0
var moment_priority := 0
var final_danger_active := false
var overtake_count := 0
var overtake_chain_seconds := 0.0
var last_seen_rank := -1
var rank_toast_seconds := 0.0
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
var track_buttons: Array[Button] = []
var career_label: Label
var mastery_label: Label
var style_button: Button
var perk_scroll: ScrollContainer
var perk_panel: PanelContainer
var course_briefing
var course_strategy_label: Label
var next_course_button: Button
var backup_layer: Control
var backup_status: Label
var backup_input: TextEdit
var backup_confirm_button: Button
var backup_previous_button: Button
var pending_backup_code := ""
var result_header: Label
var performance_actions: HBoxContainer
var copy_performance: Button
var compare_performance: Button
var performance_text := ""
var performance_copy_request := 0
var performance_report_dialog: Control
var performance_report_input: TextEdit
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
    _build_skin_shop()
    _build_perks()
    _build_race_hud()
    _build_results()
    _build_pause_menu()
    _build_online_lobby()
    _build_online_leave_dialog()
    _build_backup_dialog()
    game.net.lobby_changed.connect(_lan_status_update)
    game.net.session_closed.connect(_lan_status_update)
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
    panel.anchor_left = 0.032
    panel.anchor_top = 0.115
    panel.anchor_right = 0.45
    panel.anchor_bottom = 0.89
    menu_layer.add_child(panel)
    var col = _column(13)
    panel.add_child(col)
    col.add_child(_text("THE TABLETOP ROYALE", 15, ORANGE))
    var title = _text("MARBLE\nRACE", 63, Color.WHITE)
    title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.65))
    col.add_child(title)
    col.add_child(_text("40 glass racers. 3 distinct circuits.\nEarn medals, unlock tracks, improve your records.", 18, DIM))
    var space = Control.new()
    space.custom_minimum_size = Vector2(0,23)
    col.add_child(space)
    var quick = _action("RACE SELECTED COURSE  →", ORANGE, Color("#2a1b13"))
    quick.custom_minimum_size.y = 66
    quick.pressed.connect(show_perks)
    col.add_child(quick)
    var wifi := _action("INTERNET MULTIPLAYER  →",Color("#375d63"))
    wifi.name = "WifiMultiplayer"
    wifi.custom_minimum_size.y = 47
    wifi.add_theme_font_size_override("font_size",20)
    wifi.pressed.connect(show_online_lobby)
    col.add_child(wifi)
    col.add_child(_text("ANALOG STEERING  •  40 MARBLES  •  SOLO / INTERNET", 14, DIM))
    col.add_child(_text("Left thumb: steer   /   Right thumb: boost", 14, DIM))
    var sound = _action("SOUND: " + ("ON" if game.audio.enabled else "OFF"), Color("#292e39"))
    sound.custom_minimum_size.y = 37
    sound.pressed.connect(func():
        var active = game.audio.toggle_sound()
        sound.text = "SOUND: ON" if active else "SOUND: OFF"
    )
    col.add_child(sound)
    # Visual options stay outside the menu card to leave the launch actions readable.
    quality_button = _action("GRAPHICS: " + game.graphics_mode_label(),Color(0.13,0.18,0.22,0.86))
    quality_button.add_theme_font_size_override("font_size",17)
    quality_button.anchor_left = 0.76
    quality_button.anchor_right = 0.975
    quality_button.anchor_top = 0.755
    quality_button.anchor_bottom = 0.830
    quality_button.pressed.connect(func():
        game.set_graphics_quality((game.graphics_setting+1)%4)
        quality_button.text = "GRAPHICS: " + game.graphics_mode_label()
    )
    menu_layer.add_child(quality_button)
    var skins_button := _action("EXCLUSIVE SKINS  ✦",Color("#513c75"))
    skins_button.name = "ExclusiveTemporarySkins"
    skins_button.anchor_left = 0.76
    skins_button.anchor_right = 0.975
    skins_button.anchor_top = 0.345
    skins_button.anchor_bottom = 0.440
    skins_button.add_theme_font_size_override("font_size",17)
    skins_button.pressed.connect(show_skin_shop)
    menu_layer.add_child(skins_button)
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
    var backup_button := _action("SAVE / RESTORE  ↗",Color("#42535a"))
    backup_button.name = "SaveRestore"
    backup_button.anchor_left = 0.488
    backup_button.anchor_right = 0.735
    backup_button.anchor_top = 0.575
    backup_button.anchor_bottom = 0.664
    backup_button.add_theme_font_size_override("font_size",17)
    backup_button.pressed.connect(show_backup_dialog)
    menu_layer.add_child(backup_button)
    _build_track_picker()

func _build_backup_dialog() -> void:
    # Large-touch-target modal for Android without storage permissions.
    backup_layer = Control.new()
    backup_layer.name = "CareerSaveRestoreDialog"
    backup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(backup_layer)
    backup_layer.add_child(_shade())
    var panel := _panel()
    panel.anchor_left = 0.15
    panel.anchor_right = 0.85
    panel.anchor_top = 0.075
    panel.anchor_bottom = 0.925
    backup_layer.add_child(panel)
    var col := _column(9)
    panel.add_child(col)
    var title := _text("KEEP YOUR PROGRESS",32,ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    var explainer := _text(
        "COPY: save your code in Notes, Drive or another app before uninstalling.\\n"+
        "RESTORE: paste your old code and check it before replacing this career.\\n"+
        "Covers medals, ranks, league points, times and marble styles. Not ghosts.",16,DIM)
    explainer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(explainer)
    backup_status = _text("",17,Color("#d1edd8"))
    backup_status.name = "TransferStatus"
    backup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    backup_status.custom_minimum_size.y = 45
    col.add_child(backup_status)
    var tools_row := HBoxContainer.new()
    tools_row.add_theme_constant_override("separation",10)
    col.add_child(tools_row)
    var copy := _action("1. COPY CAREER CODE",Color("#527264"))
    copy.name = "CopyCareerCode"
    copy.custom_minimum_size.y = 53
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.pressed.connect(_copy_backup_code)
    tools_row.add_child(copy)
    backup_previous_button = _action("UNDO PREVIOUS IMPORT",Color("#51596b"))
    backup_previous_button.name = "PreviewLastCareer"
    backup_previous_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    backup_previous_button.add_theme_font_size_override("font_size",17)
    backup_previous_button.custom_minimum_size.y = 53
    backup_previous_button.pressed.connect(_preview_previous_import)
    tools_row.add_child(backup_previous_button)
    backup_input = TextEdit.new()
    backup_input.name = "BackupPasteField"
    backup_input.placeholder_text = "Paste the exported MARBLE-CAREER-V1 code here"
    backup_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    backup_input.custom_minimum_size.y = 115
    backup_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
    backup_input.add_theme_font_size_override("font_size",15)
    col.add_child(backup_input)
    var preview := _action("2. CHECK CODE BEFORE RESTORE",Color("#45616f"))
    preview.name = "CheckCareerCode"
    preview.custom_minimum_size.y = 49
    preview.pressed.connect(_check_backup_code)
    col.add_child(preview)
    backup_confirm_button = _action("3. CONFIRM REPLACE MY CAREER",Color("#7a5145"))
    backup_confirm_button.name = "ConfirmRestoreCareer"
    backup_confirm_button.custom_minimum_size.y = 49
    backup_confirm_button.disabled = true
    backup_confirm_button.pressed.connect(_confirm_restore_backup)
    col.add_child(backup_confirm_button)
    var cancel := _action("BACK TO MAIN MENU",Color("#323b49"))
    cancel.name = "CloseCareerTransfer"
    cancel.custom_minimum_size.y = 48
    cancel.pressed.connect(show_menu)
    col.add_child(cancel)
    backup_layer.visible = false

func show_backup_dialog() -> void:
    if game.net.is_active():
        return
    _hide_all()
    backup_layer.visible = true
    backup_previous_button.disabled = not FileAccess.file_exists(
        game.career.save_path+".before_import")
    pending_backup_code = ""
    backup_confirm_button.disabled = true
    backup_input.text = ""
    backup_status.text = "CURRENT: %d RACES, %d FINISHES, %d / 9 MASTERY." % [
        game.career.starts,game.career.finishes,game.career.mastery_count()]

func _copy_backup_code() -> void:
    pending_backup_code = ""
    backup_confirm_button.disabled = true
    var data: Dictionary = CAREER_TRANSFER.export_career(game.career)
    if not bool(data.get("ok",false)):
        backup_status.text = str(data.get("error","Export failed."))
        return
    var code: String = str(data["code"])
    DisplayServer.clipboard_set(code)
    backup_status.text = ("COPIED %d CHARACTERS! Paste into Notes or Drive NOW.\n"+
        "Do not uninstall until the code is saved outside the game.") % int(data["length"])

func _preview_previous_import() -> void:
    var saved: Dictionary = CAREER_TRANSFER.preview_previous_career(game.career)
    if not bool(saved.get("ok",false)):
        backup_confirm_button.disabled = true
        pending_backup_code = ""
        backup_status.text = str(saved.get("error","Previous save unavailable."))
        return
    backup_input.text = str(saved["code"])
    _check_backup_code()

func _check_backup_code() -> void:
    pending_backup_code = ""
    backup_confirm_button.disabled = true
    var code: String = backup_input.text.strip_edges()
    if code.is_empty():
        code = DisplayServer.clipboard_get().strip_edges()
    var data: Dictionary = CAREER_TRANSFER.preview_code(code)
    if not bool(data.get("ok",false)):
        backup_status.text = str(data.get("error","Invalid backup."))
        return
    pending_backup_code = code
    backup_status.text = ("BACKUP: %d RACES / %d FINISHES / %d STAMPS / %d REP\n"+
        "CURRENT: %d RACES. Confirm only if this is your intended save.") % [
            data["starts"],data["finishes"],data["mastery"],data["league"],
            game.career.starts]
    backup_confirm_button.disabled = false

func _confirm_restore_backup() -> void:
    if pending_backup_code.is_empty() or backup_confirm_button.disabled:
        return
    var result: Dictionary = CAREER_TRANSFER.restore_career(
        game.career,pending_backup_code)
    pending_backup_code = ""
    backup_confirm_button.disabled = true
    if not bool(result.get("ok",false)):
        backup_status.text = str(result.get("error","Restore failed."))
        return
    backup_previous_button.disabled = false
    # The restored career may have fewer circuits unlocked.
    # Rebuild the main menu with a valid course, not a stale locked preview.
    if not game.career.is_unlocked(game.selected_track):
        game.set_track(0)
    backup_status.text = ("RESTORED: %d RACES / %d FINISHES / %d STAMPS.\n"+
        "Your previous career remains as a local rollback copy.") % [
            result["starts"],result["finishes"],result["mastery"]]
    _refresh_career_menu()

func _build_track_picker() -> void:
    var panel := _panel()
    panel.anchor_left = 0.475
    panel.anchor_right = 0.972
    panel.anchor_top = 0.13
    panel.anchor_bottom = 0.535
    menu_layer.add_child(panel)
    var col := _column(5)
    panel.add_child(col)
    col.add_child(_text("CHOOSE YOUR CIRCUIT",23,ORANGE))
    for i in range(game.TRACK_NAMES.size()):
        var button := _action("",Color("#343c44"))
        button.add_theme_font_size_override("font_size",18)
        button.custom_minimum_size.y = 49
        button.pressed.connect(_select_track.bind(i))
        col.add_child(button)
        track_buttons.append(button)
    career_label = _text("",14,DIM)
    col.add_child(career_label)
    _refresh_career_menu()

func _select_track(index: int) -> void:
    if game.set_track(index):
        _refresh_career_menu()

func _refresh_career_menu() -> void:
    if not is_instance_valid(career_label):
        return
    for i in range(track_buttons.size()):
        var available: bool = game.career.is_unlocked(i)
        var best: int = game.career.track_best[i]
        var stars: int = game.career.stars[i]
        var info: String = ("%02d  %s  |  " % [i+1,game.TRACK_NAMES[i]])
        if not available:
            info += "LOCKED"
        elif best == 0:
            info += "NEW"
        else:
            info += "BEST #%d  %.1fs  %s" % [best,game.career.track_time[i],"★".repeat(stars)]
        if available:
            info += "  ·  M%d/3  ·  P%s" % [
                game.career.track_mastery_count(i),
                str(game.career.precision_best[i])+"/3"]
        track_buttons[i].text = info
        track_buttons[i].disabled = not available
        track_buttons[i].add_theme_stylebox_override("normal",
            _surface(Color("#655039") if i == game.selected_track else Color("#29323b"),
            ORANGE if i == game.selected_track else Color(1,1,1,0.09),8))
    career_label.text = "RACES %d   WINS %d   FINISHES %d" % [
        game.career.starts,game.career.victories,game.career.finishes]
    career_label.text += "\nMASTERY  %d/9  ·  MARBLE STYLES  %d/5" % [
        game.career.mastery_count(),game.career.unlocked_style_count()]
    career_label.text += "\nLEAGUE  %s  ·  SOLO FINISHES %d" % [
        game.career.league_progress_label(),game.career.league_races()]
    career_label.text += "\nPRECISION  %d / 9 SKILL STARS  ·  %d PERFECT RUNS" % [
        game.career.precision_best[0]+game.career.precision_best[1]+(
            game.career.precision_best[2]),game.career.precision_perfect_runs]
    if game.career.unlocked < 3:
        career_label.text += "\n" + game.career.next_locked_requirement()

func _build_online_lobby() -> void:
    lan_layer = Control.new()
    lan_layer.name = "WorldOnlineLobby"
    lan_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(lan_layer)
    lan_layer.add_child(_shade())

    var panel := _panel()
    panel.anchor_left = 0.235
    panel.anchor_right = 0.765
    panel.anchor_top = 0.055
    panel.anchor_bottom = 0.945
    lan_layer.add_child(panel)
    var col := _column(7)
    panel.add_child(col)

    var title := _text("MARBLE RACE ONLINE",34,ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    var desc := _text("Worldwide matches · Dedicated authoritative server · 2–4 players",16,DIM)
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(desc)

    lan_status = _text("Choose matchmaking or join with an invitation code.",17,TEXT)
    lan_status.name = "OnlineConnectionStatus"
    lan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lan_status.custom_minimum_size.y = 64
    lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(lan_status)

    lan_address = LineEdit.new()
    lan_address.name = "ServerUrl"
    lan_address.placeholder_text = "Server URL: wss://your-game-server.example"
    lan_address.text = game.net.online_url()
    lan_address.custom_minimum_size.y = 45
    lan_address.add_theme_font_override("font",FONT_REGULAR)
    lan_address.add_theme_font_size_override("font_size",18)
    col.add_child(lan_address)

    var quick := _action("QUICK MATCH — FIND PLAYERS",ORANGE,Color("#281b12"))
    quick.name = "OnlineQuickMatch"
    quick.custom_minimum_size.y = 49
    quick.pressed.connect(func(): _start_online_connection("public"))
    col.add_child(quick)

    var private_create := _action("CREATE PRIVATE ROOM",Color("#41656b"))
    private_create.name = "OnlineCreatePrivate"
    private_create.custom_minimum_size.y = 47
    private_create.pressed.connect(func(): _start_online_connection("private_create"))
    col.add_child(private_create)

    lan_invite = LineEdit.new()
    lan_invite.name = "InviteCode"
    lan_invite.placeholder_text = "6-character invitation code"
    lan_invite.max_length = 6
    lan_invite.custom_minimum_size.y = 44
    lan_invite.add_theme_font_override("font",FONT_REGULAR)
    lan_invite.add_theme_font_size_override("font_size",18)
    col.add_child(lan_invite)

    var join_private := _action("JOIN PRIVATE ROOM",Color("#42636a"))
    join_private.name = "OnlineJoinPrivate"
    join_private.custom_minimum_size.y = 47
    join_private.pressed.connect(func(): _start_online_connection("private_join"))
    col.add_child(join_private)

    var disconnect := _action("DISCONNECT / BACK TO SOLO",Color("#343c46"))
    disconnect.name = "DisconnectOnline"
    disconnect.custom_minimum_size.y = 47
    disconnect.pressed.connect(func():
        if game.net.is_active():
            game.net.leave_room()
        show_menu()
    )
    col.add_child(disconnect)
    lan_layer.visible = false

func _start_online_connection(mode: String) -> void:
    var endpoint := lan_address.text.strip_edges()
    var failure: String = game.net.connect_server(endpoint,mode,lan_invite.text)
    if failure != "":
        _lan_status_update(failure)
    else:
        game.net.set_online_url(endpoint)

func _lan_status_update(message: String) -> void:
    if is_instance_valid(lan_status):
        lan_status.text = message if message != "" else "Disconnected. Choose a new match."

func show_online_lobby() -> void:
    _hide_all()
    lan_layer.visible = true
    if not game.net.is_active():
        _lan_status_update("Public Quick Match or private invite code. Internet required.")

func _leave_multiplayer() -> void:
    if game.net.is_active():
        game.net.leave_room()
    game.return_to_menu()

func _build_skin_shop() -> void:
    skin_shop_layer = Control.new()
    skin_shop_layer.name = "ExclusiveSkinCollection"
    skin_shop_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(skin_shop_layer)
    skin_shop_layer.add_child(_shade())
    var panel := _panel()
    panel.anchor_left = 0.14
    panel.anchor_right = 0.86
    panel.anchor_top = 0.065
    panel.anchor_bottom = 0.935
    skin_shop_layer.add_child(panel)
    var col := _column(9)
    panel.add_child(col)
    var heading := _text("THE EXCLUSIVE COLLECTION",32,ORANGE)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(heading)
    skin_shop_status = _text("No temporary skin active",20,Color("#b9f8e5"))
    skin_shop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(skin_shop_status)
    var rules := _text(
        "10 extraordinary cosmetic skins. Every draw: 10% per skin. " +
        "A reroll can select the same skin again. New unlock REPLACES the " +
        "previous skin and its remaining time. No racing advantages.",
        16,DIM)
    rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(rules)
    var scroller := ScrollContainer.new()
    scroller.name = "TenSkinCatalogueScroll"
    scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    col.add_child(scroller)
    var list := _column(5)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroller.add_child(list)
    for index in range(PREMIUM_COLLECTION.SKINS.size()):
        var definition: Dictionary = PREMIUM_COLLECTION.SKINS[index]
        var skin_label := _text("%02d  ✦  %s   |   %s  |  10%% chance" % [
            index+1,str(definition["name"]),str(definition["fx"]).to_upper()],
            17,Color(str(definition["accent"])))
        skin_label.name = "ExclusiveSkin_%02d" % index
        list.add_child(skin_label)
    var purchase_rules := _text(
        "WATCH A VOLUNTARY REWARDED AD → random skin for 4 hours.\n" +
        "ONE-TIME CONSUMABLE PURCHASE, target price €2 → random skin for " +
        "6 hours. No video. Google Play displays final local price. " +
        "Both offers share the same 10% odds for each of the 10 skins.",
        16,Color("#e9e1c5"))
    purchase_rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(purchase_rules)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation",12)
    col.add_child(actions)
    skin_ad_button = _action("WATCH AD  ·  4 H",Color("#3a6b69"))
    skin_ad_button.name = "VoluntaryRewardedAd"
    skin_ad_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skin_ad_button.add_theme_font_size_override("font_size",18)
    skin_ad_button.pressed.connect(func():
        if not game.monetization.watch():
            skin_shop_notice.text = "Video not available. No skin was awarded."
        refresh_skin_shop())
    actions.add_child(skin_ad_button)
    skin_purchase_button = _action("BUY  €2  ·  6 H",Color("#7a526f"))
    skin_purchase_button.name = "PlayVerifiedSkinPurchase"
    skin_purchase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skin_purchase_button.add_theme_font_size_override("font_size",18)
    skin_purchase_button.pressed.connect(func():
        if not game.monetization.buy():
            skin_shop_notice.text = "Google Play purchase unavailable. No charge."
        refresh_skin_shop())
    actions.add_child(skin_purchase_button)
    skin_shop_notice = _text("",14,DIM)
    skin_shop_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(skin_shop_notice)
    var back := _action("BACK TO MAIN MENU",Color("#343b47"))
    back.custom_minimum_size.y = 42
    back.add_theme_font_size_override("font_size",18)
    back.pressed.connect(show_menu)
    col.add_child(back)
    skin_shop_layer.visible = false
    game.monetization.changed.connect(refresh_skin_shop)

func refresh_skin_shop() -> void:
    if not is_instance_valid(skin_shop_status) or not is_instance_valid(game.skins):
        return
    var index: int = game.skins.active_id()
    skin_shop_status.text = (
        "%s  •  %s remaining" % [
            str(PREMIUM_COLLECTION.SKINS[index]["name"]),
            PREMIUM_COLLECTION.format_time(game.skins.remaining())]
        if index >= 0 else "No exclusive skin active")
    if is_instance_valid(skin_ad_button):
        skin_ad_button.disabled = not game.monetization.can_watch()
    if is_instance_valid(skin_purchase_button):
        skin_purchase_button.disabled = not game.monetization.can_buy()
        skin_purchase_button.text = "BUY  %s  ·  6 H" % game.monetization.displayed_price
    if is_instance_valid(skin_shop_notice):
        skin_shop_notice.text = game.monetization.info

func show_skin_shop() -> void:
    _hide_all()
    refresh_skin_shop()
    skin_shop_layer.visible = true

func _build_perks() -> void:
    perks_layer = Control.new()
    perks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(perks_layer)
    perks_layer.add_child(_shade())
    perk_panel = _panel()
    perk_panel.name = "PerkSelectionPanel"
    perk_panel.anchor_left = 0.125
    perk_panel.anchor_top = 0.055
    perk_panel.anchor_right = 0.875
    perk_panel.anchor_bottom = 0.945
    perks_layer.add_child(perk_panel)

    # Keep the START and BACK buttons always visible on landscape Android.
    # Only the course preview and the six perk descriptions can scroll.
    var shell := _column(8)
    perk_panel.add_child(shell)
    var header := _text("PICK YOUR PERK",32,ORANGE)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shell.add_child(header)
    perk_scroll = ScrollContainer.new()
    perk_scroll.name = "PerkSelectionScroll"
    perk_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    perk_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    perk_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    perk_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    perk_scroll.follow_focus = true
    shell.add_child(perk_scroll)

    var col := _column(8)
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    perk_scroll.add_child(col)
    var sub := _text("Read the course. Choose a marble power. Roll for the podium.",16,DIM)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(sub)

    course_briefing = COURSE_BRIEFING.new()
    course_briefing.name = "PhysicalCourseBriefingMap"
    course_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(course_briefing)
    course_strategy_label = _text("",15,DIM)
    course_strategy_label.name = "RealCourseStrategy"
    course_strategy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(course_strategy_label)
    mastery_label = _text("",15,DIM)
    mastery_label.name = "MasteryChallenges"
    mastery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(mastery_label)
    var grid := GridContainer.new()
    grid.name = "SixSelectablePerks"
    grid.columns = 3
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation",8)
    grid.add_theme_constant_override("v_separation",8)
    col.add_child(grid)
    for info in PERKS:
        var item := _action(info[0].to_upper() + "\n" + info[1],CARD)
        item.custom_minimum_size = Vector2(215,101)
        item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        item.add_theme_font_size_override("font_size",16)
        item.pressed.connect(_choose_perk.bind(info[0]))
        grid.add_child(item)
        select_buttons.append(item)
    selected_description = _text("Select one of the six perks.",16,DIM)
    selected_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(selected_description)
    style_button = _action("MARBLE STYLE: COPPER",Color("#35475a"))
    style_button.name = "UnlockedMarbleStyles"
    style_button.add_theme_font_size_override("font_size",17)
    style_button.custom_minimum_size.y = 41
    style_button.pressed.connect(_cycle_marble_style)
    col.add_child(style_button)

    var footer := HBoxContainer.new()
    footer.name = "FixedPerkActions"
    footer.add_theme_constant_override("separation",13)
    shell.add_child(footer)
    var back := _action("← BACK",Color("#404650"))
    back.custom_minimum_size.x = 180
    back.pressed.connect(show_menu)
    footer.add_child(back)
    start_button = _action("START RACE  →",ORANGE,Color("#2a1b13"))
    start_button.name = "StartRaceAlwaysAccessible"
    start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_button.disabled = true
    start_button.pressed.connect(func(): game.start_race(selected_name))
    footer.add_child(start_button)

func _refresh_mastery_preview() -> void:
    if is_instance_valid(mastery_label):
        mastery_label.text = "MASTER %s:  %s\nPRECISION MEDAL: %s  (%d/3 GATES)\nLEAGUE: %s" % [
            game.track_title(),game.career.mastery_summary(game.selected_track),
            game.career.precision_medal(game.selected_track),
            game.career.precision_best[game.selected_track],
            game.career.league_progress_label()]
    if is_instance_valid(style_button):
        var count: int = game.career.unlocked_style_count()
        style_button.text = "MARBLE: %s   •   %d / 5 STYLES   ↻" % [
            game.career.style_name(),count]
        if count == 1:
            style_button.text = "MARBLE: COPPER   •   AZURE AT 2 MASTERY STAMPS"
        style_button.disabled = count <= 1

func _cycle_marble_style() -> void:
    game.career.cycle_style()
    _refresh_mastery_preview()

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
    remaining_label = _small_panel_text("WOODWORKS • 0 / 40", 19, Rect2(0.335,0.02,0.330,0.080), HORIZONTAL_ALIGNMENT_CENTER)
    leaderboard = _small_panel_text("LEADERBOARD", 16, Rect2(0.79,0.025,0.195,0.18))
    network_quality_label = _small_panel_text("NET: CONNECTING",14,Rect2(0.79,0.32,0.195,0.060))
    network_quality_label.get_parent().visible = false
    ghost_label = _small_panel_text("",14,Rect2(0.02,0.31,0.265,0.051))
    ghost_label.name = "PersonalBestGhostPace"
    ghost_label.get_parent().visible = false
    duel_label = _text("",19,Color("#c4f2e7"))
    duel_label.name = "ClosestPhysicalRival"
    duel_label.anchor_left = 0.32
    duel_label.anchor_right = 0.68
    duel_label.anchor_top = 0.249
    duel_label.anchor_bottom = 0.294
    duel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    duel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    duel_label.add_theme_color_override("font_outline_color",Color("#121820"))
    duel_label.add_theme_constant_override("outline_size",5)
    duel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    duel_label.visible = false
    hud_layer.add_child(duel_label)
    rival_marker = Label3D.new()
    rival_marker.name = "LocalRivalMarker"
    rival_marker.text = "◇"
    rival_marker.font_size = 46
    rival_marker.pixel_size = 0.014
    rival_marker.outline_size = 14
    rival_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    rival_marker.modulate = Color("#83e6ff")
    rival_marker.hide()
    add_child(rival_marker)
    fps_label = _small_panel_text("FPS --",16,Rect2(0.865,0.43,0.119,0.060))
    fps_label.get_parent().visible = game.show_fps
    performance_label = _small_panel_text(
        "SAMPLING FRAMES...",13,Rect2(0.700,0.495,0.284,0.064))
    performance_label.name = "PhonePerformanceTelemetry"
    performance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    performance_label.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
    performance_label.get_parent().visible = game.show_fps
    course_progress = _progress_bar(Color("#e9ac5d"))
    course_progress.name = "CourseProgress"
    course_progress.anchor_left = 0.335
    course_progress.anchor_right = 0.665
    course_progress.anchor_top = 0.109
    course_progress.anchor_bottom = 0.134
    hud_layer.add_child(course_progress)
    race_radar = PROGRESS_RADAR.new()
    race_radar.name = "FortyMarbleRadar"
    race_radar.anchor_left = 0.335
    race_radar.anchor_right = 0.665
    race_radar.anchor_top = 0.136
    race_radar.anchor_bottom = 0.150
    race_radar.configure(game)
    hud_layer.add_child(race_radar)
    hazard_label = _text("",19,Color("#ffd39c"))
    hazard_label.name = "UpcomingHazard"
    hazard_label.anchor_left = 0.32
    hazard_label.anchor_right = 0.68
    hazard_label.anchor_top = 0.150
    hazard_label.anchor_bottom = 0.203
    hazard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hazard_label.visible = false
    hud_layer.add_child(hazard_label)
    shortcut_label = _text("",19,Color("#f9d79a"))
    shortcut_label.name = "ForkAndMergePreview"
    shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shortcut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    shortcut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shortcut_label.anchor_left = 0.26
    shortcut_label.anchor_right = 0.74
    shortcut_label.anchor_top = 0.207
    shortcut_label.anchor_bottom = 0.243
    shortcut_label.visible = false
    hud_layer.add_child(shortcut_label)
    # Dedicated kinetic-hazard predictor: the regular banner may still need
    # to warn about a closer edge shutter in the same physical section.
    timed_gate_backdrop = Panel.new()
    timed_gate_backdrop.name = "UrgentObstacleBackdrop"
    timed_gate_backdrop.anchor_left = 0.237
    timed_gate_backdrop.anchor_right = 0.763
    timed_gate_backdrop.anchor_top = 0.301
    timed_gate_backdrop.anchor_bottom = 0.351
    timed_gate_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    timed_gate_backdrop.add_theme_stylebox_override("panel",
        _surface(Color("#281d24"),Color("#de836b"),8))
    timed_gate_backdrop.hide()
    hud_layer.add_child(timed_gate_backdrop)
    timed_gate_label = _text("",19,Color("#f6d49b"))
    timed_gate_label.name = "PredictedTimedGate"
    timed_gate_label.anchor_left = 0.237
    timed_gate_label.anchor_right = 0.763
    timed_gate_label.anchor_top = 0.302
    timed_gate_label.anchor_bottom = 0.350
    timed_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timed_gate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    timed_gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    timed_gate_label.visible = false
    hud_layer.add_child(timed_gate_label)
    # Keep optional pickups beside the standings so they never cover the
    # central steering cues. The slot also clears the online status panel.
    rare_item_label = _text("",17,Color("#b5eeff"))
    rare_item_label.name = "UpcomingHumanPowerup"
    rare_item_label.anchor_left = 0.735
    rare_item_label.anchor_right = 0.985
    rare_item_label.anchor_top = 0.220
    rare_item_label.anchor_bottom = 0.270
    rare_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rare_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    rare_item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rare_item_label.visible = false
    hud_layer.add_child(rare_item_label)
    biome_lane_label = _text("",17,Color("#b5eeff"))
    biome_lane_label.name = "SurfaceLanePreview"
    biome_lane_label.anchor_left = 0.285
    biome_lane_label.anchor_right = 0.715
    biome_lane_label.anchor_top = SURFACE_CUE_TOP
    biome_lane_label.anchor_bottom = SURFACE_CUE_BOTTOM
    biome_lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    biome_lane_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    biome_lane_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    biome_lane_label.hide()
    hud_layer.add_child(biome_lane_label)
    var cue_surface := _surface(Color("#151d28"),Color("#586579"),7)
    for cue: Label in [hazard_label,shortcut_label,timed_gate_label,rare_item_label,biome_lane_label]:
        cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cue.add_theme_font_override("font",FONT_HEAVY)
        cue.add_theme_color_override("font_outline_color",Color("#10151e"))
        cue.add_theme_constant_override("outline_size",2)
        var background := Panel.new()
        background.name = "ContrastBackground"
        background.mouse_filter = Control.MOUSE_FILTER_IGNORE
        background.show_behind_parent = true
        background.add_theme_stylebox_override("panel",cue_surface)
        background.hide()
        cue.add_child(background)
        driving_cue_backgrounds[cue] = background
        cue.resized.connect(_refresh_driving_cue_background.bind(cue))
    # Performance feedback shares a single card beside the driving view.
    race_notification_backdrop = Panel.new()
    race_notification_backdrop.name = "RaceNotification"
    race_notification_backdrop.anchor_left = 0.016
    race_notification_backdrop.anchor_right = 0.268
    race_notification_backdrop.anchor_top = 0.367
    race_notification_backdrop.anchor_bottom = 0.474
    race_notification_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_notification_backdrop.add_theme_stylebox_override("panel",
        _surface(PANEL,Color(1,1,1,0.20),10))
    race_notification_backdrop.hide()
    hud_layer.add_child(race_notification_backdrop)
    position_feedback = _text("",22,Color("#a7f0d8"))
    position_feedback.name = "RankFeedback"
    race_moment_label = _text("",23,Color("#aaf2e5"))
    race_moment_label.name = "LiveRaceMoment"
    checkpoint_label = _text("",22,ORANGE)
    checkpoint_label.name = "SectorAndPickupFeedback"
    practice_sector_label = _text("",22,TIME_LOSS)
    practice_sector_label.name = "PracticeSectorApproach"
    for label: Label in [position_feedback,race_moment_label,checkpoint_label,practice_sector_label]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        label.offset_left = 10.0
        label.offset_right = -10.0
        label.hide()
        race_notification_backdrop.add_child(label)
    woodworks_guide_label = _small_panel_text("",19,
        Rect2(0.328,0.88,0.344,0.047),HORIZONTAL_ALIGNMENT_CENTER)
    woodworks_guide_label.name = "WoodworksDrivingGuide"
    woodworks_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var guide_panel := woodworks_guide_label.get_parent() as PanelContainer
    guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var guide_style := _surface(Color("#19232f"),Color("#dbb478"),8)
    guide_style.content_margin_top = 3
    guide_style.content_margin_bottom = 3
    guide_panel.add_theme_stylebox_override("panel",guide_style)
    guide_panel.hide()
    # Four noninteractive screen streaks cost only four UI rectangles,
    # keep joystick/boost touch targets clear, and disappear in ECONOMY.
    var streak_x := [0.225,0.250,0.745,0.770]
    for i in range(streak_x.size()):
        var streak := ColorRect.new()
        streak.name = "MotionStreak_%d" % i
        streak.anchor_left = float(streak_x[i])
        streak.anchor_right = float(streak_x[i])+0.006
        streak.anchor_top = 0.35+float(i%2)*0.07
        streak.anchor_bottom = 0.63+float(i%2)*0.07
        streak.color = Color(0.65,0.88,1.0,0.0)
        streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
        streak.visible = false
        hud_layer.add_child(streak)
        speed_stripes.append(streak)
    boost_progress = _progress_bar(Color("#91e6e6"))
    boost_progress.name = "BoostCharge"
    boost_progress.anchor_left = 0.665
    boost_progress.anchor_right = 0.915
    boost_progress.anchor_top = 0.637
    boost_progress.anchor_bottom = 0.660
    hud_layer.add_child(boost_progress)
    countdown_label = _small_panel_text("",28,Rect2(0.016,0.293,0.155,0.067),
        HORIZONTAL_ALIGNMENT_CENTER)
    countdown_label.name = "StartSignal"
    countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    countdown_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    var countdown_panel := countdown_label.get_parent() as PanelContainer
    countdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var countdown_style := _surface(Color("#191d27"),Color("#b1805a"),10)
    countdown_style.content_margin_top = 2.0
    countdown_style.content_margin_bottom = 2.0
    countdown_panel.add_theme_stylebox_override("panel",countdown_style)
    countdown_panel.hide()
    # Floating left joystick + independent right-side boost. Full screen touch
    # pointer IDs protect against releases of unrelated fingers.
    touch_controls = TOUCH_CONTROLS.new()
    touch_controls.name = "MultitouchJoystickAndBoost"
    hud_layer.add_child(touch_controls)
    touch_controls.configure(game)
    touch_controls.direction_changed.connect(func(v: float): game.change_steer(v))
    touch_controls.boost_changed.connect(func(v: bool): game.change_boost(v))
    boost_label = _text("BOOST 100%", 18, ORANGE)
    boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boost_label.anchor_left = 0.665
    boost_label.anchor_right = 0.915
    boost_label.anchor_top = 0.603
    boost_label.anchor_bottom = 0.636
    hud_layer.add_child(boost_label)
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
    pause_button_ref = pause_button

func _load_controls_config() -> void:
    var settings := ConfigFile.new()
    if settings.load("user://marble_settings.cfg") == OK:
        sensitivity_index = clampi(int(settings.get_value("controls","sensitivity",1)),0,2)
        left_handed = bool(settings.get_value("controls","left_handed",false))
        woodworks_guide_seen = bool(settings.get_value("controls","woodworks_guide_seen",false))
    touch_controls.sensitivity = SENSITIVITIES[sensitivity_index]
    touch_controls.left_handed = left_handed
    sensitivity_button.text = "STEERING: " + ["SOFT","NORMAL","SHARP"][sensitivity_index]
    hand_button.text = "LAYOUT: LEFT-HAND" if left_handed else "LAYOUT: RIGHT-HAND"

func _save_controls_config() -> void:
    var settings := ConfigFile.new()
    settings.load("user://marble_settings.cfg")
    settings.set_value("controls","sensitivity",sensitivity_index)
    settings.set_value("controls","left_handed",left_handed)
    settings.set_value("controls","woodworks_guide_seen",woodworks_guide_seen)
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

func _build_pause_menu() -> void:
    pause_layer = Control.new()
    pause_layer.name = "RacePauseMenu"
    pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(pause_layer)
    pause_layer.add_child(_shade())

    var panel := _panel()
    panel.anchor_left = 0.285
    panel.anchor_right = 0.715
    panel.anchor_top = 0.195
    panel.anchor_bottom = 0.830
    pause_layer.add_child(panel)

    var col := _column(12)
    panel.add_child(col)
    var header := _text("RACE PAUSED", 37, ORANGE)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(header)

    pause_details = _text("", 18, TEXT)
    pause_details.name = "PauseDetails"
    pause_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(pause_details)
    var progress_heading := _text("TRACK PROGRESS", 14, DIM)
    progress_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(progress_heading)
    pause_progress = _progress_bar(Color("#f3b45d"))
    pause_progress.name = "PausedRaceProgress"
    pause_progress.custom_minimum_size.y = 12
    col.add_child(pause_progress)

    pause_obstacle_hint = _text("", 16, Color("#edcb9e"))
    pause_obstacle_hint.name = "PausedHazardHint"
    pause_obstacle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_obstacle_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(pause_obstacle_hint)

    var hint := _text("Drag to steer  ·  Hold BOOST  ·  Change CAMERA", 15, DIM)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(hint)

    pause_resume_button = _action("RESUME RACE", ORANGE, Color("#261b10"))
    pause_resume_button.name = "Resume"
    pause_resume_button.pressed.connect(resume_race)
    col.add_child(pause_resume_button)

    var restart := _action("RESTART CURRENT RACE", Color("#4a565c"))
    restart.name = "Restart"
    restart.pressed.connect(_restart_from_pause)
    col.add_child(restart)

    var exit := _action("MAIN MENU", Color("#323943"))
    exit.name = "Exit"
    exit.pressed.connect(_leave_from_pause)
    col.add_child(exit)
    pause_layer.visible = false

func pause_race() -> void:
    if not is_instance_valid(game):
        return
    if game.net.is_active():
        return # Multiplayer sessions cannot freeze the authoritative server.
    if game.race_state not in ["RACING","COUNTDOWN"] or get_tree().paused:
        return
    # Release individual pointers before stopping physics, so boost cannot latch.
    touch_controls.release_all()
    game.change_boost(false)
    game.change_steer(0.0)
    var seconds := int(game.race_time)
    var percentage := int(clampf(-game.player.global_position.z/absf(game.FINISH_Z)*100.0,0.0,100.0)) if is_instance_valid(game.player) else 0
    pause_details.text = "%s   ·   POSITION #%d / 40
TIME %02d:%02d   ·   TRACK %d%%
PERK: %s   ·   BOOST %d%%" % [
        game.track_title(),game.player_rank(),seconds/60,seconds%60,percentage,
        game.selected_perk.to_upper(),int(game.boost_energy*100.0)]
    pause_progress.value = percentage
    var upcoming: Dictionary = {}
    if is_instance_valid(game.player):
        var at: Vector3 = game.player.global_position
        var route: Dictionary = game.shortcut_route.shortcut_hint(at,bridge_approach_active)
        var downstream_limit: float = SHORTCUT_ROUTE.EXIT_Z if route.get("mode","") == "merge" else INF
        upcoming = game.upcoming_hazard(at.z,downstream_limit)
    pause_obstacle_hint.text = (
        "NEXT: %s %s  ·  %d m" % [upcoming.get("kind","EDGE"),upcoming["side"],upcoming["distance"]]
        if not upcoming.is_empty() else "READ THE COURSE  ·  CHOOSE YOUR LINE"
    )
    rival_marker.hide()
    pause_layer.visible = true
    game.performance_budget.suspend()
    get_tree().paused = true

func resume_race() -> void:
    if not is_instance_valid(pause_layer):
        return
    pause_layer.visible = false
    get_tree().paused = false
    touch_controls.release_all()

func _restart_from_pause() -> void:
    resume_race()
    game.retry_current_layout(game.practice_sector)

func _leave_from_pause() -> void:
    resume_race()
    game.return_to_menu()

func _toggle_pause() -> void:
    if game.net.is_active():
        if online_leave_layer.visible:
            _close_online_leave()
        elif game.race_state in ["RACING", "COUNTDOWN"]:
            touch_controls.release_all()
            game.change_steer(0.0)
            game.change_boost(false)
            touch_controls.enabled = false
            online_leave_layer.show()
            online_stay_button.grab_focus()
        return
    if get_tree().paused and pause_layer.visible:
        resume_race()
    else:
        pause_race()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and sector_map_panel.is_visible_in_tree():
        _close_sector_map()
        get_viewport().set_input_as_handled()
        return
    if (event.is_action_pressed("ui_cancel") or (
        event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P
    )) and (game.race_state in ["RACING","COUNTDOWN"]):
        _toggle_pause()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
        if is_instance_valid(game) and is_instance_valid(pause_layer):
            if game.net.is_active():
                game.net.leave_room("Disconnected on backgrounding")
            else:
                pause_race()

func _build_online_leave_dialog() -> void:
    online_leave_layer = Control.new()
    online_leave_layer.name = "OnlineLeaveDialog"
    online_leave_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    online_leave_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(online_leave_layer)
    online_leave_layer.add_child(_shade())

    var panel := _panel()
    panel.anchor_left = 0.29
    panel.anchor_right = 0.71
    panel.anchor_top = 0.30
    panel.anchor_bottom = 0.70
    online_leave_layer.add_child(panel)
    var column := _column(12)
    panel.add_child(column)
    var title := _text("LEAVE ONLINE RACE?", 34, ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var description := _text("The race keeps running while this menu is open.", 21, DIM)
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(description)
    online_stay_button = _action("KEEP RACING", ORANGE, Color("#251b0d"))
    online_stay_button.pressed.connect(_close_online_leave)
    column.add_child(online_stay_button)
    var leave := _action("LEAVE RACE")
    leave.name = "ConfirmLeaveRace"
    leave.pressed.connect(_leave_multiplayer)
    column.add_child(leave)
    online_leave_layer.hide()

func _close_online_leave() -> void:
    if not online_leave_layer.visible:
        return
    online_leave_layer.hide()
    touch_controls.enabled = true

func _build_results() -> void:
    results_layer = Control.new()
    results_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(results_layer)
    results_layer.add_child(_shade())
    var panel = _panel()
    panel.anchor_left = 0.23
    panel.anchor_right = 0.77
    panel.anchor_top = 0.04
    panel.anchor_bottom = 0.96
    results_layer.add_child(panel)
    results_card = panel
    var col = _column(11)
    panel.add_child(col)
    var title = _text("RACE RESULTS", 40, ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    result_header = title
    result_overview = _text("", 24)
    result_overview.name = "RaceResultOverview"
    result_overview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(result_overview)
    _build_sector_results(col)
    # Keep the timing and race actions in view while mastery and rankings scroll.
    var detail_scroll := ScrollContainer.new()
    detail_scroll.name = "RaceResultsScroll"
    results_scroll = detail_scroll
    detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    col.add_child(detail_scroll)
    var summary = _text("", 19)
    summary.name = "Summary"
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.add_child(summary)
    performance_actions = HBoxContainer.new()
    performance_actions.hide()
    col.add_child(performance_actions)
    copy_performance = _action("COPY FPS REPORT")
    copy_performance.name = "CopyPerformanceReport"
    copy_performance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy_performance.add_theme_font_size_override("font_size",17)
    copy_performance.pressed.connect(_copy_fps_report)
    performance_actions.add_child(copy_performance)
    compare_performance = _action("TEST ECONOMY")
    compare_performance.name = "CompareGraphicsProfile"
    compare_performance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    compare_performance.add_theme_font_size_override("font_size",17)
    compare_performance.pressed.connect(func():
        var quality := int(game.graphics_setting == 0)
        game.set_graphics_quality(quality)
        quality_button.text = "GRAPHICS: " + game.graphics_mode_label()
        game.retry_current_layout()
    )
    performance_actions.add_child(compare_performance)
    var race_actions := HBoxContainer.new()
    race_actions.add_theme_constant_override("separation", 10)
    col.add_child(race_actions)
    var replay = _action("RETRY SAME LAYOUT", ORANGE, Color("#251b0d"))
    replay.name = "Replay"
    replay.pressed.connect(_retry_from_results)
    replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    race_actions.add_child(replay)
    replay_button_ref = replay
    next_layout_button = _action("NEXT LAYOUT", Color("#454c5a"))
    next_layout_button.name = "NextLayout"
    next_layout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next_layout_button.pressed.connect(func(): game.restart_race())
    race_actions.add_child(next_layout_button)
    next_course_button = _action("NEXT CIRCUIT  →",Color("#4c6b67"))
    next_course_button.pressed.connect(_continue_championship)
    col.add_child(next_course_button)
    var menu = _action("MAIN MENU", Color("#343b47"))
    menu.pressed.connect(_leave_multiplayer)
    col.add_child(menu)
    _build_sector_map()

func _build_sector_results(parent: VBoxContainer) -> void:
    sector_results = _column(4)
    sector_results.name = "SectorResults"
    sector_results.hide()
    parent.add_child(sector_results)
    sector_result_header = _text("",18,DIM)
    sector_result_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sector_results.add_child(sector_result_header)
    sector_result_row = HBoxContainer.new()
    sector_result_row.add_theme_constant_override("separation",6)
    sector_results.add_child(sector_result_row)
    for sector in range(4):
        var cell := PanelContainer.new()
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var style := _surface(CARD,Color(1,1,1,0.09),8)
        style.content_margin_top = 4
        style.content_margin_bottom = 4
        cell.add_theme_stylebox_override("panel",style)
        sector_result_row.add_child(cell)
        var line := _column(0)
        cell.add_child(line)
        var caption := _text("SECTOR %d" % (sector+1),16,DIM)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        line.add_child(caption)
        var time := _text("",23)
        time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        line.add_child(time)
        sector_result_times.append(time)
        var gap := _text("",18)
        gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        line.add_child(gap)
        sector_result_gaps.append(gap)
    sector_retry_comparison = _text("",18)
    sector_retry_comparison.name = "SectorRetryComparison"
    sector_retry_comparison.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sector_results.add_child(sector_retry_comparison)
    sector_result_hint = _action("",Color("#3e3027"),TIME_LOSS)
    sector_result_hint.name = "ViewSlowestSectorMap"
    sector_result_hint.custom_minimum_size.y = 48.0
    sector_result_hint.add_theme_font_size_override("font_size",20)
    sector_result_hint.pressed.connect(_open_sector_map)
    sector_results.add_child(sector_result_hint)

func _build_sector_map() -> void:
    sector_map_panel = _panel()
    sector_map_panel.name = "SectorMapPanel"
    sector_map_panel.anchor_left = 0.13
    sector_map_panel.anchor_right = 0.87
    sector_map_panel.anchor_top = 0.14
    sector_map_panel.anchor_bottom = 0.86
    results_layer.add_child(sector_map_panel)
    var column := _column(10)
    sector_map_panel.add_child(column)
    sector_map_title = _text("",31,TIME_LOSS)
    column.add_child(sector_map_title)
    sector_map_boundaries = _text("",22)
    column.add_child(sector_map_boundaries)
    sector_map = COURSE_BRIEFING.new()
    sector_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(sector_map)
    column.add_child(_text("RED DOTS: MOVING GATES   •   DIAMONDS: ITEMS   •   BRANCH: BRIDGE",18,DIM))
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation",10)
    column.add_child(actions)
    sector_map_back = _action("BACK TO RESULTS")
    sector_map_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sector_map_back.pressed.connect(_close_sector_map)
    actions.add_child(sector_map_back)
    var retry := _action("RETRY SAME LAYOUT",ORANGE,Color("#251b0d"))
    retry.name = "RetryFromSectorMap"
    retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    retry.pressed.connect(_retry_from_results)
    actions.add_child(retry)
    sector_map_panel.hide()

func _open_sector_map() -> void:
    if slowest_sector < 0 or not sector_result_hint.is_visible_in_tree() or game.net.is_active():
        return
    var sector_number := slowest_sector+1
    var entry := "START GRID" if slowest_sector == 0 else "SECTOR %d SIGN" % slowest_sector
    var exit := "FINISH LINE" if slowest_sector == game.CHECKPOINT_Z.size() else (
        "SECTOR %d SIGN" % sector_number)
    sector_map_title.text = "%s  •  LAYOUT %d  •  SECTOR %d  %s VS GHOST" % [
        game.track_title(),game.built_variation+1,sector_number,sector_result_gaps[slowest_sector].text]
    sector_map_boundaries.text = "ENTRY  %s    →    EXIT  %s" % [entry,exit]
    sector_map.configure(game,game.selected_track,game.built_variation)
    sector_map.focus_sector(slowest_sector)
    results_card.hide()
    sector_map_panel.show()
    sector_map_back.grab_focus()

func _close_sector_map() -> void:
    sector_map_panel.hide()
    results_card.show()
    sector_result_hint.grab_focus()

func _retry_from_results() -> void:
    if game.net.is_active():
        show_online_lobby()
    else:
        game.retry_current_layout(slowest_sector)

func _copy_fps_report() -> void:
    if copy_performance.disabled or performance_text.is_empty() or not results_layer.is_visible_in_tree():
        return
    performance_copy_request += 1
    var request := performance_copy_request
    var report := performance_text
    copy_performance.disabled = true
    DisplayServer.clipboard_set(report)
    # Android schedules the clipboard write on its UI thread.
    if OS.get_name() == "Android":
        copy_performance.text = "COPYING..."
        for attempt in range(4):
            await get_tree().create_timer(0.15).timeout
            if request != performance_copy_request:
                return
            if DisplayServer.clipboard_get() == report:
                copy_performance.disabled = false
                copy_performance.text = "REPORT COPIED"
                return
    elif DisplayServer.clipboard_get() == report:
        copy_performance.disabled = false
        copy_performance.text = "REPORT COPIED"
        return
    copy_performance.disabled = false
    copy_performance.text = "COPY FPS REPORT"
    _show_fps_report(report)

func _show_fps_report(report: String) -> void:
    if sector_map_panel.is_visible_in_tree():
        return
    if not is_instance_valid(performance_report_dialog):
        performance_report_dialog = Control.new()
        performance_report_dialog.name = "FpsReportDialog"
        performance_report_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        root.add_child(performance_report_dialog)
        performance_report_dialog.add_child(_shade())
        var panel := _panel()
        panel.anchor_left = 0.09
        panel.anchor_right = 0.91
        panel.anchor_top = 0.11
        panel.anchor_bottom = 0.89
        performance_report_dialog.add_child(panel)
        var column := _column(10)
        panel.add_child(column)
        column.add_child(_text("FPS REPORT",29,ORANGE))
        column.add_child(_text("Clipboard unconfirmed. The full report is below.",18))
        performance_report_input = TextEdit.new()
        performance_report_input.editable = false
        performance_report_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
        performance_report_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
        performance_report_input.add_theme_font_override("font",FONT_REGULAR)
        performance_report_input.add_theme_font_size_override("font_size",19)
        performance_report_input.add_theme_color_override("font_readonly_color",TEXT)
        column.add_child(performance_report_input)
        var close := _action("CLOSE REPORT")
        close.name = "CloseFpsReport"
        close.pressed.connect(performance_report_dialog.hide)
        column.add_child(close)
    performance_report_input.text = report
    performance_report_dialog.show()
    performance_report_input.grab_focus()

func _continue_championship() -> void:
    var next_index: int = game.selected_track + 1
    game.return_to_menu()
    game.set_track(next_index)
    show_perks()

func _hide_all() -> void:
    rival_marker.hide()
    practice_entry_pending = false
    practice_hint_ready = false
    if is_instance_valid(touch_controls):
        touch_controls.release_all()
    if is_instance_valid(online_leave_layer):
        _close_online_leave()
    menu_layer.visible = false
    perks_layer.visible = false
    hud_layer.visible = false
    results_layer.visible = false
    sector_map_panel.hide()
    results_card.show()
    performance_copy_request += 1
    if is_instance_valid(performance_report_dialog):
        performance_report_dialog.hide()
    if is_instance_valid(lan_layer):
        lan_layer.visible = false
    if is_instance_valid(pause_layer):
        pause_layer.visible = false
    if is_instance_valid(backup_layer):
        backup_layer.visible = false
    if is_instance_valid(skin_shop_layer):
        skin_shop_layer.visible = false

func show_menu() -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    _refresh_career_menu()
    menu_layer.visible = true

func show_perks() -> void:
    _hide_all()
    _refresh_mastery_preview()
    if is_instance_valid(course_briefing):
        course_briefing.configure(game,game.selected_track,game.race_variation)
        course_strategy_label.text = course_briefing.describe() + (
            "\nRED = GATES   •   COLORED BRANCH = SHORTCUT   •   DIAMONDS = RARE HUMAN ITEMS   •   LAYOUT %d / 3"
            % (game.race_variation+1))
        if not game.net.is_active():
            course_strategy_label.text += (
                "\nSOLO: FOLLOW A RIVAL TO EARN DRAFT BOOST RECHARGE"
                +"\nPRECISION: CLEANLY SKIM 1 / 2 / 3 MOVING GATES FOR BRONZE / SILVER / GOLD")
        if game.selected_track == 0:
            course_strategy_label.text += (
                "\nSTAY ON THE MAIN TRACK OR TAKE THE RIGHT BRIDGE."
                + " CENTER ALL THREE BRIDGE GATES FOR A DASH.")
        elif game.selected_track == 1:
            course_strategy_label.text += (
                "\nBLUE STRIPS ARE SLIPPERY. KEEP TO THE OPEN LANE FOR GRIP"
                + " OR HOLD YOUR LINE THROUGH THE ICE. THE BRIDGE FORKS LEFT.")
        else:
            course_strategy_label.text += (
                "\nTAKE THE PISTON LANE WHEN OPEN OR PASS ON ITS OTHER SIDE."
                + " WATCH THE VENT FORECAST. THE BRIDGE FORKS RIGHT.")
    if is_instance_valid(perk_scroll):
        perk_scroll.scroll_vertical = 0
    perks_layer.visible = true

func show_race_ui() -> void:
    last_seen_rank = -1
    rank_toast_seconds = 0.0
    moment_remaining = 0.0
    moment_priority = 0
    final_danger_active = false
    overtake_count = 0
    overtake_chain_seconds = 0.0
    rival_marker.hide()
    duel_label.hide()
    toast_remaining = 0.0
    checkpoint_label.hide()
    practice_sector_label.hide()
    race_notification_backdrop.hide()
    woodworks_guide_active = game.selected_track == 0 and not game.net.is_active() and (
        not woodworks_guide_seen and game.career.finishes == 0)
    woodworks_steered = false
    woodworks_boosted = false
    woodworks_guide_label.get_parent().hide()
    if is_instance_valid(race_radar):
        race_radar.reset()
    if is_instance_valid(race_moment_label):
        race_moment_label.visible = false
    for streak in speed_stripes:
        streak.visible = false
    if is_instance_valid(position_feedback):
        position_feedback.visible = false
    bridge_approach_active = false
    biome_lane_label.anchor_top = SURFACE_CUE_TOP
    biome_lane_label.anchor_bottom = SURFACE_CUE_BOTTOM
    if is_instance_valid(shortcut_label):
        shortcut_label.visible = false
    if is_instance_valid(timed_gate_label):
        timed_gate_label.visible = false
    timed_gate_backdrop.hide()
    if is_instance_valid(rare_item_label):
        rare_item_label.visible = false
    biome_lane_label.hide()
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    practice_entry_pending = game.practice_sector >= 0 and not game.net.is_active()
    if practice_entry_pending:
        race_radar.set_practice_entry(game.sector_entry_z(game.practice_sector))
    hud_layer.visible = true
    network_quality_label.get_parent().visible = game.net.role == "client"
    if is_instance_valid(pause_button_ref):
        pause_button_ref.text = "LEAVE" if game.net.is_active() else "Ⅱ"

func show_countdown(value: String) -> void:
    countdown_label.text = value
    countdown_label.add_theme_color_override("font_color",
        Color("#8bf3c5") if value == "GO!" else Color("#ffc481"))
    ghost_label.get_parent().hide()
    countdown_label.get_parent().show()

func hide_countdown() -> void:
    countdown_label.get_parent().hide()

func show_race_moment(title: String, duration: float = 1.1, priority := 0) -> void:
    if not is_instance_valid(race_moment_label) or (moment_remaining > 0.0 and priority < moment_priority):
        return
    race_moment_label.text = title
    race_moment_label.add_theme_color_override("font_color",
        Color("#f6e8b6") if title.contains("FINISH") or title.contains("STRAIGHT") else (
            Color("#a2f3d8") if title.contains("PASS") or title.contains("OVERTAKE") else
            Color("#b5ecff")))
    moment_priority = priority
    moment_remaining = clampf(duration,0.4,2.2)
    _refresh_race_notification()

func show_overtake(count: int, rival_name: String) -> void:
    overtake_count = count+(overtake_count if overtake_chain_seconds > 0.0 else 0)
    overtake_chain_seconds = 0.38
    rank_toast_seconds = 0.0
    position_feedback.hide()
    var title := "CLEAN OVERTAKE!  •  "+rival_name
    if overtake_count > 1:
        title = "DOUBLE PASS!" if overtake_count == 2 else "%d OVERTAKES!" % overtake_count
    show_race_moment(title,1.18,2)

func clear_overtake_feedback() -> void:
    overtake_count = 0
    overtake_chain_seconds = 0.0
    if moment_priority == 2:
        moment_remaining = 0.0
        _refresh_race_notification()

func _update_rival_marker() -> void:
    var moments: RefCounted = game.race_moments
    var rival: RigidBody3D = moments.closest_rival if moments != null else null
    rival_marker.visible = game.race_state == "RACING" and not game.net.is_active() and (
        is_instance_valid(game.player) and not game.player.finished and not game.player.eliminated and
        is_instance_valid(rival) and not rival.finished and not rival.eliminated)
    if rival_marker.visible:
        rival_marker.global_position = rival.global_position+Vector3.UP*0.88
        rival_marker.modulate = Color("#ffd78d") if moments.side_by_side_active else Color("#83e6ff")

func record_woodworks_controls(steer: float, boosting: bool) -> void:
    woodworks_steered = woodworks_steered or absf(steer) >= 0.22
    woodworks_boosted = woodworks_boosted or boosting

func _update_woodworks_guide(route_mode: String, turbo_ahead: bool, urgent: bool) -> void:
    if not woodworks_guide_active or game.race_state != "RACING":
        return
    var panel := woodworks_guide_label.get_parent() as PanelContainer
    if game.net.is_active() or game.player.finished or game.player.eliminated:
        woodworks_guide_active = false
        panel.hide()
        return
    var at: Vector3 = game.player.global_position
    var fork_cleared: bool = route_mode == "merge" or (
        at.z <= SHORTCUT_ROUTE.ENTRY_PORTAL_Z-SHORTCUT_ROUTE.PORTAL_HALF_LENGTH and
        absf(at.x-game.track_center_at(at.z)) < 6.52 and at.y >= game.height_at(at.z)-0.35)
    if woodworks_steered and woodworks_boosted and fork_cleared:
        woodworks_guide_active = false
        panel.hide()
        woodworks_guide_seen = true
        _save_controls_config()
        return
    var prompt := ""
    if not woodworks_steered:
        prompt = "DRAG LEFT OR RIGHT TO STEER" if OS.has_feature("mobile") else "A / D OR DRAG TO STEER"
    elif not woodworks_boosted:
        prompt = "HOLD BOOST WITH YOUR OTHER THUMB" if OS.has_feature("mobile") else "HOLD SPACE OR BOOST TO ACCELERATE"
    elif turbo_ahead:
        prompt = "ROLL THROUGH THE DIAMOND TO ACTIVATE IT"
    elif route_mode == "fork":
        prompt = "AMBER ARROWS LEAD TO THE BRIDGE"
    if woodworks_guide_label.text != prompt:
        woodworks_guide_label.text = prompt
    panel.visible = not urgent and not prompt.is_empty()

func update_hud() -> void:
    var elapsed: float = get_process_delta_time()
    overtake_chain_seconds = maxf(0.0,overtake_chain_seconds-elapsed)
    _update_rival_marker()
    if is_instance_valid(race_radar):
        race_radar.sample(elapsed)
    moment_remaining = maxf(0.0,moment_remaining-elapsed)
    rank_toast_seconds = maxf(0.0,rank_toast_seconds-elapsed)
    toast_remaining = maxf(0.0,toast_remaining-elapsed)
    _refresh_race_notification()
    label_timer += get_process_delta_time()
    if label_timer < 0.11:
        return
    label_timer = 0.0
    if not is_instance_valid(game.player):
        return
    var speed_intensity: float = RACE_MOMENTS.edge_intensity(
        game.race_moments.local_speed,game.boosting,game.graphics_quality) if (
        game.race_moments != null and game.race_state == "RACING") else 0.0
    for line in speed_stripes:
        line.visible = speed_intensity >= 0.01
        line.color = Color(0.65,0.88,1.0,speed_intensity)
    var seconds = int(game.race_time)
    var centi = int((game.race_time - float(seconds)) * 100.0)
    clock_label.text = "%02d:%02d.%02d" % [seconds / 60, seconds % 60, centi]
    # Reuse a single real standings sort for rank and top-three HUD,
    # instead of sorting forty bodies twice every UI update.
    var ranking: Array = game.get_rankings()
    var place: int = ranking.find(game.player)+1
    if game.race_state == "RACING" and last_seen_rank > 0 and abs(place-last_seen_rank) >= 2 and (
        moment_priority != 2 or moment_remaining <= 0.0):
        var gain := last_seen_rank - place
        position_feedback.text = "+%d PLACES" % gain if gain > 0 else "-%d PLACES" % abs(gain)
        position_feedback.add_theme_color_override("font_color",
            Color("#9cf2cb") if gain > 0 else Color("#ffb19c"))
        rank_toast_seconds = 0.95
        _refresh_race_notification()
    last_seen_rank = place
    place_label.text = "#%d / 40" % place
    remaining_label.text = "%s  •  %d FINISHED" % [game.track_title(),game.racer_finish_order.size()]
    var drafting: bool = not game.net.is_active() and game.slipstream != null and (
        game.slipstream.strength >= 0.30)
    boost_label.text = ("BOOST %d%%  •  DRAFT" if drafting else "BOOST %d%%") % (
        int(game.boost_energy*100.0))
    boost_label.add_theme_color_override("font_color",
        Color("#a4f4e5") if drafting else (
            Color("#ffcf82") if game.boost_energy >= 0.25 else Color("#e9746b")))
    speed_label.text = "%02d KM/H" % int(game.player.linear_velocity.length() * 3.6)
    if is_instance_valid(game.best_ghost):
        ghost_label.get_parent().visible = game.best_ghost.replay_available and (
            not game.net.is_active() and not countdown_label.is_visible_in_tree())
        if game.best_ghost.replay_available:
            ghost_label.text = game.best_ghost.gap_text(game.player.global_position)
    # Solo duel indicator: sampled from real 3D positions by RaceMoments
    # (10Hz), with no extra physics queries.
    var duel: RefCounted = game.race_moments
    duel_label.visible = rival_marker.visible
    if duel_label.visible:
        var side: String = ["LEFT","","RIGHT"][duel.closest_rival_side+1]
        var gap_text := ("  •  "+side) if not side.is_empty() else ""
        if not duel.side_by_side_active:
            gap_text += "  •  %.1fm" % duel.closest_rival_gap
        duel_label.text = "%s  %s%s" % [
            "SIDE BY SIDE" if duel.side_by_side_active else (
                "CHASE" if duel.closest_rival_ahead else "DEFEND"),
            duel.closest_rival_name.left(16),gap_text]
        duel_label.add_theme_color_override("font_color",
            Color("#fbdaa4") if duel.side_by_side_active else (
                Color("#f6d8a3") if duel.closest_rival_ahead else Color("#a5e6e2")))
    if game.net.role == "client":
        network_quality_label.get_parent().visible = true
        var quality: String = game.net.quality_text()
        network_quality_label.text = "NET  " + quality
        network_quality_label.add_theme_color_override("font_color",
            Color("#ffac9b") if quality.contains("SLOW") or quality.contains("STALLED") else (
                Color("#ffe1a3") if quality.contains("FAIR") else Color("#b7f5d9")))
    if game.show_fps:
        var measured := Engine.get_frames_per_second()
        fps_label.text = "FPS %d" % measured
        fps_label.add_theme_color_override("font_color",
            Color("#ffb7a5") if measured < 30 else Color("#d4f8e3"))
        if game.performance_budget != null:
            performance_label.text = game.performance_budget.compact_text()
            if not game.performance_budget.report.is_empty():
                performance_label.add_theme_color_override("font_color",
                    Color("#ffbd9c") if float(game.performance_budget.report[
                        "p95_ms"]) > 33.3 else Color("#a8dfd2"))
    course_progress.value = clampf((-game.player.global_position.z/absf(game.FINISH_Z))*100.0,0.0,100.0)
    if game.obstacle_notice > 0.0:
        place_label.add_theme_color_override("font_color",Color("#ffb089"))
    else:
        place_label.add_theme_color_override("font_color",TEXT)
    boost_progress.value = game.boost_energy*100.0
    var route_hint: Dictionary = game.shortcut_route.shortcut_hint(
        game.player.global_position,bridge_approach_active) if is_instance_valid(game.shortcut_route) else {}
    bridge_approach_active = game.race_state == "RACING" and route_hint.get("mode","") == "merge"
    var downstream_limit: float = SHORTCUT_ROUTE.EXIT_Z if bridge_approach_active else INF
    var hazard: Dictionary = game.upcoming_hazard(game.player.global_position.z,downstream_limit)
    # Timed events have their own forecast, so do not show two duplicate
    # hazard banners while also preserving warnings for physical edge gates.
    hazard_label.visible = not hazard.is_empty() and not hazard.has("index") and (
        not hazard.get("final",false))
    if hazard_label.visible:
        var metres: float = float(hazard["distance"])
        var approach: float = maxf(1.25,-game.player.linear_velocity.z)
        var seconds_until: float = metres/approach
        # Distance is more useful during slow manoeuvres; time-to-impact
        # gets urgent at 20m/s and warns before the next blind baffle.
        var hazard_name: String = str(hazard.get("kind","EDGE"))
        var timing: String = "CHARGING" if hazard.has("active") and not bool(hazard["active"]) else "LIVE"
        hazard_label.text = "%s  %s  •  %dm / %.1fs" % [
            hazard_name,str(hazard["side"]),int(metres),minf(seconds_until,12.0)]
        if hazard.has("kind") and hazard_name == "FORGE PISTON":
            hazard_label.text += "  /  "+timing
        hazard_label.add_theme_color_override("font_color",
            Color("#ff9a85") if seconds_until < 1.1 else Color("#f9d49d"))
    # Predicted *arrival* timing uses the same deterministic physical hazard
    # timeline as the server, never the piston's misleading current state.
    var forward_speed := maxf(0.0,-game.player.linear_velocity.z)
    var gate_reach := clampf(forward_speed*2.0,18.0,38.0)
    var moving_event: Dictionary = game.race_director.event_ahead(
        game.player.global_position.z,downstream_limit,gate_reach) if is_instance_valid(
        game.race_director) else {}
    var still_racing: bool = game.race_state == "RACING" and not game.player.finished and not game.player.eliminated
    timed_gate_label.visible = still_racing and not moving_event.is_empty()
    var urgent_gate_eta := INF
    var gate_eta := INF
    var piston_contact_eta := INF
    var bridge_piston_warning := false
    var glacier_return_panel := false
    var audible_gate_eta := INF
    var shutter_side := ""
    var gate_id := -1
    if timed_gate_label.visible:
        var gate_distance: float = game.player.global_position.z-float(moving_event["z"])
        gate_eta = gate_distance/maxf(
            2.0,-game.player.linear_velocity.z)
        gate_id = int(moving_event["index"])
        var projected_blocking: bool = game.selected_track != 2 or (
            game.race_director.piston_up(gate_id,
                game.race_director.clock+gate_eta))
        # A rising piston still needs a warning ONLY when the predicted
        # collision envelope overlaps this player's physical driving line.
        # Show a calm clear-line cue otherwise; do not punish safe steering
        # with false hazard sounds when the gate moves on the opposite rail.
        var player_threatened: bool
        if game.selected_track == 1 and gate_id == game.race_director.GLACIER_RETURN_GATE:
            player_threatened = game.race_director.glacier_return_threatens_crossing(
                gate_eta,forward_speed,game.player.global_position.x,game.player.linear_velocity.x)
        else:
            player_threatened = projected_blocking and game.race_director.threatens_line(
                gate_id,game.race_director.clock,gate_eta,
                game.player.global_position.x,game.player.linear_velocity.x)
        var gate_side: String = str(moving_event["side"])
        if game.selected_track == 1 and player_threatened:
            shutter_side = gate_side
        var bridge_exit_preview: bool = game.selected_track == 2 and bridge_approach_active and (
            gate_id == game.race_director.FORGE_EXIT_GATE)
        var glacier_exit_preview: bool = game.selected_track == 1 and bridge_approach_active and (
            gate_id == game.race_director.GLACIER_RETURN_GATE)
        var lane_verdict: String = "DODGE!" if player_threatened else "LINE CLEAR"
        if not bridge_exit_preview and not glacier_exit_preview and player_threatened and gate_eta <= 1.45:
            urgent_gate_eta = gate_eta
        if bridge_exit_preview:
            bridge_piston_warning = game.race_director.forge_exit_blocks_during_crossing(
                gate_eta,forward_speed)
            if bridge_piston_warning:
                var action := "KEEP LEFT" if gate_side == "RIGHT" else "AIM CENTER"
                timed_gate_label.text = "AFTER BRIDGE  •  PISTON %s  •  %s  •  %.1fs" % [
                    gate_side,action,gate_eta]
            else:
                timed_gate_label.text = "AFTER BRIDGE  •  PISTON %s OPEN  •  %.1fs" % [
                    gate_side,gate_eta]
        elif glacier_exit_preview:
            var merge_distance: float = game.player.global_position.z-SHORTCUT_ROUTE.EXIT_Z
            timed_gate_label.visible = merge_distance <= SHORTCUT_ROUTE.MERGE_GUIDANCE_REACH
            glacier_return_panel = timed_gate_label.visible
            var merge: String = "MERGE RIGHT NOW" if (
                merge_distance <= SHORTCUT_ROUTE.PORTAL_HALF_LENGTH) else (
                game.shortcut_route.route_guidance_text(
                    route_hint,game.player.global_position.z,forward_speed))
            timed_gate_label.text = "%s  •  THEN AIM CENTER" % merge
            if gate_eta <= 1.3:
                timed_gate_label.text += "  •  SHUTTER %s" % gate_side
        elif game.selected_track == 2:
            var bypass := "LEFT" if gate_side == "RIGHT" else "RIGHT"
            var action := "DODGE! GO "+bypass if player_threatened else lane_verdict
            timed_gate_label.text = "FORGE PISTON %s  •  EST. %s  •  %s  •  %.1fs" % [
                gate_side,"BLOCKED" if projected_blocking else "OPEN",action,gate_eta]
        else:
            if player_threatened:
                lane_verdict = "DODGE! GO "+("LEFT" if gate_side == "RIGHT" else "RIGHT")
            timed_gate_label.text = "%s %s  •  %s  •  %.1fs" % [
                str(moving_event["kind"]),gate_side,lane_verdict,gate_eta]
        var tint := Color("#a1edcc")
        if bridge_piston_warning or glacier_exit_preview:
            tint = Color("#ffd494")
        elif player_threatened and not bridge_exit_preview:
            tint = Color("#ffae91") if gate_eta < 1.45 else Color("#f6d49b")
        if bridge_piston_warning or (player_threatened and not bridge_exit_preview and not glacier_exit_preview):
            var entry_distance: float = gate_distance-game.race_director.BODY_DEPTH*0.5-(
                game.race_director.MARBLE_CLEARANCE)
            piston_contact_eta = maxf(0.0,entry_distance)/maxf(2.0,forward_speed)
            var audio_minimum := 0.06 if game.selected_track == 1 else 0.20
            if not bridge_exit_preview and piston_contact_eta >= audio_minimum and (
                    piston_contact_eta <= PISTON_WARNING_SECONDS):
                audible_gate_eta = piston_contact_eta
        timed_gate_label.add_theme_color_override("font_color",tint)
    var lane_hint: Dictionary = game.course_mechanics.upcoming_lane(
        game.player.global_position,game.player.linear_velocity,downstream_limit) if (
        still_racing and is_instance_valid(game.course_mechanics)) else {}
    var vent_eta := float(lane_hint.get("contact_eta",INF))
    var vent_index := int(lane_hint.get("index",-1))
    var pickup_limit := urgent_gate_eta
    if game.selected_track == 2:
        var piston_priority := piston_contact_eta if (
            bridge_piston_warning or piston_contact_eta <= PISTON_WARNING_SECONDS) else INF
        var vent_priority := vent_eta if vent_eta <= VENT_WARNING_SECONDS else INF
        pickup_limit = minf(piston_priority,vent_priority)
        _show_forge_hazard(lane_hint,gate_eta,piston_priority,vent_priority)
    elif glacier_return_panel:
        hazard_label.hide()
        biome_lane_label.hide()
        timed_gate_backdrop.show()
        pickup_limit = 0.0
    elif game.selected_track == 1 and gate_id >= 0 and gate_id == int(lane_hint.get("exit_shutter",-1)):
        _show_glacier_sequence(lane_hint,shutter_side)
        # Keep the shutter's one-shot sound available for the exit while
        # the combined on-ice message is still the active steering cue.
        if not timed_gate_label.visible:
            audible_gate_eta = INF
    else:
        timed_gate_backdrop.visible = is_finite(urgent_gate_eta) or (
            game.selected_track == 1 and bridge_approach_active and timed_gate_label.visible)
        _update_biome_lane(lane_hint,urgent_gate_eta)
    _show_final_danger(gate_id,urgent_gate_eta,piston_contact_eta,lane_hint,vent_eta,still_racing)
    if vent_eta < 0.20 or vent_eta > VENT_WARNING_SECONDS:
        vent_eta = INF
    if game.audio.warned_vents.has(vent_index):
        vent_eta = INF
    if game.audio.warned_timed_gates.has(gate_id):
        audible_gate_eta = INF
    if vent_eta < audible_gate_eta:
        game.audio.warn_vent(vent_index)
    elif is_finite(audible_gate_eta):
        game.audio.warn_timed_gate(gate_id,true)
    # Predict the next still-available, immediate-effect item. Clients
    # consult their local server-confirmed visibility; AI never receive UI.
    var item_reach := clampf(forward_speed*1.55,20.0,36.0)
    var next_item: Dictionary = game.race_items.nearest_available(
        game.player.global_position,game.player.racer_id,item_reach,bridge_approach_active) if (
        is_instance_valid(game.race_items) and still_racing) else {}
    var pickup_eta := float(next_item.get("distance",INF))/maxf(2.0,forward_speed)
    rare_item_label.visible = not final_danger_active and not next_item.is_empty() and pickup_eta < pickup_limit
    if rare_item_label.visible:
        rare_item_label.text = "RARE %s  •  %s  •  %dm" % [
            str(next_item["label"]),str(next_item["side"]),
            int(ceil(float(next_item["distance"])))]
        if woodworks_guide_active and int(next_item["index"]) == 0:
            rare_item_label.text = "INSTANT TURBO DIAMOND  •  %s  •  %dm" % [
                str(next_item["side"]),int(ceil(float(next_item["distance"])))]
        var color_index: int = posmod(int(next_item["index"])+game.selected_track,
            RARE_ITEMS.COLORS.size())
        rare_item_label.add_theme_color_override("font_color",
            RARE_ITEMS.COLORS[color_index].lightened(0.20))
    shortcut_label.visible = still_racing and not route_hint.is_empty() and not glacier_return_panel
    if shortcut_label.visible:
        shortcut_label.text = game.shortcut_route.route_guidance_text(
            route_hint,game.player.global_position.z,forward_speed)
        shortcut_label.visible = not shortcut_label.text.is_empty()
        var route_tint := SHORTCUT_ROUTE.FORK_MAIN_COLOR
        if route_hint["mode"] == "fork":
            route_tint = SHORTCUT_ROUTE.FORK_BRIDGE_COLOR
        elif game.selected_track == 1:
            route_tint = SHORTCUT_ROUTE.GLACIER_RETURN_COLOR
        shortcut_label.add_theme_color_override("font_color",route_tint)
    if bridge_approach_active and (shortcut_label.visible or glacier_return_panel):
        # Keep the physical rival marked while the player reads the return line.
        duel_label.hide()
    _update_woodworks_guide(str(route_hint.get("mode","")),
        rare_item_label.visible and int(next_item.get("index",-1)) == 0,
        final_danger_active or is_finite(urgent_gate_eta))
    var table = "TOP RACERS\n"
    for i in range(min(3,ranking.size())):
        var r = ranking[i]
        table += "%02d  %s%s\n" % [i+1, r.display_name, " ★" if r.is_player else ""]
    if place > 3:
        table += "%02d  YOU ★" % place
    leaderboard.text = table
    for cue: Label in driving_cue_backgrounds:
        _refresh_driving_cue_background(cue)
    if practice_entry_pending:
        _update_practice_sector(forward_speed)
        _refresh_race_notification()

func _refresh_driving_cue_background(cue: Label) -> void:
    var background := driving_cue_backgrounds[cue]
    # An urgent alert already has a dedicated wide panel.
    var on_urgent_panel := timed_gate_backdrop.visible and (cue == timed_gate_label or (
        cue == biome_lane_label and is_equal_approx(cue.anchor_top,timed_gate_label.anchor_top)))
    background.visible = cue.visible and not cue.text.is_empty() and not on_urgent_panel
    if not background.visible:
        return
    var font := cue.get_theme_font("font")
    var font_size := cue.get_theme_font_size("font_size")
    var text_width := font.get_string_size(cue.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    var text_height := float(cue.get_line_height())*maxi(1,cue.get_line_count())
    background.size = Vector2(minf(cue.size.x,text_width+22.0),minf(cue.size.y,text_height+6.0))
    background.position = (cue.size-background.size)*0.5

func _show_final_danger(gate_id: int, urgent_gate_eta: float, piston_contact_eta: float,
        lane_hint: Dictionary, vent_eta: float, still_racing: bool) -> void:
    # Keep the nearest final-sector steering instruction in the existing
    # danger row. Later cues stay quiet until the marble clears the hazard.
    var last_gate: bool = gate_id >= 0 and gate_id == game.race_director.EVENT_Z.size()-1
    var last_surface: bool = not lane_hint.is_empty() and (
        int(lane_hint["index"]) == game.course_mechanics.ZONE_Z.size()-1)
    var final_gate_eta := urgent_gate_eta if last_gate and timed_gate_label.visible else INF
    if last_gate and game.selected_track == 2 and timed_gate_label.visible and timed_gate_backdrop.visible:
        final_gate_eta = piston_contact_eta
    var final_surface_eta := INF
    if last_surface and biome_lane_label.visible:
        if game.selected_track == 2 and vent_eta <= VENT_WARNING_SECONDS:
            final_surface_eta = vent_eta
        elif game.selected_track == 1 and lane_hint.get("on_line",false) and (
                float(lane_hint["eta"]) <= FINAL_OBSTACLE_WARNING_SECONDS):
            final_surface_eta = float(lane_hint["eta"])
    var final_warning: Dictionary = game.final_obstacle_art.approach_warning(
        game.player.global_position,game.player.linear_velocity,FINAL_OBSTACLE_WARNING_SECONDS) if (
        still_racing and is_instance_valid(game.final_obstacle_art)) else {}
    var final_obstacle_eta := float(final_warning.get("eta",INF))
    var danger_was_active := final_danger_active
    final_danger_active = is_finite(minf(final_obstacle_eta,minf(final_gate_eta,final_surface_eta)))
    if final_danger_active:
        hazard_label.hide()
        timed_gate_backdrop.show()
        if final_obstacle_eta < minf(final_gate_eta,final_surface_eta):
            timed_gate_label.text = "%s  •  %.1fs" % [final_warning["text"],final_obstacle_eta]
            timed_gate_label.add_theme_color_override("font_color",Color("#ffae91"))
            timed_gate_label.show()
            biome_lane_label.hide()
        elif final_surface_eta < final_gate_eta:
            timed_gate_label.hide()
            _update_biome_lane(lane_hint,INF,true)
        else:
            biome_lane_label.hide()
        duel_label.hide()
    if final_danger_active != danger_was_active:
        _refresh_race_notification()

func _update_practice_sector(forward_speed: float) -> void:
    practice_hint_ready = false
    if not practice_entry_pending:
        return
    var sector: int = game.practice_sector
    var distance: float = game.player.global_position.z-game.sector_entry_z(sector)
    if game.net.is_active() or game.player.finished or game.player.eliminated or (
        game.race_state == "RACING" and distance <= 0.0):
        practice_entry_pending = false
        race_radar.set_practice_entry(NAN)
        return
    if game.race_state == "COUNTDOWN" and sector == 0:
        practice_sector_label.text = "FOCUS SECTOR 1\nFROM THE START"
        practice_hint_ready = true
    elif game.race_state == "RACING" and distance <= clampf(forward_speed*2.0,16.0,44.0):
        practice_sector_label.text = "FOCUS SECTOR %d\n%d m TO ENTRY" % [sector+1,ceili(distance)]
        practice_hint_ready = true

func _show_forge_hazard(vent: Dictionary, gate_eta: float, piston_priority: float,
        vent_priority: float) -> void:
    # One driving message, with optional item guidance below it.
    # If a real threat is imminent, the earliest entry wins. Otherwise,
    # keep the forecast for whichever obstacle the player encounters first.
    var show_vent := not vent.is_empty() and (
        vent_priority < piston_priority or (
            not is_finite(piston_priority) and float(vent["eta"]) <= gate_eta))
    timed_gate_label.visible = timed_gate_label.visible and not show_vent
    if show_vent:
        biome_lane_label.anchor_top = timed_gate_label.anchor_top
        biome_lane_label.anchor_bottom = timed_gate_label.anchor_bottom
        _update_biome_lane(vent,INF)
    else:
        biome_lane_label.hide()
    timed_gate_backdrop.visible = is_finite(vent_priority) if show_vent else (
        timed_gate_label.visible and is_finite(piston_priority))

func _show_glacier_sequence(ice: Dictionary, threatened_side: String) -> void:
    timed_gate_label.hide()
    var on_ice: bool = ice["on_ice"]
    var surface_entry: bool = float(ice["eta"]) > 0.0
    if not on_ice and not surface_entry and not threatened_side.is_empty():
        timed_gate_label.show()
        timed_gate_backdrop.show()
        biome_lane_label.hide()
        return
    _update_biome_lane(ice,INF,true)
    if on_ice and not threatened_side.is_empty():
        biome_lane_label.text = "STEER GENTLY  •  SHUTTER %s AFTER ICE" % threatened_side
    timed_gate_backdrop.visible = on_ice or not threatened_side.is_empty()

func _update_biome_lane(hint: Dictionary, urgent_gate_eta: float, primary := false) -> void:
    biome_lane_label.hide()
    if game.selected_track == 1:
        biome_lane_label.anchor_left = timed_gate_label.anchor_left if primary else 0.285
        biome_lane_label.anchor_right = timed_gate_label.anchor_right if primary else 0.715
        biome_lane_label.anchor_top = timed_gate_label.anchor_top if primary else SURFACE_CUE_TOP
        biome_lane_label.anchor_bottom = timed_gate_label.anchor_bottom if primary else SURFACE_CUE_BOTTOM
        biome_lane_label.add_theme_font_size_override("font_size",19 if primary else 17)
    if hint.is_empty():
        return
    # A moving obstacle before the ice takes priority unless the player
    # has already entered the slab and needs to manage steering there.
    if is_finite(urgent_gate_eta) and not hint.get("on_ice",false) and (
            float(hint["eta"]) >= urgent_gate_eta):
        return
    var cue: String
    var tint := Color("#b8ecff")
    if game.selected_track == 1:
        var on_ice: bool = hint["on_ice"]
        var entering_ice: bool = hint["on_line"] and float(hint["eta"]) < 0.40
        var grip := "GRIP CENTER" if hint["grip_center"] else "GRIP %s" % hint["other"]
        cue = "STEER GENTLY" if on_ice or entering_ice else grip
        var timing := "%.1fs" % float(hint["eta"]) if -game.player.linear_velocity.z >= 9.0 else "%dm" % int(hint["distance"])
        biome_lane_label.text = "ON ICE  •  STEER GENTLY" if on_ice else (
            "ICE %s  •  %s  •  %s" % [hint["side"],cue,timing])
        tint = Color("#ffe09d") if on_ice or entering_ice else Color("#c3edff")
    else:
        tint = Color("#ffc39a")
        if hint["on_line"]:
            cue = "DODGE %s" % hint["other"]
            tint = Color("#ff9b85")
        else:
            cue = "LINE CLEAR" if hint["active"] else "EST. COOL"
        var timing := "%.1fs" % float(hint["contact_eta"]) if hint["on_line"] else "%dm" % int(hint["distance"])
        biome_lane_label.text = "VENT %s  •  %s  •  %s" % [hint["side"],cue,timing]
    biome_lane_label.add_theme_color_override("font_color",tint)
    biome_lane_label.show()

func _refresh_race_notification() -> void:
    # Finish feedback keeps its priority. Other timers continue to expire
    # while the driving cue has the screen to itself.
    race_moment_label.visible = moment_remaining > 0.0 and (
        not final_danger_active or moment_priority >= 3) and (
        toast_remaining <= 0.0 or moment_priority > 0)
    checkpoint_label.visible = not final_danger_active and toast_remaining > 0.0 and (
        not race_moment_label.visible)
    position_feedback.visible = not final_danger_active and rank_toast_seconds > 0.0 and (
        not checkpoint_label.visible and not race_moment_label.visible)
    practice_sector_label.visible = practice_hint_ready and not final_danger_active and (
        not timed_gate_backdrop.visible and not position_feedback.visible and (
            not checkpoint_label.visible and not race_moment_label.visible))
    var opacity := 0.0
    if race_moment_label.visible:
        opacity = minf(1.0,moment_remaining*4.0)
    elif checkpoint_label.visible:
        opacity = minf(1.0,toast_remaining*3.0)
    elif position_feedback.visible:
        opacity = minf(1.0,rank_toast_seconds*3.0)
    elif practice_sector_label.visible:
        opacity = 1.0
    race_notification_backdrop.visible = opacity > 0.0
    race_notification_backdrop.modulate.a = opacity

func show_course_event(kind: String) -> void:
    var labels := {
        "speed": "WOODLAND  /  SPEED LINE!",
        "ice": "GLACIER  /  ICE DRIFT!",
        "vent": "FORGE  /  HEAT BLAST!",
        "shortcut": "SHORTCUT  /  PERFECT LINE!",
        "jump": "AIRTIME  /  CLEAN LAUNCH!",
        "apex": "BANKED APEX  /  PERFECT CREST BOOST!",
        "bridge_gate_1": "BRIDGE SKILL  /  GATE 1 OF 3!",
        "bridge_gate_2": "BRIDGE SKILL  /  GATE 2 OF 3!",
        "bridge_perfect": "PERFECT BRIDGE  /  TRIPLE-GATE BOOST!",
        "near_miss": "NEAR MISS  /  CLEAN PASS!",
        "near_miss_precision": "PRECISION PASS  /  EXTRA MOMENTUM!",
        "near_miss_chain": "PRECISION STREAK  /  MOMENTUM BONUS!"
    }
    checkpoint_label.text = str(labels.get(kind,"COURSE HAZARD"))
    checkpoint_label.add_theme_color_override("font_color",
        Color("#b6edff") if kind in ["ice","shortcut","jump","apex",
            "near_miss","near_miss_precision","near_miss_chain",
            "bridge_gate_1","bridge_gate_2","bridge_perfect"] else Color("#ffcb8c"))
    toast_remaining = 1.45
    _refresh_race_notification()

func show_item_pickup(kind: String) -> void:
    var labels := {
        "turbo": "RARE ITEM  /  INSTANT TURBO!",
        "spring": "RARE ITEM  /  SUPER JUMP!",
        "pulse": "RARE ITEM  /  SHOCKWAVE!",
        "stabilizer": "RARE ITEM  /  STEADY DASH!"
    }
    checkpoint_label.text = str(labels.get(kind,"RARE ITEM!"))
    checkpoint_label.add_theme_color_override("font_color",Color("#9af5e2"))
    toast_remaining = 1.8
    _refresh_race_notification()

func _gap_time(seconds: float) -> String:
    return "0.00s" if absf(seconds) < VISIBLE_TIME_GAP else "%+.2fs" % seconds

func _gap_color(seconds: float) -> Color:
    if seconds <= -VISIBLE_TIME_GAP:
        return TIME_GAIN
    return TIME_LOSS if seconds >= VISIBLE_TIME_GAP else TEXT

func show_checkpoint(number: int, sector_time: float = 0.0, best_before: float = 0.0,
        ghost_delta: float = NAN) -> void:
    var timing := "  •  %.2fs" % sector_time if sector_time > 0.0 else ""
    var comparison := ""
    if is_finite(ghost_delta):
        comparison = "\n%s VS GHOST" % _gap_time(ghost_delta)
        checkpoint_label.add_theme_color_override("font_color",_gap_color(ghost_delta))
    elif best_before > 0.0 and sector_time > 0.0:
        var delta := sector_time-best_before
        comparison = "  %+.2fs" % delta
        checkpoint_label.add_theme_color_override("font_color",
            Color("#a7f4d3") if delta <= 0.0 else Color("#ffc18d"))
    else:
        checkpoint_label.add_theme_color_override("font_color",ORANGE)
    checkpoint_label.text = "SECTOR %d / 3%s%s" % [number,timing,comparison]
    toast_remaining = 2.5 if is_finite(ghost_delta) else 2.15
    _refresh_race_notification()

func _show_sector_results(status: Dictionary, finished_solo: bool) -> void:
    slowest_sector = -1
    sector_result_hint.hide()
    sector_retry_comparison.hide()
    var times: Array = status.get("sector_times",[])
    var records: Array = status.get("sector_records",[])
    var crossings: Array = status.get("ghost_deltas",[])
    var finish_gap := float(crossings[3]) if finished_solo and crossings.size() == 4 else NAN
    var has_times := finished_solo and times.size() == 4
    sector_results.visible = has_times or is_finite(finish_gap)
    if not sector_results.visible:
        return
    sector_result_row.visible = has_times
    sector_result_header.text = "SECTOR TIMES" if has_times else ""
    if is_finite(finish_gap):
        var finish_comparison := "FINISH %s VS GHOST" % _gap_time(finish_gap)
        sector_result_header.text = "SECTOR TIMES  •  " + finish_comparison if has_times else finish_comparison
    if not has_times:
        return
    var practice: Dictionary = status.get("practice_comparison",{})
    if not practice.is_empty():
        var targeted := int(practice["sector"])
        var previous := roundi(float(practice["previous"])*100.0)
        var current := roundi(float(times[targeted])*100.0)
        var difference := (current-previous)/100.0
        var change := "SAME TIME" if current == previous else (
            "%.2fs %s" % [absf(difference),"FASTER" if difference < 0.0 else "SLOWER"])
        sector_retry_comparison.text = "SECTOR %d VS LAST TRY   %.2fs → %.2fs   •   %s" % [
            targeted+1,previous/100.0,current/100.0,change]
        sector_retry_comparison.add_theme_color_override("font_color",_gap_color(difference))
        sector_retry_comparison.show()
    var has_ghost_sectors := crossings.size() == 4
    for crossing in crossings:
        has_ghost_sectors = has_ghost_sectors and is_finite(float(crossing))
    var previous_gap := 0.0
    var largest_loss := 0.0
    for sector in range(4):
        var time_label := sector_result_times[sector]
        var record := records.size() == 4 and bool(records[sector])
        time_label.text = "%.2fs%s" % [float(times[sector])," ★" if record else ""]
        time_label.add_theme_color_override("font_color",ORANGE if record else TEXT)
        var gap_label := sector_result_gaps[sector]
        gap_label.visible = has_ghost_sectors
        if has_ghost_sectors:
            var gap := float(crossings[sector])-previous_gap
            previous_gap = float(crossings[sector])
            gap_label.text = _gap_time(gap)
            gap_label.add_theme_color_override("font_color",_gap_color(gap))
            if gap >= VISIBLE_TIME_GAP and gap > largest_loss:
                largest_loss = gap
                slowest_sector = sector
    sector_result_hint.visible = slowest_sector >= 0
    if sector_result_hint.visible:
        sector_result_hint.text = "MOST TIME LOST  •  SECTOR %d  %s    →    VIEW MAP" % [
            slowest_sector+1,_gap_time(largest_loss)]

func show_results(place: int, time: float, ranking: Array) -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    results_layer.visible = true
    var summary = results_layer.find_child("Summary", true, false) as Label
    results_scroll.set_deferred("scroll_vertical", 0)
    var leaders := ""
    var finisher_count := 0
    for marble in ranking:
        if not marble.finished:
            break
        finisher_count += 1
        leaders += "%02d  %s  %.2fs\n" % [finisher_count, marble.display_name, marble.finish_time]
        if finisher_count == 5:
            break
    if leaders.is_empty():
        leaders = "No finishers yet\n"
    var status: Dictionary = game.last_result
    var finished: bool = bool(status.get("finished",false))
    _show_sector_results(status,finished and not game.net.is_active())
    var outcome: String = str(status.get("outcome", "FINISHED" if finished else "DNF"))
    var course := "LAYOUT %d / 3" % (game.built_variation + 1)
    result_overview.text = "%s  •  %.2fs  •  %s" % [
        "P%d / %d" % [place, game.MARBLE_COUNT] if finished else outcome, time, course]
    var measurements: String = game.performance_budget.race_summary() if game.show_fps else ""
    performance_text = measurements
    performance_actions.visible = not measurements.is_empty()
    if performance_actions.visible:
        performance_text = "%s | %s | LAYOUT %d | %s | %s | %s | %d MARBLES\n%s" % [
            OS.get_name(),game.track_title(),game.built_variation+1,
            game.QUALITY_NAMES[game.graphics_setting],game.selected_perk,"FINISHED" if finished else "DNF",
            game.racers.size(),measurements]
        copy_performance.text = "COPY FPS REPORT"
        copy_performance.disabled = false
        compare_performance.visible = not game.net.is_active()
        compare_performance.text = "TEST BALANCED" if game.graphics_setting == 0 else "TEST ECONOMY"
    var award := "DNF"
    if finished:
        award = "3 STARS" if place <= 3 else ("2 STARS" if place <= 10 else "1 STAR")
    if is_instance_valid(result_header):
        result_header.text = "%s  •  %s" % [game.track_title(),("ONLINE RACE" if game.net.is_active() else award)]
    var record_text := "NEW BEST FINISH!" if bool(status.get("record",false)) else (
        "NEW GHOST RECORD!" if bool(status.get("ghost_record",false)) else "")
    var unlock_text := "NEXT CIRCUIT UNLOCKED!" if bool(status.get("unlocked",false)) else ""
    var earned_stars: int = int(status.get("stars",0))
    var clean_passes: int = clampi(int(status.get("clean_passes",0)),0,3)
    var apex_passes: int = clampi(int(status.get("apex_passes",0)),0,4)
    var bridge_gates: int = clampi(int(status.get("bridge_gates",0)),0,3)
    var perfect_bridge: bool = bool(status.get("perfect_bridge",false))
    var landings: int = maxi(0,int(status.get("airtime_landings",0)))
    var best_air: float = maxf(0.0,float(status.get("airtime_best",0.0)))
    var stars_text := "CAREER STARS: %d / 3" % earned_stars
    var overtakes: int = maxi(0,int(status.get("overtakes",0)))
    var precision_gates: int = clampi(int(status.get("precision_passes",0)),0,3)
    var precision_text: String = "PRECISION  %d/3  •  BEST %s" % [
        precision_gates,str(status.get("precision_medal",
            game.career.precision_medal(game.selected_track)))]
    if bool(status.get("precision_new_record",false)):
        precision_text += "  •  NEW MEDAL!"
    var mastery_text := "MASTERY  %d/3  •  TOTAL %d/9" % [
        int(status.get("mastery_track",game.career.track_mastery_count(game.selected_track))),
        int(status.get("mastery_total",game.career.mastery_count()))]
    var new_goals: Array = status.get("mastery_new",[])
    if not new_goals.is_empty():
        mastery_text += "\nNEW STAMPS: " + ", ".join(PackedStringArray(new_goals))
    var unlocked_styles: Array = status.get("mastery_styles",[])
    if not unlocked_styles.is_empty():
        mastery_text += "\nNEW MARBLE: " + ", ".join(PackedStringArray(unlocked_styles))
    var league_text := "LEAGUE  %s  +%d REP" % [
        str(status.get("league_tier",game.career.league_name())),
        int(status.get("league_earned",0))]
    if bool(status.get("league_promoted",false)):
        league_text += "  •  LICENSE PROMOTED!"
    var checkpoint_text := ""
    var ghost_deltas: Array = status.get("ghost_deltas",[])
    if finished and not game.net.is_active() and ghost_deltas.size() == 4 and (
        is_finite(float(ghost_deltas[0])) and is_finite(float(ghost_deltas[1]))
        and is_finite(float(ghost_deltas[2]))):
        checkpoint_text = "\nGAP AT CHECKPOINTS  •  S1 %s  •  S2 %s  •  S3 %s" % [
            _gap_time(float(ghost_deltas[0])),_gap_time(float(ghost_deltas[1])),
            _gap_time(float(ghost_deltas[2]))]
    if summary:
        summary.text = "CLEAN PASSES  %d / 3  •  OVERTAKES %d\nBANKED APEXES  %d / 4\nBRIDGE GATES  %d / 3%s\nREAL LANDINGS  %d  •  BEST AIR %.2fs\n%s\n%s\n%s\n%s%s\n%s\n%s\nBEST  #%s\n\nTOP 5\n%s" % [
            clean_passes,overtakes,apex_passes,bridge_gates,
            "  •  PERFECT!" if perfect_bridge else "",landings,best_air,
            precision_text,league_text,mastery_text,stars_text,checkpoint_text,
            record_text,unlock_text,
            str(game.career.track_best[game.selected_track]) if game.career.track_best[game.selected_track] > 0 else "—",
            leaders]
    if game.net.is_active():
        # Solo challenge counters are not available on a display-only
        # multiplayer client: never show a false zero instead of the
        # server-authoritative remote clean-pass count.
        summary.text = "TOP FINISHERS\n%s" % leaders
        replay_button_ref.text = "ONLINE LOBBY — AUTO REMATCH"
        replay_button_ref.disabled = false
    else:
        replay_button_ref.text = "RETRY SAME LAYOUT"
        replay_button_ref.disabled = false
    next_layout_button.visible = not game.net.is_active()
    next_course_button.visible = not game.net.is_active() and game.selected_track < 2 and game.career.is_unlocked(game.selected_track+1)
