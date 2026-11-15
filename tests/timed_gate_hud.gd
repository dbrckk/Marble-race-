extends SceneTree
## Phone-safe forecasts for all nine moving-gate layouts. Warnings use
## the real physical piston's future state and sound at most once per gate.
const DIRECTOR = preload("res://scripts/race_director.gd")
const ROUTE = preload("res://scripts/shortcut_route.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_timed_hud_career.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    game.audio.enabled = true
    var label: Label = game.ui.timed_gate_label
    assert(is_instance_valid(label))
    assert(label.name == "PredictedTimedGate")
    assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The new HUD cannot intercept Android taps or swipes")
    assert(label.anchor_top > game.ui.duel_label.anchor_bottom,
        "The threat predictor must not obscure the live rival prompt")
    assert(label.anchor_bottom < game.ui.rare_item_label.anchor_top,
        "The threat predictor needs its own driving row")
    assert(game.ui.race_notification_backdrop.anchor_right < game.ui.duel_label.anchor_left,
        "Sector and overtake notifications must stay beside the driving view")
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.racers.size() == 40)
            var director: Node3D = game.race_director
            assert(director.variation == layout and director.biome == biome)
            var gate_index := 1
            var marking: MultiMeshInstance3D = director.get_node("GateApproachMarkings_01")
            assert(marking.multimesh.instance_count == 12 and marking.get_child_count() == 0)
            if biome == 1:
                assert(director.obstacles[gate_index].has_node("IceShutterFrostInlays"))
            var gate_z: float = director.event_z(gate_index)
            var approach_z := gate_z+13.0
            var speed := 12.0
            var eta := 13.0/speed
            var blocked_clock := 1.0
            var clear_clock := 0.0
            if biome == 2:
                var blocked_found := false
                var clear_found := false
                for sample in range(120):
                    var t: float = float(sample)*0.08
                    if director.piston_up(gate_index,t+eta) and (
                        not director.piston_up(gate_index,t)) and not blocked_found:
                        blocked_clock = t
                        blocked_found = true
                    if not director.piston_up(gate_index,t+eta) and (
                        director.piston_up(gate_index,t)) and not clear_found:
                        clear_clock = t
                        clear_found = true
                assert(blocked_found and clear_found,
                    "Forge tests must prove opposite current and arrival states")
            var collision_x: float = director.position_at(
                gate_index,blocked_clock+eta).x
            # Deliberately enter the moving body's future footprint.
            game.player.global_position = Vector3(
                collision_x,game.height_at(approach_z)+0.8,approach_z)
            game.player.linear_velocity = Vector3(0,0,-speed)
            # The world sign displays the CURRENT collider phase; synchronize
            # its animation to the sampled authoritative clock before reading.
            director.animate(blocked_clock)
            # World-space timing signs must describe the real collision
            # phase, not a decorative fake animation. No new 3D objects.
            var sign: Label3D = director.signs[gate_index]
            assert(sign.text.contains(DIRECTOR.EVENT_NAMES[biome]),
                "Every physical gate retains its world-specific name")
            if biome == 2:
                var expected_now: String = DIRECTOR.hazard_phase_cue(
                    biome,director.piston_extension(gate_index,blocked_clock),
                    director.piston_extension(gate_index,blocked_clock+0.08)-
                    director.piston_extension(gate_index,blocked_clock))
                assert(sign.text.contains(expected_now),
                    "Forge signs must reflect the CURRENT physical piston state")
                director.animate(clear_clock)
                var clear_now: String = DIRECTOR.hazard_phase_cue(
                    biome,director.piston_extension(gate_index,clear_clock),
                    director.piston_extension(gate_index,clear_clock+0.08)-
                    director.piston_extension(gate_index,clear_clock))
                assert(director.signs[gate_index].text.contains(clear_now),
                    "Forge world sign reports current piston, HUD forecasts arrival")
                # Receding metal must never show a fake RISING warning.
                var descending_found := false
                for sample in range(130):
                    var t: float = float(sample)*0.05
                    var extension: float = director.piston_extension(gate_index,t)
                    if extension > 0.15 and extension < 0.57 and (
                        director.piston_extension(gate_index,t+0.08) <
                        extension-0.001):
                        director.animate(t)
                        assert(director.signs[gate_index].text.contains("FALLING"),
                            "Lowering Forge pistons must telegraph FALLING, not RISING")
                        descending_found = true
                        break
                assert(descending_found,
                    "Every real Forge gate needs a visible descending window")
                director.animate(blocked_clock)
            else:
                assert(sign.text.contains("SWEEP"),
                    "Woodland and Glacier signs must show true movement direction")
                var first_x: float = director.position_at(
                    gate_index,blocked_clock).x
                var next_x: float = director.position_at(
                    gate_index,blocked_clock+0.08).x
                if absf(next_x-first_x) > 0.004:
                    assert(sign.text.contains("LEFT" if next_x < first_x else "RIGHT"),
                        "Displayed sweep direction must agree with physical motion")
            director.animate(blocked_clock)
            game.race_time = blocked_clock
            var actual: Dictionary = director.event_ahead(approach_z)
            assert(int(actual["index"]) == gate_index)
            assert(is_equal_approx(float(actual["z"]),gate_z))
            assert(str(actual["side"]) != "")
            var cue_channel: int = game.audio.current_channel
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.visible,"A timed hazard must be independently visible on phone")
            assert(label.text.contains(DIRECTOR.EVENT_NAMES[biome]),
                "The HUD must identify the actual physical moving gate")
            assert(game.ui.timed_gate_backdrop.visible,
                "An imminent collision warning should have a readable background")
            assert(label.text.contains("1.1s"),
                "Arrival forecast should use measured speed and distance")
            if biome == 2:
                var bypass := "LEFT" if actual["side"] == "RIGHT" else "RIGHT"
                assert(label.text.contains("EST. BLOCKED") and label.text.contains("GO "+bypass),
                    "Forge should show the clear side of a piston that blocks at arrival")
                assert(not game.ui.biome_lane_label.visible,
                    "An imminent piston warning has priority over vent advice")
                if layout == 0:
                    var pickup: Node3D = game.race_items.items[2]
                    var saved_position := pickup.position
                    pickup.position.z = gate_z-1.0
                    game.ui.label_timer = 0.25
                    game.ui.update_hud()
                    assert(not game.ui.rare_item_label.visible,
                        "A pickup beyond a blocking piston must yield to its warning")
                    pickup.position.z = approach_z-5.0
                    game.ui.label_timer = 0.25
                    game.ui.update_hud()
                    assert(game.ui.rare_item_label.visible,
                        "A pickup encountered before the piston still needs a preview")
                    pickup.position = saved_position
            assert(game.audio.warned_timed_gates.has(gate_index),
                "One audio danger cue must sound as the moving gate approaches")
            assert(game.audio.channels[cue_channel].stream == game.audio.hazard_cues[biome])
            assert(game.audio.hazard_duck > 0.0,"A warning must be audible over the race mix")
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(game.audio.warned_timed_gates.size() == 1 and
                game.audio.current_channel == (cue_channel+1)%game.audio.channels.size(),
                "The warning cannot spam ten overlapping sounds per second")
            assert(label.text.contains("DODGE!"),
                "A real future lane intersection should clearly demand evasive action")
            assert(director.threatens_line(
                gate_index,blocked_clock,eta,collision_x,0.0),
                "A stationary lateral line through the collision envelope is unsafe")
            # The same moving gate is NOT a risk on the other side of
            # the course: neither warning sound nor red HUD cue is justified.
            var clear_x: float = game.track_center_at(gate_z)-(
                director.side_at(gate_index)*2.5)
            assert(not director.threatens_line(
                gate_index,blocked_clock,eta,clear_x,0.0),
                "Opposite-side lanes must remain safe and playable")
            game.audio.warned_timed_gates.clear()
            game.audio.hazard_cooldown = 0.0
            game.player.global_position.x = clear_x
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.text.contains("LINE CLEAR") and not game.ui.timed_gate_backdrop.visible,
                "The phone HUD must distinguish a safe racing line")
            assert(game.audio.warned_timed_gates.is_empty(),
                "Do not sound a dangerous-gate siren for a safe line")
            # Fast lateral drift into the predicted body is dangerous even
            # if the marble does not currently overlap the collider's X.
            assert(director.threatens_line(gate_index,blocked_clock,eta,
                collision_x-1.8,4.0),
                "Bounded lateral trajectory prediction must include ongoing drift")
            game.player.global_position.x = collision_x
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.text.contains("DODGE!") and
                game.audio.warned_timed_gates.has(gate_index),
                "Returning to the collision lane must restore the real hazard warning")
            if biome == 2:
                _verify_forge_feedback(game)
                # An upward piston *right now* is harmless if it will have
                # retracted when this marble arrives. Clear the warning log
                # and verify no false alarm is issued for that safe arrival.
                game.audio.warned_timed_gates.clear()
                game.audio.hazard_cooldown = 0.0
                director.animate(clear_clock)
                game.race_time = clear_clock
                assert(director.piston_up(gate_index,clear_clock))
                assert(not director.piston_up(gate_index,clear_clock+eta))
                game.ui.label_timer = 0.25
                game.ui.update_hud()
                assert(label.text.contains("EST. OPEN") and
                    label.text.contains("LINE CLEAR"),
                    "A retracted future piston must show an explicitly safe window")
                assert(not director.threatens_line(
                    gate_index,clear_clock,eta,collision_x,0.0),
                    "Buried pistons must not be reported as dangerous")
                assert(game.audio.warned_timed_gates.is_empty(),
                    "No audio danger alert is allowed for a predicted clear piston")
                director.animate(blocked_clock)
                game.race_time = blocked_clock
                assert(not director.piston_up(gate_index,blocked_clock))
                assert(director.piston_up(gate_index,blocked_clock+eta))
                game.ui.label_timer = 0.25
                game.ui.update_hud()
                assert(game.audio.warned_timed_gates.has(gate_index),
                    "The audio must warn when a currently down piston WILL rise")
            game.player.global_position.z = gate_z+35.0
            game.player.linear_velocity.z = -23.0
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(label.visible,"Full speed gives the player more distance to react")
            game.player.linear_velocity.z = -12.0
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(not label.visible,
                "Do not clutter the HUD with hazards beyond the lookahead")
            if biome != 0:
                _verify_biome_lane(game,biome)
            game.return_to_menu()
            assert(not game.ui.hud_layer.visible)
    _verify_audio_cues(game.audio)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_timed_hud_career.cfg"))
    print("TIMED_HUD_PASS: 9 layouts, speed-aware approaches, original cues and nonoverlapping Forge race feedback")
    quit(0)

