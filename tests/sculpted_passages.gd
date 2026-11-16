extends SceneTree
## Real split-slope mountain apexes, collision-only physics and batched
## architectural portal art in all nine Android course rematches.
const GEOMETRY = preload("res://scripts/course_sculptures.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    assert(GEOMETRY.BANK_SECTIONS.size() == 4)
    assert(GEOMETRY.VAULT_SECTIONS.size() == 3)
    for section in GEOMETRY.BANK_SECTIONS:
        assert(GEOMETRY.is_banked_section(section))
        assert(not GEOMETRY.is_banked_section(section+1))
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.career.save_path = "user://qa_sculpted_course.cfg"
    game.career.unlocked = 3
    game.set_process(false)
    game.set_physics_process(false)
    var checked := 0
    for biome in range(3):
        game.return_to_menu()
        assert(game.set_track(biome))
        for layout in range(3):
            game.race_variation = layout
            game.start_race("Grip Tape")
            game.race_state = "RACING"
            assert(game.built_variation == layout and game.racers.size() == 40)
            var geometry: Node3D = game.course_sculptures
            assert(is_instance_valid(geometry) and
                geometry == game.board.get_node("SculptedRacePassages"))
            assert(geometry.banks.size() == 8 and
                geometry.bank_roots.size() == 4,
                "Four banked positions require two genuine sloping colliders each")
            assert(geometry.arch_rib_count == 9 and
                geometry.vault_crest_points.size() == 9,
                "Three biome passages require exactly nine actual elevated ribs")
            var roof_pitch: float = GEOMETRY.VAULT_PITCHES[biome]
            assert(roof_pitch > 0.10 and roof_pitch < 0.40)
            var crest: Vector3 = geometry.vault_crest_points[0]
            var ceiling_floor: float = game.height_at(crest.z)
            assert(crest.y-ceiling_floor > 5.6,
                "A high 3D passage leaves room above real marble jumps")
            if biome == 2:
                _verify_forge_sightline(game,geometry)
            else:
                assert(absf(crest.y-ceiling_floor-(
                    GEOMETRY.VAULT_CLEARANCE+0.57+
                    tan(roof_pitch)*(GEOMETRY.FORGE_RIB_OFFSET-GEOMETRY.FORGE_LIGHT_OFFSET))) < 0.001,
                    "Fork wing lights stay on the outer ribs")
                _verify_first_fork_sightline(game,geometry,layout)
                if biome == 0:
                    _verify_edge_markers(game,"Woodworks",[0])
            if biome == 1:
                _verify_glacier_return(game,geometry,layout)
            assert(geometry.bank_surfaces.multimesh.instance_count == 8 and
                geometry.apex_inlays.multimesh.instance_count == 4)
            var highlight_count: int = [12,15,18][biome]
            assert(geometry.vault_posts.multimesh.instance_count == 18 and
                geometry.vault_roofs.multimesh.instance_count == 18 and
                geometry.vault_highlights.multimesh.instance_count == highlight_count,
                "Lateral lighting reuses the existing GPU batch")
            assert(geometry.canopy_panels.multimesh.instance_count == 12 and
                geometry.canopy_trims.multimesh.instance_count == 12,
                "Three vaulted landmarks must include 12 open-sky roof bays")
            assert(geometry.get_child_count() == 15,
                "Eight physics banks and seven GPU batches prevent Android draw-call spikes")
            var bay: MultiMeshInstance3D = geometry.canopy_panels
            assert(bay.get_child_count() == 0 and
                bay.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
                "Canopy must not cast costly shadows or create hidden physical traps")
            # RenderingServer does not return GPU instance transforms in
            # headless mode. Compare the actual CPU transforms used by
            # _instanced() against physical ground and the open sightline.
            assert(geometry.canopy_roots.size() ==
                bay.multimesh.instance_count,
                "Each GPU canopy must be backed by one checked source point")
            for transform: Transform3D in geometry.canopy_roots:
                var at := transform.origin
                var clearance: float = at.y-game.height_at(at.z)
                assert(at.is_finite() and
                    clearance >= GEOMETRY.VAULT_CLEARANCE-0.1,
                    "The open-sky canopy must remain well above physical marble jumps")
                assert(absf(at.x-game.track_center_at(at.z)) > 4.0,
                    "Open center skylight preserves chase-camera visibility")
            var excluded: Array[RID] = []
            var pending: Array[Node] = [game.board]
            while not pending.is_empty():
                var node: Node = pending.pop_back()
                if node is CollisionObject3D and not geometry.banks.has(node):
                    excluded.append((node as CollisionObject3D).get_rid())
                for child in node.get_children():
                    pending.append(child)
            for marble in game.racers:
                excluded.append(marble.get_rid())
            await physics_frame
            for i in range(GEOMETRY.BANK_SECTIONS.size()):
                var section: int = GEOMETRY.BANK_SECTIONS[i]
                var z: float = GEOMETRY.bank_z(section,layout)
                var side: float = GEOMETRY.bank_side(section,biome,layout)
                var at: Vector3 = geometry.bank_roots[i]
                assert(absf(at.z-z) < 0.001 and
                    absf(at.x-game.track_center_at(z)-side*GEOMETRY.BANK_OFFSET) < 0.001)
                assert(absf(at.x-game.track_center_at(z))-
                    GEOMETRY.BANK_WIDTH*0.5 > 1.20,
                    "The unchanged central lane must bypass every new bank")
                for half in range(2):
                    var body: StaticBody3D = geometry.banks[i*2+half]
                    var hitbox: CollisionShape3D = body.get_node(
                        "SculptedApexCollision")
                    assert(hitbox.shape is BoxShape3D and
                        not hitbox.disabled and
                        body.physics_material_override.friction >= 0.70,
                        "Each bank is a grippy physical road, not a fake overlay")
                    assert(absf(absf(body.rotation.z)-GEOMETRY.BANK_CANT) < 0.0001)
                    assert(body.rotation.x != 0.0,
                        "Physically tilted apexes must make the marble roll up")
                # Use the real physics world and ignore ONLY unrelated
                # colliders; the ray must hit the raised apex before
                # reaching the regular road beneath it.
                var probe_z: float = z+0.62
                var probe_x: float = game.track_center_at(probe_z)+(
                    side*GEOMETRY.BANK_OFFSET)
                var start := Vector3(probe_x,game.height_at(probe_z)+1.0,probe_z)
                var query := PhysicsRayQueryParameters3D.create(
                    start,start-Vector3(0.0,1.55,0.0))
                query.exclude = excluded
                var result: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
                assert(not result.is_empty() and
                    geometry.banks.has(result.get("collider")),
                    "An actual Godot ray must contact the raised, angled road piece")
                var climb: float = (result["position"] as Vector3).y-(
                    game.height_at(probe_z))
                assert(climb >= 0.025 and climb <= 0.43,
                    "The bank is noticeably elevated but low enough for real marbles")
                checked += 1
            game.set_graphics_quality(0)
            assert(geometry.bank_surfaces.visible and
                geometry.vault_roofs.visible and geometry.vault_posts.visible,
                "Economy must retain road geometry and silhouette landmarks")
            assert(not geometry.apex_inlays.visible and
                not geometry.vault_highlights.visible and
                not geometry.canopy_panels.visible and
                not geometry.canopy_trims.visible,
                "Economy retains only physical banks and core passage landmarks")
            game.set_graphics_quality(2)
            assert(geometry.apex_inlays.visible and
                geometry.vault_highlights.visible and
                geometry.canopy_panels.visible and
                geometry.canopy_trims.visible,
                "Ultra restores the overhead skylight and luminous roof trim")
            game.set_graphics_quality(1)
            assert(geometry.canopy_panels.visible and
                not geometry.canopy_trims.visible,
                "Balanced keeps roof silhouette while avoiding extra emissive trim")
            assert(geometry.banks.size() == 8 and game.racers.size() == 40,
                "Changing Android tier must never remove any track collision")
            game.set_graphics_quality(1)
            game.return_to_menu()
    assert(checked == 36,"Four real apex road stations x nine layouts")
    game.queue_free()
    for frame in range(4):
        await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(
        "user://qa_sculpted_course.cfg"))
    print("SCULPTED_PASSAGES_PASS: 36 real ramps, nine open first forks, Glacier return, exact split markers and GPU budgets")
    quit(0)

