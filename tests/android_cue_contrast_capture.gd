extends Node

const GRID_FRAMES := 34
const MERGE_FRAMES := 41
const STEP := 1.0 / 30.0
const MERGE_SPEED := 12.0
const BUDGET = preload("res://scripts/performance_budget.gd")
const ROUTE = preload("res://scripts/shortcut_route.gd")
var game: Node3D
var trials: Array[Dictionary] = []
var measuring := false
var interrupted := false
var output := FileAccess.open("user://shadow-pack.jsonl", FileAccess.WRITE)


func _ready() -> void:
    _run.call_deferred()


func _notification(what: int) -> void:
    if measuring and what == NOTIFICATION_APPLICATION_PAUSED:
        interrupted = true


func _run() -> void:
    game = get_parent()
    game.set_process(false)
    game.set_physics_process(false)
    game.show_fps = false
    game.audio.enabled = false
    game.career.save_path = "user://shadow-pack-qa.cfg"
    game.career.unlocked = 3
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await RenderingServer.frame_post_draw
    print("OPENING_BENCH_DEVICE ", RenderingServer.get_current_rendering_driver_name())
    measuring = true
    for track in range(3):
        assert(game.set_track(track))
        # Balance the position of the old and new settings within each track.
        var current_first := track % 2 == 1
        for trial in range(4):
            await _trial(track, trial, (trial in [0, 3]) == current_first)
        game.return_to_menu()
        await RenderingServer.frame_post_draw
    measuring = false
    if OS.has_feature("android"):
        _show_report()
        await RenderingServer.frame_post_draw
    if not interrupted:
        print("OPENING_BENCH_PASS")
    if not OS.has_feature("android"):
        get_tree().quit()


func _trial(track: int, trial: int, current: bool) -> void:
    game.return_to_menu()
    await RenderingServer.frame_post_draw
    game.race_variation = 0
    seed(48042)
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    Engine.max_fps = 0
    assert(game.racers.size() == 40 and game.contact_shadows.visible)
    assert(game.contact_shadows.pool.visible_instance_count == 40)
    assert(game.primary_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
    assert(is_equal_approx(game.primary_light.directional_shadow_max_distance, [36.0, 47.0, 33.0][track]))
    if not current:
        game.primary_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if (
            track == 1) else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
        game.primary_light.directional_shadow_split_1 = 0.10 if track == 1 else 0.30
        game.primary_light.directional_shadow_max_distance = [39.0, 47.0, 33.0][track]

    game.world_time = 0.0
    game.camera.fov = 64.0
    game._update_camera(STEP, true)
    game.last_checkpoint = 1
    game.trail.hide()
    var sections := {}
    for phase in ["grid", "merge"]:
        sections[phase] = await _section(phase)
    var row := {"track": track, "trial": trial,
        "mode": "current" if current else "old", "sections": sections}
    trials.append(row)
    output.store_line(JSON.stringify(row))
    output.flush()
    print("OPENING_BENCH_TRIAL ", track, " ", trial, " ", "current" if current else "old")


func _section(phase: String) -> Array[Dictionary]:
    var samples: Array[Dictionary] = []
    var grid := phase == "grid"
    var count := GRID_FRAMES if grid else MERGE_FRAMES
    if not grid:
        _place_pack(0)
        game.race_state = "RACING"
        game.race_time = 10.0
        game._update_camera(STEP, true)
        game.ui.hide_countdown()
    for warm in range(14):
        await RenderingServer.frame_post_draw
    var previous := Time.get_ticks_usec()
    for frame in range(count):
        if grid:
            game.countdown = 1.15 - frame * STEP
        else:
            _place_pack(frame)
            game.race_director.animate(game.race_time)
            game.contact_shadows.update_shadows()
        game._process(STEP)
        game.trail.emitting = false
        await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        samples.append({
            "ms": (now - previous) / 1000.0,
            "draws": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
            "pose": hash([game.camera.global_transform, game.camera.fov, game.player.position]),
            "z": game.player.position.z,
        })
        previous = now
    return samples


func _place_pack(frame: int) -> void:
    var z := ROUTE.EXIT_Z + 8.0 - frame * STEP * MERGE_SPEED
    for index in range(game.racers.size()):
        var racer: RigidBody3D = game.racers[index]
        var point: Vector3
        var x_velocity := 0.0
        if racer == game.player:
            point = _player_position(z)
            x_velocity = (_player_position(z - STEP * MERGE_SPEED).x - point.x) / STEP
        else:
            # A dense eight-lane pack passes on the main road as the player rejoins.
            var travel_z := z + (float(index / 8) - 2.0) * 1.12
            var lane := (float((index * 5 + 3) % 8) - 3.5) * 1.36
            point = Vector3(game.track_center_at(travel_z) + lane, game.height_at(travel_z) + 0.41, travel_z)
        racer.global_transform = Transform3D(Basis(Vector3.LEFT, frame * STEP * MERGE_SPEED / 0.39), point)
        racer.linear_velocity = Vector3(x_velocity, 0, -MERGE_SPEED)


func _player_position(z: float) -> Vector3:
    var point: Vector3 = game.shortcut_route.point_at(z)
    var merge := smoothstep(0.0, 1.0, (ROUTE.EXIT_Z - z) / 7.0)
    point.x = lerpf(point.x, game.track_center_at(z), merge)
    point.y = lerpf(point.y + 0.69, game.height_at(z) + 0.41, merge)
    return point


func _show_report() -> void:
    var report := PackedStringArray([
        "Marble Race · Test des ombres · 40 billes",
        "%s / %s" % [OS.get_model_name(), RenderingServer.get_video_adapter_name()],
        "%s px / %s" % [get_viewport().get_visible_rect().size, RenderingServer.get_current_rendering_driver_name()],
    ])
    if interrupted:
        report.append("Test interrompu. Ferme puis relance l’application et garde-la ouverte.")
    else:
        report.append("P95 en ms · ancien réglage → carte unique")
        for track in range(3):
            var line: String = ["Woodworks", "Glacier", "Forge"][track]
            for phase in ["grid", "merge"]:
                var p95 := {"old": 0.0, "current": 0.0}
                for row in trials:
                    if row.track != track:
                        continue
                    var times := PackedFloat32Array()
                    for sample in row.sections[phase]:
                        times.append(sample.ms)
                    p95[row.mode] += BUDGET.percentile_95(times) * 0.5
                line += " | %s %.1f → %.1f" % [
                    "Grille" if phase == "grid" else "Pont", p95.old, p95.current]
            report.append(line)
    var result := "\n".join(report)
    var layer := CanvasLayer.new()
    layer.layer = 80
    add_child(layer)
    var overlay := ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color("#111b28")
    layer.add_child(overlay)
    var column := VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    column.offset_left = 18.0
    column.offset_right = -18.0
    column.offset_top = 14.0
    column.offset_bottom = -14.0
    overlay.add_child(column)
    var details := TextEdit.new()
    details.text = result
    details.editable = false
    details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    details.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(details)
    if not interrupted:
        var copy := Button.new()
        copy.text = "Copier le rapport"
        copy.custom_minimum_size.y = 48.0
        copy.pressed.connect(func():
            DisplayServer.clipboard_set(result)
            copy.text = "Rapport copié")
        column.add_child(copy)
