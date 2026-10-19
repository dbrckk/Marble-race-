extends Node3D
## Single batched transparent ground shadows for all rigidbody racers.
## Purely visual: contact shadows follow the inclined wooden planks.
const SHADOW_SHADER = preload("res://shaders/contact_shadow.gdshader")
const RACE_CAPACITY := 40

var racers: Array[RigidBody3D] = []
var pool: MultiMesh
var shadows: MultiMeshInstance3D
var pulse_time := 0.0
var quality_high := true

func _ready() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2(1.50,1.50)
    var material := ShaderMaterial.new()
    material.shader = SHADOW_SHADER
    quad.material = material
    pool = MultiMesh.new()
    pool.transform_format = MultiMesh.TRANSFORM_3D
    pool.instance_count = RACE_CAPACITY
    pool.mesh = quad
    pool.visible_instance_count = 0
    shadows = MultiMeshInstance3D.new()
    shadows.name = "FortySoftContactShadows"
    shadows.multimesh = pool
    shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadows)

func bind_racers(current: Array[RigidBody3D]) -> void:
    racers = current.duplicate()
    pool.visible_instance_count = mini(RACE_CAPACITY, racers.size())
    update_shadows()

func clear_racers() -> void:
    racers.clear()
    pool.visible_instance_count = 0

func update_shadows() -> void:
    if pool.visible_instance_count <= 0:
        return
    var axis := Basis(Vector3.RIGHT, -PI * 0.5 - atan(0.085))
    for i in range(pool.visible_instance_count):
        var marble := racers[i]
        if not is_instance_valid(marble):
            pool.set_instance_transform(i,Transform3D(Basis(),Vector3(0,-1000,0)))
            continue
        var p := marble.global_position
        var gap := maxf(0.0,p.y - p.z*0.085-0.39)
        var radius := clampf(1.0 + gap*0.14,0.8,1.55)
        var location := Vector3(p.x,p.z*0.085+0.065,p.z)
        var basis := axis.scaled(Vector3(radius,radius,radius))
        pool.set_instance_transform(i,Transform3D(basis,location))

func _process(delta: float) -> void:
    pulse_time += delta
    update_shadows()