func _verify_forge_feedback(game: Node3D) -> void:
    var ui: CanvasLayer = game.ui
    var card: Panel = ui.race_notification_backdrop
    var rival: RigidBody3D = game.racers[0]
    rival.global_position = game.player.global_position+Vector3(1.40,0.0,-0.55)
    rival.linear_velocity = Vector3(0,0,-12)
    for i in range(6):
        game.race_moments.tick(0.12)
    ui.show_checkpoint(2,13.72,13.88)
    ui.show_race_moment("TURBO",0.65)
    assert(card.visible and ui.checkpoint_label.visible and not ui.race_moment_label.visible,
        "Sector timing has priority over a routine boost toast")
    ui.show_overtake(2,"")
    ui.label_timer = 0.25
    ui.update_hud()
    assert(ui.timed_gate_backdrop.visible and ui.duel_label.visible and ui.rival_marker.visible,
        "An urgent piston, the real rival and their marker must survive a race notification")
    assert(ui.race_moment_label.visible and ui.race_moment_label.text == "DOUBLE PASS!" and
        not ui.checkpoint_label.visible and not ui.position_feedback.visible,
        "A confirmed double pass gets the one performance slot")
    assert(card.mouse_filter == Control.MOUSE_FILTER_IGNORE and
        ui.race_moment_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The performance card cannot swallow a swipe or tap")
    assert(not card.get_global_rect().intersects(ui.duel_label.get_global_rect()) and
        not ui.duel_label.get_global_rect().intersects(ui.timed_gate_label.get_global_rect()),
        "Rendered regions must stay disjoint even when all three are visible")
    ui.moment_remaining = 0.0
    ui.update_hud()
    assert(ui.checkpoint_label.visible and not ui.race_moment_label.visible,
        "A still-current split can use the slot once the pass expires")
    ui.toast_remaining = 0.0
    ui.update_hud()
    assert(not card.visible, "The slot must clear after notifications expire")
    game.race_moments.reset_round()

func _verify_biome_lane(game: Node3D, biome: int) -> void:
    var mechanics: Node3D = game.course_mechanics
    var label: Label = game.ui.biome_lane_label
    assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(label.anchor_top > game.ui.rare_item_label.anchor_bottom)
    var first: Vector3 = mechanics.zones[0].global_position
    var position := first+Vector3(0.0,0.55,12.0)
    var velocity := Vector3(0.0,0.0,-12.0)
    var zone_side := "LEFT" if mechanics.lane_offset(0,biome,mechanics.variation) < 0.0 else "RIGHT"
    var alternate := "LEFT" if zone_side == "RIGHT" else "RIGHT"
    if biome == 1:
        assert(mechanics.zones[0].has_node("IceLaneEdgesAndChevrons"))
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("ICE "+zone_side) and
            label.text.contains("STEER GENTLY"))
        position.x = game.track_center_at(first.z)
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("GRIP "+alternate))
        position.x = first.x-2.0
        assert(mechanics.upcoming_lane(position,Vector3(5,0,-12),INF)["on_line"],
            "Lateral drift must forecast ice contact")
    else:
        assert(mechanics.zones[0].has_node("VentFootprint"))
        var rim := mechanics.vent_rims[0].material_override as StandardMaterial3D
        mechanics.race_clock = 2.75
        mechanics._process(0.016)
        var cool_tint := rim.albedo_color
        mechanics.race_clock = 4.45
        mechanics._process(0.016)
        assert(rim.albedo_color != cool_tint)
        mechanics.race_clock = 0.10
        mechanics._process(0.016)
        assert(rim.albedo_color.is_equal_approx(Color("#ff7549")))
        assert(game.race_director.obstacles[0].has_node("PistonSteelCap"))
        # The vent is cool on approach, then ignites before the marble
        # reaches the edge of its circular collision footprint.
        mechanics.race_clock = 4.25
        game.race_time = 1.45
        game.audio.hazard_cooldown = 0.0
        var vent_channel: int = game.audio.current_channel
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("DODGE "+alternate))
        assert(game.audio.warned_vents.has(0) and
            game.audio.channels[vent_channel].stream == game.audio.hazard_cues[3])
        _update_at(game,position,velocity)
        assert(game.audio.current_channel == (vent_channel+1)%game.audio.channels.size(),
            "Repeated updates must not replay the vent warning")
        game.net.role = "client"
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("EST. COOL"),
            "Clients forecast from the replicated race time")
        game.net.role = "offline"
        mechanics.race_clock = 1.45
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("EST. COOL"))
        mechanics.race_clock = 3.83
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("DODGE "+alternate),
            "Warn when a cool vent ignites during the crossing")
        position.x = game.track_center_at(first.z)
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("LINE CLEAR"))
    var second: Vector3 = mechanics.zones[1].global_position
    var bypass: Vector3 = game.shortcut_route.point_at(second.z+3.0)
    _update_at(game,bypass+Vector3.UP,velocity)
    assert(game.ui.shortcut_label.text.contains("MERGE") and not label.visible,
        "The deck bypasses ice and vents on the main track")
    assert(mechanics.upcoming_lane(bypass,velocity,ROUTE.EXIT_Z).is_empty())
    var next_gate_z: float = game.race_director.event_z(1)
    if next_gate_z > ROUTE.EXIT_Z-24.0:
        var merge: Vector3 = game.shortcut_route.point_at(ROUTE.EXIT_Z+2.0)
        _update_at(game,merge+Vector3.UP,velocity)
        assert(game.ui.timed_gate_label.visible,
            "A warning after the merge remains relevant while still on the bridge")
    _update_at(game,Vector3(0,0,2),velocity)
    assert(not label.visible,"No surface cue outside the speed-scaled lookahead")

