extends SceneTree
const RACER = preload("res://scripts/marble.gd")
## AUTO graphics respects setting persistence and hysteresis, without mocks.
func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_graphics_quality(3)
    assert(game.graphics_setting == 3 and game.graphics_quality == 1,
        "AUTO should start from balanced, not expensive Ultra")
    assert(game.graphics_mode_label() == "AUTO (BALANCED)")
    var prefs := ConfigFile.new()
    assert(prefs.load("user://marble_settings.cfg") == OK)
    assert(int(prefs.get_value("video","quality",-1)) == 3,
        "AUTO preference must survive restart")
    for i in range(11):
        game._auto_quality_sample(24.0,1.0)
    assert(game.graphics_quality == 1, "Auto downgraded too early")
    game._auto_quality_sample(24.0,1.0)
    assert(game.graphics_quality == 0, "Sustained low FPS should downgrade")
    assert(game.graphics_mode_label() == "AUTO (ECONOMY)")
    for i in range(27):
        game._auto_quality_sample(58.0,1.0)
    assert(game.graphics_quality == 0, "Do not upgrade before 28s")
    game._auto_quality_sample(58.0,1.0)
    assert(game.graphics_quality == 1, "Recovered sustained FPS should upgrade")
    assert(game.graphics_setting == 3, "Auto must not overwrite saved mode")
    for i in range(65):
        game._auto_quality_sample(60.0,1.0)
    assert(game.graphics_quality == 1, "Auto should cap at Balanced")
    game._auto_quality_sample(22.0,8.0)
    game._auto_quality_sample(48.0,1.0)
    game._auto_quality_sample(22.0,5.0)
    assert(game.graphics_quality == 1, "Borderline FPS must reset the downgrade countdown")
    game.set_graphics_quality(2)
    game._auto_quality_sample(12.0,99.0)
    assert(game.graphics_quality == 2, "Manual profile must never be modified")
    game.set_graphics_quality(1)
    game.career.unlocked = 3
    assert(game.set_track(2))
    var key_light: DirectionalLight3D = game.primary_light
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and
        is_equal_approx(key_light.directional_shadow_max_distance,33.0),
        "Forge Balanced uses a single shadow map over the driving view")
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
    game.race_variation = 2
    game.start_race("Grip Tape")
    assert(key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
    game.return_to_menu()
    game.set_graphics_quality(2)
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and
        is_equal_approx(key_light.directional_shadow_max_distance,72.0),
        "Ultra restores its longer shadow range on Forge")
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
    game.set_graphics_quality(0)
    assert(not key_light.shadow_enabled)
    game.set_graphics_quality(3)
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL)
    assert(game.set_track(1))
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and
        is_equal_approx(key_light.directional_shadow_max_distance,47.0),
        "Glacier Balanced uses a single map at the ice and bridge shadow range")
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
    assert(_check_marble_detail(game))
    game.set_graphics_quality(3)
    assert(game.set_track(0))
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and
        is_equal_approx(key_light.directional_shadow_max_distance,36.0),
        "Woodworks Auto uses the measured single-map Balanced shadow budget")
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
    game.race_variation = 2
    game.start_race("Grip Tape")
    assert(key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and
        is_equal_approx(key_light.directional_shadow_max_distance,36.0) and
        game.contact_shadows.visible)
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
    game.return_to_menu()
    game.set_graphics_quality(2)
    assert(key_light.shadow_enabled and
        key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and
        is_equal_approx(key_light.directional_shadow_max_distance,72.0))
    assert(_check_showroom(game,GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
    game.set_graphics_quality(0)
    assert(not key_light.shadow_enabled)
    print("ADAPTIVE_GRAPHICS_PASS: saved setting, stable hysteresis, 30fps recovery, profile/track shadows and marble LOD")
    game.queue_free()
    for i in range(4):
        await process_frame
    quit(0)


func _check_showroom(game: Node3D, mode: GeometryInstance3D.ShadowCastingSetting) -> bool:
    var roof: MeshInstance3D = game.board.get_node("ShowroomRoofBeam").get_child(0)
    assert(roof.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
        "The room's large shadow still defines the track lighting")
    assert(game.secondary_showroom_art.size() == 64+game.SEGMENTS+2*ceili(game.SEGMENTS/2.0))
    for art in game.secondary_showroom_art:
        assert(game.board.is_ancestor_of(art) and art.visible and art.cast_shadow == mode,
            "Only live decorative meshes change their casting mode")
    return true


func _check_marble_detail(game: Node3D) -> bool:
    game.set_graphics_quality(1)
    game.start_race("Grip Tape")
    var near: RigidBody3D = game.racers[0]
    var far: RigidBody3D = game.racers[1]
    var featured: RigidBody3D = game.racers[2]
    game.camera.global_transform = Transform3D.IDENTITY
    game.camera.fov = 70.0
    game.player.global_position = Vector3(0,0,-3)
    near.global_position = Vector3(0,0,-8)
    far.global_position = Vector3(0,0,-32)
    featured.global_position = Vector3(1,0,-32)
    game.race_moments.closest_rival = featured
    var original_shape: Shape3D = far.collision.shape
    var glass: Node3D = game.rival_render
    game._update_marble_detail(1.0)
    glass.refresh(game.racers,game.camera)
    assert(far.using_distant_mesh and glass.pools[1].mesh == RACER.get_sphere(false,0))
    assert(not near.using_distant_mesh and not featured.using_distant_mesh and
        game.player.mesh.mesh == RACER.get_sphere(true,1))
    assert(glass.pools[0].visible_instance_count == 2 and glass.pools[1].visible_instance_count == 1,
        "Visible near and distant rivals must populate just their own draw pools")
    assert(glass.slot_ids[0] == near.racer_id and glass.slot_ids[1] == featured.racer_id and
        glass.slot_ids[glass.CAPACITY] == far.racer_id,
        "Frustum culling must retain each opponent's glass identity")
    var custom_material: ShaderMaterial = game.player.glass_material
    assert(glass.material != custom_material and far.mesh == null,
        "Player skins need their own material while rivals share the two batches")
    var scale: float = 720.0*RACER.RADIUS/tan(deg_to_rad(game.camera.fov*0.5))
    far.global_position.z = -scale/25.0
    game._update_marble_detail(1.0)
    assert(far.using_distant_mesh,"A rival between the two thresholds keeps its current geometry")
    far.global_position.z = -scale/29.0
    game._update_marble_detail(1.0)
    glass.refresh(game.racers,game.camera)
    assert(not far.using_distant_mesh and glass.pools[0].visible_instance_count == 3 and
        glass.pools[1].visible_instance_count == 0)
    far.global_position.z = -32.0
    game._update_marble_detail(1.0)
    assert(far.using_distant_mesh and far.collision.shape == original_shape and
        game.player.glass_material == custom_material and game.racers.size() == 40)
    game.set_graphics_quality(2)
    game._update_marble_detail(1.0)
    glass.refresh(game.racers,game.camera)
    assert(glass.pools[0].mesh == RACER.get_sphere(false,2) and not far.using_distant_mesh)
    assert(glass.pools[1].visible_instance_count == 0)
    game.set_graphics_quality(0)
    assert(glass.pools[0].mesh == RACER.get_sphere(false,0) and not far.using_distant_mesh)
    far.hide()
    glass.refresh(game.racers,game.camera)
    assert(glass.pools[0].visible_instance_count == 2,"Hidden rivals cannot leave phantom glass")
    game.return_to_menu()
    assert(glass.pools[0].visible_instance_count == 0 and glass.pools[1].visible_instance_count == 0)
    return true
