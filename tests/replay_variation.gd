extends SceneTree
const TrackSurface = preload("res://scripts/track_surface.gd")
const OpeningObstacles = preload("res://scripts/opening_obstacles.gd")
const FinishLine = preload("res://scripts/finish_line.gd")
const Racer = preload("res://scripts/marble.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _check_rail_batch(game: Node3D, biome: int) -> Mesh:
    var art := game.track_surface.get_node("ProfiledSafetyRails") as MultiMeshInstance3D
    var instances := art.multimesh
    var mesh := instances.mesh
    assert(mesh.get_surface_count() == 1 and mesh.get_faces().size()/3 <= 60,
        "Keep one lightweight draw surface per continuous rail profile")
    assert(mesh.get_aabb().size.is_equal_approx(TrackSurface.RAIL),
        "Rail silhouette needs to stay within the hitbox envelope")
    var expected := 105 if biome == 1 else 106
    assert(instances.instance_count == expected, "Preserve every rail and shortcut opening")
    var index := 0
    for section in game.board.get_children():
        if not section.name.begins_with("Course_"):
            continue
        for child in section.get_children():
            if not child is StaticBody3D or child.get_child_count() != 1:
                continue
            var collider := child.get_child(0) as CollisionShape3D
            if collider == null or not collider.shape is BoxShape3D:
                continue
            if not collider.shape.size.is_equal_approx(TrackSurface.RAIL):
                continue
            # The headless renderer's dummy MultiMesh does not read transforms back.
            var pose: Transform3D = art.global_transform * game.track_surface.rails[index]
            assert(child.global_transform.is_equal_approx(pose),
                "Rendered rails must follow the physical guards and track slope")
            index += 1
    assert(index == expected)
    game.set_graphics_quality(0)
    assert(art.is_visible_in_tree(), "Every quality tier must show the course boundaries")
    game.set_graphics_quality(1)
    return mesh

func _check_start_gate(game: Node3D) -> Mesh:
    var gate: Node3D = game.start_gate
    var towers := gate.get_node("StartTowers") as MeshInstance3D
    var lamps := gate.get_node("SignalLamps") as MultiMeshInstance3D
    var mesh := towers.mesh
    assert(gate.get_child_count() == 2 and mesh.get_surface_count() == 1)
    assert(lamps.multimesh.instance_count == 6 and lamps.multimesh.use_colors)
    assert(towers.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
        lamps.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    for vertex in mesh.get_faces():
        assert(absf(vertex.x) >= 5.6, "Keep the approach to the first obstacle unobstructed")
    var signal_label: Label = game.ui.countdown_label
    var panel := signal_label.get_parent() as Control
    assert(panel.anchor_right < 0.2 and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
    assert(signal_label.is_visible_in_tree() and signal_label.text == "READY")
    assert(gate.signal_stage == -1)
    for count in [3,2,1]:
        game.countdown = float(count)
        game._process(1.0/60.0)
        assert(gate.signal_stage == count and signal_label.text == str(count))
        assert(game.player.freeze and game.race_state == "COUNTDOWN")
    game.countdown = 0.01
    game._process(1.0/60.0)
    assert(gate.signal_stage == 0 and signal_label.text == "GO!")
    assert(not game.player.freeze and game.race_state == "RACING")
    game.race_time = 1.0
    game._process(1.0/60.0)
    assert(gate.signal_stage == -1 and not signal_label.is_visible_in_tree())
    return mesh

func _check_opening_obstacles(game: Node3D, layout: int) -> bool:
    var section := game.board.get_node("Course_01") as Node3D
    var art := section.get_node("OpeningObstacleArt") as OpeningObstacles
    assert(art.mesh.get_surface_count() == 1 and art.mesh.get_faces().size()/3 < 3200)
    assert(art.get_child_count() == 0 and
        art.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
    var expected: int = 2
    match layout:
        0: expected += 8 if game.selected_track == 2 else 7
        1: expected += 15
        2: expected += 9 if game.selected_track == 2 else 6
    assert(art.obstacle_count == expected and not art.entry_gaps.is_empty(),
        "The first module needs full visual coverage and a marked approach")
    assert((art.spinner_radius > 3.5) == (layout == 2),
        "Only the kinetic layout marks a full rotating sweep")
    var first_edge := art.entry_z-OpeningObstacles.ENTRY_LEAD
    for gap in art.entry_gaps:
        for footprint in art.danger_footprints:
            if footprint.end.y >= first_edge-OpeningObstacles.ENTRY_DEPTH:
                assert(gap.y <= footprint.position.x-OpeningObstacles.CLEARANCE+0.001 or
                    gap.x >= footprint.end.x+OpeningObstacles.CLEARANCE-0.001,
                    "Do not paint an entry gap through geometry or a paddle sweep")
    game.set_graphics_quality(0)
    assert(art.is_visible_in_tree(), "Economy must retain approach guidance")
    game.set_graphics_quality(1)
    return true

func _check_forge_finish(game: Node3D, finish: FinishLine) -> bool:
    var art: MeshInstance3D = game.final_obstacle_art
    assert(art.mesh.get_surface_count() == 1 and art.passing_marks.size() >= 3)
    assert(finish.mesh.get_aabb().end.y > 4.0 and (finish.get_child(0) as Label3D).position.y > 3.0)
    var probe := SphereShape3D.new()
    probe.radius = Racer.RADIUS
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = probe
    query.collision_mask = 1
    query.exclude = game.airtime.ignored_rids
    for frame in range(4):
        await physics_frame
    for mark: Vector2 in art.passing_marks:
        var x := art.global_position.x+mark.x
        var start := Vector3(x,game.height_at(mark.y+0.46)+0.55,mark.y+0.46)
        var end := Vector3(x,game.height_at(mark.y-2.1)+0.55,mark.y-2.1)
        assert(game._evasion_span_clear(query,start,end),"Painted opening intersects a real blocker")
    var mark: Vector2 = art.passing_marks[0]
    var approach_z := mark.y+5.0
    var approach := Vector3(art.global_position.x+mark.x,game.height_at(approach_z)+0.43,approach_z)
    var velocity := Vector3(0,0,-23.0)
    game.cam_mode = 0
    game.airtime.reset_round()
    game.race_moments.reset_round()
    game.player.global_position = approach
    game.player.linear_velocity = velocity
    game._update_camera(0.1,true)
    var eye: Vector3 = game.camera.global_position
    var point: Vector3 = art.passing_mark_ahead(game,approach,velocity)
    assert(point.is_finite())
    var block := eye.lerp(point,(point.z+0.5-eye.z)/(point.z-eye.z))
    block.y = game.height_at(block.z)+Racer.RADIUS
    var rival: RigidBody3D = game.racers[0]
    rival.global_position = block
    game.race_moments.tick(0.12)
    var locator: Control = game.ui.player_locator
    locator.refresh(0.12)
    assert(game.race_moments.occluded_passing_mark.is_equal_approx(point) and locator.evasion_center.is_finite(),
        "A racer masking the physical mark should reveal the passing chevron")
    rival.global_position.x += 2.8
    game.race_moments.tick(0.12)
    locator.refresh(0.12)
    assert(not game.race_moments.occluded_passing_mark.is_finite() and not locator.evasion_center.is_finite())
    var z: float = game.FINISH_Z+6.2
    game.player.global_position = Vector3(game.track_center_at(z)+2.85,game.height_at(z)+0.43,z)
    game.player.linear_velocity = Vector3(0,0,-23.0)
    game.airtime.reset_round()
    game.race_moments.reset_round()
    game.cam_mode = 0
    game._update_camera(0.1,true)
    var finish_offset := absf(game.camera_lookahead.x-finish.global_position.x)
    game.cam_mode = 1
    game._update_camera(0.1,true)
    var overhead: Vector3 = game.camera_lookahead
    game.final_obstacle_art = null
    game._update_camera(0.1,true)
    assert(game.camera_lookahead.is_equal_approx(overhead),"Player-controlled cameras must retain their pose")
    game.cam_mode = 0
    game._update_camera(0.1,true)
    assert(finish_offset < absf(game.camera_lookahead.x-finish.global_position.x),
        "The chase camera should draw the real stripe toward center")
    game.final_obstacle_art = art
    return true

func _verify() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://test_variation_career.cfg"
    var first_layout: int = game.built_variation
    assert(first_layout == 0)
    var gates: int = game.hazard_beacons.size()
    assert(gates == 28, "Expected two physical edge hazards across fourteen sections")
    var near_gate: Dictionary = game.upcoming_hazard(float(game.hazard_beacons[0]["z"]) + 12.0)
    assert(not near_gate.is_empty() and int(near_gate["distance"]) <= 12,
        "Lookahead must report approaching gate")
    var layouts: Array[int] = []
    for attempt in range(4):
        game.start_race("Grip Tape")
        layouts.append(game.built_variation)
        assert(game.board.get_parent() == game)
        assert(game.board.get_meta("track_index") == game.selected_track)
        assert(game.ui.hazard_label != null, "Upcoming gate warning not attached")
        assert(game.racers.size() == 40, "Race must have 40 marbles")
        game.return_to_menu()
        await process_frame
    assert(layouts == [0,1,2,0], "Repeat runs must cycle all three obstacle layouts")
    assert(game.get_tree().get_nodes_in_group("placeholder_empty").size() == 0)
    var boards: int = 0
    for child in game.get_children():
        if child.name == "HandcraftedWoodenCourse":
            boards += 1
    assert(boards == 1, "Old course was left in the scene and could double physics")
    print("VARIATION_AND_HAZARD_PASS: 0-1-2-0, 28 edge hazards, HUD warning, one course, 40 racers")
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var profiles: Array[Mesh] = []
    var gates_by_biome: Array[Mesh] = []
    var finishes_by_biome: Array[Mesh] = []
    for biome in range(3):
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            var opening_layout: int = game._obstacle_layout(1)
            game.start_race("Grip Tape")
            assert(game.built_variation == layout and game.racers.size() == 40)
            var finish := game.board.get_node("FinishLine") as FinishLine
            assert(is_equal_approx(finish.position.z,game.FINISH_Z))
            assert(finish.mesh.get_surface_count() == 1 and finish.get_child_count() == 2)
            for vertex in finish.mesh.get_faces():
                assert(vertex.y < 0.07 or absf(vertex.x) >= 5.60,
                    "The finish must leave the driving corridor open")
            var profile := _check_rail_batch(game,biome)
            var frame := _check_start_gate(game)
            assert(_check_opening_obstacles(game,opening_layout))
            if biome == 2:
                assert(await _check_forge_finish(game,finish))
            if layout == 0:
                assert(profile not in profiles, "Each biome needs its own geometry")
                assert(frame not in gates_by_biome, "Each biome needs its own starting towers")
                assert(finish.mesh not in finishes_by_biome,"Each biome needs its own finish markers")
                profiles.append(profile)
                gates_by_biome.append(frame)
                finishes_by_biome.append(finish.mesh)
            else:
                assert(profile == profiles[biome], "Reuse geometry across layout changes")
                assert(frame == gates_by_biome[biome], "Reuse tower geometry across layout changes")
                assert(finish.mesh == finishes_by_biome[biome])
            game.return_to_menu()
            await process_frame
    print("RAIL_PROFILE_PASS: 9 layouts, 40 racers, all guards match physics, one rail batch")
    print("START_GATE_PASS: 9 layouts, 40 racers, open sightline, countdown, launch and reset")
    print("OPENING_ART_PASS: 9 layouts, one mesh, clear first gaps, full paddle sweep, Economy")
    print("FORGE_FINISH_VIEW_PASS: three sets of collider-checked slalom marks, pack occlusion, tall signs and chase framing")
    game.queue_free()
    for n in range(4):
        await process_frame
    quit(0)
