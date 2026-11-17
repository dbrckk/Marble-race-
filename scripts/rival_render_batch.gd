extends Node3D
## Two opaque glass batches share the unchanged physics transforms of the
## opponents. The local marble keeps its own material for skins and boost.
const Racer = preload("res://scripts/marble.gd")
const CAPACITY := 39
const SPHERE_EXTENT := Vector3.ONE*Racer.RADIUS
const CULL_MARGIN := Racer.RADIUS+0.02

var pools: Array[MultiMesh] = []
var material: ShaderMaterial
var slot_ids := PackedInt32Array()
var quality := -1

func _ready() -> void:
    material = ShaderMaterial.new()
    material.shader = Racer.SHADER
    material.set_shader_parameter("instanced_rivals",true)
    slot_ids.resize(CAPACITY*2)
    slot_ids.fill(-1)
    for i in 2:
        var pool := MultiMesh.new()
        pool.transform_format = MultiMesh.TRANSFORM_3D
        pool.use_colors = true
        pool.use_custom_data = true
        pool.instance_count = CAPACITY
        pool.visible_instance_count = 0
        var batch := MultiMeshInstance3D.new()
        batch.name = "NearbyGlass" if i == 0 else "DistantGlass"
        batch.multimesh = pool
        batch.material_override = material
        batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(batch)
        pools.append(pool)
    set_quality(1)

func set_quality(value: int) -> void:
    if quality == value:
        return
    quality = value
    material.set_shader_parameter("visual_quality",float(quality))
    pools[0].mesh = Racer.get_sphere(false,quality)
    pools[1].mesh = Racer.get_sphere(false,0)
    pools[1].visible_instance_count = 0

func clear() -> void:
    for pool in pools:
        pool.visible_instance_count = 0

func refresh(racers: Array[RigidBody3D], camera: Camera3D) -> void:
    var frustum := camera.get_frustum()
    var counts := Vector2i.ZERO
    var lower := [Vector3.INF,Vector3.INF]
    var upper := [-Vector3.INF,-Vector3.INF]
    for body in racers:
        if not is_instance_valid(body) or not body.is_visible_in_tree():
            continue
        var rival := body as Racer
        if rival.is_player:
            continue
        var pose := rival.transform
        if not _sphere_in_view(frustum,rival.global_position):
            continue
        var lod := int(quality == 1 and rival.using_distant_mesh)
        var slot := counts[lod]
        var pool := pools[lod]
        pool.set_instance_transform(slot,pose)
        var cached := lod*CAPACITY+slot
        if slot_ids[cached] != rival.racer_id:
            var id := rival.racer_id
            slot_ids[cached] = id
            var accent: Color = Racer.PALETTE[(id*7+5)%Racer.PALETTE.size()]
            pool.set_instance_color(slot,Racer.PALETTE[id%Racer.PALETTE.size()])
            pool.set_instance_custom_data(slot,Color(accent.r,accent.g,accent.b,float(id)))
        lower[lod] = pose.origin.min(lower[lod])
        upper[lod] = pose.origin.max(upper[lod])
        counts[lod] += 1
    for lod in pools.size():
        var pool := pools[lod]
        if counts[lod] > 0:
            var bounds := AABB(lower[lod]-SPHERE_EXTENT,upper[lod]-lower[lod]+SPHERE_EXTENT*2.0)
            if pool.custom_aabb != bounds:
                pool.custom_aabb = bounds
        if pool.visible_instance_count != counts[lod]:
            pool.visible_instance_count = counts[lod]

static func _sphere_in_view(frustum: Array[Plane], center: Vector3) -> bool:
    for plane in frustum:
        if plane.distance_to(center) > CULL_MARGIN:
            return false
    return true
