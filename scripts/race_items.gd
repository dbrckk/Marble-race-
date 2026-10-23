extends Node3D
## Sparse arcade pickups. The offline game or dedicated server owns effects.
## Computer-controlled marbles never collect or activate an item.
const ITEM_Z := [-28.0, -79.0, -128.0, -169.0]
const ITEM_X := [-2.8, 2.8, -2.0, 2.0]
const PICKUP_RADIUS_SQUARED := 3.1
# The physical shockwave is a true radial, same-deck interaction. Remote
# clients only render the confirmed result; no client can apply its impulse.
const PULSE_RANGE := 4.12
const PULSE_MIN_DISTANCE := 0.32
const PULSE_VERTICAL_LIMIT := 1.20
const PULSE_HORIZONTAL_IMPULSE := 4.15
const PULSE_LIFT_IMPULSE := 1.10
const PULSE_VISUAL_DURATION := 0.52
const ITEM_KINDS := ["turbo", "spring", "pulse", "stabilizer"]
const ITEM_NAMES := ["TURBO", "JUMP", "SHOCKWAVE", "STEADY DASH"]
const TRACK_PATH = preload("res://scripts/track_path.gd")
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
var pulse_ring: MeshInstance3D
var pulse_material: StandardMaterial3D
var pulse_remaining := 0.0
var visual_quality := 1
var confirmed_pulses := 0

static func kind_at(index: int, track: int) -> String:
    return ITEM_KINDS[posmod(index+clampi(track,0,2),ITEM_KINDS.size())]

static func label_at(index: int, track: int) -> String:
    return ITEM_NAMES[posmod(index+clampi(track,0,2),ITEM_NAMES.size())]

static func lane_offset(index: int, track: int, variation: int) -> float:
    return ITEM_X[posmod(index+clampi(track,0,2)+posmod(variation,3),ITEM_X.size())]

static func placement_at(index: int, track: int, variation: int) -> Vector3:
    # Pure geometry shared by physical world and Android pre-race map.
    var z: float = ITEM_Z[index]
    return Vector3(TRACK_PATH.center_at(z,track)+lane_offset(index,track,variation),
        TRACK_PATH.height_at(z,track)+1.05,z)

func nearest_available(at: Vector3, racer_id: int, max_distance: float = 28.0) -> Dictionary:
    # Only four candidate pickups. Called by HUD at 9Hz, never the 60Hz
    # racing simulation. A collected client pickup stays hidden until reset.
    # A racer committed to the exterior bridge cannot reach main-road items
    # before the physical merge. Suppress misleading impossible pickup cues.
    var on_outer_bridge: bool = is_instance_valid(game.shortcut_route) and (
        str(game.shortcut_route.shortcut_hint(at).get("mode","")) == "merge")
    for i in range(items.size()):
        var pickup: Node3D = items[i]
        if not is_instance_valid(pickup) or not pickup.visible or (
            used.has("%d:%d" % [i,racer_id])):
            continue
        if on_outer_bridge and pickup.position.z <= game.shortcut_route.ENTRY_Z and (
            pickup.position.z >= game.shortcut_route.EXIT_Z):
            continue
        var distance: float = at.z-pickup.position.z
        if distance < 0.0 or distance > max_distance:
            continue
        var side: String = "LEFT" if lane_offset(i,game.selected_track,
            game.built_variation) < 0.0 else "RIGHT"
        return {"index":i, "distance":distance, "side":side,
            "kind":kind_at(i,game.selected_track),
            "label":label_at(i,game.selected_track)}
    return {}

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
        pickup.position = placement_at(i,track,variation)
        # Readable identity from the approach, without changing hitbox size.
        # One billboard per rare collectible; no extra lights or shadows.
        var title := Label3D.new()
        title.name = "ImmediateEffectLabel"
        title.text = label_at(i,track)
        title.font_size = 34
        title.pixel_size = 0.010
        title.outline_size = 10
        title.modulate = material.albedo_color.lightened(0.27)
        title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        title.position = Vector3(0.0,0.92,0.0)
        pickup.add_child(title)
        add_child(pickup)
        items.append(pickup)
    _build_pulse_fx()

func _build_pulse_fx() -> void:
    # A single reusable unlit torus is enough for one local human's instant
    # rare item. No lights, shaders, particles, physics bodies or extra
    # audio channels; it is invisible unless a real pulse is confirmed.
    pulse_ring = MeshInstance3D.new()
    pulse_ring.name = "ConfirmedShockwaveVisual"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.90
    mesh.outer_radius = 1.03
    mesh.rings = 24
    mesh.ring_segments = 6
    pulse_ring.mesh = mesh
    pulse_material = StandardMaterial3D.new()
    pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pulse_material.albedo_color = COLORS[2]
    pulse_material.emission_enabled = true
    pulse_material.emission = COLORS[2]
    pulse_material.emission_energy_multiplier = 0.72
    pulse_material.no_depth_test = false
    pulse_ring.material_override = pulse_material
    pulse_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pulse_ring.visible = false
    add_child(pulse_ring)