func _verify_forge_sightline(game: Node3D, geometry: Node3D) -> void:
    var mesh: Mesh = geometry.vault_roofs.multimesh.mesh
    assert(geometry.vault_rib_roots.size() == 18)
    for transform: Transform3D in geometry.vault_rib_roots:
        var bounds: AABB = transform*mesh.get_aabb()
        var center: float = game.track_center_at(transform.origin.z)
        if transform.origin.x < center:
            assert(bounds.end.x < center-5.15,
                "The full left rib must clear the line of sight above the lane")
        else:
            assert(bounds.position.x > center+5.15,
                "The full right rib must clear the line of sight above the lane")
    var cover: Mesh = geometry.canopy_panels.multimesh.mesh
    for transform: Transform3D in geometry.canopy_roots:
        var bounds: AABB = transform*cover.get_aabb()
        var center: float = game.track_center_at(transform.origin.z)
        assert(bounds.end.x < center-5.15 or bounds.position.x > center+5.15)
    _verify_edge_markers(game,"Forge",[0,1,2])

func _verify_first_fork_sightline(game: Node3D, geometry: Node3D, layout: int) -> void:
    var center_z := GEOMETRY.bank_z(GEOMETRY.VAULT_SECTIONS[0],layout)
    var roof: Mesh = geometry.vault_roofs.multimesh.mesh
    var canopy: Mesh = geometry.canopy_panels.multimesh.mesh
    var checked := 0
    for transform in geometry.vault_rib_roots+geometry.canopy_roots:
        if absf(transform.origin.z-center_z) > 3.4:
            continue
        var mesh := roof if transform in geometry.vault_rib_roots else canopy
        var bounds: AABB = transform*mesh.get_aabb()
        var center: float = game.track_center_at(transform.origin.z)
        assert(bounds.end.x < center-5.15 or bounds.position.x > center+5.15,
            "The first portal must be visible through the chase-camera corridor")
        checked += 1
    assert(checked == 10)

