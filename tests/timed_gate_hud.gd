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
                assert(await _verify_forge_signals(director))
                director.animate(clear_clock)
                assert(director.signs[gate_index].text.contains("BLOCKED") or
                    director.signs[gate_index].text.contains("RISING") or
                    director.signs[gate_index].text.contains("FALLING"),
                    "The raised world piston can be open on arrival in the HUD forecast")
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
            if biome == 2:
                var farther: Dictionary = director.event_ahead(
                    game.player.global_position.z,INF,38.0)
                assert(int(farther.get("index",-1)) == gate_index and
                    (label.visible or game.ui.biome_lane_label.visible),
                    "A nearer vent may occupy the HUD while a piston is in forecast range")
            else:
                assert(label.visible,"Full speed gives the player more distance to react")
            game.player.linear_velocity.z = -12.0
            game.ui.label_timer = 0.25
            game.ui.update_hud()
            assert(not label.visible,
                "Do not clutter the HUD with hazards beyond the lookahead")
            if biome != 0:
                _verify_biome_lane(game,biome)
            if biome == 1:
                assert(_verify_glacier_sequence(game))
                assert(_verify_glacier_bridge_return(game))
            if biome == 2:
                _verify_forge_exit(game)
                _verify_forge_encounter_order(game)
            assert(_verify_final_approach(game))
            game.return_to_menu()
            assert(not game.ui.hud_layer.visible)
    _verify_audio_cues(game.audio)
    game.queue_free()
    for i in range(3):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_timed_hud_career.cfg"))
    print("TIMED_HUD_PASS: 9 layouts, speed-aware approaches, original cues, Glacier ice and bridge handoffs, Forge signals, encounter order, piston crossing windows and final obstacle priority")
    quit(0)

