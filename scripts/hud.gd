extends CanvasLayer
## Native Godot touch UI. Full game remains playable offline and by keyboard.

const TOUCH_CONTROLS = preload("res://scripts/touch_controls.gd")
const CAREER_TRANSFER = preload("res://scripts/career_transfer.gd")
const RACE_MOMENTS = preload("res://scripts/race_moments.gd")
const COURSE_BRIEFING = preload("res://scripts/course_briefing.gd")
const PROGRESS_RADAR = preload("res://scripts/race_progress_radar.gd")
const RARE_ITEMS = preload("res://scripts/race_items.gd")
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
var quality_button: Button
var fps_button: Button
var course_progress: ProgressBar
var race_radar: Control
var boost_progress: ProgressBar
var checkpoint_label: Label
var hazard_label: Label
var timed_gate_label: Label
var rare_item_label: Label
var shortcut_label: Label
var position_feedback: Label
var race_moment_label: Label
var speed_stripes: Array[ColorRect] = []
var moment_remaining := 0.0
var moment_duration := 1.0
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
            info += "  ·  M%d/3" % game.career.track_mastery_count(i)
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
        mastery_label.text = "MASTER %s:  %s\nLEAGUE: %s" % [
            game.track_title(),game.career.mastery_summary(game.selected_track),
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
    leaderboard = _small_panel_text("LEADERBOARD", 16, Rect2(0.79,0.025,0.195,0.28))
    network_quality_label = _small_panel_text("NET: CONNECTING",14,Rect2(0.79,0.32,0.195,0.060))
    network_quality_label.get_parent().visible = false
    ghost_label = _small_panel_text("",14,Rect2(0.02,0.31,0.265,0.051))
    ghost_label.name = "PersonalBestGhostPace"
    ghost_label.get_parent().visible = false
    duel_label = _text("",15,Color("#c4f2e7"))
    duel_label.name = "ClosestPhysicalRival"
    duel_label.anchor_left = 0.32
    duel_label.anchor_right = 0.68
    duel_label.anchor_top = 0.308
    duel_label.anchor_bottom = 0.350
    duel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    duel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    duel_label.visible = false
    hud_layer.add_child(duel_label)
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
    hazard_label = _text("",17,Color("#ffd39c"))
    hazard_label.name = "UpcomingHazard"
    hazard_label.anchor_left = 0.32
    hazard_label.anchor_right = 0.68
    hazard_label.anchor_top = 0.150
    hazard_label.anchor_bottom = 0.203
    hazard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hazard_label.visible = false
    hud_layer.add_child(hazard_label)
    shortcut_label = _text("",17,Color("#f9d79a"))
    shortcut_label.name = "ForkAndMergePreview"
    shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shortcut_label.anchor_left = 0.26
    shortcut_label.anchor_right = 0.74
    shortcut_label.anchor_top = 0.207
    shortcut_label.anchor_bottom = 0.243
    shortcut_label.visible = false
    hud_layer.add_child(shortcut_label)
    # Dedicated kinetic-hazard predictor: the regular banner may still need
    # to warn about a closer edge shutter in the same physical section.
    timed_gate_label = _text("",15,Color("#f6d49b"))
    timed_gate_label.name = "PredictedTimedGate"
    timed_gate_label.anchor_left = 0.285
    timed_gate_label.anchor_right = 0.715
    timed_gate_label.anchor_top = 0.354
    timed_gate_label.anchor_bottom = 0.389
    timed_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timed_gate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    timed_gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    timed_gate_label.visible = false
    hud_layer.add_child(timed_gate_label)
    # Rare collectible guidance occupies its own thin band beneath timed
    # hazard warnings; it never covers the mobile steering or boost zones.
    rare_item_label = _text("",15,Color("#b5eeff"))
    rare_item_label.name = "UpcomingHumanPowerup"
    rare_item_label.anchor_left = 0.285
    rare_item_label.anchor_right = 0.715
    rare_item_label.anchor_top = 0.391
    rare_item_label.anchor_bottom = 0.426
    rare_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rare_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    rare_item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rare_item_label.visible = false
    hud_layer.add_child(rare_item_label)
    position_feedback = _text("",21,Color("#a7f0d8"))
    position_feedback.name = "RankFeedback"
    position_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    position_feedback.anchor_left = 0.38
    position_feedback.anchor_right = 0.62
    position_feedback.anchor_top = 0.257
    position_feedback.anchor_bottom = 0.298
    position_feedback.visible = false
    hud_layer.add_child(position_feedback)
    race_moment_label = _text("",25,Color("#aaf2e5"))
    race_moment_label.name = "LiveRaceMoment"
    race_moment_label.anchor_left = 0.31
    race_moment_label.anchor_right = 0.69
    race_moment_label.anchor_top = 0.43
    race_moment_label.anchor_bottom = 0.50
    race_moment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    race_moment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    race_moment_label.visible = false
    hud_layer.add_child(race_moment_label)
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
    countdown_label = _text("3", 86, ORANGE)
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    countdown_label.anchor_left = 0.35
    countdown_label.anchor_right = 0.65
    countdown_label.anchor_top = 0.27
    countdown_label.anchor_bottom = 0.59
    hud_layer.add_child(countdown_label)
    checkpoint_label = _text("", 30, ORANGE)
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
    boost_label = _text("BOOST 100%", 18, ORANGE)
    boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boost_label.anchor_left = 0.665
    boost_label.anchor_right = 0.915
    boost_label.anchor_top = 0.603
    boost_label.anchor_bottom = 0.636
    hud_layer.add_child(boost_label)
    var build_label := _text("STEER  ◀  DRAG  ▶     •     HOLD BOOST",13,Color("#c7d4db"))
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
    pause_button_ref = pause_button

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
    var upcoming: Dictionary = game.upcoming_hazard(game.player.global_position.z) if is_instance_valid(game.player) else {}
    pause_obstacle_hint.text = (
        "NEXT: %s EDGE CLOSES IN %d m" % [upcoming["side"],upcoming["distance"]]
        if not upcoming.is_empty() else "READ THE COURSE  ·  CHOOSE YOUR LINE"
    )
    pause_layer.visible = true
    get_tree().paused = true

func resume_race() -> void:
    if not is_instance_valid(pause_layer):
        return
    pause_layer.visible = false
    get_tree().paused = false
    touch_controls.release_all()

func _restart_from_pause() -> void:
    resume_race()
    game.restart_race()

func _leave_from_pause() -> void:
    resume_race()
    game.return_to_menu()

func _toggle_pause() -> void:
    if game.net.is_active():
        _leave_multiplayer()
        return
    if get_tree().paused and pause_layer.visible:
        resume_race()
    else:
        pause_race()

func _unhandled_input(event: InputEvent) -> void:
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
    var title = _text("RACE RESULTS", 40, ORANGE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(title)
    result_header = title
    # Mastery, split records and five finishers can exceed 720p height.
    # Keep replay/menu buttons visible and make only the race report swipeable.
    var detail_scroll := ScrollContainer.new()
    detail_scroll.name = "RaceResultsScroll"
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
    var replay = _action("RACE AGAIN", ORANGE, Color("#251b0d"))
    replay.name = "Replay"
    replay.pressed.connect(func():
        if game.net.is_active():
            show_online_lobby()
        else:
            game.restart_race()
    )
    col.add_child(replay)
    replay_button_ref = replay
    next_course_button = _action("NEXT CIRCUIT  →",Color("#4c6b67"))
    next_course_button.pressed.connect(_continue_championship)
    col.add_child(next_course_button)
    var menu = _action("MAIN MENU", Color("#343b47"))
    menu.pressed.connect(_leave_multiplayer)
    col.add_child(menu)

func _continue_championship() -> void:
    var next_index: int = game.selected_track + 1
    game.return_to_menu()
    game.set_track(next_index)
    show_perks()

func _hide_all() -> void:
    if is_instance_valid(touch_controls):
        touch_controls.release_all()
    menu_layer.visible = false
    perks_layer.visible = false
    hud_layer.visible = false
    results_layer.visible = false
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
                "\nSOLO: FOLLOW A RIVAL TO EARN DRAFT BOOST RECHARGE")
    if is_instance_valid(perk_scroll):
        perk_scroll.scroll_vertical = 0
    perks_layer.visible = true

func show_race_ui() -> void:
    last_seen_rank = -1
    rank_toast_seconds = 0.0
    moment_remaining = 0.0
    if is_instance_valid(race_radar):
        race_radar.reset()
    if is_instance_valid(race_moment_label):
        race_moment_label.visible = false
    for streak in speed_stripes:
        streak.visible = false
    if is_instance_valid(position_feedback):
        position_feedback.visible = false
    if is_instance_valid(shortcut_label):
        shortcut_label.visible = false
    if is_instance_valid(timed_gate_label):
        timed_gate_label.visible = false
    if is_instance_valid(rare_item_label):
        rare_item_label.visible = false
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    hud_layer.visible = true
    network_quality_label.get_parent().visible = game.net.role == "client"
    if is_instance_valid(pause_button_ref):
        pause_button_ref.text = "LEAVE" if game.net.is_active() else "Ⅱ"

func show_countdown(value: String) -> void:
    countdown_label.text = value
    countdown_label.visible = true

func hide_countdown() -> void:
    countdown_label.visible = false

func show_race_moment(title: String, duration: float = 1.1) -> void:
    if not is_instance_valid(race_moment_label):
        return
    race_moment_label.text = title
    race_moment_label.add_theme_color_override("font_color",
        Color("#f6e8b6") if title.contains("FINISH") or title.contains("STRAIGHT") else (
            Color("#a2f3d8") if title.contains("PASS") or title.contains("OVERTAKE") else
            Color("#b5ecff")))
    moment_duration = clampf(duration,0.4,2.2)
    moment_remaining = moment_duration
    race_moment_label.modulate.a = 1.0
    race_moment_label.visible = true

func update_hud() -> void:
    var elapsed: float = get_process_delta_time()
    if is_instance_valid(race_radar):
        race_radar.sample(elapsed)
    if moment_remaining > 0.0:
        moment_remaining = maxf(0.0,moment_remaining-elapsed)
        race_moment_label.visible = moment_remaining > 0.0
        race_moment_label.modulate.a = minf(1.0,
            minf(moment_remaining*3.0,(moment_duration-moment_remaining)*10.0+0.20))
    if rank_toast_seconds > 0.0:
        rank_toast_seconds -= get_process_delta_time()
        position_feedback.visible = rank_toast_seconds > 0.0
        position_feedback.modulate.a = minf(1.0,rank_toast_seconds * 2.0)
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
    if game.race_state == "RACING" and last_seen_rank > 0 and abs(place-last_seen_rank) >= 2:
        var gain := last_seen_rank - place
        position_feedback.text = "+%d PLACES" % gain if gain > 0 else "-%d PLACES" % abs(gain)
        position_feedback.add_theme_color_override("font_color",
            Color("#9cf2cb") if gain > 0 else Color("#ffb19c"))
        rank_toast_seconds = 0.95
        position_feedback.visible = true
        position_feedback.modulate.a = 1.0
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
        ghost_label.get_parent().visible = game.best_ghost.replay_available and not game.net.is_active()
        if game.best_ghost.replay_available:
            ghost_label.text = game.best_ghost.gap_text(game.player.global_position)
    # Solo duel indicator: sampled from real 3D positions by RaceMoments
    # (10Hz); no extra physics queries or per-frame allocation.
    var duel: RefCounted = game.race_moments
    duel_label.visible = not game.net.is_active() and (
        game.race_state == "RACING") and duel != null and (
        duel.closest_rival_gap < 12.0)
    if duel_label.visible:
        duel_label.text = "%s  %s  %.1fm" % [
            "SIDE BY SIDE" if duel.side_by_side_active else (
                "CHASE" if duel.closest_rival_ahead else "DEFEND"),
            duel.closest_rival_name.left(16),duel.closest_rival_gap]
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
    var hazard: Dictionary = game.upcoming_hazard(game.player.global_position.z)
    # Timed events have their own forecast, so do not show two duplicate
    # hazard banners while also preserving warnings for physical edge gates.
    hazard_label.visible = not hazard.is_empty() and not hazard.has("index")
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
    var moving_event: Dictionary = game.race_director.event_ahead(
        game.player.global_position.z) if is_instance_valid(
        game.race_director) else {}
    timed_gate_label.visible = game.race_state == "RACING" and (
        not moving_event.is_empty()) and (
        float(moving_event.get("distance",999.0)) <= 21.0)
    if timed_gate_label.visible:
        var gate_distance: float = float(moving_event["distance"])
        var gate_eta: float = gate_distance/maxf(
            2.0,-game.player.linear_velocity.z)
        var gate_id: int = int(moving_event["index"])
        var projected_blocking: bool = game.selected_track != 2 or (
            game.race_director.piston_up(gate_id,
                game.race_director.clock+gate_eta))
        # A rising piston still needs a warning ONLY when the predicted
        # collision envelope overlaps this player's physical driving line.
        # Show a calm clear-line cue otherwise; do not punish safe steering
        # with false hazard sounds when the gate moves on the opposite rail.
        var player_threatened: bool = projected_blocking and (
            game.race_director.threatens_line(
                gate_id,game.race_director.clock,gate_eta,
                game.player.global_position.x,game.player.linear_velocity.x))
        var gate_side: String = str(moving_event["side"])
        var lane_verdict: String = "DODGE!" if player_threatened else "LINE CLEAR"
        if game.selected_track == 2:
            timed_gate_label.text = "FORGE PISTON %s  •  EST. %s  •  %s  •  %.1fs" % [
                gate_side,"BLOCKED" if projected_blocking else "OPEN",
                lane_verdict,gate_eta]
        else:
            timed_gate_label.text = "%s %s  •  %s  •  %dm / %.1fs" % [
                str(moving_event["kind"]),gate_side,lane_verdict,
                int(gate_distance),gate_eta]
        timed_gate_label.add_theme_color_override("font_color",
            Color("#ffae91") if player_threatened and gate_eta < 1.45 else (
                Color("#a1edcc") if not player_threatened else Color("#f6d49b")))
        if gate_eta <= 2.20 and gate_eta >= 0.25:
            game.audio.warn_timed_gate(gate_id,player_threatened)
    # Predict the next still-available, immediate-effect item. Clients
    # consult their local server-confirmed visibility; AI never receive UI.
    var next_item: Dictionary = game.race_items.nearest_available(
        game.player.global_position,game.player.racer_id) if (
        is_instance_valid(game.race_items) and game.race_state == "RACING") else {}
    rare_item_label.visible = not next_item.is_empty()
    if rare_item_label.visible:
        rare_item_label.text = "RARE %s  •  %s  •  %dm" % [
            str(next_item["label"]),str(next_item["side"]),
            int(ceil(float(next_item["distance"])))]
        var color_index: int = posmod(int(next_item["index"])+game.selected_track,
            RARE_ITEMS.COLORS.size())
        rare_item_label.add_theme_color_override("font_color",
            RARE_ITEMS.COLORS[color_index].lightened(0.20))
    var route_hint: Dictionary = game.shortcut_route.shortcut_hint(
        game.player.global_position) if is_instance_valid(game.shortcut_route) else {}
    shortcut_label.visible = not route_hint.is_empty()
    if not route_hint.is_empty():
        if str(route_hint["mode"]) == "fork":
            shortcut_label.text = "%s FOR SHORTCUT  •  %dm" % [
                str(route_hint["side"]),int(route_hint["distance"])]
            shortcut_label.add_theme_color_override("font_color",Color("#ffdda0"))
        else:
            shortcut_label.text = "MERGE %s  •  %dm" % [
                str(route_hint["side"]),int(route_hint["distance"])]
            shortcut_label.add_theme_color_override("font_color",Color("#a8f6e4"))
    var table = "TOP RACERS\n"
    for i in range(min(3,ranking.size())):
        var r = ranking[i]
        table += "%02d  %s%s\n" % [i+1, r.display_name, " ★" if r.is_player else ""]
    if place > 3:
        table += "%02d  YOU ★" % place
    leaderboard.text = table

func show_course_event(kind: String) -> void:
    var labels := {
        "speed": "WOODLAND  /  SPEED LINE!",
        "ice": "GLACIER  /  ICE DRIFT!",
        "vent": "FORGE  /  HEAT BLAST!",
        "shortcut": "SHORTCUT  /  PERFECT LINE!",
        "jump": "AIRTIME  /  CLEAN LAUNCH!",
        "near_miss": "NEAR MISS  /  CLEAN PASS!"
    }
    checkpoint_label.text = str(labels.get(kind,"COURSE HAZARD"))
    checkpoint_label.add_theme_color_override("font_color",
        Color("#b6edff") if kind in ["ice","shortcut","jump","near_miss"] else Color("#ffcb8c"))
    checkpoint_label.modulate.a = 1.0
    checkpoint_label.visible = true
    toast_remaining = 1.45

func show_item_pickup(kind: String) -> void:
    var labels := {
        "turbo": "RARE ITEM  /  INSTANT TURBO!",
        "spring": "RARE ITEM  /  SUPER JUMP!",
        "pulse": "RARE ITEM  /  SHOCKWAVE!",
        "stabilizer": "RARE ITEM  /  STEADY DASH!"
    }
    checkpoint_label.text = str(labels.get(kind,"RARE ITEM!"))
    checkpoint_label.add_theme_color_override("font_color",Color("#9af5e2"))
    checkpoint_label.modulate.a = 1.0
    checkpoint_label.visible = true
    toast_remaining = 1.8

func show_checkpoint(number: int, sector_time: float = 0.0, best_before: float = 0.0) -> void:
    var timing := "  •  %.2fs" % sector_time if sector_time > 0.0 else ""
    var comparison := ""
    if best_before > 0.0 and sector_time > 0.0:
        var delta := sector_time-best_before
        comparison = "  %+.2fs" % delta
        checkpoint_label.add_theme_color_override("font_color",
            Color("#a7f4d3") if delta <= 0.0 else Color("#ffc18d"))
    else:
        checkpoint_label.add_theme_color_override("font_color",ORANGE)
    checkpoint_label.text = "SECTOR %d / 3%s%s" % [number,timing,comparison]
    checkpoint_label.modulate.a = 1.0
    checkpoint_label.visible = true
    toast_remaining = 2.15

func show_results(place: int, time: float, ranking: Array) -> void:
    if get_tree().paused:
        get_tree().paused = false
    _hide_all()
    results_layer.visible = true
    var summary = results_layer.find_child("Summary", true, false) as Label
    var leaders = ""
    for i in range(min(5, ranking.size())):
        leaders += "%s  %s\n" % [str(i+1).pad_zeros(2), ranking[i].display_name]
    var status: Dictionary = game.last_result
    var finished: bool = bool(status.get("finished",false))
    var award := "DNF"
    if finished:
        award = "3 STARS" if place <= 3 else ("2 STARS" if place <= 10 else "1 STAR")
    if is_instance_valid(result_header):
        result_header.text = "%s  •  %s" % [game.track_title(),("ONLINE RACE" if game.net.is_active() else award)]
    var record_text := "NEW PERSONAL BEST!" if bool(status.get("record",false)) else (
        "NEW GHOST RECORD!" if bool(status.get("ghost_record",false)) else "")
    var unlock_text := "NEXT CIRCUIT UNLOCKED!" if bool(status.get("unlocked",false)) else ""
    var earned_stars: int = int(status.get("stars",0))
    var clean_passes: int = clampi(int(status.get("clean_passes",0)),0,3)
    var stars_text := "CAREER STARS: %d / 3" % earned_stars
    var overtakes: int = maxi(0,int(status.get("overtakes",0)))
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
    var sector_text := ""
    var sector_times: Array = status.get("sector_times",[])
    var sector_records: Array = status.get("sector_records",[])
    if sector_times.size() == 4:
        sector_text = "SECTORS 1—4"
        for sector in range(4):
            sector_text += "  %.1fs%s" % [
                float(sector_times[sector]),
                " ★" if sector_records.size() == 4 and bool(sector_records[sector]) else ""]
    if summary:
        summary.text = "POSITION  #%d / 40   •   %s\nTIME  %.1fs\nCLEAN PASSES  %d / 3  •  OVERTAKES %d\n%s\n%s\n%s\n%s\n%s\n%s\nBEST  #%s\n\nTOP 5\n%s" % [
            place,"FINISHED" if finished else "TIME OUT",time,clean_passes,overtakes,league_text,mastery_text,stars_text,sector_text,
            record_text,unlock_text,
            str(game.career.track_best[game.selected_track]) if game.career.track_best[game.selected_track] > 0 else "—",
            leaders]
    if game.net.is_active():
        # Solo challenge counters are not available on a display-only
        # multiplayer client: never show a false zero instead of the
        # server-authoritative remote clean-pass count.
        summary.text = "WORLDWIDE ONLINE RACE   •   40 MARBLES\nPOSITION #%d / 40   •   %s\nTIME %.1fs\n\nTOP FINISHERS\n%s" % [
            place,"FINISHED" if finished else "DNF",time,leaders]
        replay_button_ref.text = "ONLINE LOBBY — AUTO REMATCH"
        replay_button_ref.disabled = false
    else:
        replay_button_ref.text = "RACE AGAIN"
        replay_button_ref.disabled = false
    next_course_button.visible = not game.net.is_active() and game.selected_track < 2 and game.career.is_unlocked(game.selected_track+1)
