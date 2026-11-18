extends Node3D
## Single batched transparent ground shadows for all rigidbody racers.
## Purely visual: contact shadows follow the inclined wooden planks.
const SHADOW_SHADER = preload("res://shaders/contact_shadow.gdshader")
const RACE_CAPACITY := 30

var racers: Array[RigidBody3D] = []
var pool: MultiMesh
var shadows: MultiMeshInstance3D
var shadow_interval := 1.0 / 30.0
var shadow_elapsed := 0.0

func set_update_rate(hertz: int) -> void:
    shadow_interval = 1.0 / float(maxi(1,hertz))
    shadow_elapsed = shadow_interval

func _ready() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2(1.50,1.50)
    var material := ShaderMaterial.new()
    material.shader = SHADOW_SHADER
    quad.material = material
    pool = MultiMesh.new()
    pool.transform_format = MultiMesh.TRANSFORM_3D
    # Per-marble alpha fades the ground contact as a marble takes flight.
    # Keep all thirty shadows in a single MultiMesh draw call.
    pool.use_custom_data = true
    pool.instance_count = RACE_CAPACITY
    pool.mesh = quad
    pool.visible_instance_count = 0
    shadows = MultiMeshInstance3D.new()
    shadows.name = "ThirtySoftContactShadows"
    shadows.multimesh = pool
    shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadows)

func bind_racers(current: Array[RigidBody3D]) -> void:
    racers = current.duplicate()
    pool.visible_instance_count = mini(RACE_CAPACITY, racers.size())
    shadow_elapsed = 0.0
    update_shadows()

func clear_racers() -> void:
    racers.clear()
    pool.visible_instance_count = 0

func update_shadows() -> void:
    if pool.visible_instance_count <= 0:
        return
    var stage := get_parent() as Node3D
    for i in range(pool.visible_instance_count):
        var marble := racers[i]
        if not is_instance_valid(marble):
            pool.set_instance_transform(i,Transform3D(Basis(),Vector3(0,-1000,0)))
            pool.set_instance_custom_data(i,Color(1.0,1.0,1.0,0.0))
            continue
        var p := marble.global_position
        var road_height: float = stage.height_at(p.z)
        var gap := maxf(0.0,p.y-road_height-0.39)
        var radius := clampf(1.0 + gap*0.14,0.8,1.55)
        # A high marble must not look glued to the board. The soft disc
        # expands and fades continuously without extra lights or meshes.
        var contact_alpha := 1.0-smoothstep(0.0,2.8,gap)
        var location := Vector3(p.x,road_height+0.065,p.z)
        var axis := Basis(Vector3.RIGHT, -PI*0.5-atan(stage.track_grade_at(p.z)))
        var basis := axis.scaled(Vector3(radius,radius,radius))
        pool.set_instance_transform(i,Transform3D(basis,location))
        pool.set_instance_custom_data(i,Color(1.0,1.0,1.0,contact_alpha))

func _process(delta: float) -> void:
    if not visible or racers.is_empty() or not is_instance_valid(racers[0]) or racers[0].freeze:
        return
    shadow_elapsed += delta
    if shadow_elapsed >= shadow_interval:
        shadow_elapsed = fmod(shadow_elapsed,shadow_interval)
        update_shadows()