func _verify_final_approach(game: Node3D) -> bool:
    var hud: CanvasLayer = game.ui
    var art: MeshInstance3D = game.final_obstacle_art
    assert(art.mesh.get_surface_count() == 1 and art.entry_gaps.is_empty())
    assert(art.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    assert(art.baffle_footprints.size() == 2)
    var speed := Vector3(0,0,-24.0)
    var right: Rect2 = art.baffle_footprints[1]
    var baffle_x: float = art.global_position.x+right.get_center().x
    var z: float = right.end.y+1.0
    var approach := Vector3(baffle_x,game.height_at(z)+0.68,z)
    game.set_graphics_quality(0)
    assert(art.is_visible_in_tree(), "The final warning paint belongs in Economy")
    game.set_graphics_quality(1)
    if art.spinner_radius > 0.0:
        var sweep_z: float = art.spinner_center.y+art.spinner_radius+1.2
        var sweep_x: float = art.global_position.x+art.spinner_center.x
        var sweep := Vector3(sweep_x,game.height_at(sweep_z)+0.68,sweep_z)
        var hint: Dictionary = art.approach_warning(sweep,speed,1.4)
        assert(hint.get("text","").contains("PADDLE SWEEP"))
    assert(art.approach_warning(Vector3(art.global_position.x-5.15,approach.y,approach.z),speed,1.4).is_empty(),
        "The baffle warning must follow the lane and stay silent on the opposite shoulder once its baffle is behind")
    hud.show_checkpoint(3,7.0)
    hud.show_race_moment("TURBO",1.0,1)
    _update_at(game,approach,speed)
    assert(hud.final_danger_active and hud.timed_gate_backdrop.visible and
        hud.timed_gate_label.visible and hud.timed_gate_label.text.contains("BAFFLE RIGHT") and
        not hud.hazard_label.visible and not hud.biome_lane_label.visible and
        not hud.rare_item_label.visible and not hud.race_notification_backdrop.visible,
        "The final physical baffle takes the driving row ahead of sprint and bonus toasts")
    hud.show_race_moment("PHOTO FINISH!",1.4,3)
    assert(hud.race_moment_label.visible, "Confirmed finish feedback keeps its priority")
    var clear_z: float = game.final_straight_z-0.25
    _update_at(game,Vector3(game.track_center_at(clear_z),game.height_at(clear_z)+0.7,clear_z),speed)
    assert(not hud.final_danger_active and not hud.timed_gate_label.visible and
        not hud.timed_gate_backdrop.visible)
    return true

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
    if biome == 1:
        assert(label.anchor_top > game.ui.rare_item_label.anchor_bottom)
    var first: Vector3 = mechanics.zones[0].global_position
    var position := first+Vector3(0.0,0.55,12.0)
    var velocity := Vector3(0.0,0.0,-12.0)
    var zone_side := "LEFT" if mechanics.lane_offset(0,biome,mechanics.variation) < 0.0 else "RIGHT"
    var alternate := "LEFT" if zone_side == "RIGHT" else "RIGHT"
    if biome == 1:
        _verify_glacier_markings(game,mechanics)
        var dry_hint: Dictionary = mechanics.upcoming_lane(position,velocity,INF)
        var grip := "GRIP CENTER" if dry_hint["grip_center"] else "GRIP "+alternate
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains("ICE "+zone_side) and
            label.text.contains(grip),
            "Before reaching the slab, the player can still choose the grippy side")
        _update_at(game,first+Vector3(0.0,0.55,6.0),Vector3(0,0,-23))
        assert(label.visible and label.text.contains("STEER GENTLY") and
            label.text.contains("0.1s"),
            "An imminent entry uses a fast readout and gentle steering")
        _update_at(game,first+Vector3.UP*0.55,Vector3(0,0,-23))
        assert(label.visible and label.text.contains("STEER GENTLY"),
            "The HUD distinguishes actual ice contact from an approach")
        position.x = game.track_center_at(first.z)
        _update_at(game,position,velocity)
        assert(label.visible and label.text.contains(grip))
        position.x = first.x-2.0
        assert(mechanics.upcoming_lane(position,Vector3(5,0,-12),INF)["on_line"],
            "Lateral drift must forecast ice contact")
        var behind := Vector3(first.x,first.y+0.55,first.z-5.0)
        var next_ice: Dictionary = mechanics.upcoming_lane(behind,velocity,INF)
        assert(not next_ice.get("on_ice",false),
            "Leaving the slab clears the on-ice cue")
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
    assert(game.ui.bridge_approach_active and not label.visible,
        "The detached deck bypasses ice and vents before any merge cue")
    assert(mechanics.upcoming_lane(bypass,velocity,ROUTE.EXIT_Z).is_empty())
    var next_gate_z: float = game.race_director.event_z(1)
    if next_gate_z > ROUTE.EXIT_Z-24.0:
        var merge: Vector3 = game.shortcut_route.point_at(ROUTE.EXIT_Z+2.0)
        _update_at(game,merge+Vector3.UP,velocity)
        assert(game.ui.timed_gate_label.visible,
            "A warning after the merge remains relevant while still on the bridge")
    _update_at(game,Vector3(0,0,2),velocity)
    assert(not label.visible,"No surface cue outside the speed-scaled lookahead")