func set_quality(quality: int) -> void:
    visual_quality = clampi(quality,0,2)
    if is_instance_valid(pulse_ring):
        pulse_ring.visible = visual_quality > 0 and pulse_remaining > 0.0

func _show_pulse(at: Vector3) -> void:
    # Triggered only after offline/server-authoritative human collection.
    # The client uses the validated dedicated-server notification instead.
    confirmed_pulses += 1
    pulse_remaining = PULSE_VISUAL_DURATION
    if not is_instance_valid(pulse_ring):
        return
    pulse_ring.global_position = at+Vector3(0.0,-0.46,0.0)
    pulse_ring.scale = Vector3.ONE*0.36
    set_quality(visual_quality)

func _process(delta: float) -> void:
    if pulse_remaining <= 0.0 or not is_finite(delta) or delta <= 0.0:
        return
    pulse_remaining = maxf(0.0,pulse_remaining-delta)
    if not is_instance_valid(pulse_ring):
        return
    if visual_quality == 0 or pulse_remaining <= 0.0:
        pulse_ring.visible = false
        return
    var progress: float = 1.0-pulse_remaining/PULSE_VISUAL_DURATION
    var radius: float = lerpf(0.36,PULSE_RANGE,progress)
    pulse_ring.scale = Vector3(radius,1.0,radius)
    var fade: Color = COLORS[2]
    fade.a = 0.88*pow(1.0-progress,1.4)
    pulse_material.albedo_color = fade

static func pulse_impulse(offset: Vector3) -> Vector3:
    # Zero means no hit; also makes distance falloff deterministic enough
    # to validate independently of rendering and multiplayer state.
    if not offset.is_finite() or absf(offset.y) > PULSE_VERTICAL_LIMIT:
        return Vector3.ZERO
    var lateral := Vector2(offset.x,offset.z)
    var distance: float = lateral.length()
    # Godot stores Vector3 positions as 32-bit floats. A query at exactly
    # the advertised radius can round a few nanometres *inside* the edge;
    # reject that invisible remnant instead of giving an unfair micro-push.
    if distance < PULSE_MIN_DISTANCE or distance >= PULSE_RANGE-0.001:
        return Vector3.ZERO
    var intensity: float = 1.0-smoothstep(
        PULSE_MIN_DISTANCE,PULSE_RANGE,distance)
    var direction := Vector3(offset.x,0.0,offset.z)/distance
    return direction*(PULSE_HORIZONTAL_IMPULSE*intensity)+(
        Vector3.UP*PULSE_LIFT_IMPULSE*intensity)

func reset_round() -> void:
    clock = 0.0
    used.clear()
    pulse_remaining = 0.0
    confirmed_pulses = 0
    if is_instance_valid(pulse_ring):
        pulse_ring.visible = false
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
            var kind: String = kind_at(i,game.selected_track)
            _activate(kind,marble,racers)
            if net.role == "server":
                net.notify_item_collected(marble.racer_id,i,kind)
            if net.role == "offline":
                pickup.visible = false
                if kind == "pulse":
                    _show_pulse(marble.global_position)
                game.audio.item_pickup(kind)
                game.ui.show_item_pickup(kind)
            # Shared pickups remain visible in multiplayer: each human can
            # independently claim each one exactly once on the authority.
            break

func mark_local_pickup(index: int) -> void:
    # Client display only: the dedicated server already applied the effect.
    if index >= 0 and index < items.size() and is_instance_valid(items[index]):
        if items[index].visible and kind_at(index,game.selected_track) == "pulse":
            _show_pulse(items[index].global_position)
        items[index].visible = false

func _activate(kind: String, racer: RigidBody3D, racers: Array[RigidBody3D]) -> void:
    if kind == "turbo":
        racer.apply_central_impulse(Vector3(0.0,0.8,-9.5)*racer.mass)
    elif kind == "spring":
        racer.apply_central_impulse(Vector3(0.0,5.0,-3.4)*racer.mass)
    elif kind == "pulse":
        # Every close rival receives a bounded impulse proportional to its
        # actual distance, provided both spheres are on the same 3D deck.
        # No effects through raised shortcuts, on frozen/finished bodies
        # or outside the visible wave's exact horizontal radius.
        for opponent in racers:
            if opponent == racer or not is_instance_valid(opponent) or (
                opponent.finished or opponent.eliminated or opponent.freeze):
                continue
            var impulse: Vector3 = pulse_impulse(
                opponent.global_position-racer.global_position)
            if impulse == Vector3.ZERO:
                continue
            opponent.apply_central_impulse(impulse*opponent.mass)
        racer.apply_central_impulse(Vector3(0.0,0.5,-2.4)*racer.mass)
    else:
        racer.linear_velocity.x *= 0.25
        racer.angular_velocity *= 0.35
        racer.apply_central_impulse(Vector3(0.0,0.35,-4.0)*racer.mass)
