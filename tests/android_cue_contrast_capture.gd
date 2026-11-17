extends Node

const BASE := preload("res://tests/frame_pacing_baseline/race.tscn")
const CURRENT := preload("res://scenes/main.tscn")
const FRAME_COUNT := 28
const BOOT_WARMUP := 8
const SCENE_WARMUP := 5
const STEP := 1.0 / 30.0

var game: Node3D
var output := FileAccess.open("user://frame-pacing.jsonl", FileAccess.WRITE)
var trials: Array[Dictionary] = []
var interrupted := false
var measuring := false


func _ready() -> void:
    _run.call_deferred()


func _notification(event: int) -> void:
    if measuring and event == NOTIFICATION_APPLICATION_PAUSED:
        interrupted = true


func _run() -> void:
    assert(Engine.physics_ticks_per_second == 60)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    measuring = true
    print("OPENING_BENCH_DEVICE ", RenderingServer.get_current_rendering_driver_name())
    for track in range(3):
        for trial in range(4):
            var current := (trial in [0, 3]) == (track % 2 == 1)
            await _trial(track, trial, current)
    measuring = false
    if OS.has_feature("android"):
        _show_report()
        await RenderingServer.frame_post_draw
    if not interrupted:
        print("OPENING_BENCH_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()


func _trial(track: int, trial: int, current: bool) -> void:
    game = (CURRENT if current else BASE).instantiate()
    add_child(game)
    game.audio.enabled = false
    game.show_fps = false
    game.career.save_path = "user://frame-pacing-career.cfg"
    game.career.unlocked = 3
    assert(game.set_track(track))
    game.set_graphics_quality(1)
    Engine.max_fps = 0
    for warm in range(BOOT_WARMUP):
        await RenderingServer.frame_post_draw
    var sections := {}
    for phase in ["grid", "merge"]:
        game.return_to_menu()
        seed(80431)
        game.race_variation = 0
        game.start_race("Grip Tape")
        assert(game.racers.size() == 40 and game.contact_shadows.visible)
        assert(game.primary_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
        assert(is_equal_approx(game.primary_light.directional_shadow_max_distance, [36.0, 47.0, 33.0][track]))
        Engine.max_fps = 0
        if phase == "merge":
            _position_at_merge()
        else:
            game.countdown = 0.51
        for warm in range(SCENE_WARMUP):
            await RenderingServer.frame_post_draw
        sections[phase] = await _measure()
    var row := {"track": track, "trial": trial,
        "mode": "current" if current else "reference", "sections": sections}
    trials.append(row)
    output.store_line(JSON.stringify(row))
    output.flush()
    game.return_to_menu()
    game.queue_free()
    await get_tree().process_frame
    print("OPENING_BENCH_TRIAL ", track, " ", trial, " ", row.mode)


func _position_at_merge() -> void:
    var route: Node3D = game.shortcut_route
    var exit_z: float = route.EXIT_Z
    game.race_time = 11.0
    game.race_state = "RACING"
    game.last_checkpoint = 0
    game.start_gate.set_signal(-1)
    game.ui.hide_countdown()
    for slot in range(game.racers.size()):
        var marble: RigidBody3D = game.racers[slot]
        var z := exit_z + 6.0 + float(slot / 8) * 0.95
        var x: float = game.track_center_at(z) + (float(slot % 8) - 3.5) * 1.29
        var y: float = game.height_at(z) + 0.46
        var vx := 0.0
        if marble == game.player:
            z = exit_z + 4.0
            var deck: Vector3 = route.point_at(z)
            x = deck.x
            y = deck.y + 0.70
            vx = -float(route.side) * 1.6
        var place := Vector3(x, y, z)
        marble.global_position = place
        marble.previous_race_position = place
        marble.progress_anchor_z = z
        marble.linear_velocity = Vector3(vx, 0.0, -13.0 - float(slot % 3) * 0.6)
        marble.freeze = false
        marble.sleeping = false
    # Keep the field live even if the player hits the moving Woodworks obstacle.
    game.change_steer(-float(route.side) * 0.36)
    game._update_camera(STEP, true)
    game.contact_shadows.update_shadows()


func _measure() -> Array[Dictionary]:
    var samples: Array[Dictionary] = []
    var previous := Time.get_ticks_usec()
    var physics := Engine.get_physics_frames()
    for index in range(FRAME_COUNT):
        await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        var physics_now := Engine.get_physics_frames()
        samples.append({
            "ms": (now - previous) / 1000.0,
            "steps": physics_now - physics,
            "z": game.player.position.z,
            "race_time": game.race_time,
            "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
        })
        previous = now
        physics = physics_now
    return samples


func _p95(samples: Array) -> float:
    var times := PackedFloat32Array()
    for sample in samples:
        times.append(sample.ms)
    times.sort()
    return times[ceili(times.size() * 0.95) - 1]


func _show_report() -> void:
    var window_size := DisplayServer.window_get_size()
    var lines := PackedStringArray([
        "Marble Race · Banc de course à 40 billes",
        "%s · %d × %d px · %s" % [OS.get_model_name(), window_size.x, window_size.y,
            RenderingServer.get_current_rendering_driver_name()],
        RenderingServer.get_video_adapter_name(),
    ])
    if interrupted:
        lines.append("Le test a été interrompu. Relance l’application et garde-la au premier plan.")
    else:
        lines.append("P95 en ms · 1.102.0-rc → 1.107.0-rc · 2 répétitions")
        for track in range(3):
            var line: String = ["Woodworks", "Glacier", "Forge"][track]
            for phase in ["grid", "merge"]:
                var totals := {"reference": 0.0, "current": 0.0}
                for row in trials:
                    if row.track == track:
                        totals[row.mode] += _p95(row.sections[phase]) * 0.5
                line += " | %s %.1f → %.1f" % [
                    "Départ" if phase == "grid" else "Pont", totals.reference, totals.current]
            lines.append(line)
    var result := "\n".join(lines)
    var surface := ColorRect.new()
    surface.color = Color("#142331")
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(surface)
    var column := VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    column.offset_left = 24
    column.offset_right = -24
    column.offset_top = 18
    column.offset_bottom = -18
    surface.add_child(column)
    var report := TextEdit.new()
    report.text = result
    report.editable = false
    report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    report.add_theme_font_size_override("font_size", 24)
    report.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(report)
    if not interrupted:
        var copy := Button.new()
        copy.text = "Copier le rapport"
        copy.custom_minimum_size.y = 55
        copy.pressed.connect(func():
            DisplayServer.clipboard_set(result)
            copy.text = "Rapport copié")
        column.add_child(copy)