func _update_at(game: Node3D, position: Vector3, velocity: Vector3) -> void:
    game.player.global_position = position
    game.player.linear_velocity = velocity
    game.ui.label_timer = 0.25
    game.ui.update_hud()

func _verify_audio_cues(audio: Node3D) -> void:
    var fingerprints: Array[int] = []
    for cue in audio.hazard_cues:
        assert(cue is AudioStreamWAV and cue.get_length() < 0.4)
        var fingerprint: int = hash(cue.data)
        assert(not fingerprints.has(fingerprint),"Use four distinct warning sounds")
        fingerprints.append(fingerprint)
    assert(fingerprints.size() == 4 and audio.channels.size() == 10)
    audio.enabled = false
    audio.begin_race()
    audio.warn_timed_gate(0,true)
    audio.warn_vent(0)
    assert(audio.warned_timed_gates.is_empty() and audio.warned_vents.is_empty())
    audio.enabled = true
    audio.warn_vent(0)
    audio.warn_timed_gate(1,true)
    assert(audio.warned_timed_gates.is_empty(),"A nearby second warning must not overlap")
    audio._process(0.40)
    audio.warn_timed_gate(1,true)
    assert(audio.warned_timed_gates.has(1),"A delayed gate warning may still play")
    audio.begin_race()
    assert(audio.warned_vents.is_empty() and audio.warned_timed_gates.is_empty())