func _verify_glacier_markings(game: Node3D, mechanics: Node3D) -> void:
    var guides := mechanics.get_node("GlacierGripApproach") as MultiMeshInstance3D
    var row_count: int = mechanics.GRIP_MARK_OFFSETS.size()
    assert(guides.multimesh.instance_count == mechanics.zones.size()*row_count*4 and
        guides.multimesh.use_colors and guides.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "All Glacier approach arrows share one shadow-free draw batch")
    assert(mechanics.grip_mark_origins.size() == mechanics.zones.size()*row_count)
    for index in range(mechanics.zones.size()):
        var zone: Node3D = mechanics.zones[index]
        var ice := zone.get_node("LowFrictionIce") as StaticBody3D
        var shape := ice.get_child(0).shape as BoxShape3D
        var surface := zone.get_node("GlacierIceSurface") as MeshInstance3D
        var edge := zone.get_node("IceLaneEdgesAndChevrons") as MultiMeshInstance3D
        var surface_box := surface.mesh as BoxMesh
        assert(is_equal_approx(surface_box.size.x,shape.size.x) and
            is_equal_approx(surface_box.size.z,shape.size.z) and
            is_equal_approx(edge.rotation.x,ice.rotation.x) and
            is_equal_approx(surface.rotation.x,ice.rotation.x),
            "Visible boundaries and tilt must match the low-friction slab")
        assert(edge.multimesh.instance_count == 12 and
            ice.physics_material_override.friction < 0.10)
        var dry_side: float = -signf(mechanics.lane_offset(index,1,mechanics.variation))
        var gate: int = mechanics.ice_exit_shutters[index]
        var to_center: bool = gate >= 0 and game.race_director.side_at(gate) == dry_side
        for row in range(row_count):
            var mark: Vector3 = mechanics.grip_mark_origins[index*row_count+row]
            var offset: float = mark.x-game.track_center_at(mark.z)
            var minimum := -0.55 if to_center else 0.75
            assert(offset*dry_side > minimum and offset*dry_side < 4.35 and
                absf(mark.x-zone.position.x) > shape.size.x*0.5+0.7,
                "Approach paint must stay clear of the icy lane")
            if to_center and row == row_count-1:
                assert(absf(offset) < 1.10,"The final chevron must aim inside the shutter's sweep")
            assert(is_equal_approx(mark.z-zone.position.z,mechanics.GRIP_MARK_OFFSETS[row]))

func _verify_glacier_sequence(game: Node3D) -> bool:
    var director: Node3D = game.race_director
    var mechanics: Node3D = game.course_mechanics
    var hud: CanvasLayer = game.ui
    var slab: Vector3 = mechanics.zones[0].global_position
    var speed := 23.0
    var velocity := Vector3(0,0,-speed)
    var gate := 0
    assert(mechanics.ice_exit_shutters[0] == gate)
    var gate_z: float = director.event_z(gate)
    var side: String = "LEFT" if director.side_at(gate) < 0.0 else "RIGHT"
    var before := slab+Vector3(0.0,0.60,13.0)
    _update_at(game,before,velocity)
    assert(hud.biome_lane_label.visible and not hud.timed_gate_label.visible,
        "Approaching the paired obstacles puts ice guidance first")
    var ice: Dictionary = mechanics.upcoming_lane(before,velocity,INF)
    var grip := "GRIP CENTER" if ice["grip_center"] else "GRIP "+str(ice["other"])
    assert(hud.biome_lane_label.text.contains(grip))
    var dry_x: float = game.track_center_at(gate_z)
    for sample in range(30):
        var t := float(sample)*0.17
        assert(not director.threatens_line(gate,t,0.16,dry_x,0.0),
            "The painted central option stays outside the moving shutter's full sweep")
    var clock := 0.65
    director.animate(clock)
    game.audio.warned_timed_gates.clear()
    game.audio.hazard_cooldown = 0.0
    _update_at(game,slab+Vector3.UP*0.60,velocity)
    assert(hud.biome_lane_label.text.contains("STEER GENTLY") and
        hud.biome_lane_label.visible and not hud.timed_gate_label.visible,
        "While on the slab, movement and shutter advice must share one message")
    assert(not game.audio.warned_timed_gates.has(gate))
    if director.threatens_line(gate,clock,(slab.z-gate_z)/speed,slab.x,0.0):
        assert(hud.biome_lane_label.text.contains("SHUTTER "+side+" AFTER ICE"))
    var clear_z: float = slab.z-mechanics.ZONE_LENGTH*0.5-0.22
    var x: float = director.position_at(gate,clock+(clear_z-gate_z)/speed).x
    _update_at(game,Vector3(x,game.height_at(clear_z)+0.60,clear_z),velocity)
    assert(hud.timed_gate_label.visible and not hud.biome_lane_label.visible and
        hud.timed_gate_label.text.contains("ICE SHUTTER "+side),
        "Crossing the ice exit restores the actual shutter forecast")
    assert(hud.timed_gate_label.text.contains("DODGE!") and
        game.audio.warned_timed_gates.has(gate),
        "The shutter warning sound remains available after leaving the ice")
    game.audio.hazard_cooldown = 0.0
    var channel: int = game.audio.current_channel
    _update_at(game,Vector3(x,game.height_at(clear_z)+0.60,clear_z),velocity)
    assert(game.audio.current_channel == channel,
        "A shutter cue cannot replay each HUD frame")
    _update_at(game,Vector3(x,game.height_at(gate_z-1.0)+0.60,gate_z-1.0),velocity)
    assert(not hud.biome_lane_label.visible or not hud.biome_lane_label.text.contains("AFTER ICE"))
    return true

