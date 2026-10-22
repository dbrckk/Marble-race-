extends Node3D
## Sparse arcade pickups. The offline game or dedicated server owns effects.
## Computer-controlled marbles never collect or activate an item.
const ITEM_Z := [-28.0, -79.0, -128.0, -169.0]
const ITEM_X := [-2.8, 2.8, -2.0, 2.0]
const PICKUP_RADIUS_SQUARED := 3.1
const ITEM_KINDS := ["turbo", "spring", "pulse", "stabilizer"]
const COLORS := [
    Color("#5ff0ff"), Color("#fce67b"), Color("#df90ff"), Color("#70edb8")
]
var game: Node3D
var items: Array[Node3D] = []
var used: Dictionary = {}
var clock := 0.0
# Reused scratch list: scan the 40 marbles ONCE per physics frame, then
# test pickup collisions for only the 1-4 authoritative human racers.
var eligible_collectors: Array[RigidBody3D] = []

func setup(owner: Node3D, track: int, variation: int) -> void:
    game = owner
    for i in range(ITEM_Z.size()):
        var pickup := Node3D.new()
        pickup.name = "RarePickup_%02d" % i
        var shell := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.48
        sphere.height = 0.96
        sphere.radial_segments = 16
        sphere.rings = 8
        shell.mesh = sphere
        var material := StandardMaterial3D.new()
        material.albedo_color = COLORS[(i + track) % COLORS.size()]
        material.metallic = 0.35
        material.roughness = 0.16
        material.emission_enabled = true
        material.emission = material.albedo_color
        material.emission_energy_multiplier = 1.5
        shell.material_override = material
        shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        pickup.add_child(shell)
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.57
        torus.outer_radius = 0.65
        torus.rings = 16
        torus.ring_segments = 8
        ring.mesh = torus
        ring.material_override = material
        ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        pickup.add_child(ring)
        var z: float = ITEM_Z[i]
        var x: float = ITEM_X[(i + track + variation) % ITEM_X.size()]
        pickup.position = Vector3(x+game.track_center_at(z),game.height_at(z)+1.05,z)
        add_child(pickup)
        items.append(pickup)

func reset_round() -> void:
    clock = 0.0
    used.clear()
    for item in items:
        if is_instance_valid(item):
            item.visible = true

func _is_human(marble: RigidBody3D, net: Node) -> bool:
    if net.role == "server":
        return marble.network_controlled and net.joined_slots.values().has(marble.racer_id)
    return net.role == "offline" and marble.is_player

func tick(delta: float, racers: Array[RigidBody3D], net: Node) -> void:
    clock += delta
    eligible_collectors.clear()
    for marble in racers:
        if is_instance_valid(marble) and not marble.finished and (
            not marble.eliminated) and _is_human(marble,net):
            eligible_collectors.append(marble)
    for i in range(items.size()):
        var pickup := items[i]
        if not is_instance_valid(pickup):
            continue
        pickup.rotation.y += delta * 1.8
        pickup.position.y = game.height_at(ITEM_Z[i])+1.05+sin(clock*2.5+i)*0.16
        for marble in eligible_collectors:
            var key := "%d:%d" % [i,marble.racer_id]
            if used.has(key):
                continue
            if marble.global_position.distance_squared_to(pickup.global_position) > PICKUP_RADIUS_SQUARED:
                continue
            used[key] = true
            var kind: String = ITEM_KINDS[(i + game.selected_track) % ITEM_KINDS.size()]
            _activate(kind,marble,racers)
            if net.role == "server":
                net.notify_item_collected(marble.racer_id,i,kind)
            if net.role == "offline":
                pickup.visible = false
                game.audio.item_pickup(kind)
                game.ui.show_item_pickup(kind)
            # Shared pickups remain visible in multiplayer: each human can
            # independently claim each one exactly once on the authority.
            break

func mark_local_pickup(index: int) -> void:
    # Client display only: the dedicated server already applied the effect.
    if index >= 0 and index < items.size() and is_instance_valid(items[index]):
        items[index].visible = false

func _activate(kind: String, racer: RigidBody3D, racers: Array[RigidBody3D]) -> void:
    if kind == "turbo":
        racer.apply_central_impulse(Vector3(0.0,0.8,-9.5)*racer.mass)
    elif kind == "spring":
        racer.apply_central_impulse(Vector3(0.0,5.0,-3.4)*racer.mass)
    elif kind == "pulse":
        for opponent in racers:
            if opponent == racer or not is_instance_valid(opponent) or opponent.finished or opponent.eliminated:
                continue
            var offset: Vector3 = opponent.global_position-racer.global_position
            if offset.length_squared() > 17.0 or offset.length_squared() < 0.1:
                continue
            var horizontal := Vector3(offset.x,0.0,offset.z).normalized()
            opponent.apply_central_impulse((horizontal*3.8+Vector3.UP*1.2)*opponent.mass)
        racer.apply_central_impulse(Vector3(0.0,0.5,-2.4)*racer.mass)
    else:
        racer.linear_velocity.x *= 0.25
        racer.angular_velocity *= 0.35
        racer.apply_central_impulse(Vector3(0.0,0.35,-4.0)*racer.mass)