func _verify_glacier_return(game: Node3D, geometry: Node3D, layout: int) -> void:
    var center_z := GEOMETRY.bank_z(GEOMETRY.GLACIER_RETURN_VAULT,layout)
    var route: Node3D = game.shortcut_route
    var roof: Mesh = geometry.vault_roofs.multimesh.mesh
    var canopy: Mesh = geometry.canopy_panels.multimesh.mesh
    var checked := 0
    for transform: Transform3D in geometry.vault_rib_roots+geometry.canopy_roots:
        var z := transform.origin.z
        if absf(z-center_z) > 3.4:
            continue
        var mesh := roof if transform in geometry.vault_rib_roots else canopy
        var bounds: AABB = transform*mesh.get_aabb()
        var center: float = game.track_center_at(z)
        # Include the outer edge of the second lane, which curves in
        # toward the main road beneath this passage.
        var bridge_left: float = route.point_at(z).x-route.WIDTH*0.5
        assert(bounds.end.x < bridge_left or bounds.position.x > center+5.7,
            "Ice rib and canopy art must clear both racing lanes at the return")
        checked += 1
    assert(checked == 10)
    for node in game.board.get_children():
        assert(not (node is Label3D and node.text == "CHECKPOINT 2"),
            "The old overhead Glacier checkpoint must be replaced")
    _verify_edge_markers(game,"Glacier",[0,GEOMETRY.GLACIER_RETURN_SECTOR])

func _verify_edge_markers(game: Node3D, biome_name: String, sectors: Array[int]) -> void:
    var posts := game.board.get_node(biome_name+"SectorPostBatch") as MultiMeshInstance3D
    assert(posts.multimesh.instance_count == sectors.size()*2 and posts.cast_shadow ==
        GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "Sector posts use one shadow-free draw batch")
    var fx: Node3D = game.board.get_node("PolishedToyDetails")
    for sector in sectors:
        var marker := game.board.get_node("%sSectorMarker%d" % [biome_name,sector+1]) as Node3D
        assert(is_equal_approx(marker.position.z,game.CHECKPOINT_Z[sector]))
        for child in marker.get_children():
            assert(not child is CollisionObject3D and absf(child.position.x) >= 5.35-0.001,
                "Number plates and paint must stay off the central driving line")
        for side in range(2):
            var beacon: Node3D = fx.beacons[sector*2+side]
            assert(is_equal_approx(beacon.position.z,marker.position.z) and
                is_equal_approx(absf(beacon.position.x-marker.position.x),GEOMETRY.EDGE_SECTOR_POST_OFFSET) and
                is_equal_approx(beacon.position.y-marker.position.y,GEOMETRY.EDGE_SECTOR_BEACON_HEIGHT),
                "Sector pulse follows the sign and the exact timed plane")