func _verify_glacier_bridge_return(game: Node3D) -> bool:
    var director: Node3D = game.race_director
    var road: Node3D = game.shortcut_route
    var hud: CanvasLayer = game.ui
    var gate := 1
    var gate_z: float = director.event_z(gate)
    var speed := 23.0
    var velocity := Vector3(0,0,-speed)
    var arrows := road.get_node("RouteDirectionArrows") as MultiMeshInstance3D
    assert(road.glacier_return_arrows.size() == 8 and arrows.multimesh.instance_count == 18 and
        arrows.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    var previous := INF
    var ice: Node3D = game.course_mechanics.zones[2]
    var ice_shape := ice.get_node("LowFrictionIce").get_child(0).shape as BoxShape3D
    for arrow: Transform3D in road.glacier_return_arrows:
        var at := arrow.origin
        assert(at.z < previous)
        previous = at.z
        var arrow_depth := arrows.multimesh.mesh.get_aabb().size.z*0.5
        if at.z > ROUTE.EXIT_Z:
            assert(absf(at.x-road.point_at(at.z).x) <= 0.61,
                "Approach arrows follow the actual deck")
        else:
            assert(at.z+arrow_depth < ice.position.z-ice_shape.size.z*0.5,
                "Return arrows on the main track stay beyond the ice slab")
    var last_arrow: Vector3 = road.glacier_return_arrows.back().origin
    assert(last_arrow.z > gate_z and absf(last_arrow.x-game.track_center_at(gate_z)) < 2.0)
    var center_x: float = game.track_center_at(gate_z)
    for i in range(40):
        assert(not director.threatens_line(gate,float(i)*0.11,0.9,center_x,0.0),
            "The center avoids the complete sweep of this shutter")

    game.audio.warned_timed_gates.clear()
    game.audio.hazard_cooldown = 0.0
    _update_at(game,road.point_at(ROUTE.EXIT_Z+30.0)+Vector3.UP*0.73,velocity)
    assert(hud.bridge_approach_active and not hud.shortcut_label.visible and
        not hud.timed_gate_label.visible)
    _update_at(game,road.point_at(ROUTE.EXIT_Z+16.0)+Vector3.UP*0.73,velocity)
    var preview: String = hud.timed_gate_label.text
    assert(hud.timed_gate_label.visible and preview.contains("MERGE RIGHT") and
        preview.contains("16m  /  0.7s") and not hud.biome_lane_label.visible and
        not hud.shortcut_label.visible and not hud.hazard_label.visible)
    assert(not game.audio.warned_timed_gates.has(gate))
    var lip: Vector3 = road.point_at(ROUTE.EXIT_Z+1.1)+Vector3.UP*0.73
    assert(road.shortcut_hint(lip).is_empty(),"The shared lip alone does not establish bridge context")
    _update_at(game,lip,velocity)
    assert(hud.bridge_approach_active and not hud.shortcut_label.visible and
        hud.timed_gate_label.visible and hud.timed_gate_label.text.contains("AIM CENTER") and
        hud.timed_gate_label.text.contains("MERGE RIGHT") and
        hud.timed_gate_label.text.contains("SHUTTER") and not hud.hazard_label.visible)
    assert(not game.audio.warned_timed_gates.has(gate),
        "A bridge preview must leave the immediate collision sound available")

    var z := ROUTE.EXIT_Z-1.0
    var eta := (z-gate_z)/speed
    var blocked_x: float = director.position_at(gate,director.clock+eta).x
    _update_at(game,Vector3(blocked_x,game.height_at(z)+0.64,z),velocity)
    assert(not hud.bridge_approach_active and not hud.shortcut_label.visible and
        hud.timed_gate_label.visible and hud.timed_gate_label.text.contains("DODGE!"))
    assert(game.audio.warned_timed_gates.has(gate),
        "The real collision warning is still available after the join")
    assert(_verify_glacier_crossing_window(game,director,gate),
        "The alert must cover both ends of the shutter's physical footprint")
    var main_z := ROUTE.EXIT_Z+1.1
    _update_at(game,Vector3(game.track_center_at(main_z),game.height_at(main_z)+0.64,main_z),velocity)
    assert(not hud.bridge_approach_active and not hud.shortcut_label.visible and
        not hud.timed_gate_label.text.contains("MERGE"),
        "Main-track racers never get bridge-specific instructions")
    return true

func _verify_glacier_crossing_window(game: Node3D, director: Node3D, gate: int) -> bool:
    var gate_z: float = director.event_z(gate)
    var side: float = director.side_at(gate)
    var speed := 4.0
    var eta := 0.65
    var half_window: float = (director.BODY_DEPTH*0.5+director.MARBLE_CLEARANCE)/speed
    var range_x: float = director.LANE_THREAT_RADIUS
    var chosen_clock := -1.0
    var x := 0.0
    # Pick a legal line that clips the shutter's leading edge but would
    # be called clear by a single sample at its center.
    for sample in range(80):
        var t: float = director.period()*float(sample)/80.0
        var entry_x: float = director.position_at(gate,t+eta-half_window).x
        var center_x: float = director.position_at(gate,t+eta).x
        if (center_x-entry_x)*side > 0.24:
            chosen_clock = t
            x = center_x-side*(range_x+0.035)
            break
    assert(chosen_clock >= 0.0)
    director.animate(chosen_clock)
    var entry_x: float = director.position_at(gate,chosen_clock+eta-half_window).x
    assert(absf(x-entry_x) < director.BODY_WIDTH*0.5+director.MARBLE_CLEARANCE)
    assert(not director.threatens_line(gate,chosen_clock,eta,x,0.0))
    assert(director.glacier_return_threatens_crossing(eta,speed,x,0.0))
    assert(not director.glacier_return_threatens_crossing(
        eta,speed,game.track_center_at(gate_z),0.0))
    game.audio.warned_timed_gates.clear()
    game.audio.hazard_cooldown = 0.0
    var z := gate_z+eta*speed
    _update_at(game,Vector3(x,game.height_at(z)+0.64,z),Vector3(0,0,-speed))
    assert(game.ui.timed_gate_label.text.contains("DODGE!"))
    assert(game.audio.warned_timed_gates.has(gate))
    return true

func _verify_forge_signals(director: Node3D) -> bool:
    for gate in range(3):
        var rail: MeshInstance3D = director.warning_rings[gate]
        var contact: AnimatableBody3D = director.obstacles[gate]
        var deck_placement := rail.transform
        var markings: MultiMeshInstance3D = director.forge_approach_paint[gate]
        assert(rail.mesh.get_surface_count() == 1 and
            rail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        assert(markings.multimesh.instance_count == 12 and
            markings.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
        var cases := [
            [0.60,"OPEN",DIRECTOR.OPEN_COLOR,false],
            [0.91,"GET READY",DIRECTOR.MOVING_COLOR,false],
            [0.01,"GET READY",DIRECTOR.MOVING_COLOR,false],
            [0.04,"RISING",DIRECTOR.MOVING_COLOR,false],
            [0.20,"BLOCKED",DIRECTOR.BLOCKED_COLOR,true],
            [0.42,"FALLING",DIRECTOR.MOVING_COLOR,false],
        ]
        for state in cases:
            var t := fposmod(float(state[0])*director.period()-
                float(gate)*1.71-float(director.variation)*1.29,director.period())
            director.animate(t)
            await physics_frame
            await physics_frame
            var notice: Label3D = director.signs[gate]
            var material := rail.material_override as StandardMaterial3D
            var tint: Color = state[2]
            assert(director.piston_up(gate,t) == state[3] and
                contact.position.is_equal_approx(director.position_at(gate,t)))
            assert(notice.text.ends_with(state[1]) and notice.modulate == tint)
            assert(material.albedo_color == tint and material.emission == tint)
            assert(rail.transform.is_equal_approx(deck_placement) and
                is_equal_approx(rail.position.x,contact.position.x),
                "Piston signals are fixed around the collision lane through the entire cycle")
            # The headless dummy renderer does not retain MultiMesh colors.
            if DisplayServer.get_name() != "headless":
                for row in range(3):
                    for stripe in range(1,4):
                        var error := markings.multimesh.get_instance_color(row*4+stripe)-tint
                        assert(Vector3(error.r,error.g,error.b).length() < 0.007)
        assert(rail.mesh.get_aabb().size.y > 0.85,
            "The shoulder light must rise above the deck brackets")
    return true

func _verify_forge_exit(game: Node3D) -> void:
    var director: Node3D = game.race_director
    var gate := DIRECTOR.FORGE_EXIT_GATE
    var speed := 23.0
    var z := ROUTE.EXIT_Z+4.0
    var eta: float = (z-director.event_z(gate))/speed
    var playhead := -1.0
    var clear_window := -1.0
    for phase in range(260):
        var t := float(phase)*0.02
        director.animate(t)
        if playhead < 0.0 and director.piston_up(gate,t+eta) and not director.piston_up(gate,t):
            playhead = t
        if clear_window < 0.0 and not director.forge_exit_blocks_during_crossing(eta,speed):
            clear_window = t
        if playhead >= 0.0 and clear_window >= 0.0:
            break
    assert(playhead >= 0.0 and clear_window >= 0.0)
    var at: Vector3 = game.shortcut_route.point_at(z)+Vector3.UP*0.73
    game.audio.warned_timed_gates.clear()
    game.audio.hazard_cooldown = 0.0
    director.animate(playhead)
    _update_at(game,at,Vector3(0,0,-speed))
    var hud: CanvasLayer = game.ui
    var action := "KEEP LEFT" if director.side_at(gate) > 0.0 else "AIM CENTER"
    assert(hud.bridge_approach_active and hud.shortcut_label.visible and
        hud.timed_gate_backdrop.visible and hud.timed_gate_label.text.contains(action) and
        hud.timed_gate_label.text.contains("AFTER BRIDGE") and
        not hud.timed_gate_label.text.contains("LINE CLEAR"),
        "A piston that rises after the merge must give advance lane advice")
    assert(not game.audio.warned_timed_gates.has(gate),
        "A bridge preview must leave the immediate collision cue available")
    director.animate(clear_window)
    _update_at(game,at,Vector3(0,0,-speed))
    assert(hud.timed_gate_label.text.contains("OPEN") and not hud.timed_gate_backdrop.visible,
        "A clear crossing window needs a calm status after the bridge")
    var window_found := false
    for phase in range(420):
        var t := float(phase)*0.013
        director.animate(t)
        if not director.piston_up(gate,t+eta) and director.forge_exit_blocks_during_crossing(eta,speed):
            window_found = true
            break
    assert(window_found,"The crossing window must include the front and rear of the marble")
    assert(director.has_node("ForgeExitPistonPlaque") and
        director.forge_approach_paint[gate].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    director.animate(playhead)
    assert(director.signs[gate].text.contains("OPEN") or
        director.signs[gate].text.contains("GET READY") or
        director.signs[gate].text.contains("RISING") or director.signs[gate].text.contains("FALLING"))
    var passed_z := ROUTE.EXIT_Z-0.5
    var gate_x: float = director.position_at(gate,playhead).x
    _update_at(game,Vector3(gate_x,game.height_at(passed_z)+0.73,passed_z),Vector3(0,0,-speed))
    assert(not hud.shortcut_label.visible and not hud.bridge_approach_active and
        not hud.timed_gate_label.text.contains("AFTER BRIDGE"),
        "After the join, use the regular live racing line")

func _verify_forge_encounter_order(game: Node3D) -> void:
    var hud: CanvasLayer = game.ui
    var director: Node3D = game.race_director
    var mechanics: Node3D = game.course_mechanics
    var gate := DIRECTOR.FORGE_EXIT_GATE
    var gate_z: float = director.event_z(gate)
    var gate_x: float = director.position_at(gate,0.0).x
    var vent: Node3D = mechanics.zones[3]
    var pickup: Node3D = game.race_items.items[2]
    var vent_origin := vent.position
    var preceding_vent: Node3D = mechanics.zones[2]
    var preceding_origin := preceding_vent.position
    var pickup_origin := pickup.position
    var approach_z := gate_z+18.0
    preceding_vent.position.z = approach_z+6.0
    var approach := Vector3(gate_x,game.height_at(approach_z)+0.73,approach_z)
    var velocity := Vector3(0,0,-23.0)
    var eta := (approach_z-gate_z)/23.0
    for sample in range(120):
        var clock := float(sample)*0.05
        if director.piston_up(gate,clock+eta):
            director.animate(clock)
            break
    vent.position = Vector3(gate_x,vent_origin.y,gate_z+7.0)
    mechanics.race_clock = 1.3
    pickup.position.z = gate_z-2.0
    game.audio.warned_timed_gates.clear()
    game.audio.warned_vents.clear()
    game.audio.hazard_cooldown = 0.0
    _update_at(game,approach,velocity)
    assert(hud.biome_lane_label.visible and hud.biome_lane_label.text.contains("DODGE") and
        hud.timed_gate_backdrop.visible and not hud.timed_gate_label.visible and
        not hud.rare_item_label.visible,
        "A threatening vent before the piston gets the primary row and defers the item")
    assert(game.audio.warned_vents.has(3) and not game.audio.warned_timed_gates.has(gate))
    assert(not hud.biome_lane_label.get_global_rect().intersects(hud.rare_item_label.get_global_rect()))
    pickup.position.z = approach_z-4.0
    _update_at(game,approach,velocity)
    assert(hud.rare_item_label.visible and hud.biome_lane_label.visible,
        "A reachable item before the vent remains visible below the warning")
    pickup.position.z = gate_z-2.0
    vent.position.z = gate_z-5.0
    _update_at(game,approach,velocity)
    assert(hud.timed_gate_label.visible and not hud.biome_lane_label.visible and
        hud.timed_gate_backdrop.visible and not hud.rare_item_label.visible,
        "An earlier blocking piston takes the slot when the vent lies farther away")
    var after_gate := Vector3(gate_x,game.height_at(gate_z-1.0)+0.73,gate_z-1.0)
    _update_at(game,after_gate,velocity)
    assert(hud.biome_lane_label.visible and not hud.timed_gate_label.visible and
        hud.rare_item_label.visible,
        "Passing the piston restores the next vent and reachable item cues")
    vent.position = vent_origin
    preceding_vent.position = preceding_origin
    pickup.position = pickup_origin

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
